#requires -Version 5.1
<#
.SYNOPSIS
  Council orchestrator: roda DeepSeek + Llama em paralelo (PowerShell jobs), agrega resultados.

.DESCRIPTION
  Le prompt via -PromptFile (path) ou stdin. Dispara providers em paralelo.
  Para Cross-Claude (Sonnet subagent), emite marker `__PERCUS_NEEDS_CROSS_CLAUDE__`
  em stderr — agente principal deve dispatchear subagent e re-invocar com -CrossClaudeFile.

  Output: JSON em stdout com array de respostas + sintese sugerida (heuristic).
  Log: .deepseek/council-log/<timestamp>.jsonl

.PARAMETER PromptFile
  Path do arquivo com prompt user. Se omitido, le stdin.

.PARAMETER SystemPrompt
  System prompt comum a todos providers.

.PARAMETER Providers
  Comma-separated: "deepseek,groq-llama" (default) OU "deepseek,groq-llama,cross-claude".

.PARAMETER CrossClaudeFile
  Path pra arquivo com resposta do subagent Cross-Claude (pre-coletada pelo agente).
  Se passar, orquestrator inclui no agregado sem emitir marker.

.PARAMETER Mode
  "consult" (default), "pre-mortem", "review". Afeta system prompt sugerido.

.EXAMPLE
  echo "Devo renomear users.name?" | .\council-orchestrator.ps1
  .\council-orchestrator.ps1 -PromptFile q.txt -Providers "deepseek,groq-llama,cross-claude"
#>
[CmdletBinding()]
param(
    [string]$PromptFile,
    [string]$SystemPrompt,
    [string]$Providers = "deepseek,groq-llama",
    [string]$CrossClaudeFile,
    [ValidateSet("consult","pre-mortem","review")]
    [string]$Mode = "consult"
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$pluginRoot = Split-Path $PSScriptRoot -Parent  # .../percus-review/
$providersDir = Join-Path $pluginRoot "providers"

# Read prompt
if ($PromptFile) {
    if (-not (Test-Path $PromptFile)) {
        [Console]::Error.WriteLine("[council-orchestrator] PromptFile nao encontrado: $PromptFile")
        exit 1
    }
    $userPrompt = Get-Content $PromptFile -Raw
} else {
    $userPrompt = [Console]::In.ReadToEnd()
}
if (-not $userPrompt -or $userPrompt.Trim().Length -eq 0) {
    [Console]::Error.WriteLine("[council-orchestrator] prompt vazio.")
    exit 1
}

# Default system prompts per mode
if (-not $SystemPrompt) {
    $SystemPrompt = switch ($Mode) {
        "consult"    { "Voce e consultor cross-provider Percus. Responda em <=150 palavras: 1) sua escolha/posicao, 2) razao principal, 3) maior risco da alternativa. Sem floreio." }
        "pre-mortem" { "Voce e consultor de pre-mortem Percus. Leia o plano e responda: SE este plano falhar em 30 dias, por que? Liste exatamente 3 motivos concretos em ordem de probabilidade decrescente, com 1 frase cada." }
        "review"     { "Voce e revisor cross-provider Percus (R11). Aponte bugs, regressoes, violacoes R1-R19, mocks escondidos, JWT em localStorage, imports vetados. Se nada relevante: 'Sem findings criticos'." }
    }
}

# Parse providers list
$wanted = $Providers.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }

# Separate cross-claude (handled differently)
$asyncProviders = $wanted | Where-Object { $_ -ne "cross-claude" }
$wantsCrossClaude = $wanted -contains "cross-claude"

# Write prompt to temp file for jobs to read
$tmpPrompt = [System.IO.Path]::GetTempFileName()
$userPrompt | Out-File -FilePath $tmpPrompt -Encoding utf8 -NoNewline

# Dispatch async providers as PS jobs
$jobs = @{}
$start = Get-Date
foreach ($p in $asyncProviders) {
    $wrapperPath = Join-Path $providersDir "$p.ps1"
    if (-not (Test-Path $wrapperPath)) {
        [Console]::Error.WriteLine("[council-orchestrator] WARN: provider '$p' nao tem wrapper em $wrapperPath, pulando.")
        continue
    }
    # PS jobs nao herdam env vars do parent; capturar e re-set dentro do job.
    $envSnapshot = @{
        DEEPSEEK_API_KEY = $env:DEEPSEEK_API_KEY
        GROQ_API_KEY     = $env:GROQ_API_KEY
    }
    $jobs[$p] = Start-Job -ScriptBlock {
        param($Wrapper, $PromptF, $SysPrompt, $EnvVars)
        foreach ($kv in $EnvVars.GetEnumerator()) {
            if ($kv.Value) { Set-Item -Path "env:$($kv.Key)" -Value $kv.Value }
        }
        # Capture only stdout from wrapper; stderr (warnings) goes to job's stderr stream
        & $Wrapper -PromptFile $PromptF -SystemPrompt $SysPrompt
    } -ArgumentList $wrapperPath, $tmpPrompt, $SystemPrompt, $envSnapshot
}

# Collect cross-claude (already provided OR marker)
$crossClaude = $null
if ($wantsCrossClaude) {
    if ($CrossClaudeFile -and (Test-Path $CrossClaudeFile)) {
        $crossClaude = @{
            provider   = "cross-claude"
            model      = "claude-sonnet-4-6"
            status     = "ok"
            content    = (Get-Content $CrossClaudeFile -Raw)
            latency_ms = 0
        }
    } else {
        # Emit marker pro agente
        [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__")
        [Console]::Error.WriteLine("[council-orchestrator] dispatch Sonnet subagent com prompt:")
        [Console]::Error.WriteLine("---PROMPT---")
        [Console]::Error.WriteLine("$SystemPrompt`n`n$userPrompt")
        [Console]::Error.WriteLine("---END-PROMPT---")
        [Console]::Error.WriteLine("Salve resposta em arquivo e re-invoque orchestrator com -CrossClaudeFile <path>.")
    }
}

# Wait for jobs
$responses = @()
foreach ($name in $jobs.Keys) {
    $job = $jobs[$name]
    $jobOutput = Wait-Job -Job $job | Receive-Job
    # jobOutput pode ser JSON string OR error obj
    $jsonStr = ($jobOutput | Out-String).Trim()
    Remove-Job -Job $job -Force
    try {
        $obj = $jsonStr | ConvertFrom-Json
        $responses += $obj
    } catch {
        $responses += @{
            provider   = $name
            status     = "error"
            error      = "Failed to parse provider output: $jsonStr"
            latency_ms = 0
        }
    }
}
if ($crossClaude) { $responses += $crossClaude }

Remove-Item $tmpPrompt -Force -ErrorAction SilentlyContinue

$totalLatency = [int]((Get-Date) - $start).TotalMilliseconds

# Log to .deepseek/council-log/
$logDir = Join-Path (Get-Location) ".deepseek\council-log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$Mode.jsonl"

$result = @{
    mode             = $Mode
    timestamp        = (Get-Date -Format 'o')
    prompt           = $userPrompt
    system_prompt    = $SystemPrompt
    providers_called = $wanted
    responses        = $responses
    total_latency_ms = $totalLatency
    cross_claude_pending = ($wantsCrossClaude -and (-not $crossClaude))
}

$result | ConvertTo-Json -Depth 10 | Out-File -FilePath $logFile -Encoding utf8

# Output to stdout
$result | ConvertTo-Json -Depth 10
exit 0
