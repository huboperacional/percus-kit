#!/usr/bin/env bash
# Hook pre-commit Percus migration-check (R6) - Unix.
# Skip: PERCUS_SKIP_MIGRATION_CHECK=1.

set -eo pipefail
source "$(dirname "$0")/_helpers.sh"

stdin_data=$(cat || true)
[[ -z "$stdin_data" ]] && exit 0

command=$(echo "$stdin_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[[ -z "$command" ]] && exit 0

[[ "$command" =~ git[[:space:]]+commit ]] || exit 0
[[ "$command" =~ git[[:space:]]+commit[[:space:]]+--amend[[:space:]]+--no-edit ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" || -n "$PERCUS_SKIP_MIGRATION_CHECK" ]] && exit 0

project_root=$(resolve_percus_project_root "$command")
[[ -d "$project_root/.git" ]] || exit 0

staged=$(get_percus_staged_files "$project_root")
[[ -z "$staged" ]] && exit 0

# Detecta arquivos de modelo
model_files=$(echo "$staged" | grep -iE '(^|/)(models?|schemas?|tables|entities|orm)(/|.*models?\.py$|.*entity\.py$)' | grep -E '\.py$' || true)
[[ -z "$model_files" ]] && exit 0

# Detecta migration nova (Added)
new_files=$(git -C "$project_root" diff --cached --name-only --diff-filter=A 2>/dev/null || true)
new_migrations=$(echo "$new_files" | grep -iE '(^|/)(alembic/versions|migrations)/.+\.(py|sql)$' || true)
[[ -n "$new_migrations" ]] && exit 0

# Verifica delta nos modelos
suspicious=()
while IFS= read -r mf; do
    [[ -z "$mf" ]] && continue
    diff_out=$(git -C "$project_root" diff --cached -- "$mf" 2>/dev/null || true)
    [[ -z "$diff_out" ]] && continue
    while IFS= read -r line; do
        if [[ "$line" =~ ^\+[^+] ]] && echo "$line" | grep -qE '(Column\s*\(|relationship\s*\(|__tablename__|primary_key|ForeignKey|Index\s*\(|CheckConstraint)'; then
            trimmed=$(echo "$line" | sed 's/^+//; s/^[[:space:]]*//' | cut -c1-80)
            suspicious+=("${mf} :: ${trimmed}")
            [[ ${#suspicious[@]} -ge 5 ]] && break
        fi
    done <<< "$diff_out"
    [[ ${#suspicious[@]} -ge 5 ]] && break
done <<< "$model_files"

[[ ${#suspicious[@]} -eq 0 ]] && exit 0

write_percus_block "migration-check" \
    "modelo(s) alterado(s) parece(m) schema change, mas nenhuma migration nova staged (R6)." \
    "${suspicious[@]}" \
    "Gere a migration: 'alembic revision --autogenerate -m <descricao>' e stage o arquivo." \
    "Se delta nao precisa de migration (rename Python, docstring), use:" \
    "  PERCUS_SKIP_MIGRATION_CHECK=1 (declarar motivo em voz alta)."
exit 2
