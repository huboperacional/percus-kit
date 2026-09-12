#requires -Version 5.1
# Prova que o resumo do fact-check (F3) nao esconde findings NAO VERIFICADOS.
#
# Bug medido em 2026-09-12, lido errado por DUAS sessoes diferentes no mesmo dia: a API do
# fact-check falhou inteira (`400 Bad Request: Your credit balance is too low`), os 4 findings
# sairam todos como `unverified`, e a linha de resumo imprimiu:
#
#   [percus-review-auto] fact-check: total=4 confirmado=0 infundado=0 parcial=0
#
# Isso se le como "review limpo" -- nenhum confirmado, nenhum infundado. Mas o que aconteceu foi
# o oposto: NADA foi verificado. O campo `findings_unverified` ja existia no JSON do fact-check e
# simplesmente nao entrava no resumo. Ausencia de refutacao nao e confirmacao.
#
# A funcao e extraida do script por marcador (e nao por numero de linha, que envelhece) e roda de
# verdade contra um fact-check falso -- e comportamento, nao inspecao de forma.

Describe "Invoke-FactCheck -- o resumo conta o que NAO foi verificado" {

    BeforeAll {
        $script:origem = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." ".." "scripts" "percus-review-auto.ps1")).Path

        # Recorta so a funcao: do 'function Invoke-FactCheck {' ate o '}' na coluna 0.
        $linhas = Get-Content $script:origem -Encoding UTF8
        $ini = ($linhas | Select-String -Pattern '^function Invoke-FactCheck \{' | Select-Object -First 1).LineNumber
        if (-not $ini) { throw "nao achei 'function Invoke-FactCheck {' em $($script:origem) -- o recorte do teste quebrou" }
        $fim = $null
        for ($i = $ini; $i -lt $linhas.Count; $i++) {
            if ($linhas[$i] -match '^\}') { $fim = $i + 1; break }
        }
        if (-not $fim) { throw "nao achei o fecho da funcao Invoke-FactCheck" }
        $script:corpoFuncao = ($linhas[($ini - 1)..($fim - 1)] -join "`n")

        function Invoke-ComFactCheckFalso {
            param([string]$JsonDoFactCheck)
            $dir = Join-Path ([IO.Path]::GetTempPath()) "f3-resumo-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $enc = New-Object System.Text.UTF8Encoding($true)

            # fact-check falso: ignora os argumentos e devolve o JSON pedido
            $falso = Join-Path $dir "fact-check.ps1"
            [System.IO.File]::WriteAllText($falso, @"
[CmdletBinding()]
param([string]`$FindingsFile, [Parameter(ValueFromRemainingArguments = `$true)] `$Resto)
Write-Output '$JsonDoFactCheck'
"@, $enc)

            # runner: define o que a funcao usa do escopo pai e a chama
            $runner = Join-Path $dir "runner.ps1"
            [System.IO.File]::WriteAllText($runner, @"
`$factCheckScript = '$($falso -replace "'","''")'
`$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
`$NoFactCheck = `$false

$($script:corpoFuncao)

`$saida = Invoke-FactCheck -ReviewOutput 'findings originais'
Write-Output `$saida
"@, $enc)

            $errFile = Join-Path $dir "err.txt"
            $out = & pwsh -NoProfile -File $runner 2>$errFile
            $err = if (Test-Path $errFile) { Get-Content $errFile -Raw } else { "" }
            return [pscustomobject]@{ Out = ($out -join "`n"); Err = $err }
        }

        # Os numeros REAIS da rodada de 2026-09-12, nao valores inventados.
        $script:tudoNaoVerificado = '{"findings_total":4,"findings_confirmed":0,"findings_infundado":0,"findings_parcial":0,"findings_unverified":4,"filtered_output":"os 4 findings"}'
    }

    It "recorta a funcao do script real (se isto falhar, o teste nao esta testando nada)" {
        $script:corpoFuncao | Should -Match 'function Invoke-FactCheck'
        $script:corpoFuncao | Should -Match 'findings_total'
    }

    Context "a API caiu: 4 de 4 sem verificacao" {
        It "o resumo mostra 'nao-verificado=4' -- nao so confirmado=0" {
            $r = Invoke-ComFactCheckFalso -JsonDoFactCheck $script:tudoNaoVerificado
            $r.Err | Should -Match 'nao-verificado=4' -Because "o campo existe no JSON; omiti-lo faz 'nada verificado' parecer 'nada encontrado':`n$($r.Err)"
        }

        It "e diz em voz alta que NENHUM finding foi verificado" {
            $r = Invoke-ComFactCheckFalso -JsonDoFactCheck $script:tudoNaoVerificado
            $r.Err | Should -Match 'NENHUM finding foi verificado'
            $r.Err | Should -Match "(?i)n[aã]o . 'review limpo'|NAO e 'review limpo'"
        }

        It "ainda assim devolve os findings (falha de verificacao nao pode engolir o review)" {
            $r = Invoke-ComFactCheckFalso -JsonDoFactCheck $script:tudoNaoVerificado
            $r.Out | Should -Match 'os 4 findings'
        }
    }

    Context "verificacao PARCIAL: alguns ficaram de fora" {
        It "2 de 5 sem verificacao -> avisa, sem dizer que nenhum foi verificado" {
            $j = '{"findings_total":5,"findings_confirmed":3,"findings_infundado":0,"findings_parcial":0,"findings_unverified":2,"filtered_output":"5 findings"}'
            $r = Invoke-ComFactCheckFalso -JsonDoFactCheck $j
            $r.Err | Should -Match 'nao-verificado=2'
            $r.Err | Should -Match '2 de 5'
            $r.Err | Should -Not -Match 'NENHUM finding foi verificado'
        }
    }

    Context "rodada saudavel: nada de alarme" {
        It "tudo verificado -> resumo traz nao-verificado=0 e nenhum aviso" {
            $j = '{"findings_total":3,"findings_confirmed":2,"findings_infundado":1,"findings_parcial":0,"findings_unverified":0,"filtered_output":"2 findings"}'
            $r = Invoke-ComFactCheckFalso -JsonDoFactCheck $j
            $r.Err | Should -Match 'nao-verificado=0'
            $r.Err | Should -Not -Match 'NENHUM finding foi verificado'
            $r.Err | Should -Not -Match 'ficaram SEM verificacao'
        }
    }
}
