#!/usr/bin/env bash
# Hook pre-commit Percus — graceful failure (exit 0 on any error)
#
# v6.7.2 (Proposta F+G, incidente 2026-05-19): detecta repo target do commit
# parseando `cd <dir>`, `git -C <dir>` do comando, e resolve via
# `git rev-parse --show-toplevel`. Diagnostic messages incluem git root + searched.

set +e

# >>> percus-classifica-marcador (copia IDENTICA em hooks/pre-commit-check.sh e git-hooks/pre-commit.template.sh)
# Classifica .deepseek/reviews/*.jsonl sem jq: o hook git nativo nao pode depender dele (FR-018).
# Saida: linha 1 = review|placeholder|invalido; linha 2 = motivo (invalido) ou decision
# (placeholder); linha 3 = reason (placeholder, conteudo JSON-escapado cru). Ordem e textos sao
# contrato com Get-ClasseMarcador em pre-commit-check.ps1 -- mude os tres juntos.
# Programa em heredoc dentro de FUNCAO (heredoc dentro de $(...) parseia mal em bash antigo) e
# passado por tr -d CR (o cache do plugin chega com CRLF).
percus_awk_classifica() {
cat <<'PERCUS_AWK_FIM'
function ws(   c) { while (p <= n) { c = substr(s, p, 1); if (c == " " || c == "\t" || c == "\n" || c == "\r") p++; else break } }
function pstr(   c, st, blank, h) {
  if (substr(s, p, 1) != "\"") return 0
  p++; st = p; blank = 1
  while (p <= n) {
    c = substr(s, p, 1)
    if (c == "\"") { SRAW = substr(s, st, p - st); SBLANK = blank; p++; return 1 }
    if (c == "\\") {
      c = substr(s, p + 1, 1)
      if (c == "n" || c == "t" || c == "r") { p += 2; continue }
      if (c == "\"" || c == "\\" || c == "/" || c == "b" || c == "f") { blank = 0; p += 2; continue }
      if (c == "u") {
        h = tolower(substr(s, p + 2, 4))
        if (h !~ /^[0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/) return 0
        if (h != "0020" && h != "0009" && h != "000a" && h != "000d") blank = 0
        p += 6; continue
      }
      return 0
    }
    if (c != " " && c != "\t" && c != "\n" && c != "\r") blank = 0
    p++
  }
  return 0
}
function pnum(   st, c, tok) {
  st = p
  while (p <= n) { c = substr(s, p, 1); if (index("+-.eE0123456789", c) > 0) p++; else break }
  tok = substr(s, st, p - st)
  if (tok !~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) return 0
  VTYPE = "number"; return 1
}
function parr(depth,   c) {
  p++; ws()
  if (substr(s, p, 1) == "]") { p++; VTYPE = "array"; return 1 }
  while (1) {
    if (!pval(depth + 1)) return 0
    ws(); c = substr(s, p, 1)
    if (c == ",") { p++; continue }
    if (c == "]") { p++; VTYPE = "array"; return 1 }
    return 0
  }
}
function pobj(depth,   c, k) {
  p++; ws()
  if (substr(s, p, 1) == "}") { p++; VTYPE = "object"; return 1 }
  while (1) {
    ws(); if (!pstr()) return 0
    k = SRAW
    ws(); if (substr(s, p, 1) != ":") return 0
    p++
    if (!pval(depth + 1)) return 0
    if (depth == 0) {
      if (k == "findings") { FT = VTYPE; if (VTYPE == "string") FB = SBLANK }
      if (k == "deferred") { DT = VTYPE }
      if (k == "reason") { RT = VTYPE; if (VTYPE == "string") { RB = SBLANK; RR = SRAW } }
      if (k == "decision") { ET = VTYPE; if (VTYPE == "string") { EB = SBLANK; ER = SRAW } }
    }
    ws(); c = substr(s, p, 1)
    if (c == ",") { p++; continue }
    if (c == "}") { p++; VTYPE = "object"; return 1 }
    return 0
  }
}
function pval(depth,   c) {
  ws(); c = substr(s, p, 1)
  if (c == "{") return pobj(depth)
  if (c == "[") return parr(depth)
  if (c == "\"") { if (!pstr()) return 0; VTYPE = "string"; return 1 }
  if (substr(s, p, 4) == "true") { p += 4; VTYPE = "true"; return 1 }
  if (substr(s, p, 5) == "false") { p += 5; VTYPE = "false"; return 1 }
  if (substr(s, p, 4) == "null") { p += 4; VTYPE = "null"; return 1 }
  if (c == "-" || (c >= "0" && c <= "9")) return pnum()
  return 0
}
{ s = s $0 "\n" }
END {
  if (substr(s, 1, 3) == "\357\273\277") s = substr(s, 4)
  n = length(s); p = 1; ws()
  if (p > n) { print "invalido"; print "vazio"; exit }
  if (!pval(0)) { print "invalido"; print "nao e JSON"; exit }
  ws()
  if (p <= n) { print "invalido"; print "nao e JSON"; exit }
  if (VTYPE != "object") { print "invalido"; print "raiz nao e objeto"; exit }
  if (DT == "true" && RT == "string" && RB == 0) {
    gsub(/[\001-\037]/, " ", RR); gsub(/[\001-\037]/, " ", ER)
    print "placeholder"
    if (ET == "string" && EB == 0) print ER; else print "desconhecida"
    print RR
    exit
  }
  if (FT == "") { print "invalido"; print "sem findings nem placeholder"; exit }
  if (FT != "string") { print "invalido"; print "findings nao e string"; exit }
  if (FB == 1) { print "invalido"; print "findings vazio"; exit }
  print "review"
}
PERCUS_AWK_FIM
}
percus_classifica_marcador() {
    _pcm_tam=$(wc -c < "$1" 2>/dev/null | tr -d ' \r')
    if [ -z "$_pcm_tam" ]; then printf 'invalido\nilegivel\n'; return 0; fi
    if [ "$_pcm_tam" -gt 262144 ]; then printf 'invalido\nacima do teto (256 KB)\n'; return 0; fi
    LC_ALL=C awk "$(percus_awk_classifica | tr -d '\r')" "$1"
}
percus_json_escapa() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}
# <<< percus-classifica-marcador

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

