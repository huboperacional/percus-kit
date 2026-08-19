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
    [string]$Model = "deepseek-v4-flash",
    # "low" por padrao (2026-08-19). Este script roda a CADA commit em dezenas de projetos, e
    # e o maior gastador do kit: a telemetria nova mostrou uma review real queimando 31.747
    # tokens de saida, 31.197 deles (98%) so RACIOCINANDO, pra produzir uma lista curta de
    # findings. Ver o bloco de medicao no corpo do request. "" omite o campo.
    [ValidateSet("none","low","medium","high","")]
    [string]$ReasoningEffort = "low",
    [double]$Temperature = 0.0,
    [string]$Endpoint = "https://api.deepseek.com/v1/chat/completions"
)
$ErrorActionPreference = "Stop"

# Mesmo classificador dos tres providers do conselho: HTTP 200 nao quer dizer que houve
# resposta. Aqui pesa mais do que la, porque este script libera commit (R11).
# UM child path por Join-Path. O parametro -AdditionalChildPath (que aceita 3+ argumentos)
# so existe do PowerShell 6 em diante; no 5.1 -- que e o runtime real dos hooks -- a chamada
# morre com "Nao e possivel localizar um parametro posicional que aceite o argumento
# 'providers'". Pego pelo proprio R11 em 2026-08-16: a suite roda em pwsh 7, onde funciona,
# e o ps51-compat afere PARSE, nao runtime -- isto passaria verde nos dois.
$percusProvidersDir = Join-Path (Split-Path $PSScriptRoot -Parent) "providers"
. (Join-Path $percusProvidersDir "_resposta.ps1")

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

$bodyObj = @{
    model       = $Model
    temperature = $Temperature
    messages    = @(
        @{ role = "system"; content = $systemPrompt },
        @{ role = "user"; content = $userMsg }
    )
}
# reasoning_effort (2026-08-19). Medido no mesmo prompt real de review (11 KB):
#   sem effort : completion 13805, raciocinio 12826 (80% do teto), 3284 chars de resposta
#   effort=low : completion  4395, raciocinio  2934 (18% do teto), 5140 chars de resposta
#   effort=med : completion 14207, raciocinio 12751 -- praticamente igual ao default
# Nao e economia apertando qualidade: `low` devolveu MAIS texto, porque o orcamento parou de
# ser consumido pensando. E resolve a perna que voltava VAZIA -- com 80% do teto indo pra
# raciocinio, bastava a variacao normal (medida entre 6784 e 16000 no mesmo prompt) pra nao
# sobrar nada pra resposta.
#
# ❌ NAO "consertar" isso subindo max_tokens: ja foi feito (8192 -> 16000) e o sintoma voltou
# identico, porque o raciocinio se expande ate encher o teto que existir. Ver
# conhecimento/resolver/cross-claude-review-queima-16000-e-volta-vazio.md.
if ($ReasoningEffort) { $bodyObj.reasoning_effort = $ReasoningEffort }
$body = $bodyObj | ConvertTo-Json -Depth 10 -Compress

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

# === GATE: resposta nao utilizavel NAO libera commit ===
# Ate 2026-08-16 o marcador abaixo era escrito incondicionalmente. Se o modelo devolvesse
# content vazio (gastou o teto raciocinando) ou cortado no meio, o commit passava com ZERO
# review e NADA dizia -- o hook so olha se existe marcador fresco. Fail-open num gate e pior
# que gate nenhum: gate nenhum voce sabe que nao tem.
# O lado bash (deepseek-review.sh) ja barrava resposta vazia desde sempre; o PowerShell nao.
$cls = Get-StatusResposta -Conteudo $findings `
                          -FinishReason $response.choices[0].finish_reason `
                          -Usage $response.usage
if ($cls.Status -ne "ok") {
    Write-Host "[deepseek-review] REVIEW NAO CONCLUIDA -- $($cls.Aviso)" -ForegroundColor Red
    Write-Host "[deepseek-review] O marcador NAO foi escrito: o commit segue bloqueado (R11)." -ForegroundColor Red
    Write-Host "[deepseek-review] Rode de novo. Se repetir, encolha o diff -- nao o teto." -ForegroundColor Yellow
    exit 3
}

# Fail-open residual, apontado pelo proprio R11 em 2026-08-16: o classificador so conhece
# "length" como corte, entao QUALQUER outro finish_reason anomalo (content_filter, ausente
# por resposta malformada, valor novo que a API passe a devolver) chegava aqui como "ok" e
# liberava o commit. Num gate, desconhecido tem que contar como falha, nao como sucesso.
#
# Por que esta regra mora AQUI e nao no _resposta.ps1 compartilhado: o vocabulario e por
# provider. "stop" e o encerramento normal da DeepSeek (formato OpenAI); a Anthropic devolve
# "end_turn", e o cross-claude so traduz max_tokens -> length. Um "!= stop" no classificador
# compartilhado reprovaria TODA resposta do Cross-Claude -- a correcao obvia quebraria a perna
# que acabou de ser consertada.
$finish = "$($response.choices[0].finish_reason)"
if ($finish -ne "stop") {
    $rotulo = if ([string]::IsNullOrWhiteSpace($finish)) { "<ausente>" } else { $finish }
    Write-Host "[deepseek-review] REVIEW NAO CONCLUIDA -- finish_reason inesperado: '$rotulo'." -ForegroundColor Red
    Write-Host "[deepseek-review] Encerramento normal da DeepSeek e 'stop'. Qualquer outro valor" -ForegroundColor Red
    Write-Host "[deepseek-review] significa que a resposta nao terminou como deveria." -ForegroundColor Red
    Write-Host "[deepseek-review] O marcador NAO foi escrito: o commit segue bloqueado (R11)." -ForegroundColor Red
    exit 3
}

