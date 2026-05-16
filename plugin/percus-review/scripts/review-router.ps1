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
    - "dual"         se tocar pasta sensível (auth/, payment*/, migrations/, credentials/, .env)
    - "cross-claude" se último commit tem trailer "Co-implemented-by: deepseek"
    - "deepseek"     caso contrário (default cross-provider)

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
$sensitivePatterns = @(
    '(^|[/\\])auth[/\\]',
    '(^|[/\\])payment[^/\\]*[/\\]',
    '(^|[/\\])migrations[/\\]',
    '(^|[/\\])credentials[/\\]',
    '^\.env'
)
$isSensitive = $false
foreach ($f in $files) {
    foreach ($p in $sensitivePatterns) {
        if ($f -match $p) { $isSensitive = $true; break }
    }
    if ($isSensitive) { break }
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
    @{
        decision        = $decision
        sensitive       = $isSensitive
        from_deepseek   = [bool]$fromDeepseek
        files_count     = $files.Count
        council_trigger = [bool]$councilTrigger
    } | ConvertTo-Json -Compress
} else {
    Write-Host "[router] decisão: $decision (sensitive=$isSensitive, from_deepseek=$fromDeepseek, council=$councilTrigger, $($files.Count) arquivo(s))" -ForegroundColor Cyan
    Write-Output $decision
}
