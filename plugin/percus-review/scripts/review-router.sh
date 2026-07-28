#!/usr/bin/env bash
# review-router.sh — Router de review: decide entre DeepSeek, Cross-Claude, ou dual.
#
# Inspeciona arquivos tocados (cached + working tree, ou <base>..HEAD) e o
# trailer do último commit. Decide:
#   - "dual"         se tocar pasta sensível
#   - "cross-claude" se último commit tem trailer "Co-implemented-by: deepseek"
#   - "deepseek"     caso contrário (default cross-provider)
#
# O que é "pasta sensível" vem de DOIS lugares somados (v6.31.0+):
#   1. scripts/sensitive-paths.txt — baseline global, MESMO arquivo lido pelo .ps1 e pelos testes.
#   2. .percus-review.json na raiz do repo revisado — convenção daquele projeto:
#        { "sensitivePatterns": ["(^|[/\\\\])execution[/\\\\].*\\.py$"] }
#
# FALHA FECHADA: baseline ausente/vazio, JSON inválido ou regex que não compila NÃO
# rebaixam a decisão — marcam sensitive=true e emitem aviso em "warnings".

set -euo pipefail

BASE=""
JSON=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)
            BASE="$2"; shift 2 ;;
        --base=*)
            BASE="${1#*=}"; shift ;;
        --json)
            JSON=1; shift ;;
        -h|--help)
            sed -n '2,11p' "$0"; exit 0 ;;
        *)
            shift ;;
    esac
done

# === DETECT FILES TOCADOS ===
if [[ -n "$BASE" ]]; then
    FILES_RAW="$(git diff --name-only "$BASE...HEAD" 2>/dev/null || true)"
else
    FILES_RAW="$( { git diff --name-only --cached 2>/dev/null; git diff --name-only 2>/dev/null; } | sort -u )"
fi
FILES="$(echo "$FILES_RAW" | sed '/^[[:space:]]*$/d')"
FILES_COUNT=0
if [[ -n "$FILES" ]]; then
    FILES_COUNT="$(echo "$FILES" | wc -l | tr -d ' ')"
fi

# === SENSITIVE PATHS ===
# Nada de lista hardcoded aqui: a lista duplicada em .ps1/.sh foi a causa raiz
# do incidente 2026-07-27 (os dois podiam divergir em silêncio).
WARNINGS=""
FAIL_CLOSED=0
add_warning() { WARNINGS="${WARNINGS}${1}
"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_FILE="$SCRIPT_DIR/sensitive-paths.txt"

# 1. Baseline global (fonte única compartilhada com review-router.ps1 e os testes)
PATTERNS=""
if [[ -f "$BASELINE_FILE" ]]; then
    PATTERNS="$(tr -d '\r' < "$BASELINE_FILE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
                | grep -v '^#' | grep -v '^$' || true)"
fi
if [[ -z "$PATTERNS" ]]; then
    add_warning "baseline sensitive-paths.txt ausente ou vazio em '$BASELINE_FILE' — assumindo sensitive=true (falha fechada)"
    FAIL_CLOSED=1
fi

# 2. Extensão declarada pelo projeto revisado (.percus-review.json na raiz do repo)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -z "$REPO_ROOT" ]] && REPO_ROOT="$(pwd)"
CFG_FILE="$REPO_ROOT/.percus-review.json"
if [[ -f "$CFG_FILE" ]]; then
    PROJ_PATTERNS=""
    PARSED=0
    if command -v jq >/dev/null 2>&1; then
        if PROJ_PATTERNS="$(jq -r 'if (.sensitivePatterns|type)=="array" then (.sensitivePatterns[0:100][] | select(type=="string" and length>0 and length<=200 and (contains("\n")|not))) else empty end' "$CFG_FILE" 2>/dev/null)"; then
            PARSED=1
        fi
    elif command -v python3 >/dev/null 2>&1; then
        if PROJ_PATTERNS="$(python3 -c '
import json,sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
p = d.get("sensitivePatterns")
if isinstance(p, list):
    for x in p[:100]:
        if isinstance(x, str) and x.strip() and len(x) <= 200 and "\n" not in x:
            print(x)
' "$CFG_FILE" 2>/dev/null)"; then
            PARSED=1
        fi
    else
        add_warning "sem jq nem python3 para ler .percus-review.json — assumindo sensitive=true (falha fechada)"
        FAIL_CLOSED=1
        PARSED=1
    fi
    if [[ "$PARSED" -eq 0 ]]; then
        add_warning ".percus-review.json ilegível/inválido em '$CFG_FILE' — assumindo sensitive=true (falha fechada)"
        FAIL_CLOSED=1
    elif [[ -n "$PROJ_PATTERNS" ]]; then
        # tr -d '\r': jq e python no Windows escrevem CRLF. O \r grudado no fim vira
        # parte da regex ('...$\r' não casa com nada) e o padrão morre em silêncio.
        PROJ_PATTERNS="$(printf '%s' "$PROJ_PATTERNS" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' || true)"
        if [[ -n "$PROJ_PATTERNS" ]]; then
            PATTERNS="${PATTERNS}
