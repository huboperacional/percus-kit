#requires -Version 5.1
# Prova que a tabela "Quem manda em que (por tema)" de v2/MIGRACAO.md continua valida contra o
# repo real: todo loop e todo formato de artefato do V2 tem linha, todo caminho citado existe,
# todo R-numero existe como cabecalho em 01_REGRAS_INEGOCIAVEIS.md e a coluna "Em conflito vence"
# so diz V1 ou V2.
#
# Por que existe (Fase 3, ponto 11): V1 e V2 descrevem os mesmos temas (review, deploy,
# checkpoint...) sem dizer qual texto vence quando divergem. Loop novo sem linha na tabela e o
# mesmo buraco reaberto em silencio -- por isso o ultimo bloco prova, num fixture, que o teste
# reprova nomeando o arquivo.
#
# Caminhos resolvem pela raiz do kit (3 niveis acima deste arquivo), nunca pelo cwd.

Describe "v2/MIGRACAO.md -- quem manda em que (por tema)" {

    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path

        function Get-SecaoQuemManda {
            param([string]$Texto)
            $m = [regex]::Match($Texto, '(?ms)^## Quem manda em qu\S+ \(por tema\)[ \t]*\r?$(.*?)(?=^## |\z)')
            if (-not $m.Success) { return $null }
            return $m.Groups[1].Value
        }

        # Linhas de tabela da secao, ja partidas em celulas. A primeira linha e o cabecalho;
        # a de separador (|---|) sai.
        function Get-LinhasTabela {
            param([string]$Secao)
            $linhas = @($Secao -split "\r?\n" | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|[\s\-:|]+\|\s*$' })
            $saida = @()
            foreach ($l in $linhas) {
                $t = $l.Trim()
                $t = $t.Substring(1, $t.Length - 2)
                $celulas = @($t -split '\|' | ForEach-Object { $_.Trim() })
                $saida += ,$celulas
            }
            return ,$saida
        }

        function Get-TextoTabela {
            param([string]$Secao)
            return (@($Secao -split "\r?\n" | Where-Object { $_ -match '^\|' }) -join "`n")
        }

        function Get-FaltasCobertura {
            param([string]$KitRoot, [string]$Secao)
            $tabela = Get-TextoTabela -Secao $Secao
            $faltas = @()
            # Pasta ausente NAO e' cobertura em dia: renomear v2/loops deixaria a varredura vazia e o
            # teste verde guardando NADA (mesma classe de falso-verde do piso abaixo).
            $vistos = 0
            foreach ($sub in @('loops', 'artefatos')) {
                $dir = Join-Path (Join-Path $KitRoot 'v2') $sub
                if (-not (Test-Path $dir)) { $faltas += "v2/$sub (pasta ausente -- renomeada?)"; continue }
                foreach ($f in @(Get-ChildItem -Path $dir -Filter '*.md' -File | Sort-Object Name)) {
                    $vistos++
                    $rel = "v2/$sub/$($f.Name)"
                    if (-not $tabela.Contains($rel)) { $faltas += $rel }
                }
            }
            # Piso: hoje sao 12 arquivos nas duas pastas; varredura curta e' varredura quebrada.
            if ($vistos -lt 8) { $faltas += "varredura curta: so $vistos arquivo(s) .md em v2/loops+v2/artefatos" }
            return ,$faltas
        }

        function Assert-Cobertura {
            param([string]$KitRoot, [string]$Secao)
            $faltas = Get-FaltasCobertura -KitRoot $KitRoot -Secao $Secao
            if ($faltas.Count -gt 0) {
                throw ("arquivo(s) do v2 sem linha na tabela Quem manda: " + ($faltas -join ', '))
            }
        }

        # Token entre crases que parece caminho: tem barra ou termina em extensao de arquivo.
        # `[5-T]`, `-NoFactCheck` e nomes de hook nao sao caminho.
        function Get-CaminhosCitados {
            param([string]$Secao)
            $tabela = Get-TextoTabela -Secao $Secao
            $tokens = @([regex]::Matches($tabela, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value })
            return ,@($tokens | Where-Object { $_ -match '/' -or $_ -match '\.(md|ps1|sh|cmd|json|txt|ya?ml)$' } | Sort-Object -Unique)
        }

        $script:migracao = Join-Path $script:kitRoot 'v2\MIGRACAO.md'
        $script:texto    = [IO.File]::ReadAllText($script:migracao)
        $script:secao    = Get-SecaoQuemManda -Texto $script:texto
        $script:regras   = [IO.File]::ReadAllText((Join-Path $script:kitRoot '01_REGRAS_INEGOCIAVEIS.md'))
    }

    It "a secao existe e vem logo depois de '## Estado'" {
        $script:secao | Should -Not -BeNullOrEmpty
        $cabecalhos = @([regex]::Matches($script:texto, '(?m)^## .*$') | ForEach-Object { $_.Value.Trim() })
        $iEstado = [array]::IndexOf($cabecalhos, '## Estado')
        $iEstado | Should -BeGreaterOrEqual 0
        # A posicao e contrato (plano da Fase 3, T5): quem le a tabela de Estado cai direto em quem manda.
        $cabecalhos[$iEstado + 1] | Should -Match '^## Quem manda em qu\S+ \(por tema\)$' -Because "a secao fica logo depois de '## Estado' por contrato"
    }

    It "o cabecalho da tabela tem as 5 colunas do contrato e toda linha tem 5 celulas" {
        $linhas = Get-LinhasTabela -Secao $script:secao
        $linhas.Count | Should -BeGreaterThan 10
        $cab = $linhas[0]
        $cab.Count | Should -Be 5
        $cab[0] | Should -Be 'Tema'
        $cab[1] | Should -Match '^Obriga\S+ \(V1'
        $cab[2] | Should -Match '^Procedimento \(V2'
        $cab[3] | Should -Be 'Em conflito vence'
        $cab[4] | Should -Be 'Ponteiro que falta'
        $ruins = @($linhas | Select-Object -Skip 1 | Where-Object { $_.Count -ne 5 } | ForEach-Object { $_[0] })
        $ruins | Should -BeNullOrEmpty -Because "linhas com numero errado de celulas: $($ruins -join ', ')"
    }

    It "cada v2/loops/*.md e v2/artefatos/*.md aparece em ao menos uma linha" {
        { Assert-Cobertura -KitRoot $script:kitRoot -Secao $script:secao } | Should -Not -Throw
    }

    It "cada caminho entre crases na tabela existe no repo (relativo a raiz do kit)" {
        $caminhos = Get-CaminhosCitados -Secao $script:secao
        $caminhos.Count | Should -BeGreaterThan 5
        $mortos = @($caminhos | Where-Object { -not (Test-Path -LiteralPath (Join-Path $script:kitRoot $_)) })
        $mortos | Should -BeNullOrEmpty -Because "caminhos citados que nao existem: $($mortos -join ', ')"
    }

    It "cada R<n> citado existe como '## R<n>.' em 01_REGRAS_INEGOCIAVEIS.md" {
        $tabela = Get-TextoTabela -Secao $script:secao
        $nums = @([regex]::Matches($tabela, '\bR(\d+)\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $nums.Count | Should -BeGreaterThan 3
        $inexistentes = @($nums | Where-Object { -not [regex]::IsMatch($script:regras, "(?m)^## R$_\.") } | ForEach-Object { "R$_" })
        $inexistentes | Should -BeNullOrEmpty -Because "R-numeros sem cabecalho no canon: $($inexistentes -join ', ')"
    }

    It "a coluna 'Em conflito vence' so contem V1 ou V2" {
        $linhas = Get-LinhasTabela -Secao $script:secao
        $ruins = @($linhas | Select-Object -Skip 1 | Where-Object { @('V1', 'V2') -notcontains $_[3] } | ForEach-Object { "$($_[0]) => '$($_[3])'" })
        $ruins | Should -BeNullOrEmpty -Because "valores invalidos: $($ruins -join '; ')"
    }

    Context "fixture: loop novo sem linha na tabela" {

        BeforeAll {
            $script:fixture = Join-Path ([IO.Path]::GetTempPath()) ("migracao-quem-manda-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
            New-Item -ItemType Directory -Path $script:fixture -Force | Out-Null
            Copy-Item -Path (Join-Path $script:kitRoot 'v2') -Destination $script:fixture -Recurse
            [IO.File]::WriteAllText(
                (Join-Path $script:fixture 'v2\loops\loop-novo-fixture.md'),
                "# Loop: novo (fixture)`n",
                (New-Object System.Text.UTF8Encoding($false))
            )
        }

        AfterAll {
            if ($script:fixture -and (Test-Path $script:fixture)) { [IO.Directory]::Delete($script:fixture, $true) }
        }

        It "a copia sem o arquivo novo passa (controle)" {
            [IO.File]::Delete((Join-Path $script:fixture 'v2\loops\loop-novo-fixture.md'))
            try {
                { Assert-Cobertura -KitRoot $script:fixture -Secao $script:secao } | Should -Not -Throw
            } finally {
                [IO.File]::WriteAllText(
                    (Join-Path $script:fixture 'v2\loops\loop-novo-fixture.md'),
                    "# Loop: novo (fixture)`n",
                    (New-Object System.Text.UTF8Encoding($false))
                )
            }
        }

        It "com o arquivo novo, a checagem falha nomeando o arquivo" {
            { Assert-Cobertura -KitRoot $script:fixture -Secao $script:secao } | Should -Throw '*v2/loops/loop-novo-fixture.md*'
        }
    }
}
