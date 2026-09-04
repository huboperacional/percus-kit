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
# Canonicaliza (achado no code-review, R11): find_percus_nearest_config_dir devolve path
# RESOLVIDO ($(cd ... && pwd)). O walk-up de busca do tsc compara contra $project_root pra
# saber quando parar -- se $project_root ficar CRU (a string literal do `cd "..."` do
# comando), a comparacao nunca bate. Pior que no PS1: dirname "/" devolve "/" pra sempre,
# entao o loop NAO TEM outra saida e o commit trava pra sempre (DoS real, nao so escape de
# fronteira).
project_root=$(cd "$project_root" && pwd)

py_files=$(get_percus_staged_files "$project_root" .py)
ts_files=$(get_percus_staged_files "$project_root" .ts .tsx)

errors=()
sem_venv=()
sem_tsconfig=()

# Agrupa os arquivos staged pelo diretorio mais proximo (subindo a arvore) que tem o
# marker. dirs_out/files_out sao arrays PARALELOS (bash nao tem array-de-array facil):
# dirs_out[i] e um diretorio distinto achado; files_out[i] e a lista de arquivos daquele
# grupo, separada por newline. sem_out recebe os arquivos sem NENHUM marker ate a raiz.
group_by_nearest_config() {
    local marker="$1"; shift
    local files=("$@")
    dirs_out=(); files_out=(); sem_out=()
    local f dir idx found
    for f in "${files[@]}"; do
        [[ -z "$f" ]] && continue
        if dir=$(find_percus_nearest_config_dir "$project_root" "$f" "$marker"); then
            found=0
            for idx in "${!dirs_out[@]}"; do
                if [[ "${dirs_out[$idx]}" == "$dir" ]]; then
                    files_out[$idx]+=$'\n'"$f"
                    found=1
                    break
                fi
            done
            [[ $found -eq 0 ]] && { dirs_out+=("$dir"); files_out+=("$f"); }
        else
            sem_out+=("$f")
        fi
    done
}

# mypy --strict
if [[ -n "$py_files" ]]; then
    mapfile -t py_arr <<< "$py_files"
    group_by_nearest_config ".venv" "${py_arr[@]}"
    sem_venv=("${sem_out[@]}")

    for idx in "${!dirs_out[@]}"; do
        [[ ${#errors[@]} -ge 10 ]] && break
        venv_dir="${dirs_out[$idx]}"
        # .venv achado NO diretorio (o marker JA E o proprio .venv) -- binario sempre co-localizado.
        mypy_cmd=""
        if [[ -x "$venv_dir/.venv/bin/mypy" ]]; then
            mypy_cmd="$venv_dir/.venv/bin/mypy"
        elif command -v mypy >/dev/null 2>&1; then
            mypy_cmd="mypy"
        fi
        [[ -z "$mypy_cmd" ]] && continue

        existing=()
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            [[ -f "$project_root/$f" ]] && existing+=("$f")
        done <<< "${files_out[$idx]}"
        [[ ${#existing[@]} -eq 0 ]] && continue

        cd "$project_root"
        mypy_out=$("$mypy_cmd" --strict --no-error-summary --show-error-codes "${existing[@]}" 2>&1 || true)
        while IFS= read -r line; do
            [[ "$line" == *": error:"* ]] && errors+=("mypy :: $line")
            [[ ${#errors[@]} -ge 10 ]] && break
        done <<< "$mypy_out"
    done
fi

# Sem .venv achavel a partir de algum .py staged (best-effort continua best-effort, mas
# falado -- skip silencioso e o pior dos dois mundos, finge que protegeu).
if [[ ${#sem_venv[@]} -gt 0 ]]; then
    echo "[percus:warn types-check] AVISO: ${#sem_venv[@]} arquivo(s) .py staged, mas nenhum .venv encontrado a partir deles -- checagem mypy PULADA. Isto nao e um 'ok'." >&2
fi

# tsc --noEmit
if [[ -n "$ts_files" ]] && [[ ${#errors[@]} -lt 10 ]]; then
    mapfile -t ts_arr <<< "$ts_files"
    group_by_nearest_config "tsconfig.json" "${ts_arr[@]}"
    sem_tsconfig=("${sem_out[@]}")

    for idx in "${!dirs_out[@]}"; do
        [[ ${#errors[@]} -ge 10 ]] && break
        tsconfig_dir="${dirs_out[$idx]}"
        # tsc pode NAO estar co-localizado com o tsconfig (report Plexco #2) -- sobe a
        # partir do dir do tsconfig ate project_root procurando node_modules/.bin/tsc.
        tsc_cmd=""
        walk_dir="$tsconfig_dir"
        while :; do
            if [[ -x "$walk_dir/node_modules/.bin/tsc" ]]; then
                tsc_cmd="$walk_dir/node_modules/.bin/tsc"
                break
            fi
            [[ "$walk_dir" == "$project_root" ]] && break
            walk_dir=$(dirname "$walk_dir")
        done
        [[ -z "$tsc_cmd" ]] && command -v tsc >/dev/null 2>&1 && tsc_cmd="tsc"
        [[ -z "$tsc_cmd" ]] && continue

        cd "$project_root"
        # -p explicito (nao depende do CWD ter o tsconfig): path do erro sai relativo ao
        # CWD de invocacao com '/' -- confirmado empiricamente contra TypeScript real,
        # bate com o formato de $ts_files (git diff --name-only).
        tsc_out=$("$tsc_cmd" -p "$tsconfig_dir/tsconfig.json" --noEmit --pretty false 2>&1 || true)
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
    done
fi

if [[ ${#sem_tsconfig[@]} -gt 0 ]]; then
    echo "[percus:warn types-check] AVISO: ${#sem_tsconfig[@]} arquivo(s) .ts/.tsx staged, mas nenhum tsconfig.json encontrado a partir deles -- checagem tsc PULADA. Isto nao e um 'ok'." >&2
fi

[[ ${#errors[@]} -eq 0 ]] && exit 0

write_percus_block "types-check" \
    "${#errors[@]} erro(s) de tipo em arquivos staged (R5 — tipos explicitos, mypy --strict / tsc --noEmit)." \
    "${errors[@]}" \
    "Corrija os tipos OU use:" \
    "  PERCUS_SKIP_TYPES_CHECK=1 (declarar motivo em voz alta)."
exit 2
