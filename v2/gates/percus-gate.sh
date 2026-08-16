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

# ---------- 3c. Caixa de entrada de conhecimento (um verbete por arquivo) ----------
# Antes de aferir CONTEUDO, aferir POSICAO: o glob abaixo so enxerga entrada/<area>/<slug>.md.
# Um .md em subpasta de area valida, ou solto na raiz da caixa, escapa do gate E do mesclador
# -- escrito e invisivel PARA SEMPRE, que e exatamente o que este bloco existe pra impedir.
# LEIA-ME.md fica de fora por ser a documentacao da caixa, nao verbete.
# NAO usar -mindepth/-maxdepth aqui: sao opcoes GLOBAIS do find, nao predicados, e dentro de
# \( \) elas nao filtram nada -- a primeira versao disto acusava ate o proprio LEIA-ME.md.
# O for (e nao 'find | while') tambem e de proposito: pipeline roda em subshell e o FAIL=1
# de dentro do violacao se perderia, deixando o gate acusar e ainda assim sair 0.
if [ -d conhecimento/entrada ]; then
  # IFS so em quebra de linha: sem isso o word splitting do $(find) parte caminho com espaco
  # em varios argumentos e a checagem de posicao afere pedaco de nome (R11, 2026-08-16).
  _ifs_old=$IFS
  IFS='
'
  for x in $(find conhecimento/entrada -type f -name '*.md' 2>/dev/null); do
    IFS=$_ifs_old
    rel=${x#conhecimento/entrada/}
    case "$rel" in
      LEIA-ME.md) ;;
      */*/*) violacao "$x -- profundidade errada na caixa; verbete tem de ser entrada/<area>/<slug>.md (em subpasta ele nunca seria mesclado)" ;;
      */*)   ;;
      *)     violacao "$x -- solto na raiz da caixa; verbete tem de ser entrada/<area>/<slug>.md (aqui ele nunca seria mesclado)" ;;
    esac
    IFS='
