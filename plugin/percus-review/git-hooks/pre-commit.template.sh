#!/bin/sh
# === PERCUS-MERGED-HOOK BEGIN ===
# percus-review pre-commit hook (Layer 2 anti-bypass)
# DO NOT change the marker lines (=== PERCUS-MERGED-HOOK BEGIN/END ===) --
# /percus-review:install-git-hooks usa elas pra distinguir hook Percus puro de
# hibrido (com logica custom apos END) e atualizar so o bloco Percus em re-runs.
#
# Defesa em profundidade vs bypass do PreToolUse:Bash hook (rm && commit encadeado).
# Roda no momento real do git commit -- fecha brecha onde estado muda durante o bash.
# Espelha logica de hooks/pre-commit-check.ps1 (TTL 5min, escape PERCUS_HOOKS_DISABLED).
#
# Exit codes: 0 = allow (fall-through ao custom hook se hibrido), 1 = block.
# PS1 layer 1 usa exit 2 (convencao PreToolUse). Diferenca proposital -- cada
# layer fala com runtime diferente.
#
# --amend semantics: liberamos quando 'git diff --cached --quiet' (zero staged)
# -- mais permissivo que PS1 (que so whitelistou '--amend --no-edit' literal).
# Cobre amend trocando msg sem mudar conteudo, --allow-empty, etc.

set -u

# Escape declarado em voz alta pelo usuario -- pula check Percus, mas FALL-THROUGH
# pro custom hook se hibrido (custom pode ter sua propria semantica de bypass).
if [ "${PERCUS_HOOKS_DISABLED:-}" = "1" ]; then
    : # noop, segue pra logica custom apos END marker
else
    # Sem mudancas staged (ex: --amend --no-edit, commit --allow-empty) -> libera
    if ! git diff --cached --quiet 2>/dev/null; then
        REVIEW_DIR=".deepseek/reviews"

        if [ ! -d "$REVIEW_DIR" ]; then
            >&2 echo "[percus:hook pre-commit native] BLOCK: nenhum /percus-review:review encontrado em $REVIEW_DIR/"
            >&2 echo "Rode /percus-review:review antes de commitar (R11)."
            exit 1
        fi

        # === VALIDADE POR CONTEUDO, ANTES DA POR TEMPO (2026-08-19) ===
        # Marcador d-<hash>.jsonl prova que ESTE diff foi revisado. Aqui o hook JA roda dentro
        # do repo (git chama o hook com cwd na raiz), entao nao precisa de -C como no gemeo
        # PreToolUse, que roda no cwd do agente.
        # Hash do ARQUIVO escrito por `git diff --output=`, nunca da saida capturada pelo shell:
        # shells diferentes decodificam diferente e o hash divergiria em silencio.
        if command -v sha256sum >/dev/null 2>&1; then
            TMP_DIFF="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-diff-$$")"
            git diff HEAD --output="$TMP_DIFF" 2>/dev/null || true
            DIFF_HASH=$(sha256sum "$TMP_DIFF" 2>/dev/null | cut -c1-12)
            rm -f "$TMP_DIFF"
            POR_HASH="$REVIEW_DIR/d-$DIFF_HASH.jsonl"
            if [ -n "$DIFF_HASH" ] && [ -f "$POR_HASH" ]; then
                H_MTIME=$(stat -c %Y "$POR_HASH" 2>/dev/null || stat -f %m "$POR_HASH" 2>/dev/null)
                if [ -n "$H_MTIME" ] && [ $(( $(date +%s) - H_MTIME )) -le 86400 ]; then
                    exit 0
                fi
            fi
        fi

        # Path FIXO latest.jsonl (2026-07-20): o wrapper sobrescreve sempre o
        # mesmo arquivo, entao o hook le UM path conhecido -- O(1), sem stat em N.
        # Compat: wrapper antigo deixou <ts>.jsonl -> fallback pega o mais novo.
        LATEST="$REVIEW_DIR/latest.jsonl"
        if [ ! -f "$LATEST" ]; then
            LATEST=$(ls -t "$REVIEW_DIR"/*.jsonl 2>/dev/null | head -1)
        fi

        if [ -z "$LATEST" ]; then
            >&2 echo "[percus:hook pre-commit native] BLOCK: pasta $REVIEW_DIR/ vazia"
            >&2 echo "Rode /percus-review:review antes de commitar (R11)."
            exit 1
        fi

        NOW=$(date +%s)
        # stat -c %Y (GNU/Linux/git-bash) com fallback stat -f %m (BSD/macOS)
        MTIME=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null)

        if [ -z "$MTIME" ]; then
            # Falha graceful: stat indisponivel, libera com warn
            >&2 echo "[percus:hook pre-commit native] WARN: stat falhou, liberando commit. Verifique seu shell."
        else
            AGE_SEC=$((NOW - MTIME))
            MAX_AGE=300  # 5 min

            if [ "$AGE_SEC" -gt "$MAX_AGE" ]; then
                AGE_MIN=$((AGE_SEC / 60))
                >&2 echo "[percus:hook pre-commit native] BLOCK: ultimo /percus-review:review tem $AGE_MIN min (max 5)."
                >&2 echo "Rode /percus-review:review de novo antes de commitar (R11)."
                exit 1
            fi
        fi
    fi
fi
# === PERCUS-MERGED-HOOK END ===

# Hook Percus puro (sem custom logic). /percus-review:install-git-hooks substitui
# este 'exit 0' pelo conteudo do hook custom existente quando opera em modo hibrido.
exit 0
