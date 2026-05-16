#requires -Version 5.1
<#
.SYNOPSIS
  Provider wrapper: Llama 3.3 70B via Groq — single-shot consult.

.DESCRIPTION
  Mesma interface de providers/deepseek.ps1. Free tier 30 req/min.
  Retorna JSON em stdout: {provider, status, content, latency_ms, model}.
#>
[CmdletBinding()]
param(
    [string]$PromptFile,
    [string]$SystemPrompt = "Voce e consultor cross-provider Percus. Responda direto, sem floreio. Aponte riscos concretos.",
    [double]$Temperature = 0.2,
    [int]$MaxTokens = 1024,
    [string]$Model = "llama-3.3-70b-versatile",
    [string]$Endpoint = "https://api.groq.com/openai/v1/chat/completions"
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $env:GROQ_API_KEY) {
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

if (-not $env:GROQ_API_KEY) {
    [Console]::Error.WriteLine("[groq-llama-provider] GROQ_API_KEY ausente. Obter free em https://console.groq.com.")
    exit 2
}

if ($PromptFile) {
    if (-not (Test-Path $PromptFile)) { [Console]::Error.WriteLine("[groq-llama-provider] PromptFile nao encontrado: $PromptFile"); exit 1 }
    $userPrompt = Get-Content $PromptFile -Raw
} else {
    $userPrompt = [Console]::In.ReadToEnd()
}

if (-not $userPrompt -or $userPrompt.Trim().Length -eq 0) {
    [Console]::Error.WriteLine("[groq-llama-provider] prompt vazio.")
    exit 1
}

$body = @{
    model       = $Model
    temperature = $Temperature
    max_tokens  = $MaxTokens
    messages    = @(
        @{ role = "system"; content = $SystemPrompt },
        @{ role = "user";   content = $userPrompt }
    )
} | ConvertTo-Json -Depth 10 -Compress

$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$headers = @{
    "Authorization" = "Bearer $env:GROQ_API_KEY"
    "Content-Type"  = "application/json; charset=utf-8"
}

$start = Get-Date
try {
    $resp = Invoke-RestMethod -Uri $Endpoint -Method Post -Headers $headers -Body $bodyBytes -TimeoutSec 60
    $content = $resp.choices[0].message.content
    $latency = [int]((Get-Date) - $start).TotalMilliseconds

    @{
        provider   = "groq-llama"
        model      = $Model
        status     = "ok"
        content    = $content
        latency_ms = $latency
        usage      = $resp.usage
    } | ConvertTo-Json -Depth 10 -Compress
    exit 0
} catch {
    @{
        provider   = "groq-llama"
        model      = $Model
        status     = "error"
        error      = $_.Exception.Message
        latency_ms = [int]((Get-Date) - $start).TotalMilliseconds
    } | ConvertTo-Json -Depth 10 -Compress
    exit 1
}
