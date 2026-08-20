#requires -Version 5.1
<#
.SYNOPSIS
  Provider wrapper: DeepSeek (deepseek-v4-flash) — single-shot consult.

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
  Default: 16000 -- dimensionado pra modelo de raciocinio (ver comentario no param block).

.EXAMPLE
  Get-Content prompt.txt | .\deepseek.ps1 > out.json
  .\deepseek.ps1 -PromptFile prompt.txt -Temperature 0.0
#>
[CmdletBinding()]
param(
    [string]$PromptFile,
    [string]$SystemPrompt = "Voce e consultor cross-provider Percus. Responda direto, sem floreio. Aponte riscos concretos.",
    [double]$Temperature = 0.2,
    # 16000, nao 8192. O deepseek-v4-flash RACIOCINA, e os reasoning_tokens contam DENTRO de
    # completion_tokens -- o teto cobre pensamento + resposta juntos. Medido 2026-08-16 com
    # prompt de design real em modo review: 6784, 7649 e 8192+ tokens gastos SO raciocinando,
    # em tres chamadas do MESMO prompt. Ou seja, 8192 nao era "pequeno demais" de forma limpa:
    # ficava DENTRO da faixa de variacao, e a mesma pergunta voltava ok, truncada ou vazia na
    # sorte. A 6.36.2 trocou o modelo de -pro pra -flash e nao reavaliou o teto ao lado.
    [int]$MaxTokens = 16000,
    # "low" por padrao -- ver o bloco de medicao junto do corpo do request. Nao e economia
    # apertando qualidade: no mesmo prompt o `low` devolveu MAIS texto que o default, porque o
    # orcamento parava de ser consumido pensando. Use "" pra omitir o campo.
    [ValidateSet("none","low","medium","high","")]
    [string]$ReasoningEffort = "low",
    [string]$Model = "deepseek-v4-flash",
    [string]$Endpoint = "https://api.deepseek.com/v1/chat/completions"
)
. (Join-Path $PSScriptRoot "_resposta.ps1")
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

$bodyObj = @{
    model       = $Model
    temperature = $Temperature
    max_tokens  = $MaxTokens
    messages    = @(
        @{ role = "system"; content = $SystemPrompt },
        @{ role = "user";   content = $userPrompt }
    )
}
# reasoning_effort (2026-08-19): o CONSERTO da perna que voltava vazia. Subir max_tokens NAO
# resolve -- ja foi feito (8192 -> 16000) e o sintoma voltou identico, porque o raciocinio se
# expande ate encher o teto que existir. Ver conhecimento/resolver/
# cross-claude-review-queima-16000-e-volta-vazio.md, que registra a mesma classe e proibe
# explicitamente subir o teto de novo.
#
# Medido no mesmo prompt de review real (11 KB), max_tokens=16000:
#   sem effort : completion 13805, raciocinio 12826 (80% do teto), 3284 chars de resposta
#   effort=low : completion  4395, raciocinio  2934 (18% do teto), 5140 chars de resposta
#   effort=med : completion 14207, raciocinio 12751 -- praticamente igual ao default
# `low` gasta 3,1x menos E devolve MAIS conteudo. O default queimava 80% do orcamento pensando,
# e era essa margem estreita que virava content vazio quando a variacao subia.
#
# Valores aceitos, testados contra a API real (a doc so documenta "high"): none, low, medium,
# high. String vazia OMITE o campo e restaura o comportamento anterior.
if ($ReasoningEffort) { $bodyObj.reasoning_effort = $ReasoningEffort }
$body = $bodyObj | ConvertTo-Json -Depth 10 -Compress

$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$headers = @{
    "Authorization" = "Bearer $env:DEEPSEEK_API_KEY"
    "Content-Type"  = "application/json; charset=utf-8"
}

$start = Get-Date
try {
    # 180s, nao 60s: medido 2026-08-16, chamadas que RESPONDERAM levaram 67s e 80s ja no teto
    # antigo de 8192. Com 16000 o tempo cresce junto. Subir o teto sem subir o timeout apenas
    # troca "resposta vazia" por "erro de rede".
    $resp = Invoke-RestMethod -Uri $Endpoint -Method Post -Headers $headers -Body $bodyBytes -TimeoutSec 180
    $content = $resp.choices[0].message.content
    $latency = [int]((Get-Date) - $start).TotalMilliseconds

    # HTTP 200 nao quer dizer que houve resposta. Ver _resposta.ps1 -- em 2026-07-31 este
    # provider devolveu content="" com status "ok" porque gastou os 1024 tokens raciocinando.
    $cls = Get-StatusResposta -Conteudo $content -FinishReason $resp.choices[0].finish_reason -Usage $resp.usage
    if ($cls.Aviso) { [Console]::Error.WriteLine("[deepseek] $($cls.Aviso)") }

    @{
        provider   = "deepseek"
        model      = $Model
        status     = $cls.Status
        content    = $content
        aviso      = $cls.Aviso
        latency_ms = $latency
        usage      = $resp.usage
    } | ConvertTo-Json -Depth 10 -Compress
    exit 0
} catch {
    @{
        provider   = "deepseek"
        model      = $Model
        status     = "error"
    # NAO usar apenas $_.Exception.Message: num erro HTTP ele e o cego "(413) Payload Too Large",
    # e o motivo REAL vem no corpo JSON da resposta, em $_.ErrorDetails.Message. Custou 39
    # ocorrencias de 413 diagnosticadas como "payload grande" quando o corpo dizia
    # "tokens per minute (TPM): Limit 8000" -- limite de TAXA, nao de tamanho (ver
    # #groq-llama-413-payload-too-large). Curiosidade que vale saber: a interpolacao "$_"
    # sozinha JA mostra o corpo (ErrorRecord.ToString() prefere ErrorDetails); e a forma
    # explicita $_.Exception.Message que descarta. O jeito que parece mais cuidadoso e o cego.
        error      = $(if ($_.ErrorDetails -and $_.ErrorDetails.Message) { "$($_.Exception.Message) :: $($_.ErrorDetails.Message)" } else { $_.Exception.Message })
        latency_ms = [int]((Get-Date) - $start).TotalMilliseconds
    } | ConvertTo-Json -Depth 10 -Compress
    exit 1
}
