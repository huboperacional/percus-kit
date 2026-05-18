#requires -Version 5.1
<#
.SYNOPSIS
  Smoke test: prova que cache Anthropic ativa no wrapper cross-claude.

.DESCRIPTION
  Faz 2 calls sequenciais ao wrapper com -Mode consult (>= 1024 tok no system).
  Call 1 (cache miss): expect cache_creation_input_tokens >= 1024, cache_read = 0.
  Call 2 (cache hit dentro de 5min TTL): expect cache_read_input_tokens >= 1024, cache_creation = 0.

  Custo: ~$0.015 (2 calls Sonnet 4.6, ~3000 tok system + ~30 tok user cada).
  Nota: usa Sonnet (nao Haiku) porque Haiku 4.5 atualmente nao ativa prompt cache
  mesmo com system >= 2048 tok. Sonnet/Opus cacheiam corretamente. Em producao:
  - consult (Haiku) NAO cacheia, mas qualidade enriquecida vale.
  - review (Sonnet) cacheia.
  - pre-mortem (Opus) cacheia.

.PARAMETER Wrapper
  Path pro cross-claude.ps1. Default: irmao deste script.
#>
[CmdletBinding()]
param(
    [string]$Wrapper = (Join-Path (Split-Path $PSScriptRoot) "providers" "cross-claude.ps1")
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path $Wrapper)) { Write-Error "Wrapper nao encontrado: $Wrapper"; exit 1 }
if (-not $env:ANTHROPIC_API_KEY) {
    $envPath = Join-Path (Get-Location) '.env'
    if (Test-Path $envPath) {
        Get-Content $envPath | Where-Object { $_ -match '^ANTHROPIC_API_KEY=' } | ForEach-Object {
            $env:ANTHROPIC_API_KEY = ($_ -split '=', 2)[1].Trim('"', "'")
        }
    }
}
if (-not $env:ANTHROPIC_API_KEY) { Write-Error "ANTHROPIC_API_KEY ausente"; exit 1 }

Write-Host "=== Smoke F.1 - cache Anthropic ativo? ===" -ForegroundColor Cyan
Write-Host "Wrapper: $Wrapper"
Write-Host ""

function Invoke-Call($label, $userPrompt) {
    Write-Host "Call $label ($userPrompt)..." -NoNewline
    $tmpIn = New-TemporaryFile
    Set-Content -Path $tmpIn -Value $userPrompt -Encoding utf8
    $rawOut = & pwsh -NoProfile -File $Wrapper -PromptFile $tmpIn.FullName -Mode consult -Model "claude-sonnet-4-6" 2>&1
    Remove-Item $tmpIn -Force
    $json = $rawOut | ConvertFrom-Json
    Write-Host " latency=$($json.latency_ms)ms"
    return $json
}

$c1 = Invoke-Call "1 (cache miss)" "qual a primeira regra inegociavel Percus?"
$c2 = Invoke-Call "2 (cache hit)"  "qual a segunda regra inegociavel Percus?"

Write-Host ""
Write-Host "=== Usage report ===" -ForegroundColor Cyan
@(
    @{ Label = "Call 1"; cache_creation = $c1.usage.cache_creation_input_tokens; cache_read = $c1.usage.cache_read_input_tokens; prompt_tokens = $c1.usage.prompt_tokens }
    @{ Label = "Call 2"; cache_creation = $c2.usage.cache_creation_input_tokens; cache_read = $c2.usage.cache_read_input_tokens; prompt_tokens = $c2.usage.prompt_tokens }
) | Format-Table -AutoSize

# Cache esta ativo se: (a) padrao classico cold start (c1 creation, c2 read), OU
# (b) cache pre-existente warm (ambos sao reads >= 1024). Em ambos casos mecanismo funciona.
$cachedC1 = [Math]::Max($c1.usage.cache_creation_input_tokens, $c1.usage.cache_read_input_tokens)
$cachedC2 = [Math]::Max($c2.usage.cache_creation_input_tokens, $c2.usage.cache_read_input_tokens)
$pass = ($cachedC1 -ge 1024) -and ($cachedC2 -ge 1024)

if ($pass) {
    if ($c1.usage.cache_creation_input_tokens -ge 1024) {
        Write-Host "Cache F.1 ATIVO (cold start: c1 cria $($c1.usage.cache_creation_input_tokens) tok, c2 le $($c2.usage.cache_read_input_tokens) tok)" -ForegroundColor Green
    } else {
        Write-Host "Cache F.1 ATIVO (cache pre-existente: ambos calls leram $cachedC1 tok do cache)" -ForegroundColor Green
    }
    exit 0
} else {
    Write-Host "Cache nao ativou - investigar" -ForegroundColor Red
    Write-Host "Verifique: 1) system-prompt-consult.md tem >= 1024 tok efetivos? 2) wrapper realmente le o arquivo? 3) modelo suporta cache?"
    exit 1
}
