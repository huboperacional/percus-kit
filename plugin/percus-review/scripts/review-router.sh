#!/usr/bin/env bash
# review-router.sh — Router de review: decide entre DeepSeek, Cross-Claude, ou dual.
#
# Inspeciona arquivos tocados (cached + working tree, ou <base>..HEAD) e o
# trailer do último commit. Decide:
#   - "dual"         se tocar pasta sensível (auth/, payment*/, migrations/, credentials/, .env)
#   - "cross-claude" se último commit tem trailer "Co-implemented-by: deepseek"
#   - "deepseek"     caso contrário (default cross-provider)

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
IS_SENSITIVE=0
if [[ -n "$FILES" ]]; then
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if [[ "$f" =~ (^|/)auth/ ]] \
            || [[ "$f" =~ (^|/)payment[^/]*/ ]] \
            || [[ "$f" =~ (^|/)migrations/ ]] \
            || [[ "$f" =~ (^|/)credentials/ ]] \
            || [[ "$f" =~ ^\.env ]]; then
            IS_SENSITIVE=1
            break
        fi
    done <<< "$FILES"
fi

# === CHECK COMMIT TRAILER (último commit) ===
LAST_MSG="$(git log -1 --pretty=%B 2>/dev/null || true)"
FROM_DEEPSEEK=0
if echo "$LAST_MSG" | grep -iqE '^Co-implemented-by:[[:space:]]*deepseek'; then
    FROM_DEEPSEEK=1
fi

# === DECIDE ===
if [[ "$IS_SENSITIVE" -eq 1 ]]; then
    DECISION="dual"
elif [[ "$FROM_DEEPSEEK" -eq 1 ]]; then
    DECISION="cross-claude"
else
    DECISION="deepseek"
fi

# === OUTPUT ===
if [[ "$JSON" -eq 1 ]]; then
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg decision "$DECISION" \
            --argjson sensitive "$IS_SENSITIVE" \
            --argjson from_deepseek "$FROM_DEEPSEEK" \
            --argjson files_count "$FILES_COUNT" \
            '{ decision: $decision, sensitive: ($sensitive==1), from_deepseek: ($from_deepseek==1), files_count: $files_count }'
    else
        SENS_BOOL=$([[ "$IS_SENSITIVE" -eq 1 ]] && echo true || echo false)
        FROM_BOOL=$([[ "$FROM_DEEPSEEK" -eq 1 ]] && echo true || echo false)
        printf '{"decision":"%s","sensitive":%s,"from_deepseek":%s,"files_count":%s}\n' \
            "$DECISION" "$SENS_BOOL" "$FROM_BOOL" "$FILES_COUNT"
    fi
else
    SENS_BOOL=$([[ "$IS_SENSITIVE" -eq 1 ]] && echo true || echo false)
    FROM_BOOL=$([[ "$FROM_DEEPSEEK" -eq 1 ]] && echo true || echo false)
    echo "[router] decisão: ${DECISION} (sensitive=${SENS_BOOL}, from_deepseek=${FROM_BOOL}, ${FILES_COUNT} arquivo(s))"
    echo "$DECISION"
fi
