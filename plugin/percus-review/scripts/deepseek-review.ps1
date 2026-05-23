#requires -Version 5.1
<#
.SYNOPSIS
  Revisa git diff usando DeepSeek API (cross-provider review).

.DESCRIPTION
  Lê git diff (cached + working tree, ou --base para escopo). Combina com AGENTS.md.
  Chama DeepSeek API com prompt de revisor Percus. Output: findings estruturados.
  Loga em .deepseek/reviews/<timestamp>.jsonl.

  Requer: $env:DEEPSEEK_API_KEY (ou .env do projeto).

.EXAMPLE
  .\deepseek-review.ps1                        # diff cached + working tree
  .\deepseek-review.ps1 -Base main             # diff main..HEAD
#>
[CmdletBinding()]
param(
    [string]$Base = "",
    [string]$Model = "deepseek-chat",
    [double]$Temperature = 0.0,
    [string]$Endpoint = "https://api.deepseek.com/v1/chat/completions"
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

# === LOAD .env ===
if (-not $env:DEEPSEEK_API_KEY) {
    $envPath = Join-Path (Get-Location) '.env'
    if (Test-Path $envPath) {
        Get-Content $envPath | ForEach-Object {
            if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$' -and $_ -notmatch '^\s*#') {
                $name = $matches[1]
                $val = $matches[2] -replace '^["'']|["'']$', ''
                if (-not (Get-Item -Path "env:$name" -ErrorAction SilentlyContinue)) {
                    Set-Item -Path "env:$name" -Value $val
                }
            }
        }
    }
}
if (-not $env:DEEPSEEK_API_KEY) {
    throw "DEEPSEEK_API_KEY ausente. Configure no .env do projeto."
}

# === COLLECT DIFF ===
if ($Base) {
    $diff = (Invoke-GitSafe diff "$Base...HEAD") -join "`n"
} else {
    $cached = (Invoke-GitSafe diff --cached) -join "`n"
    $unstaged = (Invoke-GitSafe diff) -join "`n"
    $diff = "$cached`n$unstaged".Trim()
}
if (-not $diff) {
    Write-Host "[deepseek-review] Nada pra revisar (diff vazio)." -ForegroundColor Yellow
    exit 0
}

# === LOAD AGENTS.md ===
# Força leitura UTF-8 + fallback CP1252. Sem -Encoding explícito, PS 5.1 lê em
# ANSI do locale (Win11 PT-BR = CP1252), bytes acentuados viram chars inválidos
# pra UTF-8 no body JSON e DeepSeek API rejeita ("invalid unicode code point").
$agentsPath = Join-Path (Get-Location) 'AGENTS.md'
$agents = if (Test-Path $agentsPath) {
    try {
        Get-Content $agentsPath -Raw -Encoding UTF8 -ErrorAction Stop
    } catch {
        # Arquivo não-UTF-8: re-le como CP1252 e converte.
        $rawBytes = [System.IO.File]::ReadAllBytes($agentsPath)
        [System.Text.Encoding]::GetEncoding(1252).GetString($rawBytes)
    }
} else {
    "(AGENTS.md ausente — revise pelo bom senso de Percus)"
}

# === BUILD PROMPT ===
$systemPrompt = @"
Você é revisor cross-provider de código no padrão Percus.
Leia o git diff e o AGENTS.md (regras do projeto).
Para cada problema, emita finding no formato:

[SEV: bug | risco | preferência]
Arquivo: caminho/relativo:linha
Regra violada: R{N} (se aplicável)
Problema: descrição em 1-2 frases
Sugestão: ação concreta

Foque em: bugs, regressões, violações R1-R13, mock escondido (R3), JWT em localStorage (R7), pasta sensível tocada indevidamente, imports fora do stack canônico.
NÃO aponte estilo subjetivo sem regra concreta. NÃO sugira refactor fora do diff. Se nada relevante, responda "Sem findings críticos."
"@

$userMsg = "AGENTS.md do projeto:`n$agents`n`n---`n`nGit diff:`n$diff"

$body = @{
    model       = $Model
    temperature = $Temperature
    messages    = @(
        @{ role = "system"; content = $systemPrompt },
        @{ role = "user"; content = $userMsg }
    )
} | ConvertTo-Json -Depth 10 -Compress

# === CRITICAL: PS 5.1 UTF-8 BUG FIX ===
# PS 5.1 default encoding is UTF-16 LE. DeepSeek API expects UTF-8.
# Use [System.Text.Encoding]::UTF8.GetBytes() to force UTF-8 body.
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

$headers = @{
    "Authorization" = "Bearer $env:DEEPSEEK_API_KEY"
    "Content-Type"  = "application/json; charset=utf-8"
}

try {
    $response = Invoke-RestMethod -Uri $Endpoint -Method Post -Headers $headers -Body $bodyBytes
    $findings = $response.choices[0].message.content
} catch {
    Write-Host "[deepseek-review] ERRO: $_" -ForegroundColor Red
    exit 1
}

# === LOG ===
$logDir = Join-Path (Get-Location) '.deepseek\reviews'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "$(Get-Date -Format 'yyyyMMdd-HHmmss').jsonl"
@{
    timestamp  = (Get-Date -Format 'o')
    base       = $Base
    diff_lines = ($diff -split "`n").Count
    findings   = $findings
} | ConvertTo-Json -Compress | Out-File -FilePath $logFile -Encoding utf8

# === OUTPUT ===
Write-Host "## Findings DeepSeek (cross-provider review)`n" -ForegroundColor Cyan
Write-Output $findings
