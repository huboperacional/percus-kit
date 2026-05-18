#!/bin/sh
# Wrapper kit-level pra agente Claude Code auto-disparar /percus-review:review
# via Bash tool, sem precisar de paste do usuário no chat.
#
# Resolve plugin percus-review instalado a nível usuário, dispatch via
# review-router + deepseek-review da versão mais recente. Path absoluto estável.
#
# Quando decisão é cross-claude ou dual, emite marker __PERCUS_NEEDS_CROSS_CLAUDE__
# no stderr -- agente lê e dispatch Sonnet subagent via Agent tool.
#
# F3 — Fact-check pipeline obrigatorio: apos reviewer principal, findings [SEV: risco|bug]
# sao validados via fact-check.sh. Findings INFUNDADO sao filtrados antes do output
# principal. Audit block preserva todos os veredictos. Opt-out via --no-fact-check.
#
# Usage:
#   bash percus-review-auto.sh                    # diff cached + working tree
#   bash percus-review-auto.sh --base main        # diff main..HEAD
#   bash percus-review-auto.sh --no-fact-check    # opt-out pra reviews triviais

set -u

BASE=""
NO_FACT_CHECK=0

# Parse args
while [ $# -gt 0 ]; do
    case "${1:-}" in
        --base)
            BASE="${2:-}"
            shift 2
            ;;
        --no-fact-check)
            NO_FACT_CHECK=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# === Resolve plugin install path ===
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PLUGINS_DIR="$CLAUDE_HOME/plugins/cache/percus-tools/percus-review"

if [ ! -d "$PLUGINS_DIR" ]; then
    >&2 echo "[percus-review-auto] ERRO: plugin nao encontrado em $PLUGINS_DIR"
    >&2 echo "Instale via /plugin install percus-review@percus-tools no chat 'claude' standalone."
    exit 1
fi

# Pega versão mais recente (semver-sorted)
CURRENT=""
for d in "$PLUGINS_DIR"/*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    case "$name" in
        [0-9]*.[0-9]*.[0-9]*)
            if [ -z "$CURRENT" ]; then
                CURRENT="$d"
            else
                # version-aware compare
                cur_name=$(basename "$CURRENT")
                if [ "$(printf '%s\n%s\n' "$cur_name" "$name" | sort -V | tail -1)" = "$name" ]; then
                    CURRENT="$d"
                fi
            fi
            ;;
    esac
done

if [ -z "$CURRENT" ]; then
    >&2 echo "[percus-review-auto] ERRO: nenhuma versao valida instalada em $PLUGINS_DIR"
    exit 1
fi

>&2 echo "[percus-review-auto] plugin v$(basename "$CURRENT") em $CURRENT"

ROUTER="$CURRENT/scripts/review-router.sh"
DEEPSEEK="$CURRENT/scripts/deepseek-review.sh"
FACT_CHECK="$CURRENT/scripts/fact-check.sh"

if [ ! -f "$ROUTER" ]; then
    >&2 echo "[percus-review-auto] ERRO: review-router.sh ausente em $CURRENT/scripts/"
    exit 1
fi

# === Run router ===
ROUTER_ARGS="--json"
if [ -n "$BASE" ]; then
    ROUTER_ARGS="$ROUTER_ARGS --base $BASE"
fi

DECISION_JSON=$(bash "$ROUTER" $ROUTER_ARGS 2>/dev/null)
if [ -z "$DECISION_JSON" ]; then
    >&2 echo "[percus-review-auto] ERRO: router falhou ou retornou vazio"
    exit 2
fi

# Parse JSON manualmente (evita dependencia de jq)
DECISION=$(echo "$DECISION_JSON" | sed -n 's/.*"decision"[ ]*:[ ]*"\([^"]*\)".*/\1/p')
SENSITIVE=$(echo "$DECISION_JSON" | sed -n 's/.*"sensitive"[ ]*:[ ]*\(true\|false\).*/\1/p')

if [ -z "$DECISION" ]; then
    >&2 echo "[percus-review-auto] ERRO: nao consegui parsear decisao de: $DECISION_JSON"
    exit 2
fi

>&2 echo "[percus-review-auto] decisao: $DECISION (sensitive=$SENSITIVE)"

