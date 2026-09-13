#!/usr/bin/env bash
# ============================================================================
# Dispatcher PostToolUse -- versao bash. PARIDADE DE COMPORTAMENTO com o par
# percus-dispatch-post.cmd (camada 1, porta) + percus-dispatch-post.ps1 (camada 2).
#
# Um arquivo so, pelo mesmo motivo do percus-dispatch-pre.sh: as duas camadas do
# Windows existem por custo de startup do PowerShell, que o bash nao paga. O que
# tem de ser igual e o que o harness observa -- exit code, stderr e, AQUI, o
# STDOUT, que e o canal do produto (o aviso de contexto chega ao agente por ele).
# A fonte da logica sao o .cmd e o .ps1; leia os cabecalhos deles. So o que MUDA:
#
#  - A PORTA existe tambem no bash, mesmo sem custo a economizar: ela muda QUANDO o
#    aviso sai, e isso e comportamento. Mesmas regras de validacao e fail-open do
#    .cmd, com duas diferencas de mecanismo, nenhuma de decisao:
#      * o carimbo e epoch (`date +%s`), nao segundos-do-dia -- o bash tem epoch, e
#        a virada da meia-noite deixa de existir em vez de cair no fail-open;
#      * o arquivo se chama percus-post-gate-SH-<sessao>, nao percus-post-gate-<sessao>:
#        com unidades diferentes, dividir o arquivo com o .cmd faria um ler o
#        carimbo do outro.
#  - SID fora de [A-Za-z0-9_-] fica sem porta (mede sempre): no .cmd um nome de
#    arquivo invalido faz a gravacao falhar e a porta nunca fechar -- mesmo efeito.
#  - A FUSAO do stdout roda num jq so, com as mesmas regras do .ps1: um emissor cru
#    sozinho passa verbatim; qualquer outro caso vira UM objeto com
#    hookSpecificOutput/systemMessage, contextos JSON primeiro e crus nomeados
#    depois. "Verdadeiro" segue o -and do PowerShell: "", 0, false, null e [] nao
#    contam, e array de 1 elemento vale o que o elemento vale (o // do jq sozinho
#    deixaria "" passar).
#  - Sem jq nao ha manifesto: cadeia antiga, avisando -- decidido ANTES de ler
#    stdin, como tudo que pode pedir fallback.
#
# Guarda: plugin/percus-review/tests/dispatch-post-paridade-sh.tests.ps1 roda este
# arquivo E o .cmd contra o mesmo payload e exige as mesmas saidas.
# Spec: docs/superpowers/specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md
# ============================================================================
set +e

[ "${PERCUS_HOOKS_DISABLED:-}" = "1" ] && exit 0

HDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${PERCUS_CANON_DIR:-}" ]; then
  CANON_HOOKS="${PERCUS_CANON_DIR//\\//}/plugin/percus-review/hooks"
  [ -f "$CANON_HOOKS/percus-dispatch-post.sh" ] && HDIR="$CANON_HOOKS"
fi

# A mesma lista do `:legado` do .cmd. stdin ainda intacto em todo caminho que chega aqui.
LEGADO="context-budget-guard"

legado() {
  local veredito=0 n
  for n in $LEGADO; do
    if [ ! -f "$HDIR/$n.sh" ]; then
      echo "[percus:dispatch-post] AVISO: wrapper de fallback ausente: $n.sh -- este check NAO rodou." >&2
      continue
    fi
    bash "$HDIR/$n.sh"
    [ $? -ne 0 ] && veredito=2
  done
  exit $veredito
}

# Ver kb() em percus-dispatch-pre.sh: arredondamento bancario, como [Math]::Round.
kb() {
  local q=$(( $1 * 10 / 1024 )) r=$(( $1 * 10 % 1024 ))
  if [ $(( r * 2 )) -gt 1024 ] || { [ $(( r * 2 )) -eq 1024 ] && [ $(( q % 2 )) -eq 1 ]; }; then
    q=$(( q + 1 ))
  fi
  if [ $(( q % 10 )) -eq 0 ]; then echo "$(( q / 10 ))"; else echo "$(( q / 10 )).$(( q % 10 ))"; fi
}

[ "${PERCUS_DISPATCHER_BYPASS:-}" = "1" ] && legado

