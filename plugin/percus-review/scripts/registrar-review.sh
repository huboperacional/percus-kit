#!/usr/bin/env bash
# registrar-review.sh -- registra no marcador R11 uma review feita fora do cliente DeepSeek
# (ex.: subagente Cross-Claude). Hash igual ao do hook; grava d-<hash>.jsonl e depois latest.jsonl
# por temporario unico + mv. Se a segunda gravacao falhar, remove o d-<hash>.jsonl que nao existia antes
# ou restaura o conteudo anterior do que ja existia (a mensagem do exit 3 diz qual).
#
# Uso: bash registrar-review.sh --arquivo <findings> --canal cross-claude [--modelo <id>] [--repo <dir>]
# Exit: 0 ok | 1 ambiente (jq/git/sha256sum) ou hash vazio | 2 entrada recusada | 3 falha de gravacao.
# Requer jq (FR-014): sem ele sai 1 -- nunca monta JSON na mao.

set -uo pipefail

falha() { echo "[registrar-review] ERRO: $2" >&2; exit "$1"; }

ARQUIVO=""; CANAL=""; MODELO=""; REPO=""
while [ $# -gt 0 ]; do
    case "$1" in
        --arquivo) ARQUIVO="${2:-}"; shift 2 ;;
        --arquivo=*) ARQUIVO="${1#*=}"; shift ;;
        --canal) CANAL="${2:-}"; shift 2 ;;
        --canal=*) CANAL="${1#*=}"; shift ;;
        --modelo) MODELO="${2:-}"; shift 2 ;;
        --modelo=*) MODELO="${1#*=}"; shift ;;
        --repo) REPO="${2:-}"; shift 2 ;;
        --repo=*) REPO="${1#*=}"; shift ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        *) falha 2 "argumento desconhecido: $1" ;;
    esac
done

command -v jq >/dev/null 2>&1 || falha 1 "dependencia 'jq' nao encontrada -- instale jq; nenhum JSON foi gravado"
for c in git sha256sum; do
    command -v "$c" >/dev/null 2>&1 || falha 1 "dependencia '$c' nao encontrada"
done

{ [ -n "$ARQUIVO" ] && [ -f "$ARQUIVO" ]; } || falha 2 "arquivo de findings ausente: '$ARQUIVO'"
[ -n "$(printf '%s' "$CANAL" | tr -d ' \t\r\n')" ] || falha 2 "canal vazio (use --canal cross-claude)"
TAM=$(wc -c < "$ARQUIVO" | tr -d ' \r') || falha 1 "nao consegui medir o tamanho de '$ARQUIVO'"
[ "$((10#$TAM))" -le 262144 ] || falha 2 "findings acima do teto (256 KB): $TAM bytes"

TMPD="$(mktemp -d 2>/dev/null || { d="${TMPDIR:-/tmp}/percus-reg-$$"; mkdir -p "$d" && echo "$d"; })"
trap 'rm -rf "$TMPD"' EXIT
FIND="$TMPD/findings.txt"
if [ "$(head -c3 "$ARQUIVO" | od -An -tx1 | tr -d ' \r\n')" = "efbbbf" ]; then
    tail -c +4 "$ARQUIVO" > "$FIND"
else
    cat "$ARQUIVO" > "$FIND"
fi
[ -n "$(tr -d ' \t\r\n' < "$FIND")" ] || falha 2 "findings vazio ou so espaco"
# So o arquivo que e INTEIRO um objeto placeholder e recusado; texto livre citando deferred passa.
if jq -e 'type == "object" and (.deferred == true or .placeholder == true)' < "$FIND" >/dev/null 2>&1; then
    CAMPO="$(jq -r 'if .deferred == true then "deferred" else "placeholder" end' < "$FIND" 2>/dev/null | tr -d '\r')"
    falha 2 "o arquivo e um placeholder (${CAMPO}:true), nao uma review"
fi
if grep -q '__PERCUS_NEEDS_CROSS_CLAUDE__' "$FIND"; then
    falha 2 "o texto contem o marcador __PERCUS_NEEDS_CROSS_CLAUDE__ -- isso e o pedido de review, nao a review"
fi

BASE_DIR="${REPO:-$PWD}"
[ -d "$BASE_DIR" ] || falha 2 "diretorio do repo nao existe: '$BASE_DIR'"
TOP="$(git -C "$BASE_DIR" rev-parse --show-toplevel 2>/dev/null | tr -d '\r')"
[ -n "$TOP" ] || falha 2 "'$BASE_DIR' nao e um repositorio git"
git -C "$TOP" rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null 2>&1 || falha 2 "$(printf 'reposit\303\263rio sem commit')"

