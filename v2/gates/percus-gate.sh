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
# HANDOFF/CONTEXT: o layout canonico e a raiz, mas projeto que os guarda em docs/
# nao pode escapar do teto (achado da sessao fria Paid Midia, 2026-07-21: docs/HANDOFF.md
# de 245 linhas passava calado -- glob so de raiz + '[ -f ] || continue' pulava sem avisar).
# Gate que so dispara no caminho abencoado e o proprio "depende de alguem lembrar" (Sec. 6).
checar_tamanho "HANDOFF.md docs/HANDOFF.md" 150  "HANDOFF descreve o presente; historico vai para docs/historico/"
checar_tamanho "CONTEXT.md docs/CONTEXT.md" 150  "CONTEXT e glossario, nao especificacao"

# ---------- 1b. Teto AGREGADO do nucleo + contagem de loops ----------
# Achado do conselho (Cross-Claude, 2026-07-20): teto por-arquivo sem teto
# agregado nao elimina volume -- DESLOCA. Todo arquivo passa e o nucleo cresce
# do 9o ao 15o loop; o boot volta como custo de ROTEAMENTO (o agente tem que
# acertar qual loop carregar, e errar e retrabalho que metrica nenhuma captura).
# Este bloco fecha o buraco: mede a SOMA e o NUMERO.
# O nucleo mora em loops/ (quando se roda de dentro do V2) ou em v2/loops/
# (quando se roda da raiz do canon). Procurar so um dos dois fazia a checagem
# passar calada -- foi o que aconteceu no primeiro teste deste bloco.
NUCLEO=""
[ -d loops ] && NUCLEO="."
[ -d v2/loops ] && NUCLEO="v2"
if [ -n "$NUCLEO" ]; then
  n_loops=$(ls "$NUCLEO"/loops/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$n_loops" -gt 10 ]; then
    violacao "$n_loops loops (teto 10) -- loop novo compete por atencao com os 8; funde ou promove a referencia"
  fi
  soma=$(cat "$NUCLEO"/CONSTITUICAO.md "$NUCLEO"/loops/*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$soma" -gt 600 ]; then
    violacao "nucleo (constituicao + loops) tem $soma linhas (teto 600) -- o V1 morreu assim, um arquivo aceitavel por vez"
  fi
fi

# ---------- 2. Verbete de conhecimento orfao do indice ----------
# NOTA de manutencao: o criterio de fence estrito (^``` na coluna 0) se repete nos
# blocos 2, 3 e 3b. Extrair em funcao POSIX sh custa mais legibilidade do que paga
# aqui -- mas se o criterio mudar de novo, mude nos TRES blocos.
for f in conhecimento/*.md referencia/conhecimento/*.md; do
  [ -f "$f" ] || continue
  # Verbete real = linha de TITULO (^## ) fora de bloco de codigo.
  # Fence ESTRITO (^``` na coluna 0): o padrao antigo casava tambem fence indentado e
  # dentro de blockquote, o toggle dessincronizava e o gate ficava CEGO do ponto em
  # diante — medido 2026-07-29: via 33 de 105 verbetes e saia exit 0 por nao olhar.
  # ^## ja exclui blockquote por construcao (linha comeca com '>').
  orfaos=$(awk '/^```/{fence=!fence; next} fence{next} /^## .*\{#/{print}' "$f" 2>/dev/null \
           | grep -oE '\{#[^}]+\}' | tr -d '{}#' | sort -u \
           | while read -r a; do grep -qF "(#$a)" "$f" || echo "$a"; done)
  for a in $orfaos; do
    violacao "$f -- verbete #$a existe mas nao esta no indice (escrito e invisivel)"
  done
done

# ---------- 3. Verbete sem linha tags: (invisivel a busca) ----------
for f in conhecimento/*.md referencia/conhecimento/*.md; do
  [ -f "$f" ] || continue
  # Skip de blockquote (^[[:space:]]*>) fica SO neste bloco: sem ele, linhas de
  # citacao antes do tags: real consomem a janela de 4 linhas e o gate acusa "sem
  # tags:" um verbete que TEM tags -- bloqueio de commit legitimo (achado do review,
  # 2026-07-29). O que cegava o gate era o FENCE, nao o blockquote; o fence estrito
  # ja resolve isso sozinho.
  sem_tags=$(awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^[[:space:]]*>/ { next }
    /^## .*\{#/ { if (p != "") print p; p=$0; c=0; next }
    # Crase em tags: e OPCIONAL de proposito ("`?"): 18 dos ~105 verbetes reais
    # escrevem "tags:" sem crase e sao encontraveis. Nao tire o "?" achando sobra.
    p != "" { c++; if ($0 ~ /^`?tags:/) p=""; else if (c >= 4) { print p; p="" } }
    END { if (p != "") print p }
  ' "$f" | grep -oE '\{#[^}]+\}' | tr -d '{}#')
  for a in $sem_tags; do
    violacao "$f -- verbete #$a sem linha tags: (a busca de conhecimento nao acha)"
  done
done

# ---------- 3b. Bloco de codigo aberto e nunca fechado ----------
# Fence sem par cega os blocos 2 e 3 dali pra frente. Acusar e obrigatorio: gate que
# para de olhar no meio do arquivo e pior que gate com falso positivo (2026-07-29).
for f in conhecimento/*.md referencia/conhecimento/*.md; do
  [ -f "$f" ] || continue
  aberto=$(awk '/^```/{fence=!fence; if (fence) linha=NR} END{print (fence ? linha : 0)}' "$f")
  if [ "$aberto" -gt 0 ]; then
    violacao "$f -- bloco de codigo aberto na linha $aberto e nunca fechado (o gate fica cego dali pra frente)"
  fi
done

# ---------- Resultado ----------
if [ "$FAIL" -ne 0 ]; then
  printf '\n  Gate Percus V2 barrou o commit.\n' >&2
  printf '  Corrija, ou declare o motivo:  PERCUS_GATE_OVERSIZE="por que" git commit ...\n' >&2
  printf '  Escape reincidente vira achado do loops/drift.md -- e sinal de desenho errado.\n\n' >&2
  exit 1
fi

exit 0
