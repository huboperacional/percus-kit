#requires -Version 5.1
# Prova COMPORTAMENTAL do gate de conhecimento: roda o script de verdade num repo
# temporario e afere o que ele barra. Nao inspeciona o codigo do gate — inspecao de
# codigo foi o que deixou passar o gate cego de 2026-07-29 (via 33 de 105 verbetes).

Describe "percus-gate.sh — higiene de conhecimento" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:gate    = Join-Path $script:kitRoot "v2\gates\percus-gate.sh"
        $script:temps   = New-Object System.Collections.ArrayList

        function Get-BashExe {
            $c = Get-Command bash -ErrorAction SilentlyContinue
            if ($c) { return $c.Source }
            foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe")) {
                if (Test-Path $p) { return $p }
            }
            return $null
        }

        # Cria repo temporario com um conhecimento/x.md montado a partir das linhas dadas.
        function New-KnowledgeRepo {
            param([string[]]$Linhas)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-gate-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path (Join-Path $dir "conhecimento") -Force | Out-Null
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\x.md"), $Linhas, (New-Object System.Text.UTF8Encoding($false)))
            [void]$script:temps.Add($dir)
            return $dir
        }

        function Invoke-Gate {
            param([string]$Repo)
            $bash = Get-BashExe
            Push-Location $Repo
            try { & $bash $script:gate 2>&1 | Out-Null; return $LASTEXITCODE } finally { Pop-Location }
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "enxerga verbete DEPOIS de fence dentro de blockquote (a causa dos 72 invisiveis)" {
        # O padrao antigo casava '> ```' como fence de verdade; o toggle dessincronizava
        # e tudo dali pra frente sumia da vista. Com fence ESTRITO (coluna 0), '> ```'
        # e so texto e o verbete seguinte continua sendo aferido.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '- [Sem tags](#sem-tags)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a, b`', '', '**Sintoma:** ok.', '',
            '> Modelo pra copiar:', '> ```', '> ## Exemplo {#exemplo}', '> ```', '',
            '## Sem tags {#sem-tags}', '', '**Sintoma:** invisivel pra busca.'
        )
        Invoke-Gate -Repo $repo | Should -Be 1 -Because "o verbete sem tags vem depois e precisa ser visto"
    }

    It "BARRA arquivo com bloco de codigo aberto e nunca fechado" {
        # Fence nao fechado cega o gate dali pra frente. Em vez de passar calado, acusa.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '```', 'bloco aberto e nunca fechado'
        )
        Invoke-Gate -Repo $repo | Should -Be 1 -Because "cegueira silenciosa e pior que falso positivo"
    }

    It "NAO acusa titulo de exemplo dentro de bloco de codigo" {
        # ^## sozinho enxergaria este exemplo como verbete real e acusaria ancora orfa.
        # Por isso o fence ESTRITO continua no gate — so ele, e so na coluna 0.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            'Exemplo de como escrever um verbete:', '',
            '```markdown', '## Titulo de exemplo {#exemplo-em-bloco}', '`tags: x`', '```'
        )
        Invoke-Gate -Repo $repo | Should -Be 0 -Because "exemplo em bloco de codigo nao e verbete"
    }

    It "aceita tags: SEM crase (18 de ~105 verbetes escrevem assim e sao encontraveis)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', 'tags: a, b', '', '**Sintoma:** ok.'
        )
        Invoke-Gate -Repo $repo | Should -Be 0
    }

    It "NAO acusa o bloco-modelo em blockquote (falso positivo de 2026-07-27)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '> Modelo pra copiar:', '> ## <sintoma curto> {#ancora-kebab}', '> `tags:` ...'
        )
        Invoke-Gate -Repo $repo | Should -Be 0
    }

    It "barra ancora que nao esta no indice" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '## Orfa {#orfa}', '', '`tags: c`', '', '**Sintoma:** fora do indice.'
        )
        Invoke-Gate -Repo $repo | Should -Be 1
    }

    It "roda limpo no canon de verdade (exit 0) — e enxergando os 105 verbetes" {
        $reais = @(Select-String -Path (Join-Path $script:kitRoot "conhecimento\COMO_RESOLVER.md") -Pattern '^## .*\{#').Count
        $reais | Should -BeGreaterThan 100 -Because "sanity: o arquivo tem ~105 verbetes"
        Invoke-Gate -Repo $script:kitRoot | Should -Be 0
    }
}
