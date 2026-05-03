#requires -Version 5.1
<#
.SYNOPSIS
  Worker DeepSeek (V4/V3.1) para implementacao mecanica delegada pelo Claude.

.DESCRIPTION
  Le um plano (texto + arquivos de contexto) e chama a API DeepSeek para gerar codigo.
  Saida em modo --dry-run mostra o resultado; modo --apply escreve arquivos.
  Loga toda execucao em .deepseek/runs/<timestamp>.jsonl para auditoria.

  Requer: $env:DEEPSEEK_API_KEY

.EXAMPLE
  .\deepseek-impl.ps1 -Task .\plano-feature.md -Files src\foo.ts,src\bar.ts -DryRun

.EXAMPLE
  .\deepseek-impl.ps1 -Task .\plano-feature.md -Files src\foo.ts -Apply
#>

[CmdletBinding(DefaultParameterSetName='DryRun')]
param(
    [Parameter(Mandatory = $true, HelpMessage = 'Caminho para arquivo de task/plano (markdown)')]
    [string]$Task,

    [Parameter(HelpMessage = 'Lista de arquivos do projeto a incluir como contexto (separados por virgula)')]
    [string[]]$Files = @(),

    [Parameter(HelpMessage = 'Arquivos de regras a injetar no system prompt (default: CLAUDE.md, AGENTS.md)')]
    [string[]]$Rules = @('CLAUDE.md', 'AGENTS.md'),

    [Parameter(HelpMessage = 'Modelo DeepSeek (default: deepseek-chat = V3.1/V4)')]
    [string]$Model = 'deepseek-chat',

    [Parameter(HelpMessage = 'Temperatura (default: 0.0 para implementacao deterministica)')]
    [double]$Temperature = 0.0,

    [Parameter(ParameterSetName = 'Apply', HelpMessage = 'Aplica mudancas (escreve arquivos)')]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'DryRun', HelpMessage = 'Apenas mostra saida, nao escreve nada (default)')]
    [switch]$DryRun,

    [Parameter(HelpMessage = 'Endpoint DeepSeek (default: API oficial)')]
    [string]$Endpoint = 'https://api.deepseek.com/v1/chat/completions'
)

$ErrorActionPreference = 'Stop'

if (-not $env:DEEPSEEK_API_KEY) {
    $envPath = Join-Path (Get-Location) '.env'
    if (Test-Path $envPath) {
        Write-Host "[deepseek-impl] Carregando .env do projeto..." -ForegroundColor DarkGray
        Get-Content $envPath | ForEach-Object {
            if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$' -and $_ -notmatch '^\s*#') {
                $name = $matches[1]
                $val = $matches[2] -replace '^["'']|["'']$',''
                if (-not (Get-Item -Path "env:$name" -ErrorAction SilentlyContinue)) {
                    Set-Item -Path "env:$name" -Value $val
                }
            }
        }
    }
}

if (-not $env:DEEPSEEK_API_KEY) {
    Write-Error "DEEPSEEK_API_KEY nao encontrada. Garanta que esta no .env do diretorio atual ou exportada na sessao."
    exit 2
}

if (-not (Test-Path $Task)) {
    Write-Error "Arquivo de task nao encontrado: $Task"
    exit 2
}

$taskBody = Get-Content -Path $Task -Raw -Encoding UTF8

$rulesText = ''
foreach ($r in $Rules) {
    if (Test-Path $r) {
        $rulesText += "`n=== $r ===`n"
        $rulesText += Get-Content -Path $r -Raw -Encoding UTF8
        $rulesText += "`n"
    }
}

$contextText = ''
foreach ($f in $Files) {
    if (Test-Path $f) {
        $contextText += "`n=== FILE: $f ===`n"
        $contextText += Get-Content -Path $f -Raw -Encoding UTF8
        $contextText += "`n=== END FILE: $f ===`n"
    } else {
        Write-Warning "Arquivo de contexto nao encontrado, ignorando: $f"
    }
}

$systemPrompt = @"
Voce e um worker de implementacao mecanica delegado pelo Claude Code.

REGRAS INEGOCIAVEIS DO PROJETO (siga literalmente):
$rulesText

DIRETRIZES DE OUTPUT:
- Para cada arquivo modificado ou criado, emita um bloco no formato:

  ===WRITE: <caminho relativo>===
  <conteudo completo do arquivo>
  ===END===

- Para cada comando shell sugerido (migration, install, etc):

  ===SHELL===
  <comando>
  ===END===

- NAO inclua explicacoes longas. Codigo + comandos + 1-2 linhas de comentario por bloco se for nao-obvio.
- NAO altere arquivos fora do escopo da task.
- Se a task for ambigua ou exigir decisao arquitetural, RECUSE com bloco:

  ===REJECT===
  Motivo: <razao>
  Pergunta a esclarecer: <o que precisa decidir>
  ===END===

  Nao invente decisao por conta propria.