# === POLITICA DE RISCO: review por CRITERIO, nao por frequencia (2026-08-19) ===
# Medido: 26 chamadas do conselho em modo review geraram achado em 8 (31%), e os 2 achados
# materiais de uma sessao inteira vieram de diffs que mexiam em LOGICA e CONTRATO -- nenhum de
# commit trivial. Pagar 60-90 s uniformes por beneficio concentrado e o desperdicio.
#
# Conservador de proposito: a dispensa e LISTA FECHADA de extensoes de texto puro. Tudo que nao
# estiver nela exige review, inclusive extensao nova -- a regra inversa ("exige so o que eu
# reconheco como perigoso") deixa o desconhecido passar, que e como enforcement por enumeracao
# ja mordeu este kit duas vezes. Um unico arquivo fora da lista exige review do commit inteiro.
# Linha a linha, com redirecionamento de ARQUIVO. Nao `for _m in $MUDADOS`: isso quebra por
# whitespace e "docs/meu arquivo.md" viraria dois tokens, o primeiro sem extensao -- o hook
# passaria a exigir review de um commit de texto puro. Falha pro lado seguro, mas errado.
# E nao `| while`: pipe roda o corpo em SUBSHELL e o TEM_CODIGO se perderia ao sair. (R11)
_TMP_MUD="${TMPDIR:-/tmp}/percus-mudados-$$"
git -C "$REPO_ROOT" diff HEAD --name-only > "$_TMP_MUD" 2>/dev/null || :
TEM_CODIGO=0
while IFS= read -r _m; do
  [ -n "$_m" ] || continue
  case "$_m" in
    *.md|*.txt|*.rst|*.adoc) ;;
    *) TEM_CODIGO=1; break ;;
  esac
done < "$_TMP_MUD"
_TEVE_MUDANCA=0
[ -s "$_TMP_MUD" ] && _TEVE_MUDANCA=1
rm -f "$_TMP_MUD"
# Silencio: dispensa nao e evento. Aviso a cada commit de texto vira ruido, e ruido e o que
# faz o operador parar de ler os avisos que importam.
if [ "$_TEVE_MUDANCA" = "1" ] && [ "$TEM_CODIGO" = "0" ]; then
  exit 0
