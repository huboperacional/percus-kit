#!/usr/bin/env bash
# deepseek-impl.sh — Worker DeepSeek (V4/V3.1) para implementação mecânica delegada pelo Claude.
#
# Lê um plano (texto + arquivos de contexto), chama a API DeepSeek, gera código.
# Modo --dry-run mostra resultado; --apply escreve arquivos.
# Loga em .deepseek/runs/<timestamp>.jsonl.
#
# Requer: DEEPSEEK_API_KEY no ambiente. jq e curl instalados.
#
# Uso:
#   ./deepseek-impl.sh --task plano.md --files src/foo.ts,src/bar.ts --dry-run
#   ./deepseek-impl.sh --task plano.md --files src/foo.ts --apply

set -euo pipefail

TASK=""
FILES=""
RULES="CLAUDE.md,AGENTS.md"
MODEL="deepseek-chat"
TEMPERATURE="0.0"
ENDPOINT="https://api.deepseek.com/v1/chat/completions"
APPLY=0
DRY_RUN=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --task) TASK="$2"; shift 2 ;;
        --files) FILES="$2"; shift 2 ;;
        --rules) RULES="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --temperature) TEMPERATURE="$2"; shift 2 ;;
        --endpoint) ENDPOINT="$2"; shift 2 ;;
        --apply) APPLY=1; DRY_RUN=0; shift ;;
        --dry-run) DRY_RUN=1; APPLY=0; shift ;;
        -h|--help)
            sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "Flag desconhecida: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "${DEEPSEEK_API_KEY:-}" && -f .env ]]; then
    echo "[deepseek-impl] Carregando .env do projeto..." >&2
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    echo "ERRO: DEEPSEEK_API_KEY não encontrada. Garanta que está no .env do diretório atual ou exportada." >&2
    exit 2
fi

if [[ -z "$TASK" || ! -f "$TASK" ]]; then
    echo "ERRO: --task arquivo obrigatório (não encontrado: $TASK)" >&2
    exit 2
fi

command -v jq >/dev/null  || { echo "jq não instalado." >&2; exit 2; }
command -v curl >/dev/null || { echo "curl não instalado." >&2; exit 2; }

TASK_BODY="$(cat "$TASK")"

RULES_TEXT=""
IFS=',' read -ra RULE_ARR <<< "$RULES"
for r in "${RULE_ARR[@]}"; do
    if [[ -f "$r" ]]; then
        RULES_TEXT+=$'\n=== '"$r"$' ===\n'
        RULES_TEXT+="$(cat "$r")"
        RULES_TEXT+=$'\n'
    fi
done

CONTEXT_TEXT=""
if [[ -n "$FILES" ]]; then
    IFS=',' read -ra FILE_ARR <<< "$FILES"
    for f in "${FILE_ARR[@]}"; do
        if [[ -f "$f" ]]; then
            CONTEXT_TEXT+=$'\n=== FILE: '"$f"$' ===\n'
            CONTEXT_TEXT+="$(cat "$f")"
            CONTEXT_TEXT+=$'\n=== END FILE: '"$f"$' ===\n'
        else
            echo "WARN: arquivo de contexto não encontrado, ignorando: $f" >&2
        fi
    done
fi

SYSTEM_PROMPT=$(cat <<EOF
Você é um worker de implementação mecânica delegado pelo Claude Code.

REGRAS INEGOCIÁVEIS DO PROJETO (siga literalmente):
$RULES_TEXT

DIRETRIZES DE OUTPUT:
- Para cada arquivo modificado ou criado, emita um bloco no formato:

  ===WRITE: <caminho relativo>===
  <conteúdo completo do arquivo>
  ===END===

- Para cada comando shell sugerido (migration, install, etc):

  ===SHELL===
  <comando>
  ===END===

- NÃO inclua explicações longas. Código + comandos + 1-2 linhas de comentário por bloco se for não-óbvio.
- NÃO altere arquivos fora do escopo da task.
- Se a task for ambígua ou exigir decisão arquitetural, RECUSE com bloco:

  ===REJECT===
  Motivo: <razão>
  Pergunta a esclarecer: <o que precisa decidir>
  ===END===

  Não invente decisão por conta própria.
EOF
)

USER_PROMPT=$(cat <<EOF
TASK:
$TASK_BODY

CONTEXTO DOS ARQUIVOS:
$CONTEXT_TEXT
EOF
)

PAYLOAD=$(jq -n \
    --arg model "$MODEL" \
    --argjson temp "$TEMPERATURE" \
    --arg sys "$SYSTEM_PROMPT" \
    --arg usr "$USER_PROMPT" \
    '{model: $model, temperature: $temp, stream: false,
      messages: [{role: "system", content: $sys}, {role: "user", content: $usr}]}')

TS=$(date +%Y%m%d-%H%M%S)
LOG_DIR=".deepseek/runs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$TS.jsonl"

echo "[deepseek-impl] Chamando $MODEL em $ENDPOINT..."

