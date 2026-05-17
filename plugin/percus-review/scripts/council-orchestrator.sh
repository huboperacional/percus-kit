#!/usr/bin/env bash
# Council orchestrator (Unix) - roda DeepSeek + Llama em paralelo via background jobs.
# Cross-Claude (subagent Sonnet): emite marker em stderr OU le --cross-claude-file.

set -eo pipefail

PROMPT_FILE=""
SYSTEM_PROMPT=""
PROVIDERS="deepseek,groq-llama"
CROSS_CLAUDE_FILE=""
MODE="consult"
MAX_INPUT_TOKENS=8000

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt-file) PROMPT_FILE="$2"; shift 2;;
        --system-prompt) SYSTEM_PROMPT="$2"; shift 2;;
        --providers) PROVIDERS="$2"; shift 2;;
        --cross-claude-file) CROSS_CLAUDE_FILE="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        --max-input-tokens) MAX_INPUT_TOKENS="$2"; shift 2;;
        *) shift;;
    esac
done

estimate_tokens() {
  local text="$1"
  echo $(( (${#text} + 3) / 3 ))
}

# Sets globals: TRUNCATED (true/false), ORIG_TOK (int), TRUNC_TEXT (string)
truncate_prompt() {
  local text="$1"; local max="$2"
  local tok; tok=$(estimate_tokens "$text")
  if [ "$tok" -le "$max" ]; then
    TRUNCATED=false; ORIG_TOK=$tok; TRUNC_TEXT="$text"
    return
  fi
  local head="${text:0:3500}"
  local tail_len=$(( (max - 1000) * 3 ))
  [ "$tail_len" -lt 1000 ] && tail_len=1000
  local tail="${text: -$tail_len}"
  local cut=$(( tok - max ))
  TRUNC_TEXT="${head}

[...TRUNCATED ~${cut} tokens...]

${tail}"
  TRUNCATED=true; ORIG_TOK=$tok
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
PROVIDERS_DIR="$PLUGIN_ROOT/providers"

# Read prompt
if [[ -n "$PROMPT_FILE" ]]; then
    [[ ! -f "$PROMPT_FILE" ]] && { echo "[council-orchestrator] PromptFile nao encontrado: $PROMPT_FILE" >&2; exit 1; }
    USER_PROMPT=$(cat "$PROMPT_FILE")
else
    USER_PROMPT=$(cat)
fi
[[ -z "$USER_PROMPT" ]] && { echo "[council-orchestrator] prompt vazio." >&2; exit 1; }

# Default system prompts per mode
if [[ -z "$SYSTEM_PROMPT" ]]; then
    case "$MODE" in
        consult)    SYSTEM_PROMPT="Voce e consultor cross-provider Percus. Responda em <=150 palavras: 1) sua escolha/posicao, 2) razao principal, 3) maior risco da alternativa. Sem floreio.";;
        pre-mortem) SYSTEM_PROMPT="Voce e consultor de pre-mortem Percus. Leia o plano e responda: SE este plano falhar em 30 dias, por que? Liste exatamente 3 motivos concretos em ordem de probabilidade decrescente, com 1 frase cada.";;
        review)     SYSTEM_PROMPT="Voce e revisor cross-provider Percus (R11). Aponte bugs, regressoes, violacoes R1-R19, mocks escondidos, JWT em localStorage, imports vetados. Se nada relevante: 'Sem findings criticos'.";;
    esac
fi

IFS=',' read -ra WANTED <<< "$PROVIDERS"

# Separate cross-claude
ASYNC_PROVIDERS=()
WANTS_CROSS_CLAUDE=0
for p in "${WANTED[@]}"; do
    p=$(echo "$p" | xargs)
    if [[ "$p" == "cross-claude" ]]; then
        WANTS_CROSS_CLAUDE=1
    else
        ASYNC_PROVIDERS+=("$p")
    fi
done

# F.5 smart truncation conservador
COMBINED_CHECK="${SYSTEM_PROMPT}
${USER_PROMPT}"
truncate_prompt "$COMBINED_CHECK" "$MAX_INPUT_TOKENS"
if [ "$TRUNCATED" = "true" ]; then
    echo "[council-orchestrator] AVISO: prompt truncado de ${ORIG_TOK} -> ~${MAX_INPUT_TOKENS} tokens." >&2
    # Aplicar truncation apenas ao userPrompt; SystemPrompt fica intacto (e curto)
    SYS_TOK=$(estimate_tokens "$SYSTEM_PROMPT")
    USER_MAX=$(( MAX_INPUT_TOKENS - SYS_TOK ))
    truncate_prompt "$USER_PROMPT" "$USER_MAX"
    USER_PROMPT="$TRUNC_TEXT"
fi
# Capture final truncation metadata for output
FINAL_TRUNCATED="$TRUNCATED"
FINAL_ORIG_TOK="$ORIG_TOK"

# Write prompt to temp file
TMP_PROMPT=$(mktemp)
echo -n "$USER_PROMPT" > "$TMP_PROMPT"

# Dispatch async providers as background jobs, collect output to per-provider files
declare -A OUTPUT_FILES
START_MS=$(date +%s%3N)
for p in "${ASYNC_PROVIDERS[@]}"; do
    WRAPPER="$PROVIDERS_DIR/${p}.sh"
    if [[ ! -f "$WRAPPER" ]]; then
        echo "[council-orchestrator] WARN: provider '$p' nao tem wrapper em $WRAPPER, pulando." >&2
        continue
    fi
    OUT=$(mktemp)
    OUTPUT_FILES[$p]="$OUT"
    (
        bash "$WRAPPER" --prompt-file "$TMP_PROMPT" --system-prompt "$SYSTEM_PROMPT" > "$OUT" 2>&1
    ) &
done

# Cross-claude
CROSS_CLAUDE_JSON=""
if [[ $WANTS_CROSS_CLAUDE -eq 1 ]]; then
    if [[ -n "$CROSS_CLAUDE_FILE" && -f "$CROSS_CLAUDE_FILE" ]]; then
        CC_CONTENT=$(cat "$CROSS_CLAUDE_FILE")
        CROSS_CLAUDE_JSON=$(jq -n --arg c "$CC_CONTENT" '{provider:"cross-claude", model:"claude-sonnet-4-6", status:"ok", content:$c, latency_ms:0}')
    else
        echo "__PERCUS_NEEDS_CROSS_CLAUDE__" >&2
        echo "[council-orchestrator] dispatch Sonnet subagent com prompt:" >&2
        echo "---PROMPT---" >&2
        echo "${SYSTEM_PROMPT}" >&2
        echo "" >&2
        echo "${USER_PROMPT}" >&2
        echo "---END-PROMPT---" >&2
        echo "Salve resposta em arquivo e re-invoque orchestrator com --cross-claude-file <path>." >&2
    fi
fi

# Wait all jobs
wait

# Collect responses
RESPONSES_JSON="[]"
for p in "${ASYNC_PROVIDERS[@]}"; do
    OUT="${OUTPUT_FILES[$p]}"
    [[ -z "$OUT" || ! -f "$OUT" ]] && continue
    CONTENT=$(cat "$OUT")
    # Try parse as JSON; if fail, wrap as error
    if echo "$CONTENT" | jq -e . >/dev/null 2>&1; then
        RESPONSES_JSON=$(echo "$RESPONSES_JSON" | jq --argjson r "$CONTENT" '. + [$r]')
    else
        ERR=$(jq -n --arg p "$p" --arg c "$CONTENT" '{provider:$p, status:"error", error:$c, latency_ms:0}')
        RESPONSES_JSON=$(echo "$RESPONSES_JSON" | jq --argjson r "$ERR" '. + [$r]')
    fi
    rm -f "$OUT"
done

if [[ -n "$CROSS_CLAUDE_JSON" ]]; then
    RESPONSES_JSON=$(echo "$RESPONSES_JSON" | jq --argjson r "$CROSS_CLAUDE_JSON" '. + [$r]')
fi

rm -f "$TMP_PROMPT"

END_MS=$(date +%s%3N)
TOTAL_LATENCY=$((END_MS - START_MS))

# Log
LOG_DIR=".deepseek/council-log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-${MODE}.jsonl"

CROSS_PENDING="false"
if [[ $WANTS_CROSS_CLAUDE -eq 1 && -z "$CROSS_CLAUDE_JSON" ]]; then
    CROSS_PENDING="true"
fi

RESULT=$(jq -n \
    --arg mode "$MODE" \
    --arg ts "$(date -Iseconds)" \
    --arg prompt "$USER_PROMPT" \
    --arg sys "$SYSTEM_PROMPT" \
    --argjson wanted "$(printf '%s\n' "${WANTED[@]}" | jq -R . | jq -s .)" \
    --argjson responses "$RESPONSES_JSON" \
    --argjson total_lat "$TOTAL_LATENCY" \
    --argjson cross_pending "$CROSS_PENDING" \
    --argjson truncated "${FINAL_TRUNCATED:-false}" \
    --argjson orig_tok "${FINAL_ORIG_TOK:-0}" \
    '{mode:$mode, timestamp:$ts, prompt:$prompt, system_prompt:$sys, providers_called:$wanted, responses:$responses, total_latency_ms:$total_lat, cross_claude_pending:$cross_pending, truncated:$truncated, original_token_count:$orig_tok}')

echo "$RESULT" > "$LOG_FILE"
echo "$RESULT"
