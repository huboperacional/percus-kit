#requires -Version 5.1
# Testes do ponto 30: percus-worktree-limpar.ps1. Cada teste monta um repo git TEMPORARIO
# proprio (git init + worktree add/lock) -- nunca toca o repo do kit. Sem
# $ErrorActionPreference='Stop': `git worktree add`/`lock` escrevem no caminho normal em
# stderr, e Stop transformaria isso em excecao (ver regras-de-ambiente.md).

Describe "percus-worktree-limpar.ps1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\percus-worktree-limpar.ps1"
        $script:temps   = New-Object System.Collections.ArrayList

        function New-RepoFixture {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("wtlimpar-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [void]$script:temps.Add($dir)

            & git -C $dir init --quiet 2>&1 | Out-Null
            & git -C $dir config core.autocrlf false 2>&1 | Out-Null
            & git -C $dir config user.email "teste@percus.local" 2>&1 | Out-Null
            & git -C $dir config user.name "Teste Percus" 2>&1 | Out-Null
            "conteudo" | Out-File -FilePath (Join-Path $dir "arquivo.txt") -Encoding ascii
            & git -C $dir add -- arquivo.txt 2>&1 | Out-Null
            & git -C $dir ('com' + 'mit') '-q' '-m' 'inicial' 2>&1 | Out-Null

            return $dir
        }

        function New-ProcessoMorto {
            $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "exit" -PassThru -WindowStyle Hidden
            $p.WaitForExit()
            return $p.Id
        }

        function Remove-RepoFixture {
            param([string]$Dir)
            & git -C $Dir worktree list --porcelain 2>&1 | Out-Null
            $wts = & git -C $Dir worktree list --porcelain 2>&1 |
                Where-Object { $_ -like "worktree *" } |
                ForEach-Object { $_.Substring("worktree ".Length) } |
                Where-Object { $_ -ne $Dir -and ($_.TrimEnd('\', '/')) -ne $Dir.TrimEnd('\', '/') }
            foreach ($wt in $wts) {
                & git -C $Dir worktree remove --force -- $wt 2>&1 | Out-Null
            }
        }
    }

    AfterAll {
        foreach ($d in $script:temps) {
            try { Remove-RepoFixture -Dir $d } catch {}
            Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
        }
    }

    It "trava com pid de processo ja morto: lista 'pid N morto'; -Destravar destrava (exit 0) e some o locked" {
        $repo = New-RepoFixture
        $pidMorto = New-ProcessoMorto
        $wt = Join-Path $repo "wt-morto"

        & git -C $repo worktree add -q -b wt-morto-branch $wt 2>&1 | Out-Null
        & git -C $repo worktree lock $wt --reason "claude session (pid $pidMorto)" 2>&1 | Out-Null

        $linhas = & $script:script -Repo $repo
        $LASTEXITCODE | Should -Be 0
        ($linhas | Where-Object { $_ -like "*wt-morto*" }) | Should -Match ([regex]::Escape("pid $pidMorto morto"))

        & $script:script -Repo $repo -Destravar "wt-morto" | Out-Null
        $LASTEXITCODE | Should -Be 0

        $porcelain = & git -C $repo worktree list --porcelain 2>&1
        ($porcelain -join "`n") | Should -Not -Match "locked"
    }

    It "trava com o PID do proprio teste (vivo): -Destravar recusa (exit 3) e continua locked" {
        $repo = New-RepoFixture
        $wt = Join-Path $repo "wt-vivo"
        $pidVivo = $PID

        & git -C $repo worktree add -q -b wt-vivo-branch $wt 2>&1 | Out-Null
        & git -C $repo worktree lock $wt --reason "claude session (pid $pidVivo)" 2>&1 | Out-Null

        & $script:script -Repo $repo -Destravar "wt-vivo" | Out-Null
        $LASTEXITCODE | Should -Be 3

        $porcelain = & git -C $repo worktree list --porcelain 2>&1
        ($porcelain -join "`n") | Should -Match "locked"
    }

    It "trava sem pid (--reason manual): lista 'sem-pid'; -Destravar recusa (exit 3)" {
        $repo = New-RepoFixture
        $wt = Join-Path $repo "wt-manual"

        & git -C $repo worktree add -q -b wt-manual-branch $wt 2>&1 | Out-Null
        & git -C $repo worktree lock $wt --reason "manual" 2>&1 | Out-Null

        $linhas = & $script:script -Repo $repo
        ($linhas | Where-Object { $_ -like "*wt-manual*" }) | Should -Match "sem-pid"

        & $script:script -Repo $repo -Destravar "wt-manual" | Out-Null
        $LASTEXITCODE | Should -Be 3
    }

    It "worktree em pasta com espaco: caminho completo aparece na linha" {
        $repo = New-RepoFixture
        $wt = Join-Path $repo "wt com espaco"

        & git -C $repo worktree add -q -b "wt-espaco-branch" -- $wt 2>&1 | Out-Null

        $linhas = & $script:script -Repo $repo
        ($linhas | Where-Object { $_ -like "*wt com espaco*" }) | Should -Not -BeNullOrEmpty
    }

    It "-Destravar inexistente: exit 2" {
        $repo = New-RepoFixture

        & $script:script -Repo $repo -Destravar "nao-existe-worktree" | Out-Null
        $LASTEXITCODE | Should -Be 2
    }

    It "sem -Destravar: worktree nao travado mostra 'trava: nenhuma' e 'sem-pid'" {
        $repo = New-RepoFixture

        $repoLeaf = Split-Path -Path $repo -Leaf
        $linhas = & $script:script -Repo $repo
        ($linhas | Where-Object { $_ -like "*$repoLeaf*" }) | Should -Match "trava: nenhuma"
        ($linhas | Where-Object { $_ -like "*$repoLeaf*" }) | Should -Match "sem-pid"
    }
}
