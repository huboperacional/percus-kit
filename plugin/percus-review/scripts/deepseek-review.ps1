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
    [string]$Endpoint = "https://api.deepseek.com/v1/chat/completions",
    # 2026-09-14 (FR-001/002): precedencia parametro > env > padrao. Sem valor padrao no param de
    # proposito: $PSBoundParameters diz se o chamador passou.
    [int]$TimeoutSec,
    [int]$BackoffSec,
    # 2026-09-15 (ponto 23): diff acima do teto e revisado em fatias por arquivo -- os achados
    # saturam em ~2,6 por chamada (verbete achado-de-review-satura-com-o-tamanho-do-diff).
    # Mesma precedencia do timeout: parametro > env > padrao.
    [int]$MaxLinhasFatia,
    [int]$MaxFatias
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
# Carga GUARDADA, nao incondicional. A faixa e ornamento do prompt; o review e o gate. Com
# dot-source cru sob ErrorActionPreference=Stop, um cache parcial (script novo sem o helper
# novo) mataria o revisor e travaria TODO commit da frota por causa do ornamento. Pego pelo
# proprio R11 nesta mudanca. Guardado nos QUATRO consumidores, do mesmo jeito.
$faixaHelper = Join-Path $PSScriptRoot "_faixa-regras.ps1"
if (Test-Path $faixaHelper) { . $faixaHelper }

