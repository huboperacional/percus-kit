#requires -Version 5.1
<#
.SYNOPSIS
  Roda a suite Pester do kit em PARALELO, e opcionalmente so os testes afetados pelo diff.

.DESCRIPTION
  Medido em 2026-08-19, antes deste script: 184 s para 424 testes em 36 arquivos, sequencial.
  O tempo nao vinha de calculo -- vinha de PROCESSO: os arquivos mais caros disparam gate, git e
  pwsh filho, e no Windows cada spawn custa ~0,5-1 s. Dois arquivos sozinhos eram 37% do total
  (gate-conhecimento 37,4 s e external-action-guard 24,3 s).

  Isso importa porque o overhead do ciclo era FIXO: um conserto de um caractere pagava a mesma
  suite que um refactor de 500 linhas. E por isso que "coisas simples ficaram lentas" -- o
  denominador encolheu e o numerador nao.

  Duas alavancas, independentes:

    -Afetados   roda so os arquivos de teste relacionados ao que mudou (git diff HEAD)
    (padrao)    roda tudo, mas repartido em N processos paralelos

  O Pester 5 nao paraleliza sozinho. A repartição aqui e por ARQUIVO, nao por teste: arquivo e a
  unidade que o Pester isola (BeforeAll/AfterAll sao por arquivo), entao dividir por arquivo nao
  quebra fixture nenhuma. Dividir por teste quebraria.

.PARAMETER Afetados
  Roda so os testes relacionados aos arquivos alterados em `git diff HEAD`. Se o diff nao casar
  com teste nenhum, cai pra suite inteira -- deixar de rodar por nao ter sabido mapear e o tipo
  de otimizacao que esconde regressao.

.PARAMETER Processos
  Quantos processos paralelos. Default: min(4, nucleos-2), no minimo 1.

.PARAMETER Caminhos
  Diretorios de teste. Default: os dois do kit.

.EXAMPLE
  pwsh -File scripts/rodar-suite.ps1
  pwsh -File scripts/rodar-suite.ps1 -Afetados
  pwsh -File scripts/rodar-suite.ps1 -Processos 8
