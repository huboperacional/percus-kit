#requires -Version 5.1
# Tests: caminhos sensiveis do router — baseline unico (scripts/sensitive-paths.txt)
# + extensao por projeto (.percus-review.json na raiz do repo revisado).
#
# Cobre dois incidentes:
#   2026-05-18 (Plexco Tasks) — alembic/versions fora da lista.
#   2026-07-27 (Melhoria na VPS) — projeto tooling/infra cujo "sensivel" se chama
#     execution/ e lib/*_client.py: o router rebaixava pra deepseek e o dual, rodado
#     na mao, achou 2 bugs que iriam pro commit.
#
# Por que estes testes mudaram de forma: a versao anterior raspava as regex do FONTE
# .ps1 com [regex]::Matches($content, "'(\([^']+\)[^']*)'"). Isso (a) so enxergava o
# .ps1, nunca o .sh — a divergencia entre os dois era invisivel; e (b) o padrao literal
# '^\.env' nao comeca com "(", entao nunca foi capturado nem testado. Agora os testes
# leem o MESMO arquivo que os dois routers leem, e ha teste de paridade entre eles.

Describe "sensitive paths — baseline unico + extensao por projeto" {
    BeforeAll {

# Helpers: em Pester 5 precisam ser definidos DENTRO do BeforeAll — codigo de topo
# do arquivo so roda na fase Discovery e some na fase Run.
function Get-BaselinePatterns {
    param([string]$Path)
    Get-Content $Path | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" -and -not $_.StartsWith("#") }
}

function Test-AnyMatch {
    param([string]$TargetPath, [string[]]$Patterns)
    foreach ($p in $Patterns) {
        if ([regex]::IsMatch($TargetPath, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $true }
    }
    return $false
}

# Repo temporario com arquivos ja staged. Sem commit de proposito: `git diff --cached`
# lista staged mesmo sem HEAD, e assim o teste nao depende de poder commitar.
function New-TempRepo {
    param([string[]]$Files, [string]$ConfigJson)
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-router-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Push-Location $dir
    try {
        & git init -q . 2>$null
        foreach ($f in $Files) {
            $full = Join-Path $dir $f
            New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
            [IO.File]::WriteAllText($full, "conteudo`n", (New-Object System.Text.UTF8Encoding($false)))
        }
        if ($ConfigJson) {
            [IO.File]::WriteAllText((Join-Path $dir ".percus-review.json"), $ConfigJson, (New-Object System.Text.UTF8Encoding($false)))
        }
        & git add -A -f 2>$null | Out-Null
    } finally { Pop-Location }
    return $dir
}

function Invoke-RouterPs {
    param([string]$Repo, [string]$RouterPath)
    Push-Location $Repo
    try { $out = & $RouterPath -Json } finally { Pop-Location }
    return (($out | Out-String).Trim() | ConvertFrom-Json)
}

function Get-BashExe {
    # bash raramente esta no PATH do PowerShell no Windows; sem esta busca o teste de
    # paridade "passa" como skipped e a divergencia .ps1/.sh volta a ser invisivel.
    $cmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe",
                     "${env:ProgramFiles(x86)}\Git\bin\bash.exe")) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

function Invoke-RouterSh {
    param([string]$Repo, [string]$RouterPath, [string]$BashExe)
    Push-Location $Repo
    try { $out = & $BashExe $RouterPath --json 2>$null } finally { Pop-Location }
    return (($out | Out-String).Trim() | ConvertFrom-Json)
}

        $script:scriptsDir  = Join-Path $PSScriptRoot ".." "scripts"
        $script:baselineTxt = Join-Path $script:scriptsDir "sensitive-paths.txt"
        $script:routerPs1   = Join-Path $script:scriptsDir "review-router.ps1"
        $script:routerSh    = Join-Path $script:scriptsDir "review-router.sh"
        $script:patterns    = @(Get-BaselinePatterns -Path $script:baselineTxt)
        $script:tempRepos   = New-Object System.Collections.ArrayList
        # regex do projeto que virou o incidente 2026-07-27 (tooling/infra)
        $script:cfgVps = '{ "sensitivePatterns": ["(^|[/\\\\])execution[/\\\\].*\\.py$", "(^|[/\\\\])lib[/\\\\].*_client\\.py$"] }'
    }

    AfterAll {
        foreach ($d in $script:tempRepos) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue }
    }

    # ------------------------------------------------------------------
    Context "Baseline: o arquivo e a fonte, e ele e portavel" {
        It "sensitive-paths.txt existe e tem os 10 padroes do baseline" {
            Test-Path $script:baselineTxt | Should -Be $true
            $script:patterns.Count | Should -BeGreaterOrEqual 10
        }

        It "todo padrao do baseline compila como regex" {
            foreach ($p in $script:patterns) {
                { [regex]::new($p) } | Should -Not -Throw -Because "padrao invalido derruba a protecao inteira: $p"
            }
        }

        It "nenhum padrao usa construcao fora do subconjunto portavel ERE/.NET" {
            # \d \w \s \b e (?...) existem no .NET e NAO no ERE do bash: o mesmo
            # arquivo roda nos dois motores, entao so o subconjunto comum e seguro.
            foreach ($p in $script:patterns) {
                $p | Should -Not -Match '\\[dwsb]' -Because "use [0-9] / [A-Za-z0-9_] no lugar (padrao: $p)"
                $p | Should -Not -Match '\(\?'    -Because "grupo (?...) nao existe em ERE (padrao: $p)"
            }
        }
    }

    # ------------------------------------------------------------------
    Context "Baseline: matching (positivos)" {
        It "casa <path>" -ForEach @(
            @{ path = "backend/alembic/versions/049_xyz.py"; why = "incidente 2026-05-18" }
            @{ path = "backend/app/api/v1/internal_tickets.py"; why = "api/vN/internal" }
            @{ path = "infra/domains.yaml"; why = "infra/*.yaml" }
            @{ path = "backend/app/config.py"; why = "config.py" }
            @{ path = "backend/app/services/webhook/dispatcher.py"; why = "services/webhook/" }
            @{ path = "backend/auth/handler.py"; why = "auth/" }
            @{ path = "backend/payments/stripe.py"; why = "payment*/" }
            @{ path = "migrations/001_init.sql"; why = "migrations/" }
            @{ path = "credentials/gcp.json"; why = "credentials/" }
            @{ path = ".env"; why = "^\.env — nunca foi coberto pelo teste antigo" }
            @{ path = ".env.production"; why = "^\.env" }
            @{ path = "backend/Auth/Handler.py"; why = "match e case-insensitive nos dois motores" }
        ) {
            Test-AnyMatch -TargetPath $path -Patterns $script:patterns |
                Should -Be $true -Because $why
        }
    }

    Context "Baseline: matching (negativos — nao inflar custo de review)" {
        It "NAO casa <path>" -ForEach @(
            @{ path = "docs/README.md" }
            @{ path = "HANDOFF.md" }
            @{ path = "src/components/Button.tsx" }
            @{ path = "execution/n8n_evo_to_gowa.py" }  # so vira sensivel via .percus-review.json do projeto
        ) {
            Test-AnyMatch -TargetPath $path -Patterns $script:patterns | Should -Be $false
        }
    }

    # ------------------------------------------------------------------
    Context "Anti-duplicacao: a lista mora em UM lugar" {
        It "review-router.ps1 le o baseline e nao tem lista hardcoded" {
            $c = Get-Content $script:routerPs1 -Raw
            $c | Should -Match 'sensitive-paths\.txt'
            $c | Should -Not -Match "'\(\^\|\[/\\\\\]\)auth" -Because "lista hardcoded no .ps1 foi a causa raiz de 2026-07-27"
        }

        It "review-router.sh le o MESMO baseline e nao tem lista hardcoded" {
            $c = Get-Content $script:routerSh -Raw
            $c | Should -Match 'sensitive-paths\.txt'
            $c | Should -Not -Match '\(\^\|/\)auth/' -Because "cadeia [[ =~ ]] duplicada no .sh podia divergir do .ps1"
        }
    }

    # ------------------------------------------------------------------
    Context "Router rodando: decisao ponta a ponta" {
        It "execution/*.py SEM .percus-review.json -> deepseek (baseline nao advinha convencao de projeto)" {
            $repo = New-TempRepo -Files @("execution/n8n_evo_to_gowa.py")
            [void]$script:tempRepos.Add($repo)
            $r = Invoke-RouterPs -Repo $repo -RouterPath $script:routerPs1
            $r.sensitive | Should -Be $false
            $r.decision  | Should -Be "deepseek"
        }

        It "execution/*.py COM .percus-review.json -> dual (o bug do comunicado 2026-07-27)" {
            $repo = New-TempRepo -Files @("execution/n8n_evo_to_gowa.py") -ConfigJson $script:cfgVps
            [void]$script:tempRepos.Add($repo)
            $r = Invoke-RouterPs -Repo $repo -RouterPath $script:routerPs1
            $r.sensitive | Should -Be $true
            $r.decision  | Should -Be "dual"
            @($r.warnings).Count | Should -Be 0 -Because "config valida nao gera aviso"
        }

        It "lib/*_client.py COM .percus-review.json -> dual" {
            $repo = New-TempRepo -Files @("lib/portainer_client.py") -ConfigJson $script:cfgVps
            [void]$script:tempRepos.Add($repo)
            (Invoke-RouterPs -Repo $repo -RouterPath $script:routerPs1).decision | Should -Be "dual"
        }

        It "doc-only COM config -> deepseek (config nao vira sensitive=true global)" {
            $repo = New-TempRepo -Files @("docs/README.md") -ConfigJson $script:cfgVps
            [void]$script:tempRepos.Add($repo)
            $r = Invoke-RouterPs -Repo $repo -RouterPath $script:routerPs1
            $r.sensitive | Should -Be $false
            $r.decision  | Should -Be "deepseek"
        }

        It ".env na raiz -> dual (baseline)" {
            $repo = New-TempRepo -Files @(".env")
            [void]$script:tempRepos.Add($repo)
            (Invoke-RouterPs -Repo $repo -RouterPath $script:routerPs1).decision | Should -Be "dual"
        }
    }

    # ------------------------------------------------------------------
    Context "Falha fechada: erro de config NAO rebaixa o review" {
        It ".percus-review.json invalido -> sensitive=true + aviso" {
            $repo = New-TempRepo -Files @("docs/README.md") -ConfigJson '{ "sensitivePatterns": [ QUEBRADO'
            [void]$script:tempRepos.Add($repo)
            $r = Invoke-RouterPs -Repo $repo -RouterPath $script:routerPs1
            $r.sensitive | Should -Be $true -Because "JSON quebrado significa protecao que o projeto quis e nao tem"
            (@($r.warnings) -join " ") | Should -Match "falha fechada"
        }

        It "regex invalida no .percus-review.json -> sensitive=true + aviso" {
            $repo = New-TempRepo -Files @("docs/README.md") -ConfigJson '{ "sensitivePatterns": ["((([" ] }'
            [void]$script:tempRepos.Add($repo)
            $r = Invoke-RouterPs -Repo $repo -RouterPath $script:routerPs1
            $r.sensitive | Should -Be $true
            (@($r.warnings) -join " ") | Should -Match "ignorado"
        }

        It "dois erros simultaneos viram DOIS avisos separados, nao um blob" {
            # Regressao: o review do DeepSeek sobre este proprio commit alegou que
            # add_warning() no .sh concatenava com '\n' literal, o que fundiria todos os
            # avisos num item so. Nao procede (a string tem newline real), mas nao havia
            # teste com 2 avisos ao mesmo tempo — agora ha, nos dois motores.
            $orphan = Join-Path ([IO.Path]::GetTempPath()) ("percus-orphan2-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
            New-Item -ItemType Directory -Path $orphan -Force | Out-Null
            [void]$script:tempRepos.Add($orphan)
            Copy-Item $script:routerPs1 (Join-Path $orphan "review-router.ps1")
            Copy-Item $script:routerSh  (Join-Path $orphan "review-router.sh")
            $repo = New-TempRepo -Files @("docs/README.md") -ConfigJson '{ "sensitivePatterns": [ QUEBRADO'
            [void]$script:tempRepos.Add($repo)

            $ps = Invoke-RouterPs -Repo $repo -RouterPath (Join-Path $orphan "review-router.ps1")
            @($ps.warnings).Count | Should -Be 2 -Because "baseline ausente + JSON quebrado sao dois problemas distintos"

            $bash = Get-BashExe
            if ($bash) {
                $sh = Invoke-RouterSh -Repo $repo -RouterPath (Join-Path $orphan "review-router.sh") -BashExe $bash
                @($sh.warnings).Count | Should -Be 2 -Because "o .sh nao pode fundir avisos num item so"
            }
        }

        It "baseline sensitive-paths.txt ausente -> sensitive=true + aviso" {
            $orphan = Join-Path ([IO.Path]::GetTempPath()) ("percus-orphan-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
            New-Item -ItemType Directory -Path $orphan -Force | Out-Null
            [void]$script:tempRepos.Add($orphan)
            Copy-Item $script:routerPs1 (Join-Path $orphan "review-router.ps1")
            $repo = New-TempRepo -Files @("docs/README.md")
            [void]$script:tempRepos.Add($repo)
            $r = Invoke-RouterPs -Repo $repo -RouterPath (Join-Path $orphan "review-router.ps1")
            $r.sensitive | Should -Be $true -Because "sem baseline, silencio seria rebaixar tudo pra deepseek"
            (@($r.warnings) -join " ") | Should -Match "sensitive-paths.txt"
        }
    }

    # ------------------------------------------------------------------
    Context "Paridade .ps1 x .sh (a divergencia que a duplicacao permitia)" {
        BeforeAll { $script:bashExe = Get-BashExe }

        It "os dois routers decidem igual em <case>" -ForEach @(
            @{ case = "execution sem config"; files = @("execution/n8n_evo_to_gowa.py"); cfg = "" }
            @{ case = "execution com config";  files = @("execution/n8n_evo_to_gowa.py"); cfg = "vps" }
            @{ case = "doc-only";              files = @("docs/README.md");               cfg = "vps" }
            @{ case = "baseline auth/";        files = @("backend/auth/h.py");            cfg = "" }
            @{ case = ".env";                  files = @(".env");                          cfg = "" }
            @{ case = "config quebrado";       files = @("docs/README.md");               cfg = "broken" }
        ) {
            if (-not $script:bashExe) { Set-ItResult -Skipped -Because "bash nao disponivel"; return }
            $json = switch ($cfg) {
                "vps"    { $script:cfgVps }
                "broken" { '{ "sensitivePatterns": [ QUEBRADO' }
                default  { $null }
            }
            $repo = New-TempRepo -Files $files -ConfigJson $json
            [void]$script:tempRepos.Add($repo)
            $ps = Invoke-RouterPs -Repo $repo -RouterPath $script:routerPs1
            $sh = Invoke-RouterSh -Repo $repo -RouterPath $script:routerSh -BashExe $script:bashExe
            $sh.decision  | Should -Be $ps.decision  -Because "mesma entrada, mesma decisao ($case)"
            $sh.sensitive | Should -Be $ps.sensitive -Because "mesma entrada, mesmo sensitive ($case)"
        }
    }
}
