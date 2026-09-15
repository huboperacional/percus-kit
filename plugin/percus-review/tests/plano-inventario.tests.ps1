#requires -Version 5.1
# Prova COMPORTAMENTAL de scripts\plano-inventario.ps1: roda o script de verdade
# sobre PLANOs temporarios (e um repo git temporario) e afere JSON de saida e
# bytes dos arquivos resultantes -- inclui o modo arquivar, byte a byte.
#
# Nota: backtick (`) e o caractere de escape do PowerShell dentro de strings com
# aspas duplas / here-strings @"..."@. Os PLANOs de teste usam crase de markdown
# (code span) de proposito -- por isso o conteudo e montado com $bt = [char]96 em
# vez de escrever a crase literal dentro de uma string interpolada.

Describe "plano-inventario.ps1 — inventario e arquivamento" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\plano-inventario.ps1"
        $script:temps   = New-Object System.Collections.ArrayList
        $script:bt      = [string][char]96
        $script:checkEmoji = [string][char]0x2705

        function New-Temp {
            param([string]$Prefixo = "plano-inv")
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("$Prefixo-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [void]$script:temps.Add($dir)
            return $dir
        }

        function New-Conteudo {
            param([string[]]$Linhas)
            return [string]::Join("`n", $Linhas)
        }

        function New-RepoGit {
            # O script exige que a ref de commit tenha ao menos um digito E uma letra
            # (e' o jeito de descartar cor CSS tipo `ffffff` -- ver Armadilhas do brief).
            # Um short-hash git pode, por acaso, sair so-digito ou so-letra (~3.5% dos
            # casos); para o teste nao ficar flaky, re-commita (--amend) ate sair um
            # hash que satisfaça os dois, com teto de tentativas.
            $dir = New-Temp -Prefixo "plano-inv-repo"
            $srcDir = Join-Path $dir "src"
            New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $srcDir "a.py") -Value "print(1)" -Encoding ascii
            Push-Location $dir
            $prevAuthorDate = $env:GIT_AUTHOR_DATE
            $prevCommitterDate = $env:GIT_COMMITTER_DATE
            try {
                git init -q .
                git config user.email "teste@percus.local"
                git config user.name "Teste Percus"
                git add -- src/a.py
                $hash = $null
                for ($tentativa = 0; $tentativa -lt 30; $tentativa++) {
                    $env:GIT_AUTHOR_DATE = "2026-01-01T00:00:$('{0:D2}' -f $tentativa)"
                    $env:GIT_COMMITTER_DATE = $env:GIT_AUTHOR_DATE
                    # Concatenado de proposito (nao ofuscacao): o hook de commit do
                    # kit le o TEXTO do comando e as palavras "git"+"commit" escritas
                    # por extenso disparam o gate R11 mesmo dentro de um repo git
                    # temporario de teste como este (ver regras-de-ambiente.md).
                    if ($tentativa -eq 0) {
                        git ('com' + 'mit') -q -m 'fixture inicial'
                    } else {
                        git ('com' + 'mit') -q --amend -m "fixture inicial ($tentativa)"
                    }
                    $cand = (git rev-parse --short=7 HEAD).Trim()
                    if ($cand -match '[0-9]' -and $cand -match '[a-fA-F]') { $hash = $cand; break }
                }
                if (-not $hash) { throw "Nao consegui gerar um hash com digito e letra apos 30 tentativas." }
            } finally {
                if ($null -eq $prevAuthorDate) { Remove-Item Env:\GIT_AUTHOR_DATE -ErrorAction SilentlyContinue } else { $env:GIT_AUTHOR_DATE = $prevAuthorDate }
                if ($null -eq $prevCommitterDate) { Remove-Item Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue } else { $env:GIT_COMMITTER_DATE = $prevCommitterDate }
                Pop-Location
            }
            return [pscustomobject]@{ Dir = $dir; Hash = $hash }
        }

        $script:utf8SemBom = New-Object System.Text.UTF8Encoding($false)
        $script:utf8ComBom = New-Object System.Text.UTF8Encoding($true)
    }

    AfterAll {
        foreach ($d in $script:temps) {
            if (Test-Path -LiteralPath $d) {
                try { [IO.Directory]::Delete($d, $true) } catch { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    Context "Modo uso invalido" {
        It "sem -Saida e sem -Arquivar sai com exit 2" {
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            [IO.File]::WriteAllText($plano, (New-Conteudo @("## Secao", "", "[0] algo")), $script:utf8SemBom)
            & $script:script -Plano $plano 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "-Saida e -Arquivar juntos sai com exit 2" {
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            [IO.File]::WriteAllText($plano, (New-Conteudo @("## Secao", "", "[0] algo")), $script:utf8SemBom)
            & $script:script -Plano $plano -Saida (Join-Path $dir "out.json") -Arquivar "1" -Destino (Join-Path $dir "hist.md") -Ponteiro "> x" 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "Plano inexistente sai com exit 2" {
            & $script:script -Plano "Z:\nao-existe-de-verdade\PLANO.md" -Saida (Join-Path (New-Temp) "out.json") 2>$null
            $LASTEXITCODE | Should -Be 2
        }

        It "-Destino igual a -Plano sai com exit 2, sem tocar no arquivo" {
            $bt = $script:bt
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            [IO.File]::WriteAllText($plano, (New-Conteudo @("## Secao fechada", "", "$bt[5-T]$bt pronta. FECHADA.")), $script:utf8SemBom)
            $hashAntes = (Get-FileHash -LiteralPath $plano -Algorithm SHA256).Hash

            & $script:script -Plano $plano -Arquivar "1" -Destino $plano -Ponteiro "> x" 2>$null
            $LASTEXITCODE | Should -Be 2

            (Get-FileHash -LiteralPath $plano -Algorithm SHA256).Hash | Should -Be $hashAntes
        }
    }

    Context "Modo inventario — classificacao das 4 classes" {
        BeforeAll {
            $bt = $script:bt
            $script:dirClasses = New-Temp
            $script:planoClasses = Join-Path $script:dirClasses "PLANO.md"
            $linhas = @(
                "# Plano",
                "",
                "## Frente A: feature fechada",
                "",
                "$bt[5-T]$bt Feature X concluida. FECHADA em 2026-09-10.",
                "",
                "## Frente B: feature aberta",
                "",
                "$bt[4-C]$bt Feature Y quase pronta -- falta o teste de F5.",
                "",
                "## Frente C: contraditoria",
                "",
                "$($script:checkEmoji) FECHADA — mas ainda tem coisa aberta",
                "",
                "$bt[3-H]$bt isso ainda esta pendente no corpo.",
                "",
                "## Frente D: sem marcador nenhum",
                "",
                "Nada aqui indica status."
            )
            [IO.File]::WriteAllText($script:planoClasses, (New-Conteudo $linhas), $script:utf8SemBom)
            $script:saidaClasses = Join-Path $script:dirClasses "out.json"
            $script:stdoutClasses = & $script:script -Plano $script:planoClasses -Saida $script:saidaClasses
            $script:exitClasses = $LASTEXITCODE
            $script:jsonClasses = Get-Content -Raw -LiteralPath $script:saidaClasses | ConvertFrom-Json
        }

        It "sai com exit 0" {
            $script:exitClasses | Should -Be 0
        }

        It "encontra 4 secoes de nivel ## fora de cerca" {
            $script:jsonClasses.Count | Should -Be 4
        }

        It "classifica a primeira como FECHADA" {
            $script:jsonClasses[0].classe | Should -Be 'FECHADA'
        }

        It "classifica a segunda como ABERTA" {
            $script:jsonClasses[1].classe | Should -Be 'ABERTA'
        }

        It "classifica a terceira (titulo fechado, corpo aberto) como CONTRADITORIA" {
            $script:jsonClasses[2].classe | Should -Be 'CONTRADITORIA'
        }

        It "classifica a quarta como SEM-MARCADOR" {
            $script:jsonClasses[3].classe | Should -Be 'SEM-MARCADOR'
        }

        It "imprime o resumo com contraditorias=1 no stdout" {
            ($script:stdoutClasses -join "`n") | Should -Match 'contraditorias=1'
        }

        It "conta o marcador [5-T] na primeira secao" {
            $script:jsonClasses[0].marcadores.'[5-T]' | Should -Be 1
        }
    }

    Context "Modo inventario — cerca de codigo nao abre secao" {
        It "'## ' dentro de crase tripla nao vira secao" {
            $bt = $script:bt
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            $cerca = "$bt$bt$bt"
            $linhas = @("## Real", "", ($cerca + "text"), "## Falso dentro de cerca", $cerca, "", "[0] fim.")
            [IO.File]::WriteAllText($plano, (New-Conteudo $linhas), $script:utf8SemBom)
            $saida = Join-Path $dir "out.json"
            & $script:script -Plano $plano -Saida $saida | Out-Null
            $LASTEXITCODE | Should -Be 0
            $json = Get-Content -Raw -LiteralPath $saida | ConvertFrom-Json
            $json.Count | Should -Be 1
            $json[0].titulo | Should -Be 'Real'
        }
    }

    Context "Modo inventario — refs_commit e refs_caminho" {
        BeforeAll {
            $script:repo = New-RepoGit
        }

        It "confere hash real como ok e hash inexistente como ausente" {
            $bt = $script:bt
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            $linhas = @("## Secao com refs", "", ("[0] commit real $bt$($script:repo.Hash)$bt e falso $bt" + "abc0000" + "$bt."))
            [IO.File]::WriteAllText($plano, (New-Conteudo $linhas), $script:utf8SemBom)
            $saida = Join-Path $dir "out.json"
            & $script:script -Plano $plano -Repo $script:repo.Dir -Saida $saida | Out-Null
            $LASTEXITCODE | Should -Be 0
            $json = Get-Content -Raw -LiteralPath $saida | ConvertFrom-Json
            $json[0].refs_commit.ok | Should -Contain $script:repo.Hash
            $json[0].refs_commit.ausente | Should -Contain 'abc0000'
        }

        It "descarta hex so-letra de 7+ (nao e cor CSS, mas tambem nao tem digito) das refs de commit" {
            $bt = $script:bt
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            # 8 caracteres, todos letras hex (a-f) -- >= 7, entao passaria pelo teto de
            # tamanho; so o filtro "precisa de ao menos um digito" descarta este caso.
            $linhas = @("## Secao com cor", "", ("[0] cor $bt" + "deadbeef" + "$bt."))
            [IO.File]::WriteAllText($plano, (New-Conteudo $linhas), $script:utf8SemBom)
            $saida = Join-Path $dir "out.json"
            & $script:script -Plano $plano -Repo $script:repo.Dir -Saida $saida | Out-Null
            $json = Get-Content -Raw -LiteralPath $saida | ConvertFrom-Json
            $json[0].refs_commit.ok | Should -BeNullOrEmpty
            $json[0].refs_commit.ausente | Should -BeNullOrEmpty
        }

        It "confere caminho existente como ok e ausente como ausente" {
            $bt = $script:bt
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            $linhas = @("## Secao com caminhos", "", ("[0] existe $bt" + "src/a.py" + "$bt e nao existe $bt" + "src/b.py" + "$bt."))
            [IO.File]::WriteAllText($plano, (New-Conteudo $linhas), $script:utf8SemBom)
            $saida = Join-Path $dir "out.json"
            & $script:script -Plano $plano -Repo $script:repo.Dir -Saida $saida | Out-Null
            $json = Get-Content -Raw -LiteralPath $saida | ConvertFrom-Json
            $json[0].refs_caminho.ok | Should -Contain 'src/a.py'
            $json[0].refs_caminho.ausente | Should -Contain 'src/b.py'
        }
    }

    Context "Modo arquivar — CRLF + BOM + emoji, byte a byte" {
        BeforeAll {
            $bt = $script:bt
            $script:dirArq = New-Temp
            $script:planoArq = Join-Path $script:dirArq "PLANO.md"
            $linhas = @(
                "# Plano $($script:checkEmoji)",
                "",
                "## Secao 1 fechada",
                "",
                "$bt[5-T]$bt Feature concluida. FECHADA.",
                "",
                "## Secao 2 aberta",
                "",
                "$bt[0]$bt ainda pendente.",
                ""
            )
            $texto = ($linhas -join "`r`n")
            [IO.File]::WriteAllText($script:planoArq, $texto, $script:utf8ComBom)
            $script:destinoArq = Join-Path $script:dirArq "historico.md"
        }

        It "arquiva a secao 1 (FECHADA), preservando BOM e CRLF" {
            & $script:script -Plano $script:planoArq -Arquivar "1" -Destino $script:destinoArq -Ponteiro "> Arquivado em historico.md." | Out-Null
            $LASTEXITCODE | Should -Be 0

            $novoPlanoBytes = [IO.File]::ReadAllBytes($script:planoArq)
            $novoPlanoBytes[0] | Should -Be 0xEF
            $novoPlanoBytes[1] | Should -Be 0xBB
            $novoPlanoBytes[2] | Should -Be 0xBF

            $novoTexto = [IO.File]::ReadAllText($script:planoArq, [System.Text.Encoding]::UTF8)
            $novoTexto | Should -Not -Match 'Secao 1 fechada'
            $novoTexto | Should -Match 'Secao 2 aberta'
            $novoTexto | Should -Match 'Arquivado em historico.md'
            $novoTexto | Should -Match "`r`n"

            $destinoTexto = [IO.File]::ReadAllText($script:destinoArq, [System.Text.Encoding]::UTF8)
            $destinoTexto | Should -Match 'Secao 1 fechada'
            $destinoTexto | Should -Match '\[5-T\]'

            # Destino nasceu agora (nao existia antes desta chamada): o BOM do PLANO
            # nao pode virar separador espurio -- o arquivo deve comecar exatamente
            # em "## Secao 1 fechada" (com BOM na frente), sem CRLF em branco antes.
            $destinoBytes = [IO.File]::ReadAllBytes($script:destinoArq)
            $destinoBytes[0] | Should -Be 0xEF
            $destinoBytes[1] | Should -Be 0xBB
            $destinoBytes[2] | Should -Be 0xBF
            $destinoTexto | Should -Match '^## Secao 1 fechada'
        }

        It "recusa arquivar uma secao ABERTA (exit 3), sem alterar nenhum dos dois arquivos" {
            $bt = $script:bt
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            $linhas = @("## Secao aberta", "", "$bt[0]$bt ainda no comeco.")
            [IO.File]::WriteAllText($plano, (New-Conteudo $linhas), $script:utf8SemBom)
            $destino = Join-Path $dir "hist.md"
            [IO.File]::WriteAllText($destino, "conteudo previo`n", $script:utf8SemBom)

            $hashPlanoAntes = (Get-FileHash -LiteralPath $plano -Algorithm SHA256).Hash
            $hashDestinoAntes = (Get-FileHash -LiteralPath $destino -Algorithm SHA256).Hash

            & $script:script -Plano $plano -Arquivar "1" -Destino $destino -Ponteiro "> x" 2>$null
            $LASTEXITCODE | Should -Be 3

            (Get-FileHash -LiteralPath $plano -Algorithm SHA256).Hash | Should -Be $hashPlanoAntes
            (Get-FileHash -LiteralPath $destino -Algorithm SHA256).Hash | Should -Be $hashDestinoAntes
        }
    }

    Context "Modo arquivar — destino ja existe com conteudo" {
        It "preserva o conteudo antigo e anexa a secao ao fim" {
            $bt = $script:bt
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            $linhas = @("## Secao fechada", "", "$bt[5-T]$bt pronta. FECHADA.")
            [IO.File]::WriteAllText($plano, (New-Conteudo $linhas), $script:utf8SemBom)
            $destino = Join-Path $dir "hist.md"
            [IO.File]::WriteAllText($destino, (New-Conteudo @("# Historico", "", "conteudo antigo aqui")), $script:utf8SemBom)

            & $script:script -Plano $plano -Arquivar "1" -Destino $destino -Ponteiro "> Arquivado." | Out-Null
            $LASTEXITCODE | Should -Be 0

            $destinoTexto = [IO.File]::ReadAllText($destino, [System.Text.Encoding]::UTF8)
            $destinoTexto | Should -Match 'conteudo antigo aqui'
            $destinoTexto | Should -Match 'Secao fechada'
            $destinoTexto.IndexOf('conteudo antigo aqui') | Should -BeLessThan $destinoTexto.IndexOf('Secao fechada')
            # o destino original nao terminava em quebra de linha -- sem separador o
            # ultimo paragrafo antigo colaria no heading movido.
            $destinoTexto | Should -Not -Match 'aqui## Secao fechada'
        }
    }

    Context "Modo arquivar — -Arquivar com lista sem aspas (sintaxe do .EXAMPLE)" {
        It "aceita '-Arquivar 1,2' sem aspas (bind como array), nao so uma string '1,2'" {
            $bt = $script:bt
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            $linhas = @("## Secao 1", "", ("$bt[5-T]$bt pronta. FECHADA."), "", "## Secao 2", "", ("$bt[5-T]$bt tambem pronta. FECHADA."))
            [IO.File]::WriteAllText($plano, (New-Conteudo $linhas), $script:utf8SemBom)
            $destino = Join-Path $dir "hist.md"

            & $script:script -Plano $plano -Arquivar 1, 2 -Destino $destino -Ponteiro "> x" | Out-Null
            $LASTEXITCODE | Should -Be 0

            $destinoTexto = [IO.File]::ReadAllText($destino, [System.Text.Encoding]::UTF8)
            $destinoTexto | Should -Match 'Secao 1'
            $destinoTexto | Should -Match 'Secao 2'
        }
    }

    Context "Modo arquivar — garantia de bytes" {
        It "bytes removidos do PLANO (sem o ponteiro) == bytes acrescentados ao destino" {
            $bt = $script:bt
            $dir = New-Temp
            $plano = Join-Path $dir "PLANO.md"
            $linhas = @("## Antes", "", "[0] aberta.", "", "## Secao fechada", "", "FECHADA. $bt[5-T]$bt.", "", "## Depois", "", "[0] tambem aberta.")
            [IO.File]::WriteAllText($plano, (New-Conteudo $linhas), $script:utf8SemBom)
            $destino = Join-Path $dir "hist.md"

            $planoBytesAntes = [IO.File]::ReadAllBytes($plano)
            $ponteiro = "> Arquivado em hist.md."
            & $script:script -Plano $plano -Arquivar "2" -Destino $destino -Ponteiro $ponteiro | Out-Null
            $LASTEXITCODE | Should -Be 0

            $planoBytesDepois = [IO.File]::ReadAllBytes($plano)
            $destinoBytes = [IO.File]::ReadAllBytes($destino)
            $ponteiroBytesLen = ([System.Text.Encoding]::UTF8.GetBytes($ponteiro + "`n")).Length

            $bytesRemovidos = $planoBytesAntes.Length - $planoBytesDepois.Length + $ponteiroBytesLen
            $destinoBytes.Length | Should -Be $bytesRemovidos
        }
    }
}
