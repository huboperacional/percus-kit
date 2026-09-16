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
# REQUISITO: gawk ou mawk (nao awk do BSD/macOS) -- ver o bloco de remocao de BOM no bloco 2.
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

# ---------- 2. Higiene de verbete (um arquivo por verbete) ----------
# Desde a 6.38.0 a base e conhecimento/<area>/<slug>.md -- um verbete por arquivo, e o NOME
# DO ARQUIVO e o slug da ancora. O monolito COMO_* foi aposentado: era ele que fazia sessoes
# de projetos diferentes colidirem (git resolve conflito em ARQUIVO) e que custava ~13k tokens
# de indice em toda consulta.
#
# As checagens sao as mesmas que o antigo bloco 3c aplicava a caixa de entrada -- a caixa foi
# aposentada porque existia PORQUE o destino era um arquivo unico. As regras sobreviveram; so
# mudaram de alvo.
#
# UMA passada de awk sobre TODOS os arquivos, de proposito. A primeira versao rodava
# sed|tr|awk por arquivo: com ~415 verbetes isso eram ~2000 processos e o gate passou de 120s.
# Gate lento no caminho do commit e gate que sera desligado -- o proprio canon diz que gate
# que atrapalha ensina a ser escapado.
_AREAS_CONHECIMENTO="conhecimento/resolver conhecimento/fazer referencia/conhecimento/resolver referencia/conhecimento/fazer"

# Enumera os verbetes de uma area a partir do INDICE DO GIT, nao do glob do disco.
#
# Por que (medido 2026-08-19): o glob varre a arvore inteira, entao arquivo UNTRACKED de outra
# sessao no mesmo checkout barrava commit de quem nao tinha nada a ver com ele. Numa unica
# sessao isso custou TRES escapes PERCUS_GATE_OVERSIZE declarados, em commits que nao tocavam
# conhecimento/ nenhum -- ou seja, o gate estava fabricando o sinal de drift que ele proprio usa
# pra dizer que algo esta errado.
#
# `git ls-files` lista o INDICE: rastreado + recem-staged, e NAO lista untracked. E exatamente o
# conjunto pelo qual este commit responde. Rascunho de terceiro na arvore deixa de ser problema
# meu; quando ELE der `git add`, vira problema dele.
#
# Uma chamada do git por AREA (nao por arquivo): 400 processos aqui foi metade do que fez a
# primeira versao deste bloco levar 120 s.
# Temp da listagem por area. Arquivo, e nao variavel, porque o `while read` precisa de
# redirecionamento: com pipe, o corpo do loop roda em SUBSHELL e o $_lista montado la dentro
# se perde ao sair -- o gate passaria a nao ver verbete nenhum e ficaria verde por vacuidade,
# que e o pior modo de falhar pra um gate.
_TMP_VERBETES="${TMPDIR:-/tmp}/percus-verbetes-$$"
_TMP_LSFILES="${TMPDIR:-/tmp}/percus-lsfiles-$$"
_TMP_DIFF="${TMPDIR:-/tmp}/percus-diff-$$"
_TMP_BLOB="${TMPDIR:-/tmp}/percus-blob-$$"
_TMP_DIFF_LC="${TMPDIR:-/tmp}/percus-difflc-$$"
trap 'rm -f "$_TMP_VERBETES" "$_TMP_LSFILES" "$_TMP_DIFF" "$_TMP_BLOB" "$_TMP_DIFF_LC"' EXIT

# UMA chamada de git por execucao do gate, em cache. A primeira versao deste bloco chamava
# `git rev-parse` + `git ls-files` por AREA e por SITIO -- 4 spawns por execucao. Parece
# nada, mas gate-conhecimento.tests.ps1 executa o gate 48 vezes: o custo virou ~2,5 s por
# execucao e a SUITE passou de 184 s pra mais de 600 s. Ou seja: a correcao que existia pra
# acelerar o ciclo tinha desacelerado ele. Medido, nao suposto.
_DENTRO_GIT=0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && _DENTRO_GIT=1
: > "$_TMP_LSFILES"
if [ "$_DENTRO_GIT" = "1" ]; then
  git ls-files > "$_TMP_LSFILES" 2>/dev/null || :
fi