#>
[CmdletBinding()]
param(
    [switch]$Afetados,
    [int]$Processos = 0,
    [string[]]$Caminhos = @("plugin/percus-review/tests", "tools/__tests__")
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$raiz = Split-Path -Parent $PSScriptRoot
Push-Location $raiz
try {
    $arquivos = @()
    foreach ($c in $Caminhos) {
        $p = Join-Path $raiz $c
        if (Test-Path $p) {
            $arquivos += (Get-ChildItem $p -Filter "*.tests.ps1" -File -Recurse | ForEach-Object { $_.FullName })
        }
    }
    if ($arquivos.Count -eq 0) { Write-Host "[rodar-suite] nenhum arquivo de teste encontrado."; exit 0 }

    if ($Afetados) {
        # Mapeamento por NOME DE BASE, nos dois sentidos:
        #   1. teste cujo nome contem o nome do arquivo alterado (deepseek-review.ps1 ->
        #      *deepseek-review*.tests.ps1);
        #   2. teste cujo CONTEUDO menciona o nome do arquivo alterado (pega o caso em que o
        #      teste se chama outra coisa mas exercita aquele script).
        # O segundo sentido existe porque o primeiro sozinho e otimista: a maioria dos testes
        # deste kit nao se chama como o arquivo que testa.
        $mudados = @(& git diff HEAD --name-only 2>$null | Where-Object { $_ })
        if ($mudados.Count -eq 0) {
            Write-Host "[rodar-suite] git diff HEAD vazio -- nada mudou, rodando a suite inteira."
        } else {
            $bases = $mudados | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) } |
                     Where-Object { $_ } | Sort-Object -Unique
            $sel = New-Object System.Collections.Generic.HashSet[string]
            foreach ($a in $arquivos) {
                $nome = Split-Path $a -Leaf
                $texto = $null
                foreach ($b in $bases) {
                    # .Contains e nao -like: o -like trata [ ] * ? como metacaractere, entao um
                    # arquivo chamado "foo[1].ps1" viraria classe de caracteres e nao casaria com
                    # o teste que o exercita. Casamento aqui e literal, sempre. (R11, 2026-08-19)
                    if ($nome.Contains($b)) { [void]$sel.Add($a); break }
                    if ($null -eq $texto) { $texto = Get-Content $a -Raw -ErrorAction SilentlyContinue }
                    if ($texto -and $texto.Contains($b)) { [void]$sel.Add($a); break }
                }
            }
            if ($sel.Count -eq 0) {
                # Fail-safe deliberado: nao souber mapear NAO pode virar "nao rodou nada".
                Write-Host "[rodar-suite] nenhum teste casou com o diff -- rodando a suite inteira por seguranca."
            } else {
                $arquivos = @($sel)
                Write-Host "[rodar-suite] modo -Afetados: $($arquivos.Count) de $((Get-ChildItem (Join-Path $raiz $Caminhos[0]) -Filter '*.tests.ps1').Count) arquivos"
            }
        }
    }

    if ($Processos -le 0) {
        $nucleos = [Environment]::ProcessorCount
        $Processos = [Math]::Max(1, [Math]::Min(4, $nucleos - 2))
    }
    $Processos = [Math]::Min($Processos, $arquivos.Count)

    # Distribuicao round-robin, nao em blocos contiguos: os arquivos caros estao agrupados por
    # nome (gate-*, external-*), e fatiar em blocos jogaria todos eles no mesmo processo --
    # o paralelismo existiria no papel e o tempo total continuaria sendo o do pior bucket.
    $baldes = @{}
    for ($i = 0; $i -lt $Processos; $i++) { $baldes[$i] = New-Object System.Collections.ArrayList }
    for ($i = 0; $i -lt $arquivos.Count; $i++) { [void]$baldes[$i % $Processos].Add($arquivos[$i]) }

    Write-Host "[rodar-suite] $($arquivos.Count) arquivos em $Processos processo(s)..."
    $inicio = Get-Date

    # PROCESSOS de verdade (Start-Process pwsh), nao Start-Job. Start-Job roda em runspace dentro
    # da MESMA sessao, e alguns testes deste kit invocam ferramenta externa que tenta interagir
    # (npm, git). Na primeira versao deste script isso travou a suite inteira com
    # "one or more jobs are blocked waiting for user interaction" -- e travou em SILENCIO, sem
    # nenhum teste falhar. Processo separado com stdin fechado nao tem esse problema, e e o mesmo
    # isolamento que a execucao sequencial ja tinha.
    $saidas = @()
    $procs  = @()
    for ($i = 0; $i -lt $Processos; $i++) {
        $lista = @($baldes[$i])
        if ($lista.Count -eq 0) { continue }
        $arqJson = [IO.Path]::GetTempFileName()
        $outJson = [IO.Path]::GetTempFileName()
        $saidas += $outJson
        ($lista | ConvertTo-Json -Compress) | Set-Content -Path $arqJson -Encoding utf8
        $script = @"
`$ErrorActionPreference = 'Continue'
`$arqs = Get-Content -Raw '$arqJson' | ConvertFrom-Json
`$c = New-PesterConfiguration
`$c.Run.Path = @(`$arqs)
`$c.Run.PassThru = `$true
`$c.Output.Verbosity = 'None'
`$r = Invoke-Pester -Configuration `$c
[pscustomobject]@{
    Total  = `$r.TotalCount
    Passou = `$r.PassedCount
    Falhou = `$r.FailedCount
    Nomes  = @(`$r.Failed | ForEach-Object { `$_.ExpandedPath })
} | ConvertTo-Json -Depth 5 | Set-Content -Path '$outJson' -Encoding utf8
"@
        $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
        $procs += Start-Process -FilePath "pwsh" -ArgumentList @("-NoProfile","-NonInteractive","-EncodedCommand",$b64) -PassThru -WindowStyle Hidden
    }
    $procs | ForEach-Object { $_.WaitForExit() }

    $res = @()
    foreach ($o in $saidas) {
        if (Test-Path $o) {
            $conteudo = Get-Content -Raw $o -ErrorAction SilentlyContinue
            if ($conteudo) { $res += ($conteudo | ConvertFrom-Json) }
            Remove-Item $o -Force -ErrorAction SilentlyContinue
        }
    }
    if ($res.Count -eq 0) {
        # Zero resultado nao pode ser lido como zero falha: e o modo de falhar calado que este
        # script inteiro existe pra nao criar.
        Write-Host "[rodar-suite] ERRO: nenhum processo devolveu resultado -- rode sequencial pra ver o motivo."
        exit 1
    }

    $total  = ($res | Measure-Object -Property Total  -Sum).Sum
    $passou = ($res | Measure-Object -Property Passou -Sum).Sum
    $falhou = ($res | Measure-Object -Property Falhou -Sum).Sum
    $seg    = [Math]::Round(((Get-Date) - $inicio).TotalSeconds, 1)

    Write-Host ""
    Write-Host "[rodar-suite] $passou/$total em ${seg}s ($Processos processos)"
    if ($falhou -gt 0) {
        Write-Host "[rodar-suite] FALHAS ($falhou):"
        foreach ($r in $res) { foreach ($n in $r.Nomes) { Write-Host "  - $n" } }
        exit 1
    }
    exit 0
} finally { Pop-Location }
