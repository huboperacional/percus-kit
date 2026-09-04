#!/usr/bin/env bash
# Helpers compartilhados pelos hooks Percus. Source via:
#   source "$(dirname "$0")/_helpers.sh"

resolve_percus_project_root() {
    local command="$1"
    if [[ -n "$command" ]]; then
        if [[ "$command" =~ cd[[:space:]]+\"([^\"]+)\" ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        fi
        if [[ "$command" =~ cd[[:space:]]+\'([^\']+)\' ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        fi
        if [[ "$command" =~ cd[[:space:]]+([^[:space:]\&\;]+) ]]; then
            local candidate="${BASH_REMATCH[1]}"
            candidate="${candidate%\"}"; candidate="${candidate#\"}"
            candidate="${candidate%\'}"; candidate="${candidate#\'}"
            if [[ -d "$candidate" ]]; then
                echo "$candidate"
                return
            fi
        fi
    fi
    pwd
}

get_percus_staged_files() {
    local project_root="$1"
    shift
    local exts=("$@")
    [[ -d "$project_root/.git" ]] || return 0
    local files
    files=$(git -C "$project_root" diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
    [[ -z "$files" ]] && return 0
    if [[ ${#exts[@]} -eq 0 ]]; then
        echo "$files"
        return
    fi
    while IFS= read -r f; do
        for ext in "${exts[@]}"; do
            if [[ "$f" == *"$ext" ]]; then
                echo "$f"
                break
            fi
        done
    done <<< "$files"
}

find_percus_nearest_config_dir() {
    # Acha o diretorio mais proximo (subindo a arvore a partir de um arquivo staged,
    # parando em project_root) que contem um marker (arquivo ou pasta). Resolve monorepo
    # (tsconfig.json/.venv numa subpasta como frontend/, nao na raiz) sem o hook precisar
    # saber o layout. Devolvida Plexco Tasks 2026-09-04 (equivalente bash de
    # Find-PercusNearestConfigDir em _helpers.ps1 -- mantenha os dois em paridade).
    local project_root="$1" rel_file="$2" marker="$3"
    local root dir
    root=$(cd "$project_root" && pwd)
    dir=$(dirname "$root/$rel_file")
    while [[ "$dir" == "$root"* ]]; do
        if [[ -e "$dir/$marker" ]]; then
            echo "$dir"
            return 0
        fi
        [[ "$dir" == "$root" ]] && break
        dir=$(dirname "$dir")
    done
    return 1
}

get_percus_staged_content() {
    local project_root="$1"
    local rel_path="$2"
    git -C "$project_root" show ":${rel_path}" 2>/dev/null
}

write_percus_block() {
    local hook_name="$1"
    shift
    echo "[percus:hook $hook_name] BLOCK:" >&2
    for line in "$@"; do
        echo "  $line" >&2
    done
}