# ---------- Escopo do BLOQUEIO: o diff staged (Fase 5, 2026-09-16) ----------
# Medido: em ~40 commits de 2026-09-15/16 foi preciso PERCUS_GATE_OVERSIZE pelo MESMO motivo --
# INDICE.md listando verbete de outra sessao e link morto em verbete ja commitado, problemas que
# o commit nao tocou. Escape de rotina e o sinal de desenho errado que este proprio gate descreve
# no rodape. Contrato: as checagens de CONHECIMENTO que dependem de estado de outras sessoes
# (2b link, 2d INDICE x arquivos) BLOQUEIAM so quando o problema envolve arquivo do diff staged --
# a origem do link, o alvo removido, o verbete ou o INDICE da area. Problema herdado vira AVISO,
# com a lista: continua visivel, so deixa de cobrar de quem nao o causou.
#
# Continuam bloqueando FORA do diff, de proposito: tetos de tamanho (1, 1b), higiene do verbete
# (2: tags, slug, ancora, vazio -- gate-escopo-git caso 3), posicao (2e), monolito (2c) e versao (4).
# Nenhuma delas depende de rascunho de outra sessao estar ou nao commitado.
#
# Fora de repo git (ou se o git diff falhar) o diff e DESCONHECIDO e tudo bloqueia: responder
# "nao e deste commit" sem ter como saber seria ficar verde por vacuidade.
# Diff VAZIO (rodada manual, nada staged, ou --allow-empty) tambem conta como DESCONHECIDO: e o
# modo AUDITORIA, em que tudo bloqueia como antes da Fase 5. A primeira versao tratava diff vazio
# como "nada foi causado" e rebaixava tudo a AVISO -- a revisao mostrou que isso tirava o dente do
# teste "no canon de verdade": 46 defeitos reais no git (2 verbetes COMMITADOS fora do INDICE)
# passavam verdes em lugar nenhum da suite. No pre-commit o custo e ~zero: git commit -a e
# git commit <arquivos> preenchem o indice temporario que o diff le; so --allow-empty cai aqui.
: > "$_TMP_DIFF"
_DIFF_CONHECIDO=0
_N_HERDADOS=0
if [ "$_DENTRO_GIT" = "1" ]; then
  # -z: nome com espaco ou acento sai cru (sem as aspas do core.quotePath). --no-renames: rename
  # vira remocao + adicao, e o caminho ANTIGO tambem conta (link para ele morreu neste commit).
  # --relative: mesmos caminhos relativos ao cwd que o git ls-files acima devolve.
  if git diff --cached --name-only --no-renames --relative -z > "$_TMP_BLOB" 2>/dev/null; then
    tr '\000' '\n' < "$_TMP_BLOB" | tr -d '\r' > "$_TMP_DIFF"
    LC_ALL=C tr 'A-Z' 'a-z' < "$_TMP_DIFF" > "$_TMP_DIFF_LC"
    [ -s "$_TMP_DIFF" ] && _DIFF_CONHECIDO=1
    # PERCUS_GATE_AUDITORIA=1 forca o modo auditoria mesmo com algo staged: o teste do canon real
    # nao pode ficar verde ou vermelho conforme o que outra sessao deixou no indice.
    [ "${PERCUS_GATE_AUDITORIA:-}" = "1" ] && _DIFF_CONHECIDO=0
  fi
fi

# Algum dos caminhos (um por linha em $1) esta no diff staged? Diff desconhecido: SIM (conservador).
# Lista por linha e here-doc, e nao "$@" + set --: nao mexe nos parametros posicionais nem no
# glob do gate, e o laco roda no shell corrente (o return sai da funcao, nao de um subshell).
envolve_diff() {
  [ "$_DIFF_CONHECIDO" = "1" ] || return 0
  # Sem diferenciar caixa: o Windows resolve ](Alvo.md) em alvo.md -- o [ -f ] do link concorda,
  # entao a comparacao com o diff tambem nao pode diferenciar (senao remover alvo.md vira AVISO).
  # Minusculas pelo tr dos DOIS lados, e nao grep -i: o grep -iF do Git Bash ABORTA (medido
  # 2026-09-16), e erro de grep lido como "nao casou" rebaixaria bloqueio a AVISO calado.
  # Pelo mesmo motivo, qualquer saida do grep que nao seja 1 (nao casou) conta como envolvido.
  # Limite consciente: dobra so ASCII. Slug de verbete e ASCII por convencao, e nome com acento
  # ja fica fora de todo o bloco 2 (git ls-files sem -z devolve o nome entre aspas).
  _ed_lista=$(printf '%s\n' "$1" | LC_ALL=C tr 'A-Z' 'a-z')
  while IFS= read -r _ed_p; do
    [ -n "$_ed_p" ] || continue
    grep -qxF -- "$_ed_p" "$_TMP_DIFF_LC"
    [ "$?" -ne 1 ] && return 0
  done <<EOF_ENVOLVE
$_ed_lista
EOF_ENVOLVE
  return 1
}

# $1 = mensagem; $2 = caminhos envolvidos no problema, um por linha.
violacao_do_diff() {
  _vd_m=$1
  if envolve_diff "$2"; then
    violacao "$_vd_m"
  else
    _N_HERDADOS=$((_N_HERDADOS + 1))
    printf '  AVISO (herdado, fora do diff -- nao barra): %s\n' "$_vd_m" >&2
  fi
}

# Este arquivo pertence ao escopo do gate? Mesma regra do listar_verbetes_git, so que pra um
# arquivo so: FORA de repo git a resposta e SIM (fallback conservador -- gate que responde
# "nao" sem ter como saber fica verde por vacuidade, a pior falha possivel aqui).
verbete_do_git() {
  [ "$_DENTRO_GIT" = "1" ] || return 0
  grep -qxF "$1" "$_TMP_LSFILES"
}

