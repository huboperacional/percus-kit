#!/usr/bin/env bash
# ============================================================================
# Dispatcher PreToolUse -- versao bash. PARIDADE DE COMPORTAMENTO com o par
# percus-dispatch-pre.cmd (camada 1) + percus-dispatch-pre.ps1 (camada 2).
#
# Um arquivo so, e nao duas camadas: no Windows elas existem por CUSTO (o startup
# do PowerShell 5.1 e ~420 ms). O bash nao paga isso, entao separar nao economiza
# nada. O que tem de ser igual e o que o harness observa: exit code, stderr, e
# QUAIS checks rodam em QUE ordem. A fonte da logica sao o .cmd e o .ps1 -- leia
# os cabecalhos deles para o porque de cada decisao. Aqui so o que MUDA no bash:
#
#  - gatilhos-pre.txt esta em CRLF. Lido cru, cada gatilho carregaria o \r e nunca
#    casaria. Linha vazia e ignorada (num `grep -f` ela casaria TUDO), e a ultima
#    linha conta mesmo sem quebra no fim (`read` sozinho a descartaria).
#  - stdin nao passa por captura de cmd.exe, entao nao trunca em ~80 KB. JSON
#    invalido aqui e payload estranho do harness: mesma decisao (BLOCK), outra
#    causa na mensagem. O tamanho reportado e o que o bash leu; o .cmd reporta o
#    que a captura produziu (+CRLF), entao perto da fronteira de 0,1 KB os dois
#    numeros podem diferir por esse motivo e so por ele.
#  - sem jq nao ha como ler o manifesto: e o analogo do "manifesto ilegivel" do
#    .ps1 e termina no mesmo lugar (cadeia antiga), avisando.
#  - "check que lanca excecao" (defesa 2 do .ps1) nao tem analogo: um .sh que
#    morre sai nao-zero e entra no veredito como qualquer bloqueio.
#  - comparacoes de evento e matcher ignoram caixa, e a de registro nao: e o que
#    -eq e -ceq fazem no .ps1.
#
# Guarda: plugin/percus-review/tests/dispatch-pre-paridade-sh.tests.ps1 roda este
# arquivo E o .cmd contra o mesmo payload e exige as mesmas saidas.
# Spec: docs/superpowers/specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md
# ============================================================================
set +e

[ "${PERCUS_HOOKS_DISABLED:-}" = "1" ] && exit 0

HDIR="$(cd "$(dirname "$0")" && pwd)"
# Trampolim, igual ao .cmd: com o kit apontado e o dispatcher dentro dele, manifesto,
# gatilhos e checks vem do kit, nao da copia instalada.
if [ -n "${PERCUS_CANON_DIR:-}" ]; then
  CANON_HOOKS="${PERCUS_CANON_DIR//\\//}/plugin/percus-review/hooks"
  [ -f "$CANON_HOOKS/percus-dispatch-pre.sh" ] && HDIR="$CANON_HOOKS"
fi

# stdin byte a byte: `$(cat)` sozinho come as quebras de linha do fim.
BRUTO="$(cat; printf x)"; BRUTO="${BRUTO%x}"

# A mesma lista do `:legado` do .cmd, na mesma ordem.
LEGADO="pre-commit-check mock-scan-pre-commit auth-import-pre-commit migration-check-pre-commit types-check-pre-commit external-action-guard crud-evidence-warn spec-analyze-check"

legado() {
  local veredito=0 n
  for n in $LEGADO; do
    # Wrapper ausente NAO e pulado em silencio: este caminho so roda quando o dispatcher
    # ja falhou, que e o pior momento para perder um check calado.
    if [ ! -f "$HDIR/$n.sh" ]; then
      echo "[percus:dispatch-pre] AVISO: wrapper de fallback ausente: $n.sh -- este check NAO rodou." >&2
      continue
    fi
    printf '%s' "$BRUTO" | bash "$HDIR/$n.sh"
    [ $? -ne 0 ] && veredito=2
  done
  exit $veredito
}

