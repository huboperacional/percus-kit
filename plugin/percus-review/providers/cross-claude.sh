#!/usr/bin/env bash
# Provider wrapper: Cross-Claude (Anthropic API direto, com prompt cache ephemeral).
# Substitui marker-based dispatch quando ANTHROPIC_API_KEY presente.
# Aplica cache_control:ephemeral no system block (TTL 5min Anthropic).
# Retorna JSON em stdout: {provider, model, status, content, latency_ms, usage}.
# Exit 0 = ok, 1 = network/auth fail, 2 = key ausente.

set -eo pipefail

SYSTEM_PROMPT=""
SYSTEM_PROMPT_EXPLICIT=0
# NAO existe TEMPERATURE aqui: a familia Opus 4.7+ / Sonnet 5 / Fable 5 removeu os sampling
# params e devolve HTTP 400 se receber um. Medido 2026-08-16: este arquivo ainda mandava
# temperature depois que a 6.36.2 subiu o modelo pra Sonnet 5, e a perna bash do conselho
# ficou 100% muda -- toda chamada, nao de vez em quando. Steering vai por prompt, nao por
# sampling. A mesma correcao ja tinha sido feita no cross-claude.ps1 e no fact-check.sh; este
# arquivo, que e o provider em si, passou batido porque o teste de paridade da 6.36.3 compara
# a tabela de MODELOS dos orquestradores, nao os parametros do wrapper.
# 16000, nao 4096: em Sonnet 5 / Opus 5 o thinking vem LIGADO por padrao e o teto cobre
# pensamento + resposta juntos. Tem que bater com o default do cross-claude.ps1 -- o
# orquestrador bash nao passa --max-tokens, entao quem manda no runtime e este default.
MAX_TOKENS="16000"
MODEL="claude-sonnet-5"
ENDPOINT="https://api.anthropic.com/v1/messages"
PROMPT_FILE=""
MODE="consult"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt-file)    PROMPT_FILE="$2"; shift 2;;
        --system-prompt)  SYSTEM_PROMPT="$2"; SYSTEM_PROMPT_EXPLICIT=1; shift 2;;
        --max-tokens)     MAX_TOKENS="$2"; shift 2;;
        --model)          MODEL="$2"; shift 2;;
        --endpoint)       ENDPOINT="$2"; shift 2;;
        --mode)           MODE="$2"; shift 2;;
        *) shift;;
    esac
done

case "$MODE" in
    consult|review|pre-mortem|analyze) ;;
    *) echo "[cross-claude-provider] Mode invalido: '$MODE'. Use: consult|review|pre-mortem|analyze" >&2; exit 1;;
esac

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
#
# Corpo vai pra ARQUIVO, nao pra argv do curl -- mesma classe de bug achada em
# deepseek.sh (ver comentario la, tiatendo 2026-08-05 spec N19): "-d "$BODY"" passa
# JSON longo/multibyte pelo argv do curl.exe nativo via MSYS/Git-Bash e a fronteira
# corrompe o texto. --data-binary @arquivo le bytes direto do disco, sem cruzar argv.
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT
# 🔴 EFFORT E O QUE IMPEDE A RESPOSTA DE SAIR VAZIA. Medido em 2026-08-17, mesmo
# prompt, tres vezes:
#   sem controle -> output_tokens=16000, stop_reason=max_tokens, 0 char de texto, 153s
#   effort=low   -> output_tokens=3719,  stop_reason=end_turn,   1378 chars,       47s
# Com thinking adaptativo ligado por padrao nos modelos 5, o raciocinio enche o
# max_tokens (que cobre pensamento + resposta) e nao sobra orcamento pra escrever.
# Subir o teto so aumenta o pensamento -- a 6.36.4 tentou (8192->16000) e o sintoma
# voltou identico.
# ⚠️ NAO usar `thinking.budget_tokens`: nos modelos 5 o campo foi removido e a API
# responde 400 ("thinking.type.enabled is not supported for this model").
EFFORT="${PERCUS_CROSS_CLAUDE_EFFORT:-low}"

jq -n \
    --arg model "$MODEL" \
    --argjson max "$MAX_TOKENS" \
    --arg sys "$SYSTEM_PROMPT" \
    --arg usr "$USER_PROMPT" \
    --arg effort "$EFFORT" \
    '{
        model: $model,
        max_tokens: $max,
        output_config: { effort: $effort },
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
    }' > "$BODY_FILE"

START_MS=$(date +%s%3N)
# 180s, nao 60s: com thinking ligado e teto 16000, resposta LEGITIMA ja levou 80s (medido
# 2026-08-16 no lado DeepSeek, mesma classe). Subir o teto sem subir o timeout so troca
# "resposta vazia" por "erro de rede" -- o defeito muda de nome e continua.
RESP=$(curl -s --max-time 180 -X POST "$ENDPOINT" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "Content-Type: application/json" \
    --data-binary "@$BODY_FILE" || echo "")
END_MS=$(date +%s%3N)
LATENCY=$((END_MS - START_MS))

if [[ -z "$RESP" ]]; then
    jq -n --arg msg "network/empty response" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"cross-claude", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

# API pode devolver erro em texto puro (nao-JSON) -- mesma classe de bug achada em
# deepseek.sh (ver comentario la, tiatendo 2026-08-05 spec N19). Sem este check,
# "jq -e '.error'" falha calado em RESP nao-JSON, o script cai no caminho de sucesso,
# e o parse error do jq seguinte mascara a mensagem real da API.
if ! echo "$RESP" | jq -e . >/dev/null 2>&1; then
    jq -n --arg msg "$RESP" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"cross-claude", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

if echo "$RESP" | jq -e '.error' >/dev/null 2>&1; then
    ERR_MSG=$(echo "$RESP" | jq -r '.error.message // "network/empty response"' 2>/dev/null || echo "network/empty")
    jq -n --arg msg "$ERR_MSG" --argjson lat "$LATENCY" --arg mdl "$MODEL" \
        '{provider:"cross-claude", model:$mdl, status:"error", error:$msg, latency_ms:$lat}'
    exit 1
fi

# NAO use .content[0]: com Sonnet 5 / Opus 5 o thinking vem LIGADO por padrao e a resposta chega em
# DOIS blocos -- content[0].type="thinking" (sem campo .text) e content[1].type="text". Pegar o
# indice 0 devolve "" e o provider reporta status="empty" com stop_reason="end_turn". Medido em
# 2026-08-15 no .ps1 (mesmo contrato de API). Prompt trivial nao dispara thinking, entao o teste de
# fumaca via verde enquanto todo review real voltava vazio.
CONTENT=$(echo "$RESP" | jq -r '[.content[] | select(.type=="text") | .text] | first // ""')
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
