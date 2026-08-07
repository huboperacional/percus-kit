#requires -Version 5.1

Describe "external-action-guard.ps1 hook" {
    BeforeAll {
        $script:hookPath = Join-Path $PSScriptRoot ".." "hooks" "external-action-guard.ps1"

        # Invoca o hook com um cwd controlado -- o hook le (Get-Location).Path pra montar o
        # caminho do arquivo de autorizacao, entao os testes precisam simular "rodando de
        # dentro do projeto X" sem tocar o .percus/ real do repo.
        function Invoke-HookEmDir {
            param([string]$Dir, [string]$Stdin)
            Push-Location $Dir
            try {
                return ($Stdin | & pwsh -NoProfile -File $script:hookPath 2>&1)
            } finally {
                Pop-Location
            }
        }

        # Planta um arquivo de autorizacao fixture com idade controlada (em minutos atras de
        # agora), no formato timestamp_unix que o hook espera.
        function New-AutorizacaoFixture {
            param([string]$Dir, [double]$IdadeMinutos = 5, [string]$Motivo = "teste")
            $percusDir = Join-Path $Dir ".percus"
            New-Item -ItemType Directory -Path $percusDir -Force | Out-Null
            $quando = (Get-Date).AddMinutes(-$IdadeMinutos)
            $epoch = [DateTimeOffset]::new($quando).ToUnixTimeSeconds()
            $auth = [pscustomobject]@{
                id             = [guid]::NewGuid().ToString()
                motivo         = $Motivo
                autorizado_em  = $quando.ToString("o")
                timestamp_unix = $epoch
            }
            $caminho = Join-Path $percusDir "acao-externa-autorizada.json"
            ($auth | ConvertTo-Json) | Set-Content -LiteralPath $caminho -Encoding utf8
            return $caminho
        }
    }

    It "existe" {
        Test-Path $hookPath | Should -Be $true
    }

    It "permite tool nao-externo (echo hello)" {
        $stdin = '{"tool_input":{"command":"echo hello"}}'
        $result = $stdin | & pwsh -NoProfile -File $hookPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It "permite gh pr list (read-only)" {
        $stdin = '{"tool_input":{"command":"gh pr list"}}'
        $result = $stdin | & pwsh -NoProfile -File $hookPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It "bloqueia gh pr comment sem aprovacao operador" {
        # Setup: sem .deepseek/council-log/ ou council log antigo > 5min OU premise_validity ruim
        # No env override
        $stdin = '{"tool_input":{"command":"gh pr comment 123 --body \"test\""}}'
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $result = $stdin | & pwsh -NoProfile -File $hookPath 2>&1
        $LASTEXITCODE | Should -Be 2 -Because "gh pr comment requer aprovacao R20"
    }

    It "permite gh pr comment com PERCUS_EXTERNAL_OVERRIDE setado" {
        $stdin = '{"tool_input":{"command":"gh pr comment 123 --body test"}}'
        $env:PERCUS_EXTERNAL_OVERRIDE = "1"
        $result = $stdin | & pwsh -NoProfile -File $hookPath 2>&1
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $LASTEXITCODE | Should -Be 0
    }

    It "bloqueia slack-cli send" {
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"slack-cli send --channel general msg"}}'
        $result = $stdin | & pwsh -NoProfile -File $hookPath 2>&1
        $LASTEXITCODE | Should -Be 2
    }

    It "bloqueia gh issue close" {
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"gh issue close 42"}}'
        $result = $stdin | & pwsh -NoProfile -File $hookPath 2>&1
        $LASTEXITCODE | Should -Be 2
    }

    It "permite git push se override setado (R20 escape)" {
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $env:PERCUS_EXTERNAL_OVERRIDE = "1"
        $result = $stdin | & pwsh -NoProfile -File $hookPath 2>&1
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $LASTEXITCODE | Should -Be 0
    }

    It "stderr message inclui R20 reference" {
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"gh pr comment 123 --body x"}}'
        $errOutput = $stdin | & pwsh -NoProfile -File $hookPath 2>&1
        ($errOutput -join " ") | Should -Match "R20|external-action-guard"
    }

    It "graceful em stdin vazio (exit 0)" {
        $result = "" | & pwsh -NoProfile -File $hookPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It "barra a mesma acao vinda de QUALQUER tool -- <Tool>" -ForEach @(
        @{ Tool = "Bash" }
        @{ Tool = "PowerShell" }
    ) {
        # Ate 2026-07-31 o matcher era "Bash" e mais nada, e o harness expoe DUAS tools de shell.
        # Medido no mesmo instante e na mesma maquina: a mesma acao externa barrada pela tool Bash
        # e livre pela tool PowerShell. Foi por esse caminho que o push de 2026-07-30 saiu.
        #
        # O conserto e no matcher (Task 4), nao aqui: este hook nunca olhou tool_name, sempre leu
        # tool_input.command, que as duas tools preenchem. Este It amarra esse "sempre" -- se
        # alguem introduzir ramificacao por tool_name, o matcher entregaria a chamada e o hook a
        # descartaria em silencio, e o teste do matcher sozinho seguiria verde.
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_name":"' + $Tool + '","tool_input":{"command":"git push origin main"}}'
        $null = $stdin | & pwsh -NoProfile -File $hookPath 2>&1
        $LASTEXITCODE | Should -Be 2 -Because "acao externa pela tool $Tool tem que barrar igual"
    }

    It "permite acao externa com autorizacao em lote fresca (timestamp_unix recente)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 0 -Because "autorizacao em lote fresca deve liberar"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "NAO permite acao externa com autorizacao em lote expirada (timestamp_unix ha mais de 60min)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 61 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "autorizacao expirada nao pode liberar"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
}
