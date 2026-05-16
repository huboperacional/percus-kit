#requires -Version 5.1
<#
.SYNOPSIS
  Provider wrapper: DeepSeek (deepseek-chat) — single-shot consult.

.DESCRIPTION
  Recebe prompt via -PromptFile (path) ou stdin. Chama DeepSeek API.
  Retorna JSON em stdout: {provider, status, content, latency_ms, model}.
  Stderr: warnings/erros. Exit 0 = ok, 1 = network/auth fail, 2 = key ausente.

.PARAMETER PromptFile
  Path pra arquivo com prompt completo (system+user mergeados). Se omitido, le stdin.

.PARAMETER SystemPrompt
  Override do system prompt. Default: "Voce e consultor cross-provider Percus..."

.PARAMETER Temperature
  Default: 0.2 (consult = pouco mais criativo que review=0.0).

.PARAMETER MaxTokens
  Default: 1024.

.EXAMPLE
  Get-Content prompt.txt | .\deepseek.ps1 > out.json
  .\deepseek.ps1 -PromptFile prompt.txt -Temperature 0.0
#>
[CmdletBinding()]
param(
    [string]$PromptFile,
    [string]$SystemPrompt = "Voce e consultor cross-provider Percus. Responda direto, sem floreio. Aponte riscos concretos.",
    [double]$Temperature = 0.2,
    [int]$MaxTokens = 1024,
    [string]$Model = "deepseek-chat",
    [string]$Endpoint = "https://api.deepseek.com/v1/chat/completions"
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Load .env (best-effort)
if (-not $env:DEEPSEEK_API_KEY) {
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

if (-not $env:DEEPSEEK_API_KEY) {
    [Console]::Error.WriteLine("[deepseek-provider] DEEPSEEK_API_KEY ausente no .env ou env vars.")
    exit 2
}

# Read prompt
if ($PromptFile) {
    if (-not (Test-Path $PromptFile)) {
        [Console]::Error.WriteLine("[deepseek-provider] PromptFile nao encontrado: $PromptFile")
        exit 1
    }
    $userPrompt = Get-Content $PromptFile -Raw
} else {
    $userPrompt = [Console]::In.ReadToEnd()
}

if (-not $userPrompt -or $userPrompt.Trim().Length -eq 0) {
    [Console]::Error.WriteLine("[deepseek-provider] prompt vazio.")
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
    "Authorization" = "Bearer $env:DEEPSEEK_API_KEY"
    "Content-Type"  = "application/json; charset=utf-8"
}

$start = Get-Date
try {
    $resp = Invoke-RestMethod -Uri $Endpoint -Method Post -Headers $headers -Body $bodyBytes -TimeoutSec 60
    $content = $resp.choices[0].message.content
    $latency = [int]((Get-Date) - $start).TotalMilliseconds

    @{
        provider   = "deepseek"
        model      = $Model
        status     = "ok"
        content    = $content
        latency_ms = $latency
        usage      = $resp.usage
    } | ConvertTo-Json -Depth 10 -Compress
    exit 0
} catch {
    @{
        provider   = "deepseek"
        model      = $Model
        status     = "error"
        error      = $_.Exception.Message
        latency_ms = [int]((Get-Date) - $start).TotalMilliseconds
    } | ConvertTo-Json -Depth 10 -Compress
    exit 1
}