'
  done
  IFS=$_ifs_old

  # Caixa com entrada e monolito de destino ausente: o mesclador falha nesse caso, entao o
  # gate nao pode aprovar. Mesma classe gate<->mesclador, agora com o destino inexistente.
  for d in resolver:COMO_RESOLVER.md fazer:COMO_FAZER.md; do
    _area=${d%%:*}; _dest=${d#*:}
    for y in conhecimento/entrada/$_area/*.md; do
      [ -f "$y" ] || continue
      if [ ! -f "conhecimento/$_dest" ]; then
        violacao "conhecimento/$_dest ausente, mas a caixa tem entrada em entrada/$_area (o mesclador falharia)"
      fi
      break
    done
  done
fi

# A caixa (conhecimento/entrada/<area>/<slug>.md) existe pra sessoes concorrentes pararem de
# colidir no monolito: arquivos diferentes nao dao conflito de git. Mas entrada fora de gate e
# entrada que nasce invisivel -- exatamente o que a caixa deveria evitar.
#
# Por que bloco PROPRIO e nao mais um glob nos blocos 2/3: a checagem 2 exige que a ancora
# apareca como (#ancora) no MESMO arquivo. Num arquivo de UM verbete isso nunca e verdade, e
# estender o glob reprovaria toda entrada valida. Aqui a regra e outra: o NOME DO ARQUIVO e o
# indice. E e ele que torna o merge deterministico e o split futuro mecanico.
for f in conhecimento/entrada/*/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f" .md)

  # Fence primeiro: fence impar cega as checagens abaixo, entao acusar e parar por aqui.
  aberto=$(awk '/^```/{fence=!fence; if (fence) linha=NR} END{print (fence ? linha : 0)}' "$f")
  if [ "$aberto" -gt 0 ]; then
    violacao "$f -- bloco de codigo aberto na linha $aberto e nunca fechado (o gate fica cego dali pra frente)"
    continue
  fi

  # Padrao ESTRITO e igual ao do mesclador: '##' + espaco OU TAB, e a ancora fechando a linha.
  # O padrao frouxo ('/^## .*\{#/') aceitava '## Titulo {#slug} sobra' e recusava '##<TAB>Titulo'
  # -- nos dois casos gate e mesclador discordavam sobre o que e valido, e gate que aprova o
  # que o passo seguinte recusa faz o checkpoint quebrar depois do commit (R11, 2026-08-16).
  # tr -d '\r' antes do awk: arquivo CRLF no working tree (core.autocrlf desligado, ou
  # Windows) faz o '$' do awk nao casar, e TODA entrada valida seria denunciada como
  # malformada. No Git Bash passa; em bash nativo/CI, nao. O mesclador ja usa '\r?$' --
  # esta era a mesma divergencia gate/mesclador de novo, agora por quebra de linha.
  # Titulo VAZIO ('## {#slug}') tambem e malformado: o mesclador precisa do titulo pra montar
  # a linha de indice, entao sem ele o gate aprovaria algo que o merge recusa (R11, 2026-08-16).
  malformado=$(sed '1s/^\xEF\xBB\xBF//' "$f" | tr -d '\r' | awk '/^```/{fence=!fence; next} fence{next} (/^##[ \t]/ || /^##$/) && !/^##[ \t]+..*\{#[^}]+\}[ \t]*$/{print NR}' 2>/dev/null | head -1)
  if [ -n "$malformado" ]; then
    violacao "$f -- titulo na linha $malformado: a ancora {#slug} tem de FECHAR a linha (sem texto depois)"
    continue
  fi

  # sed pega SO a ancora do fim da linha, como o regex do mesclador (que ancora em $). O
  # 'grep -oE' anterior extraia TODAS as ocorrencias, entao '## Usar {#fake} e {#slug}' virava
  # 2 ancoras no gate e 1 no mesclador -- divergencia de novo, agora em titulo exotico.
  ancoras=$(sed '1s/^\xEF\xBB\xBF//' "$f" | tr -d '\r' | awk '/^```/{fence=!fence; next} fence{next} /^##[ \t]+..*\{#[^}]+\}[ \t]*$/{print}' 2>/dev/null \
            | sed -E 's/.*\{#([^}]+)\}[ \t]*$/\1/')
  n=$(printf '%s\n' "$ancoras" | grep -c '[^[:space:]]' || true)
  if [ "$n" -ne 1 ]; then
    violacao "$f -- a caixa e UM verbete por arquivo (achei $n titulos '## ... {#slug}')"
    continue
  fi
  if [ "$ancoras" != "$base" ]; then
    violacao "$f -- slug '#$ancoras' diverge do nome do arquivo '$base' (o nome do arquivo E o slug)"
  fi

  # Mesma janela de 4 linhas do bloco 3, e a crase continua opcional pelo mesmo motivo.
  semtags=$(sed '1s/^\xEF\xBB\xBF//' "$f" | tr -d '\r' | awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^[[:space:]]*>/ { next }
    /^##[ \t]+.*\{#/ { if (p != "") print p; p=$0; c=0; next }
    p != "" { c++; if ($0 ~ /^`?tags:/) p=""; else if (c >= 4) { print p; p="" } }
    END { if (p != "") print p }
  ')
  if [ -n "$semtags" ]; then
    violacao "$f -- verbete sem linha tags: (a busca de conhecimento nao acha)"
  fi

  # Duplicata: acusar AQUI e nao so no mesclador. Gate que aprova o que o passo seguinte
  # recusa faz o checkpoint quebrar depois do commit ter passado -- e ensina a ignorar gate.
  area=$(basename "$(dirname "$f")")
  case "$area" in
    resolver) destino="conhecimento/COMO_RESOLVER.md" ;;
    fazer)    destino="conhecimento/COMO_FAZER.md" ;;
    *)
      # Area que o mesclador nao processa = verbete que fica na caixa PARA SEMPRE. Gate que
      # aprova o que o passo seguinte ignora e o cenario exato que o bloco 3c existe pra
      # impedir: conhecimento escrito e invisivel.
      violacao "$f -- area '$area' desconhecida; o mesclador so processa 'resolver' e 'fazer' (o verbete ficaria na caixa pra sempre)"
      continue
      ;;
  esac
  if [ -f "$destino" ]; then
    # Fora de fence, como TODAS as outras checagens deste bloco: um verbete que apenas CITA
    # '{#slug}' como exemplo dentro de ``` nao pode bloquear uma entrada nova legitima.
    # Comparacao sem distincao de caixa (ancora que difere so em maiuscula colide na
    # renderizacao), mas feita baixando a caixa dos DOIS lados em vez de usar 'grep -i':
    # neste Git Bash, `grep -iF` ABORTA com SIGABRT (rc=134) -- medido 2026-08-16. `-cF`
    # sozinho funciona; e a combinacao -i + -F que quebra.
    # grep -c em vez de -q: o -q sai no primeiro casamento, o tr/awk a montante levam SIGPIPE
    # e o bash imprime "Done ..." no meio da saida do gate, sujando o diagnostico.
    # Ancora e SO o que esta na linha de titulo. Varrer o texto todo fazia uma mencao inline
    # em prosa ("a ancora e escrita como {#slug}") bloquear entrada nova legitima -- e a base
    # de conhecimento fala de si mesma o tempo todo (R11 round 5, 2026-08-16).
    base_lc=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
    dup=$(sed '1s/^\xEF\xBB\xBF//' "$destino" | tr -d '\r' \
          | awk '/^```/{fence=!fence; next} fence{next} /^##[ \t]+..*\{#[^}]+\}[ \t]*$/{print}' \
          | sed -E 's/.*\{#([^}]+)\}[ \t]*$/\1/' \
          | tr '[:upper:]' '[:lower:]' | grep -cxF "$base_lc")
    if [ "$dup" -gt 0 ]; then
      violacao "$f -- o slug '#$base' JA existe em $destino (duplicata quebraria os links das duas)"
    fi
  fi
done

# ---------- 4. Conteudo de kit staged sem bump de versao ----------
# Os 6 testes de version-alignment provam que os 4 arquivos de versao CONCORDAM.
# Nao provam que a versao ANDOU: 6.35.0 nos quatro, com template novo dentro,
# concorda e mente. Este bloco e o gatilho que faltava (Sec. 6: regra que depende
# de alguem lembrar ja falhou -- e o versionamento era a maior violacao disso).
#
# Compara com origin/main, nao com "o cabecalho mudou neste commit": senao o
# segundo commit da mesma versao exigiria bump de novo, e gate que atrapalha
# ensina a ser escapado.
#
# QUEM decide se este repo e o canon e o REMOTO, nao o disco: o gatilho e
# "origin/main tem CANON_VERSION.md". Ancorar em [ -f CANON_VERSION.md ] daria
# duas portas pra desligar o gate de graca -- `git rm --cached` (some do indice)
# e `git rm` (some do disco) -- e as duas passariam calado.
# Em repo de projeto e em clone sem origin/main: pulado, como as demais checagens.
versao_do_cabecalho() { # le stdin, devolve X.Y.Z do cabecalho
  grep '^\*\*Vers' | sed -n 's/.*`\([0-9][0-9.]*\)`.*/\1/p' | head -1
}

# Compara X.Y.Z sem depender de `sort -V` (GNU-only; BSD/macOS nao tem).
# Ecoa "maior" se $1 > $2, senao "nao".
versao_avancou() {
  printf '%s %s\n' "$1" "$2" | awk '{
    n = split($1, a, "."); split($2, b, ".")
    for (i = 1; i <= 3; i++) {
      x = a[i] + 0; y = b[i] + 0
      if (x > y) { print "maior"; exit }
      if (x < y) { print "nao";   exit }
    }
    print "nao"
  }'
}

# origin/main e ref de remote-tracking LOCAL: pode estar velha, porque hook de
# pre-commit nao faz fetch (rede no caminho do commit e lento e quebra offline).
# Limitacao assumida -- o push recusa o non-fast-forward depois de qualquer jeito.
v_origin=$(git show origin/main:CANON_VERSION.md 2>/dev/null | versao_do_cabecalho)
if [ -n "$v_origin" ]; then
  staged=$(git diff --cached --name-only 2>/dev/null || true)
  if printf '%s\n' "$staged" | grep -Eq '^(plugin|templates|v2|scripts)/|^0[1-6]_.*\.md$'; then
    # Le do INDICE, nao do working tree: bumpar e esquecer o `git add` do
    # CANON_VERSION.md deixaria o commit entrar com conteudo novo em versao
    # velha, que e exatamente o estado que este gate existe para impedir.
    v_local=$(git show :CANON_VERSION.md 2>/dev/null | versao_do_cabecalho)
    if [ -z "$v_local" ]; then
      violacao "CANON_VERSION.md sumiu do indice (rm/rm --cached) enquanto ha conteudo de kit staged -- o arquivo de versao e obrigatorio no canon"
    elif [ "$(versao_avancou "$v_local" "$v_origin")" != "maior" ]; then
      # Exige AVANCO, nao apenas diferenca: repo atrasado em relacao ao remoto
      # tambem esta commitando conteudo novo numa versao ja publicada.
      violacao "conteudo de kit staged na versao $v_local, que nao avanca sobre a $v_origin de origin/main -- rode scripts/bump-canon.ps1 <nova-versao> antes de commitar"
    fi
  fi
fi

# ---------- Resultado ----------
if [ "$FAIL" -ne 0 ]; then
  printf '\n  Gate Percus V2 barrou o commit.\n' >&2
  printf '  Corrija, ou declare o motivo:  PERCUS_GATE_OVERSIZE="por que" git commit ...\n' >&2
  printf '  Escape reincidente vira achado do loops/drift.md -- e sinal de desenho errado.\n\n' >&2
  exit 1
fi

exit 0
