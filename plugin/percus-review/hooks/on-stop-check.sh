#!/usr/bin/env bash
# Hook on-stop Percus — graceful failure
set +e

STDIN=$(cat)
[ -z "$STDIN" ] && exit 0

TRANSCRIPT=$(echo "$STDIN" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

# Skip flag
if [ -n "${PERCUS_SKIP_HANDOFF:-}" ]; then
  mkdir -p .deepseek
  echo "$(date -Iseconds) | skip flag used | transcript=$TRANSCRIPT" >> .deepseek/handoff-skipped.log
  exit 0
fi

CODE_EXT_REGEX='\.(py|ts|tsx|js|jsx|sql|go|rs|java|css|html|vue|svelte)$'

CODE_EDITS=0
HANDOFF_EDITED=0

while IFS= read -r line; do
  if echo "$line" | grep -qE '"tool_name"[[:space:]]*:[[:space:]]*"(Edit|Write|NotebookEdit)"'; then
    FILE=$(echo "$line" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    [ -z "$FILE" ] && continue
    BASE=$(basename "$FILE")
    if [ "$BASE" = "HANDOFF.md" ]; then HANDOFF_EDITED=1
    elif echo "$FILE" | grep -qiE "$CODE_EXT_REGEX"; then CODE_EDITS=$((CODE_EDITS + 1))
    fi
  fi
done < "$TRANSCRIPT"

# ── Catalog auto-publish (v6.0.0+) ──────────────────────────────────────
# Se transcript editou catalog-info.yaml, dispara catalog_publish.py em background.
if [ -z "${PERCUS_SKIP_CATALOG_PUBLISH:-}" ]; then
  CATALOG_EDITED=0
  while IFS= read -r line; do
    if echo "$line" | grep -qE '"tool_name"[[:space:]]*:[[:space:]]*"(Edit|Write)"' && \
       echo "$line" | grep -qE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*catalog-info\.yaml"'; then
      CATALOG_EDITED=1
      break
    fi
  done < "$TRANSCRIPT"

  if [ $CATALOG_EDITED -eq 1 ] && [ -f "catalog-info.yaml" ]; then
    PUBLISH_SCRIPT="/d/Claud Automations/_Novo_Projeto/plugin/percus-review/scripts/catalog_publish.py"
    # Suporta tambem path Linux/macOS
    [ ! -f "$PUBLISH_SCRIPT" ] && PUBLISH_SCRIPT="$HOME/.claude-plugins/percus-tools/percus-review/scripts/catalog_publish.py"
    if [ -f "$PUBLISH_SCRIPT" ]; then
      mkdir -p .deepseek
      nohup python3 "$PUBLISH_SCRIPT" > .deepseek/catalog-publish.log 2> .deepseek/catalog-publish.log.err &
      echo "[percus:hook on-stop] catalog-publish disparado em background (log: .deepseek/catalog-publish.log)" >&2
    fi
  fi
fi

[ $CODE_EDITS -eq 0 ] && exit 0
[ $HANDOFF_EDITED -eq 1 ] && exit 0

echo "[percus:hook on-stop] BLOCK: sessao tocou $CODE_EDITS arquivo(s) de codigo mas HANDOFF.md nao foi atualizado (R8)." >&2
echo "Atualize HANDOFF.md antes de encerrar OU defina PERCUS_SKIP_HANDOFF=1 com motivo declarado em voz alta." >&2
echo "Skip fica logado em .deepseek/handoff-skipped.log." >&2
exit 2
