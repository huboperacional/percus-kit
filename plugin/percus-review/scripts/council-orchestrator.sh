#!/usr/bin/env bash
# Council orchestrator (Unix) - roda DeepSeek + Llama em paralelo via background jobs.
# Cross-Claude (subagent Sonnet): emite marker em stderr OU le --cross-claude-file.
#
# F2 — Code Context Injection: --code-context-dir ou blocks ```file:path``` no prompt
# injetam codigo no system prompt. Providers devem validar claims (anti-alucinacao).

set -eo pipefail

PROMPT_FILE=""
SYSTEM_PROMPT=""
PROVIDERS="deepseek,groq-llama"
CROSS_CLAUDE_FILE=""
MODE="consult"
MAX_INPUT_TOKENS=8000
DEEPSEEK_MODEL="deepseek-chat"
GROQ_MODEL="llama-3.3-70b-versatile"
CROSS_CLAUDE_MODEL=""
# F2 params
CODE_CONTEXT_DIR=""
MAX_TOKENS_PER_FILE=2000

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt-file) PROMPT_FILE="$2"; shift 2;;
        --system-prompt) SYSTEM_PROMPT="$2"; shift 2;;
        --providers) PROVIDERS="$2"; shift 2;;
        --cross-claude-file) CROSS_CLAUDE_FILE="$2"; shift 2;;
        --mode) MODE="$2"; shift 2;;
        --max-input-tokens) MAX_INPUT_TOKENS="$2"; shift 2;;
        --deepseek-model) DEEPSEEK_MODEL="$2"; shift 2;;
        --groq-model) GROQ_MODEL="$2"; shift 2;;
        --cross-claude-model) CROSS_CLAUDE_MODEL="$2"; shift 2;;
        --code-context-dir) CODE_CONTEXT_DIR="$2"; shift 2;;
        --max-tokens-per-file) MAX_TOKENS_PER_FILE="$2"; shift 2;;
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

# ---------------------------------------------------------------------------
# F2 — truncate_file_content: trunca conteudo de arquivo a max_tok tokens (chars/3)
# Sets global: TRUNC_FILE_TEXT (string), FILE_WAS_TRUNCATED (true/false)
# ---------------------------------------------------------------------------
truncate_file_content() {
    local text="$1"; local max_tok="$2"
    local tok; tok=$(estimate_tokens "$text")
    if [ "$tok" -le "$max_tok" ]; then
        FILE_WAS_TRUNCATED=false
        TRUNC_FILE_TEXT="$text"
        return
    fi
    local max_chars=$(( max_tok * 3 ))
    TRUNC_FILE_TEXT="${text:0:$max_chars}"$'\n'"[...TRUNCATED to ~${max_tok} tokens...]"
    FILE_WAS_TRUNCATED=true
}

# ---------------------------------------------------------------------------
# F2 — get_premise_validity: extrai premise_validity das primeiras 10 linhas do content
# Outputs: "ok", "invalid", "unverified", ou "" (ausente)
# ---------------------------------------------------------------------------
get_premise_validity() {
    local content="$1"
    echo "$content" | head -10 | grep -ioE 'premise_validity\s*:\s*(ok|invalid|unverified)' | \
        grep -ioE '(ok|invalid|unverified)$' | head -1 | tr '[:upper:]' '[:lower:]'
}