listar_verbetes_git() {
  # FORA de um work tree do git (fixture de teste, diretorio solto) nao ha indice pra
  # consultar, e a resposta honesta e o glob: valida tudo. Cair pra lista VAZIA aqui seria
  # muito pior que o falso positivo que este helper veio matar -- gate que nao enxerga
  # arquivo nenhum fica verde por vacuidade, a falha que este canon mais persegue.
  if [ "$_DENTRO_GIT" = "1" ]; then
    grep "^$1/[^/]*[.]md$" "$_TMP_LSFILES" || true
  else
    for _g in "$1"/*.md; do
      [ -f "$_g" ] && printf "%s
" "$_g"
    done
  fi
}

_lista=""
for _d in $_AREAS_CONHECIMENTO; do
  [ -d "$_d" ] || continue
  listar_verbetes_git "$_d" > "$_TMP_VERBETES"
  while IFS= read -r _f; do
    [ -f "$_f" ] || continue
    # Expansao de parametro, nao basename: sao ~415 arquivos, e um processo por arquivo aqui
    # foi metade do que fez o gate passar de 120s na primeira versao deste bloco.
    _b=${_f##*/}; _b=${_b%.md}
    case "$_b" in LEIA-ME|INDICE) continue ;; esac
    # Arquivo VAZIO nao entra na lista -- ele e acusado aqui mesmo. O awk nunca enxerga um
    # arquivo de zero bytes: sem registros, FNR==1 nao dispara, ele nunca vira 'atual' e nunca
    # e finalizado. Somado a um INDICE que ainda o liste, escapava de TODAS as guardas -- a
    # classe "escrito e invisivel" que este bloco existe pra matar (R11, 2026-08-18).
    if [ ! -s "$_f" ]; then
      violacao "$_f -- arquivo vazio; verbete precisa de titulo com ancora e linha tags:"
      continue
    fi
    _lista="$_lista$_f
"
  done < "$_TMP_VERBETES"
done

if [ -n "$_lista" ]; then
  # Saida do awk: "<arquivo><TAB><mensagem>". O shell so traduz em violacao.
  _achados=$(printf '%s' "$_lista" | tr '\n' '\0' | xargs -0 awk '
    function finaliza(f,   b) {
      if (f == "") return
      if (aberto[f] > 0) { print f "\t" "bloco de codigo aberto na linha " aberto[f] " e nunca fechado (o gate fica cego dali pra frente)"; return }
      if (malha[f] > 0)  { print f "\t" "titulo na linha " malha[f] ": precisa da ancora {#slug} FECHANDO a linha (sem ela o verbete nasce sem link e fora do indice)"; return }
      if (nanc[f] != 1)  { print f "\t" "e UM verbete por arquivo (achei " nanc[f] " titulos de verbete)"; return }
      b = f; sub(/.*\//, "", b); sub(/\.md$/, "", b)
      if (anc[f] != b) { print f "\t" "slug do titulo diverge do nome do arquivo (o nome do arquivo E o slug)" }
      if (faltatags[f]) { print f "\t" "verbete sem linha tags: (a busca por classe de sintoma nao acha)" }
    }
    FNR == 1 {
      # Fechar a janela do tags: do arquivo ANTERIOR antes de trocar de arquivo. Sem esta
      # linha, "viu titulo e nunca achou tags:" so era convertido em falta no END, ou seja,
      # a checagem valia apenas para o ULTIMO arquivo da lista -- e passava verde em todos os
      # outros. Passada unica troca ~2000 processos por 1, mas move o estado por arquivo para
      # dentro do awk; quem faz isso tem de fechar o arquivo anterior na mao.
      if (atual != "" && viu && !achou) faltatags[atual] = 1
      finaliza(atual)
      atual = FILENAME; fence = 0; aberto[atual] = 0; nanc[atual] = 0
      anc[atual] = ""; malha[atual] = 0; faltatags[atual] = 0
      viu = 0; achou = 0; c = 0
      # BOM: substr com escapes octais em vez de regex com escape hex.
      # HONESTIDADE SOBRE O LIMITE, porque a primeira versao deste comentario prometia
      # portabilidade que o codigo NAO tem (apontado pelo R11, 2026-08-18): octal em string de
      # awk tambem nao e POSIX. gawk e mawk interpretam como bytes; o awk do BSD/macOS pode
      # tratar como literal, e ai o BOM sobrevive, o "^##" nao casa e todo verbete com BOM
      # barra o commit.
      # O gate REQUER gawk ou mawk -- e essa e a realidade de todo o kit, nao uma escolha deste
      # bloco (Git Bash no Windows, e gawk/mawk em Linux/CI). Registrado aqui em vez de
      # disfarcado: um comentario que promete portabilidade inexistente e pior que a limitacao,
      # porque impede que alguem a descubra antes de ela morder.
      if (substr($0, 1, 3) == "\357\273\277") $0 = substr($0, 4)
    }
    { linha = $0; sub(/\r$/, "", linha) }
    linha ~ /^```/ { fence = !fence; if (fence) aberto[atual] = FNR; else aberto[atual] = 0; next }
    fence { next }
    linha ~ /^##[ \t]+..*\{#[^}]+\}[ \t]*$/ {
      if (viu && !achou) faltatags[atual] = 1
      nanc[atual]++
      a = linha; sub(/.*\{#/, "", a); sub(/\}[ \t]*$/, "", a); anc[atual] = a
      viu = 1; achou = 0; c = 0
      next
    }
    (linha ~ /^##[ \t]/ || linha ~ /^##$/) { if (malha[atual] == 0) malha[atual] = FNR; next }
    linha ~ /^[[:space:]]*>/ { next }
    viu && !achou {
      c++
      if (linha ~ /^`?tags:/) achou = 1
      else if (c >= 4) { faltatags[atual] = 1; achou = 1 }
    }
    END { if (atual != "" && viu && !achou) faltatags[atual] = 1; finaliza(atual) }
  ' 2>/dev/null)

  _old_ifs=$IFS
  IFS='
