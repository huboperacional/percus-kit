#requires -Version 5.1
<#
.SYNOPSIS
  Provider wrapper: Cross-Claude (Anthropic API direto, com prompt cache ephemeral).

.DESCRIPTION
  Substitui marker-based dispatch quando ANTHROPIC_API_KEY presente.
  Aplica cache_control:ephemeral no system block (TTL 5min Anthropic).
  Retorna JSON em stdout: {provider, model, status, content, latency_ms, usage}.
  Stderr: warnings/erros. Exit 0 = ok, 1 = network/auth fail, 2 = key ausente.

.PARAMETER PromptFile
  Path pra arquivo com prompt completo. Se omitido, le stdin.

.PARAMETER SystemPrompt
  Override do system prompt. Se omitido, carrega system-prompt-{Mode}.md do diretorio providers/.

.PARAMETER Temperature
  Default: 0.2.

.PARAMETER MaxTokens
  Default: 1024.

.PARAMETER Model
  Default: claude-sonnet-4-6 (orchestrator vai passar conforme router F.2).

.PARAMETER Endpoint
  Default: https://api.anthropic.com/v1/messages

.PARAMETER Mode
  Modo de operacao: consult | review | pre-mortem. Default: consult.
  Determina qual system-prompt-{Mode}.md carrega. pre-mortem faz fold pra consult.

.EXAMPLE
  Get-Content prompt.txt | .\cross-claude.ps1 > out.json
  .\cross-claude.ps1 -PromptFile prompt.txt -Model "claude-haiku-4-5"
  .\cross-claude.ps1 -PromptFile prompt.txt -Mode review
#>
[CmdletBinding()]
param(
    [string]$PromptFile,
    [string]$SystemPrompt,
    [double]$Temperature = 0.2,
    [int]$MaxTokens = 1024,
    [string]$Model = "claude-sonnet-4-6",
    [string]$Endpoint = "https://api.anthropic.com/v1/messages",
    [ValidateSet("consult","review","pre-mortem")]
    [string]$Mode = "consult"
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Load .env (best-effort)
if (-not $env:ANTHROPIC_API_KEY) {
    $envPath = Join-Path (Get-Location) '.env'
    if (Test-Path $envPath) {
        Get-Content $envPath | ForEach-Object {
            if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$' -and $_ -notmatch '^\s*#') {
                $name = $matches[1]; $val = $matches[2] -replace '^["'']|["'']$', ''
                if (-not (Get-Item -Path "env:$name" -ErrorAction SilentlyContinue)) {
                    Set-Item -Path "env:$name" -Value $val
                }
            }
        }
    }
}

if (-not $env:ANTHROPIC_API_KEY) {
    [Console]::Error.WriteLine("[cross-claude-provider] ANTHROPIC_API_KEY ausente no .env ou env vars.")
    exit 2
}

# Resolve SystemPrompt: -SystemPrompt explícito vence; senão carrega system-prompt-{Mode}.md;
# fallback: default inline curto (mantém retrocompat se arquivo faltar).
if (-not $PSBoundParameters.ContainsKey('SystemPrompt') -or -not $SystemPrompt) {
    $modeFile = if ($Mode -eq 'pre-mortem') { 'consult' } else { $Mode }
    $promptPath = Join-Path $PSScriptRoot "system-prompt-$modeFile.md"
    if (Test-Path $promptPath) {
        $raw = Get-Content $promptPath -Raw
        # Strip YAML frontmatter (---...---)
        $SystemPrompt = $raw -replace '^---\r?\n[\s\S]*?\r?\n---\r?\n', ''
    } else {
        $SystemPrompt = "Voce e consultor cross-provider Percus. Responda direto, sem floreio. Aponte riscos concretos."
    }
}

# Read prompt
if ($PromptFile) {
    if (-not (Test-Path $PromptFile)) {
        [Console]::Error.WriteLine("[cross-claude-provider] PromptFile nao encontrado: $PromptFile")
        exit 1
    }
    $userPrompt = Get-Content $PromptFile -Raw
} else {
    $userPrompt = [Console]::In.ReadToEnd()
}

if (-not $userPrompt -or $userPrompt.Trim().Length -eq 0) {
    [Console]::Error.WriteLine("[cross-claude-provider] prompt vazio.")
    exit 1
}

# IMPORTANTE: system deve ser array de blocks com cache_control — NAO string simples.
# Anthropic API rejeita cache_control se system for string.
$body = @{
    model      = $Model
    max_tokens = $MaxTokens
    temperature = $Temperature
    system     = @(
        @{
            type          = "text"
            text          = $SystemPrompt
            cache_control = @{ type = "ephemeral" }
        }
    )
    messages   = @(
        @{ role = "user"; content = $userPrompt }
    )
} | ConvertTo-Json -Depth 10 -Compress

$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$headers = @{
    "x-api-key"         = $env:ANTHROPIC_API_KEY
    "anthropic-version" = "2023-06-01"
    "content-type"      = "application/json"
}

$start = Get-Date
try {
    $resp = Invoke-RestMethod -Uri $Endpoint -Method Post -Headers $headers -Body $bodyBytes -TimeoutSec 60
    $content = $resp.content[0].text
    $latency = [int]((Get-Date) - $start).TotalMilliseconds

    @{
        provider   = "cross-claude"
        model      = $resp.model
        status     = "ok"
        content    = $content
        latency_ms = $latency
        usage      = @{
            prompt_tokens               = $resp.usage.input_tokens
            completion_tokens           = $resp.usage.output_tokens
            cache_creation_input_tokens = if ($resp.usage.PSObject.Properties['cache_creation_input_tokens']) { $resp.usage.cache_creation_input_tokens } else { 0 }
            cache_read_input_tokens     = if ($resp.usage.PSObject.Properties['cache_read_input_tokens']) { $resp.usage.cache_read_input_tokens } else { 0 }
        }
    } | ConvertTo-Json -Depth 10 -Compress
    exit 0
} catch {
    @{
        provider   = "cross-claude"
        model      = $Model
        status     = "error"
        error      = $_.Exception.Message
        latency_ms = [int]((Get-Date) - $start).TotalMilliseconds
    } | ConvertTo-Json -Depth 10 -Compress
    exit 1
}
