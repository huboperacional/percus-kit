#!/usr/bin/env bash
# Vetor B (v6.14.0) - Unix: triagem Groq upstream do fact-check Sonnet.
# Espelha fact-check-triage.ps1 (primario, testado via Pester). Usa python3 pra
# parsing/JSON (confiavel) e chama o wrapper groq-llama.sh por finding.
# Em duvida -> SUSPEITA (escala pro Sonnet). Falha graceful: erro -> unverified.
#
# Uso: cat findings.md | fact-check-triage.sh [--wrapper <path>] [--model <m>] [--findings-file <f>]
set +e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER=""
MODEL="openai/gpt-oss-120b"
FINDINGS_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --wrapper) WRAPPER="$2"; shift 2;;
        --model) MODEL="$2"; shift 2;;
        --findings-file) FINDINGS_FILE="$2"; shift 2;;
        *) shift;;
    esac
done
[[ -z "$WRAPPER" ]] && WRAPPER="$SCRIPT_DIR/../providers/groq-llama.sh"

if [[ -n "$FINDINGS_FILE" && -f "$FINDINGS_FILE" ]]; then
    INPUT=$(cat "$FINDINGS_FILE")
else
    INPUT=$(cat)
fi

PERCUS_INPUT="$INPUT" PERCUS_WRAPPER="$WRAPPER" PERCUS_MODEL="$MODEL" python3 - <<'PYEOF'
import os, re, json, subprocess, tempfile
raw = os.environ.get('PERCUS_INPUT', '')
wrapper = os.environ.get('PERCUS_WRAPPER', '')
model = os.environ.get('PERCUS_MODEL', '')

def emit_empty(reason=""):
    o = {"triage_total": 0, "triage_plausivel": 0, "triage_suspeita": 0,
         "triage_unverified": 0, "escalate": [], "results": []}
    if reason:
        o["skip_reason"] = reason
    print(json.dumps(o, ensure_ascii=False, indent=2))
    raise SystemExit(0)

if not raw.strip():
    emit_empty()
if re.search(r'(?i)Sem findings cr[ií]ticos', raw):
    emit_empty("Sem findings criticos detectado no input")

pattern = re.compile(r'(\[SEV:\s*(risco|bug)\].*?)(?=\[SEV:\s*(?:risco|bug)\]|\Z)', re.S)
findings = []
for m in pattern.finditer(raw):
    block = m.group(1).strip()
    sev = m.group(2)
    fp = ""
    fm = re.search(r'(?:^|\s|`|")([A-Za-z0-9_./-]+\.[A-Za-z]{1,5}(?::\d+(?:-\d+)?)?)', block)
    if fm:
        fp = fm.group(1).strip().strip('`"')
    findings.append({"severity": sev, "file_path": fp, "description": block,
                     "triage": "unverified", "reason": ""})

if not findings:
    emit_empty()

sysprompt = ("Voce e triador de claims tecnicos sobre codigo. Para o claim recebido, responda com UMA palavra na PRIMEIRA linha:\n"
             "- PLAUSIVEL  (claim coerente e provavelmente correto; nao exige ler o codigo pra confiar)\n"
             "- SUSPEITA   (claim duvidoso, generico demais, ou que exige ler o codigo pra confirmar/refutar)\n"
             "Em duvida, responda SUSPEITA. Depois da palavra, no maximo 1 frase. Maximo 40 palavras.")

wrapper_ok = os.path.isfile(wrapper)
for f in findings:
    if not wrapper_ok:
        f["reason"] = "wrapper groq-llama.sh nao encontrado: %s" % wrapper
        continue
    up = "Claim do reviewer:\n%s\n\nArquivo citado: %s\n\nTriagem (comece com PLAUSIVEL ou SUSPEITA):" % (f["description"], f["file_path"])
    tmp = None
    try:
        with tempfile.NamedTemporaryFile('w', suffix='.txt', delete=False, encoding='utf-8') as tf:
            tf.write(up)
            tmp = tf.name
        # 1024, nao 64: o triador virou modelo de RACIOCINIO (openai/gpt-oss-120b) em 2026-08-18 e
        # gasta 60~270 tokens pensando antes da primeira letra. Com teto 64/128 o content volta
        # VAZIO em 100% das amostras. Aqui NAO ha o bug de stream do irmao .ps1: capture_output
        # separa stdout de stderr, entao o aviso do wrapper nao contamina o json.loads.
        r = subprocess.run(['bash', wrapper, '--prompt-file', tmp, '--system-prompt', sysprompt,
                            '--model', model, '--max-tokens', '1024'],
                           capture_output=True, text=True, encoding='utf-8')
        try:
            j = json.loads(r.stdout)
        except Exception:
            j = None
        # "truncated" tambem serve: le-se so a PRIMEIRA LINHA, que chega muito antes do corte.
        if j and j.get('status') in ('ok', 'truncated') and j.get('content'):
            first = next((l for l in j['content'].split('\n') if l.strip()), '')
            # O modelo responde "**PLAUSIVEL**" (negrito) e acentua o I. O padrao antigo exigia a
            # palavra crua no inicio da linha, entao nao casava nenhum dos dois e tudo virava
            # "formato inesperado". Normaliza a enfase antes; '.' cobre o acento sem tirar o
            # arquivo do 100% ASCII.
            norm = re.sub(r'[*_`#>~\s]', '', first)
            # O motivo nem sempre cabe na linha do veredito: este modelo costuma responder
            # "**SUSPEITA**" sozinho e justificar na linha seguinte. Sem este fallback a
            # auditoria gravava veredito com reason vazio -- decisao sem o porque.
            _linhas = [l for l in j['content'].split('\n') if l.strip()]
            prox = re.sub(r'^[*_`#>~\s-]+', '', _linhas[1]).strip() if len(_linhas) > 1 else ""
            if re.match(r'(?i)^PLAUS.VEL', norm):
                f["triage"] = "plausivel"
                mm = re.search(r'(?i)PLAUS.VEL[*_:\s-]+(.+)', first)
                f["reason"] = mm.group(1).strip() if mm else prox
            elif re.match(r'(?i)^SUSPEITA', norm):
                f["triage"] = "suspeita"
                mm = re.search(r'(?i)SUSPEITA[*_:\s-]+(.+)', first)
                f["reason"] = mm.group(1).strip() if mm else prox
            else:
                f["triage"] = "unverified"
                f["reason"] = "triador retornou formato inesperado"
        else:
            f["triage"] = "unverified"
            f["reason"] = ("Groq error: %s" % j.get('error')) if (j and j.get('error')) else "resposta nao parseavel do wrapper"
    except Exception as e:
        f["triage"] = "unverified"
        f["reason"] = "excecao ao chamar wrapper: %s" % e
    finally:
        if tmp:
            try:
                os.unlink(tmp)
            except Exception:
                pass

escalate = [f for f in findings if f["triage"] != "plausivel"]
print(json.dumps({
    "triage_total": len(findings),
    "triage_plausivel": sum(1 for f in findings if f["triage"] == "plausivel"),
    "triage_suspeita": sum(1 for f in findings if f["triage"] == "suspeita"),
    "triage_unverified": sum(1 for f in findings if f["triage"] == "unverified"),
    "escalate": escalate,
    "results": findings,
}, ensure_ascii=False, indent=2))
PYEOF
exit $?
