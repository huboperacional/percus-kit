#!/bin/sh
# percus-review pre-commit hook
# DO NOT change the marker line above (line 2) -- /percus-review:install-git-hooks
# usa esse texto pra distinguir hook Percus de hook custom no projeto-alvo.
#
# Defesa em profundidade vs bypass do PreToolUse:Bash hook (rm && commit encadeado).
# Roda no momento real do git commit -- fecha brecha onde estado muda durante o bash.
# Espelha lógica de hooks/pre-commit-check.ps1 (TTL 5min, escape PERCUS_HOOKS_DISABLED).
#
# Exit codes: 0 = allow, 1 = block (convenção git native).
# PS1 layer 1 usa exit 2 (convenção PreToolUse). Diferença é proposital -- cada
# layer fala com runtime diferente.
#
# --amend semantics: liberamos quando 'git diff --cached --quiet' (zero staged)
# -- mais permissivo que PS1 (que só whitelistou '--amend --no-edit' literal).
# Cobre amend trocando msg sem mudar conteudo, --allow-empty, etc. Critério:
# se nao ha codigo novo pra revisar, nao exige review.

set -u

# Escape declarado em voz alta pelo usuario
if [ "${PERCUS_HOOKS_DISABLED:-}" = "1" ]; then
    exit 0
fi

# Sem mudanças staged (ex: --amend --no-edit, commit --allow-empty) -> libera
if git diff --cached --quiet 2>/dev/null; then
    exit 0
fi

REVIEW_DIR=".deepseek/reviews"

if [ ! -d "$REVIEW_DIR" ]; then
    >&2 echo "[percus:hook pre-commit native] BLOCK: nenhum /percus-review:review encontrado em $REVIEW_DIR/"
    >&2 echo "Rode /percus-review:review antes de commitar (R11)."
    exit 1
fi

# Mais recente .jsonl
LATEST=""
for f in "$REVIEW_DIR"/*.jsonl; do
    [ -e "$f" ] || continue
    if [ -z "$LATEST" ] || [ "$f" -nt "$LATEST" ]; then
        LATEST="$f"
    fi
done

if [ -z "$LATEST" ]; then
    >&2 echo "[percus:hook pre-commit native] BLOCK: pasta $REVIEW_DIR/ vazia"
    >&2 echo "Rode /percus-review:review antes de commitar (R11)."
    exit 1
fi

NOW=$(date +%s)
# stat -c %Y (GNU/Linux/git-bash) com fallback stat -f %m (BSD/macOS)
MTIME=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null)

if [ -z "$MTIME" ]; then
    # Falha graceful: stat indisponivel, libera com warn (alinhado com PS1 try/catch)
    >&2 echo "[percus:hook pre-commit native] WARN: stat falhou, liberando commit. Verifique seu shell."
    exit 0
fi

AGE_SEC=$((NOW - MTIME))
MAX_AGE=300  # 5 min

if [ "$AGE_SEC" -gt "$MAX_AGE" ]; then
    AGE_MIN=$((AGE_SEC / 60))
    >&2 echo "[percus:hook pre-commit native] BLOCK: ultimo /percus-review:review tem $AGE_MIN min (max 5)."
    >&2 echo "Rode /percus-review:review de novo antes de commitar (R11)."
    exit 1
fi

exit 0