# ---------------------------------------------------------------- PORTA -----
# Toda duvida cai em FAIL-OPEN (mede). Fechar por engano custa a medicao de contexto.
AGORA="$(date +%s 2>/dev/null)"
SID="${CLAUDE_CODE_SESSION_ID:-}"
MARCAR=0
if [[ "$AGORA" =~ ^[0-9]+$ ]] && [[ "$SID" =~ ^[A-Za-z0-9_-]+$ ]]; then
  STAMP="${TMPDIR:-${TEMP:-/tmp}}/percus-post-gate-sh-$SID.txt"
  MARCAR=1
  # env explicito vence o arquivo (e o que os testes usam).
  N="${PERCUS_POST_PORTA_SEGUNDOS:-}"
  if [ -z "$N" ] && [ -f "$HDIR/porta-post.txt" ]; then
    IFS= read -r N < "$HDIR/porta-post.txt"
    N="${N%$'\r'}"
  fi
  # So inteiro decimal positivo e canonico: o .cmd compara o valor com ele mesmo passado
  # pelo `set /a`, entao BOM, espaco, sinal, "030" (octal) e "0x1e" caem todos fora. E o `set /a`
  # e de 32 bits: aceita ate 2147483647 (10 digitos) e acima disso estoura -- o teto vem de la.
  if [[ "$N" =~ ^[1-9][0-9]{0,9}$ ]] && [ "$N" -le 2147483647 ] && [ -f "$STAMP" ]; then
    LAST=""
    IFS= read -r LAST < "$STAMP"
    LAST="${LAST%$'\r'}"
    if [[ "$LAST" =~ ^(0|[1-9][0-9]{0,11})$ ]]; then
      DELTA=$(( AGORA - LAST ))
      # Delta negativo = relogio para tras: fail-open.
      if [ "$DELTA" -ge 0 ] && [ "$DELTA" -lt "$N" ]; then
        exit 0   # PORTA FECHADA
      fi
    fi
  fi
fi
# Marca ANTES de rodar: duas tool calls concorrentes da mesma sessao nao medem duas vezes.
[ "$MARCAR" -eq 1 ] && printf '%s\n' "$AGORA" > "$STAMP" 2>/dev/null

# --- TUDO QUE PODE PEDIR FALLBACK VEM ANTES DE TOCAR EM STDIN ---------------
if ! command -v jq >/dev/null 2>&1; then
  echo "[percus:dispatch-post] jq ausente -- sem ele nao ha como ler o manifesto; rodando a cadeia antiga." >&2
  legado
fi

MANIFESTO="$HDIR/hooks-manifest.json"
ERRO="$(jq empty "$MANIFESTO" 2>&1)"
if [ $? -ne 0 ]; then
  echo "[percus:dispatch-post] hooks-manifest.json ilegivel: $(printf '%s' "$ERRO" | head -n 1)" >&2
  legado
fi

