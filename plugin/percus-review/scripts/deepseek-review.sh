#!/usr/bin/env bash
# deepseek-review.sh — Revisa git diff usando DeepSeek API (cross-provider review).
#
# Lê git diff (cached + working tree, ou --base <ref> para escopo). Combina com AGENTS.md.
# Chama DeepSeek API com prompt de revisor Percus. Output: findings estruturados.
# Loga em .deepseek/reviews/<timestamp>.jsonl.
#
# Requer: DEEPSEEK_API_KEY (env var ou .env do projeto), curl, jq, git.

set -euo pipefail

BASE=""
MODEL="${DEEPSEEK_MODEL:-deepseek-chat}"
TEMPERATURE="${DEEPSEEK_TEMPERATURE:-0.0}"
ENDPOINT="${DEEPSEEK_ENDPOINT:-https://api.deepseek.com/v1/chat/completions}"

# === ARGS ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)
            BASE="$2"; shift 2 ;;
        --base=*)
            BASE="${1#*=}"; shift ;;
        -h|--help)
            sed -n '2,9p' "$0"; exit 0 ;;
        *)
            shift ;;
    esac
done

# === LOAD .env ===
if [[ -z "${DEEPSEEK_API_KEY:-}" && -f .env ]]; then
    while IFS='=' read -r key val; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        val="$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'\'']\(.*\)["'\'']$/\1/')"
        if [[ -n "$key" && -z "${!key:-}" ]]; then
            export "$key=$val"
        fi
    done < .env
fi
if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    echo "[deepseek-review] ERRO: DEEPSEEK_API_KEY ausente. Configure no .env do projeto." >&2
    exit 1
fi

# === DEPS ===
for cmd in curl jq git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[deepseek-review] ERRO: dependência '$cmd' não encontrada." >&2
        exit 1
    fi
done

# === COLLECT DIFF ===
if [[ -n "$BASE" ]]; then
    DIFF="$(git diff "$BASE...HEAD" 2>/dev/null || true)"
else
    CACHED="$(git diff --cached 2>/dev/null || true)"
    UNSTAGED="$(git diff 2>/dev/null || true)"
    DIFF="$(printf '%s\n%s' "$CACHED" "$UNSTAGED" | sed -e 's/^[[:space:]]*$//' )"
fi

if [[ -z "$(echo "$DIFF" | tr -d '[:space:]')" ]]; then
    echo "[deepseek-review] Nada pra revisar (diff vazio)."
    exit 0
fi

# === LOAD AGENTS.md ===
if [[ -f AGENTS.md ]]; then
    AGENTS="$(cat AGENTS.md)"
else
    AGENTS="(AGENTS.md ausente — revise pelo bom senso de Percus)"
fi

# === BUILD PROMPT ===
SYSTEM_PROMPT='Você é revisor cross-provider de código no padrão Percus.
Leia o git diff e o AGENTS.md (regras do projeto).
Para cada problema, emita finding no formato:

[SEV: bug | risco | preferência]
Arquivo: caminho/relativo:linha
Regra violada: R{N} (se aplicável)
Problema: descrição em 1-2 frases
Sugestão: ação concreta

Foque em: bugs, regressões, violações R1-R13, mock escondido (R3), JWT em localStorage (R7), pasta sensível tocada indevidamente, imports fora do stack canônico.
NÃO aponte estilo subjetivo sem regra concreta. NÃO sugira refactor fora do diff. Se nada relevante, responda "Sem findings críticos."'

USER_MSG="AGENTS.md do projeto:
${AGENTS}

---

Git diff:
${DIFF}"

# === BUILD JSON BODY (jq garante encoding seguro) ===
BODY="$(jq -n \
    --arg model "$MODEL" \
    --argjson temperature "$TEMPERATURE" \
    --arg sys "$SYSTEM_PROMPT" \
    --arg usr "$USER_MSG" \
    '{
        model: $model,
        temperature: $temperature,
        messages: [
            { role: "system", content: $sys },
            { role: "user", content: $usr }
        ]
    }')"

# === CALL API ===
RESPONSE="$(curl -sS -X POST "$ENDPOINT" \
    -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "$BODY")" || {
    echo "[deepseek-review] ERRO: chamada API falhou." >&2
    exit 1
}

FINDINGS="$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')"
if [[ -z "$FINDINGS" ]]; then
    echo "[deepseek-review] ERRO: resposta vazia. Raw:" >&2
    echo "$RESPONSE" >&2
    exit 1
fi

# === LOG ===
LOG_DIR=".deepseek/reviews"
mkdir -p "$LOG_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${LOG_DIR}/${TS}.jsonl"
DIFF_LINES="$(echo "$DIFF" | wc -l | tr -d ' ')"
jq -n \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg base "$BASE" \
    --argjson diff_lines "$DIFF_LINES" \
    --arg findings "$FINDINGS" \
    '{ timestamp: $timestamp, base: $base, diff_lines: $diff_lines, findings: $findings }' \
    > "$LOG_FILE"

# === OUTPUT ===
printf '## Findings DeepSeek (cross-provider review)\n\n'
printf '%s\n' "$FINDINGS"
