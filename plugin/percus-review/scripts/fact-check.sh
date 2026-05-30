#!/bin/sh
# fact-check.sh — mirror POSIX do fact-check.ps1 (F3 pipeline obrigatorio)
#
# Recebe via stdin (ou --findings-file <path>) o output markdown do reviewer.
# Parse cada finding [SEV: risco|bug], dispara fact-check via cross-claude
# wrapper (Python inline para chamada Anthropic API), classifica CONFIRMADO|INFUNDADO|PARCIAL.
# Findings INFUNDADO sao filtrados do output principal, preservados em audit.
#
# Output: JSON estruturado em stdout.
# Exit codes: 0 = ok, 1 = erro critico
#
# Usage:
#   cat findings.md | bash fact-check.sh
#   bash fact-check.sh --findings-file findings.md
#   bash fact-check.sh --no-fact-check    # opt-out pra reviews triviais

set -u

# === Parse args ===
FINDINGS_FILE=""
NO_FACT_CHECK=0
WRAPPER=""

while [ $# -gt 0 ]; do
    case "$1" in
        --findings-file)
            FINDINGS_FILE="$2"
            shift 2
            ;;
        --no-fact-check)
            NO_FACT_CHECK=1
            shift
            ;;
        --wrapper)
            WRAPPER="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# === Resolve wrapper (cross-claude.ps1 nao disponivel em sh — usa python inline) ===
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
PROVIDERS_DIR="$(dirname "$SCRIPT_DIR")/providers"

# Load .env se existir (best-effort)
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "./.env" 2>/dev/null || true
    set +a
fi

# === Read input ===
if [ -n "$FINDINGS_FILE" ] && [ -f "$FINDINGS_FILE" ]; then
    FINDINGS_RAW=$(cat "$FINDINGS_FILE")
else
    FINDINGS_RAW=$(cat)
fi

# === Output helpers (JSON sem dependencia de jq) ===
json_escape() {
    # Escapa string pra JSON: backslash, quotes, newlines
    printf '%s' "$1" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
        || printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/; $s/\\n//')"
}

# === Vazio ===
if [ -z "$(printf '%s' "$FINDINGS_RAW" | tr -d '[:space:]')" ]; then
    printf '{"findings_total":0,"findings_confirmed":0,"findings_infundado":0,"findings_parcial":0,"findings_unverified":0,"filtered_output":"","audit":[]}\n'
    exit 0
fi

# === Opt-out ===
if [ "$NO_FACT_CHECK" = "1" ]; then
    ESCAPED=$(json_escape "$FINDINGS_RAW")
    printf '{"findings_total":-1,"filtered_output":%s,"audit":[],"skipped":true,"skip_reason":"NoFactCheck flag ativo"}\n' "$ESCAPED"
    exit 0
fi

# === Quick skip: sem findings criticos ===
if printf '%s' "$FINDINGS_RAW" | grep -qi "Sem findings cr[ií]ticos"; then
    ESCAPED=$(json_escape "$FINDINGS_RAW")
    printf '{"findings_total":0,"findings_confirmed":0,"findings_infundado":0,"findings_parcial":0,"findings_unverified":0,"filtered_output":%s,"audit":[],"skipped":true,"skip_reason":"Sem findings criticos detectado no input"}\n' "$ESCAPED"
    exit 0
fi

# === Parse e fact-check via Python inline ===
# Python 3 disponivel na maioria dos ambientes Linux/macOS Percus
python3 - "$FINDINGS_RAW" "$ANTHROPIC_API_KEY" <<'PYEOF'
import sys
import re
import json
import os
import urllib.request
import urllib.error

findings_raw = sys.argv[1] if len(sys.argv) > 1 else ""
api_key = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("ANTHROPIC_API_KEY", "")

# Parse findings [SEV: risco|bug]
# v6.14.0: bloco vai ate o proximo [SEV: risco|bug] ou fim (\Z), com .*? sob
# re.DOTALL — nao trunca em '[' interno (ex: refs a [R7]). Paridade com fact-check.ps1.
pattern = r'(\[SEV:\s*(risco|bug)\].*?)(?=\[SEV:\s*(?:risco|bug)\]|\Z)'
raw_matches = re.findall(pattern, findings_raw, re.DOTALL)

findings = []
for block, sev in raw_matches:
    block = block.strip()
    # Extrair file_path
    file_path = ""
    fp_match = re.search(r'(?:^|\s|`|")([A-Za-z0-9_./-]+\.[A-Za-z]{1,5}(?::\d+(?:-\d+)?)?)', block)
    if fp_match:
        file_path = fp_match.group(1).strip('`"')
    findings.append({
        "severity": sev.strip(),
        "file_path": file_path,
        "description": block,
        "fact_check": "unverified",
        "reason": ""
    })

