#requires -Version 5.1
<#
.SYNOPSIS
  Classifica a resposta de um provider: util, vazia ou truncada. Compartilhado pelos tres.

.DESCRIPTION
  Existe por causa de um bug medido em 2026-07-31, no pre-mortem do plano 2.

  Os providers gravavam status="ok" sempre que a chamada HTTP dava certo, SEM NUNCA OLHAR O
  CONTEUDO. Numa mesma rodada de conselho:

    DeepSeek       completion_tokens=1024, reasoning_tokens=1024, content=""  -> reportado "ok"
    Cross-Claude   completion_tokens=1024, content cortado no meio da frase   -> reportado "ok"

  Ou seja: das tres pernas do conselho, uma nao respondeu e outra respondeu pela metade, e o
  orquestrador devolveu as duas como sucesso. Quem lesse o log concluiria "3 providers
  consultados" e trataria como consenso o que era uma perna so.

  A causa da primeira e o teto de 1024 tokens combinado com modelo de RACIOCINIO: em
  deepseek-v4-pro os reasoning_tokens contam DENTRO de completion_tokens, entao um prompt
  dificil faz o modelo gastar o teto inteiro pensando e devolver string vazia. Nao e erro de
  API -- do ponto de vista do HTTP, deu 200.

  Resposta vazia nao e resposta. Truncada nao e resposta inteira. As duas precisam ter nome
  proprio, e nenhuma pode se chamar "ok".

.PARAMETER Conteudo
  O texto devolvido pelo modelo.

.PARAMETER FinishReason
  finish_reason da API. "length" significa que bateu no teto -- sinal autoritativo, melhor do
  que adivinhar por tamanho.

.PARAMETER Usage
  Objeto usage da resposta, usado so pra montar a mensagem de diagnostico.

.OUTPUTS
  Hashtable @{ Status = "ok"|"empty"|"truncated"; Aviso = <string ou $null> }
#>

function Get-StatusResposta {
    param(
        [string]$Conteudo,
        [string]$FinishReason,
        $Usage
    )

    $comp = $null; $reas = $null
    if ($Usage) {
        $comp = $Usage.completion_tokens
        if ($Usage.completion_tokens_details) { $reas = $Usage.completion_tokens_details.reasoning_tokens }
    }
    $gasto = "completion=$comp reasoning=$reas finish_reason=$FinishReason"

    if ([string]::IsNullOrWhiteSpace($Conteudo)) {
        $motivo = if ("$reas" -and [int]"$reas" -gt 0) {
            "o modelo gastou o teto de tokens RACIOCINANDO e nao sobrou nada pra resposta -- suba -MaxTokens"
        } else {
            "o modelo devolveu conteudo vazio"
        }
        return @{
            Status = "empty"
            Aviso  = "resposta VAZIA: $motivo. ($gasto)"
        }
    }

    if ($FinishReason -ceq "length") {
        return @{
            Status = "truncated"
            Aviso  = "resposta CORTADA no teto de tokens -- a ultima frase nao terminou, e a conclusao pode nem ter sido escrita. Suba -MaxTokens. ($gasto)"
        }
    }

    return @{ Status = "ok"; Aviso = $null }
}
