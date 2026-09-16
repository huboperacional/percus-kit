#!/bin/sh
# === PERCUS-MERGED-HOOK BEGIN ===
# percus-review pre-push hook (R20, camada 2)
# DO NOT change the marker lines (=== PERCUS-MERGED-HOOK BEGIN/END ===) --
# git-hooks/instalar-pre-push.sh usa elas pra distinguir hook Percus puro de
# hibrido (com logica custom apos END) e atualizar so o bloco Percus em re-runs.
#
# Por que existe (Fase 5, 2026-09-16): a camada 1 (external-action-guard, PreToolUse) casa o
# comando por TEXTO, e a revisao de seguranca achou 20+ formas de push que passam sem autorizacao
# (`git "push"`, `git -c alias.x=push x`, `git 2>/dev/null push`, `git${IFS}push`...). Texto nunca
# fecha ofuscacao. Este hook fecha, porque quem o executa e o proprio git, em TODO push, qualquer
# que tenha sido a grafia do comando.
#
# Contrato: exige .percus/acao-externa-autorizada.json na raiz do checkout (o mesmo arquivo que
# scripts/autorizar-acao-externa.ps1 cria e o guard aceita), JSON valido, com "id" e "motivo"
# string e "timestamp_unix" inteiro a menos de 3600 s e nao no futuro. Com autorizacao valida,
# grava UMA linha em .percus/autorizacoes-usadas.jsonl (origem "pre-push", remoto e refs lidos do
# stdin do hook). Sem gravar a auditoria, NAO libera: a auditoria e parte do gate R20.
#
# NAO ha escape por variavel de ambiente, de proposito: PERCUS_EXTERNAL_OVERRIDE /
# PERCUS_HOOKS_DISABLED escritos na frente do comando (`X=1 git push`) chegariam ate aqui e
# reabririam por TEXTO o buraco que este hook fecha.
#
# LIMITE DECLARADO: `git push --no-verify` e `git -c core.hooksPath=<outro> push` nao executam
# este hook. Quem barra essas formas e a camada 1 (guard) -- por isso ela continua existindo.
#
# Exit codes: 1 = block; allow = fall-through ao custom hook (se hibrido) ou ao `exit 0` do fim.
# Sem jq e sem python: o parser JSON e awk estrito (awk vem com todo git-bash).

set -u

PERCUS_PP_TAG="[percus:hook pre-push native]"

# stdin do git: "<local ref> <local sha> <remote ref> <remote sha>" por linha. Lido INTEIRO antes de
# qualquer decisao (git escreve nele; nao ler pode travar o push em pipe cheio).
_pp_stdin=$(cat)

percus_pp_bloqueia() {
    >&2 echo "$PERCUS_PP_TAG BLOCK (R20): $1"
    >&2 echo "  Push exige autorizacao explicita do operador, valida por 60 min."
    >&2 echo "  Depois da confirmacao dele na conversa, na raiz do repo:"
    >&2 echo "    powershell -NoProfile -File <percus-kit>/scripts/autorizar-acao-externa.ps1 -Motivo \"<motivo>\" -ProjetoRoot \"<raiz do repo>\""
    >&2 echo "  (cria .percus/acao-externa-autorizada.json; o push seguinte e auditado em .percus/autorizacoes-usadas.jsonl)"
    exit 1
}

