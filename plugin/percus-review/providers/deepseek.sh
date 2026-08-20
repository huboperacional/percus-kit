#!/usr/bin/env bash
# Provider wrapper DeepSeek (deepseek-v4-flash) - single-shot consult
# Uso: echo "prompt" | ./deepseek.sh  OR  ./deepseek.sh --prompt-file path.txt

set -eo pipefail

SYSTEM_PROMPT="Voce e consultor cross-provider Percus. Responda direto, sem floreio. Aponte riscos concretos."
TEMPERATURE="0.2"
# 16000: o deepseek-v4-flash raciocina e os reasoning_tokens contam DENTRO de completion_tokens.
# Medido 2026-08-16: 6784..8192+ tokens gastos so raciocinando num prompt de review real, ou
# seja, 8192 caia no meio da faixa e a mesma pergunta voltava ok/truncada/vazia na sorte.
# Tem que bater com o default do deepseek.ps1 -- os dois runtimes respondem a mesma pergunta.
MAX_TOKENS="16000"
# reasoning_effort (2026-08-19): conserto da perna que voltava vazia. Subir MAX_TOKENS NAO
# resolve -- ja foi feito (8192 -> 16000) e o sintoma voltou igual, porque o raciocinio se
# expande ate encher o teto que existir. Ver conhecimento/resolver/
# cross-claude-review-queima-16000-e-volta-vazio.md, que PROIBE subir o teto de novo.
# Medido no mesmo prompt real de review (11 KB), teto 16000:
#   sem effort -> 12826 tokens so pensando (80% do teto), 3284 chars de resposta
#   low        ->  2934 tokens so pensando (18% do teto), 5140 chars de resposta
# Gasta 3,1x menos E devolve MAIS texto. Vazio ("") omite o campo e volta ao antigo.
REASONING_EFFORT="${DEEPSEEK_REASONING_EFFORT:-low}"
MODEL="deepseek-v4-flash"
ENDPOINT="https://api.deepseek.com/v1/chat/completions"
PROMPT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt-file) PROMPT_FILE="$2"; shift 2;;
        --system-prompt) SYSTEM_PROMPT="$2"; shift 2;;
        --temperature) TEMPERATURE="$2"; shift 2;;
        --max-tokens) MAX_TOKENS="$2"; shift 2;;
        --reasoning-effort) REASONING_EFFORT="$2"; shift 2;;
        --model) MODEL="$2"; shift 2;;
        --endpoint) ENDPOINT="$2"; shift 2;;
        *) shift;;
    esac
done

# Load .env (best-effort)
if [[ -z "$DEEPSEEK_API_KEY" && -f ".env" ]]; then
    set -a; source .env 2>/dev/null || true; set +a
fi

if [[ -z "$DEEPSEEK_API_KEY" ]]; then
    echo "[deepseek-provider] DEEPSEEK_API_KEY ausente no .env ou env vars." >&2
    exit 2
fi

if [[ -n "$PROMPT_FILE" ]]; then
    [[ ! -f "$PROMPT_FILE" ]] && { echo "[deepseek-provider] PromptFile nao encontrado: $PROMPT_FILE" >&2; exit 1; }
    USER_PROMPT=$(cat "$PROMPT_FILE")
else
    USER_PROMPT=$(cat)
fi

[[ -z "$USER_PROMPT" ]] && { echo "[deepseek-provider] prompt vazio." >&2; exit 1; }

