#!/usr/bin/env bash
# Hook PostToolUse Percus (todas as tools) -- orcamento de contexto. OBSERVADOR: exit 0 sempre.
# Paridade com context-budget-guard.ps1 (a fonte da logica e o .ps1; leia o cabecalho dele).
# Le a ultima `usage` da CAUDA do transcript (tail -c), soma input + cache_read + cache_creation,
# e avisa (additionalContext + systemMessage) acima dos limiares, uma vez por nivel por sessao.
set +e

STDIN=$(cat)
[ -z "$STDIN" ] && exit 0
[ -n "${PERCUS_SKIP_CONTEXT_BUDGET:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

TRANSCRIPT=$(printf '%s' "$STDIN" | jq -r '.transcript_path // ""' 2>/dev/null)
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then exit 0; fi
SESSION_ID=$(printf '%s' "$STDIN" | jq -r '.session_id // "sem-id"' 2>/dev/null | tr -cd 'A-Za-z0-9_-')
CWD=$(printf '%s' "$STDIN" | jq -r '.cwd // ""' 2>/dev/null)
[ -d "$CWD" ] || CWD=$(pwd)

# Paridade com Get-Limiar do .ps1: valor nao-numerico ou <=0 cai no default (finding R11 2026-09-12;
# sob set +e um `[ -ge abc ]` falharia calado e o hook nunca avisaria).
limiar() { case "$1" in ''|*[!0-9]*|0) echo "$2";; *) echo "$1";; esac; }
WIN_ENV=$(limiar "${PERCUS_CTX_WINDOW:-}" 0)
WARN_ENV=$(limiar "${PERCUS_CTX_WARN:-}" 0)
HARD_ENV=$(limiar "${PERCUS_CTX_HARD:-}" 0)
LIM_HORAS=$(limiar "${PERCUS_CTX_HOURS:-}" 8)
LIM_DIAS=$(limiar "${PERCUS_CTX_RESUME_DAYS:-}" 2)

# cauda: ultima linha com usage + input_tokens (descarta a primeira linha, possivelmente cortada).
# Duas janelas: um tool_result maior que a 1a, gravado DEPOIS da usage, esconderia a medicao
# (finding R11, 2026-09-12). A 2a e o teto por chamada; acima disso a chamada seguinte recupera.
LINHA=""
TAM=$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)
for JANELA in 262144 2097152; do
  # a 1a linha da cauda so esta cortada quando a janela comecou no meio do arquivo (paridade .ps1)
  if [ "$TAM" -gt "$JANELA" ]; then
    LINHA=$(tail -c "$JANELA" "$TRANSCRIPT" | tail -n +2 | grep '"usage"[[:space:]]*:[[:space:]]*{' | grep '"input_tokens"' | tail -n 1)
  else
    LINHA=$(grep '"usage"[[:space:]]*:[[:space:]]*{' "$TRANSCRIPT" | grep '"input_tokens"' | tail -n 1)
  fi
  [ -n "$LINHA" ] && break
  [ "$TAM" -le "$JANELA" ] && break
done
[ -z "$LINHA" ] && exit 0
num() { printf '%s' "$LINHA" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*[0-9]*" | head -n1 | grep -o '[0-9]*$'; }
IN=$(num input_tokens); CR=$(num cache_read_input_tokens); CC=$(num cache_creation_input_tokens)
TOKENS=$(( ${IN:-0} + ${CR:-0} + ${CC:-0} ))
# o "model" vem na MESMA linha do usage: descobrir a janela custa zero de I/O extra (paridade .ps1)
MODELO=$(printf '%s' "$LINHA" | grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')

# ---- a janela: descoberta, nao suposta (paridade .ps1; ver cabecalho do .ps1 para o porque) ----
if [ "$WIN_ENV" -gt 0 ]; then
  JANELA_CTX=$WIN_ENV; JANELA_FONTE="PERCUS_CTX_WINDOW"
elif printf '%s' "$MODELO" | grep -Eqi '(\[1m\]|[-_]1m([^a-z0-9]|$))'; then
  JANELA_CTX=1000000; JANELA_FONTE="modelo $MODELO"
else
  JANELA_CTX=200000;  JANELA_FONTE="piso (o modelo nao declara a janela)"
fi
# perna 3: a medicao falsifica a suposicao -- sessao viva acima da janela suposta prova que a
# suposicao esta errada, sem precisar saber qual e a janela real.
# passar do piso prova que a janela NAO e a suposta; nao prova qual e. Promover pra 1M so
# trocaria uma suposicao invisivel por outra (paridade .ps1; finding R11 3a rodada).
JANELA_INCERTA=0
if [ "$WIN_ENV" -le 0 ] && [ "$TOKENS" -gt "$JANELA_CTX" ]; then
  JANELA_INCERTA=1
  # "piso" so e verdade se a suposicao veio do piso; se veio do marcador, o modelo DECLAROU
  case "$JANELA_FONTE" in
    piso*) COMO_SUPUS="o piso que eu supunha" ;;
    *)     COMO_SUPUS="o que o marcador do modelo declarava ($MODELO)" ;;
  esac
  JANELA_FONTE="INDETERMINADA (passou de ~$(( JANELA_CTX / 1000 ))k, ${COMO_SUPUS}, e a sessao continua viva)"