# Tamanho em KB com uma casa, do jeito que o .ps1 imprime [Math]::Round(n/1KB, 1):
# arredondamento BANCARIO (0,25 -> 0,2) e sem ",0" em valor inteiro. Aritmetica
# inteira: os empates possiveis (n/1024 com fracao .x5) sao exatos em binario, entao
# nao ha erro de ponto flutuante do lado .NET para imitar.
kb() {
  local q=$(( $1 * 10 / 1024 )) r=$(( $1 * 10 % 1024 ))
  if [ $(( r * 2 )) -gt 1024 ] || { [ $(( r * 2 )) -eq 1024 ] && [ $(( q % 2 )) -eq 1 ]; }; then
    q=$(( q + 1 ))
  fi
  if [ $(( q % 10 )) -eq 0 ]; then echo "$(( q / 10 ))"; else echo "$(( q / 10 )).$(( q % 10 ))"; fi
}

[ "${PERCUS_DISPATCHER_BYPASS:-}" = "1" ] && legado
[ -f "$HDIR/gatilhos-pre.txt" ] || legado

# Substring sem caixa (os dois lados ja vem em minuscula). O `case *"g"*` do bash e quadratico em
# texto grande: medido na Fase 5 (rodada 3), 300 KB levavam ~50 s so na triagem e 1 MB passava de
# 90 s -- e timeout de hook NAO bloqueia, entao lento = fail-open. Acima de 32 KB (o mesmo corte do
# .cmd) usa `grep -F`, linear; abaixo fica o `case`, sem custo de processo.
contem() {
  if [ "${#1}" -lt 32000 ]; then
    case "$1" in *"$2"*) return 0 ;; esac
    return 1
  fi
  printf '%s' "$1" | grep -qF -- "$2"
}

# --- Triagem: alguem PODERIA disparar? Casa contra o JSON inteiro, sem caixa. -----
BRUTO_LC="${BRUTO,,}"
TEM_GATILHO=0
CASOU=0
while IFS= read -r g || [ -n "$g" ]; do
  g="${g%$'\r'}"
  [ -z "${g//[[:space:]]/}" ] && continue
  TEM_GATILHO=1
  if contem "$BRUTO_LC" "${g,,}"; then CASOU=1; break; fi
done < "$HDIR/gatilhos-pre.txt"
# Arquivo sem gatilho nenhum e o analogo do findstr com erro: fail-OPEN, roda a camada 2.
[ "$TEM_GATILHO" -eq 1 ] && [ "$CASOU" -eq 0 ] && exit 0

# --- Decisao precisa (a camada 2 do .ps1) ---------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "[percus:dispatch-pre] jq ausente -- sem ele nao ha como ler o manifesto; rodando a cadeia antiga." >&2
  legado
fi

# `[[ =~ ]]` e nao `${BRUTO//[[:space:]]/}`: a substituicao e quadratica e custava ~45 s com 300 KB
# (medido na Fase 5, rodada 3) -- lento = timeout = fail-open.
[[ "$BRUTO" =~ [^[:space:]] ]] || exit 0

if ! printf '%s' "$BRUTO" | jq empty >/dev/null 2>&1; then
  echo "[percus:dispatch-pre] BLOCK: payload nao parseia como JSON ($(kb ${#BRUTO}) KB)." >&2
  echo "  Causa provavel: payload malformado vindo do harness (no bash nao ha captura de stdin que trunque)." >&2
  echo "  Nenhum check pode rodar -- e passar em silencio esconderia isso." >&2
  echo "  Contorno: PERCUS_DISPATCHER_BYPASS=1 (cadeia antiga) ou comando menor." >&2
  exit 2
fi

# -j e nao -r: o jq.exe nativo do Windows escreve "\n" como "\r\n", e o -r deixaria um \r
# colado no fim do valor. Medido 2026-09-13: foi o que zerou a selecao de checks inteira.
COMANDO="$(printf '%s' "$BRUTO" | jq -j 'if (.tool_input | type) == "object" then (if .tool_input.command == null then empty else (.tool_input.command | tostring) end) else empty end' 2>/dev/null)"
[ -z "$COMANDO" ] && exit 0

