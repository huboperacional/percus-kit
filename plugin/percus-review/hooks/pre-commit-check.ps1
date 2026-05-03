#requires -Version 5.1
# Hook pre-commit Percus — bloqueia commit sem /percus:review recente.
# Falha graceful: qualquer erro -> exit 0.

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $command = $input.tool_input.command

    # Não-commit -> libera
    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }

    # Amend sem edit (rebase) -> libera
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }

    # Escape pro user (motivo declarado em voz alta)
    if ($env:PERCUS_HOOKS_DISABLED) { exit 0 }

    # Procurar review recente
    $cwd = (Get-Location).Path
    $reviewDir = Join-Path $cwd ".deepseek/reviews"
    if (-not (Test-Path $reviewDir)) {
        Write-Host "[percus:hook pre-commit] BLOCK: nenhum /percus:review encontrado em .deepseek/reviews/" -ForegroundColor Red
        Write-Host "Rode /percus:review antes de commitar (R11)." -ForegroundColor Yellow
        exit 2
    }

    $latest = Get-ChildItem $reviewDir -Filter "*.jsonl" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Host "[percus:hook pre-commit] BLOCK: pasta .deepseek/reviews/ vazia" -ForegroundColor Red
        Write-Host "Rode /percus:review antes de commitar (R11)." -ForegroundColor Yellow
        exit 2
    }

    $age = (Get-Date) - $latest.LastWriteTime
    if ($age.TotalMinutes -gt 5) {
        $mins = [math]::Round($age.TotalMinutes, 1)
        Write-Host "[percus:hook pre-commit] BLOCK: ultimo /percus:review tem $mins min (max 5)." -ForegroundColor Red
        Write-Host "Rode /percus:review de novo antes de commitar (R11)." -ForegroundColor Yellow
        exit 2
    }

    # Review fresco -> libera
    exit 0
} catch {
    # Falha do hook nao bloqueia workflow
    Write-Host "[percus:hook pre-commit] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
