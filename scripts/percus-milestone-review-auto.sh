#!/bin/sh
# Wrapper kit-level pra agente auto-disparar /percus-review:milestone-review.
# Marco usa SEMPRE dual (DeepSeek + Cross-Claude). Wrapper roda DeepSeek e
# emite marker pra agente dispatchar Sonnet subagent.
#
# Usage:
#   bash percus-milestone-review-auto.sh --base <commit-inicio-marco>

set -u

BASE=""
if [ "${1:-}" = "--base" ] && [ -n "${2:-}" ]; then
    BASE="$2"
fi

if [ -z "$BASE" ]; then
    >&2 echo "[percus-milestone-auto] ERRO: --base <commit> obrigatorio"
    >&2 echo "Usage: bash percus-milestone-review-auto.sh --base <commit-inicio-marco>"
    exit 1
fi

# === Resolve plugin ===
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PLUGINS_DIR="$CLAUDE_HOME/plugins/cache/percus-tools/percus-review"

if [ ! -d "$PLUGINS_DIR" ]; then
    >&2 echo "[percus-milestone-auto] ERRO: plugin nao encontrado em $PLUGINS_DIR"
    exit 1
fi

CURRENT=""
for d in "$PLUGINS_DIR"/*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    case "$name" in
        [0-9]*.[0-9]*.[0-9]*)
            if [ -z "$CURRENT" ]; then
                CURRENT="$d"
            else
                cur_name=$(basename "$CURRENT")
                if [ "$(printf '%s\n%s\n' "$cur_name" "$name" | sort -V | tail -1)" = "$name" ]; then
                    CURRENT="$d"
                fi
            fi
            ;;
    esac
done

if [ -z "$CURRENT" ]; then
    >&2 echo "[percus-milestone-auto] ERRO: nenhuma versao instalada"
    exit 1
fi

>&2 echo "[percus-milestone-auto] plugin v$(basename "$CURRENT")"

DEEPSEEK="$CURRENT/scripts/deepseek-review.sh"

# === Marco SEMPRE dual ===
>&2 echo "[percus-milestone-auto] base=$BASE, escopo do marco"
bash "$DEEPSEEK" --base "$BASE"
if [ $? -ne 0 ]; then
    >&2 echo "[percus-milestone-auto] ERRO: deepseek-review.sh falhou"
    exit 3
fi

>&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: marco fechado (dual obrigatorio). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de milestone-review (escopo: $BASE..HEAD)."

exit 0