# >>> percus-pp-le-autorizacao
# Parser JSON estrito (mesma familia do percus-classifica-marcador do pre-commit). Saida:
# linha 1 = ok|invalido; ok: linha 2 = timestamp_unix, linha 3 = id cru, linha 4 = motivo cru
# (conteudo JSON-escapado, reemitivel entre aspas); invalido: linha 2 = motivo da recusa.
percus_pp_awk() {
cat <<'PERCUS_PP_AWK_FIM'
function ws(   c) { while (p <= n) { c = substr(s, p, 1); if (c == " " || c == "\t" || c == "\n" || c == "\r") p++; else break } }
function pstr(   c, st, blank, h) {
  if (substr(s, p, 1) != "\"") return 0
  p++; st = p; blank = 1
  while (p <= n) {
    c = substr(s, p, 1)
    if (c == "\"") { SRAW = substr(s, st, p - st); SBLANK = blank; p++; return 1 }
    if (c < " ") return 0
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
    if (c != " ") blank = 0
    p++
  }
  return 0
}
function pnum(   st, c) {
  st = p
  while (p <= n) { c = substr(s, p, 1); if (index("+-.eE0123456789", c) > 0) p++; else break }
  NTOK = substr(s, st, p - st)
  if (NTOK !~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) return 0
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
  if (depth > 32) return 0
  p++; ws()
  if (substr(s, p, 1) == "}") { p++; VTYPE = "object"; return 1 }
  while (1) {
    ws(); if (!pstr()) return 0
    k = SRAW
    ws(); if (substr(s, p, 1) != ":") return 0
    p++
    if (!pval(depth + 1)) return 0
    if (depth == 0) {
      if (k in VISTO) DUP = 1
      VISTO[k] = 1
      if (k == "timestamp_unix") { TT = VTYPE; if (VTYPE == "number") TV = NTOK }
      if (k == "id") { IT = VTYPE; if (VTYPE == "string") { IB = SBLANK; IV = SRAW } }
      if (k == "motivo") { MT = VTYPE; if (VTYPE == "string") { MB = SBLANK; MV = SRAW } }
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
  if (c == "[") { if (depth > 32) return 0; return parr(depth) }
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
  if (p > n) { print "invalido"; print "arquivo vazio"; exit }
  if (!pval(0)) { print "invalido"; print "nao e JSON"; exit }
  ws()
  if (p <= n) { print "invalido"; print "nao e JSON"; exit }
  if (VTYPE != "object") { print "invalido"; print "raiz nao e objeto"; exit }
  if (DUP == 1) { print "invalido"; print "chave duplicada"; exit }
  if (TT != "number" || TV !~ /^[0-9]+$/ || length(TV) > 12) { print "invalido"; print "timestamp_unix ausente ou nao e inteiro"; exit }
  if (IT != "string" || IB == 1) { print "invalido"; print "id ausente ou vazio"; exit }
  if (MT != "string" || MB == 1) { print "invalido"; print "motivo ausente ou vazio"; exit }
  print "ok"; print TV; print IV; print MV
}
PERCUS_PP_AWK_FIM
}
# <<< percus-pp-le-autorizacao

percus_pp_json_escapa() {
    # Controle fora (tr), depois \ e " escapados. Entrada de git: nome de remoto, URL, refs, sha.
    printf '%s' "$1" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

percus_pp_mascara_url() {
    # Credencial em URL (https://TOKEN@host, https://u:senha@host) -- mesma regra 1 do guard.
    printf '%s' "$1" | sed 's#://[^/@[:space:]]*@#://***@#g'
}

_pp_top=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
[ -n "$_pp_top" ] || percus_pp_bloqueia "nao consegui resolver a raiz do repo (git rev-parse --show-toplevel)"

_pp_auth="$_pp_top/.percus/acao-externa-autorizada.json"
_pp_log="$_pp_top/.percus/autorizacoes-usadas.jsonl"

[ -e "$_pp_auth" ] || percus_pp_bloqueia "sem autorizacao: $_pp_auth nao existe"
[ -f "$_pp_auth" ] && [ -r "$_pp_auth" ] || percus_pp_bloqueia "autorizacao ilegivel: $_pp_auth"
_pp_tam=$(wc -c < "$_pp_auth" 2>/dev/null | tr -d ' \r')
[ -n "$_pp_tam" ] || percus_pp_bloqueia "autorizacao ilegivel: $_pp_auth"
[ "$_pp_tam" -le 65536 ] 2>/dev/null || percus_pp_bloqueia "autorizacao acima do teto (64 KB)"

_pp_cls=$(LC_ALL=C awk "$(percus_pp_awk | tr -d '\r')" "$_pp_auth" 2>/dev/null)
_pp_classe=$(printf '%s\n' "$_pp_cls" | sed -n 1p)
if [ "$_pp_classe" = "invalido" ]; then
    percus_pp_bloqueia "autorizacao invalida: $(printf '%s\n' "$_pp_cls" | sed -n 2p)"
fi
# Qualquer coisa que nao seja "ok" (awk ausente, quebrado, saida truncada) BLOQUEIA.
[ "$_pp_classe" = "ok" ] || percus_pp_bloqueia "nao consegui ler a autorizacao (parser nao respondeu)"

_pp_ts=$(printf '%s\n' "$_pp_cls" | sed -n 2p)
_pp_id=$(printf '%s\n' "$_pp_cls" | sed -n 3p)
_pp_motivo=$(printf '%s\n' "$_pp_cls" | sed -n 4p)

_pp_agora=$(date +%s 2>/dev/null)
case "$_pp_agora" in
    ''|*[!0-9]*) percus_pp_bloqueia "relogio indisponivel (date +%s)" ;;
esac
# Epoch puro, como no guard: imune a fuso e horario de verao.
_pp_idade=$((_pp_agora - _pp_ts))
[ "$_pp_idade" -ge 0 ] || percus_pp_bloqueia "autorizacao com timestamp_unix no futuro ($((0 - _pp_idade)) s adiante)"
[ "$_pp_idade" -lt 3600 ] || percus_pp_bloqueia "autorizacao expirada (idade $((_pp_idade / 60)) min, janela 60 min)"

# --- auditoria (parte do contrato: sem linha gravada, sem push) ---
_pp_remoto=$(percus_pp_json_escapa "${1:-}")
_pp_url=$(percus_pp_json_escapa "$(percus_pp_mascara_url "${2:-}")")
_pp_refs=""
_pp_nl='
'
_pp_resto="$_pp_stdin"
while [ -n "$_pp_resto" ]; do
    case "$_pp_resto" in
        *"$_pp_nl"*) _pp_linha=${_pp_resto%%"$_pp_nl"*}; _pp_resto=${_pp_resto#*"$_pp_nl"} ;;
        *) _pp_linha=$_pp_resto; _pp_resto="" ;;
    esac
    _pp_linha=$(printf '%s' "$_pp_linha" | tr -d '\r')
    [ -n "$_pp_linha" ] || continue
    # read, nao `set --`: os parametros posicionais ($1 remoto, $2 url) sao do custom hook no
    # modo hibrido e nao podem ser sobrescritos; read tambem nao expande glob.
    IFS=' ' read -r _pp_lref _pp_lsha _pp_rref _pp_rsha _pp_sobra <<PERCUS_PP_LINHA_FIM
$_pp_linha
PERCUS_PP_LINHA_FIM
    _pp_item=$(printf '{"local_ref":"%s","local_sha":"%s","remote_ref":"%s","remote_sha":"%s"}' \
        "$(percus_pp_json_escapa "${_pp_lref:-}")" "$(percus_pp_json_escapa "${_pp_lsha:-}")" \
        "$(percus_pp_json_escapa "${_pp_rref:-}")" "$(percus_pp_json_escapa "${_pp_rsha:-}")")
    if [ -z "$_pp_refs" ]; then _pp_refs="$_pp_item"; else _pp_refs="$_pp_refs,$_pp_item"; fi
done

_pp_quando=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
[ -n "$_pp_quando" ] || percus_pp_bloqueia "relogio indisponivel para a auditoria (date -u)"
_pp_linhalog=$(printf '{"id":"%s","motivo":"%s","comando":"git push %s %s","quando":"%s","origem":"pre-push","remoto":"%s","url":"%s","refs":[%s]}' \
    "$_pp_id" "$_pp_motivo" "$_pp_remoto" "$_pp_url" "$_pp_quando" "$_pp_remoto" "$_pp_url" "$_pp_refs")

# \r\n como o guard e o registrar-uso-autorizacao.ps1: os tres escrevem no MESMO .jsonl.
if ! printf '%s\r\n' "$_pp_linhalog" 2>/dev/null >> "$_pp_log"; then
    percus_pp_bloqueia "autorizacao valida (id $_pp_id), mas nao consegui gravar a auditoria em $_pp_log -- libere a escrita e repita"
fi

>&2 echo "$PERCUS_PP_TAG autorizacao ativa (id $_pp_id, idade $((_pp_idade / 60)) min) -- push auditado em .percus/autorizacoes-usadas.jsonl"

# Devolve o stdin ao custom hook (modo hibrido): ele pode querer ler as refs tambem.
if [ -n "$_pp_stdin" ]; then
exec 0<<PERCUS_PP_STDIN_FIM
$_pp_stdin
PERCUS_PP_STDIN_FIM
else
    exec 0</dev/null
fi
# set -u e do bloco Percus, nao do custom: em modo hibrido o corpo custom roda depois daqui e
# nao pode herdar um `set -u` que nunca pediu.
set +u
# === PERCUS-MERGED-HOOK END ===

# Tudo abaixo do END so existe no template puro (modo NOVO). Nos modos HIBRIDO e GERIDO o
# instalador usa apenas o bloco BEGIN..END do template, e abaixo do END fica o corpo do hook
# existente.
exit 0