'
  for _linha in $_achados; do
    IFS=$_old_ifs
    [ -n "$_linha" ] || { IFS='
'; continue; }
    _arq=${_linha%%	*}
    _msg=${_linha#*	}
    violacao "$_arq -- $_msg"
    IFS='
'
  done
  IFS=$_old_ifs
fi

# ---------- 2b. Integridade de link entre verbetes ----------
# Risco apontado por 2/2 no pre-mortem do conselho (2026-08-18): com um arquivo por verbete,
# link quebra em SILENCIO. Nao e hipotese -- no mesmo dia, 16 cross-refs do monolito ja
# apontavam pra slug inexistente, e nada nunca reclamou.
#
# O MESMO pre-mortem avisou que este bloco vira falso positivo e acaba desligado. Por isso as
# exclusoes nascem junto: fence (a base cita exemplo de link o tempo todo), citacao, e link
# externo. INDICE.md e link entre areas (../fazer/x.md) resolvem sozinhos pela checagem de
# caminho -- nao precisam de caso especial, e caso especial e o que apodrece.
if [ -n "$_lista" ]; then
  _links=$(printf '%s' "$_lista" | tr '\n' '\0' | xargs -0 awk '
    # Resolve os segmentos . e .. do caminho: o alvo removido NESTE commit so e reconhecido no
    # diff staged pela forma canonica (conhecimento/fazer/x.md, nunca resolver/../fazer/x.md).
    function normaliza(p,   n, i, s, k, out) {
      n = split(p, s, "/"); k = 0
      for (i = 1; i <= n; i++) {
        if (s[i] == "" || s[i] == ".") continue
        if (s[i] == ".." && k > 0 && pilha[k] != "..") { k--; continue }
        pilha[++k] = s[i]
      }
      out = ""
      for (i = 1; i <= k; i++) out = out (i > 1 ? "/" : "") pilha[i]
      return out
    }
    FNR == 1 { fence = 0; if (substr($0, 1, 3) == "\357\273\277") $0 = substr($0, 4) }
    { linha = $0; sub(/\r$/, "", linha) }
    linha ~ /^```/ { fence = !fence; next }
    fence { next }
    linha ~ /^[[:space:]]*>/ { next }
    {
      # Remove CODE SPAN (`...`) antes de procurar link. Crase inline e a forma do markdown de
      # dizer "isto e literal, nao link" -- nenhum renderizador linkifica dentro dela. Sem isso,
      # um verbete que DOCUMENTA notacao de link (e esta base documenta a si mesma o tempo todo)
      # e barrado pelos proprios exemplos: aconteceu com o verbete que explica este bloco,
      # numa tabela de "formas que escapavam". Fence e citacao ja eram pulados; faltava a crase.
      while (match(linha, /`[^`]*`/)) {
        linha = substr(linha, 1, RSTART - 1) substr(linha, RSTART + RLENGTH)
      }
      resto = linha
      while (match(resto, /\]\([^)]+\.md(#[^)]*)?\)/)) {
        alvo = substr(resto, RSTART + 2, RLENGTH - 3)
        resto = substr(resto, RSTART + RLENGTH)
        if (alvo ~ /^https?:\/\// || alvo ~ /^mailto:/) continue
        # ](arquivo.md#secao): valida a parte ANTES do sustenido. Sem isso o link com secao passava
        # calado, e ele e forma legitima de escrita (R11 round 3, 2026-08-18).
        sub(/#.*$/, "", alvo)
        if (alvo == "") continue
        d = FILENAME; sub(/\/[^\/]*$/, "", d)
        print FILENAME "\t" normaliza(d "/" alvo) "\t" alvo
      }
      # Link de ANCORA ](#slug): era a forma dominante de cross-ref no monolito, onde origem e
      # destino moravam no mesmo arquivo. Com um arquivo por verbete a ancora deixou de existir
      # no arquivo de origem -- 50 links morreram na fatiagem, e a primeira versao deste bloco
      # era CEGA a eles: so olhava ](x.md).
      #
      # CUIDADO COM O SENTIDO DA CHECAGEM: ele e o oposto do intuitivo. Ancora do tipo
      # ](#secao) e a forma CANONICA de markdown pra secao INTERNA do mesmo documento --
      # escrever um link de volta pra "causa raiz" e legitimo. Barrar toda ancora tornaria o
      # gate um estorvo, e estorvo se desliga (foi o risco que 2/2 do conselho apontaram no
      # pre-mortem). Entao a violacao sai so quando <alvo>.md EXISTE: ai nao ha ambiguidade, e
      # referencia a outro verbete na forma que morreu com a fatiagem. Sem o arquivo, assume-se
      # ancora de secao e passa. (R11 round 4, 2026-08-18.)
      resto = linha
      while (match(resto, /\]\(#[a-z0-9-]+\)/)) {
        alvo = substr(resto, RSTART + 3, RLENGTH - 4)
        resto = substr(resto, RSTART + RLENGTH)
        proprio = FILENAME; sub(/.*\//, "", proprio); sub(/\.md$/, "", proprio)
        if (alvo == proprio) continue
        d = FILENAME; sub(/\/[^\/]*$/, "", d)
        print FILENAME "\tANCORA\t" d "/" alvo ".md" "\t" alvo
      }
      # Link WIKI [[slug]]: a terceira notacao do monolito. Cada rodada de review descobriu que
      # este bloco era cego a mais uma forma -- primeiro ](#slug), depois [[slug]]. A licao e que
      # "valida link" so vale se enumerar TODAS as notacoes em uso: uma guarda que cobre a forma
      # minoritaria e passa a majoritaria e pior que nenhuma, porque da a sensacao de cobertura.
      resto = linha
      while (match(resto, /\[\[[a-z0-9-]+\]\]/)) {
        alvo = substr(resto, RSTART + 2, RLENGTH - 4)
        resto = substr(resto, RSTART + RLENGTH)
        proprio = FILENAME; sub(/.*\//, "", proprio); sub(/\.md$/, "", proprio)
        if (alvo == proprio) continue
        d = FILENAME; sub(/\/[^\/]*$/, "", d)
        print FILENAME "\tWIKI" "\t" d "/" alvo ".md" "\t[[" alvo "]]"
      }
    }
  ' 2>/dev/null)

  _old_ifs=$IFS
  IFS='
'
  for _l in $_links; do
    IFS=$_old_ifs
    [ -n "$_l" ] || { IFS='
'; continue; }
    _arq=${_l%%	*}; _rest=${_l#*	}
    _tipo=${_rest%%	*}
    if [ "$_tipo" = "ANCORA" ]; then
      # Sentido INVERTIDO de proposito: barra quando o arquivo EXISTE. Ver o comentario no awk --
      # ](#secao) e ancora interna legitima, e so vira erro quando o alvo e um verbete de
      # verdade, ou seja, cross-ref na forma que a fatiagem matou.
      _rest=${_rest#*	}
      _cam=${_rest%%	*}; _alvo=${_rest#*	}
      if [ -f "$_cam" ]; then
        violacao_do_diff "$_arq -- ](#$_alvo) aponta pra um verbete que existe; com um arquivo por verbete a ancora nao resolve. Use ](${_alvo}.md). Se for MESMO ancora de secao interna, renomeie a secao: o gate nao consegue distinguir quando existe um verbete com o mesmo slug" "$_arq
$_cam"
      fi
    elif [ "$_tipo" = "WIKI" ]; then
      # [[slug]] nao carrega caminho -- e a notacao DOMINANTE da base: 287 dos 288 cross-refs
      # medidos em 2026-09-07. Resolver o alvo so no diretorio da ORIGEM fazia todo link
      # cross-area (fazer/ <-> resolver/) virar falso positivo que acusa "link morto" sobre um
      # arquivo que EXISTE -- barra o commit e manda investigar o lugar errado. Mordeu duas
      # sessoes no mesmo dia. Ver conhecimento/resolver/wikilink-so-resolve-dentro-da-mesma-area.md.
      #
      # PRECEDENCIA: a area da propria ORIGEM vence, e por isso o teste de existencia vem
      # primeiro. So quando o slug NAO esta la e que as demais areas sao varridas -- assim
      # passar a resolver cross-area nao muda o destino de nenhum link que ja resolvia.
      _rest=${_rest#*	}
      _cam=${_rest%%	*}; _alvo=${_rest#*	}
      if [ ! -f "$_cam" ]; then
        _slug=${_cam##*/}; _slug=${_slug%.md}
        _achados=""; _n=0
        # Candidatos em TODAS as areas, existindo ou nao: remover (ou adicionar) o slug em
        # qualquer area neste commit e o que mata (ou torna ambiguo) o link alheio.
        _cands=""
        for _a in $_AREAS_CONHECIMENTO; do
          _cands="$_cands
$_a/$_slug.md"
          [ -f "$_a/$_slug.md" ] || continue
          _achados="$_achados $_a"
          _n=$((_n + 1))
        done
        if [ "$_n" = "0" ]; then
          _envolvidos="$_arq
$_cam$_cands"
        else
          _envolvidos="$_arq$_cands"
        fi
        if [ "$_n" = "0" ]; then
          violacao_do_diff "$_arq -- link para '$_alvo' nao resolve num arquivo existente (link morto nasce calado)" "$_envolvidos"
        elif [ "$_n" -gt 1 ]; then
          # Escolher uma area no escuro seria mentir que sabe. O gate diz que NAO sabe, e a
          # saida honesta e o caminho explicito -- que nenhuma das leituras deixa ambiguo.
          violacao_do_diff "$_arq -- '$_alvo' e ambiguo: o slug existe em$_achados. [[slug]] nao diz qual -- cite por caminho: ](../<area>/$_slug.md)" "$_envolvidos"
        fi
      fi
    else
      _cam=${_rest%%	*}; _alvo=${_rest#*	}
      if [ ! -f "$_cam" ]; then
        violacao_do_diff "$_arq -- link para '$_alvo' nao resolve num arquivo existente (link morto nasce calado)" "$_arq
$_cam"
      fi
    fi
    IFS='
'
  done
  IFS=$_old_ifs
fi


# ---------- 2e. POSICAO do arquivo de conhecimento ----------
# Antes de aferir CONTEUDO, aferir POSICAO -- era o que o antigo bloco 3c fazia com a caixa de
# entrada, e a migracao tinha perdido essa metade. O glob dos blocos acima nao e recursivo, o
# gerador so indexa <area>/*.md, e o guard so barra monolito e indice. Resultado: um verbete
# criado por engano em conhecimento/foo.md, ou em conhecimento/resolver/sub/foo.md, nasce
# INVISIVEL -- ninguem afere, ninguem indexa, ninguem reclama. E a classe "escrito e invisivel"
# que esta versao existe pra matar, entrando pela porta da posicao (R11, 2026-08-18).
for _raiz in conhecimento referencia/conhecimento; do
  [ -d "$_raiz" ] || continue
  # IFS so em quebra de linha: sem isso caminho com espaco vira varios argumentos e a checagem
  # afere pedaco de nome. O 'for' (e nao 'find | while') e de proposito: pipeline roda em
  # subshell e o FAIL=1 de dentro do violacao se perderia, deixando o gate acusar e sair 0.
  _ifs_old=$IFS
  IFS='
'
  for _x in $(find "$_raiz" -type f -name '*.md' 2>/dev/null); do
    IFS=$_ifs_old
    _rel=${_x#"$_raiz"/}
    case "$_rel" in
      # README e LEIA-ME na raiz da area sao DOCUMENTACAO, nao verbete. Isentar so o LEIA-ME
      # barrava 'referencia/conhecimento/README.md' -- e o bug era invisivel da raiz do repo,
      # porque 'referencia/conhecimento' so existe quando o gate roda de dentro do v2/. Achado
      # pelo R11 (2026-08-18): guarda que so quebra num dos caminhos de execucao passa em todos
      # os testes que rodam pelo outro.
      README.md|LEIA-ME.md) ;;
      resolver/*/*|fazer/*/*)
        violacao "$_x -- profundidade errada; verbete e <area>/<slug>.md (em subpasta ele nao e aferido nem indexado)" ;;
      resolver/*|fazer/*) ;;
      */*)
        violacao "$_x -- area desconhecida; so 'resolver' e 'fazer' sao aferidas e indexadas" ;;
      *)
        violacao "$_x -- solto na raiz de $_raiz; verbete e <area>/<slug>.md (aqui ele nasce invisivel)" ;;
    esac
    IFS='
'
  done
  IFS=$_ifs_old
done

# ---------- 2d. INDICE.md em sincronia com os verbetes ----------
# Achado do review R11 (2026-08-18): o gerador de indice ganhou -Verificar e o gate NAO o
# chamava. Um verbete novo, commitado sem regerar, passava calado -- reintroduzindo exatamente
# o defeito que a migracao existe pra matar: indice divergente do conteudo, que foi o que
# deixou 14 verbetes invisiveis por semanas.
#
# O gate nao chama o gerador (dependeria de pwsh no caminho do commit, e o gate roda em sh).
# Faz a comparacao de CONJUNTOS aqui mesmo, e nos DOIS sentidos: verbete que falta no indice, e
# indice que lista arquivo que nao existe.
#
# Um 'sort | uniq -u' resolve os dois de uma vez -- linha que aparece uma vez so esta em apenas
# um dos lados. Comparar item a item custaria ~400 greps, e gate lento e gate desligado.
for _d in $_AREAS_CONHECIMENTO; do
  [ -d "$_d" ] || continue
  _idx="$_d/INDICE.md"
  [ -f "$_idx" ] || continue

  # Mesmo conjunto do bloco acima: indice do git, nao glob do disco -- senao o verbete
  # untracked de outra sessao apareceria como "fora do INDICE" e barraria meu commit.
  _disco=$(listar_verbetes_git "$_d" | while IFS= read -r _f; do
             [ -f "$_f" ] || continue
             _b=${_f##*/}; _b=${_b%.md}
             case "$_b" in INDICE|LEIA-ME) continue ;; esac
             printf '%s\n' "$_b"
           done)

  # Link com barra e referencia a OUTRA area (../fazer/x.md): nao pertence a este indice.
  _listados=$(awk '
    /^```/ { fence = !fence; next }
    fence { next }
    {
      resto = $0
      while (match(resto, /\]\([^)]+\.md\)/)) {
        a = substr(resto, RSTART + 2, RLENGTH - 3)
        resto = substr(resto, RSTART + RLENGTH)
        if (a ~ /\//) continue
        sub(/\.md$/, "", a)
        print a
      }
    }
  ' "$_idx" 2>/dev/null | sort -u)

  _dif=$(printf '%s\n%s\n' "$_disco" "$_listados" | sed '/^[[:space:]]*$/d' | sort | uniq -u)
  # As duas direcoes deixaram de ser simetricas em 2026-08-19, e de proposito:
  #
  #   verbete que o GIT conhece e falta no INDICE.md -> VIOLACAO. E o defeito que deixou
  #     14 verbetes invisiveis por semanas: escrito, commitado, e fora do indice.
  #
  #   entrada do INDICE.md sem verbete no git -> so e violacao se o arquivo tambem NAO
  #     EXISTIR no disco. O gerador le o disco e o gate le o git; num checkout
  #     compartilhado essa diferenca e permanente, porque outra sessao tem rascunho
  #     untracked na arvore o tempo todo. Acusar isso barraria meu commit por causa do
  #     arquivo dela -- o mesmo falso positivo que esta versao veio matar, voltando pela
  #     porta dos fundos. Link para arquivo que existe e link que funciona; quando ela
  #     commitar, a primeira regra passa a cobrar o indice.
  for _s in $_dif; do
    if [ -f "$_d/$_s.md" ]; then
      if verbete_do_git "$_d/$_s.md"; then
        violacao_do_diff "$_d/$_s.md -- verbete FORA do INDICE.md (rode scripts/gerar-indice-conhecimento.ps1)" "$_d/$_s.md
$_idx"
      fi
    else
      violacao_do_diff "$_idx -- lista '$_s.md', que nao existe (rode scripts/gerar-indice-conhecimento.ps1)" "$_idx
$_d/$_s.md"
    fi
  done
done

# ---------- 2c. Referencia orfa ao monolito aposentado ----------
# Terceiro risco de consenso do pre-mortem: referencia esquecida ao arquivo que nao existe
# mais falha DIAS depois, na primeira sessao que tentar le-lo.
#
# O padrao usa alternancia com parenteses de proposito: assim o texto do padrao nao casa a si
# mesmo, e este bloco nao se acusa. A mensagem tambem evita escrever o nome literal.
#
# O padrao exige o CAMINHO ('conhecimento/COMO_...'), nao o nome solto. A diferenca decide se
# a guarda e util ou insuportavel: referencia com caminho e INSTRUCAO DE USO e precisa morrer;
# o nome solto em prosa costuma ser relato historico -- e a base de conhecimento conta a
# propria historia o tempo todo ("medido no monolito de 912 KB"). Medido em 2026-08-18: das 28
# ocorrencias, 13 eram caminho (instrucao viva) e 15 eram narrativa dentro de verbete. Barrar
# as 15 tornaria impossivel escrever a licao sobre a propria migracao.
#
# tests/ fica de fora porque os testes deste bloco PRECISAM citar o caminho aposentado; docs de
# plano/spec e .archive sao registro historico do que foi feito, nao instrucao viva.
if [ -d conhecimento/resolver ]; then
  orfas=$(grep -rlE 'conhecimento/COMO_(RESOLVER|FAZER)\.md' \
            --include='*.md' --include='*.ps1' --include='*.sh' --include='*.json' \
            --include='*.py' --include='*.yml' --include='*.yaml' --include='*.ts' \
            --exclude-dir='.git' --exclude-dir='node_modules' \
            --exclude-dir='.worktrees' --exclude-dir='.claude' -I . 2>/dev/null \
          | sed 's|^\./||' \
          | grep -vE '^(docs/superpowers/(plans|specs)/|\.archive/|plugin/percus-review/tests/|CANON_VERSION\.md$)' || true)
  for x in $orfas; do
    violacao "$x -- cita o monolito de conhecimento aposentado; a base agora e conhecimento/<area>/<slug>.md"
  done
fi


# ---------- 3. .ps1/.psm1/.psd1 staged com byte > 0x7F sem BOM ----------
# O PowerShell 5.1 le .ps1 SEM BOM como ANSI (cp1252): acento vira mojibake e string com aspa
# tipografica ou travessao quebra o parse. A falha passou por 2 revisoes seguidas (T2 da Fase 3
# e teste do MDS na Fase 4) e so o ps51-compat da suite inteira pegou -- regra que depende de
# alguem lembrar ja falhou (Sec. 6).
#
# So o STAGED (adicionado/modificado): .ps1 herdado nao e deste commit. Le o blob do INDICE, nao
# o disco -- o que entra no commit e o indice. Removido no commit nao tem blob e e pulado.
# ":./<caminho>" porque a lista do diff e relativa ao cwd (--relative), e ":<caminho>" e da raiz.
# Sem nada staged (ou fora de repo git) a regra nao roda: ela e sobre o que entra no commit.
# .psm1 e .psd1 tem a mesma armadilha (Import-Module / Import-PowerShellDataFile no 5.1).
# BOM UTF-16 (FF FE / FE FF) e valido no 5.1: os bytes altos sao do UTF-16, nao ANSI -- nao barra.
# Guarda pelo ARQUIVO do diff, e nao por _DIFF_CONHECIDO: o modo auditoria zera aquela flag pra
# endurecer o conhecimento, e nao pode por tabela desligar esta checagem (R11 2026-09-16).
if [ -s "$_TMP_DIFF" ]; then
  while IFS= read -r _ps; do
    case "$_ps" in *.[pP][sS]1|*.[pP][sS][mM]1|*.[pP][sS][dD]1) ;; *) continue ;; esac
    git cat-file blob ":./$_ps" > "$_TMP_BLOB" 2>/dev/null || continue
    _alto=$(LC_ALL=C tr -d '\000-\177' < "$_TMP_BLOB" | dd bs=1 count=1 2>/dev/null | wc -c | tr -d ' ')
    [ "$_alto" = "0" ] && continue
    _bom=$(dd if="$_TMP_BLOB" bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \r\n')
    case "$_bom" in
      efbbbf|fffe*|feff*) ;;
      *) violacao "$_ps -- PowerShell (.ps1/.psm1/.psd1) com byte > 0x7F (acento/emoji) sem BOM: .ps1 com acento/emoji nasce com BOM; o PowerShell 5.1 le em ANSI e quebra. Regrave em UTF-8 com BOM (nao com python: ele come o BOM)" ;;
    esac
  done < "$_TMP_DIFF"
fi

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
    # Branch de feature x branch principal. O numero da versao e atribuido no MERGE:
    # exigir bump dentro do branch faz branches paralelos brigarem pelo mesmo numero e
    # conflitarem no CANON_VERSION.md. Fora de main/master, IGUALDADE com origin/main e
    # aceita; versao ATRASADA, arquivo fora do indice e remocao continuam barrados.
    # HEAD destacado (symbolic-ref vazio) nao prova que e feature: fica na regra estrita.
    # O avanco na main fica garantido pelo commit de bump da release, que este bloco checa
    # (merge sem conflito nao roda pre-commit; fast-forward nao roda hook nenhum).
    # tr -d do CR: no Git Bash a saida de git pode trazer CR no fim da linha.
    # Ref COMPLETO, nao --short: com uma tag chamada main (ou master) no repo,
    # --short desambigua o branch homonimo para heads/main, o case abaixo nao
    # casa mais main e o commit cairia na regra relaxada dentro do proprio
    # branch principal. O ref completo (refs/heads/main) nao sofre esse choque.
    branch_atual=$(git symbolic-ref -q HEAD 2>/dev/null | tr -d '\r')
    case "$branch_atual" in
      ''|refs/heads/main|refs/heads/master) branch_feature=0 ;;
      *)                                    branch_feature=1 ;;
    esac
    branch_nome=${branch_atual#refs/heads/}
    if [ -z "$v_local" ]; then
      violacao "CANON_VERSION.md sumiu do indice (rm/rm --cached) enquanto ha conteudo de kit staged -- o arquivo de versao e obrigatorio no canon"
    elif [ "$branch_feature" -eq 1 ]; then
      if [ "$(versao_avancou "$v_origin" "$v_local")" = "maior" ]; then
        violacao "conteudo de kit staged no branch $branch_nome na versao $v_local, ATRAS da $v_origin de origin/main -- atualize o branch com origin/main (igualdade e aceita; atraso nao)"
      fi
    elif [ "$(versao_avancou "$v_local" "$v_origin")" != "maior" ]; then
      # Exige AVANCO, nao apenas diferenca: repo atrasado em relacao ao remoto
      # tambem esta commitando conteudo novo numa versao ja publicada.
      violacao "conteudo de kit staged na versao $v_local, que nao avanca sobre a $v_origin de origin/main -- rode scripts/bump-canon.ps1 <nova-versao> antes de commitar (em branch de feature, igualdade e aceita: o numero e atribuido no merge)"
    fi
  fi
fi

# ---------- Resultado ----------
if [ "$_N_HERDADOS" -gt 0 ]; then
  printf '\n  %s problema(s) de conhecimento HERDADO(S), fora do diff staged: listados acima como AVISO, nao barram.\n' "$_N_HERDADOS" >&2
  printf '  Corrija em commit proprio (INDICE: scripts/gerar-indice-conhecimento.ps1).\n' >&2
fi
if [ "$FAIL" -ne 0 ]; then
  printf '\n  Gate Percus V2 barrou o commit.\n' >&2
  printf '  Corrija, ou declare o motivo:  PERCUS_GATE_OVERSIZE="por que" git commit ...\n' >&2
  printf '  Escape reincidente vira achado do loops/drift.md -- e sinal de desenho errado.\n\n' >&2
  exit 1
fi

exit 0
