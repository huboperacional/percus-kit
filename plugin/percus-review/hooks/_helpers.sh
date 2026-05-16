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
