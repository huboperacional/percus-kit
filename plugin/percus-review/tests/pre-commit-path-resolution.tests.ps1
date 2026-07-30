#requires -Version 5.1
# Tests: pre-commit-check.ps1 resolve o repo target de comandos vindos do git-bash.
#
# Dois defeitos encontrados em 2026-07-27, rodando o proprio gate do kit:
#
#   1. `cd "/d/Claud Automations/repo" && git commit` — o path MSYS ia direto pro git do
#      Windows (exit 128), o hook caia no fallback e procurava review em
#      '\d\Claud Automations\repo\.deepseek\reviews'. Bloqueava commit que TINHA review.
#   2. `git -c commit.gpgsign=false commit` — o -match do PowerShell e case-insensitive,
#      entao o '-c' casava no padrao de '-C <dir>' e o repo target virava
#      'commit.gpgsign=false'.
#
# Os dois bloqueiam commit legitimo (falham pro lado seguro), mas atrito assim e o que
# ensina a usar PERCUS_HOOKS_DISABLED — e ai o gate deixa de existir de verdade.
#
# O twin .sh NAO tem nenhum dos dois: usa sed (ERE case-sensitive) e roda com path MSYS
# nativo. Por isso estes testes sao so do .ps1.

Describe "pre-commit-check.ps1 — resolucao do repo target" {
    BeforeAll {
        $script:hookPs1   = Join-Path $PSScriptRoot ".." "hooks" "pre-commit-check.ps1"
        $script:tempDirs  = New-Object System.Collections.ArrayList

        # Repo temporario com marker de review. -AgeMinutes envelhece o marker.
        function New-RepoWithReview {
            param([switch]$NoReview, [double]$AgeMinutes = 0)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-hook-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Push-Location $dir
            try { & git init -q . 2>$null } finally { Pop-Location }
            if (-not $NoReview) {
                $rev = Join-Path $dir ".deepseek\reviews"
                New-Item -ItemType Directory -Path $rev -Force | Out-Null
                $marker = Join-Path $rev "latest.jsonl"
                [IO.File]::WriteAllText($marker, '{"findings":"Sem findings criticos."}', (New-Object System.Text.UTF8Encoding($false)))
                if ($AgeMinutes -gt 0) {
                    (Get-Item $marker).LastWriteTime = (Get-Date).AddMinutes(-$AgeMinutes)
                }
            }
            return $dir
        }

        # 'C:\Users\x\Temp\r' -> '/c/Users/x/Temp/r' (forma que o git-bash entrega)
        function ConvertTo-MsysPath {
            param([string]$WinPath)
            if ($WinPath -match '^([a-zA-Z]):\\(.*)$') {
                return "/" + $matches[1].ToLower() + "/" + ($matches[2] -replace '\\', '/')
            }
            return $WinPath
        }

        function Invoke-Hook {
            param([string]$Command, [string]$WorkingDir)
            $stdin = @{ tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
            if ($WorkingDir) { Push-Location $WorkingDir }
            try {
                $stdin | & pwsh -NoProfile -File $script:hookPs1 *>$null
                return $LASTEXITCODE
            } finally { if ($WorkingDir) { Pop-Location } }
        }
    }

    AfterAll {
        foreach ($d in $script:tempDirs) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue }
    }

    Context "Defeito 1: path MSYS do git-bash" {
        It "libera commit com path MSYS quando o review esta fresco" {
            $repo = New-RepoWithReview
            [void]$script:tempDirs.Add($repo)
            $msys = ConvertTo-MsysPath $repo
            $msys | Should -Match '^/[a-z]/' -Because "o teste precisa mesmo exercitar a forma MSYS"
            Invoke-Hook -Command "cd `"$msys`" && git commit -m x" |
                Should -Be 0 -Because "review existe e esta fresco; bloquear aqui e falso positivo"
        }

        It "AINDA bloqueia path MSYS quando o repo target nao tem review" {
            $repo = New-RepoWithReview -NoReview
            [void]$script:tempDirs.Add($repo)
            $msys = ConvertTo-MsysPath $repo
            Invoke-Hook -Command "cd `"$msys`" && git commit -m x" |
                Should -Be 2 -Because "normalizar o path nao pode virar bypass"
        }

        It "AINDA bloqueia path MSYS quando o review esta velho (>5 min)" {
            $repo = New-RepoWithReview -AgeMinutes 30
            [void]$script:tempDirs.Add($repo)
            $msys = ConvertTo-MsysPath $repo
            Invoke-Hook -Command "cd `"$msys`" && git commit -m x" | Should -Be 2
        }
    }

    Context "Defeito 2: '-c config' confundido com '-C dir'" {
        It "libera 'git -c commit.gpgsign=false commit' com review fresco no cwd" {
            $repo = New-RepoWithReview
            [void]$script:tempDirs.Add($repo)
            Invoke-Hook -Command "git -c commit.gpgsign=false commit -m x" -WorkingDir $repo |
                Should -Be 0 -Because "'-c' e config, nao diretorio: o target e o cwd"
        }

        It "AINDA bloqueia 'git -c ... commit' quando o cwd nao tem review" {
            $repo = New-RepoWithReview -NoReview
            [void]$script:tempDirs.Add($repo)
            Invoke-Hook -Command "git -c commit.gpgsign=false commit -m x" -WorkingDir $repo | Should -Be 2
        }
    }

    Context "Nao-regressao: '-C dir' maiusculo continua sendo o repo target" {
        It "usa o repo do '-C', nao o cwd (review fresco no target)" {
            $target = New-RepoWithReview
            $other  = New-RepoWithReview -NoReview
            [void]$script:tempDirs.Add($target); [void]$script:tempDirs.Add($other)
            Invoke-Hook -Command "git -C `"$target`" commit -m x" -WorkingDir $other |
                Should -Be 0 -Because "o commit e no target, que tem review"
        }

        It "bloqueia quando o repo do '-C' e que nao tem review (mesmo com cwd revisado)" {
            $target = New-RepoWithReview -NoReview
            $other  = New-RepoWithReview
            [void]$script:tempDirs.Add($target); [void]$script:tempDirs.Add($other)
            Invoke-Hook -Command "git -C `"$target`" commit -m x" -WorkingDir $other |
                Should -Be 2 -Because "review do cwd nao vale pro repo target"
        }
    }

    Context "Nao-regressao: o que sempre passou continua passando" {
        It "comando que nao e commit passa direto" {
            $repo = New-RepoWithReview -NoReview
            [void]$script:tempDirs.Add($repo)
            Invoke-Hook -Command "git status --short" -WorkingDir $repo | Should -Be 0
        }

        It "'git commit --amend --no-edit' passa (rebase)" {
            $repo = New-RepoWithReview -NoReview
            [void]$script:tempDirs.Add($repo)
            Invoke-Hook -Command "git commit --amend --no-edit" -WorkingDir $repo | Should -Be 0
        }
    }
}
