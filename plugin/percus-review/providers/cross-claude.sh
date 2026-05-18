#!/usr/bin/env bash
# Provider wrapper: Cross-Claude (Anthropic API direto, com prompt cache ephemeral).
# Substitui marker-based dispatch quando ANTHROPIC_API_KEY presente.
# Aplica cache_control:ephemeral no system block (TTL 5min Anthropic).
# Retorna JSON em stdout: {provider, model, status, content, latency_ms, usage}.
# Exit 0 = ok, 1 = network/auth fail, 2 = key ausente.

set -eo pipefail

SYSTEM_PROMPT=""
SYSTEM_PROMPT_EXPLICIT=0
TEMPERATURE="0.2"
MAX_TOKENS="1024"
MODEL="claude-sonnet-4-6"
ENDPOINT="https://api.anthropic.com/v1/messages"
PROMPT_FILE=""
MODE="consult"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt-file)    PROMPT_FILE="$2"; shift 2;;
        --system-prompt)  SYSTEM_PROMPT="$2"; SYSTEM_PROMPT_EXPLICIT=1; shift 2;;
        --temperature)    TEMPERATURE="$2"; shift 2;;
        --max-tokens)     MAX_TOKENS="$2"; shift 2;;
        --model)          MODEL="$2"; shift 2;;
        --endpoint)       ENDPOINT="$2"; shift 2;;
        --mode)           MODE="$2"; shift 2;;
        *) shift;;
    esac
done

# Load .env (best-effort)
if [[ -z "$ANTHROPIC_API_KEY" && -f ".env" ]]; then
    set -a; source .env 2>/dev/null || true; set +a
fi

if [[ -z "$ANTHROPIC_API_KEY" ]]; then
    echo "[cross-claude-provider] ANTHROPIC_API_KEY ausente no .env ou env vars." >&2
    exit 2
fi

# Resolve SystemPrompt: --system-prompt explícito vence; senão carrega system-prompt-{mode}.md;
# fallback: default inline curto (mantém retrocompat se arquivo faltar).
if [[ "$SYSTEM_PROMPT_EXPLICIT" -eq 0 || -z "$SYSTEM_PROMPT" ]]; then
    MODE_FILE="$MODE"
    [[ "$MODE" == "pre-mortem" ]] && MODE_FILE="consult"
    # BASE_DIR resolve diretório do script (handle symlinks)
    BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROMPT_PATH="$BASE_DIR/system-prompt-${MODE_FILE}.md"
    if [[ -f "$PROMPT_PATH" ]]; then
        # Strip YAML frontmatter via awk
        SYSTEM_PROMPT=$(awk 'BEGIN{found_first=0; in_yaml=0; printed=0}
            /^---$/ {
                if (found_first==0) { found_first=1; in_yaml=1; next }
                if (in_yaml==1) { in_yaml=0; printed=1; next }
            }
            in_yaml==0 && printed==1 { print }
            in_yaml==0 && found_first==0 { print }
        ' "$PROMPT_PATH")
    else
        SYSTEM_PROMPT="Voce e consultor cross-provider Percus. Responda direto, sem floreio. Aponte riscos concretos."
    fi
fi

if [[ -n "$PROMPT_FILE" ]]; then
    [[ ! -f "$PROMPT_FILE" ]] && { echo "[cross-claude-provider] PromptFile nao encontrado: $PROMPT_FILE" >&2; exit 1; }
    USER_PROMPT=$(cat "$PROMPT_FILE")
else
    USER_PROMPT=$(cat)
fi

[[ -z "$USER_PROMPT" ]] && { echo "[cross-claude-provider] prompt vazio." >&2; exit 1; }

# IMPORTANTE: system deve ser array de blocks com cache_control — NAO string simples.
# Anthropic API rejeita cache_control se system for string.
BODY=$(jq -n \
    --arg model "$MODEL" \
    --argjson temp "$TEMPERATURE" \
    --argjson max "$MAX_TOKENS" \
    --arg sys "$SYSTEM_PROMPT" \
    --arg usr "$USER_PROMPT" \
    '{
        model: $model,
        max_tokens: $max,
        temperature: $temp,
        system: [
            {
                type: "text",
                text: $sys,
                cache_control: { type: "ephemeral" }
            }
        ],
        messages: [
            { role: "user", content: $usr }
        ]
    }')

START_MS=$(date +%s%3N)
RESP=$(curl -s --max-time 60 -X POST "$ENDPOINT" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "Content-Type: application/json" \
    -d "$BODY" || echo "")
END_MS=$(date +%s%3N)
LATENCY=$((END_MS - START_MS))

if [[ -z "$RESP" ]] || echo "$RESP" | jq -e '.error' >/dev/null 2>&1; then
    ERR_MSG=$(echo "$RESP" | jq -r '.error.message // "network/empty response"' 2>/dev/null || echo "network/empty")
    jq -n --arg msg "$ERR_MSG" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"cross-claude", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

CONTENT=$(echo "$RESP" | jq -r '.content[0].text // ""')
ACTUAL_MODEL=$(echo "$RESP" | jq -r '.model // ""')
INPUT_TOKENS=$(echo "$RESP" | jq -r '.usage.input_tokens // 0')
OUTPUT_TOKENS=$(echo "$RESP" | jq -r '.usage.output_tokens // 0')
CACHE_CREATION=$(echo "$RESP" | jq -r '.usage.cache_creation_input_tokens // 0')
CACHE_READ=$(echo "$RESP" | jq -r '.usage.cache_read_input_tokens // 0')

jq -n \
    --arg content "$CONTENT" \
    --arg model "$ACTUAL_MODEL" \
    --argjson lat "$LATENCY" \
    --argjson prompt_tok "$INPUT_TOKENS" \
    --argjson completion_tok "$OUTPUT_TOKENS" \
    --argjson cache_create "$CACHE_CREATION" \
    --argjson cache_read "$CACHE_READ" \
    '{
        provider: "cross-claude",
        model: $model,
        status: "ok",
        content: $content,
        latency_ms: $lat,
        usage: {
            prompt_tokens: $prompt_tok,
            completion_tokens: $completion_tok,
            cache_creation_input_tokens: $cache_create,
            cache_read_input_tokens: $cache_read
        }
    }'
