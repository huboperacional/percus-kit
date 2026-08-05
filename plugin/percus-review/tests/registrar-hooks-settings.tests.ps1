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

        $saida | Should -Match "2 hook"
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
}