if not findings:
    result = {
        "findings_total": 0,
        "findings_confirmed": 0,
        "findings_infundado": 0,
        "findings_parcial": 0,
        "findings_unverified": 0,
        "filtered_output": findings_raw,
        "audit": []
    }
    print(json.dumps(result))
    sys.exit(0)

# Fact-check via Anthropic API (se key disponivel)
system_prompt = (
    "Voce e fact-checker tecnico de codigo. Sua tarefa: validar se um claim tecnico sobre codigo e factualmente correto.\n"
    "Voce vai receber o texto do finding com o claim e o path do arquivo citado (se houver).\n\n"
    "Sua resposta DEVE comecar com exatamente UMA das seguintes palavras na primeira linha:\n"
    "- CONFIRMADO  (claim e factualmente correto)\n"
    "- INFUNDADO: <razao em 1 frase>  (claim e errado)\n"
    "- PARCIAL: <caveat em 1 frase>  (claim tem fundamento mas com nuance)\n\n"
    "Se nao consegue verificar, responda:\n"
    "INFUNDADO: nao foi possivel verificar (sem path verificavel ou arquivo ausente)\n\n"
    "Maximo 100 palavras totais."
)

def call_anthropic(user_prompt):
    if not api_key:
        return None, "ANTHROPIC_API_KEY ausente"
    body = json.dumps({
        "model": "claude-sonnet-4-6",
        "max_tokens": 256,
        "temperature": 0.2,
        "system": [{"type": "text", "text": system_prompt, "cache_control": {"type": "ephemeral"}}],
        "messages": [{"role": "user", "content": user_prompt}]
    }).encode("utf-8")
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=body,
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read())
            return data["content"][0]["text"], None
    except urllib.error.HTTPError as e:
        return None, f"HTTP {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}"
    except Exception as e:
        return None, str(e)

for f in findings:
    user_prompt = (
        f"Finding alega:\n{f['description']}\n\n"
        f"Arquivos citados: {f['file_path']}\n\n"
        "Valide o claim. Resposta (comece com CONFIRMADO, INFUNDADO: ou PARCIAL:):"
    )
    content, err = call_anthropic(user_prompt)
    if err:
        f["fact_check"] = "unverified"
        f["reason"] = f"API error: {err}"
        continue
    if not content:
        f["fact_check"] = "unverified"
        f["reason"] = "resposta vazia do API"
        continue
    first_line = content.strip().split("\n")[0].strip()
    if first_line.startswith("CONFIRMADO"):
        f["fact_check"] = "CONFIRMADO"
        rest = re.sub(r'^CONFIRMADO:?\s*', '', first_line).strip()
        f["reason"] = rest
    elif first_line.startswith("INFUNDADO"):
        f["fact_check"] = "INFUNDADO"
        f["reason"] = re.sub(r'^INFUNDADO:?\s*', '', first_line).strip()
    elif first_line.startswith("PARCIAL"):
        f["fact_check"] = "PARCIAL"
        f["reason"] = re.sub(r'^PARCIAL:?\s*', '', first_line).strip()
    else:
        f["fact_check"] = "unverified"
        f["reason"] = f"formato inesperado: {first_line[:100]}"

# Construir filtered_output (remove INFUNDADO)
filtered = findings_raw
for f in findings:
    if f["fact_check"] == "INFUNDADO":
        filtered = filtered.replace(f["description"], "")
# Limpar espacos em branco multiplos
filtered = re.sub(r'\n{3,}', '\n\n', filtered).strip()

# Audit block
audit_lines = [
    "\n\n## Audit (fact-check v6.7.0+)\n",
    "| Severity | File | Verdict | Reason |",
    "|---|---|---|---|"
]
for f in findings:
    verdict = f"**INFUNDADO** (filtrado)" if f["fact_check"] == "INFUNDADO" else f"**{f['fact_check']}**"
    reason = f["reason"] if f["reason"] else "-"
    audit_lines.append(f"| {f['severity']} | {f['file_path']} | {verdict} | {reason} |")
audit_block = "\n".join(audit_lines)

confirmed  = sum(1 for f in findings if f["fact_check"] == "CONFIRMADO")
infundado  = sum(1 for f in findings if f["fact_check"] == "INFUNDADO")
parcial    = sum(1 for f in findings if f["fact_check"] == "PARCIAL")
unverified = sum(1 for f in findings if f["fact_check"] == "unverified")

result = {
    "findings_total":      len(findings),
    "findings_confirmed":  confirmed,
    "findings_infundado":  infundado,
    "findings_parcial":    parcial,
    "findings_unverified": unverified,
    "filtered_output":     filtered + audit_block,
    "audit":               findings
}
print(json.dumps(result))
PYEOF
