#requires -Version 5.1
# Prova comportamental do gerador de indice. Sucessor de mesclar-conhecimento.tests.ps1:
# desde a 6.38.0 nao ha monolito nem caixa de entrada, entao nao ha merge -- so a geracao
# do INDICE.md a partir dos arquivos de verbete.
#
# O indice e GERADO de proposito. Indice divergente do conteudo foi o defeito que deixou 14
# verbetes invisiveis por semanas (2026-08-18), e um indice mantido a mao volta a divergir
# no primeiro dia corrido.

Describe "gerar-indice-conhecimento.ps1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\gerar-indice-conhecimento.ps1"
        $script:temps   = New-Object System.Collections.ArrayList

        function New-BaseFalsa {
            param([hashtable]$Verbetes, [string[]]$IndiceExistente)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-idx-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            $res = Join-Path $dir "conhecimento\resolver"
            New-Item -ItemType Directory -Path $res -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $dir "conhecimento\fazer") -Force | Out-Null
            $enc = New-Object System.Text.UTF8Encoding($false)
            foreach ($slug in $Verbetes.Keys) {
                [IO.File]::WriteAllText((Join-Path $res "$slug.md"), ($Verbetes[$slug] -join "`r`n"), $enc)
            }
            if ($IndiceExistente) {
                [IO.File]::WriteAllText((Join-Path $res "INDICE.md"), ($IndiceExistente -join "`r`n"), $enc)
            }
            [void]$script:temps.Add($dir)
            return $dir
        }

        function Invoke-Gerador {
            param([string]$Raiz, [switch]$Verificar)
            $args = @("-NoProfile","-File",$script:script,"-Raiz",$Raiz)
            if ($Verificar) { $args += "-Verificar" }
            $saida = & pwsh @args 2>&1 | Out-String
            return [pscustomobject]@{ Exit = $LASTEXITCODE; Saida = $saida }
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "existe" { Test-Path $script:script | Should -Be $true }

    It "gera o INDICE.md com uma linha por verbete, em ordem de nome" {
        $dir = New-BaseFalsa @{
            'bbb' = @('## Titulo B {#bbb}', '', '`tags: x`', '', 'corpo.')
            'aaa' = @('## Titulo A {#aaa}', '', '`tags: x`', '', 'corpo.')
        }
        $r = Invoke-Gerador -Raiz $dir
        $r.Exit | Should -Be 0 -Because $r.Saida
        $idx = Get-Content (Join-Path $dir "conhecimento\resolver\INDICE.md") -Raw
        $idx | Should -Match '\- \[Titulo A\]\(aaa\.md\)'
        $idx | Should -Match '\- \[Titulo B\]\(bbb\.md\)'
        $idx.IndexOf('aaa.md') | Should -BeLessThan $idx.IndexOf('bbb.md')
    }

    It "e IDEMPOTENTE -- rodar duas vezes nao muda o arquivo" {
        $dir = New-BaseFalsa @{ 'um' = @('## Um {#um}', '', '`tags: x`', '', 'corpo.') }
        Invoke-Gerador -Raiz $dir | Out-Null
        $primeiro = Get-Content (Join-Path $dir "conhecimento\resolver\INDICE.md") -Raw
        Invoke-Gerador -Raiz $dir | Out-Null
        $segundo = Get-Content (Join-Path $dir "conhecimento\resolver\INDICE.md") -Raw
        $segundo | Should -BeExactly $primeiro
    }

    It "NAO inclui LEIA-ME nem o proprio INDICE como verbete" {
        $dir = New-BaseFalsa @{
            'um'      = @('## Um {#um}', '', '`tags: x`', '', 'corpo.')
            'LEIA-ME' = @('# Documentacao da area', '', 'texto.')
        }
        $r = Invoke-Gerador -Raiz $dir
        $r.Exit | Should -Be 0 -Because $r.Saida
        $idx = Get-Content (Join-Path $dir "conhecimento\resolver\INDICE.md") -Raw
        $idx | Should -Not -Match 'LEIA-ME'
        $idx | Should -Not -Match '\(INDICE\.md\)'
    }

    It "-Verificar sai 1 quando o INDICE esta DESATUALIZADO, sem escrever" {
        $dir = New-BaseFalsa -Verbetes @{ 'um' = @('## Um {#um}', '', '`tags: x`', '', 'corpo.') } `
                             -IndiceExistente @('# Indice - Como Resolver', '', 'conteudo velho')
        $antes = Get-Content (Join-Path $dir "conhecimento\resolver\INDICE.md") -Raw
        $r = Invoke-Gerador -Raiz $dir -Verificar
        $r.Exit | Should -Be 1 -Because $r.Saida
        (Get-Content (Join-Path $dir "conhecimento\resolver\INDICE.md") -Raw) | Should -BeExactly $antes
    }

    It "-Verificar sai 0 quando o INDICE esta em dia" {
        $dir = New-BaseFalsa @{ 'um' = @('## Um {#um}', '', '`tags: x`', '', 'corpo.') }
        Invoke-Gerador -Raiz $dir | Out-Null
        $r = Invoke-Gerador -Raiz $dir -Verificar
        $r.Exit | Should -Be 0 -Because $r.Saida
    }

    It "DENUNCIA verbete cujo slug diverge do nome do arquivo, e nao o indexa" {
        # Mesma regra do gate. Gerador e gate discordando sobre o que e verbete valido faz o
        # gate aprovar o que o indice ignora -- e o verbete some sem ninguem ver.
        $dir = New-BaseFalsa @{ 'nome-do-arquivo' = @('## Titulo {#outro-slug}', '', '`tags: x`', '', 'corpo.') }
        $r = Invoke-Gerador -Raiz $dir
        $r.Exit | Should -Be 3 -Because $r.Saida
        $r.Saida | Should -Match 'diverge'
    }

    It "DENUNCIA arquivo sem titulo de verbete, e nao o indexa" {
        $dir = New-BaseFalsa @{ 'sem-titulo' = @('texto solto, sem titulo de verbete.') }
        $r = Invoke-Gerador -Raiz $dir
        $r.Exit | Should -Be 3 -Because $r.Saida
        $r.Saida | Should -Match 'sem titulo'
    }

    It "titulo de EXEMPLO dentro de fence nao vira o titulo do verbete" {
        $dir = New-BaseFalsa @{
            'com-fence' = @('## Real {#com-fence}', '', '`tags: x`', '', '```md', '## Exemplo {#exemplo}', '```')
        }
        $r = Invoke-Gerador -Raiz $dir
        $r.Exit | Should -Be 0 -Because $r.Saida
        $idx = Get-Content (Join-Path $dir "conhecimento\resolver\INDICE.md") -Raw
        $idx | Should -Match '\[Real\]\(com-fence\.md\)'
        $idx | Should -Not -Match 'Exemplo'
    }

    It "o INDICE do canon de verdade esta EM DIA" {
        # Se este falhar, alguem escreveu verbete e nao regerou -- e o indice ja esta mentindo.
        $r = Invoke-Gerador -Raiz $script:kitRoot -Verificar
        $r.Exit | Should -Be 0 -Because "rode scripts/gerar-indice-conhecimento.ps1. Saida: $($r.Saida)"
    }
}