"@

$userPrompt = @"
TASK:
$taskBody

CONTEXTO DOS ARQUIVOS:
$contextText
"@

$body = @{
    model       = $Model
    temperature = $Temperature
    messages    = @(
        @{ role = 'system'; content = $systemPrompt },
        @{ role = 'user'; content = $userPrompt }
    )
    stream      = $false
} | ConvertTo-Json -Depth 10 -Compress

# PS 5.1 + Invoke-RestMethod manda body como Windows-1252, quebra acentos do CLAUDE.md/AGENTS.md.
# Forcar UTF-8 explicitamente via byte array + content-type com charset.
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

$headers = @{
    'Authorization' = "Bearer $($env:DEEPSEEK_API_KEY)"
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = Join-Path (Get-Location) '.deepseek\runs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "$timestamp.jsonl"

Write-Host "[deepseek-impl] Chamando $Model em $Endpoint..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $Endpoint -Method Post -Headers $headers -Body $bodyBytes -ContentType 'application/json; charset=utf-8' -TimeoutSec 600
} catch {
    Write-Error "Falha na chamada DeepSeek: $_"
    @{ ts = $timestamp; error = $_.ToString(); request = $body } | ConvertTo-Json -Compress | Out-File -FilePath $logFile -Encoding utf8
    exit 1
}

$content = $response.choices[0].message.content
$usage = $response.usage

@{
    ts       = $timestamp
    model    = $Model
    task     = $Task
    files    = $Files
    rules    = $Rules
    usage    = $usage
    response = $content
} | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $logFile -Encoding utf8

Write-Host "[deepseek-impl] Tokens: prompt=$($usage.prompt_tokens) completion=$($usage.completion_tokens) total=$($usage.total_tokens)" -ForegroundColor Green
Write-Host "[deepseek-impl] Log: $logFile" -ForegroundColor Green
Write-Host ''

if ($content -match '===REJECT===') {
    Write-Warning "DeepSeek RECUSOU a task. Veja o motivo abaixo:"
    Write-Host $content
    exit 3
}

$writeMatches = [regex]::Matches($content, '(?ms)===WRITE:\s*(.+?)===\r?\n(.*?)\r?\n===END===')
$shellMatches = [regex]::Matches($content, '(?ms)===SHELL===\r?\n(.*?)\r?\n===END===')

if ($writeMatches.Count -eq 0 -and $shellMatches.Count -eq 0) {
    Write-Warning "Saida sem blocos WRITE/SHELL/REJECT. Output bruto abaixo:"
    Write-Host $content
    exit 4
}

Write-Host "[deepseek-impl] Arquivos a escrever: $($writeMatches.Count)" -ForegroundColor Yellow
Write-Host "[deepseek-impl] Comandos sugeridos:  $($shellMatches.Count)" -ForegroundColor Yellow
Write-Host ''

foreach ($m in $writeMatches) {
    $path = $m.Groups[1].Value.Trim()
    $body = $m.Groups[2].Value
    $bytes = [System.Text.Encoding]::UTF8.GetByteCount($body)
    Write-Host ("  WRITE {0,-60} {1,8} bytes" -f $path, $bytes) -ForegroundColor White
}

foreach ($m in $shellMatches) {
    $cmd = $m.Groups[1].Value.Trim()
    Write-Host "  SHELL $cmd" -ForegroundColor Magenta
}

if (-not $Apply) {
    Write-Host ''
    Write-Host "[deepseek-impl] DRY-RUN. Nada escrito. Use -Apply para aplicar." -ForegroundColor Yellow
    Write-Host ''
    Write-Host "=== RAW OUTPUT ===" -ForegroundColor DarkGray
    Write-Host $content
    exit 0
}

Write-Host ''
Write-Host "[deepseek-impl] APPLY mode. Escrevendo arquivos..." -ForegroundColor Cyan

foreach ($m in $writeMatches) {
    $path = $m.Groups[1].Value.Trim()
    $body = $m.Groups[2].Value

    $dir = Split-Path -Path $path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $path -Value $body -Encoding utf8 -NoNewline
    Write-Host "  + $path" -ForegroundColor Green
}

if ($shellMatches.Count -gt 0) {
    Write-Host ''
    Write-Host "[deepseek-impl] Comandos shell NAO foram executados automaticamente. Revise e rode manualmente:" -ForegroundColor Yellow
    foreach ($m in $shellMatches) {
        Write-Host "  $($m.Groups[1].Value.Trim())" -ForegroundColor Magenta
    }
}

Write-Host ''
Write-Host "[deepseek-impl] Pronto. Rode /percus-review:review antes de commitar (R11)." -ForegroundColor Green
