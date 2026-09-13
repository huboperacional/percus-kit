#requires -Version 5.1
# Prova que a LISTA DE REGRAS que o revisor recebe vem do canon em tempo de execucao.
#
# Defeito que este arquivo fecha (medido em 2026-09-12): `system-prompt-review.md` e
# `system-prompt-consult.md` nao apontavam para o canon -- carregavam uma COPIA INLINE das 19
# primeiras regras, escrita a mao numa numeracao ANTERIOR a renumeracao do canon. SETE das
# dezenove traziam o texto errado debaixo do numero certo:
#
#   R1  canon: Criterio unico de "feito" -- copia: "Linguagem e tom"
#   R2  canon: Tracking de status        -- copia: "Arquitetura por frentes"
#   R4  canon: Setup de credenciais      -- copia: "Subagent-driven development"
#   R6  canon: Banco novo por projeto    -- copia: "Stack canonica"
#   R8  canon: Sessao sem HANDOFF        -- copia: "Testes via TDD"
#   R9  canon: Superpowers               -- copia: "Pre-commit review obrigatorio"
#   R12 canon: Regra precisa verificacao -- copia: "Checklist de code review"
#
# E PIOR que a faixa curta de [[revisor-cita-faixa-de-regras-fixa-no-prompt...]]: a faixa
# tornava regra INVISIVEL, e invisivel se descobre pela ausencia. Isto faz o revisor avaliar
# com conviccao contra uma definicao que nao existe mais, e chega como finding fundamentado.
#
# Sobreviveu desde maio porque o `canon-version-check` compara DATA (frontmatter) com SEMVER
# (CANON_VERSION.md) e o proprio comentario dele declara que vai SEMPRE divergir, de
# proposito. Aviso que dispara sempre e aviso desligado.
#
# Verbete: conhecimento/resolver/system-prompt-do-revisor-tem-copia-do-canon-com-texto-de-regra-errado.md

