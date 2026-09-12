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
LIM_WARN=$(limiar "${PERCUS_CTX_WARN:-}" 150000)
LIM_HARD=$(limiar "${PERCUS_CTX_HARD:-}" 180000)
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
MSG="[percus:context-budget] contexto vivo ~${K}k tokens, ${HORAS}h de sessao (limiar de aviso ${KW}k)."
[ "$NIVEL" -ge 2 ] && MSG="$MSG LIMITE DURO (${KH}k) cruzado: a partir daqui a compactacao automatica e a unica saida e ela pode falhar (rate-limit); um resume em janela de 200k e impossivel."
if [ "$COND_D" -eq 1 ]; then MSG="$MSG Este transcript foi iniciado ha $DIAS dias -- e uma sessao retomada/velha. Nao continue nela: abra sessao nova e cole o bloco de retomada do HANDOFF."
elif [ "$COND_H" -eq 1 ]; then MSG="$MSG ${HORAS}h de parede na mesma sessao: o custo por passo so sobe daqui."; fi
MSG="$MSG Acao: rode percus-review:checkpoint AGORA e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto. Acima de ~${KW}k um resume futuro em janela 200k falha."
OP="[percus:hook context-budget-guard] contexto ~${K}k tokens / ${HORAS}h. Hora de checkpoint + sessao nova (veja o aviso ao agente)."

jq -n --arg sid "$SESSION_ID" --argjson t "$TOKENS" --argjson h "$HORAS" --argjson n "$NIVEL" --argjson d "$DIAS" \
  '{ts:(now|todate),session_id:$sid,tokens:$t,horas:$h,nivel:$n,dias:$d}' >> "$STATE_DIR/eventos.jsonl" 2>/dev/null
jq -n --arg a "$MSG" --arg o "$OP" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$a},systemMessage:$o}'
exit 0
