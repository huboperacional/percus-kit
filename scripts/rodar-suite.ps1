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
    [string[]]$Caminhos = @("plugin/percus-review/tests", "tools/__tests__"),
    [switch]$MostrarPulados,
    [string[]]$ManterEnv = @(),
    # Fase 6: por padrao a suite pula testes marcados com a tag Pester "Lento" (a matriz cara
    # do external-action-guard, que roda o dispatcher real em 3 runtimes -- 652 testes,
    # ~600s sozinha). -IncluirLentos roda tudo.
    [switch]$IncluirLentos
)
# Injecao de teste (rodar-suite.tests.ps1), NAO um parametro do script: duas env vars, nao um
# switch de linha de comando -- parametro publico e um canal que um operador digitaria por engano
# e silenciaria o `git diff` real. E DUAS vars, nao uma: uma env var isolada (RODARSUITE_TESTE_MUDADOS)
# poderia vazar sozinha de um dotfile/CI e -Afetados passaria a usar diff falso sem ninguem notar --
# exatamente o "some quando alguem mexe no guard" que a Fase 6 existe pra evitar. Com o portao
# duplo, as DUAS teriam que vazar juntas, o que nao acontece por acidente. (Achados R11/DeepSeek.)
$script:TesteMudadosOverride = $null
if ($env:RODARSUITE_TESTE_GATE -eq '1' -and $env:RODARSUITE_TESTE_MUDADOS) {
    $script:TesteMudadosOverride = @($env:RODARSUITE_TESTE_MUDADOS -split ';' | Where-Object { $_ })
}
# Le uma vez e apaga do processo -- um filho (git, pwsh de teste chamado la na frente) nao pode
# herdar nem re-ler estas duas. Reduz ainda mais a janela de vazamento. Achado R11/DeepSeek.
Remove-Item Env:RODARSUITE_TESTE_GATE -ErrorAction SilentlyContinue
Remove-Item Env:RODARSUITE_TESTE_MUDADOS -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# `pwsh -File rodar-suite.ps1 -ManterEnv A,B` chega como UM elemento so ("A,B"), nao dois --
# medido 2026-09-15 (revisao da Fase 2 T13). Aceita tambem essa forma: valor unico com virgula
# vira split por virgula + trim. Lista ja com 2+ elementos (`-ManterEnv A,B` via `&`/`-Command`)
# passa direto.
if ($ManterEnv.Count -eq 1 -and $ManterEnv[0] -match ',') {
    $ManterEnv = @($ManterEnv[0].Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

$raiz = Split-Path -Parent $PSScriptRoot
Push-Location $raiz
try {
    $arquivos = @()
    foreach ($c in $Caminhos) {
        if ([IO.Path]::IsPathRooted($c)) { $p = $c } else { $p = Join-Path $raiz $c }
        if (Test-Path $p) {
            $arquivos += (Get-ChildItem $p -Filter "*.tests.ps1" -File -Recurse | ForEach-Object { $_.FullName })
        }
    }
    if ($arquivos.Count -eq 0) { Write-Host "[rodar-suite] nenhum arquivo de teste encontrado."; exit 0 }
    # Guardado ANTES do bloco -Afetados sobrescrever $arquivos com o subconjunto selecionado --
    # reusar esta contagem evita recalcular com Get-ChildItem de so $Caminhos[0] (o default tem
    # DOIS caminhos; recontar so o primeiro subestimava o M de "N de M arquivos". Achado R11/DeepSeek).
    $totalArquivosAntesDeAfetados = $arquivos.Count

    # Fase 6: -IncluirLentos sempre inclui. Fora isso, -Afetados com diff tocando o guard
    # tambem inclui -- a matriz nunca pode sumir justamente quando alguem mexe no guard, mesmo
    # sem passar -IncluirLentos explicitamente. So o guard usa a tag Lento hoje, entao a
    # decisao e global (nao por-arquivo): se qualquer arquivo mudado bate um destes padroes,
    # a suite inteira roda com Lento incluido nesta chamada.
    $padroesGuard = @('external-action-guard\.', 'percus-dispatch-pre\.', 'gatilhos-pre\.txt', 'hooks-manifest\.json')
    $incluirLentoEfetivo = [bool]$IncluirLentos

    if ($Afetados) {
        # Mapeamento por NOME DE BASE, nos dois sentidos:
        #   1. teste cujo nome contem o nome do arquivo alterado (deepseek-review.ps1 ->
        #      *deepseek-review*.tests.ps1);
        #   2. teste cujo CONTEUDO menciona o nome do arquivo alterado (pega o caso em que o
        #      teste se chama outra coisa mas exercita aquele script).
        # O segundo sentido existe porque o primeiro sozinho e otimista: a maioria dos testes
        # deste kit nao se chama como o arquivo que testa.
        if ($null -ne $script:TesteMudadosOverride) {
            # Bypass de teste tornado BARULHENTO de proposito: um portao duplo que vaza em silencio
            # nao e portao, e "log". Achado R11/DeepSeek.
            Write-Host "[rodar-suite] OVERRIDE DE TESTE ATIVO: diff simulado ($($script:TesteMudadosOverride -join ';'))"
            $mudados = @($script:TesteMudadosOverride)
        } else {
            $mudados = @(& git diff HEAD --name-only 2>$null | Where-Object { $_ })
        }
        foreach ($m in $mudados) {
            $nomeM = Split-Path $m -Leaf
            foreach ($p in $padroesGuard) {
                if ($nomeM -match $p) { $incluirLentoEfetivo = $true; break }
            }
            if ($incluirLentoEfetivo) { break }
        }
        # "Suite inteira" nos dois fallbacks abaixo (diff vazio / nada casou) e verdade so pra
        # arquivos -- por padrao ainda exclui a tag Lento. Sem esta ressalva a mensagem mente por
        # omissao: o comentario deste arquivo diz "a matriz nunca pode sumir", e sumir calado
        # atras de "suite inteira" e exatamente isso. Achado R11/DeepSeek.
        $ressalvaLento = $(if ($incluirLentoEfetivo) { "" } else { " (tag Lento ainda excluida -- use -IncluirLentos)" })
        if ($mudados.Count -eq 0) {
            Write-Host "[rodar-suite] git diff HEAD vazio -- nada mudou, rodando a suite inteira.$ressalvaLento"
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
                Write-Host "[rodar-suite] nenhum teste casou com o diff -- rodando a suite inteira por seguranca.$ressalvaLento"
            } else {
                $arquivos = @($sel)
                Write-Host "[rodar-suite] modo -Afetados: $($arquivos.Count) de $totalArquivosAntesDeAfetados arquivos"
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
    # Todo arquivo temporario criado aqui embaixo entra nesta lista e sai no finally logo
    # depois da coleta de resultados -- inclusive no caminho de excecao (JSON de um filho
    # que nao parseia, WaitForExit que estoura), pra nao empilhar lixo em %TEMP% a cada
    # execucao que aborta no meio.
    $tempFiles = New-Object System.Collections.ArrayList

    $manterJson = [IO.Path]::GetTempFileName()
    [void]$tempFiles.Add($manterJson)
    ($ManterEnv | ConvertTo-Json -Compress) | Set-Content -Path $manterJson -Encoding utf8

    $saidas       = @()
    $procs        = @()
    $baldesPorSaida = @()
    # Literal `$true`/`$false` pronto pra ir dentro do here-string do filho (que interpola
    # variavel do processo PAI sem escape) -- [bool] normal interpolaria como "True"/"False",
    # que nao e sintaxe valida de expressao PowerShell.
    $incluirLentoLiteral = if ($incluirLentoEfetivo) { '$true' } else { '$false' }
    try {
    for ($i = 0; $i -lt $Processos; $i++) {
        $lista = @($baldes[$i])
        if ($lista.Count -eq 0) { continue }
        $arqJson = [IO.Path]::GetTempFileName()
        $outJson = [IO.Path]::GetTempFileName()
        [void]$tempFiles.Add($arqJson)
        [void]$tempFiles.Add($outJson)
        $saidas += $outJson
        $baldesPorSaida += ,@($lista | ForEach-Object { Split-Path $_ -Leaf })
        ($lista | ConvertTo-Json -Compress) | Set-Content -Path $arqJson -Encoding utf8
        $script = @"
`$ErrorActionPreference = 'Continue'
`$manter = @(Get-Content -Raw '$manterJson' | ConvertFrom-Json)
`$removidos = @()
foreach (`$item in (Get-ChildItem Env:PERCUS_* -ErrorAction SilentlyContinue)) {
    if (`$manter -notcontains `$item.Name) {
        Remove-Item "Env:`$(`$item.Name)"
        `$removidos += `$item.Name
    }
}
`$arqs = Get-Content -Raw '$arqJson' | ConvertFrom-Json
`$excluidoTag = 0
# Rodada 2 (revisao suite-review.md 2026-09-16): a versao anterior fazia um grep ANTES de pagar
# a passada de discovery, pra pular o custo quando nenhum arquivo do lote tinha a tag -- o
# padrao usado era LARGO por design (`-Tag\b[^\r\n]*Lento`, nao so `-Tag "Lento"` isolado), mas
# ainda assim regex por LINHA: um `-Tag @(` multi-linha (tag numa linha, "Lento" na proxima) nao
# batia em nenhum dos dois padroes -- a passada de discovery nao rodava, `excluidoTag` ficava 0
# e o resumo mentia calado ("pulados por tag Lento: 0" com o Filter.ExcludeTag excluindo de
# verdade por baixo). ESCOLHA: tirar o grep (largo ou estreito, tanto faz -- o problema e ser
# TEXTUAL) e SEMPRE rodar Run.SkipRun quando a tag pode estar excluida -- a contagem fica 100%
# estrutural (Tag do Test/Block, nunca texto), sem heuristica pra divergir do que o Pester
# realmente filtra. Custo medido: discovery de ~700 testes leva <1s; a suite inteira do kit (76
# arquivos, 4 processos) ja media 681s com este mesmo esquema -- a segunda passada e uma fracao
# pequena do total.
if (-not $incluirLentoLiteral) {
    # Passada de SO descoberta (Run.SkipRun) para contar quantos testes ficam de fora por causa
    # da tag Lento. MEDIDO (nao suposto): Filter.ExcludeTag no Pester 5 NAO tira o teste da
    # contagem -- ele continua em `$r.TotalCount E em `$r.NotRunCount, so nao roda. Por isso
    # NaoRodou abaixo subtrai `$excluidoTag de NotRunCount (senao um arquivo tagueado contaria
    # como "nao rodado" duas vezes: uma aqui, outra na linha de baixo).
    `$cd = New-PesterConfiguration
    `$cd.Run.Path = @(`$arqs)
    `$cd.Run.PassThru = `$true
    `$cd.Run.SkipRun = `$true
    `$cd.Output.Verbosity = 'None'
    `$rd = Invoke-Pester -Configuration `$cd
    # `$_.Tag (do proprio It) nao herda a tag do Describe -- o Pester so guarda a tag do bloco em
    # `$_.Block.Tag. Sobe a cadeia de blocos (Describe/Context aninhado) igual o motor faz para o
    # ExcludeTag funcionar de verdade -- medido: contar so `$_.Tag dava 0 mesmo com a tag no Describe.
    `$excluidoTag = 0
    foreach (`$teste in `$rd.Tests) {
        # Tag no proprio It (`It "x" -Tag "Lento" { ... }`) tambem conta -- ExcludeTag do Pester
        # exclui os dois casos na execucao real; contar so a cadeia de blocos deixava esse caso
        # com ExcluidoTag=0 mentiroso. Achado R11/DeepSeek.
        `$achouLento = (`$teste.Tag -and `$teste.Tag -contains 'Lento')
        `$blocoAtual = `$teste.Block
        while ((-not `$achouLento) -and `$blocoAtual) {
            if (`$blocoAtual.Tag -and `$blocoAtual.Tag -contains 'Lento') { `$achouLento = `$true; break }
            `$blocoAtual = `$blocoAtual.Parent
        }
        if (`$achouLento) { `$excluidoTag++ }
    }
}
`$c = New-PesterConfiguration
`$c.Run.Path = @(`$arqs)
`$c.Run.PassThru = `$true
`$c.Output.Verbosity = 'None'
if (-not $incluirLentoLiteral) { `$c.Filter.ExcludeTag = @('Lento') }
`$r = Invoke-Pester -Configuration `$c
[pscustomobject]@{
    Total        = `$r.TotalCount
    Passou       = `$r.PassedCount
    Falhou       = `$r.FailedCount
    Pulou        = `$r.SkippedCount
    NaoRodou     = [Math]::Max(0, (`$r.NotRunCount - `$excluidoTag))
    ExcluidoTag  = `$excluidoTag
    Nomes        = @(`$r.Failed | ForEach-Object { `$_.ExpandedPath })
    NomesPulados = @(`$r.Skipped | ForEach-Object { `$_.ExpandedPath })
    EnvRemovido  = @(`$removidos)
} | ConvertTo-Json -Depth 5 | Set-Content -Path '$outJson' -Encoding utf8
"@
        $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
        $procs += Start-Process -FilePath "pwsh" -ArgumentList @("-NoProfile","-NonInteractive","-EncodedCommand",$b64) -PassThru -WindowStyle Hidden
    }
    $procs | ForEach-Object { $_.WaitForExit() }

    $res = @()
    $faltantes = @()
    for ($i = 0; $i -lt $saidas.Count; $i++) {
        $o = $saidas[$i]
        $ok = $false
        if (Test-Path $o) {
            $conteudo = Get-Content -Raw $o -ErrorAction SilentlyContinue
            if ($conteudo) { $res += ($conteudo | ConvertFrom-Json); $ok = $true }
        }
        if (-not $ok) { $faltantes += ,@{ Arquivos = $baldesPorSaida[$i] } }
    }
    } finally {
        foreach ($t in $tempFiles) { Remove-Item $t -Force -ErrorAction SilentlyContinue }
    }

    if ($faltantes.Count -gt 0) {
        # Um processo morto sem devolver nada nao pode ser lido como zero falha: e o modo de
        # falhar calado que este script inteiro existe pra nao criar.
        $listaArqs = ($faltantes | ForEach-Object { $_.Arquivos -join ", " }) -join " | "
        Write-Host "[rodar-suite] ERRO: $($faltantes.Count) de $($saidas.Count) processo(s) nao devolveram resultado: $listaArqs"
        exit 1
    }

    $total    = ($res | Measure-Object -Property Total    -Sum).Sum
    $passou   = ($res | Measure-Object -Property Passou   -Sum).Sum
    $falhou   = ($res | Measure-Object -Property Falhou   -Sum).Sum
    $pulou    = ($res | Measure-Object -Property Pulou    -Sum).Sum
    $naoRodou = ($res | Measure-Object -Property NaoRodou -Sum).Sum
    $excluidoTag = ($res | Measure-Object -Property ExcluidoTag -Sum).Sum
    $seg      = [Math]::Round(((Get-Date) - $inicio).TotalSeconds, 1)

    $envRemovido = @()
    foreach ($r in $res) { foreach ($n in $r.EnvRemovido) { if ($envRemovido -notcontains $n) { $envRemovido += $n } } }
    if ($envRemovido.Count -gt 0) {
        Write-Host "[rodar-suite] env limpo no filho: $($envRemovido -join ', ')"
    } else {
        Write-Host "[rodar-suite] env limpo no filho: nenhum"
    }

    Write-Host ""
    Write-Host "[rodar-suite] $passou/$total em ${seg}s ($Processos processos) -- pulados $pulou, nao rodados $naoRodou"
    if ($IncluirLentos) {
        Write-Host "[rodar-suite] pulados por tag Lento: 0 (-IncluirLentos ja incluiu tudo)"
    } elseif ($incluirLentoEfetivo) {
        # Achado R11/DeepSeek: nao pode dizer "-IncluirLentos" quando quem incluiu foi a
        # auto-deteccao de -Afetados tocando o guard -- o operador nao passou esse switch.
        Write-Host "[rodar-suite] pulados por tag Lento: 0 (auto-incluido: -Afetados detectou diff tocando o guard)"
    } else {
        Write-Host "[rodar-suite] pulados por tag Lento: $excluidoTag (rode com -IncluirLentos)"
    }
    if ($MostrarPulados -and $pulou -gt 0) {
        Write-Host "[rodar-suite] PULADOS ($pulou):"
        foreach ($r in $res) { foreach ($n in $r.NomesPulados) { Write-Host "  - $n" } }
    }
    if ($falhou -gt 0) {
        Write-Host "[rodar-suite] FALHAS ($falhou):"
        foreach ($r in $res) { foreach ($n in $r.Nomes) { Write-Host "  - $n" } }
        exit 1
    }
    exit 0
} finally { Pop-Location }
