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
    # Mesmo fix do caso "dual" de percus-review-auto.sh: DeepSeek fora do ar nao pode
    # deixar o marco INTEIRO sem registro e sem marker -- marco e SEMPRE dual, entao
    # este `exit 3` bloqueava 100% dos fechamentos de marco ate a chave ser restaurada.
    # Grava placeholder deferred ANTES do marker/sair, mesmo padrao do caso "cross-claude".
    >&2 echo "[percus-milestone-auto] ERRO: deepseek-review.sh falhou -- registrando placeholder deferred pra nao travar o gate."
    REVIEW_DIR=".deepseek/reviews"
    mkdir -p "$REVIEW_DIR"
    LOG_FILE="$REVIEW_DIR/latest.jsonl"
    LOG_TMP="$REVIEW_DIR/latest.jsonl.tmp"
    ISO_TS=$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg reason "decision=milestone-dual (base=$BASE), DeepSeek falhou -- provavel outage/API key invalida. Registro parcial; Cross-Claude ainda precisa rodar (R11)." --arg ts "$ISO_TS" \
            '{deferred:true, reason:$reason, decision:"milestone-dual", timestamp:$ts, placeholder:true, note:"Agente DEVE dispatchar Sonnet subagent agora com prompt de milestone-review; substituir este placeholder pelas findings reais quando possivel."}' \
            > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"
    else
        # $BASE vem de quem chama o wrapper (ref/commit) -- nao e literal controlado como
        # nos outros branches, entao escapa backslash ANTES de aspas (mesma ordem exigida
        # pra nao gerar sequencia de escape invalida em JSON).
        ESCAPED_BASE=$(printf '%s' "$BASE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"deferred":true,"reason":"decision=milestone-dual (base=%s), DeepSeek falhou -- provavel outage/API key invalida.","decision":"milestone-dual","timestamp":"%s","placeholder":true,"note":"Agente DEVE dispatchar Sonnet subagent agora com prompt de milestone-review; substituir este placeholder pelas findings reais quando possivel."}\n' \
            "$ESCAPED_BASE" "$ISO_TS" > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"
    fi
    >&2 echo "[percus-milestone-auto] placeholder escrito em $LOG_FILE (libera hook por TTL)"
    >&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: marco fechado (dual obrigatorio, DeepSeek indisponivel). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de milestone-review (escopo: $BASE..HEAD)."
    exit 0
fi

>&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: marco fechado (dual obrigatorio). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de milestone-review (escopo: $BASE..HEAD)."

exit 0
