#!/usr/bin/env bash
# Provider wrapper Llama 3.3 70B via Groq - single-shot consult
set -eo pipefail

SYSTEM_PROMPT="Voce e consultor cross-provider Percus. Responda direto, sem floreio. Aponte riscos concretos."
TEMPERATURE="0.2"
MAX_TOKENS="2048"
MODEL="llama-3.3-70b-versatile"
ENDPOINT="https://api.groq.com/openai/v1/chat/completions"
PROMPT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt-file) PROMPT_FILE="$2"; shift 2;;
        --system-prompt) SYSTEM_PROMPT="$2"; shift 2;;
        --temperature) TEMPERATURE="$2"; shift 2;;
        --max-tokens) MAX_TOKENS="$2"; shift 2;;
        --model) MODEL="$2"; shift 2;;
        --endpoint) ENDPOINT="$2"; shift 2;;
        *) shift;;
    esac
done

if [[ -z "$GROQ_API_KEY" && -f ".env" ]]; then
    set -a; source .env 2>/dev/null || true; set +a
fi

if [[ -z "$GROQ_API_KEY" ]]; then
    echo "[groq-llama-provider] GROQ_API_KEY ausente. Obter free em https://console.groq.com." >&2
    exit 2
fi

if [[ -n "$PROMPT_FILE" ]]; then
    [[ ! -f "$PROMPT_FILE" ]] && { echo "[groq-llama-provider] PromptFile nao encontrado: $PROMPT_FILE" >&2; exit 1; }
    USER_PROMPT=$(cat "$PROMPT_FILE")
else
    USER_PROMPT=$(cat)
fi

[[ -z "$USER_PROMPT" ]] && { echo "[groq-llama-provider] prompt vazio." >&2; exit 1; }

# Corpo vai pra ARQUIVO, nao pra argv do curl -- mesma classe de bug achada em
# deepseek.sh (ver comentario la, tiatendo 2026-08-05 spec N19): "-d "$BODY"" passa
# JSON longo/multibyte pelo argv do curl.exe nativo via MSYS/Git-Bash e a fronteira
# corrompe o texto. --data-binary @arquivo le bytes direto do disco, sem cruzar argv.
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT
jq -n \
    --arg model "$MODEL" \
    --argjson temp "$TEMPERATURE" \
    --argjson max "$MAX_TOKENS" \
    --arg sys "$SYSTEM_PROMPT" \
    --arg usr "$USER_PROMPT" \
    '{model: $model, temperature: $temp, max_tokens: $max, messages: [{role:"system",content:$sys},{role:"user",content:$usr}]}' > "$BODY_FILE"

START_MS=$(date +%s%3N)
RESP=$(curl -s --max-time 60 -X POST "$ENDPOINT" \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "@$BODY_FILE" || echo "")
END_MS=$(date +%s%3N)
LATENCY=$((END_MS - START_MS))

if [[ -z "$RESP" ]]; then
    jq -n --arg msg "network/empty response" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"groq-llama", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

# API pode devolver erro em texto puro (nao-JSON) -- mesma classe de bug achada em
# deepseek.sh (ver comentario la, tiatendo 2026-08-05 spec N19). Sem este check,
# "jq -e '.error'" falha calado em RESP nao-JSON, o script cai no caminho de sucesso,
# e o parse error do jq seguinte mascara a mensagem real da API.
if ! echo "$RESP" | jq -e . >/dev/null 2>&1; then
    jq -n --arg msg "$RESP" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"groq-llama", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

if echo "$RESP" | jq -e '.error' >/dev/null 2>&1; then
    ERR_MSG=$(echo "$RESP" | jq -r '.error.message // "network/empty response"' 2>/dev/null || echo "network/empty")
    jq -n --arg msg "$ERR_MSG" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"groq-llama", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

CONTENT=$(echo "$RESP" | jq -r '.choices[0].message.content // ""')
USAGE=$(echo "$RESP" | jq '.usage // {}')

jq -n \
    --arg content "$CONTENT" \
    --argjson usage "$USAGE" \
    --argjson lat "$LATENCY" \
    --arg mdl "$MODEL" \
    '{provider:"groq-llama", model:$mdl, status:"ok", content:$content, latency_ms:$lat, usage:$usage}'