RESPONSE=$(curl -sS --max-time 600 -X POST "$ENDPOINT" \
    -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD") || {
    echo "ERRO: falha na chamada DeepSeek" >&2
    jq -n --arg ts "$TS" --arg err "curl failed" --argjson req "$PAYLOAD" \
        '{ts: $ts, error: $err, request: $req}' > "$LOG_FILE"
    exit 1
}

CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
USAGE=$(echo "$RESPONSE" | jq -c '.usage // {}')

if [[ -z "$CONTENT" ]]; then
    echo "ERRO: resposta vazia ou erro de API. Resposta crua:" >&2
    echo "$RESPONSE" >&2
    echo "$RESPONSE" > "$LOG_FILE"
    exit 1
fi

jq -n --arg ts "$TS" --arg model "$MODEL" --arg task "$TASK" \
      --arg files "$FILES" --arg rules "$RULES" \
      --argjson usage "$USAGE" --arg response "$CONTENT" \
   '{ts: $ts, model: $model, task: $task, files: $files, rules: $rules, usage: $usage, response: $response}' \
   > "$LOG_FILE"

PT=$(echo "$USAGE" | jq -r '.prompt_tokens // 0')
CT=$(echo "$USAGE" | jq -r '.completion_tokens // 0')
TT=$(echo "$USAGE" | jq -r '.total_tokens // 0')
echo "[deepseek-impl] Tokens: prompt=$PT completion=$CT total=$TT"
echo "[deepseek-impl] Log: $LOG_FILE"
echo

if echo "$CONTENT" | grep -q '===REJECT==='; then
    echo "WARN: DeepSeek RECUSOU a task." >&2
    echo "$CONTENT"
    exit 3
fi

# Parse blocos WRITE
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "$CONTENT" > "$TMPDIR/raw.txt"

WRITE_PATHS=()
SHELL_CMDS=()

# Awk parser para blocos
awk '
  /^===WRITE: / {
    sub(/^===WRITE: /, "")
    sub(/===$/, "")
    path=$0
    body=""
    while ((getline line) > 0) {
      if (line ~ /^===END===$/) break
      body = body line "\n"
    }
    print "WRITE\t" path > "/dev/stderr"
    fname=path
    gsub(/[\/]/, "__", fname)
    print body > "'"$TMPDIR"'/W_" fname
    next
  }
  /^===SHELL===$/ {
    cmd=""
    while ((getline line) > 0) {
      if (line ~ /^===END===$/) break
      cmd = cmd line "\n"
    }
    print "SHELL\t" cmd > "/dev/stderr"
    next
  }
' "$TMPDIR/raw.txt" 2> "$TMPDIR/blocks.log"

WRITE_COUNT=$(grep -c '^WRITE\b' "$TMPDIR/blocks.log" || true)
SHELL_COUNT=$(grep -c '^SHELL\b' "$TMPDIR/blocks.log" || true)

if [[ "$WRITE_COUNT" -eq 0 && "$SHELL_COUNT" -eq 0 ]]; then
    echo "WARN: saída sem blocos WRITE/SHELL/REJECT. Output bruto abaixo:" >&2
    echo "$CONTENT"
    exit 4
fi

echo "[deepseek-impl] Arquivos a escrever: $WRITE_COUNT"
echo "[deepseek-impl] Comandos sugeridos:  $SHELL_COUNT"
echo

while IFS=$'\t' read -r kind payload; do
    if [[ "$kind" == "WRITE" ]]; then
        fname=$(echo "$payload" | tr '/' '_')
        sz=$(wc -c < "$TMPDIR/W_$fname" | tr -d ' ')
        printf "  WRITE %-60s %8s bytes\n" "$payload" "$sz"
    elif [[ "$kind" == "SHELL" ]]; then
        printf "  SHELL %s\n" "$(echo "$payload" | head -1)"
    fi
done < "$TMPDIR/blocks.log"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo
    echo "[deepseek-impl] DRY-RUN. Nada escrito. Use --apply para aplicar."
    echo
    echo "=== RAW OUTPUT ==="
    echo "$CONTENT"
    exit 0
fi

echo
echo "[deepseek-impl] APPLY mode. Escrevendo arquivos..."

while IFS=$'\t' read -r kind payload; do
    [[ "$kind" == "WRITE" ]] || continue
    fname=$(echo "$payload" | tr '/' '_')
    dir=$(dirname "$payload")
    [[ -n "$dir" && "$dir" != "." ]] && mkdir -p "$dir"
    cp "$TMPDIR/W_$fname" "$payload"
    echo "  + $payload"
done < "$TMPDIR/blocks.log"

if [[ "$SHELL_COUNT" -gt 0 ]]; then
    echo
    echo "[deepseek-impl] Comandos shell NÃO foram executados automaticamente. Revise e rode manualmente:"
    grep '^SHELL\b' "$TMPDIR/blocks.log" | cut -f2- | sed 's/^/  /'
fi

echo
echo "[deepseek-impl] Pronto. Adicione trailer 'Co-implemented-by: deepseek-v4' ao commit message e rode /percus:review antes de commitar (R11)."
