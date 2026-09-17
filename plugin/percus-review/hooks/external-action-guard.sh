#!/usr/bin/env bash
# Hook PreToolUse Percus external-action-guard (Layer 1, R20) - Unix.
# STUB FAIL-CLOSED (v6.28.0): espelha SO o contrato minimo do external-action-guard.ps1 --
# bloqueia acao externa publica (git push / gh pr|issue comment|close|merge / slack-cli / mailto:)
# sem PERCUS_EXTERNAL_OVERRIDE=1. NAO reimplementa o check de premise_validity do council-log do .ps1;
# so garante que o Unix FALHE FECHADO em vez de deixar passar silenciosamente (o .ps1 e a versao completa,
# operador roda Windows). Ver nota "Runtime suportado & paridade .sh" em 01_REGRAS_INEGOCIAVEIS.md (R20).
# Skip global: PERCUS_HOOKS_DISABLED=1. Escape declarado: PERCUS_EXTERNAL_OVERRIDE=1.
set +e

STDIN=$(cat || true)
[[ -z "$STDIN" ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" ]] && exit 0

# Entrada acima de 64 KB com `push`: bloqueia antes de qualquer parse (rodada 3, gemeo do .ps1).
# Medido: 1 MB levava este stub a 19 s e o dispatcher .sh a >90 s -- timeout de hook nao bloqueia.
if [[ ${#STDIN} -gt 65536 && "${STDIN,,}" == *push* ]]; then
  echo "[percus:hook external-action-guard] BLOCK (R20): comando acima de 64 KB com 'push' -- nao e analisado (fail-closed)." >&2
  echo "  Proxima acao: rode o push SOZINHO, na forma simples: git -C \"<caminho absoluto>\" push <remoto> <branch>" >&2
  exit 2
fi

# Extrai o comando do JSON do hook. Com python3, JSON invalido BLOQUEIA (gemeo do .ps1, rodada 3) e
# JSON sem `command` libera. Sem python3: fallback no stdin cru (fail-closed -- ainda casa os padroes).
if command -v python3 >/dev/null 2>&1; then
  command=$(printf '%s' "$STDIN" | python3 -c "import sys,json
d=json.load(sys.stdin)
t=d.get('tool_input',{}) if isinstance(d,dict) else {}
c=t.get('command','') if isinstance(t,dict) else ''
sys.stdout.write(c if isinstance(c,str) else str(c))" 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo "[percus:hook external-action-guard] BLOCK (R20): entrada do hook nao e JSON valido -- nada pode ser avaliado (fail-closed)." >&2
    echo "  Proxima acao: repita o comando; se persistir, PERCUS_DISPATCHER_BYPASS=1 mostra a cadeia antiga." >&2
    exit 2
  fi
  [[ -z "$command" ]] && exit 0
else
  command="$STDIN"
fi

# Padroes de acao externa publica (espelham external-action-guard.ps1)
#
#  PARIDADE: esta lista TEM que acompanhar a do .ps1. Nao e zelo abstrato -- na 6.36.2 um
# parametro foi removido de tres arquivos e esquecido no quarto, e o teste de paridade nao pegou
# porque comparava MODELOS, nao parametros. Aqui a divergencia seria pior: o Unix pararia de
# barrar exatamente o que o Windows barra.
#
# A ampliacao de 2026-08-19 (classes de acao em vez de nomes de ferramenta) nasceu de um deploy
# por ssh que publicou um site em producao sem casar padrao nenhum.

# Inicio de comando: comeco da string, ou logo depois de um separador de shell. Serve para
# distinguir EXECUTAR de MENCIONAR -- ver o bloco "publicar" abaixo.
#  `then`/`do` com fronteira de palavra a mao (`(^|[^[:alnum:]_])`): sem ela, `heathen deploy`
# casa pela substring "then " e vira falso positivo -- e o irmao .ps1 usa `\b`, que ERE nao tem.
# Achado do review, e e a MESMA classe de divergencia que esta versao diz ter eliminado.
cmd_ini='(^|[;&|(]+[[:space:]]*|&&[[:space:]]*|\|\|[[:space:]]*|(^|[^[:alnum:]_])then[[:space:]]+|(^|[^[:alnum:]_])do[[:space:]]+)'

# Fim de token de comando. Em ASPAS SIMPLES de proposito: dentro de aspas duplas o `\$` viraria
# `$` LITERAL em vez da ancora de fim de string, e `ssh vps` sozinho deixaria de casar so no Unix
# -- exatamente a divergencia que o changelog afirmava ter fechado. Achado do review.
cmd_fim='([[:space:]]|[;&|]|$)'

# git e gh: DETECCAO LARGA -- gemeo da do .ps1 (Fase 5, rodada 2, 2026-09-16).
# Enumerar formas (`git -C x push`, `git -c k=v push`...) nunca fechou: a revisao achou 20+ formas
# que passavam. Regra: normaliza (tira aspas, barra invertida, continuacao de linha, ${IFS}),
# poe em minuscula e trata como acao externa todo comando com token `git` E token `push`/`send-pack`
# em qualquer posicao; idem token `gh` com comment/close/merge/create/sync. Falso positivo aceito.
# Fronteira de token: nao-[a-z0-9_] dos dois lados (identica ao .ps1).
# Este stub nao le autorizacao (so PERCUS_EXTERNAL_OVERRIDE): toda acao detectada bloqueia, entao
# o escopo por repositorio do .ps1 nao tem gemeo aqui.
normaliza() {
  local s="$1"
  s="${s//$'\\\r\n'/ }"
  s="${s//$'\\\n'/ }"
  s="${s//'${IFS}'/ }"
  s="${s//'$IFS'/ }"
  s="${s//\"/}"
  s="${s//\'/}"
  s="${s//\\/}"
  printf '%s' "$s"
}
# Fallback sem python3: o texto e o JSON cru, onde quebra de linha e tab sao `\n`/`\t` literais.
# Sem trocar por espaco, a remocao da barra colaria `git\npush` em `gitnpush`.
if [[ "$command" == "$STDIN" ]]; then
  command="${command//\\n/ }"
  command="${command//\\t/ }"
  command="${command//\\r/ }"
fi
bruto_min="${command,,}"
normal=$(normaliza "$command")
normal_min="${normal,,}"
fr='[^a-z0-9_]'
re_git="(^|${fr})git(\.exe)?(${fr}|\$)"
# Rodada 3 (gemeo do .ps1): `push` so como TOKEN delimitado (espaco, aspa, =, separador, chave);
# send-pack/http-push como substring. `pre-push.template.sh`, `push-x`, `origin/push` nao contam.
delim=$'[[:space:]"\'=;&|(){}<>`,]'
re_push="(^|${delim})push(${delim}|\$)|send-pack|http-push"
re_gh="(^|${fr})gh(\.exe)?(${fr}|\$)"
re_gh_acao="(^|${fr})(comment|close|merge|create|sync)(${fr}|\$)"
tem_token() { [[ "$bruto_min" =~ $1 ]] || [[ "$normal_min" =~ $1 ]]; }
# `git stash push` e `@{push}` nunca exigem autorizacao: saem antes de procurar o token push.
tira_push_local() { printf '%s' "$1" | sed -E "s/@\\{push\\}/@{u}/g; s/(^|[^a-z0-9_-])stash([[:space:]]+)push(${delim}|\$)/\\1stash\\2salvar\\3/g"; }
push_bruto=$(tira_push_local "$bruto_min")
push_normal=$(tira_push_local "$normal_min")
tem_push() { [[ "$push_bruto" =~ $re_push ]] || [[ "$push_normal" =~ $re_push ]]; }
# Mensagem de commit/tag (-m "...", --message=, -F arq) nao e opcao: sai antes dos testes de bypass.
sem_msg=$(printf '%s' "$command" | sed -E "s/(^|[^A-Za-z0-9_-])(-m|--message|-F|--file)(=|[[:space:]]+)(\"[^\"]*\"|'[^']*'|[^[:space:]]+)/\\1 /g")
sem_msg_min="${sem_msg,,}"

patterns=(
  # --- interacao publica em plataforma de terceiros (git/gh: deteccao larga acima) ---
  'slack-cli'
  'mailto:'
  # --- publicar: o resultado fica visivel pra quem nao e a gente ---
  #
  #  ANCORADOS em posicao de comando ($cmd_ini). Sem a ancora, a primeira versao destes padroes
  # bloqueou a REDACAO de um documento que apenas CITAVA um comando de deploy dentro de uma tag
  # HTML -- guard que impede escrever sobre deploy vira imposto, e imposto acaba desligado.
  # Os padroes de cima (gh/git/slack) ficam sem ancora de proposito: ja sao especificos.
  "${cmd_ini}(sudo[[:space:]]+)?(npx[[:space:]]+|npm[[:space:]]+exec[[:space:]]+|yarn[[:space:]]+)?wrangler[[:space:]]+(versions[[:space:]]+|pages[[:space:]]+|triggers[[:space:]]+)?(deploy|publish)"
  "${cmd_ini}(sudo[[:space:]]+)?docker[[:space:]]+stack[[:space:]]+deploy"
  "${cmd_ini}(sudo[[:space:]]+)?docker[[:space:]]+service[[:space:]]+(create|update|scale|rm)"
  "${cmd_ini}(sudo[[:space:]]+)?(npx[[:space:]]+)?vercel[[:space:]]+(deploy|--prod)"
  "${cmd_ini}(sudo[[:space:]]+)?(npx[[:space:]]+)?netlify[[:space:]]+deploy"
  "${cmd_ini}(sudo[[:space:]]+)?kubectl[[:space:]]+(apply|rollout|delete)"
  # --- executar em OUTRA maquina: o efeito nao fica nesta (ancorado pelo mesmo motivo) ---
  #
  #  NAO exige `user@host`. A primeira versao exigia, e o review pegou: `ssh vps 'cmd'`, com
  # alias do ~/.ssh/config, e a forma MAIS comum de execucao remota e nao tem arroba. O
  # [[:space:]] depois de `ssh` ja exclui ssh-keygen/ssh-add.
  # O host pode terminar em espaco, em separador de comando OU no fim da string: `ssh host;` e
  # `ssh host &` sao execucao remota igual, e a 1a versao exigia espaco -- as duas escapavam.
  #  `ssh -p 22 host` casa com `22` no lugar do host e bloqueia igual. E CONSERVADOR DE
  # PROPOSITO: continua sendo execucao remota, e errar para o lado de pedir o operador custa um
  # round-trip; errar para o outro custou um deploy em producao sem gate.
  "${cmd_ini}(sudo[[:space:]]+)?ssh[[:space:]]+(-[^[:space:]]+[[:space:]]+)*[^[:space:]-][^[:space:]]*${cmd_fim}"
  #  Wrapper LOCAL que abre sessao remota -- gemeo do padrao no .ps1, add. 2026-08-21.
  # Medido: o guard barrou o `ssh` direto e o MESMO efeito passou pelo wrapper do projeto
  # (`python scripts/vps_exec.py`), porque o texto do comando nao carrega a palavra procurada.
  # O sinal e o NOME do script declarar destino remoto (vps/ssh), nao o conteudo dele.
  #  Exige INTERPRETADOR na frente: sem isso `cat scripts/vps_exec.py` bloquearia, e guard que
  # impede LER o wrapper vira imposto. Ha teste para os dois lados no .tests.ps1.
  #  ERE nao tem \b nem \w: `[_[:alnum:]]*` faz o papel do \w*, e a fronteira final vem do
  # ponto da extensao. Divergir do irmao .ps1 aqui e exatamente como a guarda vaza -- e a
  # primeira versao DIVERGIU: ela usava `[^[:space:]]*(vps|ssh)`, sem exigir fronteira, enquanto
  # o .ps1 usa `\S*\b(vps|ssh)`. O review cross-provider pegou: `myvps.py` bloqueava aqui e
  # passava la. Alinhado pela semantica de TOKEN (a do .ps1), nao afrouxando, porque afrouxar
  # bloquearia `transship.py` -- que contem "ssh" no meio de uma palavra e nao tem nada de
  # remoto. Falso positivo assim vira imposto, e imposto acaba desligado.
  # `([^[:space:]]*[^[:alnum:]])?` = prefixo opcional que TERMINA em nao-alfanumerico; e o que
  # faz `scripts/vps_exec.py` e `deploy-vps.sh` casarem e `myvps.py` nao.
  #  A fronteira e explicita dos DOIS lados e identica ao gemeo .ps1 (que usa lookaround):
  # nao-alfanumerico antes de vps/ssh, e nao-alfanumerico (ou fim) depois da extensao. A 1a
  # versao errou nos dois pontos e o review cross-provider pegou: `my_vps.py` e
  # `vps_exec.pyfoo` casavam aqui e nao la, cada um um bypass pelo outro provedor.
  "${cmd_ini}(sudo[[:space:]]+)?(python[0-9.]*|py|uv[[:space:]]+run|poetry[[:space:]]+run|node|bash|sh|pwsh|powershell(\.exe)?)[[:space:]]+(-[^[:space:]]+[[:space:]]+)*([^[:space:]]*[^[:alnum:]])?(vps|ssh)[-_]?[_[:alnum:]]*\.(py|sh|ps1|mjs|js)([^[:alnum:]]|$)"
)

# --- mutar estado alheio por HTTP. Lista SEPARADA de proposito: so ela aceita a isencao de host
#     local, e por isso a versao anterior precisava de uma lista negativa para decidir quem podia
#     ser isentado -- que tinha um defeito pego pelo review: um POST para localhost num comando
#     que por acaso contivesse a substring "gh" ficava sem isencao e era bloqueado. Separar as
#     duas familias resolve pela estrutura, nao por remendo.
#
#     GET fica de fora DE PROPOSITO: ler e livre, escrever e que precisa do operador. Ancorados
#     como os de deploy: prosa que CITA `curl -X POST` nao e um POST.
#  Sem `\b` aqui: ERE do bash nao tem. A 1a versao usou `([[:space:]]|$)` no lugar, e isso
# CONSOME um caractere -- o padrao passou a exigir DOIS espacos e `curl -X POST` deixou de casar.
# Falha silenciosa e para o lado errado (guard que libera). Pego pelo teste comportamental, nao
# por leitura: os dois irmaos tinham o mesmo texto e comportamentos diferentes.
http_mutation=(
  "${cmd_ini}(sudo[[:space:]]+)?curl[[:space:]][^|;]*-X[[:space:]]*[\"']?(POST|PUT|PATCH|DELETE)"
  "${cmd_ini}(sudo[[:space:]]+)?curl[[:space:]][^|;]*--request[[:space:]]+[\"']?(POST|PUT|PATCH|DELETE)"
)

is_external=0
eh_git_push=0
if tem_token "$re_git" && tem_push; then is_external=1; eh_git_push=1; fi
# Atalhos que desligam a camada 2 SEM push no texto (gemeo do .ps1, rodada 3): `git config ... core.hooksPath`
# (--unset reativa: passa) e alterar/remover/renomear algo em .git/hooks (ler e livre).
desliga_hook=""

# Fase 6 (gemeo do .ps1): LER core.hooksPath e COPIAR de .git/hooks para fora passam, so na forma que da
# para decidir sem interpretar shell. Tokens: palavra nua ou citada INTEIRA; aspa no meio = falha.
# Preenche TOKS (valor) e TOKQ (1 = citado).
tokeniza() {
  local resto="$1" re_tok
  re_tok=$'^("([^"]*)"|\'([^\']*)\'|([^[:space:]"\']+))([[:space:]]+|$)'
  TOKS=(); TOKQ=()
  resto="${resto#"${resto%%[![:space:]]*}"}"
  resto="${resto%"${resto##*[![:space:]]}"}"
  while [[ -n "$resto" ]]; do
    [[ "$resto" =~ $re_tok ]] || return 1
    if [[ -n "${BASH_REMATCH[4]}" ]]; then TOKS+=("${BASH_REMATCH[4]}"); TOKQ+=(0)
    else TOKS+=("${BASH_REMATCH[2]}${BASH_REMATCH[3]}"); TOKQ+=(1); fi
    resto="${resto:${#BASH_REMATCH[0]}}"
  done
  return 0
}
re_proib_leitura='[`$%{}()@<>*?]|\[|\]'
re_opt_leitura='^(--global|--system|--local|--worktree|--get|--get-all|--get-regexp|-l|--list|--show-origin|--show-scope|--includes|--no-includes|-z|--null|--name-only|--all|--regexp|--bool|--int|--bool-or-int|--path|--no-type|--type=(bool|int|bool-or-int|path|expiry-date|color))$'
# `git [-C dir] config [get|list] [opcoes de leitura] [chave]`, no maximo UM posicional.
leitura_hookspath() {
  local t="$1" n i v pos=0
  [[ "$t" =~ $re_proib_leitura ]] && return 1
  tokeniza "$t" || return 1
  n=${#TOKS[@]}
  [[ $n -ge 2 ]] || return 1
  case "${TOKS[0],,}" in git|git.exe) ;; *) return 1 ;; esac
  i=1
  if [[ "${TOKS[1]}" == "-C" ]]; then [[ $n -ge 4 ]] || return 1; i=3; fi
  [[ "${TOKS[$i],,}" == "config" ]] || return 1
  i=$((i + 1))
  if [[ $i -lt $n ]]; then case "${TOKS[$i],,}" in get|list) i=$((i + 1)) ;; esac; fi
  while [[ $i -lt $n ]]; do
    v="${TOKS[$i]}"
    [[ "$v" == *\\* ]] && return 1
    if [[ "$v" == -* ]]; then
      [[ "${v,,}" =~ $re_opt_leitura ]] || return 1
    else
      pos=$((pos + 1))
    fi
    i=$((i + 1))
  done
  [[ $pos -le 1 ]]
}
# Comando INTEIRO = cp/Copy-Item/copy/cpi com 1 origem e 1 destino; destino absoluto, sem ./.., sem .git e
# sem hooks (barra invertida lida como separador E como escape). Citado com `\` nu: tem de ser absoluto sem ela.
re_proib_copia=$'[;&|()<>`$%*?{}@,+\r\n]|\\[|\\]'
copia_para_fora() {
  local c="$1" n i v prog espera="" fim=0 dst dstq com_barra sem_barra
  local -a origens=() destinos=() destq=() posic=() posq=()
  [[ "$c" =~ $re_proib_copia ]] && return 1
  tokeniza "$c" || return 1
  n=${#TOKS[@]}
  [[ $n -ge 3 ]] || return 1
  prog="${TOKS[0],,}"
  if [[ "$prog" == "cp" ]]; then
    local re_opt_cp='^(-[prRfv]+|--(preserve|recursive|force|verbose|no-clobber))$'
    for ((i = 1; i < n; i++)); do
      v="${TOKS[$i]}"
      if [[ $fim -eq 0 && "$v" == "--" ]]; then fim=1; continue; fi
      if [[ $fim -eq 0 && "$v" == -* ]]; then [[ "$v" =~ $re_opt_cp ]] || return 1; continue; fi
      posic+=("$v"); posq+=("${TOKQ[$i]}")
    done
    [[ ${#posic[@]} -eq 2 ]] || return 1
    origens=("${posic[0]}"); destinos=("${posic[1]}"); destq=("${posq[1]}")
  elif [[ "$prog" == "copy-item" || "$prog" == "copy" || "$prog" == "cpi" ]]; then
    for ((i = 1; i < n; i++)); do
      v="${TOKS[$i]}"
      if [[ "$espera" == origem ]]; then origens+=("$v"); espera=""; continue; fi
      if [[ "$espera" == destino ]]; then destinos+=("$v"); destq+=("${TOKQ[$i]}"); espera=""; continue; fi
      case "${v,,}" in
        -path|-literalpath) espera=origem; continue ;;
        -destination) espera=destino; continue ;;
        -force|-recurse|-passthru|-verbose|/y|/-y|/v|/b) continue ;;
      esac
      [[ "$v" == -* ]] && return 1
      posic+=("$v"); posq+=("${TOKQ[$i]}")
    done
    [[ -z "$espera" ]] || return 1
    for ((i = 0; i < ${#posic[@]}; i++)); do
      if [[ ${#origens[@]} -eq 0 ]]; then origens+=("${posic[$i]}")
      elif [[ ${#destinos[@]} -eq 0 ]]; then destinos+=("${posic[$i]}"); destq+=("${posq[$i]}")
      else return 1; fi
    done
  else
    return 1
  fi
  [[ ${#origens[@]} -eq 1 && ${#destinos[@]} -eq 1 ]] || return 1
  dst="${destinos[0]}"; dstq="${destq[0]}"
  [[ -n "$dst" ]] || return 1
  com_barra="${dst//\\//}"
  sem_barra="${dst//\\/}"
  local re_dst_proib='\.git|hooks' re_abs='^([a-z]:/|/|~/)' re_pontos='(^|/)\.{1,2}(/|$)'
  [[ "${com_barra,,}" =~ $re_dst_proib || "${sem_barra,,}" =~ $re_dst_proib ]] && return 1
  [[ "${com_barra,,}" =~ $re_abs ]] || return 1
  if [[ "$dstq" == 0 && "$dst" == *\\* ]]; then [[ "${sem_barra,,}" =~ $re_abs ]] || return 1; fi
  [[ "$com_barra" =~ $re_pontos ]] && return 1
  return 0
}

# Por TRECHO: --unset so vale no mesmo `config` (achado R11). Fase 6: trecho de LEITURA passa se a mensagem
# nao tirou nada do comando e o comando nao tem `$ % {} () @ < > * ? []`/crase; mais trechos config+hooksPath
# no texto NORMALIZADO do que no cru (`core.hooks""Path x`) = ofuscacao = bloqueia.
re_cfg_hp='(^|[^a-z0-9_-])config([^a-z0-9_-].*)?hookspath'
re_cfg_unset='(^|[^a-z0-9_-])config([^a-z0-9_-].*)?--unset'
if tem_token "$re_git"; then
  texto_cfg=$(printf '%s' "$sem_msg" | sed -E 's/(^|[[:space:]])[12]?>&[12]([[:space:]]|$)/\1 \2/g; s/(^|[[:space:]])2>[[:space:]]*(\/dev\/null|nul|NUL)([[:space:]]|$)/\1 \3/g')
  cfg_cru=0; cfg_normal=0; cfg_escrita=0
  while IFS= read -r trecho_cfg; do
    tmin="${trecho_cfg,,}"
    if [[ "$tmin" =~ $re_cfg_hp ]] && ! [[ "$tmin" =~ $re_cfg_unset ]]; then
      cfg_cru=$((cfg_cru + 1))
      leitura_hookspath "$trecho_cfg" || cfg_escrita=1
    fi
  done <<< "$(printf '%s\n' "$texto_cfg" | tr ';|&()\r' '\n\n\n\n\n\n')"
  texto_cfg_normal=$(normaliza "$texto_cfg")
  while IFS= read -r trecho_cfg; do
    tmin="${trecho_cfg,,}"
    if [[ "$tmin" =~ $re_cfg_hp ]] && ! [[ "$tmin" =~ $re_cfg_unset ]]; then cfg_normal=$((cfg_normal + 1)); fi
  done <<< "$(printf '%s\n' "$texto_cfg_normal" | tr ';|&()\r' '\n\n\n\n\n\n')"
  if [[ $cfg_cru -gt 0 ]] && [[ "$sem_msg" != "$command" || "$texto_cfg" =~ $re_proib_leitura ]]; then cfg_escrita=1; fi
  if [[ $cfg_escrita -eq 1 || $cfg_normal -gt $cfg_cru ]]; then
    desliga_hook="$desliga_hook git-config-core.hooksPath"
  fi
fi
# `.git/hooks` + verbo no texto cru OU normalizado. Fase 6: sed/perl/new-item/ni/clear-content/clc entram;
# copia PARA FORA sai (copia_para_fora).
re_hooksdir='\.git[\\/]+hooks'
re_mexe='(^|[^a-z0-9_-])(rm|rmdir|del|erase|rd|ri|remove-item|mv|move|move-item|mi|ren|rename|rename-item|rni|chmod|cp|copy|copy-item|cpi|set-content|sc|out-file|add-content|tee|ln|truncate|sed|perl|new-item|ni|clear-content|clc)([^a-z0-9_-]|$)'
sem_msg_normal=$(normaliza "$sem_msg")
texto_hooks="${sem_msg_min}"$'\n'"${sem_msg_normal,,}"
if [[ "$texto_hooks" =~ $re_hooksdir ]]; then
  sem_redir="${texto_hooks//[12]>&[12]/}"
  sem_redir="${sem_redir//>&[12]/}"
  if [[ "$texto_hooks" =~ $re_mexe || "$sem_redir" == *'>'* ]]; then
    copia_para_fora "$command" || desliga_hook="$desliga_hook alterar-.git/hooks"
  fi
fi
[[ -n "$desliga_hook" ]] && is_external=1
if tem_token "$re_gh" && tem_token "$re_gh_acao"; then is_external=1; fi
if [[ "$is_external" -eq 0 ]]; then
  for p in "${patterns[@]}"; do
    if [[ "$command" =~ $p ]] || [[ "$normal" =~ $p ]]; then is_external=1; break; fi
  done
fi

if [[ "$is_external" -eq 0 ]]; then
  for p in "${http_mutation[@]}"; do
    if [[ "$command" =~ $p ]]; then is_external=1; break; fi
  done
  # Isencao de host local: mutacao HTTP contra a propria maquina nao sai daqui. Guard barulhento
  # acaba desligado, que e pior que guard ausente. Conservador: basta UMA url externa pra valer.
  if [[ "$is_external" -eq 1 ]]; then
    urls=$(printf '%s' "$command" | grep -oE 'https?://[^[:space:]"'"'"'`)]+' || true)
    if [[ -n "$urls" ]]; then
      externas=$(printf '%s\n' "$urls" | grep -vE '://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])' || true)
      [[ -z "$externas" ]] && is_external=0
    fi
  fi
fi

[[ "$is_external" -eq 0 ]] && exit 0

# Formas que DESLIGAM o hook pre-push do git (camada 2, f440c4d): bloqueiam SEMPRE, antes do
# override -- gemeo do bloco do .ps1. --no-v (abreviacao de --no-verify), -n no trecho do git,
# core.hooksPath, GIT_CONFIG*, include.path/includeIf.
if [[ -n "$desliga_hook" ]]; then
  {
    echo ""
    echo "[percus:hook external-action-guard] BLOCK (R20):"
    echo "  Comando: $command"
    echo "  Razao:${desliga_hook}: essas formas desligam o hook pre-push do git (camada 2) e NAO sao aceitas,"
    echo "  nem com PERCUS_EXTERNAL_OVERRIDE."
    echo "  Proxima acao: nao mexa no hook. Se o pre-push barrou um envio, leia a mensagem dele e peca ao operador"
    echo "  a autorizacao para o push na forma simples: git -C \"<caminho absoluto>\" push <remoto> <branch>"
    echo ""
  } >&2
  exit 2
fi

if [[ "$eh_git_push" -eq 1 ]]; then
  normal_sem_msg=$(normaliza "$sem_msg")
  tudo="${sem_msg_min}"$'\n'"${normal_sem_msg,,}"
  bypass=""
  [[ "$tudo" == *send-pack* || "$tudo" == *http-push* ]] && bypass="$bypass send-pack/http-push(use-git-push)"
  re_nov='(^|[^a-z0-9_-])--no-v'
  [[ "$tudo" =~ $re_nov ]] && bypass="$bypass --no-verify"
  re_hp='(^|[^a-z0-9_/\\-])hookspath([^a-z0-9_.-]|$)'
  [[ "$tudo" =~ $re_hp ]] && bypass="$bypass hooksPath"
  re_ce='(^|[^a-z0-9_-])--config-env([^a-z0-9_-]|$)'
  [[ "$tudo" =~ $re_ce ]] && bypass="$bypass --config-env"
  re_gc='(^|[^a-z0-9_])git_config[a-z0-9_]*[[:space:]]*='
  [[ "$tudo" =~ $re_gc ]] && bypass="$bypass GIT_CONFIG*"
  re_inc='(^|[^a-z0-9_/\\-])include(\.path|if\.[^[:space:]=]*)[[:space:]]*='
  [[ "$tudo" =~ $re_inc ]] && bypass="$bypass include.path/includeIf"
  re_home='(^|[^a-z0-9_])(xdg_config_home|home)[[:space:]]*='
  [[ "$tudo" =~ $re_home ]] && bypass="$bypass HOME/XDG_CONFIG_HOME"
  re_copia='(^|[^a-z0-9_-])(cp|robocopy|xcopy|copy|copy-item|cpi|rsync|mv|move|move-item|tar)([^a-z0-9_-]|$)'
  re_dotgit='\.git([^a-z0-9_]|$)'
  [[ "$tudo" =~ $re_copia ]] && [[ "$tudo" =~ $re_dotgit ]] && bypass="$bypass copia-do-.git"
  # -n so quando push e o SUBCOMANDO do git (git log -n, git grep -n push, tail -n nao contam).
  re_n='(^|[^A-Za-z0-9_-])-[A-Za-z]*n[A-Za-z]*([^A-Za-z0-9_-]|$)'
  re_subpush='(^|[[:space:]])([^[:space:]]*[\\/])?git(\.exe)?([[:space:]]+-c[[:space:]]+("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]+)|[[:space:]]+--?[^[:space:]]+)*[[:space:]]+push([[:space:]]|$)'
  while IFS= read -r trecho; do
    trecho_min="${trecho,,}"
    if [[ "$trecho_min" =~ $re_subpush ]] && [[ "$trecho" =~ $re_n ]]; then bypass="$bypass -n"; break; fi
  done <<< "$(printf '%s\n%s\n' "$sem_msg" "$normal_sem_msg" | tr ';|&()\r' '\n\n\n\n\n\n')"
  if [[ -n "$bypass" ]]; then
    {
      echo ""
      echo "[percus:hook external-action-guard] BLOCK (R20):"
      echo "  Comando: $command"
      echo "  Razao:${bypass}: essas formas desligam o hook pre-push do git (camada 2) e NAO sao aceitas,"
      echo "  nem com PERCUS_EXTERNAL_OVERRIDE."
      echo "  Proxima acao: rode sem elas, na forma simples: git -C \"<caminho absoluto>\" push <remoto> <branch>"
      echo ""
    } >&2
    exit 2
  fi
fi

# Escopo ambiguo nao e liberado nem pelo override (gemeo do bloco do .ps1): cd, variavel, crase,
# --git-dir/--work-tree/GIT_DIR, ou mais de um trecho com git/gh. O .ps1 ainda exige a forma
# simples do git; este stub nao, porque sem override ele ja bloqueia tudo.
if tem_token "$re_git" || tem_token "$re_gh"; then
  ambiguo=""
  re_cd='(^|[^a-z0-9_-])(cd|pushd|popd|chdir|set-location|push-location)([^a-z0-9_-]|$)'
  re_var='%[a-z_][a-z0-9_]*%'
  [[ "$bruto_min" =~ $re_cd ]] && ambiguo="$ambiguo cd"
  [[ "$command" == *'$'* ]] && ambiguo="$ambiguo variavel"
  [[ "$bruto_min" =~ $re_var ]] && ambiguo="$ambiguo %VAR%"
  [[ "$command" == *'`'* ]] && ambiguo="$ambiguo crase"
  [[ "$bruto_min" == *--git-dir* || "$bruto_min" == *--work-tree* || "$bruto_min" == *git_dir* || "$bruto_min" == *git_work_tree* ]] && ambiguo="$ambiguo --git-dir"
  # Parenteses/subexpressao e splatting fora de aspas (tool PowerShell), gemeo do .ps1 (rodada 3).
  fora_aspas=$(printf '%s' "$command" | sed -E "s/\"[^\"]*\"|'[^']*'/\"\"/g")
  [[ "$fora_aspas" == *'('* || "$fora_aspas" == *')'* ]] && ambiguo="$ambiguo parenteses"
  re_splat='(^|[^a-z0-9_@])@[a-z_]'
  [[ "${fora_aspas,,}" =~ $re_splat ]] && ambiguo="$ambiguo splatting"
  n_trechos=0
  while IFS= read -r trecho; do
    trecho_min=$(printf '%s' "$trecho" | tr '[:upper:]' '[:lower:]')
    if [[ "$trecho_min" =~ $re_git ]] || [[ "$trecho_min" =~ $re_gh ]]; then n_trechos=$((n_trechos + 1)); fi
  done <<< "$(printf '%s\n' "$command" | tr ';|&()\r' '\n\n\n\n\n\n')"
  [[ "$n_trechos" -gt 1 ]] && ambiguo="$ambiguo $n_trechos-trechos"
  if [[ -n "$ambiguo" && "$PERCUS_EXTERNAL_OVERRIDE" == "1" ]]; then
    {
      echo ""
      echo "[percus:hook external-action-guard] BLOCK (R20):"
      echo "  Comando: $command"
      echo "  Razao: escopo ambiguo --${ambiguo}. PERCUS_EXTERNAL_OVERRIDE nao libera escopo ambiguo."
      echo "  use a forma simples: git -C \"<caminho absoluto>\" push <remoto> <branch>"
      echo ""
    } >&2
    exit 2
  fi
fi

# Escape hatch: operador autorizou explicitamente
if [[ "$PERCUS_EXTERNAL_OVERRIDE" == "1" ]]; then
  echo "[percus:hook external-action-guard] PERCUS_EXTERNAL_OVERRIDE setado -- permitindo." >&2
  exit 0
fi

# Default fail-closed: bloqueia acao externa publica sem aprovacao explicita (R20)
{
  echo ""
  echo "[percus:hook external-action-guard] BLOCK (R20):"
  echo "  Comando: $command"
  echo "  Razao: acao externa publica requer aprovacao explicita do operador (R20)"
  echo ""
  echo "  Para autorizar: setar PERCUS_EXTERNAL_OVERRIDE=1 com motivo declarado no commit/log."
  echo "  Deteccao LARGA: git + a palavra push (ou gh + comment/close/merge/create/sync) em qualquer posicao."
  echo "  Falso positivo (ex.: git log --grep push) libera do mesmo jeito: PERCUS_EXTERNAL_OVERRIDE=1."
  echo "  (Stub Unix fail-closed -- a versao completa com check de council e o .ps1 no Windows.)"
  echo ""
} >&2
exit 2
