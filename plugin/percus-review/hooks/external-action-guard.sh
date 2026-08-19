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

# Extrai o comando do JSON do hook. Fallback sem python3: usa o stdin cru (fail-closed -- ainda casa
# os padroes perigosos abaixo, so nao isola o campo command).
command=$(printf '%s' "$STDIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)
[[ -z "$command" ]] && command="$STDIN"

# Padroes de acao externa publica (espelham external-action-guard.ps1)
#
# ⚠️ PARIDADE: esta lista TEM que acompanhar a do .ps1. Nao e zelo abstrato -- na 6.36.2 um
# parametro foi removido de tres arquivos e esquecido no quarto, e o teste de paridade nao pegou
# porque comparava MODELOS, nao parametros. Aqui a divergencia seria pior: o Unix pararia de
# barrar exatamente o que o Windows barra.
#
# A ampliacao de 2026-08-19 (classes de acao em vez de nomes de ferramenta) nasceu de um deploy
# por ssh que publicou um site em producao sem casar padrao nenhum.

# Inicio de comando: comeco da string, ou logo depois de um separador de shell. Serve para
# distinguir EXECUTAR de MENCIONAR -- ver o bloco "publicar" abaixo.
# ⚠️ `then`/`do` com fronteira de palavra a mao (`(^|[^[:alnum:]_])`): sem ela, `heathen deploy`
# casa pela substring "then " e vira falso positivo -- e o irmao .ps1 usa `\b`, que ERE nao tem.
# Achado do review, e e a MESMA classe de divergencia que esta versao diz ter eliminado.
cmd_ini='(^|[;&|(]+[[:space:]]*|&&[[:space:]]*|\|\|[[:space:]]*|(^|[^[:alnum:]_])then[[:space:]]+|(^|[^[:alnum:]_])do[[:space:]]+)'

# Fim de token de comando. Em ASPAS SIMPLES de proposito: dentro de aspas duplas o `\$` viraria
# `$` LITERAL em vez da ancora de fim de string, e `ssh vps` sozinho deixaria de casar so no Unix
# -- exatamente a divergencia que o changelog afirmava ter fechado. Achado do review.
cmd_fim='([[:space:]]|[;&|]|$)'

patterns=(
  # --- interacao publica em plataforma de terceiros ---
  'gh[[:space:]]+(pr|issue)[[:space:]]+comment'
  'gh[[:space:]]+pr[[:space:]]+(close|merge)'
  'gh[[:space:]]+issue[[:space:]]+close'
  'slack-cli'
  'git[[:space:]]+push'
  'mailto:'
  # --- publicar: o resultado fica visivel pra quem nao e a gente ---
  #
  # ⚠️ ANCORADOS em posicao de comando ($cmd_ini). Sem a ancora, a primeira versao destes padroes
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
  # ⚠️ NAO exige `user@host`. A primeira versao exigia, e o review pegou: `ssh vps 'cmd'`, com
  # alias do ~/.ssh/config, e a forma MAIS comum de execucao remota e nao tem arroba. O
  # [[:space:]] depois de `ssh` ja exclui ssh-keygen/ssh-add.
  # O host pode terminar em espaco, em separador de comando OU no fim da string: `ssh host;` e
  # `ssh host &` sao execucao remota igual, e a 1a versao exigia espaco -- as duas escapavam.
  # ⚠️ `ssh -p 22 host` casa com `22` no lugar do host e bloqueia igual. E CONSERVADOR DE
  # PROPOSITO: continua sendo execucao remota, e errar para o lado de pedir o operador custa um
  # round-trip; errar para o outro custou um deploy em producao sem gate.
  "${cmd_ini}(sudo[[:space:]]+)?ssh[[:space:]]+(-[^[:space:]]+[[:space:]]+)*[^[:space:]-][^[:space:]]*${cmd_fim}"
)

# --- mutar estado alheio por HTTP. Lista SEPARADA de proposito: so ela aceita a isencao de host
#     local, e por isso a versao anterior precisava de uma lista negativa para decidir quem podia
#     ser isentado -- que tinha um defeito pego pelo review: um POST para localhost num comando
#     que por acaso contivesse a substring "gh" ficava sem isencao e era bloqueado. Separar as
#     duas familias resolve pela estrutura, nao por remendo.
#
#     GET fica de fora DE PROPOSITO: ler e livre, escrever e que precisa do operador. Ancorados
#     como os de deploy: prosa que CITA `curl -X POST` nao e um POST.
# ⚠️ Sem `\b` aqui: ERE do bash nao tem. A 1a versao usou `([[:space:]]|$)` no lugar, e isso
# CONSOME um caractere -- o padrao passou a exigir DOIS espacos e `curl -X POST` deixou de casar.
# Falha silenciosa e para o lado errado (guard que libera). Pego pelo teste comportamental, nao
# por leitura: os dois irmaos tinham o mesmo texto e comportamentos diferentes.
http_mutation=(
  "${cmd_ini}(sudo[[:space:]]+)?curl[[:space:]][^|;]*-X[[:space:]]*[\"']?(POST|PUT|PATCH|DELETE)"
  "${cmd_ini}(sudo[[:space:]]+)?curl[[:space:]][^|;]*--request[[:space:]]+[\"']?(POST|PUT|PATCH|DELETE)"
)

is_external=0
for p in "${patterns[@]}"; do
  if [[ "$command" =~ $p ]]; then is_external=1; break; fi
done

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
  echo "  (Stub Unix fail-closed -- a versao completa com check de council e o .ps1 no Windows.)"
  echo ""
} >&2
exit 2
