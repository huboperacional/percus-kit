#!/usr/bin/env bash
# Hook PreToolUse:Bash|PowerShell Percus -- gate [S] mecanico. WARN-ONLY: exit 0 sempre.
# Paridade com spec-analyze-check.ps1 (a fonte da logica e o .ps1; leia o cabecalho dele).
# Avisa quando um `git commit` leva uma spec (docs/superpowers/specs/*.md) sem analyze do conselho.
# Escape: PERCUS_SKIP_SPEC_ANALYZE=1. Falha graciosa: qualquer erro -> exit 0.
set +e

# Kill-switch geral do kit, como os outros 8 .sh de PreToolUse fazem (o .cmd checa antes de
# invocar; no Unix o .sh e o entrypoint, entao a checagem tem que morar aqui tambem).
[ "${PERCUS_HOOKS_DISABLED:-}" = "1" ] && exit 0

STDIN=$(cat)
[ -z "$STDIN" ] && exit 0
[ -n "${PERCUS_SKIP_SPEC_ANALYZE:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

COMANDO=$(printf '%s' "$STDIN" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$COMANDO" ] && exit 0
printf '%s' "$COMANDO" | grep -qE '\bgit\b[^|;&]*\bcommit\b' || exit 0

# raiz do projeto: o diretorio do `cd` no comando, senao o cwd
ALVO=$(printf '%s' "$COMANDO" | sed -n 's/.*cd[[:space:]]\{1,\}"\([^"]*\)".*/\1/p' | head -n1)
# Tres formas de `cd`, porque so aspas duplas deixava `cd /repo && git commit` cair no cwd e
# avisar sobre o repo ERRADO (falso negativo silencioso) -- o .ps1 ja cobria as tres via
# Resolve-PercusProjectRoot, entao a paridade estava quebrada onde ninguem olhava.
[ -z "$ALVO" ] && ALVO=$(printf '%s' "$COMANDO" | sed -n "s/.*cd[[:space:]]\{1,\}'\([^']*\)'.*/\1/p" | head -n1)
[ -z "$ALVO" ] && ALVO=$(printf '%s' "$COMANDO" | sed -n 's/.*cd[[:space:]]\{1,\}\([^[:space:]&|;"'"'"']\{1,\}\).*/\1/p' | head -n1)
[ -z "$ALVO" ] && ALVO=$(pwd)
RAIZ=$(git -C "$ALVO" rev-parse --show-toplevel 2>/dev/null)
[ -z "$RAIZ" ] && exit 0

SPECS=$(git -C "$RAIZ" diff --cached --name-only 2>/dev/null | grep -E '(^|/)docs/superpowers/specs/[^/]+\.md$')
[ -z "$SPECS" ] && exit 0

LOGDIR="$RAIZ/.deepseek/council-log"
# normaliza: CRLF->LF, colapsa espacos, apara pontas -- diferenca de quebra de linha nao e
# diferenca de conteudo (paridade com Get-SpecAssinatura do .ps1)
normalizar() { tr -d '\r' | sed 's/[[:space:]]\{1,\}/ /g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
titulo_de() { grep -m1 -E '^[[:space:]]*#[[:space:]]+[^[:space:]]' | normalizar; }

SEM=""
DESAT=""
while IFS= read -r spec; do
    [ -z "$spec" ] && continue
    TEXTO=$(git -C "$RAIZ" show ":$spec" 2>/dev/null)
    [ -z "$TEXTO" ] && continue
    ALVO_NORM=$(printf '%s' "$TEXTO" | normalizar)
    ALVO_TIT=$(printf '%s' "$TEXTO" | titulo_de)
    COBERTA=0
    VIU_TITULO=0
    if [ -d "$LOGDIR" ]; then
        # teto de 50, do mais recente pro mais antigo: a pasta cresce por sessao
        for log in $(ls -t "$LOGDIR"/*-analyze.jsonl 2>/dev/null | head -n 50); do
            # LINHA A LINHA, nao o arquivo inteiro: .jsonl promete um objeto por linha, e
            # `jq -r .prompt arquivo` com dois objetos emite os DOIS prompts colados por \n --
            # que o normalizar transforma em espaco e nunca casa. Seria falso negativo silencioso
            # (dizer "nenhum analyze" em spec ANALISADA) exatamente no caso que o .ps1 foi
            # corrigido para evitar. Achado do R11, 2026-09-12.
            # `|| [ -n "$objeto" ]`: sem isso, arquivo que NAO termina em newline perde a ultima
            # linha -- e o log de uma rodada so e exatamente isso. O .ps1 (ReadAllLines) nao tem
            # esse buraco, entao a paridade quebraria no caso mais comum. Pego por teste, 2026-09-12.
            while IFS= read -r objeto || [ -n "$objeto" ]; do
                [ -z "$objeto" ] && continue
                PROMPT=$(printf '%s' "$objeto" | jq -r '.prompt // ""' 2>/dev/null)
                [ -z "$PROMPT" ] && continue
                P_NORM=$(printf '%s' "$PROMPT" | normalizar)
                if [ "$P_NORM" = "$ALVO_NORM" ]; then COBERTA=1; break; fi
                P_TIT=$(printf '%s' "$PROMPT" | titulo_de)
                if [ -n "$ALVO_TIT" ] && [ "$P_TIT" = "$ALVO_TIT" ]; then VIU_TITULO=1; fi
            done < "$log"
            [ "$COBERTA" -eq 1 ] && break
        done
    fi
    if [ "$COBERTA" -eq 1 ]; then continue; fi
    if [ "$VIU_TITULO" -eq 1 ]; then
        DESAT="${DESAT}${spec}
"
    else
        SEM="${SEM}${spec}
"
    fi
done <<< "$SPECS"

if [ -z "$SEM" ] && [ -z "$DESAT" ]; then exit 0; fi

echo "[percus:hook spec-analyze] AVISO (nao bloqueia): spec indo pro commit sem analyze do conselho." >&2
printf '%s' "$SEM"   | while IFS= read -r s; do [ -n "$s" ] && echo "  - $s -- nenhum analyze encontrado em .deepseek/council-log/" >&2; done
printf '%s' "$DESAT" | while IFS= read -r s; do [ -n "$s" ] && echo "  - $s -- ha analyze desta spec, mas o texto mudou desde entao (versao anterior)" >&2; done
echo "O canon manda rodar sozinho, sem pedir permissao (01_REGRAS_INEGOCIAVEIS.md R9, v2/loops/spec.md):" >&2
echo "  skill percus-review:spec-analyze  --  ou council-orchestrator.sh --mode analyze --providers 'deepseek,groq-llama,cross-claude'" >&2
echo "Veredito AJUSTAR/BLOQUEADA: corrija antes de a feature virar [0]. Escape: PERCUS_SKIP_SPEC_ANALYZE=1" >&2
exit 0
