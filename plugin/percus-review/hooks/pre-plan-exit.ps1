#requires -Version 5.1
# Hook pre-plan-exit Percus (R9 + Modo 3 do conselho).
# Intercepta ExitPlanMode e bloqueia se plano > 500 linhas sem pre-mortem rodado.
# Escape: $env:PERCUS_PREMORTEM_OVERRIDE=1 (logado).

. "$PSScriptRoot\_helpers.ps1"

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $toolName = $input.tool_name
    if ($toolName -ne "ExitPlanMode") { exit 0 }

    if ($env:PERCUS_HOOKS_DISABLED) { exit 0 }

    $plan = $input.tool_input.plan
    if (-not $plan) { exit 0 }

    $lines = ($plan -split "`n").Count
    if ($lines -le 500) { exit 0 }  # plano pequeno, libera

    # Plano grande. Verificar se pre-mortem foi rodado recente.
    $cwd = (Get-Location).Path
    $logDir = Join-Path $cwd ".deepseek\council-log"

    if ($env:PERCUS_PREMORTEM_OVERRIDE) {
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $overrideLog = Join-Path $logDir "pre-mortem-override.jsonl"
        @{
            timestamp  = (Get-Date -Format 'o')
            plan_lines = $lines
            cwd        = $cwd
            reason     = "PERCUS_PREMORTEM_OVERRIDE=1"
        } | ConvertTo-Json -Compress | Out-File -Append -FilePath $overrideLog -Encoding utf8
        exit 0
    }

    if (Test-Path $logDir) {
        $latest = Get-ChildItem $logDir -Filter "*-pre-mortem.jsonl" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) {
            $age = (Get-Date) - $latest.LastWriteTime
            if ($age.TotalMinutes -le 15) { exit 0 }  # pre-mortem recente, libera
        }
    }

    # Bloqueia
    Write-PercusBlock -HookName 'pre-plan-exit' -Lines @(
        "plano tem $lines linhas (>500) e nao tem pre-mortem recente em .deepseek/council-log/ (max 15min)."
    "Rode antes de ExitPlanMode:"
    "  /council:pre-mortem  (ou) pwsh scripts/council-orchestrator.ps1 -Mode pre-mortem -Providers deepseek,groq-llama,cross-claude"
    "Escape (com motivo declarado): `$env:PERCUS_PREMORTEM_OVERRIDE=1 (logado)."
    )
    exit 2
} catch {
    Write-Host "[percus:hook pre-plan-exit] WARN: hook crashed, allowing ExitPlanMode. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