fi
# 75%/90% reproduz 150k/180k exatos numa janela de 200k; env explicito vence.
if [ "$WARN_ENV" -gt 0 ]; then LIM_WARN=$WARN_ENV; else LIM_WARN=$(( JANELA_CTX * 75 / 100 )); fi
if [ "$HARD_ENV" -gt 0 ]; then LIM_HARD=$HARD_ENV; else LIM_HARD=$(( JANELA_CTX * 90 / 100 )); fi

# cabeca: primeiro timestamp -> horas de parede
TS0=$(head -c 8192 "$TRANSCRIPT" | grep -o '"timestamp"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')
HORAS=0
if [ -n "$TS0" ]; then
  T0=$(date -u -d "$TS0" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%S" "${TS0%%.*}" +%s 2>/dev/null || echo "")
  [ -n "$T0" ] && HORAS=$(( ( $(date -u +%s) - T0 ) / 3600 ))
  [ "$HORAS" -lt 0 ] && HORAS=0
fi
DIAS=$(( HORAS / 24 ))

NIVEL=0
[ "$TOKENS" -ge "$LIM_WARN" ] && NIVEL=1
[ "$TOKENS" -ge "$LIM_HARD" ] && NIVEL=2
# LIMITE DURO afirma "falta pouco pro teto" e com a janela indeterminada eu nao sei onde ele esta
# se o operador declarou PERCUS_CTX_HARD, o teto e dele: rebaixar ali silenciaria o limite que
# ele mesmo configurou (paridade .ps1; finding R11 4a rodada)
[ "$JANELA_INCERTA" -eq 1 ] && [ "$HARD_ENV" -le 0 ] && [ "$NIVEL" -ge 2 ] && NIVEL=1
COND_H=0; [ "$HORAS" -ge "$LIM_HORAS" ] && COND_H=1
COND_D=0; [ "$DIAS" -ge "$LIM_DIAS" ] && COND_D=1

STATE_DIR="$CWD/.deepseek/context-budget"; mkdir -p "$STATE_DIR" 2>/dev/null
STATE="$STATE_DIR/$SESSION_ID.json"
ST_N=0; ST_H=0; ST_D=0
if [ -f "$STATE" ]; then
  ST_N=$(jq -r '.nivel // 0' "$STATE" 2>/dev/null); ST_H=$(jq -r 'if .horas then 1 else 0 end' "$STATE" 2>/dev/null); ST_D=$(jq -r 'if .dias then 1 else 0 end' "$STATE" 2>/dev/null)
fi
FALA=0
[ "$NIVEL" -gt "${ST_N:-0}" ] && FALA=1
[ "$COND_H" -eq 1 ] && [ "${ST_H:-0}" -eq 0 ] && FALA=1
[ "$COND_D" -eq 1 ] && [ "${ST_D:-0}" -eq 0 ] && FALA=1
[ "$FALA" -eq 0 ] && exit 0

NN=$NIVEL; [ "${ST_N:-0}" -gt "$NN" ] && NN=$ST_N
NH=$(( COND_H | ${ST_H:-0} )); ND=$(( COND_D | ${ST_D:-0} ))
jq -n --argjson n "$NN" --argjson h "$([ $NH -eq 1 ] && echo true || echo false)" --argjson d "$([ $ND -eq 1 ] && echo true || echo false)" --argjson t "$TOKENS" \
  '{nivel:$n,horas:$h,dias:$d,tokens:$t,ts:(now|todate)}' > "$STATE" 2>/dev/null

K=$(( (TOKENS + 500) / 1000 )); KW=$(( LIM_WARN / 1000 )); KH=$(( LIM_HARD / 1000 ))
KJ=$(( JANELA_CTX / 1000 )); PCT=$(( TOKENS * 100 / JANELA_CTX ))
if [ "$JANELA_INCERTA" -eq 1 ]; then PCT_TXT="janela indeterminada"; else PCT_TXT="${PCT}% da janela"; fi
if [ "$JANELA_INCERTA" -eq 1 ]; then
  MSG="[percus:context-budget] contexto vivo ~${K}k tokens, ${HORAS}h de sessao. Janela ${JANELA_FONTE} -- entao ela e MAIOR que isso, mas eu nao sei quanto, e sem o denominador nao da pra dizer se voce esta perto do teto. Defina PERCUS_CTX_WINDOW pra eu voltar a medir percentual."
else
  MSG="[percus:context-budget] contexto vivo ~${K}k tokens (${PCT}% de uma janela ~${KJ}k -- ${JANELA_FONTE}), ${HORAS}h de sessao; limiar de aviso ${KW}k."
fi
if [ "$NIVEL" -ge 2 ] && [ "$JANELA_INCERTA" -eq 1 ]; then
  # so se chega aqui com PERCUS_CTX_HARD declarado; o teto e do operador, mas a mensagem nao pode
  # carregar a janela junto -- e o denominador que a 1a frase acabou de negar (paridade .ps1)
  MSG="$MSG LIMITE DURO (${KH}k, que voce configurou em PERCUS_CTX_HARD) cruzado: a partir daqui a compactacao automatica e a unica saida e ela pode falhar (rate-limit)."
elif [ "$NIVEL" -ge 2 ]; then
  MSG="$MSG LIMITE DURO (${KH}k) cruzado: a partir daqui a compactacao automatica e a unica saida e ela pode falhar (rate-limit); um resume em janela ~${KJ}k e impossivel."
  # paridade .ps1: entre 90% e 100% de um PISO adivinhado o hook nao tem como saber se a janela
  # esta certa -- a duvida vira linha acionavel em vez de certeza falsa
  case "$JANELA_FONTE" in
    piso*) MSG="$MSG ATENCAO: a janela ~${KJ}k acima e um PISO adivinhado -- o modelo nao a declara. Se esta sessao tem janela maior (ex.: variante 1M), este aviso e falso: confira o painel de contexto e, se for o caso, sete PERCUS_CTX_WINDOW." ;;
  esac
