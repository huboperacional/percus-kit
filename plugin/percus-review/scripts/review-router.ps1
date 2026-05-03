#requires -Version 5.1
<#
.SYNOPSIS
  Router de review: decide entre DeepSeek, Cross-Claude, ou ambos (dual).

.DESCRIPTION
  Inspeciona arquivos tocados (cached + working tree, ou <base>..HEAD) e o
  trailer do último commit. Decide:
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

# === DETECT FILES TOCADOS ===
if ($Base) {
    $files = @(git diff --name-only "$Base...HEAD" 2>$null)
} else {
    $files = @(git diff --name-only --cached 2>$null) + @(git diff --name-only 2>$null) | Sort-Object -Unique
}
$files = $files | Where-Object { $_ -and $_.Trim() -ne "" }

# === SENSITIVE PATHS ===
$sensitivePatterns = @(
    '^.*[/\\]auth[/\\]',
    '^.*[/\\]payment.*[/\\]',
    '^.*[/\\]migrations[/\\]',
    '^.*[/\\]credentials[/\\]',
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
$lastCommitMsg = git log -1 --pretty=%B 2>$null
$fromDeepseek = $false
if ($lastCommitMsg) {
    $fromDeepseek = $lastCommitMsg -match '(?im)^Co-implemented-by:\s*deepseek'
}

# === DECIDE ===
$decision = if ($isSensitive) {
    "dual"
} elseif ($fromDeepseek) {
    "cross-claude"
} else {
    "deepseek"
}

if ($Json) {
    @{
        decision      = $decision
        sensitive     = $isSensitive
        from_deepseek = [bool]$fromDeepseek
        files_count   = $files.Count
    } | ConvertTo-Json -Compress
} else {
    Write-Host "[router] decisão: $decision (sensitive=$isSensitive, from_deepseek=$fromDeepseek, $($files.Count) arquivo(s))" -ForegroundColor Cyan
    Write-Output $decision
}
