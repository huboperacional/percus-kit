#requires -Version 5.1

Describe "external-action-guard.ps1 hook" {
    BeforeAll {
        $script:hookPath = Join-Path $PSScriptRoot ".." "hooks" "external-action-guard.ps1"
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
}
