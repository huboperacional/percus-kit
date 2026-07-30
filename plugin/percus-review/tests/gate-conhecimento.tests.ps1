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
            try {
                $saida = & $bash $script:gate 2>&1 | Out-String
                return [pscustomobject]@{ Exit = $LASTEXITCODE; Saida = $saida.Trim() }
            } finally { Pop-Location }
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
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "o verbete sem tags vem depois e precisa ser visto. Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'sem linha tags'
    }

    It "enxerga verbete depois de UM fence espurio impar (a dessincronizacao real)" {
        # Um unico '> ```' (blockquote seguido IMEDIATAMENTE de crase tripla, sem texto
        # entre os dois) bastava pro padrao antigo togglar uma vez so e considerar TODO
        # o resto do arquivo como dentro de bloco. Foi assim que 72 dos 105 verbetes
        # sumiram da vista do gate no canon real. (Um '> ``` texto solto' NAO reproduz:
        # o padrao antigo so casa crase tripla logo apos '> ', sem nada no meio.)
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '- [Sem tags](#sem-tags)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '> ```', '',
            '## Sem tags {#sem-tags}', '', '**Sintoma:** precisa ser acusada mesmo vindo depois.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "um fence espurio nao pode apagar o resto do arquivo. Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'sem linha tags'
    }

    It "BARRA arquivo com bloco de codigo aberto e nunca fechado" {
        # Fence nao fechado cega o gate dali pra frente. Em vez de passar calado, acusa.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '```', 'bloco aberto e nunca fechado'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "cegueira silenciosa e pior que falso positivo. Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'nunca fechado'
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
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "exemplo em bloco de codigo nao e verbete. Saida do gate: $($r.Saida)"
    }

    It "aceita tags: SEM crase (18 de ~105 verbetes escrevem assim e sao encontraveis)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', 'tags: a, b', '', '**Sintoma:** ok.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "NAO acusa o bloco-modelo em blockquote (falso positivo de 2026-07-27)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '> Modelo pra copiar:', '> ## <sintoma curto> {#ancora-kebab}', '> `tags:` ...'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "barra ancora que nao esta no indice" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '## Orfa {#orfa}', '', '`tags: c`', '', '**Sintoma:** fora do indice.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'nao esta no indice'
    }

    It "NAO acusa verbete cujo tags: vem depois de linhas de citacao" {
        # Blockquote nao pode consumir a janela de 4 linhas do tags: -- senao o gate
        # bloqueia commit legitimo, e gate que bloqueia demais ensina a desliga-lo.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '> Nota 1', '> Nota 2', '> Nota 3', '> Nota 4', '',
            '`tags: a, b`', '', '**Sintoma:** ok.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "o verbete TEM tags, so estao depois da citacao. Saida do gate: $($r.Saida)"
    }

    It "acusa ancora fora do padrao kebab (antes escapava dos dois checks)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '## Ruim {#AncoraRuim}', '', '**Sintoma:** sem tags e com ancora fora do padrao.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "ancora fora do padrao ficava invisivel aos dois checks. Saida do gate: $($r.Saida)"
    }

    It "roda limpo no canon de verdade (exit 0) — e enxergando os 105 verbetes" {
        $reais = @(Select-String -Path (Join-Path $script:kitRoot "conhecimento\COMO_RESOLVER.md") -Pattern '^## .*\{#').Count
        $reais | Should -BeGreaterThan 100 -Because "sanity: o arquivo tem ~105 verbetes"
        $r = Invoke-Gate -Repo $script:kitRoot
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }
}
