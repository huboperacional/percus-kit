#!/usr/bin/env bash
# Hook pre-commit Percus types-check (R5) - Unix.
# Skip: PERCUS_SKIP_TYPES_CHECK=1.

set -eo pipefail
source "$(dirname "$0")/_helpers.sh"

stdin_data=$(cat || true)
[[ -z "$stdin_data" ]] && exit 0

command=$(echo "$stdin_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[[ -z "$command" ]] && exit 0

[[ "$command" =~ git[[:space:]]+commit ]] || exit 0
[[ "$command" =~ git[[:space:]]+commit[[:space:]]+--amend[[:space:]]+--no-edit ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" || -n "$PERCUS_SKIP_TYPES_CHECK" ]] && exit 0

project_root=$(resolve_percus_project_root "$command")
[[ -d "$project_root/.git" ]] || exit 0

py_files=$(get_percus_staged_files "$project_root" .py)
ts_files=$(get_percus_staged_files "$project_root" .ts .tsx)

errors=()

# mypy --strict
if [[ -n "$py_files" ]]; then
    mypy_cmd=""
    if [[ -x "$project_root/.venv/bin/mypy" ]]; then
        mypy_cmd="$project_root/.venv/bin/mypy"
    elif command -v mypy >/dev/null 2>&1; then
        mypy_cmd="mypy"
    fi

    if [[ -n "$mypy_cmd" ]]; then
        # Filtra arquivos existentes
        existing=()
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            [[ -f "$project_root/$f" ]] && existing+=("$f")
        done <<< "$py_files"

        if [[ ${#existing[@]} -gt 0 ]]; then
            cd "$project_root"
            mypy_out=$("$mypy_cmd" --strict --no-error-summary --show-error-codes "${existing[@]}" 2>&1 || true)
            while IFS= read -r line; do
                [[ "$line" == *": error:"* ]] && errors+=("mypy :: $line")
                [[ ${#errors[@]} -ge 10 ]] && break
            done <<< "$mypy_out"
        fi
    fi
fi

# tsc --noEmit
if [[ -n "$ts_files" ]] && [[ ${#errors[@]} -lt 10 ]]; then
    tsc_cmd=""
    if [[ -x "$project_root/node_modules/.bin/tsc" ]]; then
        tsc_cmd="$project_root/node_modules/.bin/tsc"
    elif command -v tsc >/dev/null 2>&1; then
        tsc_cmd="tsc"
    fi

    if [[ -n "$tsc_cmd" && -f "$project_root/tsconfig.json" ]]; then
        cd "$project_root"
        tsc_out=$("$tsc_cmd" --noEmit --pretty false 2>&1 || true)
        # Filtra erros TS que mencionam arquivos staged
        while IFS= read -r line; do
            [[ "$line" == *"error TS"* ]] || continue
            for f in $ts_files; do
                if [[ "$line" == *"$f"* ]]; then
                    errors+=("tsc :: $line")
                    break
                fi
            done
            [[ ${#errors[@]} -ge 10 ]] && break
        done <<< "$tsc_out"
    fi
fi

[[ ${#errors[@]} -eq 0 ]] && exit 0

write_percus_block "types-check" \
    "${#errors[@]} erro(s) de tipo em arquivos staged (R5 — tipos explicitos, mypy --strict / tsc --noEmit)." \
    "${errors[@]}" \
    "Corrija os tipos OU use:" \
    "  PERCUS_SKIP_TYPES_CHECK=1 (declarar motivo em voz alta)."
exit 2