DIFF_TMP="$TMPD/diff.txt"
git -C "$TOP" diff HEAD --output="$DIFF_TMP" 2>/dev/null || falha 1 "git diff HEAD falhou -- hash vazio, nada gravado"
[ -s "$DIFF_TMP" ] || falha 2 "git diff HEAD vazio -- nao ha o que registrar"
HASH="$(sha256sum "$DIFF_TMP" | cut -c1-12)"
{ [ -n "$HASH" ] && [ "$HASH" != "e3b0c44298fc" ]; } || falha 1 "hash vazio -- nada gravado"
DIFF_LINES="$(wc -l < "$DIFF_TMP" | tr -d ' \r')"

REV_DIR="$TOP/.deepseek/reviews"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DOC="$TMPD/doc.json"
jq -nc --arg timestamp "$TS" --argjson diff_lines "$((10#$DIFF_LINES))" --arg model "$MODELO" \
    --rawfile findings "$FIND" --arg canal "$CANAL" \
    '{timestamp: $timestamp, base: "", diff_lines: $diff_lines, model: (if $model == "" then null else $model end), usage: null, findings: $findings, canal: $canal}' \
    2>/dev/null | tr -d '\r' > "$DOC"
[ -s "$DOC" ] || falha 1 "jq nao montou o marcador -- nada gravado"

grava_atomico() {  # $1 origem pronta, $2 destino
    [ -d "$2" ] && return 1
    _t="$2.$$.$RANDOM.tmp"
    cp "$1" "$_t" 2>/dev/null || { rm -f "$_t"; return 1; }
    mv -f "$_t" "$2" 2>/dev/null || { rm -f "$_t"; return 1; }
    return 0
}
mkdir -p "$REV_DIR" 2>/dev/null || falha 3 "nao consegui criar $REV_DIR -- nada gravado"
D_PATH="$REV_DIR/d-$HASH.jsonl"
L_PATH="$REV_DIR/latest.jsonl"
# d-<hash> pre-existente (ex.: review anterior do mesmo diff): copia em $TMPD (o trap remove) antes de
# gravar, para restaurar em vez de apagar.
D_PREV=""
if [ -f "$D_PATH" ]; then
    D_PREV="$TMPD/d-anterior.jsonl"
    cp "$D_PATH" "$D_PREV" 2>/dev/null || falha 3 "nao consegui copiar o d-$HASH.jsonl pre-existente -- nada gravado"
fi
grava_atomico "$DOC" "$D_PATH" || falha 3 "falha ao gravar $D_PATH -- nada gravado"
if ! grava_atomico "$DOC" "$L_PATH"; then
    if [ -z "$D_PREV" ]; then
        rm -f "$D_PATH"
        falha 3 "falha ao gravar $L_PATH -- d-$HASH.jsonl nao existia antes e foi removido"
    fi
    if grava_atomico "$D_PREV" "$D_PATH" && cmp -s "$D_PREV" "$D_PATH"; then
        falha 3 "falha ao gravar $L_PATH -- d-$HASH.jsonl pre-existente restaurado ao conteudo anterior"
    fi
    # Restauracao nao conferida: a copia sai do $TMPD (que o trap apaga) antes de sair.
    GUARDA="$D_PATH.$$.$RANDOM.bak"
    if cp "$D_PREV" "$GUARDA" 2>/dev/null; then
        falha 3 "falha ao gravar $L_PATH -- NAO consegui restaurar o d-$HASH.jsonl pre-existente; o conteudo anterior esta em $GUARDA"
    fi
    trap - EXIT
    falha 3 "falha ao gravar $L_PATH -- NAO consegui restaurar o d-$HASH.jsonl pre-existente; o conteudo anterior esta em $D_PREV"
fi

{
    mkdir -p "$TOP/.deepseek/spend" &&
    jq -nc --arg timestamp "$TS" --arg provider "$CANAL" --arg model "$MODELO" --argjson diff_lines "$((10#$DIFF_LINES))" \
        '{timestamp: $timestamp, tool: "registrar-review", provider: $provider, model: (if $model == "" then null else $model end), usage: null, diff_lines: $diff_lines}' \
        | tr -d '\r' >> "$TOP/.deepseek/spend/$(date -u +%Y-%m).jsonl"
} 2>/dev/null || true

printf 'hash=%s latest=%s d=%s\n' "$HASH" "$L_PATH" "$D_PATH"
exit 0