# ---------------------------------------------------------------------------
# F2 — build_code_context_block: le arquivos e monta bloco de contexto
# Sets global: CODE_CONTEXT_BLOCK (string), CODE_CONTEXT_FILES (array), HAS_CODE_CONTEXT (0/1)
# ---------------------------------------------------------------------------
build_code_context_block() {
    CODE_CONTEXT_BLOCK=""
    CODE_CONTEXT_FILES=()
    HAS_CODE_CONTEXT=0
    local max_files=8
    local file_count=0

    if [[ -n "$CODE_CONTEXT_DIR" && -d "$CODE_CONTEXT_DIR" ]]; then
        # Caminho A: pasta curada
        while IFS= read -r -d '' fpath; do
            if [ "$file_count" -ge "$max_files" ]; then
                echo "[council-orchestrator][F2] AVISO: CodeContextDir tem mais de $max_files arquivos; usando primeiros $max_files." >&2
                break
            fi
            local fname; fname=$(basename "$fpath")
            local raw; raw=$(cat "$fpath" 2>/dev/null || true)
            truncate_file_content "$raw" "$MAX_TOKENS_PER_FILE"
            if [ "$FILE_WAS_TRUNCATED" = "true" ]; then
                echo "[council-orchestrator][F2] AVISO: arquivo '$fname' truncado a ~$MAX_TOKENS_PER_FILE tokens." >&2
            fi
            CODE_CONTEXT_BLOCK+="$fname"$'\n'"---"$'\n'"$TRUNC_FILE_TEXT"$'\n\n'
            CODE_CONTEXT_FILES+=("$fname")
            (( file_count++ )) || true
        done < <(find "$CODE_CONTEXT_DIR" \( -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" \
            -o -name "*.go" -o -name "*.rs" -o -name "*.ps1" -o -name "*.sh" -o -name "*.md" \) \
            -maxdepth 1 -type f -print0 2>/dev/null)
    else
        # Caminho B: parse ```file:path``` blocks no prompt
        local found_paths
        found_paths=$(echo "$USER_PROMPT" | grep -oP '(?<=```file:)[^\s`]+' 2>/dev/null || true)
        while IFS= read -r fpath; do
            [[ -z "$fpath" ]] && continue
            if [ "$file_count" -ge "$max_files" ]; then
                echo "[council-orchestrator][F2] AVISO: limite de $max_files arquivos via file_block atingido." >&2
                break
            fi
            # Resolver path
            local resolved
            if [[ "$fpath" = /* ]]; then
                resolved="$fpath"
            else
                resolved="$(pwd)/$fpath"
            fi
            if [[ ! -f "$resolved" ]]; then
                echo "[council-orchestrator][F2] AVISO: arquivo referenciado no prompt nao encontrado: $resolved" >&2
                continue
            fi
            local fname; fname=$(basename "$fpath")
            local raw; raw=$(cat "$resolved" 2>/dev/null || true)
            truncate_file_content "$raw" "$MAX_TOKENS_PER_FILE"
            if [ "$FILE_WAS_TRUNCATED" = "true" ]; then
                echo "[council-orchestrator][F2] AVISO: arquivo '$fname' truncado a ~$MAX_TOKENS_PER_FILE tokens." >&2
            fi
            CODE_CONTEXT_BLOCK+="$fpath"$'\n'"---"$'\n'"$TRUNC_FILE_TEXT"$'\n\n'
            CODE_CONTEXT_FILES+=("$fpath")
            (( file_count++ )) || true
        done <<< "$found_paths"
    fi

    if [ "${#CODE_CONTEXT_FILES[@]}" -gt 0 ]; then
        HAS_CODE_CONTEXT=1
        echo "[council-orchestrator][F2] ${#CODE_CONTEXT_FILES[@]} arquivo(s) de codigo injetados no system prompt." >&2
    fi
}

# ---------------------------------------------------------------------------
# F2 — build_enriched_system_prompt: prefixa system prompt com contexto + instrucao
# Sets global: ENRICHED_SYSTEM_PROMPT
# ---------------------------------------------------------------------------
build_enriched_system_prompt() {
    if [ "$HAS_CODE_CONTEXT" -eq 0 ]; then
        ENRICHED_SYSTEM_PROMPT="$SYSTEM_PROMPT"
        return
    fi
    ENRICHED_SYSTEM_PROMPT=$(cat <<ENRICHED
=== CONTEXTO DE CODIGO (referenciado no prompt) ===

${CODE_CONTEXT_BLOCK}
=== INSTRUCAO ANTI-ALUCINACAO ===

Voce esta consultando sobre uma decisao. O prompt do operador inclui claims
tecnicos sobre o codigo acima. ANTES de opinar, VALIDE se claims refletem
o codigo real apresentado. Se algum claim e factualmente errado, reporte como
INVALIDA_PREMISSA em vez de opinar sobre a alternativa.

=== TIPOS DE RESPOSTA OBRIGATORIOS ===

Comece sua resposta com UMA das tags:
- \`premise_validity: ok\` -- claims do prompt sao consistentes com codigo
- \`premise_validity: invalid\` -- pelo menos 1 claim e factualmente errado (cite qual)
- \`premise_validity: unverified\` -- nao consegui ler/validar (lib externa, ambiguous)

Apos a tag, sua opiniao normal segue.

=== INSTRUCAO ORIGINAL ===

${SYSTEM_PROMPT}
ENRICHED
)
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

# F.2 Automatic router: choose Cross-Claude model by mode (unless overridden)
if [[ -z "$CROSS_CLAUDE_MODEL" ]]; then
    case "$MODE" in
        consult)    CROSS_CLAUDE_MODEL="claude-haiku-4-5";;
        review)     CROSS_CLAUDE_MODEL="claude-sonnet-4-6";;
        pre-mortem) CROSS_CLAUDE_MODEL="claude-opus-4-7";;
        *)          CROSS_CLAUDE_MODEL="claude-sonnet-4-6";;
    esac
fi

IFS=',' read -ra WANTED <<< "$PROVIDERS"

# Load .env (best-effort, antes de checar ANTHROPIC_API_KEY pra direct cross-claude)
if [[ -z "$ANTHROPIC_API_KEY" && -f ".env" ]]; then
    set -a; source .env 2>/dev/null || true; set +a
fi

# Detect if direct wrapper can be used for cross-claude (avoids marker, enables cache_control)
CROSS_CLAUDE_WRAPPER="$PROVIDERS_DIR/cross-claude.sh"
USE_DIRECT_CLAUDE=0
for p in "${WANTED[@]}"; do
    p=$(echo "$p" | xargs)
    if [[ "$p" == "cross-claude" && -f "$CROSS_CLAUDE_WRAPPER" && -n "$ANTHROPIC_API_KEY" && -z "$CROSS_CLAUDE_FILE" ]]; then
        USE_DIRECT_CLAUDE=1
    fi
done

# Separate cross-claude (handled differently unless direct wrapper available)
ASYNC_PROVIDERS=()
WANTS_CROSS_CLAUDE=0
for p in "${WANTED[@]}"; do
    p=$(echo "$p" | xargs)
    if [[ "$p" == "cross-claude" ]]; then
        if [[ $USE_DIRECT_CLAUDE -eq 1 ]]; then
            ASYNC_PROVIDERS+=("$p")  # inclui cross-claude no dispatch normal
            WANTS_CROSS_CLAUDE=0    # NAO emitir marker
        else
            WANTS_CROSS_CLAUDE=1
        fi
    else
        ASYNC_PROVIDERS+=("$p")
    fi
done

# F2 — Load code context (Caminho A precede Caminho B)
build_code_context_block
build_enriched_system_prompt
SYSTEM_PROMPT="$ENRICHED_SYSTEM_PROMPT"

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
    MODEL_ARG=""
    case "$p" in
        deepseek)     MODEL_ARG="$DEEPSEEK_MODEL";;
        groq-llama)   MODEL_ARG="$GROQ_MODEL";;
        cross-claude) MODEL_ARG="$CROSS_CLAUDE_MODEL";;
    esac
    (
        # F.1 fix v6.6.1: pra cross-claude, passar --mode pra carregar system-prompt-{mode}.md
        # (enriquecido com R1-R19, ativa cache Anthropic). NAO passar --system-prompt
        # senao wrapper detecta override e pula o file load.
        if [[ "$WRAPPER" == *cross-claude* ]]; then
            if [[ -n "$MODEL_ARG" ]]; then
                bash "$WRAPPER" --prompt-file "$TMP_PROMPT" --mode "$MODE" --model "$MODEL_ARG" > "$OUT" 2>&1
            else
                bash "$WRAPPER" --prompt-file "$TMP_PROMPT" --mode "$MODE" > "$OUT" 2>&1
            fi
        else
            if [[ -n "$MODEL_ARG" ]]; then
                bash "$WRAPPER" --prompt-file "$TMP_PROMPT" --system-prompt "$SYSTEM_PROMPT" --model "$MODEL_ARG" > "$OUT" 2>&1
            else
                bash "$WRAPPER" --prompt-file "$TMP_PROMPT" --system-prompt "$SYSTEM_PROMPT" > "$OUT" 2>&1
            fi
        fi
    ) &
done

# Cross-claude
CROSS_CLAUDE_JSON=""
if [[ $WANTS_CROSS_CLAUDE -eq 1 ]]; then
    if [[ -n "$CROSS_CLAUDE_FILE" && -f "$CROSS_CLAUDE_FILE" ]]; then
        CC_CONTENT=$(cat "$CROSS_CLAUDE_FILE")
        CROSS_CLAUDE_JSON=$(jq -n --arg c "$CC_CONTENT" --arg m "$CROSS_CLAUDE_MODEL" '{provider:"cross-claude", model:$m, status:"ok", content:$c, latency_ms:0}')
    else
        echo "__PERCUS_NEEDS_CROSS_CLAUDE__" >&2
        echo "[council-orchestrator] dispatch Cross-Claude subagent com prompt:" >&2
        echo "---MODEL-HINT---" >&2
        echo "${CROSS_CLAUDE_MODEL}" >&2
        echo "---END-MODEL-HINT---" >&2
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
        # F2: parse premise_validity quando code context presente
        if [ "$HAS_CODE_CONTEXT" -eq 1 ]; then
            PCONTENT=$(echo "$CONTENT" | jq -r '.content // ""')
            PV=$(get_premise_validity "$PCONTENT")
            CONTENT=$(echo "$CONTENT" | jq --arg pv "$PV" '. + {premise_validity: $pv}')
        fi
        RESPONSES_JSON=$(echo "$RESPONSES_JSON" | jq --argjson r "$CONTENT" '. + [$r]')
    else
        ERR=$(jq -n --arg p "$p" --arg c "$CONTENT" '{provider:$p, status:"error", error:$c, latency_ms:0, premise_validity:""}')
        RESPONSES_JSON=$(echo "$RESPONSES_JSON" | jq --argjson r "$ERR" '. + [$r]')
    fi
    rm -f "$OUT"
done

if [[ -n "$CROSS_CLAUDE_JSON" ]]; then
    # F2: parse premise_validity para cross-claude
    if [ "$HAS_CODE_CONTEXT" -eq 1 ]; then
        CC_CONTENT_TEXT=$(echo "$CROSS_CLAUDE_JSON" | jq -r '.content // ""')
        CC_PV=$(get_premise_validity "$CC_CONTENT_TEXT")
        CROSS_CLAUDE_JSON=$(echo "$CROSS_CLAUDE_JSON" | jq --arg pv "$CC_PV" '. + {premise_validity: $pv}')
    fi
    RESPONSES_JSON=$(echo "$RESPONSES_JSON" | jq --argjson r "$CROSS_CLAUDE_JSON" '. + [$r]')
fi

rm -f "$TMP_PROMPT"

END_MS=$(date +%s%3N)
TOTAL_LATENCY=$((END_MS - START_MS))

# F2 — compute premise_validity_consensus
PREMISE_CONSENSUS=""
if [ "$HAS_CODE_CONTEXT" -eq 1 ]; then
    HAS_INVALID=$(echo "$RESPONSES_JSON" | jq '[.[] | select(.premise_validity == "invalid")] | length')
    HAS_UNVERIF=$(echo "$RESPONSES_JSON" | jq '[.[] | select(.premise_validity == "unverified")] | length')
    HAS_OK=$(echo "$RESPONSES_JSON"      | jq '[.[] | select(.premise_validity == "ok")] | length')
    if [ "$HAS_INVALID" -gt 0 ]; then
        PREMISE_CONSENSUS="invalid"
    elif [ "$HAS_UNVERIF" -gt 0 ]; then
        PREMISE_CONSENSUS="unverified"
    elif [ "$HAS_OK" -gt 0 ]; then
        PREMISE_CONSENSUS="ok"
    else
        PREMISE_CONSENSUS="unverified"
    fi
fi

# Vetor D (v6.14.0) — Llama tie-breaker: exatamente 2 OK, sem groq-llama entre eles,
# premise_validity divergente (>=1 nao-vazio). Bloco NAO-FATAL (set +e local): nunca
# aborta o output principal mesmo se jq/wrapper falhar. NOTA: nao testado neste host
# (sem jq local) — validar em Unix antes de confiar.
TIE_BREAKER_INVOKED=false
TIE_BREAKER_JSON="null"
set +e
{
    OK_COUNT=$(echo "$RESPONSES_JSON" | jq '[.[] | select(.status=="ok")] | length' 2>/dev/null || echo 0)
    LLAMA_IN_OK=$(echo "$RESPONSES_JSON" | jq '[.[] | select(.status=="ok" and .provider=="groq-llama")] | length' 2>/dev/null || echo 0)
    PV_DISTINCT=$(echo "$RESPONSES_JSON" | jq '[.[] | select(.status=="ok") | (.premise_validity // "")] | unique | length' 2>/dev/null || echo 0)
    PV_NONEMPTY=$(echo "$RESPONSES_JSON" | jq '[.[] | select(.status=="ok") | (.premise_validity // "") | select(. != "")] | length' 2>/dev/null || echo 0)
    if [ "${OK_COUNT:-0}" -eq 2 ] && [ "${LLAMA_IN_OK:-0}" -eq 0 ] && [ "${PV_DISTINCT:-0}" -ge 2 ] && [ "${PV_NONEMPTY:-0}" -ge 1 ]; then
        TB_WRAPPER="$PROVIDERS_DIR/groq-llama.sh"
        if [ -f "$TB_WRAPPER" ]; then
            OPINIONS=$(echo "$RESPONSES_JSON" | jq -r '[.[] | select(.status=="ok") | "--- \(.provider) (premise_validity=\(.premise_validity // "")) ---\n\(.content)\n"] | join("\n")' 2>/dev/null || echo "")
            TB_SYS="Voce e desempate (tie-breaker) tecnico. Dois consultores divergiram. Leia a pergunta original e as duas opinioes. Diga qual posicao e mais defensavel e por que, em no maximo 80 palavras. Comece com 'TIE-BREAK:'."
            TB_TMP=$(mktemp)
            printf 'Pergunta original:\n%s\n\nOpinioes divergentes:\n%s' "$USER_PROMPT" "$OPINIONS" > "$TB_TMP"
            TB_OUT=$(bash "$TB_WRAPPER" --prompt-file "$TB_TMP" --system-prompt "$TB_SYS" --max-tokens 256 2>/dev/null || echo "")
            rm -f "$TB_TMP"
            if echo "$TB_OUT" | jq -e '.status=="ok"' >/dev/null 2>&1; then
                TB_CONTENT=$(echo "$TB_OUT" | jq -r '.content // ""')
                TIE_BREAKER_INVOKED=true
                TIE_BREAKER_JSON=$(jq -n --arg c "$TB_CONTENT" '{provider:"groq-llama", role:"tie-breaker", content:$c, note:"convergencia 2/3 informal -- tie-breaker fraco; operador decide"}' 2>/dev/null || echo "null")
                echo "[council-orchestrator][Vetor D] tie-breaker Llama invocado (2 OK divergentes, sem groq-llama)." >&2
            fi
        fi
    fi
} || true
set -eo pipefail

# Log
LOG_DIR=".deepseek/council-log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-${MODE}.jsonl"

CROSS_PENDING="false"
if [[ $WANTS_CROSS_CLAUDE -eq 1 && -z "$CROSS_CLAUDE_JSON" ]]; then
    CROSS_PENDING="true"
fi

# Build code_context_files JSON array
CC_FILES_JSON=$(printf '%s\n' "${CODE_CONTEXT_FILES[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo "[]")

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
    --argjson has_ctx "$HAS_CODE_CONTEXT" \
    --argjson cc_files "$CC_FILES_JSON" \
    --arg pv_consensus "$PREMISE_CONSENSUS" \
    --argjson tb_invoked "${TIE_BREAKER_INVOKED:-false}" \
    --argjson tb "${TIE_BREAKER_JSON:-null}" \
    '{mode:$mode, timestamp:$ts, prompt:$prompt, system_prompt:$sys, providers_called:$wanted, responses:$responses, total_latency_ms:$total_lat, cross_claude_pending:$cross_pending, truncated:$truncated, original_token_count:$orig_tok, has_code_context:$has_ctx, code_context_files:$cc_files, premise_validity_consensus:$pv_consensus, tie_breaker_invoked:$tb_invoked, tie_breaker:$tb}')

echo "$RESULT" > "$LOG_FILE"
echo "$RESULT"
