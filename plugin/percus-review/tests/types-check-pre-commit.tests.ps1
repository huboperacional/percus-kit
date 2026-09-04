#requires -Version 5.1
# Testes do hook types-check-pre-commit (R5).
#
# Devolutiva Plexco Tasks (2026-09-04): o hook so procurava tsconfig.json/.venv na
# RAIZ do projeto, entao pulava em silencio (skip sem aviso) em monorepo com
# frontend/backend em subpasta. Custou 5 dias de CI vermelho la (erro de tipo que
# deveria ter sido barrado no commit passou batido).
#
# Fix: acha o tsconfig.json/.venv mais proximo subindo a arvore a partir de CADA
# arquivo staged (para em ProjectRoot). Se sobrar staged sem match -> aviso AUDIVEL
# (nao bloqueia -- o hook continua best-effort), nunca mais silencio puro.

Describe "types-check-pre-commit hook (R5 -- monorepo tsconfig/.venv discovery)" {
    BeforeAll {
        $script:hook = Join-Path $PSScriptRoot ".." "hooks" "types-check-pre-commit.ps1"

        function New-TypesCheckRepo {
            $repo = Join-Path ([IO.Path]::GetTempPath()) "typecheck-test-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $repo | Out-Null
            & git -C $repo init -q
            & git -C $repo config user.email "t@t.t"
            & git -C $repo config user.name "t"
            & git -C $repo config commit.gpgsign false
            return $repo
        }

        function Add-FakeTsc {
            # Stub de tsc: acha *.ts/*.tsx com o marcador PERCUS-FAKE-ERROR-AQUI sob $Dir
            # e reporta erro TS9999, no MESMO formato do tsc real: path relativo ao CWD de
            # invocacao, com '/' -- confirmado empiricamente contra TypeScript real
            # instalado via npm (nao chutado): `tsc -p <subpasta>/tsconfig.json` chamado da
            # RAIZ do projeto emite paths relativos A RAIZ com barra normal, nao nativos do
            # Windows. Um stub que usasse `for /r` (path nativo, backslash) mentiria sobre
            # o formato real e o teste passaria/falharia pelo motivo errado.
            param([string]$Dir)
            $binDir = Join-Path $Dir "node_modules\.bin"
            New-Item -ItemType Directory -Force -Path $binDir | Out-Null
            $stub = Join-Path $binDir "tsc.cmd"
            @'
@echo off
powershell -NoProfile -Command "$root=(Get-Location).Path; Get-ChildItem -Path '%~dp0..\..' -Recurse -Include *.ts,*.tsx | ForEach-Object { if ((Get-Content $_.FullName -Raw) -match 'PERCUS-FAKE-ERROR-AQUI') { $rel = $_.FullName.Substring($root.Length+1) -replace '\\','/'; Write-Output ('{0}(1,7): error TS9999: fake type error' -f $rel) } }"
exit /b 1
'@ | Set-Content -Path $stub -Encoding ascii
        }

        # Sem stub de mypy.exe: nao da pra fabricar um .exe funcional em Pester puro
        # (precisaria de Python real ou um binario de verdade). A descoberta do mypy usa
        # o MESMO helper (Find-PercusNearestConfigDir) que o tsc, entao a cobertura de
        # integracao do tsc acima + os testes de unidade do helper abaixo bastam: o unico
        # codigo NAO-compartilhado que o mypy tem e resolver ".venv\Scripts\mypy.exe"
        # dentro do dir achado, que e trivial (Join-Path + Test-Path, sem logica nova).

        function Invoke-TypesCheck {
            param([string]$Repo, [string]$Message = "feat: x")
            $cmd = "cd `"$Repo`" && git commit -m `"$Message`""
            $stdin = @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            $out = $stdin | & pwsh -NoProfile -File $script:hook 2>&1
            return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
        }

        $enc = New-Object System.Text.UTF8Encoding($false)
    }

    It "existe" {
        Test-Path $hook | Should -Be $true
    }

    Context "monorepo: tsconfig.json numa subpasta (frontend/), nao na raiz" {
        It "acha o tsconfig da subpasta e BLOQUEIA no erro de tipo (nao pula mais em silencio)" {
            $repo = New-TypesCheckRepo
            try {
                $frontend = Join-Path $repo "frontend"
                New-Item -ItemType Directory -Force -Path (Join-Path $frontend "src") | Out-Null
                Set-Content -Path (Join-Path $frontend "tsconfig.json") -Value '{}' -Encoding utf8
                Add-FakeTsc -Dir $frontend
                [IO.File]::WriteAllText((Join-Path $frontend "src\x.ts"), "// PERCUS-FAKE-ERROR-AQUI`nconst x = 1;", $enc)

                & git -C $repo add -A
                $r = Invoke-TypesCheck -Repo $repo

                $r.Code | Should -Be 2 -Because "ha tsconfig achavel (so nao esta na raiz) -- isto NAO e mais skip legitimo"
                $r.Out | Should -Match "tsc ::"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "raiz SEM tsconfig e SEM subpasta com tsconfig -> aviso AUDIVEL, exit 0 (skip legitimo, mas falado)" {
            $repo = New-TypesCheckRepo
            try {
                New-Item -ItemType Directory -Force -Path (Join-Path $repo "src") | Out-Null
                [IO.File]::WriteAllText((Join-Path $repo "src\x.ts"), "const x = 1;", $enc)
                & git -C $repo add -A
                $r = Invoke-TypesCheck -Repo $repo

                $r.Code | Should -Be 0 -Because "sem tsconfig em lugar nenhum, best-effort continua sendo best-effort"
                $r.Out | Should -Match "(?i)AVISO.*tsconfig"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }
    }

    Context "regressao: layout raiz continua funcionando (nao quebrar o caso simples)" {
        It "tsconfig.json na raiz, como antes -> continua bloqueando no erro" {
            $repo = New-TypesCheckRepo
            try {
                Set-Content -Path (Join-Path $repo "tsconfig.json") -Value '{}' -Encoding utf8
                Add-FakeTsc -Dir $repo
                New-Item -ItemType Directory -Force -Path (Join-Path $repo "src") | Out-Null
                [IO.File]::WriteAllText((Join-Path $repo "src\x.ts"), "// PERCUS-FAKE-ERROR-AQUI`nconst x = 1;", $enc)
                & git -C $repo add -A
                $r = Invoke-TypesCheck -Repo $repo

                $r.Code | Should -Be 2
                $r.Out | Should -Match "tsc ::"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "sem nenhum .ts/.tsx staged -> nunca fala nada, exit 0" {
            $repo = New-TypesCheckRepo
            try {
                [IO.File]::WriteAllText((Join-Path $repo "README.md"), "oi", $enc)
                & git -C $repo add -A
                $r = Invoke-TypesCheck -Repo $repo
                $r.Code | Should -Be 0
                $r.Out | Should -BeNullOrEmpty
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }
    }

    Context "seguranca: walk-up de busca do tsc nao escapa do ProjectRoot (achado no code-review)" {
        It "projectRoot CRU (barra normal, formato nao-canonico) nao impede a comparacao de bater -- nao pega tsc.cmd de FORA do repo" {
            # Reproduz o achado do review: Find-PercusNearestConfigDir devolve path
            # RESOLVIDO (Resolve-Path), mas o walk-up de busca do tsc comparava contra
            # $projectRoot CRU (a string literal do `cd "..."`). Um `cd` com barra normal
            # (formato valido no Windows, mas diferente do que Resolve-Path devolve) forca
            # o mismatch que fazia a comparacao nunca bater.
            #
            # Sandbox EXCLUSIVO (nao usa New-TypesCheckRepo, que cria direto em $TEMP): o
            # "vizinho de fora" fica em $sandbox/node_modules, nao na raiz do TEMP
            # compartilhado -- outro processo/teste concorrente pode ter algo la.
            $sandbox = Join-Path ([IO.Path]::GetTempPath()) "tscboundary-$(Get-Random)"
            $repo = Join-Path $sandbox "repo"
            New-Item -ItemType Directory -Force -Path $repo | Out-Null
            try {
                & git -C $repo init -q
                & git -C $repo config user.email "t@t.t"
                & git -C $repo config user.name "t"
                & git -C $repo config commit.gpgsign false

                # tsc.cmd "vizinho", FORA do repo (em $sandbox, um nivel acima) -- se o
                # walk-up escapar da raiz, acha este e o usa. A prova de execucao e um
                # ARQUIVO gravado em disco (efeito colateral direto), NAO o texto do erro:
                # a saida do hook filtra linhas de erro que nao mencionam um arquivo staged
                # (ver o segundo Where-Object do bloco tsc), entao um marcador SO no texto
                # do erro seria descartado mesmo que o binario de fora tivesse rodado --
                # gerando um teste que passa pelo motivo errado (achado rodando este proprio
                # teste sem a correcao: deu verde por este defeito, nao porque a fronteira
                # segurava).
                $flag = Join-Path $sandbox "FOI-EXECUTADO.flag"
                $outsideBin = Join-Path $sandbox "node_modules\.bin"
                New-Item -ItemType Directory -Force -Path $outsideBin | Out-Null
                @"
@echo off
echo. > "$flag"
echo PERCUS-TSC-DE-FORA-DO-REPO-FOI-USADO(1,1): error TS0000: vazamento de fronteira
exit /b 1
"@ | Set-Content -Path (Join-Path $outsideBin "tsc.cmd") -Encoding ascii

                # tsconfig numa subpasta, SEM tsc.cmd em lugar nenhum DENTRO do repo --
                # forca o walk-up a subir ate a raiz sem achar nada la dentro.
                $frontend = Join-Path $repo "frontend"
                New-Item -ItemType Directory -Force -Path (Join-Path $frontend "src") | Out-Null
                Set-Content -Path (Join-Path $frontend "tsconfig.json") -Value '{}' -Encoding utf8
                [IO.File]::WriteAllText((Join-Path $frontend "src\x.ts"), "const x = 1;", $enc)
                & git -C $repo add -A

                # cd com BARRA NORMAL (formato diferente do que Resolve-Path devolveria).
                $repoForwardSlash = $repo.Replace('\', '/')
                $cmd = "cd `"$repoForwardSlash`" && git commit -m `"feat: x`""
                $stdin = @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress

                $job = Start-Job -ScriptBlock {
                    param($h, $s)
                    $s | & pwsh -NoProfile -File $h 2>&1
                } -ArgumentList $script:hook, $stdin
                $done = Wait-Job $job -Timeout 20
                if (-not $done) {
                    Stop-Job $job; Remove-Job $job -Force
                    throw "hook nao terminou em 20s -- walk-up pode ter escapado em loop (o .sh irmao tem o mesmo risco, la SEM saida garantida)"
                }
                Remove-Job $job -Force

                Test-Path $flag | Should -Be $false -Because "o tsc de fora do repo NUNCA deveria ser EXECUTADO -- walk-up tem que parar em ProjectRoot (checa o arquivo que o binario externo grava ao rodar, nao o texto do erro: esse e filtrado pelo match de staged-file antes de chegar na saida do hook, entao provaria pouco)"
            } finally {
                Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Find-PercusNearestConfigDir (helper de descoberta monorepo)" {
    BeforeAll {
        . (Join-Path $PSScriptRoot ".." "hooks" "_helpers.ps1")
    }

    It "acha o marker numa subpasta a partir de um arquivo dentro dela" {
        $repo = Join-Path ([IO.Path]::GetTempPath()) "findup-test-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path (Join-Path $repo "frontend\src\deep") | Out-Null
        New-Item -ItemType File -Force -Path (Join-Path $repo "frontend\tsconfig.json") | Out-Null
        try {
            $got = Find-PercusNearestConfigDir -ProjectRoot $repo -RelativeFile "frontend/src/deep/x.ts" -Marker "tsconfig.json"
            $got | Should -Be (Join-Path $repo "frontend")
        } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
    }

    It "acha o marker na propria raiz (layout simples, regressao)" {
        $repo = Join-Path ([IO.Path]::GetTempPath()) "findup-test-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path (Join-Path $repo "src") | Out-Null
        New-Item -ItemType File -Force -Path (Join-Path $repo "tsconfig.json") | Out-Null
        try {
            $got = Find-PercusNearestConfigDir -ProjectRoot $repo -RelativeFile "src/x.ts" -Marker "tsconfig.json"
            $got | Should -Be $repo
        } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
    }

    It "devolve `$null quando o marker nao existe ate a raiz (nunca sobe alem de ProjectRoot)" {
        $repo = Join-Path ([IO.Path]::GetTempPath()) "findup-test-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path (Join-Path $repo "src") | Out-Null
        try {
            $got = Find-PercusNearestConfigDir -ProjectRoot $repo -RelativeFile "src/x.ts" -Marker "tsconfig.json"
            $got | Should -Be $null
        } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
    }

    It "para dois projetos irmaos (frontend/ e backend/), cada arquivo acha o SEU marker, nao o do irmao" {
        $repo = Join-Path ([IO.Path]::GetTempPath()) "findup-test-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path (Join-Path $repo "frontend\src") | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $repo "backend\app") | Out-Null
        New-Item -ItemType File -Force -Path (Join-Path $repo "frontend\tsconfig.json") | Out-Null
        try {
            $got = Find-PercusNearestConfigDir -ProjectRoot $repo -RelativeFile "backend/app/x.ts" -Marker "tsconfig.json"
            $got | Should -Be $null -Because "backend/ nao tem tsconfig.json, so frontend/ tem"
        } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
    }
}
