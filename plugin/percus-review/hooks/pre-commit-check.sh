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

# === VALIDADE POR CONTEUDO, ANTES DA VALIDADE POR TEMPO (2026-08-19) ===
# Se existe marcador pro hash do diff ATUAL, a review cobre exatamente este codigo -- libera
# sem olhar relogio. Tempo nunca foi proxy de "isto foi revisado": a janela de 5 min forcava
# re-review do MESMO diff depois de rodar a suite, e no sentido inverso deixava commitar
# codigo editado depois da review, desde que dentro da janela.
#
# `git diff HEAD` (nao --cached) porque ele NAO muda no `git add`: assim o fluxo
# editar -> revisar -> stage -> commit nao invalida a review no meio do caminho.
#
# O `tr -d ''` e o `$(...)` (que corta newline final) existem pra bater byte a byte com o
# irmao PowerShell, que faz -join "`n" e -replace "`r". Hash divergente entre os dois runtimes
# seria falha silenciosa: o hook simplesmente nunca acharia o marcador e cairia no caminho
# antigo sem dizer por que.
#
# Lookup DIRETO pelo nome: O(1), sem enumerar o diretorio.
if command -v sha256sum >/dev/null 2>&1; then
  # Hash do ARQUIVO escrito por `git diff --output=`, nunca da saida capturada pelo shell --
  # ver o comentario gemeo no deepseek-review.sh. Shell diferente decodifica diferente; git
  # escrevendo o arquivo elimina a variavel.
  TMP_DIFF="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-diff-$$")"
  # `-C "$REPO_ROOT"` e obrigatorio: o hook roda no cwd do agente, nao no repo alvo. Sem
  # ele o hash sai do diff do diretorio errado, nunca casa com o marcador, e a otimizacao
  # vira codigo morto que sempre cai no fallback -- falha silenciosa.
  git -C "$REPO_ROOT" diff HEAD --output="$TMP_DIFF" 2>/dev/null || true
  DIFF_HASH=$(sha256sum "$TMP_DIFF" 2>/dev/null | cut -c1-12)
  rm -f "$TMP_DIFF"
  POR_HASH="$REVIEW_DIR/d-$DIFF_HASH.jsonl"
  # -n no hash: sem ele, git falhando faria o hook procurar "d-.jsonl" -- que o lado escritor
  # ja nao cria mais, mas o par tem que ser simetrico pra nao reabrir a brecha por um lado so.
  if [ -n "$DIFF_HASH" ] && [ -f "$POR_HASH" ]; then
    H_NOW=$(date +%s)
    H_MTIME=$(stat -c %Y "$POR_HASH" 2>/dev/null || stat -f %m "$POR_HASH" 2>/dev/null)
    if [ $((H_NOW - H_MTIME)) -le 86400 ]; then
      exit 0
    fi
  fi
fi

# Path fixo latest.jsonl (2026-07-20) -- O(1); fallback ao glob so se ausente.
LATEST="$REVIEW_DIR/latest.jsonl"
[ -f "$LATEST" ] || LATEST=$(ls -t "$REVIEW_DIR"/*.jsonl 2>/dev/null | head -1)
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
