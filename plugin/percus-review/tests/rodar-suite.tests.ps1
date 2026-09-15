#requires -Version 5.1
# Fixtures minimas em %TEMP%, rodando o rodar-suite.ps1 DE VERDADE (processo real, nao mock).
# Armadilha conhecida (T6/T7): este teste roda DENTRO da suite principal, entao o rodar-suite
# testado aqui vira um processo NETO da suite -- fixtures pequenas e -Processos explicito
# evitam que o teste dispare uma arvore grande de pwsh.

Describe "rodar-suite.ps1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\rodar-suite.ps1"
        $script:temps   = New-Object System.Collections.ArrayList

        function New-DirTeste {
            $d = Join-Path ([IO.Path]::GetTempPath()) ("percus-suite-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            [void]$script:temps.Add($d)
            return $d
        }

        function Invoke-RodarSuite {
            param([string]$Dir, [string[]]$ArgsExtra = @())
            $listaArgs = @("-NoProfile", "-File", $script:script, "-Caminhos", $Dir) + $ArgsExtra
            $saida = & pwsh @listaArgs 2>&1
            [pscustomobject]@{ Saida = ($saida | Out-String); Exit = $LASTEXITCODE }
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "mostra pulados na linha final e soma passou/pulou" {
        $d = New-DirTeste
        $f = Join-Path $d "a.tests.ps1"
        @'
Describe "a" {
    It "passa" { 1 | Should -Be 1 }
    It "pula" { Set-ItResult -Skipped -Because "fixture" }
}
'@ | Set-Content -Path $f -Encoding utf8
        $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1")
        $r.Exit | Should -Be 0 -Because $r.Saida
        $r.Saida | Should -Match "1/2" -Because $r.Saida
        $r.Saida | Should -Match "pulados 1" -Because $r.Saida
    }

    It "-MostrarPulados lista o nome do teste pulado" {
        $d = New-DirTeste
        $f = Join-Path $d "a.tests.ps1"
        @'
Describe "a" {
    It "passa" { 1 | Should -Be 1 }
    It "pula esta marca rara" { Set-ItResult -Skipped -Because "fixture" }
}
'@ | Set-Content -Path $f -Encoding utf8
        $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1", "-MostrarPulados")
        $r.Exit | Should -Be 0 -Because $r.Saida
        $r.Saida | Should -Match "pula esta marca rara" -Because $r.Saida
    }

    It "acusa processo que morre sem devolver resultado, com o nome do arquivo" {
        $d = New-DirTeste
        $ok = Join-Path $d "ok.tests.ps1"
        $morre = Join-Path $d "morre.tests.ps1"
        @'
Describe "ok" { It "passa" { 1 | Should -Be 1 } }
'@ | Set-Content -Path $ok -Encoding utf8
        @'
Describe "morre" {
    BeforeAll { [Environment]::Exit(9) }
    It "nunca roda" { 1 | Should -Be 1 }
}
'@ | Set-Content -Path $morre -Encoding utf8
        $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "2")
        $r.Exit | Should -Be 1 -Because $r.Saida
        $r.Saida | Should -Match "1 de 2 processo\(s\) nao devolveram resultado" -Because $r.Saida
        $r.Saida | Should -Match "morre\.tests\.ps1" -Because $r.Saida
    }

    It "mantem o comportamento atual: teste que falha reporta FALHAS e sai 1" {
        $d = New-DirTeste
        $f = Join-Path $d "a.tests.ps1"
        @'
Describe "a" { It "falha" { 1 | Should -Be 2 } }
'@ | Set-Content -Path $f -Encoding utf8
        $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1")
        $r.Exit | Should -Be 1 -Because $r.Saida
        $r.Saida | Should -Match "FALHAS \(1\)" -Because $r.Saida
    }

    It "-Caminhos aceita caminho absoluto" {
        $d = New-DirTeste
        $f = Join-Path $d "a.tests.ps1"
        @'
Describe "a" { It "passa" { 1 | Should -Be 1 } }
'@ | Set-Content -Path $f -Encoding utf8
        [IO.Path]::IsPathRooted($d) | Should -Be $true
        $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1")
        $r.Exit | Should -Be 0 -Because $r.Saida
        $r.Saida | Should -Match "1/1" -Because $r.Saida
    }

    # --- T7: env do filho nao herda PERCUS_* do pai --------------------------------
    It "limpa PERCUS_* herdado do pai antes do filho rodar, e anuncia o nome na saida" {
        $d = New-DirTeste
        $f = Join-Path $d "a.tests.ps1"
        @'
Describe "a" {
    It "nao ve PERCUS_HOOKS_DISABLED do pai" { $env:PERCUS_HOOKS_DISABLED | Should -BeNullOrEmpty }
}
'@ | Set-Content -Path $f -Encoding utf8
        $env:PERCUS_HOOKS_DISABLED = "1"
        try {
            $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1")
        } finally { Remove-Item Env:PERCUS_HOOKS_DISABLED -ErrorAction SilentlyContinue }
        $r.Exit | Should -Be 0 -Because $r.Saida
        $r.Saida | Should -Match "env limpo no filho.*PERCUS_HOOKS_DISABLED" -Because $r.Saida
    }

    It "-ManterEnv preserva a variavel no filho (fixture que exige o oposto passa a falhar)" {
        $d = New-DirTeste
        $f = Join-Path $d "a.tests.ps1"
        @'
Describe "a" {
    It "nao ve PERCUS_HOOKS_DISABLED do pai" { $env:PERCUS_HOOKS_DISABLED | Should -BeNullOrEmpty }
}
'@ | Set-Content -Path $f -Encoding utf8
        $env:PERCUS_HOOKS_DISABLED = "1"
        try {
            $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1", "-ManterEnv", "PERCUS_HOOKS_DISABLED")
        } finally { Remove-Item Env:PERCUS_HOOKS_DISABLED -ErrorAction SilentlyContinue }
        $r.Exit | Should -Be 1 -Because $r.Saida
    }
}
