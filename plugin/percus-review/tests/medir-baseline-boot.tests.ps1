#requires -Version 5.1
# Testes do scripts/medir-baseline-boot.ps1 (v6.45.0).
#
# Instrumento READ-ONLY: para cada transcript em <claude-home>/projects/<projeto>/*.jsonl, le a
# PRIMEIRA linha com `usage` e imprime data | modelo | baseline em k tokens | projeto. E a medicao
# que mostrou 65-73k de custo fixo em toda a frota (2026-09-12) -- system prompt + tool defs de MCP
# + hooks + skills, antes da primeira palavra do operador. Serve para o operador comparar ANTES e
# DEPOIS de desligar conectores: o kit nao consegue decompor por conector (as tool defs nao ficam em
# disco), entao a decomposicao e por experimento, e o experimento precisa de um medidor estavel.

Describe "medir-baseline-boot (custo fixo da 1a chamada por sessao)" {
    BeforeAll {
        $script:script = Join-Path $PSScriptRoot ".." ".." ".." "scripts" "medir-baseline-boot.ps1"

        function New-ClaudeHome {
            $casa = Join-Path ([IO.Path]::GetTempPath()) "baseline-test-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path (Join-Path $casa "projects") | Out-Null
            return $casa
        }
        function Add-Transcript {
            param([string]$Casa, [string]$Projeto, [string]$Nome, [int]$Tokens, [string]$Modelo = "claude-opus-5", [string]$Data = "2026-09-10")
            $dir = Join-Path (Join-Path $Casa "projects") $Projeto
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $p = Join-Path $dir "$Nome.jsonl"
            $enc = New-Object System.Text.UTF8Encoding($false)
            $linhas = @(
                '{"type":"user","timestamp":"' + $Data + 'T10:00:00.000Z","message":{"role":"user","content":"oi"}}'
                '{"type":"assistant","timestamp":"' + $Data + 'T10:00:03.000Z","message":{"model":"' + $Modelo + '","usage":{"input_tokens":' + [int]($Tokens * 0.1) + ',"cache_read_input_tokens":0,"cache_creation_input_tokens":' + [int]($Tokens * 0.9) + ',"output_tokens":5}}}'
                '{"type":"assistant","timestamp":"' + $Data + 'T10:05:00.000Z","message":{"model":"' + $Modelo + '","usage":{"input_tokens":999999,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":5}}}'
            )
            [System.IO.File]::WriteAllText($p, ($linhas -join "`n") + "`n", $enc)
            return $p
        }
        # O parametro NAO pode se chamar $Args: e variavel automatica do PowerShell e o splat
        # nao chega ao script -- ele cai no default (CLAUDE_CONFIG_DIR real) e o teste passa
        # por coincidencia contra a frota de verdade. Aconteceu na 1a rodada deste arquivo.
        function Invoke-Medidor {
            param([string[]]$Argumentos)
            $out = & pwsh -NoProfile -File $script:script @Argumentos 2>&1
            return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
        }
    }

    It "existe" {
        Test-Path $script | Should -Be $true
    }

    It "le a PRIMEIRA usage de cada transcript (a do boot), nao a ultima" {
        $casa = New-ClaudeHome
        Add-Transcript -Casa $casa -Projeto "d--x-projA" -Nome "s1" -Tokens 68000 | Out-Null
        $r = Invoke-Medidor -Argumentos @("-ClaudeHome", $casa)
        $r.Code | Should -Be 0
        $r.Out  | Should -Match '68k'
        $r.Out  | Should -Not -Match '999'
    }

    It "imprime data, modelo e projeto na mesma linha do valor" {
        $casa = New-ClaudeHome
        Add-Transcript -Casa $casa -Projeto "d--x-projA" -Nome "s1" -Tokens 68000 -Modelo "claude-sonnet-5" -Data "2026-09-11" | Out-Null
        $r = Invoke-Medidor -Argumentos @("-ClaudeHome", $casa)
        $linha = ($r.Out -split "`n") | Where-Object { $_ -match '68k' } | Select-Object -First 1
        $linha | Should -Match '2026-09-11'
        $linha | Should -Match 'claude-sonnet-5'
        $linha | Should -Match 'projA'
    }

    It "-Projeto filtra por nome (substring) e -Ultimos limita a quantidade" {
        $casa = New-ClaudeHome
        Add-Transcript -Casa $casa -Projeto "d--x-projA" -Nome "s1" -Tokens 60000 -Data "2026-09-01" | Out-Null
        Add-Transcript -Casa $casa -Projeto "d--x-projA" -Nome "s2" -Tokens 70000 -Data "2026-09-02" | Out-Null
        Add-Transcript -Casa $casa -Projeto "d--x-projB" -Nome "s3" -Tokens 80000 -Data "2026-09-03" | Out-Null
        $r = Invoke-Medidor -Argumentos @("-ClaudeHome", $casa, "-Projeto", "projA", "-Ultimos", "1")
        $r.Out | Should -Match '70k'
        $r.Out | Should -Not -Match '60k'
        $r.Out | Should -Not -Match '80k'
    }

    It "resume no fim: mediana e faixa, pra comparar antes/depois de desligar um conector" {
        $casa = New-ClaudeHome
        Add-Transcript -Casa $casa -Projeto "d--x-projA" -Nome "s1" -Tokens 60000 | Out-Null
        Add-Transcript -Casa $casa -Projeto "d--x-projA" -Nome "s2" -Tokens 70000 | Out-Null
        Add-Transcript -Casa $casa -Projeto "d--x-projB" -Nome "s3" -Tokens 80000 | Out-Null
        $r = Invoke-Medidor -Argumentos @("-ClaudeHome", $casa)
        $r.Out | Should -Match 'mediana'
        $r.Out | Should -Match '70k'
        $r.Out | Should -Match '60k.*80k'
    }

    It "transcript sem usage e ignorado sem quebrar; claude-home vazio sai 0 com aviso" {
        $casa = New-ClaudeHome
        $dir = Join-Path (Join-Path $casa "projects") "d--x-vazio"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Set-Content -Path (Join-Path $dir "s.jsonl") -Value '{"type":"user","message":{"content":"oi"}}'
        $r = Invoke-Medidor -Argumentos @("-ClaudeHome", $casa)
        $r.Code | Should -Be 0
        $r.Out  | Should -Match 'nenhum'
    }

    It "primeira usage com 0 tokens (mensagem <synthetic>) e pulada: o boot e a primeira chamada REAL" {
        # Visto na frota real: sessoes cujo primeiro registro com usage e um <synthetic> com
        # input_tokens=0. Contar isso como baseline daria 0k e afundaria a mediana.
        $casa = New-ClaudeHome
        $dir = Join-Path (Join-Path $casa "projects") "d--x-synth"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $linhas = @(
            '{"type":"assistant","timestamp":"2026-09-12T10:00:00.000Z","message":{"model":"<synthetic>","usage":{"input_tokens":0,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":0}}}'
            '{"type":"assistant","timestamp":"2026-09-12T10:00:03.000Z","message":{"model":"claude-opus-5","usage":{"input_tokens":7000,"cache_read_input_tokens":0,"cache_creation_input_tokens":64000,"output_tokens":5}}}'
        )
        [System.IO.File]::WriteAllText((Join-Path $dir "s.jsonl"), ($linhas -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Medidor -Argumentos @("-ClaudeHome", $casa)
        $r.Out | Should -Match '71k'
        $r.Out | Should -Not -Match 'synthetic'
    }

    It "transcript ABERTO por uma sessao viva (escritor com FileShare.Read) ainda e medido" {
        # O script existe pra medir a frota ENQUANTO ha sessoes abertas. O harness mantem o
        # transcript aberto pra escrita; um leitor que nao pede FileShare.ReadWrite leva
        # IOException e o arquivo some da conta sem aviso (finding Cross-Claude, 2026-09-12).
        $casa = New-ClaudeHome
        $p = Add-Transcript -Casa $casa -Projeto "d--x-vivo" -Nome "s1" -Tokens 66000
        $escritor = [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try {
            $r = Invoke-Medidor -Argumentos @("-ClaudeHome", $casa)
        } finally { $escritor.Close() }
        $r.Out | Should -Match '66k'
        $r.Out | Should -Not -Match 'Exception|IOException'
    }

    It "nao escreve nada: e read-only (nenhuma linha viva grava arquivo)" {
        $vivas = @(Get-Content $script -ErrorAction Stop | Where-Object { -not "$_".TrimStart().StartsWith('#') })
        @($vivas | Where-Object { $_ -match 'Set-Content|Out-File|WriteAllText|Add-Content|AppendAllText|New-Item' }) | Should -BeNullOrEmpty
    }
}
