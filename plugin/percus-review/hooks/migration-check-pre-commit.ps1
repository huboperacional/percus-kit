#requires -Version 5.1
# Hook pre-commit Percus migration-check (R6).
# Bloqueia commit se staged diff modifica modelos (SQLAlchemy/Pydantic) sem
# uma migration nova correspondente em alembic/versions/ (ou migrations/).
# Skip: $env:PERCUS_SKIP_MIGRATION_CHECK=1 (declarar motivo em voz alta).

. "$PSScriptRoot\_helpers.ps1"

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $command = $input.tool_input.command

    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }
    if ($env:PERCUS_HOOKS_DISABLED -or $env:PERCUS_SKIP_MIGRATION_CHECK) { exit 0 }

    $projectRoot = Resolve-PercusProjectRoot -Command $command
    if (-not (Test-Path (Join-Path $projectRoot ".git"))) { exit 0 }

    $stagedAll = Get-PercusStagedFiles -ProjectRoot $projectRoot
    if (-not $stagedAll -or $stagedAll.Count -eq 0) { exit 0 }

    # Detecta arquivos de modelo (SQLAlchemy/Pydantic table models).
    # Heuristica: paths que contem /models/, /db/models/, /database/models/,
    # ou /schema/*.py, /tables/*.py, /entities/*.py.
    $modelRe = '(?i)(^|/)(models?|schemas?|tables|entities|orm)(/|.*models?\.py$|.*entity\.py$)'
    $modelFiles = $stagedAll | Where-Object {
        $_ -match '\.py$' -and ($_ -match $modelRe)
    }

    if (-not $modelFiles -or $modelFiles.Count -eq 0) { exit 0 }

    # Detecta migration nova staged.
    # Alembic: alembic/versions/<rev>_*.py (NOVO arquivo)
    # Custom: migrations/*.sql (NOVO arquivo)
    $migrationRe = '(?i)(^|/)(alembic/versions|migrations)/.+\.(py|sql)$'

    # Get only Added files (--diff-filter=A)
    $newFiles = & git -C $projectRoot diff --cached --name-only --diff-filter=A 2>$null
    $newMigrations = @($newFiles | Where-Object { $_ -match $migrationRe })

    if ($newMigrations.Count -gt 0) { exit 0 }

    # Detecta delta nos modelos que parece schema change (add/drop/alter Column, table_name, __tablename__)
    $suspicious = @()
    foreach ($mf in $modelFiles) {
        $diff = & git -C $projectRoot diff --cached -- $mf 2>$null
        if (-not $diff) { continue }
        $addLines = $diff -split "`n" | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' }
        foreach ($line in $addLines) {
            if ($line -match '(Column\s*\(|relationship\s*\(|__tablename__|primary_key|ForeignKey|Index\s*\(|CheckConstraint)') {
                $suspicious += "$mf :: $($line.Trim().Substring(1, [Math]::Min(80, $line.Trim().Length - 1)))"
                if ($suspicious.Count -ge 5) { break }
            }
        }
        if ($suspicious.Count -ge 5) { break }
    }

    if ($suspicious.Count -eq 0) { exit 0 }

    Write-PercusBlock -HookName 'migration-check' -Lines (@(
        "modelo(s) alterado(s) parece(m) schema change, mas nenhuma migration nova staged (R6)."
    ) + $suspicious + @(
        "Gere a migration: 'alembic revision --autogenerate -m <descricao>' e stage o arquivo gerado.",
        "Se delta nao precisa de migration (rename de variavel Python, docstring, etc), use:",
        "  `$env:PERCUS_SKIP_MIGRATION_CHECK=1 (declarar motivo em voz alta)."
    ))
    exit 2
} catch {
    Write-Host "[percus:hook migration-check] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
