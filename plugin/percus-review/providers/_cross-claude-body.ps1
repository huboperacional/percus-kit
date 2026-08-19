#requires -Version 5.1
# Monta o corpo da requisicao do cross-claude.
#
# Vive FORA do wrapper de proposito: o teste precisa montar o corpo e inspecionar as chaves SEM
# disparar a chamada HTTP. Enquanto isto era inline no cross-claude.ps1, a unica forma de aferir
# era ler o fonte com regex -- e teste que le fonte foi exatamente o que deixou o `temperature`
# vivo no cross-claude.sh por um mes (ver #regra-duplicada-ps1-sh e provider-limites.tests.ps1).

function Get-EffortCapabilities {
    param([string]$TabelaPath)
    if (-not $TabelaPath) { $TabelaPath = Join-Path $PSScriptRoot "_effort-capabilities.json" }
    # Falha ALTO se a tabela sumir. O contrario -- assumir "sem restricao" e seguir -- devolveria
    # a perna vazia com HTTP 200 no modelo errado, que e a falha muda que este conserto existe
    # para matar. Tabela ausente e defeito de instalacao, nao caso de borda.
    if (-not (Test-Path $TabelaPath)) {
        throw "[cross-claude] tabela de effort ausente: $TabelaPath"
    }
    return (Get-Content $TabelaPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Resolve-EffortParaModelo {
    # Devolve o nivel a mandar, ou $null quando output_config nao deve entrar no corpo.
    param([string]$Model, [string]$Effort, $Caps)

    # Minusculas ANTES de qualquer coisa. O ValidateSet do wrapper e case-insensitive, entao
    # -Effort "HIGH" passa na validacao, e -contains tambem e case-insensitive, entao o nivel
    # seria aceito e enviado como "HIGH" -- que a API recusa: medido 2026-08-19, HTTP 400
    # "Input should be 'low', 'medium', 'high', 'xhigh' or 'max'". O .sh normaliza com tr; sem
    # esta linha os dois interpretadores divergiriam calados no MESMO env var.
    if ($Effort) { $Effort = $Effort.ToLowerInvariant() }

    # O NOME DO MODELO nao e normalizado, e isso e deliberado -- a review R11 ja sugeriu duas
    # vezes normalizar. Medido 2026-08-19: `CLAUDE-HAIKU-4-5` devolve HTTP 404 "model:
    # CLAUDE-HAIKU-4-5" -- a API recusa o proprio ID, nos DOIS interpretadores, antes de o effort
    # importar. Normalizar aqui mascararia um ID invalido e trocaria um 404 claro por um erro
    # adiante. Case do NIVEL se normaliza (a API aceitaria o modelo e recusaria o valor); case do
    # MODELO nao.

    if ($Effort -eq 'none') { return $null }

    if ($Caps.sem_effort -contains $Model) {
        [Console]::Error.WriteLine("[cross-claude] $Model nao aceita output_config.effort -- omitindo (medido 2026-08-19: HTTP 400 'This model does not support the effort parameter').")
        return $null
    }

    $niveis = $Caps.niveis_por_modelo.$Model
    if ($niveis -and ($niveis -notcontains $Effort)) {
        # A politica de rebaixamento e DADO, nao codigo: vive na tabela, lida igual pelos dois
        # wrappers. Escrita duas vezes, ela divergiria sem ninguem ver.
        $preferido = $Caps.fallback_nivel
        $alvo = if ($preferido -and ($niveis -contains $preferido)) { $preferido } else { @($niveis)[-1] }
        [Console]::Error.WriteLine("[cross-claude] $Model nao aceita effort='$Effort' (aceita: $($niveis -join ', ')) -- usando '$alvo'.")
        return $alvo
    }

    return $Effort
}

function Build-CrossClaudeBody {
    param(
        [Parameter(Mandatory=$true)][string]$Model,
        [Parameter(Mandatory=$true)][int]$MaxTokens,
        [string]$Effort = 'low',
        [string]$SystemPrompt = '',
        [string]$UserPrompt = '',
        $Caps
    )
    if (-not $Caps) { $Caps = Get-EffortCapabilities }

    $body = @{
        model      = $Model
        max_tokens = $MaxTokens
        # IMPORTANTE: system deve ser array de blocks com cache_control -- NAO string simples.
        # Anthropic API rejeita cache_control se system for string.
        system     = @(
            @{
                type          = "text"
                text          = $SystemPrompt
                cache_control = @{ type = "ephemeral" }
            }
        )
        messages   = @(
            @{ role = "user"; content = $UserPrompt }
        )
    }

    # NAO enviar temperature/top_p/top_k: a familia Opus 4.7+ / Sonnet 5 / Fable 5 removeu os
    # sampling params e retorna 400 se recebidos. Steering vai por prompt, nao por sampling.
    #
    # `thinking` fica FORA do corpo de proposito -- adaptativo e o default nos modelos 5, e
    # qualquer configuracao explicita de budget e 400.
    #
    # output_config.effort e CONDICIONAL desde 6.42.0: ver _effort-capabilities.json.
    $eff = Resolve-EffortParaModelo -Model $Model -Effort $Effort -Caps $Caps
    if ($eff) { $body.output_config = @{ effort = $eff } }

    return $body
}
