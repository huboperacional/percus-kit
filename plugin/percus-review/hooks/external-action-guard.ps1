#requires -Version 5.1
# Hook PreToolUse Percus (Layer 1 R20 enforcement).
# Bloqueia tools externos publicos quando council recente tem premise_validity != ok
# OU quando findings criticos nao tem fact_check: CONFIRMADO.
# Falha graceful: qualquer erro -> exit 0 (nao bloqueia injustamente).

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin -or $stdin.Trim() -eq '') { exit 0 }

    $inputObj = $stdin | ConvertFrom-Json -ErrorAction Stop
    $command = $inputObj.tool_input.command
    if (-not $command) { exit 0 }

    # Lista de comandos que sao "acao externa publica" (R20)
    $externalPatterns = @(
        'gh\s+(pr|issue)\s+comment',
        'gh\s+pr\s+(close|merge)',
        'gh\s+issue\s+close',
        'slack-cli',
        'git\s+push',
        'mailto:'
    )

    $isExternalAction = $false
    foreach ($p in $externalPatterns) {
        if ($command -match $p) { $isExternalAction = $true; break }
    }

    if (-not $isExternalAction) { exit 0 }

    # Escape hatch: operador autorizou explicitamente
    if ($env:PERCUS_EXTERNAL_OVERRIDE -eq "1") {
        [Console]::Error.WriteLine("[percus:hook external-action-guard] PERCUS_EXTERNAL_OVERRIDE setado — permitindo.")
        exit 0
    }

    # Verifica council recente (premise_validity)
    $cwd = (Get-Location).Path
    $councilDir = Join-Path $cwd ".deepseek/council-log"
    $councilBad = $false
    $councilBadReason = ""

    if (Test-Path $councilDir) {
        $latestCouncil = Get-ChildItem $councilDir -Filter "*.jsonl" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestCouncil -and ((Get-Date) - $latestCouncil.LastWriteTime).TotalMinutes -lt 60) {
            $councilContent = Get-Content $latestCouncil.FullName -Raw
            if ($councilContent -match '"premise_validity"\s*:\s*"(invalid|unverified)"') {
                $councilBad = $true
                $councilBadReason = "council log $($latestCouncil.Name) tem premise_validity=$($matches[1])"
            }
        }
    }

    # Fact-check (F3) ja roda no pipeline de review desde v6.7.0 (scripts/fact-check.ps1):
    # findings INFUNDADO sao filtrados antes do consolidador. Logo, qualquer finding que
    # chegue a uma acao externa ja passou por fact-check — nao ha check adicional aqui.

    if ($councilBad) {
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine("[percus:hook external-action-guard] BLOCK (R20):")
        [Console]::Error.WriteLine("  Comando: $command")
        [Console]::Error.WriteLine("  Razao: $councilBadReason")
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine("  R20 — Decisoes de conselho com premise_validity ruim NAO autorizam acao externa publica.")
        [Console]::Error.WriteLine("  Antes de prosseguir:")
        [Console]::Error.WriteLine("    1. Operador valida sintese do council explicitamente")
        [Console]::Error.WriteLine("    2. Findings passaram por fact-check")
        [Console]::Error.WriteLine("    3. OU setar PERCUS_EXTERNAL_OVERRIDE=1 com motivo declarado")
        [Console]::Error.WriteLine("")
        exit 2
    }

    # Default: bloqueia acao externa publica sem aprovacao explicita
    # (mesmo que council esteja OK — operador deve validar EXPLICITAMENTE cada acao publica)
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("[percus:hook external-action-guard] BLOCK (R20):")
    [Console]::Error.WriteLine("  Comando: $command")
    [Console]::Error.WriteLine("  Razao: acao externa publica requer aprovacao explicita do operador (R20)")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  Para autorizar: setar PERCUS_EXTERNAL_OVERRIDE=1 com motivo declarado no commit/log.")
    [Console]::Error.WriteLine("")
    exit 2
} catch {
    # Falha graceful — nao bloqueia injustamente
    [Console]::Error.WriteLine("[percus:hook external-action-guard] erro interno (skip): $($_.Exception.Message)")
    exit 0
}