# Corpo vai pra ARQUIVO, nao pra argv do curl. Achado real (tiatendo, 2026-08-05, spec
# N19 modo analyze): "-d "$BODY"" passa o JSON como argumento de linha de comando pro
# curl.exe NATIVO do Windows (build mingw32) atraves da fronteira MSYS/Git-Bash -- essa
# fronteira corrompe UTF-8 longo/multibyte (acentos, travessoes, setas) no meio do
# caminho, e a API rejeita com "invalid unicode code point" mesmo com o prompt original
# perfeito. Confirmado por teste A/B direto: --data-binary @arquivo funciona, -d "$VAR"
# com o MESMO conteudo falha. --data-binary @arquivo le bytes direto do disco, sem
# cruzar a fronteira de argv nenhuma vez.
BODY_FILE=$(mktemp)
# PROMPT vai pra ARQUIVO, nao pro argv do jq. Mesma classe do corpo do curl logo abaixo -- e o
# comentario dela ja estava neste arquivo, so que aplicado ao curl e nao ao jq ao lado. Medido
# 2026-08-19: com prompt de ~8000 tokens o `jq --arg usr` morre com "Argument list too long"
# (exit 126), stdout sai VAZIO, e o orquestrador conta a perna como `error` SEM mensagem.
# Falhava so em prompt grande -- exatamente quando a terceira voz faz mais falta.
SYS_FILE=$(mktemp)
USR_FILE=$(mktemp)
printf '%s' "$SYSTEM_PROMPT" > "$SYS_FILE"
printf '%s' "$USER_PROMPT"   > "$USR_FILE"
# trap DEPOIS das atribuicoes: registrado antes, ele referenciaria $SYS_FILE/$USR_FILE
# ainda vazios, e uma saida precoce chamaria `rm -f ""`.
trap 'rm -f "$BODY_FILE" "$SYS_FILE" "$USR_FILE"' EXIT
jq -n \
    --arg model "$MODEL" \
    --argjson temp "$TEMPERATURE" \
    --argjson max "$MAX_TOKENS" \
    --rawfile sys "$SYS_FILE" \
    --rawfile usr "$USR_FILE" \
    --arg effort "$REASONING_EFFORT" \
    '{model: $model, temperature: $temp, max_tokens: $max, messages: [{role:"system",content:$sys},{role:"user",content:$usr}]}
     + (if $effort == "" then {} else {reasoning_effort: $effort} end)' > "$BODY_FILE"

START_MS=$(date +%s%3N)
# 180s: com teto 16000 e modelo que raciocina, resposta legitima ja levou 80s (medido 2026-08-16).
RESP=$(curl -s --max-time 180 -X POST "$ENDPOINT" \
    -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "@$BODY_FILE" || echo "")
END_MS=$(date +%s%3N)
LATENCY=$((END_MS - START_MS))

if [[ -z "$RESP" ]]; then
    jq -n --arg msg "network/empty response" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"deepseek", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

# A API pode devolver erro em TEXTO PURO (nao-JSON) -- achado real, tiatendo 2026-08-05,
# spec N19: "Failed to parse the request body as JSON: messages[1].content: invalid
# unicode code point at line 12 column 6401" (caractere corrompido no prompt do usuario).
# Sem este check, "jq -e '.error'" abaixo falha CALADO (RESP nao eh JSON), o antigo
# `if` combinado concluia "sem erro" e o script caia no caminho de sucesso -- onde o
# `jq -r '.choices[0]...' mais adiante falhava de novo, e o parse error DESSE segundo
# jq mascarava a mensagem real da API no log (`.deepseek/council-log/`).
if ! echo "$RESP" | jq -e . >/dev/null 2>&1; then
    jq -n --arg msg "$RESP" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"deepseek", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

if echo "$RESP" | jq -e '.error' >/dev/null 2>&1; then
    ERR_MSG=$(echo "$RESP" | jq -r '.error.message // "network/empty response"' 2>/dev/null || echo "network/empty")
    jq -n --arg msg "$ERR_MSG" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"deepseek", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

CONTENT=$(echo "$RESP" | jq -r '.choices[0].message.content // ""')
USAGE=$(echo "$RESP" | jq '.usage // {}')

jq -n \
    --arg content "$CONTENT" \
    --argjson usage "$USAGE" \
    --argjson lat "$LATENCY" \
    --arg mdl "$MODEL" \
    '{provider:"deepseek", model:$mdl, status:"ok", content:$content, latency_ms:$lat, usage:$usage}'