MANIFESTO="$HDIR/hooks-manifest.json"
ERRO="$(jq empty "$MANIFESTO" 2>&1)"
if [ $? -ne 0 ]; then
  echo "[percus:dispatch-pre] hooks-manifest.json ilegivel: $(printf '%s' "$ERRO" | head -n 1)" >&2
  legado
fi

# Uma linha por check: nome<TAB>gatilhos separados por \x1f (vazios e nulos ja fora --
# o `Where-Object { $_ }` do .ps1). `registro ==` diferencia caixa, como o -ceq.
# O `tr -d '\r'` nao e enfeite: com o jq.exe nativo cada linha chega com \r, o ultimo campo
# o carrega, e gatilho "zeta\r" nunca casa -- check nenhum roda, e nada avisa.
mapfile -t CHECKS < <(jq -r '
  # verdade = o que o PowerShell considera verdadeiro. No jq so null e false sao falsos, e o // so
  # troca esses dois; no PowerShell 0, "" e @() tambem sao. Achado do R11 Cross-Claude (2026-09-13).
  # Array: 0 elementos e falso, 1 elemento vale o que o elemento vale, 2+ e verdadeiro (2a rodada do R11).
  def verdade: if type == "array" then (if length == 0 then false elif length == 1 then (.[0] | verdade) else true end) else (. != null and . != false and . != 0 and . != "") end;
  (if type == "object" then .hooks else null end) // []
  | if type == "array" then .[] else empty end
  | select(type == "object")
  | select(((.evento // "") | tostring | ascii_downcase) == "pretooluse"
       and ((.matcher // "") | tostring | ascii_downcase) == "bash|powershell"
       and (.registrado | verdade)
       and .registro == "percus-dispatch-pre")
  | [(.nome | tostring),
     ((.gatilhos // []) | if type == "array" then . else [.] end
       | map(select(verdade) | tostring) | join("\u001f"))]
  | @tsv' "$MANIFESTO" 2>/dev/null | tr -d '\r')

if [ "${#CHECKS[@]}" -eq 0 ]; then
  echo "[percus:dispatch-pre] nenhum check registrado no manifesto." >&2
  legado
fi

COMANDO_LC="${COMANDO,,}"
VEREDITO=0
RODARAM=0
for linha in "${CHECKS[@]}"; do
  nome="${linha%%$'\t'*}"
  gats=""
  [ "$linha" != "$nome" ] && gats="${linha#*$'\t'}"
  script="$HDIR/$nome.sh"

  # Tripwire de integridade: registrado e ausente e instalacao corrompida. Antes do gatilho.
  if [ ! -f "$script" ]; then
    echo "[percus:dispatch-pre] check registrado mas AUSENTE do disco: $nome.sh" >&2
    VEREDITO=2
    continue
  fi

  # Sem gatilho declarado => roda sempre (default seguro). Com gatilho, casa so o COMANDO.
  if [ -n "$gats" ]; then
    casou=0
    IFS=$'\x1f' read -r -a lista <<< "$gats"
    for g in "${lista[@]}"; do
      if contem "$COMANDO_LC" "${g,,}"; then casou=1; break; fi
    done
    [ "$casou" -eq 0 ] && continue
  fi

  if [ "$(wc -c < "$script")" -lt 200 ]; then
    echo "[percus:dispatch-pre] check '$nome' esta TRUNCADO em disco (< 200 bytes) -- instalacao corrompida." >&2
    VEREDITO=2
    continue
  fi

  printf '%s' "$BRUTO" | bash "$script"
  ec=$?
  RODARAM=$(( RODARAM + 1 ))
  # NAO para no primeiro bloqueio: quase todo check e warn-only, e o curto-circuito
  # apagaria justo o aviso deles.
  [ "$ec" -ne 0 ] && VEREDITO=2
done

[ "${PERCUS_DISPATCH_DEBUG:-}" = "1" ] && echo "[percus:dispatch-pre] checks rodados: $RODARAM de ${#CHECKS[@]} | veredito: $VEREDITO" >&2

exit $VEREDITO
