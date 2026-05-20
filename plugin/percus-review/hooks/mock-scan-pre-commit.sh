#!/usr/bin/env bash
# Hook pre-commit Percus mock-scan (R3) - Unix.
# Skip explicito: commit message com 'MOCK-OK:' OU PERCUS_SKIP_MOCK_SCAN=1.

set -eo pipefail
source "$(dirname "$0")/_helpers.sh"

stdin_data=$(cat || true)
[[ -z "$stdin_data" ]] && exit 0

command=$(echo "$stdin_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[[ -z "$command" ]] && exit 0

[[ "$command" =~ git[[:space:]]+commit ]] || exit 0
[[ "$command" =~ git[[:space:]]+commit[[:space:]]+--amend[[:space:]]+--no-edit ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" || -n "$PERCUS_SKIP_MOCK_SCAN" ]] && exit 0

# MOCK-OK escape on commit message
if [[ "$command" =~ -m[[:space:]]+\"([^\"]+)\" ]]; then
    [[ "${BASH_REMATCH[1]}" =~ MOCK-OK: ]] && exit 0
fi
if [[ "$command" =~ -m[[:space:]]+\'([^\']+)\' ]]; then
    [[ "${BASH_REMATCH[1]}" =~ MOCK-OK: ]] && exit 0
fi

project_root=$(resolve_percus_project_root "$command")
[[ -d "$project_root/.git" ]] || exit 0

files=$(get_percus_staged_files "$project_root" .py .ts .tsx .js .jsx .go .rs .java .css .html .vue .svelte .sql)
[[ -z "$files" ]] && exit 0

# Patterns: "regex|why"
declare -a patterns=(
    '\bMOCK_(?!OK\b)\w+|identificador MOCK_*'
    '\b(?-i:TODO|FIXME|XXX|HACK)\b[: ]|TODO/FIXME/XXX/HACK pendente'
    'lorem[[:space:]]+ipsum|lorem ipsum'
    'dummy_|dummy_'
    'placeholder_value|placeholder_value'
    'https?://localhost:[0-9]+|URL localhost:porta hardcoded'
    'hardcoded|comentario hardcoded'
)

findings=()
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    content=$(get_percus_staged_content "$project_root" "$f")
    [[ -z "$content" ]] && continue
    line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        for p in "${patterns[@]}"; do
            re="${p%%|*}"
            why="${p##*|}"
            if echo "$line" | grep -qiP "$re" 2>/dev/null; then
                trimmed=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-80)
                findings+=("${f}:${line_num} -> ${why} :: ${trimmed}")
                break
            fi
        done
        [[ ${#findings[@]} -ge 10 ]] && break
    done <<< "$content"
    [[ ${#findings[@]} -ge 10 ]] && break
done <<< "$files"

[[ ${#findings[@]} -eq 0 ]] && exit 0

write_percus_block "mock-scan" \
    "encontrados ${#findings[@]}+ padrao(es) de mock/placeholder em arquivos staged (R3)." \
    "${findings[@]}" \
    "Remova o mock OU use commit message comecando com 'MOCK-OK: <motivo>' pra pular." \
    "Skip permanente: PERCUS_SKIP_MOCK_SCAN=1 (declarar motivo em voz alta)."
exit 2
