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

# Comando de registro da review Cross-Claude (FR-008): mesma resolucao do
# percus-review-auto.sh -- copia do plugin instalado, ou a do kit se o cache ainda
# nao tem o comando.
REGISTRAR="$CURRENT/scripts/registrar-review.sh"
if [ ! -f "$REGISTRAR" ]; then
    _KIT_DIR=$(cd "$(dirname "$0")/.." 2>/dev/null && { pwd -W 2>/dev/null || pwd; })
    if [ -f "$_KIT_DIR/plugin/percus-review/scripts/registrar-review.sh" ]; then
        REGISTRAR="$_KIT_DIR/plugin/percus-review/scripts/registrar-review.sh"
    fi
fi
INSTRUCAO_REGISTRO=" Depois que o subagente responder, grave os findings dele num arquivo FORA do repo (ex.: com mktemp ou em \${TMPDIR:-/tmp}; nunca dentro do repo, senao muda o git diff HEAD e o hash registrado deixa de bater) e registre com registrar-review: bash '$REGISTRAR' --arquivo '<arquivo-dos-findings>' --canal cross-claude --modelo '<modelo-do-subagente>'. Sem esse registro o commit so passa pelo placeholder de 5 min."

causa_falha_deepseek() {
    case "$1" in
        4)
            printf 'provedor indispon\303\255vel ap\303\263s retry (exit 4)'
            ;;
        3)
            printf 'resposta inutiliz\303\241vel do DeepSeek: vazia, cortada ou finish_reason inesperado (exit 3)'
            ;;
        1)
            printf 'erro n\303\243o recuper\303\241vel do DeepSeek: chave, cr\303\251dito ou requisi\303\247\303\243o (exit 1)'
            ;;
        *)
            printf 'DeepSeek falhou (exit %s)' "$1"
            ;;
    esac
}

# Marcador so ganha a linha do registrar se houver diff pendente (git diff HEAD --quiet
# devolve <>0 quando ha diferenca). Arvore limpa apos o merge do marco nao tem o que
# registrar via hash de commit -- os findings vao no relatorio do marco.
if git diff HEAD --quiet 2>/dev/null; then
    SUFIXO_MARCADOR=" Marco sem diff pendente: nao ha marcador R11 a registrar; guarde os findings no relatorio do marco."
else
    SUFIXO_MARCADOR="$INSTRUCAO_REGISTRO"
fi

# === Marco SEMPRE dual ===
>&2 echo "[percus-milestone-auto] base=$BASE, escopo do marco"
bash "$DEEPSEEK" --base "$BASE"
DS_RC=$?
if [ "$DS_RC" -ne 0 ]; then
    # Mesmo fix do caso "dual" de percus-review-auto.sh: DeepSeek fora do ar nao pode
    # deixar o marco INTEIRO sem registro e sem marker -- marco e SEMPRE dual, entao
    # este `exit 3` bloqueava 100% dos fechamentos de marco ate a chave ser restaurada.
    # Grava placeholder deferred ANTES do marker/sair, mesmo padrao do caso "cross-claude".
    >&2 echo "[percus-milestone-auto] ERRO: deepseek-review.sh falhou (exit $DS_RC) -- registrando placeholder deferred pra nao travar o gate."
    REVIEW_DIR=".deepseek/reviews"
    mkdir -p "$REVIEW_DIR"
    LOG_FILE="$REVIEW_DIR/latest.jsonl"
    LOG_TMP="$REVIEW_DIR/latest.jsonl.tmp"
    ISO_TS=$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
    CAUSA=$(causa_falha_deepseek "$DS_RC")
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg reason "decision=milestone-dual (base=$BASE), $CAUSA. Registro parcial; Cross-Claude ainda precisa rodar (R11)." --arg ts "$ISO_TS" \
            '{deferred:true, reason:$reason, decision:"milestone-dual", timestamp:$ts, placeholder:true, note:"Agente DEVE dispatchar Sonnet subagent agora com prompt de milestone-review; substituir este placeholder pelas findings reais quando possivel."}' \
            > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"
    else
        # $BASE vem de quem chama o wrapper (ref/commit) -- nao e literal controlado como
        # nos outros branches, entao escapa backslash ANTES de aspas (mesma ordem exigida
        # pra nao gerar sequencia de escape invalida em JSON).
        ESCAPED_BASE=$(printf '%s' "$BASE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        ESCAPED_CAUSA=$(printf '%s' "$CAUSA" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"deferred":true,"reason":"decision=milestone-dual (base=%s), %s. Registro parcial; Cross-Claude ainda precisa rodar (R11).","decision":"milestone-dual","timestamp":"%s","placeholder":true,"note":"Agente DEVE dispatchar Sonnet subagent agora com prompt de milestone-review; substituir este placeholder pelas findings reais quando possivel."}\n' \
            "$ESCAPED_BASE" "$ESCAPED_CAUSA" "$ISO_TS" > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"
    fi
    >&2 echo "[percus-milestone-auto] placeholder escrito em $LOG_FILE (libera hook por TTL)"
    >&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: marco fechado (dual obrigatorio, $CAUSA). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de milestone-review (escopo: $BASE..HEAD).$SUFIXO_MARCADOR"
    exit 0
fi

>&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: marco fechado (dual obrigatorio). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de milestone-review (escopo: $BASE..HEAD).$SUFIXO_MARCADOR"

exit 0