fi
if [ "$COND_D" -eq 1 ]; then MSG="$MSG Este transcript foi iniciado ha $DIAS dias -- e uma sessao retomada/velha. Nao continue nela: abra sessao nova e cole o bloco de retomada do HANDOFF."
elif [ "$COND_H" -eq 1 ]; then MSG="$MSG ${HORAS}h de parede na mesma sessao: o custo por passo so sobe daqui."; fi
if [ "$JANELA_INCERTA" -eq 1 ]; then
  MSG="$MSG Acao: rode percus-review:checkpoint e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto."
else
  MSG="$MSG Acao: rode percus-review:checkpoint e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto. Acima de ~${KW}k um resume futuro em janela ~${KJ}k falha."
fi
# o operador so e avisado se pedir: ele ve o contexto no painel do VSCode (decisao dele 2026-09-12)
OP=""
[ "$(limiar "${PERCUS_CTX_OPERADOR:-}" 0)" -gt 0 ] && OP="[percus:hook context-budget-guard] contexto ~${K}k tokens / ${HORAS}h (${PCT_TXT}). Hora de checkpoint + sessao nova (veja o aviso ao agente)."

jq -n --arg sid "$SESSION_ID" --argjson t "$TOKENS" --argjson h "$HORAS" --argjson n "$NIVEL" --argjson d "$DIAS" \
  '{ts:(now|todate),session_id:$sid,tokens:$t,horas:$h,nivel:$n,dias:$d}' >> "$STATE_DIR/eventos.jsonl" 2>/dev/null
if [ -n "$OP" ]; then
  jq -n --arg a "$MSG" --arg o "$OP" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$a},systemMessage:$o}'
else
  jq -n --arg a "$MSG" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$a}}'
fi
exit 0