# === LOG ===
$logDir = Join-Path (Get-Location) '.deepseek\reviews'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
# Path FIXO latest.jsonl (2026-07-20): antes era <timestamp>.jsonl e o dir
# acumulava milhares de marcadores (TTL 5min, zero valor) ate o hook R11
# pendurar ~148s e travar os commits do projeto. Um arquivo sobrescrito =>
# hook O(1), acumulo inexistente. Escrita atomica (tmp + rename) pro hook
# nunca ler no meio da escrita.
$logFile = Join-Path $logDir 'latest.jsonl'
$logTmp  = Join-Path $logDir 'latest.jsonl.tmp'
# model + usage no log (2026-08-15): sem eles o marcador nao diz QUAL modelo revisou nem
# quanto custou, e a troca de deepseek-chat -> v4-pro (24/07) passou tres semanas invisivel
# por aqui -- so apareceu no painel da DeepSeek. Quem grava o veredito grava o preco dele.
# Campos ausentes na resposta viram $null em vez de quebrar a escrita do marcador: este
# arquivo e o que libera o commit (R11), e nao pode falhar por causa de telemetria.
@{
    timestamp  = (Get-Date -Format 'o')
    base       = $Base
    diff_lines = ($diff -split "`n").Count
    model      = $Model
    usage      = $response.usage
    findings   = $findings
} | ConvertTo-Json -Depth 5 -Compress | Out-File -FilePath $logTmp -Encoding utf8
Move-Item -Path $logTmp -Destination $logFile -Force

# === TELEMETRIA DE GASTO (2026-08-19) ===
# Diretorio SEPARADO do marcador, de proposito. O latest.jsonl e sobrescrito a cada review
# (2026-07-20) pra manter o hook R11 em O(1) -- decisao certa, que custou a visibilidade do
# custo: em 2026-08-19 os logs de conselho de 62 diretorios .deepseek somavam $0.89 de um
# painel de $29.76. 97% do gasto invisivel, e justamente pelo caminho MAIS usado (review
# existe em 48 projetos, o dobro do conselho).
#
# Formato: APPEND de uma linha por review em .deepseek/spend/<YYYY-MM>.jsonl. Arquivo por MES
# (12 por ano, nao milhares) -- e o que impede a volta do acumulo que pendurou o hook em 148s.
# O hook nunca varre este diretorio: ele so olha .deepseek/reviews/latest.jsonl.
#
# NAO grava prompt nem resposta: telemetria nao e copia de conteudo. So o que precifica.
#
# try/catch com silencio deliberado: este script libera o commit (R11). Se a telemetria
# falhar (disco cheio, permissao, corrida no append), o review TEM que seguir -- o mesmo
# principio que ja fez os campos ausentes virarem $null no marcador em vez de quebrar.
try {
    $spendDir = Join-Path (Get-Location) '.deepseek\spend'
    if (-not (Test-Path $spendDir)) { New-Item -ItemType Directory -Path $spendDir -Force | Out-Null }
    # UTC nos DOIS irmaos, de proposito. O .sh usa `date -u`; se este usasse hora local, o
    # mesmo instante cairia em dia diferente conforme o script que rodou -- e na virada do mes,
    # em ARQUIVO diferente. O parser tira o offset e compara naive, entao a divergencia nao
    # apareceria como erro: apareceria como relatorio de N dias silenciosamente torto (4h de
    # deslocamento neste fuso). Achado pelo R11 antes de commitar.
    $agoraUtc  = [DateTime]::UtcNow
    $spendFile = Join-Path $spendDir ($agoraUtc.ToString('yyyy-MM') + '.jsonl')
    $linha = @{
        timestamp  = $agoraUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        tool       = 'deepseek-review'
        provider   = 'deepseek'
        model      = $Model
        usage      = $response.usage
        diff_lines = ($diff -split "`n").Count
    } | ConvertTo-Json -Depth 5 -Compress
    # Uma linha por chamada, com \n no fim: append curto e a forma mais proxima de atomico que
    # da pra ter sem lock. Se duas sessoes appendarem no mesmo instante e uma linha sair
    # cortada, o leitor (parse_spend_file) pula a linha ruim em vez de perder o mes.
    Add-Content -Path $spendFile -Value $linha -Encoding utf8
} catch {
    # Silencio proposital -- ver comentario acima. A ausencia de telemetria nao pode custar
    # um commit.
}

# Auto-poda: o mecanismo agora e latest.jsonl unico. Remove marcadores
# <timestamp>.jsonl irmaos (pilhas antigas drenam sozinhas no proximo review,
# sem depender de limpeza manual nem de reinstalar os hooks). Produtor-side.
Get-ChildItem $logDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'latest.jsonl' } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# === OUTPUT ===
Write-Host "## Findings DeepSeek (cross-provider review)`n" -ForegroundColor Cyan
Write-Output $findings
