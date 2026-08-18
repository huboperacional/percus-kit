#requires -Version 5.1
# Prova COMPORTAMENTAL do gate de versao: monta repo git temporario com ref
# origin/main de verdade e roda o gate real.
#
# O que este gate resolve: os 6 testes de version-alignment provam que os 4
# arquivos CONCORDAM -- e 6.35.0 nos quatro, com template novo dentro, concorda
# e mente. Faltava o GATILHO. A comparacao e contra origin/main (nao contra "o
# cabecalho mudou neste commit"), senao todo commit da mesma versao exigiria
# bump novo.

Describe "percus-gate.sh — bump de versao do kit" {
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

        function Cabecalho { param([string]$V) return "# Canon`n`n**Versao canonica em ``x``:** ``$V``  `n" }

        # Repo com CANON_VERSION.md commitado e ref origin/main apontando pra esse commit.
        function New-CanonRepo {
            param([string]$Versao = "6.35.0", [switch]$SemCanon, [switch]$SemOrigin)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("gate-versao-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [void]$script:temps.Add($dir)

            & git -C $dir init -q 2>&1 | Out-Null
            & git -C $dir config user.email "t@t.t" 2>&1 | Out-Null
            & git -C $dir config user.name  "t"     2>&1 | Out-Null

            $utf8 = New-Object System.Text.UTF8Encoding($false)
            if (-not $SemCanon) {
                [IO.File]::WriteAllText((Join-Path $dir "CANON_VERSION.md"), (Cabecalho $Versao), $utf8)
            }
            [IO.File]::WriteAllText((Join-Path $dir "leiame.md"), "base`n", $utf8)
            & git -C $dir add -A 2>&1 | Out-Null
            & git -C $dir commit -q -m base 2>&1 | Out-Null
            if (-not $SemOrigin) {
                & git -C $dir update-ref refs/remotes/origin/main HEAD 2>&1 | Out-Null
            }
            return $dir
        }

        function Add-Staged {
            param([string]$Repo, [string]$Caminho, [string]$Conteudo = "x")
            $full = Join-Path $Repo $Caminho
            New-Item -ItemType Directory -Path (Split-Path $full) -Force | Out-Null
            [IO.File]::WriteAllText($full, "$Conteudo`n", (New-Object System.Text.UTF8Encoding($false)))
            & git -C $Repo add -- $Caminho 2>&1 | Out-Null
        }

        function Set-Versao {
            param([string]$Repo, [string]$V, [switch]$SemStage)
            [IO.File]::WriteAllText((Join-Path $Repo "CANON_VERSION.md"), (Cabecalho $V), (New-Object System.Text.UTF8Encoding($false)))
            if (-not $SemStage) { & git -C $Repo add -- CANON_VERSION.md 2>&1 | Out-Null }
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

    It "BARRA template novo numa versao que ja esta em origin/main" {
        $repo = New-CanonRepo -Versao "6.35.0"
        Add-Staged -Repo $repo -Caminho "templates/novo/coisa.ts"

        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "6.35.0 ja foi empurrada. Saida: $($r.Saida)"
        $r.Saida | Should -Match 'versao|bump'
    }

    It "BARRA mudanca em plugin/ sem bump" {
        $repo = New-CanonRepo -Versao "6.35.0"
        Add-Staged -Repo $repo -Caminho "plugin/percus-review/hooks/x.ps1"

        (Invoke-Gate -Repo $repo).Exit | Should -Be 1
    }

    It "BARRA mudanca em documento numerado do canon sem bump" {
        $repo = New-CanonRepo -Versao "6.35.0"
        Add-Staged -Repo $repo -Caminho "01_REGRAS_INEGOCIAVEIS.md" -Conteudo "# regras"

        (Invoke-Gate -Repo $repo).Exit | Should -Be 1
    }

    It "PASSA quando o bump acompanha a mudanca" {
        $repo = New-CanonRepo -Versao "6.35.0"
        Add-Staged -Repo $repo -Caminho "templates/novo/coisa.ts"
        Set-Versao -Repo $repo -V "6.36.0"

        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "bumpou junto. Saida: $($r.Saida)"
    }

    It "PASSA em commit seguinte da MESMA versao ja bumpada (nao exige bump por commit)" {
        # origin/main ficou em 6.35.0; o repo local ja esta em 6.36.0 de um commit
        # anterior. Segundo commit tocando templates/ nao pode exigir 6.37.0.
        $repo = New-CanonRepo -Versao "6.35.0"
        Set-Versao -Repo $repo -V "6.36.0"
        & git -C $repo commit -q -m bump 2>&1 | Out-Null
        Add-Staged -Repo $repo -Caminho "templates/novo/outra.ts"

        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "a versao local ja avancou em relacao a origin/main. Saida: $($r.Saida)"
    }

    It "BARRA mudanca em scripts/ sem bump" {
        # scripts/ e kit que os projetos consomem via PERCUS_CANON_DIR -- ficou de
        # fora do padrao na primeira versao desta checagem, e o proprio commit que
        # criou scripts/bump-canon.ps1 teria escapado.
        $repo = New-CanonRepo -Versao "6.35.0"
        Add-Staged -Repo $repo -Caminho "scripts/coisa.ps1"

        (Invoke-Gate -Repo $repo).Exit | Should -Be 1
    }

    It "BARRA quando a versao local esta ATRAS de origin/main" {
        # Igualdade nao basta: repo atrasado em relacao ao remoto tambem esta
        # commitando conteudo novo numa versao ja publicada.
        $repo = New-CanonRepo -Versao "6.36.0"
        Set-Versao -Repo $repo -V "6.35.0"
        Add-Staged -Repo $repo -Caminho "templates/novo/coisa.ts"

        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "6.35.0 e anterior a 6.36.0 que ja esta no remoto. Saida: $($r.Saida)"
    }

    It "BARRA bump que ficou no working tree e nao entrou no commit" {
        # Ler o working tree em vez do indice deixa passar o pior caso: bumpar,
        # esquecer o git add do CANON_VERSION.md, e commitar o kit sem o bump --
        # o historico de main fica com conteudo novo em versao velha.
        $repo = New-CanonRepo -Versao "6.35.0"
        Add-Staged -Repo $repo -Caminho "templates/novo/coisa.ts"
        Set-Versao -Repo $repo -V "6.36.0" -SemStage

        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "o bump nao entra no commit. Saida: $($r.Saida)"
    }

    It "BARRA quando CANON_VERSION.md existe no disco mas saiu do indice" {
        # `git rm --cached CANON_VERSION.md` deixaria `git show :CANON_VERSION.md`
        # falhar calado, a versao vazia, e a checagem inteira pulada -- um jeito
        # silencioso de desligar o gate.
        $repo = New-CanonRepo -Versao "6.35.0"
        Add-Staged -Repo $repo -Caminho "templates/novo/coisa.ts"
        & git -C $repo rm --cached -q -- CANON_VERSION.md 2>&1 | Out-Null

        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "arquivo de versao fora do indice e violacao, nao motivo pra pular. Saida: $($r.Saida)"
    }

    It "BARRA quando CANON_VERSION.md e REMOVIDO no proprio commit" {
        # Mesma classe da anterior por outra porta: `git rm` apaga do disco e do
        # indice, entao um guard baseado em [ -f ] pularia a checagem inteira.
        # Por isso o gatilho e "origin/main tem CANON_VERSION.md", nao "o arquivo
        # existe aqui" -- quem decide se este repo e o canon e o remoto.
        $repo = New-CanonRepo -Versao "6.35.0"
        Add-Staged -Repo $repo -Caminho "templates/novo/coisa.ts"
        & git -C $repo rm -q -- CANON_VERSION.md 2>&1 | Out-Null

        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "apagar o arquivo de versao nao pode desligar o gate. Saida: $($r.Saida)"
    }

    It "NAO dispara para conhecimento/ (cresce toda hora, nao e versao do kit)" {
        $repo = New-CanonRepo -Versao "6.35.0"
        # Verbete VALIDO no layout da 6.38.0 (<area>/<slug>.md, com ancora e tags:). A fixture
        # antiga usava 'conhecimento/nota.md', solto na raiz -- que o bloco 2e passou a acusar,
        # e com razao. O teste afere o gate de VERSAO, entao a fixture nao pode violar OUTRA
        # regra: senao ele passaria (ou falharia) pelo motivo errado.
        Add-Staged -Repo $repo -Caminho "conhecimento/resolver/nota.md" `
                   -Conteudo "## So uma nota {#nota}`n`n``tags: nota``n`ncorpo."

        (Invoke-Gate -Repo $repo).Exit | Should -Be 0
    }

    It "NAO dispara em repo de projeto (sem CANON_VERSION.md)" {
        $repo = New-CanonRepo -SemCanon
        Add-Staged -Repo $repo -Caminho "templates/novo/coisa.ts"

        (Invoke-Gate -Repo $repo).Exit | Should -Be 0
    }

    It "NAO dispara sem ref origin/main (clone sem remoto nao pode travar commit)" {
        $repo = New-CanonRepo -Versao "6.35.0" -SemOrigin
        Add-Staged -Repo $repo -Caminho "templates/novo/coisa.ts"

        (Invoke-Gate -Repo $repo).Exit | Should -Be 0
    }
}