${PROJ_PATTERNS}"
        fi
    fi
fi

# 3. Match (case-insensitive nos dois motores; regex que não compila → falha fechada)
IS_SENSITIVE="$FAIL_CLOSED"
if [[ "$IS_SENSITIVE" -eq 0 && -n "$FILES" && -n "$PATTERNS" ]]; then
    shopt -s nocasematch
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            if [[ "$f" =~ $p ]]; then
                IS_SENSITIVE=1
                break
            elif [[ $? -eq 2 ]]; then
                add_warning "padrão inválido ignorado: '$p' — assumindo sensitive=true (falha fechada)"
                FAIL_CLOSED=1
                IS_SENSITIVE=1
                break
            fi
        done <<< "$PATTERNS"
        if [[ "$IS_SENSITIVE" -eq 1 ]]; then
            break
        fi
    done <<< "$FILES"
    shopt -u nocasematch
fi

# === CHECK COMMIT TRAILER (último commit) ===
LAST_MSG="$(git log -1 --pretty=%B 2>/dev/null || true)"
FROM_DEEPSEEK=0
if echo "$LAST_MSG" | grep -iqE '^Co-implemented-by:[[:space:]]*deepseek'; then
    FROM_DEEPSEEK=1
fi

# === DECIDE ===
# Fase 6 v6.1.0+: "council" quando sensitive E (commit do DS OU >10 arquivos).
COUNCIL_TRIGGER=0
if [[ "$IS_SENSITIVE" -eq 1 ]] && { [[ "$FROM_DEEPSEEK" -eq 1 ]] || [[ "$FILES_COUNT" -gt 10 ]]; }; then
    COUNCIL_TRIGGER=1
fi

if [[ "$COUNCIL_TRIGGER" -eq 1 ]]; then
    DECISION="council"
elif [[ "$IS_SENSITIVE" -eq 1 ]]; then
    DECISION="dual"
elif [[ "$FROM_DEEPSEEK" -eq 1 ]]; then
    DECISION="cross-claude"
else
    DECISION="deepseek"
fi

# === OUTPUT ===
# 'warnings' sai no JSON (e não só no stderr) porque o wrapper chama o router com
# 2>/dev/null: aviso que só existe em stderr é aviso que ninguém lê.
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
WARN_JSON="[]"
if [[ -n "$WARNINGS" ]]; then
    WARN_ITEMS=""
    while IFS= read -r w; do
        [[ -z "$w" ]] && continue
        if [[ -z "$WARN_ITEMS" ]]; then
            WARN_ITEMS="\"$(json_escape "$w")\""
        else
            WARN_ITEMS="${WARN_ITEMS},\"$(json_escape "$w")\""
        fi
    done <<< "$WARNINGS"
    WARN_JSON="[${WARN_ITEMS}]"
fi

if [[ "$JSON" -eq 1 ]]; then
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg decision "$DECISION" \
            --argjson sensitive "$IS_SENSITIVE" \
            --argjson from_deepseek "$FROM_DEEPSEEK" \
            --argjson files_count "$FILES_COUNT" \
            --argjson council_trigger "$COUNCIL_TRIGGER" \
            --argjson warnings "$WARN_JSON" \
            '{ decision: $decision, sensitive: ($sensitive==1), from_deepseek: ($from_deepseek==1), files_count: $files_count, council_trigger: ($council_trigger==1), warnings: $warnings }'
    else
        SENS_BOOL=$([[ "$IS_SENSITIVE" -eq 1 ]] && echo true || echo false)
        FROM_BOOL=$([[ "$FROM_DEEPSEEK" -eq 1 ]] && echo true || echo false)
        COUNCIL_BOOL=$([[ "$COUNCIL_TRIGGER" -eq 1 ]] && echo true || echo false)
        printf '{"decision":"%s","sensitive":%s,"from_deepseek":%s,"files_count":%s,"council_trigger":%s,"warnings":%s}\n' \
            "$DECISION" "$SENS_BOOL" "$FROM_BOOL" "$FILES_COUNT" "$COUNCIL_BOOL" "$WARN_JSON"
    fi
else
    SENS_BOOL=$([[ "$IS_SENSITIVE" -eq 1 ]] && echo true || echo false)
    FROM_BOOL=$([[ "$FROM_DEEPSEEK" -eq 1 ]] && echo true || echo false)
    if [[ -n "$WARNINGS" ]]; then
        while IFS= read -r w; do
            [[ -z "$w" ]] && continue
            >&2 echo "[router] AVISO: $w"
        done <<< "$WARNINGS"
    fi
    echo "[router] decisão: ${DECISION} (sensitive=${SENS_BOOL}, from_deepseek=${FROM_BOOL}, ${FILES_COUNT} arquivo(s))"
    echo "$DECISION"
fi
