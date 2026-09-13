#requires -Version 5.1
# Prova que a faixa de regras citada ao revisor e MEDIDA do canon em tempo de execucao,
# nunca escrita a mao.
#
# O defeito que este arquivo existe pra impedir (medido em 2026-09-12): "R1-R13", "R1-R19" e
# "R1-R23" estavam literais em 8 sitios de script mais 11 de prompt/command, enquanto o canon
# ja ia a R25. O revisor dizia que R20..R25 "nao existem" -- com a confianca de quem cita
# documentacao. Verbete:
# conhecimento/resolver/revisor-cita-faixa-de-regras-fixa-no-prompt-e-reprova-regra-valida.md
#
# Trocar o literal por "R1-R25" NAO e conserto: so reinicia o relogio ate o R26. Por isso o
# ultimo teste deste arquivo e uma GUARDA -- ele reprova qualquer faixa literal nova.

Describe "faixa de regras derivada do canon" {

    BeforeAll {
        $script:kitRoot    = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:scriptsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts"
        $script:helperPs1  = Join-Path $script:scriptsDir "_faixa-regras.ps1"
        $script:helperSh   = Join-Path $script:scriptsDir "_faixa-regras.sh"
        # bash raramente esta no PATH do pwsh nesta maquina; sem o fallback do Git a
        # paridade .sh vira tres testes SKIPPED -- paridade que nao roda nao prova paridade.
        # Mesmo idioma de context-budget-guard.tests.ps1.
        $script:bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
        if (-not $script:bash) {
            $script:bash = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
                Where-Object { Test-Path $_ } | Select-Object -First 1
        }

        # Maximo real do canon, medido aqui do mesmo jeito que o helper deveria medir.
        # Nao e constante: se o canon ganhar R26 este teste acompanha sozinho -- que e
        # exatamente a propriedade que o helper precisa ter.
        $canonFile = Join-Path $script:kitRoot "01_REGRAS_INEGOCIAVEIS.md"
        $script:maxReal = ([regex]::Matches(
            [IO.File]::ReadAllText($canonFile),
            '(?m)^##\s+R(\d+)\.'
        ) | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum

        # Canon de mentira, fora de ordem: prova que o helper tira o MAXIMO e nao o ULTIMO
        # citado. Foi por inferir "o ultimo que vi e o teto" que a primeira versao do verbete
        # errou por dois.
        $script:canonFake = Join-Path ([IO.Path]::GetTempPath()) ("canon-fake-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $script:canonFake -Force | Out-Null
        $textoFake = "# Canon de teste`n`n## R1. primeira`n`n## R30. trigesima`n`n## R7. setima`n`ntexto ## R99. isto nao e cabecalho`n"
        [IO.File]::WriteAllText(
            (Join-Path $script:canonFake "01_REGRAS_INEGOCIAVEIS.md"),
            $textoFake,
            (New-Object System.Text.UTF8Encoding($false))
        )

        # Diretorio sem canon nenhum: o caso "perguntei e nao deu pra medir".
        $script:canonVazio = Join-Path ([IO.Path]::GetTempPath()) ("canon-vazio-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $script:canonVazio -Force | Out-Null

        # harness compartilhado -- ver tests/_captura-http.ps1
        . (Join-Path $PSScriptRoot '_captura-http.ps1')

        if (Test-Path $script:helperPs1) { . $script:helperPs1 }
    }

    AfterAll {
        foreach ($d in @($script:canonFake, $script:canonVazio)) {
            if ($d -and (Test-Path $d)) { [IO.Directory]::Delete($d, $true) }
        }
    }

    Context "o helper .ps1 mede o canon" {

        It "existe um helper compartilhado em scripts/_faixa-regras.ps1" {
            Test-Path $script:helperPs1 | Should -BeTrue -Because "os 4 scripts que montam prompt precisam medir do MESMO jeito; helper por script e a duplicacao de novo"
        }

        It "devolve o maior cabecalho de regra do canon real" {
            $script:maxReal | Should -BeGreaterThan 20 -Because "anti-vacuidade: se o canon nao foi lido, maxReal vem vazio e o teste afere nada"
            Get-PercusCanonMaxRule -CanonDir $script:kitRoot | Should -Be $script:maxReal
        }

        It "tira o MAXIMO, nao o ULTIMO citado, mesmo com as regras fora de ordem" {
            Get-PercusCanonMaxRule -CanonDir $script:canonFake | Should -Be 30
        }

        It "so conta cabecalho de nivel 2, nao R-numero no meio do texto" {
            # O canon fake tem "## R99." dentro de uma linha de prosa. Se contasse, daria 99.
            Get-PercusCanonMaxRule -CanonDir $script:canonFake | Should -Not -Be 99
        }

        It "monta a faixa a partir do que mediu" {
            Get-PercusFaixaRegras -CanonDir $script:kitRoot | Should -Be "R1-R$($script:maxReal)"
        }
    }

    Context "negativa bem-sucedida nao vira numero inventado" {

        It "devolve 0 quando o canon nao existe -- nao chuta um teto" {
            Get-PercusCanonMaxRule -CanonDir $script:canonVazio | Should -Be 0
        }

        It "a frase degradada DIZ que nao mediu, em vez de citar faixa" {
            $frase = Get-PercusFaixaRegras -CanonDir $script:canonVazio
            $frase | Should -Not -Match 'R1-R\d+' -Because "citar faixa sem ter medido e o defeito original com outra roupa"
            $frase | Should -Match 'n[aa]o medida' -Because "o revisor tem que saber que a faixa faltou, nao receber silencio"
            $frase | Should -Match '01_REGRAS_INEGOCIAVEIS' -Because "sem faixa, o revisor precisa ao menos do ponteiro pra fonte"
        }
    }

    Context "paridade .sh" {

        It "existe o par scripts/_faixa-regras.sh" {
            Test-Path $script:helperSh | Should -BeTrue
        }

        It "o .sh devolve o mesmo numero que o .ps1 no canon real" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $p = ($script:kitRoot -replace '\\', '/')
            $h = ($script:helperSh -replace '\\', '/')
            $saida = & $script:bash -c ". '$h'; percus_canon_max_rule '$p'" 2>&1 | Out-String
            $saida.Trim() | Should -Be "$($script:maxReal)"
        }

        It "o .sh tambem devolve 0 quando o canon nao existe" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $v = ($script:canonVazio -replace '\\', '/')
            $h = ($script:helperSh -replace '\\', '/')
            $saida = & $script:bash -c ". '$h'; percus_canon_max_rule '$v'" 2>&1 | Out-String
            $saida.Trim() | Should -Be "0"
        }

        It "o .sh monta a mesma faixa que o .ps1" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $p = ($script:kitRoot -replace '\\', '/')
            $h = ($script:helperSh -replace '\\', '/')
            $saida = & $script:bash -c ". '$h'; percus_faixa_regras '$p'" 2>&1 | Out-String
            $saida.Trim() | Should -Be (Get-PercusFaixaRegras -CanonDir $script:kitRoot)
        }
    }

    Context "ponta a ponta: o que SAI do wrapper, nao o que esta escrito nele" {

        # O placeholder {{FAIXA_REGRAS}} dos system-prompt-*.md so vale se alguem SUBSTITUIR.
        # Placeholder que vaza cru pro modelo e pior que a faixa velha: a faixa velha ao menos
        # era uma frase. Grep no fonte nao prova substituicao -- prova que o texto existe, que
        # e exatamente o erro de "medir o rotulo" que estes verbetes documentam. Entao aqui o
        # wrapper e executado de verdade contra um socket local que captura o corpo enviado.

        It "cross-claude.ps1 envia a faixa MEDIDA, e nenhum placeholder cru" {
            $wrapper = Join-Path (Split-Path $PSScriptRoot -Parent) "providers" "cross-claude.ps1"
            $arqPrompt = Join-Path ([IO.Path]::GetTempPath()) ("p-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".txt")
            "diff de teste" | Set-Content $arqPrompt -Encoding UTF8
            try {
                $corpo = Invoke-CapturaCorpoHttp -Disparo {
                    param($porta)
                    Start-Job -ScriptBlock {
                        param($w, $pf, $ep)
                        $env:ANTHROPIC_API_KEY = "chave-de-teste-nao-usada"
                        & $w -PromptFile $pf -Mode review -Endpoint $ep 2>&1 | Out-Null
                    } -ArgumentList $wrapper, $arqPrompt, "http://127.0.0.1:$porta/v1/messages"
                }

                $corpo | Should -Not -BeNullOrEmpty -Because "o wrapper tem que chegar a fazer o POST; sem corpo capturado o teste nao afere nada"
                $corpo | Should -Not -Match '\{\{FAIXA_REGRAS\}\}' -Because "placeholder cru chegando ao modelo e pior que a faixa velha"
                $corpo | Should -Match "R1-R$($script:maxReal)" -Because "a faixa que sai tem que ser a MEDIDA no canon de agora"
            } finally {
                Remove-Item $arqPrompt -Force -ErrorAction SilentlyContinue
            }
        }

        It "cross-claude.sh envia a faixa MEDIDA, e nenhum placeholder cru" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $wrapperSh = Join-Path (Split-Path $PSScriptRoot -Parent) "providers" "cross-claude.sh"
            $arqPrompt = Join-Path ([IO.Path]::GetTempPath()) ("p-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".txt")
            "diff de teste" | Set-Content $arqPrompt -Encoding UTF8
            try {
                $corpo = Invoke-CapturaCorpoHttp -Disparo {
                    param($porta)
                    Start-Job -ScriptBlock {
                        param($b, $w, $pf, $ep)
                        $env:ANTHROPIC_API_KEY = "chave-de-teste-nao-usada"
                        & $b "$($w -replace '\\','/')" --prompt-file "$($pf -replace '\\','/')" --mode review --endpoint $ep 2>&1 | Out-Null
                    } -ArgumentList $script:bash, $wrapperSh, $arqPrompt, "http://127.0.0.1:$porta/v1/messages"
                }

                $corpo | Should -Not -BeNullOrEmpty -Because "o wrapper .sh tem que chegar a fazer o POST"
                $corpo | Should -Not -Match '\{\{FAIXA_REGRAS\}\}' -Because "placeholder cru chegando ao modelo e pior que a faixa velha"
                $corpo | Should -Match "R1-R$($script:maxReal)" -Because "a faixa que sai tem que ser a MEDIDA no canon de agora"
            } finally {
                Remove-Item $arqPrompt -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "helper ausente DEGRADA, nao mata o revisor" {

        # Finding do proprio R11 nesta mudanca (2026-09-12, perna DeepSeek): os quatro
        # consumidores carregavam o helper de dois jeitos. `cross-claude.ps1` e
        # `percus-review-auto.*` guardavam com Test-Path e caiam na frase degradada;
        # `deepseek-review.*` e `council-orchestrator.*` faziam dot-source incondicional sob
        # ErrorActionPreference=Stop / set -e -- helper ausente matava o revisor inteiro.
        #
        # Por que importa: hooks e scripts chegam a frota por publicacao, e um cache parcial
        # (script novo sem o helper novo) travaria TODO commit da frota por causa de um
        # ornamento de prompt. A faixa e enfeite do prompt; o review e o gate. Enfeite que
        # falta nao pode derrubar gate.
        BeforeAll {
            $script:semHelper = Join-Path ([IO.Path]::GetTempPath()) ("sem-helper-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            $pluginDir = Split-Path $PSScriptRoot -Parent
            New-Item -ItemType Directory -Path $script:semHelper -Force | Out-Null
            Copy-Item (Join-Path $pluginDir "scripts")   (Join-Path $script:semHelper "scripts")   -Recurse -Force
            Copy-Item (Join-Path $pluginDir "providers") (Join-Path $script:semHelper "providers") -Recurse -Force
            # o helper NAO existe nesta copia -- e esse o cenario
            Get-ChildItem (Join-Path $script:semHelper "scripts") -Filter "_faixa-regras.*" | Remove-Item -Force
            (Get-ChildItem (Join-Path $script:semHelper "scripts") -Filter "_faixa-regras.*").Count |
                Should -Be 0 -Because "o cenario do teste e justamente a ausencia do helper"

            # Repo git limpo: sem diff, o deepseek-review sai em "Nada pra revisar" ANTES de
            # tocar a API -- seam pra exercitar a carga do helper sem gastar chamada.
            $script:repoLimpo = Join-Path ([IO.Path]::GetTempPath()) ("repo-limpo-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $script:repoLimpo -Force | Out-Null
            Push-Location $script:repoLimpo
            try {
                & git init -q 2>&1 | Out-Null
                & git config user.email "teste@percus.local" 2>&1 | Out-Null
                & git config user.name "teste" 2>&1 | Out-Null
                "conteudo" | Set-Content (Join-Path $script:repoLimpo "a.txt")
                & git add -A 2>&1 | Out-Null
                & git commit -q -m "base" 2>&1 | Out-Null
            } finally { Pop-Location }

            $script:promptVazio = Join-Path ([IO.Path]::GetTempPath()) ("vazio-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".txt")
            Set-Content -Path $script:promptVazio -Value "" -NoNewline
        }

        AfterAll {
            # `git init` deixa os objetos em .git como somente-leitura, e Delete() recursivo
            # levanta UnauthorizedAccessException -- limpeza que FALHA reprova o bloco inteiro
            # e transforma teste verde em suite vermelha. Tira o atributo antes, e desiste em
            # silencio se ainda assim nao der: e diretorio temporario, nao resultado.
            foreach ($d in @($script:semHelper, $script:repoLimpo)) {
                if (-not $d -or -not (Test-Path $d)) { continue }
                try {
                    Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue |
                        ForEach-Object { $_.Attributes = 'Normal' }
                    [IO.Directory]::Delete($d, $true)
                } catch { }
            }
            Remove-Item $script:promptVazio -Force -ErrorAction SilentlyContinue
        }

        It "deepseek-review.ps1 sem o helper ainda chega a decidir que nao ha o que revisar" {
            $script = Join-Path $script:semHelper "scripts\deepseek-review.ps1"
            Push-Location $script:repoLimpo
            try {
                $saida = & pwsh -NoProfile -Command "`$env:DEEPSEEK_API_KEY='chave-de-teste'; & '$script'" 2>&1 | Out-String
            } finally { Pop-Location }
            $saida | Should -Match 'Nada pra revisar' -Because "sem o helper o script tem que seguir, nao morrer no dot-source"
        }

        It "deepseek-review.sh sem o helper ainda roda" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $sh = (Join-Path $script:semHelper "scripts\deepseek-review.sh") -replace '\\', '/'
            $saida = & $script:bash -c "'$sh' --help" 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0 -Because "sob set -euo um source de arquivo ausente mata o script inteiro"
            $saida | Should -Match 'deepseek-review' -Because "tem que chegar a imprimir o help"
        }

        It "council-orchestrator.ps1 sem o helper ainda chega a validar o prompt" {
            $script = Join-Path $script:semHelper "scripts\council-orchestrator.ps1"
            $saida = & pwsh -NoProfile -File $script -PromptFile $script:promptVazio 2>&1 | Out-String
            $saida | Should -Match 'prompt vazio' -Because "sem o helper o orquestrador tem que seguir ate a validacao normal"
        }

        It "council-orchestrator.sh sem o helper ainda chega a validar o prompt" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $sh = (Join-Path $script:semHelper "scripts\council-orchestrator.sh") -replace '\\', '/'
            $pf = $script:promptVazio -replace '\\', '/'
            $saida = & $script:bash -c "'$sh' --prompt-file '$pf'" 2>&1 | Out-String
            $saida | Should -Match 'prompt vazio' -Because "sem o helper o orquestrador tem que seguir ate a validacao normal"
        }

        It "sem o helper, o prompt sai com a frase degradada -- nao com faixa chutada" {
            # Prova de ponta a ponta do ramo degradado: o wrapper roda sem helper e o corpo
            # enviado nao pode conter faixa nenhuma inventada.
            $wrapper = Join-Path $script:semHelper "providers\cross-claude.ps1"
            $arqPrompt = Join-Path ([IO.Path]::GetTempPath()) ("p-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".txt")
            "diff de teste" | Set-Content $arqPrompt -Encoding UTF8
            try {
                $corpo = Invoke-CapturaCorpoHttp -Disparo {
                    param($porta)
                    Start-Job -ScriptBlock {
                        param($w, $pf, $ep)
                        $env:ANTHROPIC_API_KEY = "chave-de-teste-nao-usada"
                        & $w -PromptFile $pf -Mode review -Endpoint $ep 2>&1 | Out-Null
                    } -ArgumentList $wrapper, $arqPrompt, "http://127.0.0.1:$porta/v1/messages"
                }
                $corpo | Should -Not -BeNullOrEmpty -Because "o wrapper tem que chegar a fazer o POST mesmo sem helper"
                $corpo | Should -Not -Match '\{\{FAIXA_REGRAS\}\}' -Because "placeholder cru nunca pode vazar"
                $corpo | Should -Not -Match 'R1-R\d+' -Because "sem medir o canon, citar faixa e o defeito original de volta"
                $corpo | Should -Match 'nao medida' -Because "o revisor precisa saber que a faixa faltou"
            } finally {
                Remove-Item $arqPrompt -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "as funcoes .sh sobrevivem a set -euo pipefail em chamada DIRETA" {

        # Achado do R11 em 2026-09-13, e ele estava certo -- eu quase dispensei.
        #
        # Com `set -e` + `pipefail`, um canon que EXISTE mas nao tem `## R<N>.` faz o `grep`
        # devolver 1, o pipeline devolver 1, e a atribuicao MATAR o script antes de chegar na
        # guarda `[[ -n "$saida" ]]` que produz a frase degradada. Ou seja: o caminho que
        # existe para degradar com honestidade e o caminho que morre.
        #
        # Por que passou despercebido: TODOS os call sites de hoje chamam dentro de `$( )`,
        # e o bash nao aplica errexit do jeito esperado dentro de substituicao de comando --
        # medido: chamada direta sai 1, a mesma chamada dentro de `$( )` sai 0. A seguranca
        # de hoje e ACIDENTE da forma da chamada, nao propriedade da funcao. O primeiro call
        # site direto que alguem escrever quebra.
        BeforeAll {
            $script:canonSemRegra = Join-Path ([IO.Path]::GetTempPath()) ("canon-sem-regra-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $script:canonSemRegra -Force | Out-Null
            [IO.File]::WriteAllText(
                (Join-Path $script:canonSemRegra "01_REGRAS_INEGOCIAVEIS.md"),
                "# Canon presente, porem sem nenhum cabecalho de regra`n`ntexto qualquer`n",
                (New-Object System.Text.UTF8Encoding($false)))
        }

        AfterAll {
            if ($script:canonSemRegra -and (Test-Path $script:canonSemRegra)) {
                try { [IO.Directory]::Delete($script:canonSemRegra, $true) } catch { }
            }
        }

        It "percus_canon_max_rule nao mata o script chamada DIRETAMENTE" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $h = ($script:helperSh -replace '\\', '/')
            $c = ($script:canonSemRegra -replace '\\', '/')
            $saida = & $script:bash -c "set -euo pipefail; . '$h'; percus_canon_max_rule '$c'; echo ' VIVO'" 2>&1 | Out-String
            # Comparacao EXATA, nao `-Match '0'`: aquilo casaria com qualquer string que
            # contivesse um zero -- inclusive a frase degradada ou uma mensagem de erro --
            # e passaria se a funcao devolvesse outra coisa. Apontado pelo R11 nesta entrega.
            ($saida -replace '\s+', ' ').Trim() | Should -BeExactly '0 VIVO' `
                -Because "tem que sair EXATAMENTE 0 (ausencia de medida) e o script tem que sobreviver"
        }

        It "percus_regras_do_canon nao mata o script chamada DIRETAMENTE" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $h = ($script:helperSh -replace '\\', '/')
            $c = ($script:canonSemRegra -replace '\\', '/')
            $saida = & $script:bash -c "set -euo pipefail; . '$h'; percus_regras_do_canon '$c'; echo ' VIVO'" 2>&1 | Out-String
            $saida | Should -Match 'VIVO' -Because "a funcao tem que DEGRADAR, nao derrubar quem a chamou"
            $saida | Should -Match '01_REGRAS_INEGOCIAVEIS' -Because "degradar e dizer o que faltou e apontar a fonte"
        }
    }

    Context "GUARDA: nenhum sitio vivo carrega faixa literal (o que impede o R26 reabrir isto)" {

        It "nenhum script, prompt, command ou skill tem faixa de regras escrita a mao" {
            # tests/ fica fora: este proprio arquivo precisa citar o padrao pra falar dele.
            # .deepseek/ fica fora: sao LOGS historicos de conselho, registro do que foi
            # enviado na epoca -- reescrever log e falsificar medicao.
            $alvos = @()
            $alvos += Get-ChildItem (Join-Path $script:kitRoot "plugin") -Recurse -File -ErrorAction SilentlyContinue
            $alvos += Get-ChildItem (Join-Path $script:kitRoot "scripts") -Recurse -File -ErrorAction SilentlyContinue
            $alvos = @($alvos | Where-Object {
                    $_.Extension -in @('.ps1', '.sh', '.md', '.json', '.txt', '.cmd') -and
                    $_.FullName -notmatch '\\\.deepseek\\' -and
                    $_.FullName -notmatch '\\tests\\'
                })

            $alvos.Count | Should -BeGreaterThan 40 -Because "anti-vacuidade: varredura curta e varredura quebrada"

            $achados = @()
            foreach ($a in $alvos) {
                $texto = [IO.File]::ReadAllText($a.FullName)
                foreach ($m in [regex]::Matches($texto, 'R1-R\d+')) {
                    $linha = ($texto.Substring(0, $m.Index) -split "`n").Count
                    $achados += ("{0}:{1} -- {2}" -f $a.FullName.Replace($script:kitRoot + '\', ''), $linha, $m.Value)
                }
            }

            $achados | Should -BeNullOrEmpty -Because "faixa literal envelhece calada; derive do canon ou nao cite faixa"
        }
    }
}