mapfile -t CHECKS < <(jq -r '
  # verdade = o que o PowerShell considera verdadeiro. No jq so null e false sao falsos, e o // so
  # troca esses dois; no PowerShell 0, "" e @() tambem sao. Achado do R11 Cross-Claude (2026-09-13).
  # Array: 0 elementos e falso, 1 elemento vale o que o elemento vale, 2+ e verdadeiro (2a rodada do R11).
  def verdade: if type == "array" then (if length == 0 then false elif length == 1 then (.[0] | verdade) else true end) else (. != null and . != false and . != 0 and . != "") end;
  (if type == "object" then .hooks else null end) // []
  | if type == "array" then .[] else empty end
  | select(type == "object")
  | select(((.evento // "") | tostring | ascii_downcase) == "posttooluse"
       and (.registrado | verdade)
       and .registro == "percus-dispatch-post")
  | .nome | tostring' "$MANIFESTO" 2>/dev/null | tr -d '\r')   # jq.exe nativo: \r em cada linha (ver o .sh do pre)

if [ "${#CHECKS[@]}" -eq 0 ]; then
  echo "[percus:dispatch-post] nenhum check de PostToolUse registrado no manifesto." >&2
  legado
fi

# Integridade em disco, ainda antes de stdin. Se nenhum sobrevive, a cadeia antiga ainda
# pode rodar; se alguns sobrevivem, segue com eles e o sumico do outro vira ruido alto.
RODAVEIS=()
ESTRUTURAL=0
for nome in "${CHECKS[@]}"; do
  s="$HDIR/$nome.sh"
  if [ ! -f "$s" ]; then
    echo "[percus:dispatch-post] check registrado mas AUSENTE do disco: $nome.sh" >&2
    ESTRUTURAL=1
    continue
  fi
  if [ "$(wc -c < "$s")" -lt 200 ]; then
    echo "[percus:dispatch-post] check '$nome' esta TRUNCADO em disco (< 200 bytes) -- instalacao corrompida." >&2
    ESTRUTURAL=1
    continue
  fi
  RODAVEIS+=("$nome")
done
[ "${#RODAVEIS[@]}" -eq 0 ] && legado

# --- A PARTIR DAQUI STDIN FOI CONSUMIDO: sem volta pro fallback -------------
BRUTO="$(cat; printf x)"; BRUTO="${BRUTO%x}"
[ -z "${BRUTO//[[:space:]]/}" ] && exit 0

if ! printf '%s' "$BRUTO" | jq empty >/dev/null 2>&1; then
  echo "[percus:dispatch-post] payload nao parseia como JSON ($(kb ${#BRUTO}) KB) -- nenhum check rodou." >&2
  exit 0
fi

# Cada saida vira {nome, texto} ja aparada (o Out-String + Trim do .ps1), direto do pipe:
# passar por variavel do bash comeria quebras do fim, e por argv esbarraria no ARG_MAX.
ITENS=""
RODARAM=0
for nome in "${RODAVEIS[@]}"; do
  item="$(printf '%s' "$BRUTO" | bash "$HDIR/$nome.sh" |
          jq -R -s -c --arg n "$nome" '{nome: $n, texto: (sub("\\A\\s+"; "") | sub("\\s+\\z"; ""))}')"
  RODARAM=$(( RODARAM + 1 ))
  ITENS+="$item"$'\n'
done

FUSAO='
def verdade: if type == "array" then (if length == 0 then false elif length == 1 then (.[0] | verdade) else true end) else (. != null and . != false and . != 0 and . != "") end;
map(select(.texto != ""))
| map(. as $s | $s + (try {ok: true, v: ($s.texto | fromjson)} catch {ok: false}))
| . as $S
| [ $S[] | select(.ok) | .v | select(type == "object") | .hookSpecificOutput
      | select(type == "object") | .additionalContext | select(verdade) | tostring ] as $ctx
| [ $S[] | select(.ok) | .v | select(type == "object") | .systemMessage | select(verdade) | tostring ] as $sis
| [ $S[] | select(.ok | not) ] as $cru
| if ($S | length) == 1 and ($cru | length) == 1 then
    {raw: $cru[0].texto}
  else
    ($ctx + [ $cru[] | "[\(.nome)] \(.texto)" ]) as $todos
    | {avisos: [ $cru[] | .nome ],
       saida: ((if ($todos | length) > 0
                then {hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: ($todos | join("\n"))}}
                else {} end)
               + (if ($sis | length) > 0 then {systemMessage: ($sis | join(" "))} else {} end))}
  end'

R="$(printf '%s' "$ITENS" | jq -s -c "$FUSAO" 2>/dev/null)"
if [ $? -ne 0 ] || [ -z "$R" ]; then
  # O catch final do .ps1: stdin ja foi drenado, nao existe rota alternativa honesta.
  echo "[percus:dispatch-post] ERRO depois de consumir stdin: a fusao das saidas falhou no jq." >&2
  echo "  A medicao de contexto desta tool call foi perdida (a proxima recupera)." >&2
  echo "  Contorno: PERCUS_DISPATCHER_BYPASS=1 roda a cadeia antiga direto." >&2
  exit 0
fi

# -b nas duas escritas do stdout: o jq.exe nativo em modo texto troca "\n" por "\r\n" DENTRO do
# valor (medido 2026-09-13: `jq -j '"a\nb"'` sai a\r\nb; com -b sai a\nb). Sem ele, um aviso de
# varias linhas chegaria ao harness diferente do que o check escreveu.
if printf '%s' "$R" | jq -e 'has("raw")' >/dev/null 2>&1; then
  # UM check, e ele falou texto cru: verbatim.
  printf '%s' "$R" | jq -b -j '.raw'
else
  while IFS= read -r n; do
    [ -n "$n" ] && echo "[percus:dispatch-post] saida nao-JSON de '$n' embrulhada na fusao (stdout compartilhado com outro check)." >&2
  done < <(printf '%s' "$R" | jq -r '.avisos[]' | tr -d '\r')
  # Check calado vira dispatcher calado: objeto vazio nao sai.
  printf '%s' "$R" | jq -b -j 'if (.saida | length) > 0 then (.saida | tojson) else empty end'
fi

[ "${PERCUS_DISPATCH_DEBUG:-}" = "1" ] && echo "[percus:dispatch-post] checks rodados: $RODARAM de ${#CHECKS[@]}" >&2

[ "$ESTRUTURAL" -eq 1 ] && exit 2
exit 0