fi

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
RECUSADO=""
if command -v sha256sum >/dev/null 2>&1; then
  TMP_DIFF="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-diff-$$")"
  git -C "$REPO_ROOT" diff HEAD --output="$TMP_DIFF" 2>/dev/null || true
  DIFF_HASH=$(sha256sum "$TMP_DIFF" 2>/dev/null | cut -c1-12)
  rm -f "$TMP_DIFF"
  POR_HASH="$REVIEW_DIR/d-$DIFF_HASH.jsonl"
  # e3b0c44298fc = hash do conteudo vazio = sem hash (emenda FR-016).
  if [ -n "$DIFF_HASH" ] && [ "$DIFF_HASH" != "e3b0c44298fc" ] && [ -f "$POR_HASH" ]; then
    H_NOW=$(date +%s)
    H_MTIME=$(stat -c %Y "$POR_HASH" 2>/dev/null || stat -f %m "$POR_HASH" 2>/dev/null)
    if [ -n "$H_MTIME" ] && [ $((H_NOW - H_MTIME)) -le 86400 ]; then
      _CLS=$(percus_classifica_marcador "$POR_HASH")
      _CLASSE=$(printf '%s\n' "$_CLS" | sed -n 1p)
      if [ "$_CLASSE" = "review" ]; then exit 0; fi
      # Classe fora do contrato (classificador nao respondeu) nao vira "recusado:" com motivo
      # vazio: cai no caminho do latest, que avisa e libera (F-c, paridade FR-019).
      if [ "$_CLASSE" = "placeholder" ]; then
        RECUSADO="d-$DIFF_HASH.jsonl recusado: placeholder nao libera por hash"
      elif [ "$_CLASSE" = "invalido" ]; then
        RECUSADO="d-$DIFF_HASH.jsonl recusado: $(printf '%s\n' "$_CLS" | sed -n 2p)"
      fi
    fi
  fi
fi
recusado_context() {
  [ -n "$RECUSADO" ] && echo "  recusado: $RECUSADO" >&2
  return 0
}

# Path fixo latest.jsonl (2026-07-20) -- O(1); fallback ao glob so se ausente.
LATEST="$REVIEW_DIR/latest.jsonl"
[ -f "$LATEST" ] || LATEST=$(ls -t "$REVIEW_DIR"/*.jsonl 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
  echo "[percus:hook pre-commit] BLOCK: $REVIEW_DIR vazia" >&2
  block_context "$REVIEW_DIR"
  recusado_context
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
  recusado_context
  echo "  latest:   $(basename "$LATEST")" >&2
  echo "Rode /percus-review:review de novo (R11)." >&2
  exit 2
fi

_CLS=$(percus_classifica_marcador "$LATEST")
_CLASSE=$(printf '%s\n' "$_CLS" | sed -n 1p)
if [ "$_CLASSE" = "review" ]; then exit 0; fi
if [ "$_CLASSE" = "placeholder" ]; then
  _DEC=$(printf '%s\n' "$_CLS" | sed -n 2p)
  _REA=$(printf '%s\n' "$_CLS" | sed -n 3p)
  echo "[percus:hook pre-commit] AVISO: commit SEM review real -- liberado por placeholder deferido ($(basename "$LATEST"), decision=$_DEC). Registre a review Cross-Claude com registrar-review." >&2
  { printf '{"timestamp":"%s","camada":"pretooluse","repo":"%s","decision":"%s","reason":"%s"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(percus_json_escapa "$REPO_ROOT")" "$_DEC" "$_REA" >> "$REVIEW_DIR/deferidos.log"; } 2>/dev/null || true
  exit 0
fi
# F-c (2026-09-15): 1a linha fora de review|placeholder|invalido = o classificador nao respondeu
# (awk ausente/quebrado). Erro interno do hook, nao veredito sobre o marcador: avisa e libera,
# com o mesmo prefixo do WARN do pre-commit-check.ps1 (FR-019).
if [ "$_CLASSE" != "invalido" ]; then
  echo "[percus:hook pre-commit] WARN: hook crashed, allowing commit. Error: classificador do marcador nao respondeu" >&2
  exit 0
fi
echo "[percus:hook pre-commit] BLOCK: marcador $(basename "$LATEST") invalido: $(printf '%s\n' "$_CLS" | sed -n 2p)" >&2
block_context "$REVIEW_DIR"
recusado_context
echo "Rode /percus-review:review de novo (R11)." >&2
exit 2
