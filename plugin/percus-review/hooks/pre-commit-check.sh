#!/usr/bin/env bash
# Hook pre-commit Percus — graceful failure (exit 0 on any error)
#
# v6.7.2 (Proposta F+G, incidente 2026-05-19): detecta repo target do commit
# parseando `cd <dir>`, `git -C <dir>` do comando, e resolve via
# `git rev-parse --show-toplevel`. Diagnostic messages incluem git root + searched.

set +e

STDIN=$(cat)
[ -z "$STDIN" ] && exit 0

COMMAND=$(echo "$STDIN" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Non-commit
if ! echo "$COMMAND" | grep -qE '\bgit[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?commit\b'; then exit 0; fi

# Amend no-edit (rebase)
if echo "$COMMAND" | grep -qE '\bgit[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?commit[[:space:]]+--amend[[:space:]]+--no-edit\b'; then exit 0; fi

# Escape
if [ -n "${PERCUS_HOOKS_DISABLED:-}" ]; then exit 0; fi

# Resolver repo target do commit
extract_target() {
  local cmd="$1"
  local m
  # git -C <dir> ... commit
  m=$(echo "$cmd" | sed -nE 's/.*\bgit[[:space:]]+-C[[:space:]]+(\"([^\"]+)\"|'\''([^'\'']+)'\''|([^[:space:]]+))[[:space:]]+.*\bcommit\b.*/\2\3\4/p' | head -1)
  if [ -n "$m" ]; then echo "$m"; return; fi
  # cd <dir> && git commit  (ou ;)
  m=$(echo "$cmd" | sed -nE 's/.*\bcd[[:space:]]+(\"([^\"]+)\"|'\''([^'\'']+)'\''|([^[:space:]]+))[[:space:]]*(\&\&|;).*/\2\3\4/p' | head -1)
  if [ -n "$m" ]; then echo "$m"; return; fi
}

CWD="$(pwd)"
TARGET=$(extract_target "$COMMAND")
[ -z "$TARGET" ] && TARGET="$CWD"

REPO_ROOT=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && REPO_ROOT="$TARGET"

REVIEW_DIR="$REPO_ROOT/.deepseek/reviews"

block_context() {
  local searched="$1"
  echo "  git root: $REPO_ROOT" >&2
  if [ "$CWD" != "$REPO_ROOT" ]; then
    echo "  cwd:      $CWD" >&2
  fi
  echo "  searched: $searched" >&2
}

if [ ! -d "$REVIEW_DIR" ]; then
  echo "[percus:hook pre-commit] BLOCK: nenhum /percus-review:review em .deepseek/reviews/ do repo target" >&2
  block_context "$REVIEW_DIR"
  echo "Rode /percus-review:review do repo target antes de commitar (R11)." >&2
  exit 2
fi

LATEST=$(ls -t "$REVIEW_DIR"/*.jsonl 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
  echo "[percus:hook pre-commit] BLOCK: $REVIEW_DIR vazia" >&2
  block_context "$REVIEW_DIR"
  echo "Rode /percus-review:review do repo target antes de commitar (R11)." >&2
  exit 2
fi

# Age in seconds (300 = 5 min)
NOW=$(date +%s)
MTIME=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null)
AGE=$((NOW - MTIME))

if [ $AGE -gt 300 ]; then
  AGE_MIN=$(( AGE / 60 ))
  echo "[percus:hook pre-commit] BLOCK: ultimo review tem $AGE_MIN min (max 5)" >&2
  block_context "$REVIEW_DIR"
  echo "  latest:   $(basename "$LATEST")" >&2
  echo "Rode /percus-review:review de novo (R11)." >&2
  exit 2
fi

exit 0
