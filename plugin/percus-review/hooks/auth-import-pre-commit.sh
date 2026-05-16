#!/usr/bin/env bash
# Hook pre-commit Percus auth-import (R7) - Unix.
# Skip: PERCUS_SKIP_AUTH_IMPORT=1.

set -eo pipefail
source "$(dirname "$0")/_helpers.sh"

stdin_data=$(cat || true)
[[ -z "$stdin_data" ]] && exit 0

command=$(echo "$stdin_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[[ -z "$command" ]] && exit 0

[[ "$command" =~ git[[:space:]]+commit ]] || exit 0
[[ "$command" =~ git[[:space:]]+commit[[:space:]]+--amend[[:space:]]+--no-edit ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" || -n "$PERCUS_SKIP_AUTH_IMPORT" ]] && exit 0

project_root=$(resolve_percus_project_root "$command")
[[ -d "$project_root/.git" ]] || exit 0

py_files=$(get_percus_staged_files "$project_root" .py)
ts_files=$(get_percus_staged_files "$project_root" .ts .tsx .js .jsx .mjs .cjs)

findings=()

# Python: from gotrue / import supabase
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    content=$(get_percus_staged_content "$project_root" "$f")
    [[ -z "$content" ]] && continue
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        lineno=$(echo "$match" | cut -d: -f1)
        text=$(echo "$match" | cut -d: -f2- | sed 's/^[[:space:]]*//')
        findings+=("${f}:${lineno} -> gotrue/supabase-py — use percus-auth :: $text")
        [[ ${#findings[@]} -ge 10 ]] && break
    done < <(echo "$content" | grep -nP '^\s*(from|import)\s+(gotrue|supabase)\b' 2>/dev/null || true)
    [[ ${#findings[@]} -ge 10 ]] && break
done <<< "$py_files"

# TS/JS: @supabase / next-auth / @auth
if [[ ${#findings[@]} -lt 10 ]]; then
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        content=$(get_percus_staged_content "$project_root" "$f")
        [[ -z "$content" ]] && continue
        while IFS= read -r match; do
            [[ -z "$match" ]] && continue
            lineno=$(echo "$match" | cut -d: -f1)
            text=$(echo "$match" | cut -d: -f2- | sed 's/^[[:space:]]*//')
            findings+=("${f}:${lineno} -> @supabase/next-auth/@auth — use percus-auth :: $text")
            [[ ${#findings[@]} -ge 10 ]] && break
        done < <(echo "$content" | grep -nP "(from\s+['\"](@supabase/|next-auth|@auth/))|require\(['\"]@supabase/" 2>/dev/null || true)
        [[ ${#findings[@]} -ge 10 ]] && break
    done <<< "$ts_files"
fi

[[ ${#findings[@]} -eq 0 ]] && exit 0

write_percus_block "auth-import" \
    "encontrados ${#findings[@]} import(s) de auth providers vetados (R7)." \
    "${findings[@]}" \
    "Migre pra percus-auth ou GET https://auth.huboperacional.com.br/." \
    "Ver _Novo_Projeto/02_INFRA_E_STACK_PERCUS.md secao 'Auth'." \
    "Skip (raro): PERCUS_SKIP_AUTH_IMPORT=1"
exit 2
