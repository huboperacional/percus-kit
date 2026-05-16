#!/usr/bin/env bash
# Hook pre-plan-exit Percus (Unix). Bloqueia ExitPlanMode em plano >500 linhas sem pre-mortem recente.
# Escape: PERCUS_PREMORTEM_OVERRIDE=1.

set -eo pipefail
source "$(dirname "$0")/_helpers.sh"

stdin_data=$(cat || true)
[[ -z "$stdin_data" ]] && exit 0

tool_name=$(echo "$stdin_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
[[ "$tool_name" != "ExitPlanMode" ]] && exit 0

[[ -n "$PERCUS_HOOKS_DISABLED" ]] && exit 0

plan=$(echo "$stdin_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('plan',''))" 2>/dev/null || echo "")
[[ -z "$plan" ]] && exit 0

line_count=$(echo "$plan" | wc -l)
[[ $line_count -le 500 ]] && exit 0

log_dir=".deepseek/council-log"

if [[ -n "$PERCUS_PREMORTEM_OVERRIDE" ]]; then
    mkdir -p "$log_dir"
    cat >> "$log_dir/pre-mortem-override.jsonl" <<EOF
{"timestamp":"$(date -Iseconds)","plan_lines":$line_count,"cwd":"$(pwd)","reason":"PERCUS_PREMORTEM_OVERRIDE=1"}
EOF
    exit 0
fi

if [[ -d "$log_dir" ]]; then
    latest=$(ls -t "$log_dir"/*-pre-mortem.jsonl 2>/dev/null | head -1 || true)
    if [[ -n "$latest" ]]; then
        # mtime within 15 minutes?
        if [[ $(find "$latest" -mmin -15 -print 2>/dev/null) ]]; then
            exit 0
        fi
    fi
fi

write_percus_block "pre-plan-exit" \
    "plano tem $line_count linhas (>500) e nao tem pre-mortem recente em .deepseek/council-log/ (max 15min)." \
    "Rode antes de ExitPlanMode:" \
    "  /council:pre-mortem  (ou) bash scripts/council-orchestrator.sh --mode pre-mortem --providers deepseek,groq-llama,cross-claude" \
    "Escape (com motivo declarado): PERCUS_PREMORTEM_OVERRIDE=1 (logado)."
exit 2
