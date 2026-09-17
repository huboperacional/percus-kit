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

        # A fixture usa o MESMO nome de arquivo que o guard real ("external-action-guard.tests.ps1")
        # de proposito: e o nome que -Afetados casa por base ("external-action-guard.ps1" mudado ->
        # basename "external-action-guard") e tambem o padrao de guard que forca incluir Lento. Duas
        # mecanicas, um nome, porque e assim que -Afetados se comporta pro guard de verdade.
        function New-FixtureComLento {
            param([string]$Dir)
            $f = Join-Path $Dir "external-action-guard.tests.ps1"
            @'
Describe "a" {
    It "passa" { 1 | Should -Be 1 }
}
Describe "lento" -Tag "Lento" {
    It "so roda com Lento incluido" { 1 | Should -Be 1 }
}
'@ | Set-Content -Path $f -Encoding utf8
            return $f
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

    It "-ManterEnv aceita valor unico com virgula (forma que -File entrega) e preserva as duas variaveis" {
        $d = New-DirTeste
        $f = Join-Path $d "a.tests.ps1"
        @'
Describe "a" {
    It "nao ve PERCUS_A nem PERCUS_B do pai" {
        $env:PERCUS_A | Should -BeNullOrEmpty
        $env:PERCUS_B | Should -BeNullOrEmpty
    }
}
'@ | Set-Content -Path $f -Encoding utf8
        $env:PERCUS_A = "1"
        $env:PERCUS_B = "1"
        try {
            $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1", "-ManterEnv", "PERCUS_A,PERCUS_B")
        } finally {
            Remove-Item Env:PERCUS_A -ErrorAction SilentlyContinue
            Remove-Item Env:PERCUS_B -ErrorAction SilentlyContinue
        }
        $r.Exit | Should -Be 1 -Because $r.Saida
    }

    # --- Fase 6: tag Lento (matriz cara do guard tirada da suite padrao) --------------------
    It "sem parametro exclui Lento e anuncia quantos" {
        $d = New-DirTeste
        New-FixtureComLento -Dir $d | Out-Null
        $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1")
        $r.Exit | Should -Be 0 -Because $r.Saida
        $r.Saida | Should -Match "1/2" -Because $r.Saida
        $r.Saida | Should -Match "pulados por tag Lento: 1" -Because $r.Saida
    }

    It "-IncluirLentos roda o teste marcado Lento tambem" {
        $d = New-DirTeste
        New-FixtureComLento -Dir $d | Out-Null
        $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1", "-IncluirLentos")
        $r.Exit | Should -Be 0 -Because $r.Saida
        $r.Saida | Should -Match "2/2" -Because $r.Saida
        $r.Saida | Should -Match "pulados por tag Lento: 0" -Because $r.Saida
    }

    It "-Afetados com diff tocando o guard inclui o Lento mesmo sem -IncluirLentos" {
        $d = New-DirTeste
        New-FixtureComLento -Dir $d | Out-Null
        # Portao duplo (env, nao parametro): rodar-suite.ps1 so honra RODARSUITE_TESTE_MUDADOS
        # quando RODARSUITE_TESTE_GATE=1 tambem esta setada -- so este proprio teste
        # deveria por acaso ter as DUAS. O `pwsh` que Invoke-RodarSuite invoca (o proprio
        # rodar-suite.ps1, processo filho direto desta sessao Pester) herda as duas do ambiente.
        $env:RODARSUITE_TESTE_GATE = "1"
        $env:RODARSUITE_TESTE_MUDADOS = "hooks/external-action-guard.ps1"
        try {
            $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1", "-Afetados")
        } finally {
            Remove-Item Env:RODARSUITE_TESTE_MUDADOS -ErrorAction SilentlyContinue
            Remove-Item Env:RODARSUITE_TESTE_GATE -ErrorAction SilentlyContinue
        }
        $r.Exit | Should -Be 0 -Because $r.Saida
        $r.Saida | Should -Match "2/2" -Because $r.Saida
        $r.Saida | Should -Match "pulados por tag Lento: 0" -Because $r.Saida
    }

    It "-Afetados com diff que NAO toca o guard continua excluindo o Lento" {
        $d = New-DirTeste
        New-FixtureComLento -Dir $d | Out-Null
        $env:RODARSUITE_TESTE_GATE = "1"
        $env:RODARSUITE_TESTE_MUDADOS = "algum-outro-arquivo.txt"
        try {
            $r = Invoke-RodarSuite -Dir $d -ArgsExtra @("-Processos", "1", "-Afetados")
        } finally {
            Remove-Item Env:RODARSUITE_TESTE_MUDADOS -ErrorAction SilentlyContinue
            Remove-Item Env:RODARSUITE_TESTE_GATE -ErrorAction SilentlyContinue
        }
        $r.Exit | Should -Be 0 -Because $r.Saida
        $r.Saida | Should -Match "1/2" -Because $r.Saida
        $r.Saida | Should -Match "pulados por tag Lento: 1" -Because $r.Saida
    }

}
