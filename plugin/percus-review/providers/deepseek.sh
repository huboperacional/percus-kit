#!/usr/bin/env bash
# Provider wrapper DeepSeek (deepseek-v4-flash) - single-shot consult
# Uso: echo "prompt" | ./deepseek.sh  OR  ./deepseek.sh --prompt-file path.txt

set -eo pipefail

SYSTEM_PROMPT="Voce e consultor cross-provider Percus. Responda direto, sem floreio. Aponte riscos concretos."
TEMPERATURE="0.2"
MAX_TOKENS="8192"
MODEL="deepseek-v4-flash"
ENDPOINT="https://api.deepseek.com/v1/chat/completions"
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
