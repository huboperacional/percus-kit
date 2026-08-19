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
  Default: claude-sonnet-5 (orchestrator vai passar conforme router F.2).

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
    # 16000 e nao 4096: em Sonnet 5 / Opus 5 o thinking vem LIGADO por padrao (omitir o campo
    # roda adaptive, ao contrario de Sonnet 4.6 / Opus 4.7), e max_tokens limita pensamento +
    # resposta JUNTOS. Manter 4096 aqui repetiria o defeito de #resposta-vazia-teto-de-tokens
    # um degrau acima: HTTP 200, content vazio, e o orquestrador contando como perna respondida.
    # Vale para os tres modos, inclusive consult/Haiku 4.5 (teto de saida do Haiku e 64K, entao
    # 16000 cabe). Teto NAO e consumo: subir o limite nao encarece resposta curta, so evita que
    # ela seja cortada -- por isso um numero unico em vez de um teto por modo.
    [int]$MaxTokens = 16000,
    # 🔴 SEM ISTO A PERNA VOLTA VAZIA. Medido em 2026-08-17 com o mesmo prompt,
    # tres vezes:
    #   sem controle        -> output_tokens=16000, stop_reason=max_tokens, 0 char de texto, 153s
    #   effort=low          -> output_tokens=3719,  stop_reason=end_turn,   1378 chars,       47s
    # Com thinking adaptativo ligado por padrao nos modelos 5, o raciocinio se
    # expande ate encher o `max_tokens` -- que cobre pensamento + resposta -- e
    # nao sobra orcamento pra escrever. Subir o teto so aumenta o tamanho do
    # pensamento: foi o que a 6.36.4 fez (8192->16000) e o sintoma voltou igual.
    #
    # ⚠️ E o controle NAO e `thinking.budget_tokens`: nos modelos 5 esse campo foi
    # REMOVIDO e a API responde 400 ("thinking.type.enabled is not supported for
    # this model"). Medido na mesma bateria. O controle vivo e `output_config.effort`.
    # "none" existe para DESLIGAR o parametro. Sem ele nao havia como chamar um modelo que
    # nao aceita effort, e o modo consult (Haiku 4.5) devolvia 400 em toda chamada.
    # O normal e nao precisar: o wrapper ja omite sozinho pelos dados de
    # _effort-capabilities.json. "none" e para o caso em que quem chama sabe mais.
    [ValidateSet("low","medium","high","xhigh","max","none")]
    [string]$Effort = "low",
    [string]$Model = "claude-sonnet-5",
    [string]$Endpoint = "https://api.anthropic.com/v1/messages",
    [ValidateSet("consult","review","pre-mortem","analyze")]
    [string]$Mode = "consult"
)
# ANTES dos dot-source, nao depois: se um deles faltar no pacote instalado, com o default
# Continue o erro e nao-terminante e o script segue ate estourar la na frente com mensagem que
# nao aponta para a causa. Falha alta e imediata no carregamento e o que se quer.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_resposta.ps1")
. (Join-Path $PSScriptRoot "_cross-claude-body.ps1")
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
    $baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path }
    $promptPath = Join-Path $baseDir "system-prompt-$modeFile.md"
    if (Test-Path $promptPath) {
        $raw = Get-Content $promptPath -Raw
        # Strip YAML frontmatter (---...---)
        $SystemPrompt = $raw -replace '^---\r?\n[\s\S]*?\r?\n---(\r?\n|$)', ''
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

# O corpo e montado por Build-CrossClaudeBody (_cross-claude-body.ps1), fora deste arquivo, para
# que o teste possa inspecionar as chaves sem chamar a API. As regras de system/cache_control,
# sampling param e output_config.effort estao documentadas la e na tabela _effort-capabilities.json.
$bodyObj = Build-CrossClaudeBody -Model $Model -MaxTokens $MaxTokens -Effort $Effort `
                                 -SystemPrompt $SystemPrompt -UserPrompt $userPrompt
$body = $bodyObj | ConvertTo-Json -Depth 10 -Compress

$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$headers = @{
    "x-api-key"         = $env:ANTHROPIC_API_KEY
    "anthropic-version" = "2023-06-01"
    "content-type"      = "application/json"
}

$start = Get-Date
try {
    # 180s, nao 60s: com thinking ligado e teto 16000 a chamada demora de verdade -- medido em
    # 2026-08-16, resposta LEGITIMA levou 67s e 80s no teto antigo, e o tempo cresce junto com o
    # teto. 60s cortava resposta boa no meio e o erro chegava como falha de rede, escondendo a
    # causa. A 6.36.3 ja tinha registrado este 60s hardcoded como limite conhecido.
    $resp = Invoke-RestMethod -Uri $Endpoint -Method Post -Headers $headers -Body $bodyBytes -TimeoutSec 180
    # NAO use content[0]: com o modelo em Sonnet 5 / Opus 5 o thinking vem LIGADO por padrao (a
    # mesma razao que forcou MaxTokens=16000 la em cima), e a resposta chega em DOIS blocos --
    # content[0].type='thinking' (sem campo .text) e content[1].type='text'. Medido em 2026-08-15
    # chamando a API crua. Pegar o indice 0 devolvia $null e o provider reportava status='empty'
    # com stop_reason='end_turn' e 5015 tokens gastos: a perna respondia e o parser jogava fora.
    # Passou despercebido porque prompt trivial ("responda PONG") nao dispara bloco de thinking --
    # o teste de fumaca via verde enquanto todo review real voltava vazio.
    $content = ($resp.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
    $latency = [int]((Get-Date) - $start).TotalMilliseconds

    # A API da Anthropic chama de stop_reason, e "max_tokens" e o equivalente de "length".
    # Traduzido aqui pra o classificador ser um so pros tres providers. Medido em 2026-07-31:
    # esta perna voltou CORTADA no meio da frase e mesmo assim foi reportada como "ok".
    $finish = if ($resp.stop_reason -ceq "max_tokens") { "length" } else { "$($resp.stop_reason)" }
    $cls = Get-StatusResposta -Conteudo $content -FinishReason $finish -Usage $resp.usage
    if ($cls.Aviso) { [Console]::Error.WriteLine("[cross-claude] $($cls.Aviso)") }

    @{
        provider   = "cross-claude"
        model      = $resp.model
        status     = $cls.Status
        aviso      = $cls.Aviso
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
    # Invoke-RestMethod poe o CORPO da resposta de erro da API em $_.ErrorDetails.Message
    # (ex.: '{"error":{"message":"temperature: Extra inputs are not permitted"}}'); sozinho,
    # $_.Exception.Message e' so o generico "(400) Bad Request". Preferir o corpo quando existir.
    $apiBody = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $null }
    $errMsg = if ($apiBody) { "$($_.Exception.Message) :: $apiBody" } else { $_.Exception.Message }
    @{
        provider   = "cross-claude"
        model      = $Model
        status     = "error"
        error      = $errMsg
        latency_ms = [int]((Get-Date) - $start).TotalMilliseconds
    } | ConvertTo-Json -Depth 10 -Compress
    exit 1
}