# === F3 Fact-check helper ===
# Recebe review output via stdin, passa pelo fact-check pipeline.
# Se --no-fact-check ou script ausente, passa direto.
run_fact_check() {
    REVIEW_OUTPUT="$1"
    if [ "$NO_FACT_CHECK" = "1" ]; then
        >&2 echo "[percus-review-auto] fact-check: skipped (--no-fact-check)"
        printf '%s' "$REVIEW_OUTPUT"
        return 0
    fi
    if [ ! -f "$FACT_CHECK" ]; then
        >&2 echo "[percus-review-auto] WARN: fact-check.sh nao encontrado em $FACT_CHECK — passando output direto"
        printf '%s' "$REVIEW_OUTPUT"
        return 0
    fi
    >&2 echo "[percus-review-auto] fact-check: iniciando pipeline F3..."
    FC_OUT=$(printf '%s' "$REVIEW_OUTPUT" | bash "$FACT_CHECK" 2>/dev/null)
    if [ -n "$FC_OUT" ]; then
        # Extrair filtered_output do JSON via python3 (best-effort)
        FILTERED=$(printf '%s' "$FC_OUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inf = d.get('findings_infundado', 0)
    tot = d.get('findings_total', 0)
    if inf and inf > 0:
        import sys as s
        print(f'[percus-review-auto] WARN: {inf} finding(s) INFUNDADO(s) filtrado(s) do output — ver bloco Audit', file=s.stderr)
    print(d.get('filtered_output', ''), end='')
except Exception:
    pass
" 2>/tmp/percus_fc_warn)
        cat /tmp/percus_fc_warn >&2 2>/dev/null || true
        if [ -n "$FILTERED" ]; then
            printf '%s' "$FILTERED"
            return 0
        fi
    fi
    >&2 echo "[percus-review-auto] WARN: fact-check nao retornou filtered_output — passando output original"
    printf '%s' "$REVIEW_OUTPUT"
}

# === Dispatch ===
DEEPSEEK_ARGS=""
if [ -n "$BASE" ]; then
    DEEPSEEK_ARGS="--base $BASE"
fi

case "$DECISION" in
    deepseek)
        # Captura output do reviewer pra passar pelo fact-check pipeline (F3)
        REVIEW_OUTPUT=$(bash "$DEEPSEEK" $DEEPSEEK_ARGS 2>/dev/null)
        if [ $? -ne 0 ]; then
            >&2 echo "[percus-review-auto] ERRO: deepseek-review.sh falhou"
            exit 3
        fi
        run_fact_check "$REVIEW_OUTPUT"
        ;;

    dual)
        # Captura output do reviewer pra passar pelo fact-check pipeline (F3)
        REVIEW_OUTPUT=$(bash "$DEEPSEEK" $DEEPSEEK_ARGS 2>/dev/null)
        if [ $? -ne 0 ]; then
            >&2 echo "[percus-review-auto] ERRO: deepseek-review.sh falhou"
            exit 3
        fi
        run_fact_check "$REVIEW_OUTPUT"
        >&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: pasta sensitive detectada (decision=dual). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt R11 cross-claude-review."
        ;;

    cross-claude)
        # R11: DeepSeek nao pode auto-revisar. Placeholder pra liberar hook TTL,
        # agente DEVE dispatchar Sonnet via Agent tool.
        # Nota: fact-check nao aplicavel aqui — sem output de reviewer local.
        REVIEW_DIR=".deepseek/reviews"
        mkdir -p "$REVIEW_DIR"
        TS=$(date +%Y%m%d-%H%M%S)
        PLACEHOLDER="$REVIEW_DIR/$TS-deferred-cross-claude.jsonl"
        ISO_TS=$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
        printf '{"deferred":true,"reason":"decision=cross-claude (commit from DeepSeek). R11 anti auto-revisao -- so Sonnet revisa.","decision":"cross-claude","timestamp":"%s","placeholder":true,"note":"Agente DEVE dispatchar Sonnet subagent agora; substituir este placeholder pelas findings reais."}\n' "$ISO_TS" > "$PLACEHOLDER"
        >&2 echo "[percus-review-auto] placeholder escrito em $PLACEHOLDER (libera hook por TTL)"
        >&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: commit veio de DeepSeek (decision=cross-claude). DEVE dispatchar Sonnet subagent via Agent tool agora -- DeepSeek NAO revisa proprio output (R11)."
        ;;

    *)
        >&2 echo "[percus-review-auto] ERRO: decisao desconhecida do router: $DECISION"
        exit 2
        ;;
esac

exit 0