# Force UTF-8 console (Windows PS 5.1 default is Win-1252, mangles PT-BR)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Helper: roda git sem deixar stderr virar NativeCommandError em PS 5.1
function Invoke-GitSafe {
    # ⚠️ SILENCIAR stderr E IGNORAR o exit code era a receita de um portao que
    # passa em silencio: `git diff` falhando devolvia vazio, o chamador lia
    # "diff vazio" e o script saia 0 -- R11 satisfeito sem ter revisado nada.
    # Medido em 2026-08-25 com arquivo staged: saida "Nada pra revisar", exit 0.
    # Agora a falha do git PROPAGA. Portao que nao consegue medir REPROVA.
    # stderr vai para ARQUIVO, nao para o stdout: com `2>&1` os avisos do git
    # ("LF will be replaced by CRLF", dicas de hint) entravam no texto do DIFF
    # enviado ao modelo -- o portao passaria a revisar ruido junto com o codigo.
    # Achado pela review DeepSeek do proprio patch, e visivel no output dela.
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $output = & git @Arguments 2>$errFile
        if ($LASTEXITCODE -ne 0) {
            $erro = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
            throw "git $($Arguments -join ' ') falhou (exit $LASTEXITCODE): $erro"
        }
        return $output
    } finally {
        $ErrorActionPreference = $prev
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
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

# === TIMEOUT E BACKOFF (2026-09-14) ===
# Ate aqui a chamada nao tinha timeout: medido um travamento de 4 min que segurou uma onda de
# commits ~65 min. Parametro invalido e erro do chamador (exit 2); env invalida vira padrao com aviso.
function Get-InteiroDeEnv {
    param([string]$Nome, [int]$Padrao, [int]$Minimo)
    $valor = [Environment]::GetEnvironmentVariable($Nome)
    if ([string]::IsNullOrWhiteSpace($valor)) { return $Padrao }
    $n = 0
    if ([int]::TryParse($valor.Trim(), [ref]$n) -and $n -ge $Minimo) { return $n }
    [Console]::Error.WriteLine("[deepseek-review] WARN: $Nome='$valor' invalido -- usando padrao $Padrao.")
    return $Padrao
}
if ($PSBoundParameters.ContainsKey('TimeoutSec')) {
    if ($TimeoutSec -lt 1) { [Console]::Error.WriteLine("[deepseek-review] ERRO: -TimeoutSec precisa ser >= 1."); exit 2 }
    $timeoutEfetivo = $TimeoutSec
} else { $timeoutEfetivo = Get-InteiroDeEnv -Nome 'PERCUS_DEEPSEEK_TIMEOUT_S' -Padrao 180 -Minimo 1 }
if ($PSBoundParameters.ContainsKey('BackoffSec')) {
    if ($BackoffSec -lt 0) { [Console]::Error.WriteLine("[deepseek-review] ERRO: -BackoffSec precisa ser >= 0."); exit 2 }
    $backoffEfetivo = $BackoffSec
} else { $backoffEfetivo = Get-InteiroDeEnv -Nome 'PERCUS_DEEPSEEK_BACKOFF_S' -Padrao 5 -Minimo 0 }
if ($PSBoundParameters.ContainsKey('MaxLinhasFatia')) {
    if ($MaxLinhasFatia -lt 200) { [Console]::Error.WriteLine("[deepseek-review] ERRO: -MaxLinhasFatia precisa ser >= 200."); exit 2 }
    $maxLinhasFatiaEfetivo = $MaxLinhasFatia
} else { $maxLinhasFatiaEfetivo = Get-InteiroDeEnv -Nome 'PERCUS_R11_MAX_LINHAS_FATIA' -Padrao 1500 -Minimo 200 }
if ($PSBoundParameters.ContainsKey('MaxFatias')) {
    if ($MaxFatias -lt 1) { [Console]::Error.WriteLine("[deepseek-review] ERRO: -MaxFatias precisa ser >= 1."); exit 2 }
    $maxFatiasEfetivo = $MaxFatias
} else { $maxFatiasEfetivo = Get-InteiroDeEnv -Nome 'PERCUS_R11_MAX_FATIAS' -Padrao 8 -Minimo 1 }

# === COLLECT DIFF ===
if ($Base) {
    # `$Base` e o PRIMEIRO parametro posicional, e os skills mandam o texto de
    # contexto posicionalmente ("diff staged: ..."). Esse texto virava -Base, o
    # `git diff "<texto>...HEAD"` falhava, e o script saia 0 dizendo "diff
    # vazio" -- toda invocacao com contexto passava sem revisar nada.
    # Validar aqui separa "ref que nao existe" de "voce passou contexto".
    # `git` DIRETO aqui, nao Invoke-GitSafe: aquela agora LANCA em exit != 0, e
    # o ponto desta checagem e' justamente tratar o exit != 0 com uma mensagem
    # que diz o que fazer. Com Invoke-GitSafe o usuario levava um stack trace.
    $null = & git rev-parse --verify --quiet "$Base^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[deepseek-review] ERRO: -Base '$Base' nao e um ref git valido." -ForegroundColor Red
        Write-Host "  Se voce quis passar CONTEXTO, nao passe posicionalmente -- o 1o posicional e -Base." -ForegroundColor Red
        Write-Host "  Rode sem argumento (revisa staged+working tree) ou use -Base <ref>." -ForegroundColor Red
        exit 2
    }
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
# A faixa e MEDIDA no canon agora, nao escrita a mao. Ate 2026-09-12 estava literal aqui com
# um teto de duas dezenas atras do canon, e o revisor reprovava regra valida dizendo que ela
# "nao existe". Ver scripts/_faixa-regras.ps1 e o verbete
# conhecimento/resolver/revisor-cita-faixa-de-regras-fixa-no-prompt-e-reprova-regra-valida.md
$faixaRegras = if (Get-Command Get-PercusFaixaRegras -ErrorAction SilentlyContinue) {
    Get-PercusFaixaRegras
} else {
    "faixa nao medida -- consulte 01_REGRAS_INEGOCIAVEIS.md"
}

$systemPrompt = @"
Você é revisor cross-provider de código no padrão Percus.
Leia o git diff e o AGENTS.md (regras do projeto).
Para cada problema, emita finding no formato:

[SEV: bug | risco | preferência]
Arquivo: caminho/relativo:linha
Regra violada: R{N} (se aplicável)
Problema: descrição em 1-2 frases
Sugestão: ação concreta

Foque em: bugs, regressões, violações do canon Percus ($faixaRegras), mock escondido (R3), JWT em localStorage (R7), pasta sensível tocada indevidamente, imports fora do stack canônico.
NÃO aponte estilo subjetivo sem regra concreta. NÃO sugira refactor fora do diff. Se nada relevante, responda "Sem findings críticos."
"@

function New-CorpoRevisao {
param([string]$Sistema, [string]$Usuario)
$bodyObj = @{
    model       = $Model
    temperature = $Temperature
    messages    = @(
        @{ role = "system"; content = $Sistema },
        @{ role = "user"; content = $Usuario }
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
# Virgula: devolve o byte[] inteiro, sem o pipeline desempacotar em N bytes.
return ,([System.Text.Encoding]::UTF8.GetBytes($body))
}

# === FATIAMENTO POR ARQUIVO (2026-09-15, ponto 23) ===
# Os achados saturam em ~2,6 por chamada (verbete achado-de-review-satura-com-o-tamanho-do-diff):
# um diff de 5.000 linhas revisado de uma vez rende o mesmo que um de 1.500. Acima do teto o diff
# e partido nas fronteiras `diff --git` e cada fatia vira uma chamada. Linhas contadas sobre o
# MESMO texto que vai ao modelo ($diff), nao sobre os arquivos.
function Test-CaminhoDeTeste {
    param([string]$Caminho)
    $nome = ($Caminho -split '/')[-1]
    # Sem distinguir maiuscula: a convencao do kit e `x.tests.ps1`, mas o padrao do Pester em outros
    # projetos e `X.Tests.ps1` -- case-sensitive mandaria o teste pro grupo de codigo (achado do R11
    # desta mudanca). O awk do irmao .sh usa tolower() pelo mesmo motivo.
    return (($nome -like '*.tests.ps1') -or ($nome -match '^test_.*\.py$') -or ($nome -match '_test\.py$') -or
            ($nome -match '\.(test|spec)\.tsx?$') -or (('/' + $Caminho) -like '*/tests/*'))
}

function Split-DiffEmArquivos {
    # So `diff --git ` no INICIO da linha abre arquivo novo: dentro de um .md a mesma string vem
    # com prefixo +/-/espaco. Texto antes do 1o cabecalho (nao deveria existir) fica no 1o bloco.
    param([string]$Texto)
    $blocos = New-Object System.Collections.Generic.List[object]
    $atual = $null
    foreach ($l in ($Texto -split "`n")) {
        $ehCabecalho = $l.StartsWith('diff --git ')
        if ($null -eq $atual -or ($ehCabecalho -and $atual.TemCabecalho)) {
            $atual = @{ Linhas = New-Object System.Collections.Generic.List[string]; Caminho = ''; TemCabecalho = $false; EhTeste = $false }
            [void]$blocos.Add($atual)
        }
        if ($ehCabecalho) {
            $atual.TemCabecalho = $true
            $cab = $l.TrimEnd("`r")
            $i = $cab.LastIndexOf(' b/')
            if ($i -ge 0) { $atual.Caminho = $cab.Substring($i + 3) }
            else {
                $i = $cab.LastIndexOf(' "b/')
                if ($i -ge 0) { $atual.Caminho = $cab.Substring($i + 4).TrimEnd('"') }
            }
            $atual.EhTeste = Test-CaminhoDeTeste -Caminho $atual.Caminho
        }
        [void]$atual.Linhas.Add($l)
    }
    return ,$blocos
}

function New-FatiasDoDiff {
    # Codigo primeiro, teste depois, cada grupo na ordem do diff; fatia de teste nunca mistura
    # codigo. Gulosa: fecha a fatia quando o proximo arquivo estouraria o teto. Arquivo sozinho
    # maior que o teto vira fatia propria, sem corte.
    param($Blocos, [int]$Teto)
    $fatias = New-Object System.Collections.Generic.List[object]
    foreach ($grupoTeste in @($false, $true)) {
        $cur = $null
        foreach ($b in $Blocos) {
            if ($b.EhTeste -ne $grupoTeste) { continue }
            $n = $b.Linhas.Count
            if ($null -ne $cur -and ($cur.Linhas + $n) -gt $Teto) { [void]$fatias.Add($cur); $cur = $null }
            if ($null -eq $cur) { $cur = @{ Linhas = 0; Blocos = New-Object System.Collections.Generic.List[object] } }
            [void]$cur.Blocos.Add($b)
            $cur.Linhas += $n
        }
        if ($null -ne $cur) { [void]$fatias.Add($cur) }
    }
    return ,$fatias
}

$diffLinhasTotal = ($diff -split "`n").Count
$userMsg = "AGENTS.md do projeto:`n$agents`n`n---`n`nGit diff:`n$diff"
# Uma chamada = @{ Corpo; Sufixo; Rotulo; Linhas }. Sem fatiar: UMA chamada com o corpo identico ao
# de antes do fatiamento.
$chamadas = New-Object System.Collections.Generic.List[object]
if ($diffLinhasTotal -gt $maxLinhasFatiaEfetivo) {
    $fatiasPlano = New-FatiasDoDiff -Blocos (Split-DiffEmArquivos -Texto $diff) -Teto $maxLinhasFatiaEfetivo
    if ($fatiasPlano.Count -gt $maxFatiasEfetivo) {
        [Console]::Error.WriteLine("[deepseek-review] WARN: diff de $diffLinhasTotal linhas precisaria de $($fatiasPlano.Count) fatias (> $maxFatiasEfetivo): revisado inteiro; achados saturam em ~2,6 por chamada -- considere dividir o commit.")
    } elseif ($fatiasPlano.Count -gt 1) {
        $nF = $fatiasPlano.Count
        for ($iF = 0; $iF -lt $nF; $iF++) {
            $f = $fatiasPlano[$iF]
            $arqs = @($f.Blocos | ForEach-Object { $_.Caminho } | Where-Object { $_ }) -join ', '
            $linhasF = New-Object System.Collections.Generic.List[string]
            foreach ($b in $f.Blocos) { $linhasF.AddRange($b.Linhas) }
            $sis = $systemPrompt + "`n`nEsta e a fatia $($iF + 1) de $nF (arquivos: $arqs). Revise so o que esta nela."
            $usr = "AGENTS.md do projeto:`n$agents`n`n---`n`nGit diff:`n" + ($linhasF -join "`n")
            [void]$chamadas.Add(@{ Corpo = (New-CorpoRevisao -Sistema $sis -Usuario $usr); Sufixo = " (fatia $($iF + 1)/$nF)"; Rotulo = "$($iF + 1)/$nF"; Arquivos = $arqs; Linhas = $f.Linhas })
        }
    }
}
if ($chamadas.Count -eq 0) {
    [void]$chamadas.Add(@{ Corpo = (New-CorpoRevisao -Sistema $systemPrompt -Usuario $userMsg); Sufixo = ''; Rotulo = ''; Arquivos = ''; Linhas = $diffLinhasTotal })
}

# === CHAMADA COM TIMEOUT E EXATAMENTE 1 RETRY (2026-09-14, FR-001..005) ===
# HttpClient e nao Invoke-RestMethod: no 5.1 o IRM lanca em 4xx/5xx e o corpo se perde, e em 2xx sem
# choices a linha seguinte morria em "Cannot index into a null array" descartando o corpo (verbete
# deepseek-review-2xx-sem-choices-nao-grava-review). HttpClient devolve status e corpo nos dois
# runtimes, e o Timeout cobre conexao + leitura do corpo (ResponseContentRead e o padrao).
Add-Type -AssemblyName System.Net.Http
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

function Get-TrechoMascarado {
    # Mascara ANTES de cortar: cortar primeiro deixaria meia chave na borda dos 2000.
    param([string]$Corpo, [string]$Chave)
    $m = "$Corpo"
    if ($Chave) { $m = $m.Replace($Chave, '***') }
    if ($m.Length -gt 2000) { $m = $m.Substring(0, 2000) }
    return $m
}

function Write-UltimoErro {
    param([int]$Status, [string]$Trecho)
    try {
        $dir = Join-Path (Get-Location) '.deepseek\reviews'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $txt = "timestamp=" + [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ') + "`n" + "status=$Status`n---`n" + $Trecho
        [IO.File]::WriteAllText((Join-Path $dir 'ultimo-erro.txt'), $txt, (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        [Console]::Error.WriteLine("[deepseek-review] WARN: nao consegui gravar ultimo-erro.txt: $($_.Exception.Message)")
    }
}

function Invoke-TentativaDeepSeek {
    param([string]$Uri, [byte[]]$Corpo, [string]$Chave, [int]$Timeout)
    $cliente = New-Object System.Net.Http.HttpClient
    $cliente.Timeout = [TimeSpan]::FromSeconds($Timeout)
    try {
        $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $Uri)
        [void]$req.Headers.TryAddWithoutValidation('Authorization', "Bearer $Chave")
        # Virgula: passa o byte[] como UM argumento, nao como N argumentos.
        $conteudo = New-Object System.Net.Http.ByteArrayContent -ArgumentList (,$Corpo)
        [void]$conteudo.Headers.TryAddWithoutValidation('Content-Type', 'application/json; charset=utf-8')
        $req.Content = $conteudo
        $resp = $cliente.SendAsync($req).GetAwaiter().GetResult()
        $bytes = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        return @{ Rede = $false; Status = [int]$resp.StatusCode; Corpo = [Text.Encoding]::UTF8.GetString($bytes); Erro = '' }
    } catch {
        # HttpClient.Timeout aborta a leitura cancelando a task: a excecao de FORA e
        # TaskCanceledException, mas a MAIS FUNDA da cadeia costuma ser um IOException generico
        # ("operacao de E/S anulada"). Descer direto ate a mais funda (como o resto do script faz
        # pra pegar a mensagem legivel) perdia o sinal de timeout -- medido: o teste de timeout
        # caia no ramo "erro de rede/timeout: <IOException>" em vez de "timeout de Ns". Por isso
        # a cadeia INTEIRA e varrida pelo tipo ANTES de descer pra pegar a mensagem.
        $e = $_.Exception
        $ehTimeout = $false
        $cursor = $e
        while ($cursor) {
            if ($cursor -is [System.Threading.Tasks.TaskCanceledException] -or
                $cursor -is [System.TimeoutException] -or
                $cursor -is [System.OperationCanceledException]) { $ehTimeout = $true }
            $cursor = $cursor.InnerException
        }
        while ($e.InnerException) { $e = $e.InnerException }
        $msg = $e.Message
        if ($ehTimeout) { $msg = "timeout de ${Timeout}s" }
        return @{ Rede = $true; Status = 0; Corpo = ''; Erro = $msg }
    } finally { $cliente.Dispose() }
}

function Get-VereditoTentativa {
    # @{ Veredito = 'ok'|'retry'|'fatal'; Causa; Resposta }
    param($T, [string]$Chave)
    if ($T.Rede) { return @{ Veredito = 'retry'; Causa = "erro de rede/timeout: $($T.Erro)"; Resposta = $null } }
    $s = $T.Status
    $obj = $null
    $temChoices = $false
    $corpoLimpo = "$($T.Corpo)".Trim()
    # Raiz pelo 1o caractere: pwsh 7 enumera array na raiz do ConvertFrom-Json.
    if ($corpoLimpo.StartsWith('{')) {
        try { $obj = ConvertFrom-Json -InputObject $T.Corpo -ErrorAction Stop } catch { $obj = $null }
        if ($obj -is [System.Management.Automation.PSCustomObject] -and $null -ne $obj.choices -and @($obj.choices).Count -gt 0) { $temChoices = $true }
    }
    if (-not $temChoices) {
        $trecho = Get-TrechoMascarado -Corpo $T.Corpo -Chave $Chave
        [Console]::Error.WriteLine("[deepseek-review] resposta sem choices (HTTP $s) -- primeiros 2000 caracteres do corpo:")
        [Console]::Error.WriteLine($trecho)
        Write-UltimoErro -Status $s -Trecho $trecho
    }
    if ($s -ge 200 -and $s -le 299) {
        if ($temChoices) { return @{ Veredito = 'ok'; Causa = ''; Resposta = $obj } }
        if ($corpoLimpo.Length -eq 0) { return @{ Veredito = 'retry'; Causa = "HTTP $s com corpo vazio"; Resposta = $null } }
        return @{ Veredito = 'retry'; Causa = "HTTP $s sem choices"; Resposta = $null }
    }
    if ($s -eq 429 -or ($s -ge 500 -and $s -le 599)) { return @{ Veredito = 'retry'; Causa = "HTTP $s"; Resposta = $null } }
    return @{ Veredito = 'fatal'; Causa = "HTTP $s"; Resposta = $null }
}

[Console]::Error.WriteLine("[deepseek-review] timeout=${timeoutEfetivo}s backoff=${backoffEfetivo}s")
[Console]::Error.WriteLine("[deepseek-review] max_linhas_fatia=$maxLinhasFatiaEfetivo max_fatias=$maxFatiasEfetivo diff_lines=$diffLinhasTotal chamadas=$($chamadas.Count)")
$chaveApi = $env:DEEPSEEK_API_KEY

# Uma chamada com timeout e exatamente 1 retry, e os portoes da resposta. Qualquer falha SAI do
# script com o codigo de sempre (+ " (fatia i/n)" quando fatiado): nada abaixo -- latest.jsonl,
# d-<hash>, spend -- e gravado. Fatia parcial nunca libera commit meio revisado.
function Invoke-ChamadaRevisao {
param([byte[]]$bodyBytes, [string]$Sufixo)
$av = Get-VereditoTentativa -T (Invoke-TentativaDeepSeek -Uri $Endpoint -Corpo $bodyBytes -Chave $chaveApi -Timeout $timeoutEfetivo) -Chave $chaveApi
if ($av.Veredito -eq 'retry') {
    [Console]::Error.WriteLine("[deepseek-review] tentativa 1 falhou: $($av.Causa.Replace($chaveApi, '***')). Nova tentativa em ${backoffEfetivo}s.$Sufixo")
    Start-Sleep -Seconds $backoffEfetivo
    $av = Get-VereditoTentativa -T (Invoke-TentativaDeepSeek -Uri $Endpoint -Corpo $bodyBytes -Chave $chaveApi -Timeout $timeoutEfetivo) -Chave $chaveApi
    if ($av.Veredito -eq 'retry') {
        [Console]::Error.WriteLine("[deepseek-review] PROVEDOR INDISPONIVEL apos retry: $($av.Causa.Replace($chaveApi, '***')). Nenhum marcador gravado (exit 4).$Sufixo")
        exit 4
    }
}
if ($av.Veredito -eq 'fatal') {
    [Console]::Error.WriteLine("[deepseek-review] ERRO: $($av.Causa) -- nao recuperavel, sem nova tentativa. Nenhum marcador gravado (exit 1).$Sufixo")
    exit 1
}
$response = $av.Resposta
$findings = $response.choices[0].message.content

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
    Write-Host "[deepseek-review] REVIEW NAO CONCLUIDA -- $($cls.Aviso)$Sufixo" -ForegroundColor Red
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
    Write-Host "[deepseek-review] REVIEW NAO CONCLUIDA -- finish_reason inesperado: '$rotulo'.$Sufixo" -ForegroundColor Red
    Write-Host "[deepseek-review] Encerramento normal da DeepSeek e 'stop'. Qualquer outro valor" -ForegroundColor Red
    Write-Host "[deepseek-review] significa que a resposta nao terminou como deveria." -ForegroundColor Red
    Write-Host "[deepseek-review] O marcador NAO foi escrito: o commit segue bloqueado (R11)." -ForegroundColor Red
    exit 3
}
return $response
}

# Fatias em ordem: codigo antes de teste (New-FatiasDoDiff), entao as de teste so rodam depois de
# todas as de codigo passarem -- a primeira falha sai do script.
foreach ($ch in $chamadas) {
    $swCh = [Diagnostics.Stopwatch]::StartNew()
    $respCh = Invoke-ChamadaRevisao -bodyBytes $ch.Corpo -Sufixo $ch.Sufixo
    $swCh.Stop()
    $ch.LatenciaMs = [long]$swCh.Elapsed.TotalMilliseconds
    $ch.Resposta = $respCh
}
$nChamadas = $chamadas.Count
if ($nChamadas -eq 1) {
    $response = $chamadas[0].Resposta
    $findings = $response.choices[0].message.content
    $usageTotal = $response.usage
} else {
    $travessao = [string][char]0x2014
    $partes = New-Object System.Collections.Generic.List[string]
    foreach ($ch in $chamadas) {
        [void]$partes.Add("### Fatia $($ch.Rotulo) $travessao $($ch.Arquivos)`n`n" + $ch.Resposta.choices[0].message.content)
    }
    $findings = $partes -join "`n`n"
    # Soma campo a campo; ausente conta 0 (sem `??`: roda no 5.1).
    $usageTotal = [ordered]@{}
    foreach ($campo in @('prompt_tokens', 'completion_tokens', 'total_tokens', 'prompt_cache_hit_tokens', 'prompt_cache_miss_tokens')) {
        $soma = [long]0
        foreach ($ch in $chamadas) {
            $u = $ch.Resposta.usage
            if ($null -ne $u) { $v = $u.$campo; if ($null -ne $v) { $soma += [long]$v } }
        }
        $usageTotal[$campo] = $soma
    }
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
# Fatiado: UM latest.jsonl so, com os achados de todas as fatias e usage somado -- o hook le um
# arquivo so (pre-commit-check.ps1), e um por fatia liberaria commit meio revisado.
@{
    timestamp  = (Get-Date -Format 'o')
    base       = $Base
    diff_lines = $diffLinhasTotal
    model      = $Model
    usage      = $usageTotal
    findings   = $findings
    fatias     = $nChamadas
} | ConvertTo-Json -Depth 5 -Compress | Out-File -FilePath $logTmp -Encoding utf8
Move-Item -Path $logTmp -Destination $logFile -Force

# === MARCADOR POR HASH DO DIFF (2026-08-19) ===
# A validade da review deixa de ser TEMPO e passa a ser CONTEUDO.
#
# Por que: a janela de 5 min media a coisa errada. Consertar um finding, rodar a suite (184 s
# nesta maquina) ou bumpar versao estourava a janela e forcava re-review -- que revisava
# exatamente o mesmo diff de novo, ~90 s e ~$0,01 por nada. E o inverso tambem era falso: dentro
# dos 5 min dava pra editar tudo e commitar com o aval de uma review que nunca viu aquele codigo.
# Tempo nao e proxy de "isto foi revisado"; hash e.
#
# Hash de `git diff HEAD`, nao de `--cached`, de proposito: `git diff HEAD` NAO muda quando voce
# faz `git add`. Com o diff staged, o fluxo natural (editar -> revisar -> stage -> commit)
# invalidaria a review no `git add`, que e exatamente o retrabalho que este bloco vem matar.
#
# Resolve tambem o marcador compartilhado entre sessoes: o hash de outra sessao simplesmente nao
# casa com o meu diff. Nao precisa de id de sessao -- o conteudo ja discrimina.
#
# O acumulo de 2026-07-20 (milhares de arquivos, hook pendurado em 148 s) NAO volta: o hook faz
# lookup DIRETO do arquivo do hash, nunca enumera o diretorio, e a poda abaixo e por idade.
# ⚠️ O diff vai pra ARQUIVO via `git diff --output=`, e o hash e do ARQUIVO -- nunca da saida
# capturada pelo shell. Medido em 2026-08-19: capturar `git diff HEAD` no PowerShell e no bash e
# hashear o texto produziu hashes DIFERENTES pro mesmo diff (24b54443f4ed vs b5a3110dfee7),
# porque o PowerShell decodifica a saida do processo usando o encoding do console e o diff tem
# acentos. Com `--output=` quem escreve os bytes e o git, identico nos dois runtimes.
# A divergencia seria FALHA SILENCIOSA: o hook nao acharia o marcador, cairia no caminho antigo
# de 5 min, e ninguem descobriria que a otimizacao nunca funcionou no runtime Unix.
try {
    $hashHex = $null
    $tmpDiff = [System.IO.Path]::GetTempFileName()
    try {
        # -C na raiz, igual aos hooks: se o review rodar de um subdiretorio, o hash tem que ser
        # o mesmo que o hook calcula, senao o marcador nunca casa e a otimizacao morre calada.
        $repoTop = (git rev-parse --show-toplevel 2>$null)
        if (-not $repoTop) { $repoTop = (Get-Location).Path }
        git -C $repoTop diff HEAD --output=$tmpDiff 2>$null | Out-Null
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fs  = [IO.File]::OpenRead($tmpDiff)
        try { $hashHex = ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-','').ToLower().Substring(0,12) }
        finally { $fs.Dispose() }
    } finally { Remove-Item $tmpDiff -Force -ErrorAction SilentlyContinue }
    # Guarda do hash vazio: sem ela, git falhando geraria o marcador "d-.jsonl" -- lixo que ainda
    # por cima casaria com um hash vazio do outro lado, liberando commit sem review.
    # e3b0c44298fc = hash do arquivo VAZIO (repo sem commit, git diff HEAD falhou): sem hash,
    # nunca d-e3b0c44298fc.jsonl (emenda FR-011).
    if ($hashHex -and $hashHex -ne 'e3b0c44298fc') {
        Copy-Item -Path $logFile -Destination (Join-Path $logDir "d-$hashHex.jsonl") -Force
    }
} catch {
    # Marcador por hash e otimizacao: se falhar, o latest.jsonl + regra de 5 min continua
    # valendo e o commit segue pelo caminho antigo. Nunca derrubar o review por causa disto.
}

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
    # Uma linha por CHAMADA (fatia), com fatia/fatias/latency_ms; diff_lines e o da fatia.
    # So chega aqui com todas as fatias ok: falha no meio sai antes, sem spend de sucesso.
    for ($iS = 0; $iS -lt $nChamadas; $iS++) {
        $chS = $chamadas[$iS]
        $linha = @{
            timestamp  = $agoraUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
            tool       = 'deepseek-review'
            provider   = 'deepseek'
            model      = $Model
            usage      = $chS.Resposta.usage
            diff_lines = $chS.Linhas
            fatia      = ($iS + 1)
            fatias     = $nChamadas
            latency_ms = $chS.LatenciaMs
        } | ConvertTo-Json -Depth 5 -Compress
        # Uma linha por chamada, com \n no fim: append curto e a forma mais proxima de atomico que
        # da pra ter sem lock. Se duas sessoes appendarem no mesmo instante e uma linha sair
        # cortada, o leitor (parse_spend_file) pula a linha ruim em vez de perder o mes.
        Add-Content -Path $spendFile -Value $linha -Encoding utf8
    }
} catch {
    # Silencio proposital -- ver comentario acima. A ausencia de telemetria nao pode custar
    # um commit.
}

# Auto-poda, produtor-side. Antes apagava TUDO que nao fosse latest.jsonl; agora preserva os
# marcadores por hash (d-*.jsonl) dentro da validade e apaga o resto.
#
# O que continua sendo apagado sem dó: <timestamp>.jsonl de wrappers antigos -- eram eles que
# acumulavam aos milhares e penduravam o hook em 148 s (2026-07-20).
#
# 24 h de validade para o d-*.jsonl: o hash ja garante que o conteudo revisado e o mesmo, entao
# o prazo nao serve pra "frescor" -- serve so pra impedir que o diretorio cresca sem fim. Um dia
# de trabalho gera dezenas de hashes distintos, nao milhares, e o hook nunca enumera este dir.
$limiteMarcador = (Get-Date).AddHours(-24)
Get-ChildItem $logDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -ne 'latest.jsonl' -and
        -not ($_.Name -like 'd-*.jsonl' -and $_.LastWriteTime -gt $limiteMarcador)
    } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# === OUTPUT ===
Write-Host "## Findings DeepSeek (cross-provider review)`n" -ForegroundColor Cyan
Write-Output $findings
