#requires -Version 5.1
<#
.SYNOPSIS
  Wrapper kit-level pra agente Claude Code auto-disparar
  /percus-review:milestone-review via Bash tool.

.DESCRIPTION
  Marco usa SEMPRE dual (DeepSeek + Cross-Claude). Wrapper roda DeepSeek e
  emite marker pra agente dispatchar Sonnet subagent. Path absoluto estável.

  Diferença vs review-auto: marco ignora a decisão do router e força dual.

.EXAMPLE
  pwsh -File ".../percus-milestone-review-auto.ps1" -Base <commit-inicio-marco>

.NOTES
  Exit codes: 0 = success, 1 = plugin não encontrado, 3 = deepseek-review falhou
  Base é OBRIGATÓRIO em milestone-review (escopo do marco).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Base
)
$ErrorActionPreference = "Stop"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# === Resolve PowerShell host (pwsh preferred, fallback to powershell.exe) ===
# See percus-review-auto.ps1 for rationale.
$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

# === Resolve plugin ===
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
$pluginsDir = Join-Path $claudeHome "plugins\cache\percus-tools\percus-review"

if (-not (Test-Path $pluginsDir)) {
    [Console]::Error.WriteLine("[percus-milestone-auto] ERRO: plugin nao encontrado em $pluginsDir")
    exit 1
}

$current = Get-ChildItem $pluginsDir -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [Version]$_.Name } -Descending |
    Select-Object -First 1

if (-not $current) {
    [Console]::Error.WriteLine("[percus-milestone-auto] ERRO: nenhuma versao instalada")
    exit 1
}

[Console]::Error.WriteLine("[percus-milestone-auto] plugin v$($current.Name)")

$deepseekScript = Join-Path $current.FullName "scripts\deepseek-review.ps1"

# === Marco e SEMPRE dual: DeepSeek + Sonnet (agente faz Sonnet via Agent tool) ===
[Console]::Error.WriteLine("[percus-milestone-auto] base=$Base, escopo do marco")
& $PsExe -NoProfile -ExecutionPolicy Bypass -File $deepseekScript -Base $Base
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("[percus-milestone-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE)")
    exit 3
}

[Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: marco fechado (dual obrigatorio). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de milestone-review (escopo: $Base..HEAD).")

exit 0
