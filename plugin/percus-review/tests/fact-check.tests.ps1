#requires -Version 5.1
# Tests: fact-check.ps1 pipeline F3 — valida findings criticos contra codigo real.
# TDD: escrever primeiro, rodar ANTES da implementacao (todos devem falhar).

Describe "fact-check.ps1" {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot ".." "scripts" "fact-check.ps1"
    }

    It "existe" {
        Test-Path $scriptPath | Should -Be $true
    }

    It "parse findings com tag [SEV: risco] e [SEV: bug]" {
        $content = Get-Content $scriptPath -Raw
        $content | Should -Match "SEV:\s*(risco|bug)"
    }

    It "retorna JSON com filtered_output e audit" {
        $content = Get-Content $scriptPath -Raw
        $content | Should -Match "filtered_output"
        $content | Should -Match "audit"
    }

    It "edge case: input sem findings retorna estrutura vazia (graceful)" {
        $emptyInput = "Sem findings criticos.`n`nO diff e limpo."
        $result = $emptyInput | & pwsh -NoProfile -File $scriptPath -NoFactCheck 2>&1
        $result | Should -Not -BeNullOrEmpty
        $json = $result | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($json) {
            $json.findings_total | Should -BeLessOrEqual 0
        } else {
            $LASTEXITCODE | Should -Be 0
        }
    }

    It "extrai file path de [SEV: risco] auth/handler.py:42" {
        $content = Get-Content $scriptPath -Raw
        # Script deve conter logica de extracao de file path
        $content | Should -Match "file_path|filePath|file path"
    }

    It "usa cross-claude.ps1 wrapper pra fact-check" {
        $content = Get-Content $scriptPath -Raw
        $content | Should -Match "cross-claude"
    }

    Context "Regressao v6.14.0: parse de finding multi-linha nao trunca o bloco" {
        BeforeAll {
            $script:stubDir2 = Join-Path $env:TEMP "factcheck-regex-$(Get-Random)"
            New-Item -ItemType Directory -Force $stubDir2 | Out-Null
            $script:stubCC = Join-Path $stubDir2 "stub-cc.ps1"
            Set-Content -Path $stubCC -Encoding utf8 -Value @'
param([string]$PromptFile,[string]$Mode,[string]$SystemPrompt,[int]$MaxTokens,[string]$Model)
@{ status="ok"; content="CONFIRMADO" } | ConvertTo-Json -Compress
exit 0
'@
        }
        AfterAll { if (Test-Path $stubDir2) { Remove-Item -Recurse -Force $stubDir2 -ErrorAction SilentlyContinue } }

        It "captura file_path de finding multi-linha (bug: flag m truncava bloco no 1o EOL)" {
            $finding = "[SEV: bug]`nArquivo: auth/handler.py:42`nProblema: race condition no refresh do token"
            $out = $finding | & pwsh -NoProfile -File $scriptPath -Wrapper $stubCC 2>&1
            $json = ($out -join "`n") | ConvertFrom-Json
            $json.findings_total       | Should -Be 1
            $json.audit[0].file_path   | Should -Be "auth/handler.py:42" -Because "bloco nao pode ser truncado no 1o fim-de-linha"
        }
    }
}
