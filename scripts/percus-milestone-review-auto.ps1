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
  Exit codes: 0 = success (inclui deepseek-review falho -- placeholder deferred gravado,
  ver marker __PERCUS_NEEDS_CROSS_CLAUDE__ no stderr), 1 = plugin não encontrado
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
    # Mesmo fix do caso "dual" de percus-review-auto.ps1: DeepSeek fora do ar (outage/API
    # key invalida) nao pode deixar o marco INTEIRO sem registro e sem marker -- marco e
    # SEMPRE dual, entao este `exit 3` bloqueava 100% dos fechamentos de marco ate a
    # chave ser restaurada, sem chance de Cross-Claude cobrir sozinho. Grava placeholder
    # deferred em .deepseek/reviews/latest.jsonl ANTES do marker/sair, mesmo padrao do
    # caso "cross-claude" de percus-review-auto.
    [Console]::Error.WriteLine("[percus-milestone-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE) -- registrando placeholder deferred pra nao travar o gate.")
    $reviewDir = ".deepseek\reviews"
    New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null
    $logFile = Join-Path $reviewDir 'latest.jsonl'
    $logTmp  = Join-Path $reviewDir 'latest.jsonl.tmp'
    @{
        deferred    = $true
        reason      = "decision=milestone-dual (base=$Base), DeepSeek falhou (exit $LASTEXITCODE) -- provavel outage/API key invalida. Registro parcial; Cross-Claude ainda precisa rodar (R11)."
        decision    = "milestone-dual"
        timestamp   = (Get-Date -Format 'o')
        placeholder = $true
        note        = "Agente DEVE dispatchar Sonnet subagent agora com prompt de milestone-review; substituir este placeholder pelas findings reais quando possivel."
    } | ConvertTo-Json -Compress | Set-Content -Path $logTmp -Encoding UTF8
    Move-Item -Path $logTmp -Destination $logFile -Force
    [Console]::Error.WriteLine("[percus-milestone-auto] placeholder escrito em $logFile (libera hook por TTL)")
    [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: marco fechado (dual obrigatorio, DeepSeek indisponivel). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de milestone-review (escopo: $Base..HEAD).")
    exit 0
}

[Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: marco fechado (dual obrigatorio). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de milestone-review (escopo: $Base..HEAD).")

exit 0
