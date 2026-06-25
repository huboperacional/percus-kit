#!/usr/bin/env bash
# Hook PreCompact Percus - backstop de checkpoint antes da compactacao de contexto.
# Contrato (docs.claude.com hooks): evento "PreCompact", stdin JSON com
#   { session_id, transcript_path, cwd, hook_event_name, trigger("manual"|"auto") }.
# NAO bloqueia. Loga fail-loud (prova que disparou) + emite systemMessage lembrando /checkpoint.
# Falha graceful: qualquer erro -> exit 0.
set +e

STDIN=$(cat)
[ -z "$STDIN" ] && exit 0

# Skip flag
[ -n "${PERCUS_SKIP_PRECOMPACT:-}" ] && exit 0

TRIGGER=$(echo "$STDIN" | jq -r '.trigger // "unknown"' 2>/dev/null || echo "unknown")
SESSION_ID=$(echo "$STDIN" | jq -r '.session_id // ""' 2>/dev/null || echo "")

# Log fail-loud: prova que o hook disparou (anti-falha-silenciosa do pre-mortem).
mkdir -p .deepseek/checkpoint-log 2>/dev/null
TS=$(date +%Y%m%d-%H%M%S)
echo "{\"event\":\"PreCompact\",\"trigger\":\"$TRIGGER\",\"session_id\":\"$SESSION_ID\",\"timestamp\":\"$(date -Iseconds)\"}" \
    >> ".deepseek/checkpoint-log/precompact-$TS.jsonl" 2>/dev/null

# systemMessage: aviso visivel pro operador (PreCompact suporta; nao bloqueia em exit 0).
MSG="[percus:PreCompact] Contexto vai compactar (trigger=$TRIGGER). Se ainda nao rodou /checkpoint nesta sessao, rode antes: HANDOFF/PLANO podem ficar stale. (disparo logado em .deepseek/checkpoint-log/)"
jq -n --arg m "$MSG" '{systemMessage:$m}' 2>/dev/null || echo "{\"systemMessage\":\"$MSG\"}"

exit 0
