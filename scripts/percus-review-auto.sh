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

# A versao real e a do plugin.json; o NOME DA PASTA reflete o ultimo republish e fica
# legitimamente atras (republish descartado em 01/07/2026 — ver CANON_VERSION.md).
MANIFEST_VERSION="?"
if [ -f "$CURRENT/plugin.json" ]; then
    MANIFEST_VERSION=$(sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$CURRENT/plugin.json" | head -1)
    [ -z "$MANIFEST_VERSION" ] && MANIFEST_VERSION="?"
fi
>&2 echo "[percus-review-auto] plugin pasta=$(basename "$CURRENT") plugin.json=$MANIFEST_VERSION em $CURRENT"

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

# Avisos do router (v6.31.0): o router roda com 2>/dev/null, entao os avisos vem
# DENTRO do JSON. Rebaixamento silencioso por config quebrada foi o bug de 2026-07-27.
WARN_LINES=""
if command -v jq >/dev/null 2>&1; then
    WARN_LINES=$(printf '%s' "$DECISION_JSON" | jq -r '.warnings[]?' 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
    WARN_LINES=$(printf '%s' "$DECISION_JSON" | python3 -c 'import json,sys
for w in (json.load(sys.stdin).get("warnings") or []): print(w)' 2>/dev/null || true)
elif printf '%s' "$DECISION_JSON" | tr -d ' \n' | grep -q '"warnings":\["'; then
    WARN_LINES="router emitiu avisos e nao ha jq/python3 para le-los — rode o router direto"
fi
if [ -n "$WARN_LINES" ]; then
    printf '%s\n' "$WARN_LINES" | while IFS= read -r w; do
        [ -z "$w" ] || >&2 echo "[percus-review-auto] WARN (router): $w"
    done
fi

>&2 echo "[percus-review-auto] decisao: $DECISION (sensitive=$SENSITIVE)"

# === Placeholder "deferred" em .deepseek/reviews/latest.jsonl ===
# Usado sempre que o registro real (findings de DeepSeek e/ou Cross-Claude) nao pode
# ser persistido no momento em que o wrapper decide "dual"/"council" (ex.: DeepSeek
# fora do ar / API key invalida) -- SEM isto, o caminho antigo fazia `exit` direto
# nesse ponto, sem nunca gravar nada em .deepseek/reviews/ e sem emitir o marker de
# Cross-Claude. O gate de 5min (R11, pre-commit-check.sh) entao nunca achava registro
# fresco pro commit e bloqueava ate o operador declarar PERCUS_HOOKS_DISABLED --
# exatamente no caminho sensivel (dual/council), que e o de maior risco. Mesmo padrao
# que ja existia so pro caso "cross-claude": grava ANTES de emitir o marker/sair.
write_deferred_review_placeholder() {
    DECISION_ARG="$1"
    REASON_ARG="$2"
    REVIEW_DIR=".deepseek/reviews"
    mkdir -p "$REVIEW_DIR"
    LOG_FILE="$REVIEW_DIR/latest.jsonl"
    LOG_TMP="$REVIEW_DIR/latest.jsonl.tmp"
    ISO_TS=$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg decision "$DECISION_ARG" --arg reason "$REASON_ARG" --arg ts "$ISO_TS" \
            '{deferred:true, reason:$reason, decision:$decision, timestamp:$ts, placeholder:true, note:"Agente DEVE dispatchar Sonnet subagent agora; substituir este placeholder pelas findings reais quando possivel."}' \
            > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"
    else
        # Sem jq: escreve JSON manualmente. Escapa backslash ANTES de aspas -- generico
        # pra qualquer $Reason futuro que contenha barra invertida (ex.: path Windows),
        # nao so os literais atuais (que nao tem barra invertida, mas a funcao e reusavel).
        ESCAPED_REASON=$(printf '%s' "$REASON_ARG" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"deferred":true,"reason":"%s","decision":"%s","timestamp":"%s","placeholder":true,"note":"Agente DEVE dispatchar Sonnet subagent agora; substituir este placeholder pelas findings reais quando possivel."}\n' \
            "$ESCAPED_REASON" "$DECISION_ARG" "$ISO_TS" > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"
    fi
    >&2 echo "[percus-review-auto] placeholder escrito em $LOG_FILE (libera hook por TTL)"
}

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
            # Mesmo fix dos branches dual/cross-claude/council: rota solo tambem nao pode
            # travar o commit inteiro so porque a chave DeepSeek caiu -- essa e a rota mais
            # comum do portfolio. Conselho 3/3 (deepseek+llama+cross-claude, consult
            # 2026-08-05) confirmou: escalar pra Cross-Claude via marker, nao bloquear.
            >&2 echo "[percus-review-auto] ERRO: deepseek-review.sh falhou -- registrando placeholder deferred pra nao travar o gate."
            write_deferred_review_placeholder "deepseek" "decision=deepseek (rota solo), DeepSeek falhou -- provavel outage/API key invalida. Sem segunda perna de review por padrao nesta rota; escalado pra Cross-Claude."
            >&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: rota solo (decision=deepseek), DeepSeek indisponivel. DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de review R11 (escopo: commit atual)."
            exit 0
        fi
        run_fact_check "$REVIEW_OUTPUT"
        ;;

    dual)
        # Captura output do reviewer pra passar pelo fact-check pipeline (F3)
        REVIEW_OUTPUT=$(bash "$DEEPSEEK" $DEEPSEEK_ARGS 2>/dev/null)
        if [ $? -ne 0 ]; then
            # DeepSeek falhou (outage/API key invalida/etc.). ANTES: `exit 3` aqui matava
            # o wrapper inteiro sem gravar nada em .deepseek/reviews/ e sem emitir o marker
            # -- gate de 5min nunca achava registro pro caminho dual, forcando escape manual
            # em TODO commit sensivel. Fix: registra placeholder deferred e ainda sinaliza
            # Cross-Claude, pra R11 poder ser cumprido so pela perna que sobrou de pe.
            >&2 echo "[percus-review-auto] ERRO: deepseek-review.sh falhou -- registrando placeholder deferred pra nao travar o gate."
            write_deferred_review_placeholder "dual" "decision=dual, DeepSeek falhou -- provavel outage/API key invalida. Registro parcial; Cross-Claude ainda precisa rodar (R11)."
            >&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: pasta sensitive detectada (decision=dual, DeepSeek indisponivel). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt R11 cross-claude-review."
            exit 0
        fi
        run_fact_check "$REVIEW_OUTPUT"
        >&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: pasta sensitive detectada (decision=dual). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt R11 cross-claude-review."
        ;;

    council)
        # Fase 6 v6.1.0+: o router emite "council" (sensivel + grande/from-DS) desde a
        # v6.1.0, mas este case nunca existiu aqui — so no .ps1. Resultado: quem rodava
        # o wrapper por bash caia em "decisao desconhecida" e o review NAO acontecia.
        # Encontrado em 2026-07-27 rodando o proprio gate sobre este commit.
        # Semantica identica a do .ps1: DeepSeek local + Llama via orchestrator + marker
        # pro agente completar a 3a perspectiva (Cross-Claude).
        REVIEW_OUTPUT=$(bash "$DEEPSEEK" $DEEPSEEK_ARGS 2>/dev/null)
        if [ $? -ne 0 ]; then
            # Mesmo fix do caso "dual" acima: DeepSeek fora do ar nao pode matar o
            # wrapper inteiro antes de registrar nada e antes do marker -- Llama e
            # Cross-Claude ainda cobrem o conselho enquanto DeepSeek estiver indisponivel.
            >&2 echo "[percus-review-auto] ERRO: deepseek-review.sh falhou -- registrando placeholder deferred pra nao travar o gate."
            write_deferred_review_placeholder "council" "decision=council, DeepSeek falhou -- provavel outage/API key invalida. Registro parcial; Llama/Cross-Claude cobrem o resto."
        else
            run_fact_check "$REVIEW_OUTPUT"
        fi

        ORCH="$CURRENT/scripts/council-orchestrator.sh"
        if [ -f "$ORCH" ]; then
            if [ -n "$BASE" ]; then
                DIFF=$(git diff "$BASE...HEAD" 2>/dev/null)
            else
                DIFF=$(printf '%s\n%s' "$(git diff --cached 2>/dev/null)" "$(git diff 2>/dev/null)")
            fi
            if [ -n "$(printf '%s' "$DIFF" | tr -d '[:space:]')" ]; then
                TMP_PROMPT=$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-council-$$.txt")
                printf 'Revise o git diff abaixo no padrao Percus R1-R19. Aponte bugs, regressoes, mocks, violacoes de auth, imports vetados. Se nada relevante: '"'"'Sem findings criticos'"'"'.\n\n---DIFF---\n%s' "$DIFF" > "$TMP_PROMPT"
                if bash "$ORCH" --prompt-file "$TMP_PROMPT" --mode review --providers groq-llama >/dev/null 2>&1; then
                    >&2 echo "[percus-review-auto] orchestrator Llama executado (log em .deepseek/council-log/)"
                else
                    >&2 echo "[percus-review-auto] WARN: orchestrator Llama falhou (DeepSeek ja cobriu hook)"
                fi
                rm -f "$TMP_PROMPT"
            fi
        fi

        >&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: decision=council (sensitive + grande/from-DS). DEVE dispatchar Sonnet subagent via Agent tool agora pra completar conselho 3-membros."
        ;;

    cross-claude)
        # R11: DeepSeek nao pode auto-revisar. Placeholder pra liberar hook TTL,
        # agente DEVE dispatchar Sonnet via Agent tool.
        # Nota: fact-check nao aplicavel aqui — sem output de reviewer local.
        write_deferred_review_placeholder "cross-claude" "decision=cross-claude (commit from DeepSeek). R11 anti auto-revisao -- so Sonnet revisa."
        >&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: commit veio de DeepSeek (decision=cross-claude). DEVE dispatchar Sonnet subagent via Agent tool agora -- DeepSeek NAO revisa proprio output (R11)."
        ;;

    *)
        >&2 echo "[percus-review-auto] ERRO: decisao desconhecida do router: $DECISION"
        exit 2
        ;;
esac

exit 0
