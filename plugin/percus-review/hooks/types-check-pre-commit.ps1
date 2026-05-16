#requires -Version 5.1
# Hook pre-commit Percus types-check (R5).
# Roda mypy --strict em arquivos .py staged + tsc --noEmit em arquivos .ts/.tsx staged.
# Best-effort: se mypy ou tsc nao disponiveis no projeto, skip silencioso.
# Skip: $env:PERCUS_SKIP_TYPES_CHECK=1.

. "$PSScriptRoot\_helpers.ps1"

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $command = $input.tool_input.command

    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }
    if ($env:PERCUS_HOOKS_DISABLED -or $env:PERCUS_SKIP_TYPES_CHECK) { exit 0 }

    $projectRoot = Resolve-PercusProjectRoot -Command $command
    if (-not (Test-Path (Join-Path $projectRoot ".git"))) { exit 0 }

    $pyFiles = Get-PercusStagedFiles -ProjectRoot $projectRoot -Extensions @('.py')
    $tsFiles = Get-PercusStagedFiles -ProjectRoot $projectRoot -Extensions @('.ts','.tsx')

    $errors = @()

    # ── mypy --strict ────────────────────────────────────────────────────
    if ($pyFiles -and $pyFiles.Count -gt 0) {
        # mypy disponivel? Tenta resolver no PATH OU em .venv do projeto.
        $mypyCmd = $null
        $venvMypy = Join-Path $projectRoot ".venv\Scripts\mypy.exe"
        if (Test-Path $venvMypy) { $mypyCmd = $venvMypy }
        elseif (Get-Command mypy -ErrorAction SilentlyContinue) { $mypyCmd = "mypy" }

        if ($mypyCmd) {
            # Filtra arquivos que existem em disco (staged pode incluir deletados? --diff-filter=ACMR ja exclui)
            $pyExisting = @($pyFiles | Where-Object { Test-Path (Join-Path $projectRoot $_) })
            if ($pyExisting.Count -gt 0) {
                Push-Location $projectRoot
                try {
                    $mypyOut = & $mypyCmd --strict --no-error-summary --show-error-codes @pyExisting 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        $errLines = @($mypyOut | Where-Object { $_ -match ': error:' } | Select-Object -First 10)
                        foreach ($l in $errLines) { $errors += "mypy :: $l" }
                    }
                } finally { Pop-Location }
            }
        }
    }

    # ── tsc --noEmit ─────────────────────────────────────────────────────
    if (($tsFiles -and $tsFiles.Count -gt 0) -and ($errors.Count -lt 10)) {
        # tsc disponivel? Local em node_modules/.bin OU global.
        $tscCmd = $null
        $localTsc = Join-Path $projectRoot "node_modules\.bin\tsc.cmd"
        if (Test-Path $localTsc) { $tscCmd = $localTsc }
        elseif (Get-Command tsc -ErrorAction SilentlyContinue) { $tscCmd = "tsc" }

        # Roda apenas se ha tsconfig.json
        $tsconfig = Join-Path $projectRoot "tsconfig.json"
        if ($tscCmd -and (Test-Path $tsconfig)) {
            Push-Location $projectRoot
            try {
                # tsc nao aceita lista de arquivos quando tsconfig esta presente — roda no projeto inteiro
                $tscOut = & $tscCmd --noEmit --pretty false 2>&1
                if ($LASTEXITCODE -ne 0) {
                    # Filtra erros que afetam arquivos staged
                    $stagedSet = @{}
                    foreach ($f in $tsFiles) { $stagedSet[$f.Replace('\','/')] = $true }
                    $errLines = @($tscOut | Where-Object { $_ -match 'error TS\d+:' } | Where-Object {
                        $line = $_
                        $matched = $false
                        foreach ($s in $stagedSet.Keys) {
                            if ($line -match [regex]::Escape($s)) { $matched = $true; break }
                        }
                        $matched
                    } | Select-Object -First 10)
                    foreach ($l in $errLines) { $errors += "tsc :: $l" }
                }
            } finally { Pop-Location }
        }
    }

    if ($errors.Count -eq 0) { exit 0 }

    Write-PercusBlock -HookName 'types-check' -Lines (@(
        "$($errors.Count) erro(s) de tipo em arquivos staged (R5 — tipos explicitos, mypy --strict / tsc --noEmit)."
    ) + $errors + @(
        "Corrija os tipos OU use:",
        "  `$env:PERCUS_SKIP_TYPES_CHECK=1 (declarar motivo em voz alta)."
    ))
    exit 2
} catch {
    Write-Host "[percus:hook types-check] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
