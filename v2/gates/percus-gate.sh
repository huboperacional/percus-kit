#!/bin/sh
# percus-gate -- verificacao mecanica dos tetos do canon V2.
#
# Filosofia (CONSTITUICAO Sec. 6): regra que depende de alguem lembrar ja falhou.
# Este script e o gate. Ele mede TAMANHO, nao delta -- foi medir delta que deixou
# um HANDOFF real chegar a 6.185 linhas.
#
# Uso:   sh gates/percus-gate.sh            (roda na raiz do repo alvo)
# Escape declarado e LOGADO:
#        PERCUS_GATE_OVERSIZE="motivo" git commit ...
#
# Checagem que nao se aplica ao repo (arquivo ausente) e simplesmente pulada,
# entao o mesmo script serve para o canon e para um projeto.

set -u

FAIL=0
LOGDIR=".percus"
ESCAPE="${PERCUS_GATE_OVERSIZE:-}"

log_escape() {
  mkdir -p "$LOGDIR" 2>/dev/null || true
  printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$ESCAPE" >> "$LOGDIR/gate-escapes.log"
}

violacao() { # $1 = mensagem
  if [ -n "$ESCAPE" ]; then
    log_escape "$1"
    printf '  AVISO (escape declarado): %s\n' "$1" >&2
  else
    printf '  BLOQUEADO: %s\n' "$1" >&2
    FAIL=1
  fi
}

# ---------- 1. Tetos de tamanho ----------
checar_tamanho() { # $1 = padrao  $2 = teto  $3 = por que
  for f in $1; do
    [ -f "$f" ] || continue
    n=$(wc -l < "$f" | tr -d ' ')
    if [ "$n" -gt "$2" ]; then
      violacao "$f tem $n linhas (teto $2) -- $3"
    fi
  done
}

checar_tamanho "loops/*.md"      60  "loop tem UM trabalho; o excedente e referencia, mova em vez de comprimir"
checar_tamanho "CONSTITUICAO.md" 80  "constituicao guarda invariante, nao procedimento"
checar_tamanho "HANDOFF.md"     150  "HANDOFF descreve o presente; historico vai para docs/historico/"
checar_tamanho "CONTEXT.md"     150  "CONTEXT e glossario, nao especificacao"

# ---------- 2. Verbete de conhecimento orfao do indice ----------
for f in conhecimento/*.md referencia/conhecimento/*.md; do
  [ -f "$f" ] || continue
  # Ignora exemplos: linhas em code fence (```) ou blockquote (>) nao sao verbete real.
  orfaos=$(awk '/^[[:space:]]*(> )?```/{fence=!fence; next} fence{next} /^[[:space:]]*>/{next} {print}' "$f" \
           | grep -oE '\{#[a-z0-9-]+\}' 2>/dev/null | tr -d '{}#' | sort -u \
           | while read -r a; do grep -qF "(#$a)" "$f" || echo "$a"; done)
  for a in $orfaos; do
    violacao "$f -- verbete #$a existe mas nao esta no indice (escrito e invisivel)"
  done
done

# ---------- 3. Verbete sem linha tags: (invisivel a busca) ----------
for f in conhecimento/*.md referencia/conhecimento/*.md; do
  [ -f "$f" ] || continue
  sem_tags=$(awk '
    /^[[:space:]]*(> )?```/ { fence = !fence; next }
    fence { next }
    /^[[:space:]]*>/ { next }
    /^## .*\{#/ { if (p != "") print p; p=$0; c=0; next }
    p != "" { c++; if ($0 ~ /^`tags:/) p=""; else if (c >= 4) { print p; p="" } }
    END { if (p != "") print p }
  ' "$f" | grep -oE '\{#[a-z0-9-]+\}' | tr -d '{}#')
  for a in $sem_tags; do
    violacao "$f -- verbete #$a sem linha tags: (a busca de conhecimento nao acha)"
  done
done

# ---------- Resultado ----------
if [ "$FAIL" -ne 0 ]; then
  printf '\n  Gate Percus V2 barrou o commit.\n' >&2
  printf '  Corrija, ou declare o motivo:  PERCUS_GATE_OVERSIZE="por que" git commit ...\n' >&2
  printf '  Escape reincidente vira achado do loops/drift.md -- e sinal de desenho errado.\n\n' >&2
  exit 1
fi

exit 0