Describe "regras do canon injetadas no system prompt" {

    AfterAll {
        [Console]::OutputEncoding = $script:encodingAnterior
    }

    BeforeAll {
        # O pwsh decodifica o STDOUT de comando nativo (& bash, powershell.exe) com
        # [Console]::OutputEncoding -- que e 850 quando a suite roda pelo Bash ou em janela oculta
        # (o rodar-suite), e 65001 no terminal do agente. Os titulos tem travessao e acento: sem
        # fixar UTF-8 aqui, os dois testes que comparam a saida de um filho ficavam VERDES no
        # terminal e VERMELHOS na suite, com o produto certo. Medido 2026-09-13: um travessao
        # capturado do bash tem comprimento 3 sob 850 e 1 sob UTF-8.
        $script:encodingAnterior = [Console]::OutputEncoding
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

        $script:kitRoot      = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:scriptsDir   = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts"
        $script:providersDir = Join-Path (Split-Path $PSScriptRoot -Parent) "providers"
        $script:helperPs1    = Join-Path $script:scriptsDir "_faixa-regras.ps1"
        $script:helperSh     = Join-Path $script:scriptsDir "_faixa-regras.sh"

        $script:bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
        if (-not $script:bash) {
            $script:bash = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
                Where-Object { Test-Path $_ } | Select-Object -First 1
        }

        # Verdade medida do canon, do mesmo jeito dos dois lados -- nunca literal no teste.
        $canonFile = Join-Path $script:kitRoot "01_REGRAS_INEGOCIAVEIS.md"
        $script:titulos = @{}
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($canonFile), '(?m)^##\s+R(\d+)\.\s*(.+?)\s*$')) {
            $script:titulos[[int]$m.Groups[1].Value] = $m.Groups[2].Value
        }

        $script:canonVazio = Join-Path ([IO.Path]::GetTempPath()) ("canon-vazio-r-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $script:canonVazio -Force | Out-Null

        . (Join-Path $PSScriptRoot '_captura-http.ps1')
        if (Test-Path $script:helperPs1) { . $script:helperPs1 }
    }

    AfterAll {
        if ($script:canonVazio -and (Test-Path $script:canonVazio)) {
            try { [IO.Directory]::Delete($script:canonVazio, $true) } catch { }
        }
    }

    Context "o helper le as regras do canon" {

        It "o canon foi lido (anti-vacuidade)" {
            $script:titulos.Count | Should -BeGreaterThan 20 -Because "sem ler o canon, toda comparacao abaixo compara vazio com vazio"
        }

        It "devolve uma linha por regra do canon, nem mais nem menos" {
            $texto = Get-PercusRegrasDoCanon -CanonDir $script:kitRoot
            $linhas = @($texto -split "`r?`n" | Where-Object { $_ -match '^\s*R\d+\b' })
            $linhas.Count | Should -Be $script:titulos.Count
        }

        It "cada titulo bate com o do canon -- medido dos dois lados" {
            $texto = Get-PercusRegrasDoCanon -CanonDir $script:kitRoot
            $divergentes = @()
            foreach ($n in ($script:titulos.Keys | Sort-Object)) {
                $esperado = $script:titulos[$n]
                if ($texto -notmatch [regex]::Escape("R$n") + '\s*[-—]\s*' + [regex]::Escape($esperado)) {
                    $divergentes += "R$n deveria dizer '$esperado'"
                }
            }
            $divergentes | Should -BeNullOrEmpty
        }

        It "NAO contem os titulos stale da copia antiga" {
            # Os 7 que estavam errados. Se algum sobreviver, a copia voltou por alguma porta.
            $texto = Get-PercusRegrasDoCanon -CanonDir $script:kitRoot
            foreach ($stale in @('Linguagem e tom', 'Arquitetura por frentes', 'Subagent-driven',
                                 'Stack can', 'Testes via TDD', 'Pre-commit review obrigat',
                                 'Checklist de code review')) {
                $texto | Should -Not -Match ([regex]::Escape($stale)) -Because "'$stale' e titulo da copia pre-renumeracao"
            }
        }
    }

    Context "negativa bem-sucedida: canon ilegivel nao vira lista inventada" {

        It "sem canon, DIZ que nao leu e nao lista regra nenhuma" {
            $texto = Get-PercusRegrasDoCanon -CanonDir $script:canonVazio
            $texto | Should -Match '(?i)n[aã]o foi poss[ií]vel|n[aã]o lida|n[aã]o li' -Because "o revisor tem que saber que rodou sem a lista"
            $texto | Should -Match '01_REGRAS_INEGOCIAVEIS' -Because "sem a lista, ao menos o ponteiro pra fonte"
            @($texto -split "`r?`n" | Where-Object { $_ -match '^\s*R\d+\s*[-—]' }).Count |
                Should -Be 0 -Because "listar regra sem ter lido o canon e o defeito original com outra roupa"
        }
    }

    Context "paridade .sh" {

        It "o .sh devolve exatamente o mesmo texto que o .ps1" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $p = ($script:kitRoot -replace '\\', '/')
            $h = ($script:helperSh -replace '\\', '/')
            $saidaSh = (& $script:bash -c ". '$h'; percus_regras_do_canon '$p'" 2>&1 | Out-String)
            $esperado = Get-PercusRegrasDoCanon -CanonDir $script:kitRoot
            # normaliza fim de linha: o que importa e o conteudo, nao CRLF x LF
            ($saidaSh -replace "`r`n", "`n").Trim() | Should -Be (($esperado -replace "`r`n", "`n").Trim())
        }

        It "o .sh tambem degrada sem listar regra" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $v = ($script:canonVazio -replace '\\', '/')
            $h = ($script:helperSh -replace '\\', '/')
            $saida = (& $script:bash -c ". '$h'; percus_regras_do_canon '$v'" 2>&1 | Out-String)
            $saida | Should -Match '01_REGRAS_INEGOCIAVEIS'
            @($saida -split "`r?`n" | Where-Object { $_ -match '^\s*R\d+\s*[-—]' }).Count | Should -Be 0
        }
    }

    Context "ponta a ponta: o que o MODELO recebe" {

        # A prova que importa. Grep no .md diria que o placeholder esta la; so olhando o corpo
        # enviado da pra saber que o titulo certo chegou e o errado nao.
        It "cross-claude.ps1 manda o titulo REAL da R1 e nao o stale" {
            $wrapper = Join-Path $script:providersDir "cross-claude.ps1"
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
                $corpo | Should -Not -BeNullOrEmpty -Because "sem corpo capturado o teste afere nada"
                $corpo | Should -Not -Match '\{\{REGRAS_DO_CANON\}\}' -Because "placeholder cru chegando ao modelo e pior que a copia velha"
                $corpo | Should -Not -Match 'Linguagem e tom' -Because "esse era o titulo STALE da R1"
                # o titulo real da R1, medido do canon agora
                # O corpo trafega como JSON: as aspas do titulo da R1 chegam escapadas (\").
                # Comparar o titulo cru contra o JSON cru falha pelo ESCAPE, nao pelo
                # conteudo -- e isso passaria por "o titulo nao chegou", que e o oposto.
                $limpo = $corpo -replace '\\"', '"'
                $r1 = $script:titulos[1]
                $limpo | Should -Match ([regex]::Escape($r1)) `
                    -Because "o titulo que o modelo recebe tem que ser o do canon de agora, INTEIRO"
            } finally {
                Remove-Item $arqPrompt -Force -ErrorAction SilentlyContinue
            }
        }

        It "cross-claude.sh manda o titulo REAL da R1 e nao o stale" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
            $wrapperSh = Join-Path $script:providersDir "cross-claude.sh"
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
                $corpo | Should -Not -BeNullOrEmpty
                $corpo | Should -Not -Match '\{\{REGRAS_DO_CANON\}\}'
                $corpo | Should -Not -Match 'Linguagem e tom'
                $limpo = $corpo -replace '\\"', '"'
                $r1 = $script:titulos[1]
                $limpo | Should -Match ([regex]::Escape($r1))
            } finally {
                Remove-Item $arqPrompt -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "os titulos sobrevivem ao PowerShell 5.1 (nao so ao pwsh 7)" {

        # Achado do R11 em 2026-09-13. Os titulos do canon tem acento e travessao (—), e o
        # helper passou a EMITIR travessao -- coisa que a versao so-faixa (ASCII "R1-R25")
        # nunca fez. Sob Windows PowerShell 5.1 um .ps1 salvo SEM BOM e lido como Windows-1252
        # e o "—" chega como "â€"": o prompt injetado diverge do canon e da perna .sh, calado.
        #
        # A suite roda em pwsh 7, que assume UTF-8, entao ela e CEGA pra esta classe por
        # construcao -- mesma cegueira de ps51-compat.tests.ps1, e 5.1 nao e hipotese: os
        # wrappers .cmd dos hooks invocam powershell.exe, nunca pwsh.

        It "_faixa-regras.ps1 tem BOM (sem ele o 5.1 le como ANSI)" {
            $b = [IO.File]::ReadAllBytes($script:helperPs1)
            "$($b[0]),$($b[1]),$($b[2])" | Should -Be "239,187,191"
        }

        It "rodando sob powershell.exe 5.1 de verdade, os titulos saem IDENTICOS ao pwsh" {
            $ps51 = Get-Command powershell.exe -ErrorAction SilentlyContinue
            if (-not $ps51) { Set-ItResult -Skipped -Because "powershell.exe (5.1) nao existe nesta maquina"; return }

            $esperado = Get-PercusRegrasDoCanon -CanonDir $script:kitRoot

            # UTF-8 nos DOIS lados do pipe: o filho forca na escrita (abaixo) e o pai na leitura
            # (BeforeAll deste arquivo). O que se quer medir e a DECODIFICACAO DO FONTE .ps1, nao o
            # encoding do pipe. Ate 2026-09-13 este comentario ja dizia "dos dois lados" com so o
            # filho forcando, e o teste ficava vermelho em console 850.
            $prog = '[Console]::OutputEncoding=[Text.Encoding]::UTF8; . "' + $script:helperPs1 + '"; ' +
                    '[Console]::Out.Write((Get-PercusRegrasDoCanon -CanonDir "' + $script:kitRoot + '"))'
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ("r51-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".ps1")
            try {
                # O programa auxiliar tambem vai COM BOM: ele seria lido como ANSI tambem.
                [IO.File]::WriteAllText($tmp, $prog, (New-Object Text.UTF8Encoding($true)))
                $saidaBytes = & $ps51.Source -NoProfile -ExecutionPolicy Bypass -File $tmp 2>&1
                $saida = ($saidaBytes | Out-String)
            } finally {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }

            $saida.Trim() | Should -Not -BeNullOrEmpty -Because "anti-vacuidade: saida vazia compararia nada com nada"
            $saida | Should -Not -Match 'â€' -Because "mojibake classico de UTF-8 lido como Windows-1252"
            ($saida -replace "`r`n", "`n").Trim() | Should -Be (($esperado -replace "`r`n", "`n").Trim())
        }
    }

    Context "GUARDA: nenhum system prompt carrega lista de regras escrita a mao" {

        It "nenhum system-prompt-*.md tem bloco de regras inline" {
            $arqs = @(Get-ChildItem $script:providersDir -Filter "system-prompt-*.md" -File)
            $arqs.Count | Should -BeGreaterThan 2 -Because "anti-vacuidade: sao 3 system prompts"

            # Precisao importa: a secao "Antipadroes" TAMBEM usa `**R<N> — ...**`, e ela e
            # legitima -- sao exemplos concretos de violacao com codigo, conferidos contra o
            # canon. O que nao pode existir e a LISTA DE REGRAS escrita a mao, que morava
            # debaixo do cabecalho "## Regras inegociaveis". Guarda burra demais aqui
            # apagaria conteudo bom, e foi exatamente o que quase aconteceu ao consertar.
            $achados = @()
            foreach ($a in $arqs) {
                $linhas = [IO.File]::ReadAllLines($a.FullName)
                $iCab = @(0..($linhas.Length - 1) | Where-Object { $linhas[$_] -match '^##\s+Regras inegoci' })
                if ($iCab.Count -eq 0) { continue }
                $ini = $iCab[0]
                $prox = @(($ini + 1)..($linhas.Length - 1) | Where-Object { $linhas[$_] -match '^##\s' })
                $fim = if ($prox.Count -gt 0) { $prox[0] } else { $linhas.Length }
                for ($i = $ini + 1; $i -lt $fim; $i++) {
                    if ($linhas[$i] -match '^\*\*R\d+\s*[-—]') { $achados += ("{0}:{1}" -f $a.Name, ($i + 1)) }
                }
            }
            $achados | Should -BeNullOrEmpty -Because "copia manual do canon envelhece calada; injete do canon em runtime"
        }
    }
}
