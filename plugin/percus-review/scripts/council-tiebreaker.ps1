#requires -Version 5.1
<#
.SYNOPSIS
  Vetor D (v6.14.0): Llama tie-breaker do conselho. Funcoes puras, dot-sourcaveis.

.DESCRIPTION
  Sem main body de proposito (dot-source seguro pra teste e pro council-orchestrator).

  Test-CouncilNeedsTieBreaker decide QUANDO chamar o desempate:
    - exatamente 2 providers responderam com sucesso (status "ok"), E
    - groq-llama NAO esta entre eles (senao a Llama ja votou), E
    - premise_validity divergente entre os 2 (valores distintos, >=1 nao-vazio).
  Conservador: sem sinal estruturado de divergencia -> nao chama (fail-safe, evita custo).

  Invoke-LlamaTieBreaker FAZ a chamada (groq-llama) e devolve o veredito como
  "tie-breaker fraco / convergencia 2/3 informal" — operador decide, nao e consenso.

  Fonte 100% ASCII (PS 5.1 le .ps1 sem BOM como cp1252).
#>

function Test-CouncilNeedsTieBreaker {
    param([array]$Responses)
    if (-not $Responses -or $Responses.Count -eq 0) { return $false }
    $ok = @($Responses | Where-Object { "$($_.status)" -eq "ok" })
    if ($ok.Count -ne 2) { return $false }
    $hasLlama = @($ok | Where-Object { "$($_.provider)" -eq "groq-llama" }).Count -gt 0
    if ($hasLlama) { return $false }
    $pvs = @($ok | ForEach-Object { "$($_.premise_validity)" })
    $distinct = @($pvs | Select-Object -Unique)
    if ($distinct.Count -lt 2) { return $false }                       # mesma pv -> sem divergencia
    if (@($pvs | Where-Object { $_ -ne "" }).Count -eq 0) { return $false }  # nenhum sinal real
    return $true
}

function Invoke-LlamaTieBreaker {
    param(
        [array]$Responses,
        [string]$UserPrompt,
        [string]$Wrapper,
        [string]$PsExe = "pwsh"
    )
    if (-not $Wrapper -or -not (Test-Path $Wrapper)) {
        return @{ status = "error"; error = "groq-llama wrapper ausente: $Wrapper"; content = "" }
    }
    $ok = @($Responses | Where-Object { "$($_.status)" -eq "ok" })
    $opinions = ""
    foreach ($r in $ok) {
        $opinions += "--- $($r.provider) (premise_validity=$($r.premise_validity)) ---`n$($r.content)`n`n"
    }
    $sys = "Voce e desempate (tie-breaker) tecnico. Dois consultores divergiram. Leia a pergunta original e as duas opinioes. Diga qual posicao e mais defensavel e por que, em no maximo 80 palavras. Comece a resposta com 'TIE-BREAK:'."
    $up  = "Pergunta original:`n$UserPrompt`n`nOpinioes divergentes:`n$opinions"
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmp, $up, [System.Text.Encoding]::UTF8)
        $raw = & $PsExe -NoProfile -ExecutionPolicy Bypass -File $Wrapper -PromptFile $tmp -SystemPrompt $sys -MaxTokens 256 2>&1
        $j = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($j -and $j.status -eq "ok" -and $j.content) {
            return @{ status = "ok"; provider = "groq-llama"; model = $j.model; content = $j.content }
        }
        return @{ status = "error"; error = "resposta nao parseavel do wrapper"; content = "" }
    } catch {
        return @{ status = "error"; error = $_.Exception.Message; content = "" }
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}
