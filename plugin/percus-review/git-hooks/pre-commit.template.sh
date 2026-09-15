#!/bin/sh
# === PERCUS-MERGED-HOOK BEGIN ===
# percus-review pre-commit hook (Layer 2 anti-bypass)
# DO NOT change the marker lines (=== PERCUS-MERGED-HOOK BEGIN/END ===) --
# /percus-review:install-git-hooks usa elas pra distinguir hook Percus puro de
# hibrido (com logica custom apos END) e atualizar so o bloco Percus em re-runs.
#
# Defesa em profundidade vs bypass do PreToolUse:Bash hook (rm && commit encadeado).
# Roda no momento real do git commit -- fecha brecha onde estado muda durante o bash.
# Espelha logica de hooks/pre-commit-check.ps1 (hash 24 h, TTL 5 min, classificacao do marcador, escape PERCUS_HOOKS_DISABLED).
#
# Exit codes: 0 = allow (fall-through ao custom hook se hibrido), 1 = block.
# PS1 layer 1 usa exit 2 (convencao PreToolUse). Diferenca proposital -- cada
# layer fala com runtime diferente.
#
# --amend semantics: liberamos quando 'git diff --cached --quiet' (zero staged)
# -- mais permissivo que PS1 (que so whitelistou '--amend --no-edit' literal).
# Cobre amend trocando msg sem mudar conteudo, --allow-empty, etc.

set -u

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
        RECUSADO=""
        _PERCUS_OK_HASH=""
        if command -v sha256sum >/dev/null 2>&1; then
            TMP_DIFF="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-diff-$$")"
            git diff HEAD --output="$TMP_DIFF" 2>/dev/null || true
            DIFF_HASH=$(sha256sum "$TMP_DIFF" 2>/dev/null | cut -c1-12)
            rm -f "$TMP_DIFF"
            POR_HASH="$REVIEW_DIR/d-$DIFF_HASH.jsonl"
            # e3b0c44298fc = hash do conteudo vazio = sem hash (emenda FR-016).
            if [ -n "$DIFF_HASH" ] && [ "$DIFF_HASH" != "e3b0c44298fc" ] && [ -f "$POR_HASH" ]; then
                H_MTIME=$(stat -c %Y "$POR_HASH" 2>/dev/null || stat -f %m "$POR_HASH" 2>/dev/null)
                if [ -n "$H_MTIME" ] && [ $(( $(date +%s) - H_MTIME )) -le 86400 ]; then
                    _CLS=$(percus_classifica_marcador "$POR_HASH")
                    _CLASSE=$(printf '%s\n' "$_CLS" | sed -n 1p)
                    # Libera SEM exit 0: em hook hibrido a logica custom apos END (ex.: gate V2)
                    # tem de rodar tambem quando o R11 aprova pelo hash (2026-09-15).
                    if [ "$_CLASSE" = "review" ]; then _PERCUS_OK_HASH=1; fi
                    if [ "$_CLASSE" = "placeholder" ]; then _MOT="placeholder nao libera por hash"; else _MOT=$(printf '%s\n' "$_CLS" | sed -n 2p); fi
                    RECUSADO="d-$DIFF_HASH.jsonl recusado: $_MOT"
                fi
            fi
        fi

        if [ -z "$_PERCUS_OK_HASH" ]; then
        # Path FIXO latest.jsonl (2026-07-20): o wrapper sobrescreve sempre o
        # mesmo arquivo, entao o hook le UM path conhecido -- O(1), sem stat em N.
        # Compat: wrapper antigo deixou <ts>.jsonl -> fallback pega o mais novo.
        LATEST="$REVIEW_DIR/latest.jsonl"
        if [ ! -f "$LATEST" ]; then
            LATEST=$(ls -t "$REVIEW_DIR"/*.jsonl 2>/dev/null | head -1)
        fi

        if [ -z "$LATEST" ]; then
            >&2 echo "[percus:hook pre-commit native] BLOCK: pasta $REVIEW_DIR/ vazia"
            [ -n "$RECUSADO" ] && >&2 echo "  recusado: $RECUSADO"
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
                [ -n "$RECUSADO" ] && >&2 echo "  recusado: $RECUSADO"
                >&2 echo "Rode /percus-review:review de novo antes de commitar (R11)."
                exit 1
            fi
        fi

        _CLS=$(percus_classifica_marcador "$LATEST")
        _CLASSE=$(printf '%s\n' "$_CLS" | sed -n 1p)
        if [ "$_CLASSE" = "placeholder" ]; then
            _DEC=$(printf '%s\n' "$_CLS" | sed -n 2p)
            _REA=$(printf '%s\n' "$_CLS" | sed -n 3p)
            >&2 echo "[percus:hook pre-commit native] AVISO: commit SEM review real -- liberado por placeholder deferido ($(basename "$LATEST"), decision=$_DEC). Registre a review Cross-Claude com registrar-review."
            _TOP=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
            { printf '{"timestamp":"%s","camada":"git-hook","repo":"%s","decision":"%s","reason":"%s"}\n' \
                "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(percus_json_escapa "$_TOP")" "$_DEC" "$_REA" >> "$REVIEW_DIR/deferidos.log"; } 2>/dev/null || true
        elif [ "$_CLASSE" != "review" ]; then
            >&2 echo "[percus:hook pre-commit native] BLOCK: marcador $(basename "$LATEST") invalido: $(printf '%s\n' "$_CLS" | sed -n 2p)"
            [ -n "$RECUSADO" ] && >&2 echo "  recusado: $RECUSADO"
            >&2 echo "Rode /percus-review:review de novo antes de commitar (R11)."
            exit 1
        fi
        fi # _PERCUS_OK_HASH
    fi
fi
# === PERCUS-MERGED-HOOK END ===

# Hook Percus puro (sem custom logic). /percus-review:install-git-hooks substitui
# este 'exit 0' pelo conteudo do hook custom existente quando opera em modo hibrido.
exit 0
