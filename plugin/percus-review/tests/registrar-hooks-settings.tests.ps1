#requires -Version 5.1
# O script mexe no settings.json do usuario. O teste NUNCA toca o real: monta um par
# (kit falso com manifesto+wrappers + settings falso) e afere o resultado, mesmo padrao
# de plugin/percus-review/tests/renomear-kit-local.tests.ps1.

Describe "registrar-hooks-settings.ps1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\registrar-hooks-settings.ps1"
        $script:temps   = New-Object System.Collections.ArrayList

        # Kit falso: so o suficiente pra exercitar o script (manifesto pequeno, 2 guarda + 1
        # observador), sem precisar dos 12 hooks reais. O Task 5 cruza com o manifesto de
        # verdade separadamente.
        function New-KitFalso {
            param([bool]$ComWrappers = $true)
            $raiz = Join-Path ([IO.Path]::GetTempPath()) ("regh-kit-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            $hooksDir = Join-Path $raiz "plugin\percus-review\hooks"
            New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null

            $manifesto = @{
                hooks = @(
                    @{ nome = "guarda-um";  evento = "PreToolUse"; matcher = "Bash|PowerShell"; forma = "guarda";     registrado = $true }
                    @{ nome = "guarda-dois";evento = "PreToolUse"; matcher = "Bash|PowerShell"; forma = "guarda";     registrado = $true }
                    @{ nome = "obs-um";     evento = "Stop";       matcher = $null;             forma = "observador";registrado = $true }
                    @{ nome = "orfao";      evento = "SessionStart"; matcher = $null;           forma = "observador";registrado = $false }
                )
            } | ConvertTo-Json -Depth 10
            [IO.File]::WriteAllText((Join-Path $hooksDir "hooks-manifest.json"), $manifesto, (New-Object System.Text.UTF8Encoding($false)))

            if ($ComWrappers) {
                foreach ($nome in @("guarda-um", "guarda-dois", "obs-um")) {
                    [IO.File]::WriteAllText((Join-Path $hooksDir "$nome.cmd"), "@echo off`r`nexit /b 0`r`n", (New-Object System.Text.UTF8Encoding($false)))
                }
            }
            [void]$script:temps.Add($raiz)
            return $raiz
        }

        function New-SettingsFalso {
            param([hashtable]$Conteudo = @{})
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("regh-set-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $caminho = Join-Path $dir "settings.json"
            [IO.File]::WriteAllText($caminho, ($Conteudo | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
            [void]$script:temps.Add($dir)
            return $caminho
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "DryRun com escopo Guardas: reporta 2 hooks (os 2 de forma guarda), nao os observadores nem o orfao" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}

        $saida = & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings -DryRun *>&1 | Out-String

        $saida | Should -Match "\b2 hook\(s\)"
        $saida | Should -Match "guarda-um"
        $saida | Should -Match "guarda-dois"
        $saida | Should -Not -Match "obs-um"
        $saida | Should -Not -Match "orfao"
    }

    It "aborta SEM escrever nada quando o manifesto cita um hook sem wrapper .cmd em disco" {
        $kit = New-KitFalso -ComWrappers $false
        $settings = New-SettingsFalso -Conteudo @{}
        $antes = Get-Content $settings -Raw

        { & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings -DryRun } |
            Should -Throw -ExpectedMessage "*sem wrapper*"

        (Get-Content $settings -Raw) | Should -Be $antes -Because "registro parcial mente sobre o que esta protegido -- nada pode ser gravado"
    }

    It "registra no settings.json vazio e preserva hook alheio ja existente" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{
            hooks = @{ SessionStart = @(@{ matcher = ""; hooks = @(@{ type = "command"; command = "echo alheio" }) }) }
        }

        & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings | Out-Null

        $j = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $blocosPreToolUse = @($j.hooks.PreToolUse)
        $comandos = @($blocosPreToolUse | ForEach-Object { @($_.hooks) } | ForEach-Object { $_.command })
        ($comandos -join "|") | Should -Match "guarda-um\.cmd"
        ($comandos -join "|") | Should -Match "guarda-dois\.cmd"

        # o matcher e o que faz o guard disparar de verdade -- confere que foi escrito
        # com o valor exato do manifesto falso ("Bash|PowerShell"), nao so que o comando existe
        $blocoComGuarda = $blocosPreToolUse | Where-Object {
            @($_.hooks) | ForEach-Object { $_.command } | Where-Object { $_ -match "guarda-um\.cmd|guarda-dois\.cmd" }
        }
        @($blocoComGuarda) | ForEach-Object { $_.matcher } | Should -Contain "Bash|PowerShell"

        # o hook alheio de SessionStart sobrevive intacto
        $sessionStart = @($j.hooks.SessionStart)
        ($sessionStart | ForEach-Object { @($_.hooks) } | ForEach-Object { $_.command }) | Should -Contain "echo alheio"
    }

    It "reexecucao e idempotente: mesmo numero de blocos PreToolUse na segunda rodada" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}

        & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings | Out-Null
        $j1 = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $n1 = @($j1.hooks.PreToolUse).Count

        & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings | Out-Null
        $j2 = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $n2 = @($j2.hooks.PreToolUse).Count

        $n2 | Should -Be $n1 -Because "rodar duas vezes nao pode duplicar bloco -- enforcement duplo e real (item 2 da medicao)"
    }

    It "faz backup datado do settings.json antes de sobrescrever" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}

        & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings | Out-Null

        @(Get-ChildItem (Split-Path $settings -Parent) -Filter "settings.json.bak-*").Count |
            Should -Be 1 -Because "primeira escrita sobrescreve um settings.json que ja existia (o fixture cria vazio antes)"
    }

    It "settings.json JA invalido antes de qualquer mudanca: aborta e nao mexe no arquivo" {
        $kit = New-KitFalso
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("regh-set-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $settings = Join-Path $dir "settings.json"
        [IO.File]::WriteAllText($settings, "{ isto nao e json valido", (New-Object System.Text.UTF8Encoding($false)))
        [void]$script:temps.Add($dir)
        $antes = Get-Content $settings -Raw

        { & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings } |
            Should -Throw -ExpectedMessage "*JA esta invalido*"

        (Get-Content $settings -Raw) | Should -Be $antes
        @(Get-ChildItem $dir -Filter "settings.json.bak-*").Count | Should -Be 0 -Because "nada deveria ter sido tentado, nem backup"
    }

    It "escopo Observadores filtra so o hook de forma observador" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}
        $saida = & $script:script -Escopo Observadores -KitRoot $kit -SettingsPath $settings -DryRun *>&1 | Out-String
        $saida | Should -Match "\b1 hook\(s\)"
        $saida | Should -Match "obs-um"
        $saida | Should -Not -Match "guarda-um"
    }

    It "escopo Todos inclui guarda e observador, nunca o orfao" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}
        $saida = & $script:script -Escopo Todos -KitRoot $kit -SettingsPath $settings -DryRun *>&1 | Out-String
        $saida | Should -Match "\b3 hook\(s\)"
        $saida | Should -Not -Match "orfao"
    }

    It "escopo Todos SEM DryRun: escreve blocos reais em PreToolUse (guardas) E em Stop (observador) na mesma chamada, sem duplicar na 2a rodada" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}

        & $script:script -Escopo Todos -KitRoot $kit -SettingsPath $settings | Out-Null

        $j1 = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $comandosPreToolUse1 = @($j1.hooks.PreToolUse | ForEach-Object { @($_.hooks) } | ForEach-Object { $_.command })
        $comandosStop1       = @($j1.hooks.Stop       | ForEach-Object { @($_.hooks) } | ForEach-Object { $_.command })

        ($comandosPreToolUse1 -join "|") | Should -Match "guarda-um\.cmd"
        ($comandosPreToolUse1 -join "|") | Should -Match "guarda-dois\.cmd"
        ($comandosStop1 -join "|")       | Should -Match "obs-um\.cmd"

        $nPre1 = @($j1.hooks.PreToolUse).Count
        $nStop1 = @($j1.hooks.Stop).Count

        & $script:script -Escopo Todos -KitRoot $kit -SettingsPath $settings | Out-Null
        $j2 = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $nPre2 = @($j2.hooks.PreToolUse).Count
        $nStop2 = @($j2.hooks.Stop).Count

        $nPre2  | Should -Be $nPre1  -Because "2a rodada nao pode duplicar bloco de PreToolUse"
        $nStop2 | Should -Be $nStop1 -Because "2a rodada nao pode duplicar bloco de Stop"
    }

    It "settings.json que ainda NAO existe: cria o arquivo com o conteudo esperado e nao faz backup (nada pra fazer backup)" {
        $kit = New-KitFalso
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("regh-novo-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $settings = Join-Path $dir "settings.json"
        [void]$script:temps.Add($dir)

        Test-Path $settings | Should -Be $false -Because "o teste precisa exercitar o branch de primeiro uso, sem arquivo previo"

        & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings | Out-Null

        Test-Path $settings | Should -Be $true
        $j = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $comandos = @($j.hooks.PreToolUse | ForEach-Object { @($_.hooks) } | ForEach-Object { $_.command })
        ($comandos -join "|") | Should -Match "guarda-um\.cmd"
        ($comandos -join "|") | Should -Match "guarda-dois\.cmd"

        @(Get-ChildItem $dir -Filter "settings.json.bak-*").Count | Should -Be 0 -Because "primeiro uso: nao existe settings.json anterior pra fazer backup"
    }

    It "contra o manifesto REAL do kit: Guardas=9, Observadores=4, Todos=13 -- todos com wrapper em disco" {
        # Regressao de verdade: usa o hooks-manifest.json e os .cmd reais do proprio repo,
        # nao o kit falso. Prova que o script bate com o que hooks-manifest.tests.ps1 ja
        # afirma sobre o mundo real (9 guarda / 4 observador / 13 total).
        $settings = New-SettingsFalso -Conteudo @{}

        $saidaGuardas = & $script:script -Escopo Guardas -KitRoot $script:kitRoot -SettingsPath $settings -DryRun *>&1 | Out-String
        $saidaGuardas | Should -Match "\b9 hook\(s\)"

        $saidaObs = & $script:script -Escopo Observadores -KitRoot $script:kitRoot -SettingsPath $settings -DryRun *>&1 | Out-String
        $saidaObs | Should -Match "\b4 hook\(s\)"

        $saidaTodos = & $script:script -Escopo Todos -KitRoot $script:kitRoot -SettingsPath $settings -DryRun *>&1 | Out-String
        $saidaTodos | Should -Match "\b13 hook\(s\)"
    }
}
