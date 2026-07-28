#requires -Version 5.1
<#
.SYNOPSIS
  Router de review: decide entre DeepSeek, Cross-Claude, ou ambos (dual).

.DESCRIPTION
  Inspeciona arquivos tocados (cached + working tree, ou <base>..HEAD) e o
  trailer do último commit. Decide (ordem de precedência):
    - "council"      se tocar pasta sensível E (commit veio DeepSeek OU >10 arquivos tocados).
                     Aciona conselho 3-membros via council-orchestrator (DS + Llama + CC).
                     Fase 6 v6.1.0+.
    - "dual"         se tocar pasta sensível
    - "cross-claude" se último commit tem trailer "Co-implemented-by: deepseek"
    - "deepseek"     caso contrário (default cross-provider)

  O que é "pasta sensível" vem de DOIS lugares somados (v6.31.0+):
    1. scripts/sensitive-paths.txt — baseline global, MESMO arquivo lido pelo .sh e pelos testes.
    2. .percus-review.json na raiz do repo revisado — convenção daquele projeto:
         { "sensitivePatterns": ["(^|[/\\\\])execution[/\\\\].*\\.py$"] }

  FALHA FECHADA: baseline ausente/vazio, JSON inválido ou regex que não compila
  NÃO rebaixam a decisão — marcam sensitive=true e emitem aviso em "warnings".
  Rebaixar em silêncio é o bug que esta versão corrige.

.EXAMPLE
  .\review-router.ps1                  # texto humano
  .\review-router.ps1 -Json            # decisão como JSON
  .\review-router.ps1 -Base main -Json
#>
[CmdletBinding()]
param(
    [string]$Base = "",
    [switch]$Json
)
$ErrorActionPreference = "Stop"

# Force UTF-8 console (Windows PS 5.1 default is Win-1252, mangles PT-BR)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Helper: roda git sem deixar stderr virar NativeCommandError em PS 5.1
function Invoke-GitSafe {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git @Arguments 2>$null
        return $output
    } finally {
        $ErrorActionPreference = $prev
    }
}

# === DETECT FILES TOCADOS ===
if ($Base) {
    $files = @(Invoke-GitSafe diff --name-only "$Base...HEAD")
} else {
    $files = @(Invoke-GitSafe diff --name-only --cached) + @(Invoke-GitSafe diff --name-only) | Sort-Object -Unique
}
$files = $files | Where-Object { $_ -and $_.Trim() -ne "" }

# === SENSITIVE PATHS ===
# Baseline global + extensão do projeto. Nada de lista hardcoded aqui: a lista
# duplicada em .ps1/.sh foi a causa raiz do incidente 2026-07-27.
$warnings = New-Object System.Collections.ArrayList
$failClosed = $false      # erro de config nunca rebaixa a decisão
$rawPatterns = New-Object System.Collections.ArrayList

# 1. Baseline global (fonte única compartilhada com review-router.sh e os testes)
$baselineFile = Join-Path $PSScriptRoot "sensitive-paths.txt"
if (Test-Path $baselineFile) {
    Get-Content $baselineFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -ne "" -and -not $line.StartsWith("#")) { [void]$rawPatterns.Add($line) }
    }
}
if ($rawPatterns.Count -eq 0) {
    [void]$warnings.Add("baseline sensitive-paths.txt ausente ou vazio em '$baselineFile' — assumindo sensitive=true (falha fechada)")
    $failClosed = $true
}

# 2. Extensão declarada pelo projeto revisado (.percus-review.json na raiz do repo)
$repoRoot = @(Invoke-GitSafe rev-parse --show-toplevel) | Where-Object { $_ } | Select-Object -First 1
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$cfgPath = Join-Path $repoRoot ".percus-review.json"
if (Test-Path $cfgPath) {
    try {
        $cfg = Get-Content $cfgPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $projPatterns = @($cfg.sensitivePatterns) | Where-Object { $_ -is [string] -and $_.Trim() -ne "" }
        if ($projPatterns.Count -eq 0) {
            [void]$warnings.Add(".percus-review.json existe mas não declara sensitivePatterns utilizáveis — só o baseline vale")
        }
        # Teto anti-abuso: config vem de repo, não confia cegamente.
        if ($projPatterns.Count -gt 100) {
            [void]$warnings.Add(".percus-review.json declara $($projPatterns.Count) padrões — usando os 100 primeiros")
            $projPatterns = $projPatterns[0..99]
        }
        foreach ($p in $projPatterns) {
            if ($p.Length -gt 200) {
                [void]$warnings.Add("padrão do projeto ignorado (>200 chars): $($p.Substring(0,60))…")
                $failClosed = $true
            } else {
                [void]$rawPatterns.Add($p)
            }
        }
    } catch {
        [void]$warnings.Add(".percus-review.json ilegível/inválido ($($_.Exception.Message)) — assumindo sensitive=true (falha fechada)")
        $failClosed = $true
    }
}

# 3. Compila. Regex que não compila = caminho que o projeto quis proteger e ficou fora → falha fechada.
$compiled = New-Object System.Collections.ArrayList
foreach ($p in $rawPatterns) {
    try {
        [void]$compiled.Add([regex]::new($p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase, [TimeSpan]::FromSeconds(2)))
    } catch {
        [void]$warnings.Add("padrão inválido ignorado: '$p' ($($_.Exception.Message))")
        $failClosed = $true
    }
}

$isSensitive = $failClosed
if (-not $isSensitive) {
    foreach ($f in $files) {
        foreach ($re in $compiled) {
            try {
                if ($re.IsMatch($f)) { $isSensitive = $true; break }
            } catch [System.Text.RegularExpressions.RegexMatchTimeoutException] {
                [void]$warnings.Add("timeout avaliando '$($re.ToString())' contra '$f' — assumindo sensitive=true")
                $isSensitive = $true; break
            }
        }
        if ($isSensitive) { break }
    }
}

# === CHECK COMMIT TRAILER (último commit) ===
$lastCommitMsg = Invoke-GitSafe log -1 --pretty=%B
$fromDeepseek = $false
if ($lastCommitMsg) {
    $fromDeepseek = $lastCommitMsg -match '(?im)^Co-implemented-by:\s*deepseek'
}

# === DECIDE ===
# Council (3 providers) quando: pasta sensivel + (commit do DeepSeek OU mudanca grande)
# Sinaliza "merece 3 perspectivas paralelas".
$councilTrigger = $isSensitive -and ($fromDeepseek -or $files.Count -gt 10)
$decision = if ($councilTrigger) {
    "council"
} elseif ($isSensitive) {
    "dual"
} elseif ($fromDeepseek) {
    "cross-claude"
} else {
    "deepseek"
}

if ($Json) {
    # 'warnings' sai no JSON (e não só no stderr) porque o wrapper chama o router
    # com 2>$null: aviso que só existe em stderr é aviso que ninguém lê.
    @{
        decision        = $decision
        sensitive       = $isSensitive
        from_deepseek   = [bool]$fromDeepseek
        files_count     = $files.Count
        council_trigger = [bool]$councilTrigger
        warnings        = [string[]]$warnings.ToArray()
    } | ConvertTo-Json -Compress
} else {
    foreach ($w in $warnings) { [Console]::Error.WriteLine("[router] AVISO: $w") }
    Write-Host "[router] decisão: $decision (sensitive=$isSensitive, from_deepseek=$fromDeepseek, council=$councilTrigger, $($files.Count) arquivo(s))" -ForegroundColor Cyan
    Write-Output $decision
}
