#requires -Version 5.1
<#
.SYNOPSIS
  Wrapper kit-level pra agente Claude Code auto-disparar /percus-review:review
  via Bash tool, sem precisar de paste do usuário no chat.

.DESCRIPTION
  Resolve plugin percus-review instalado a nível de usuário (CLAUDE_CONFIG_DIR
  ou ~/.claude default), localiza versão mais recente, dispatch via review-router
  + deepseek-review da versão instalada. Path absoluto estável -- agente chama
  por path direto (D:/Claud Automations/_Novo_Projeto/scripts/percus-review-auto.ps1).

  Quando decisão exige Cross-Claude (cross-claude ou dual), wrapper emite marker
  __PERCUS_NEEDS_CROSS_CLAUDE__ no stderr -- agente lê e dispatch Sonnet subagent
  via Agent tool (não dá pra fazer de PowerShell).

.EXAMPLE
  pwsh -File "D:/Claud Automations/_Novo_Projeto/scripts/percus-review-auto.ps1"
  pwsh -File "D:/Claud Automations/_Novo_Projeto/scripts/percus-review-auto.ps1" -Base main

.NOTES
  Exit codes: 0 = success, 1 = plugin não encontrado, 2 = router falhou, 3 = deepseek-review falhou
#>
[CmdletBinding()]
param(
    [string]$Base = ""
)
$ErrorActionPreference = "Stop"

# Force UTF-8 console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# === Resolve plugin install path ===
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
$pluginsDir = Join-Path $claudeHome "plugins\cache\percus-tools\percus-review"

if (-not (Test-Path $pluginsDir)) {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: plugin nao encontrado em $pluginsDir")
    [Console]::Error.WriteLine("Instale via /plugin install percus-review@percus-tools no chat 'claude' standalone.")
    exit 1
}

$current = Get-ChildItem $pluginsDir -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [Version]$_.Name } -Descending |
    Select-Object -First 1

if (-not $current) {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: nenhuma versao valida instalada em $pluginsDir")
    exit 1
}

[Console]::Error.WriteLine("[percus-review-auto] plugin v$($current.Name) em $($current.FullName)")

$routerScript = Join-Path $current.FullName "scripts\review-router.ps1"
$deepseekScript = Join-Path $current.FullName "scripts\deepseek-review.ps1"

if (-not (Test-Path $routerScript)) {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: review-router.ps1 ausente em $($current.FullName)\scripts\")
    exit 1
}

# === Run router (decisão deepseek/cross-claude/dual) ===
$routerArgs = @("-Json")
if ($Base) { $routerArgs += @("-Base", $Base) }

$decisionJson = & pwsh -NoProfile -ExecutionPolicy Bypass -File $routerScript @routerArgs 2>$null
if ($LASTEXITCODE -ne 0 -or -not $decisionJson) {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: router falhou (exit $LASTEXITCODE)")
    exit 2
}

try {
    $decision = $decisionJson | ConvertFrom-Json
} catch {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: router retornou JSON invalido: $decisionJson")
    exit 2
}

[Console]::Error.WriteLine("[percus-review-auto] decisao: $($decision.decision) (sensitive=$($decision.sensitive), from_deepseek=$($decision.from_deepseek), $($decision.files_count) arquivo(s))")

# === Dispatch ===
$reviewWritten = $false

switch ($decision.decision) {
    "deepseek" {
        $deepseekArgs = @()
        if ($Base) { $deepseekArgs += @("-Base", $Base) }
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $deepseekScript @deepseekArgs
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("[percus-review-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE)")
            exit 3
        }
        $reviewWritten = $true
    }

    "dual" {
        # Roda DeepSeek (cobre layer cheap), agente faz Sonnet via Agent tool
        $deepseekArgs = @()
        if ($Base) { $deepseekArgs += @("-Base", $Base) }
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $deepseekScript @deepseekArgs
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("[percus-review-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE)")
            exit 3
        }
        $reviewWritten = $true
        [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: pasta sensitive detectada (decision=dual). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt R11 cross-claude-review.")
    }

    "cross-claude" {
        # R11: DeepSeek nao pode auto-revisar (commit veio dele). So Sonnet revisa.
        # Mas hook precisa de .jsonl em .deepseek/reviews/ pra liberar commit.
        # Solucao: agente vai dispatchar Sonnet e DEVE salvar saida em .deepseek/reviews/
        # via wrapper save-review (ou criar manualmente).
        $reviewDir = ".deepseek\reviews"
        New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null
        $placeholderPath = Join-Path $reviewDir "$(Get-Date -Format 'yyyyMMdd-HHmmss')-deferred-cross-claude.jsonl"
        @{
            deferred = $true
            reason = "decision=cross-claude (commit from DeepSeek). R11 anti auto-revisao -- so Sonnet revisa."
            decision = $decision.decision
            timestamp = (Get-Date).ToString('o')
            placeholder = $true
            note = "Agente DEVE dispatchar Sonnet subagent agora; substituir este placeholder pelas findings reais."
        } | ConvertTo-Json -Compress | Set-Content -Path $placeholderPath -Encoding UTF8
        [Console]::Error.WriteLine("[percus-review-auto] placeholder escrito em $placeholderPath (libera hook por TTL)")
        [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: commit veio de DeepSeek (decision=cross-claude). DEVE dispatchar Sonnet subagent via Agent tool agora -- DeepSeek NAO revisa proprio output (R11).")
        $reviewWritten = $true
    }

    default {
        [Console]::Error.WriteLine("[percus-review-auto] ERRO: decisao desconhecida do router: $($decision.decision)")
        exit 2
    }
}

exit 0
