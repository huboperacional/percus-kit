#!/usr/bin/env bash
# Hook pre-commit Percus — graceful failure (exit 0 on any error)

set +e

STDIN=$(cat)
[ -z "$STDIN" ] && exit 0

COMMAND=$(echo "$STDIN" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Non-commit
if ! echo "$COMMAND" | grep -qE '\bgit[[:space:]]+commit\b'; then exit 0; fi

# Amend no-edit (rebase)
if echo "$COMMAND" | grep -qE '\bgit[[:space:]]+commit[[:space:]]+--amend[[:space:]]+--no-edit\b'; then exit 0; fi

# Escape
if [ -n "${PERCUS_HOOKS_DISABLED:-}" ]; then exit 0; fi

REVIEW_DIR=".deepseek/reviews"
if [ ! -d "$REVIEW_DIR" ]; then
  echo "[percus:hook pre-commit] BLOCK: nenhum /percus-review:review em $REVIEW_DIR" >&2
  echo "Rode /percus-review:review antes de commitar (R11)." >&2
  exit 2
fi

LATEST=$(ls -t "$REVIEW_DIR"/*.jsonl 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
  echo "[percus:hook pre-commit] BLOCK: $REVIEW_DIR vazia" >&2
  echo "Rode /percus-review:review antes de commitar (R11)." >&2
  exit 2
fi

# Age in seconds (300 = 5 min)
NOW=$(date +%s)
MTIME=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null)
AGE=$((NOW - MTIME))

if [ $AGE -gt 300 ]; then
  AGE_MIN=$(( AGE / 60 ))
  echo "[percus:hook pre-commit] BLOCK: ultimo review tem $AGE_MIN min (max 5)" >&2
  echo "Rode /percus-review:review de novo (R11)." >&2
  exit 2
fi

exit 0
