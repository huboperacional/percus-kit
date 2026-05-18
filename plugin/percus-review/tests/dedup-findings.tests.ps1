#requires -Version 5.1
# Tests: dedup-findings.ps1 — F5 echo dedup findings em PRs stackados.
# TDD: escrever primeiro, rodar ANTES da implementacao (todos devem falhar).

Describe "dedup-findings.ps1" {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot ".." "scripts" "dedup-findings.ps1"
        $script:fixtureDir = Join-Path $env:TEMP "dedup-test-fixtures"
        New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null

        # 3 PRs com mesmo finding (ecoado em stack)
        Set-Content -Path (Join-Path $fixtureDir "pr2.md") -Value @"
## Findings DeepSeek

[SEV: risco] Arquivo: backend/app/api/v1/support_tickets.py:170-176
Problema: Webhook ticket.closed dispara antes de db.delete sem rollback.
Sugestao: Mover dispatch pra apos commit.
"@ -Encoding utf8

        Set-Content -Path (Join-Path $fixtureDir "pr3.md") -Value @"
## Findings DeepSeek

[SEV: risco] Arquivo: backend/app/api/v1/support_tickets.py:170-176
Problema: Webhook ticket.closed dispara antes de db.delete sem rollback.
Sugestao: Mover dispatch pra apos commit.
"@ -Encoding utf8

        Set-Content -Path (Join-Path $fixtureDir "pr4.md") -Value @"
## Findings DeepSeek

[SEV: risco] Arquivo: backend/app/api/v1/support_tickets.py:170-176
Problema: Webhook ticket.closed dispara antes de db.delete sem rollback.
Sugestao: Mover dispatch pra apos commit.

[SEV: bug] Arquivo: outro.py:10
Problema: typo no nome de variavel.
"@ -Encoding utf8
    }

    AfterAll {
        if (Test-Path $fixtureDir) { Remove-Item -Recurse -Force $fixtureDir }
    }

    It "existe" {
        Test-Path $scriptPath | Should -Be $true
    }

    It "dedup 3 findings identicos -> 2 uniques (1 ecoado + 1 bug unico)" {
        $result = & pwsh -NoProfile -File $scriptPath -FindingsDir $fixtureDir 2>&1 | ConvertFrom-Json
        $result.total_raw | Should -BeGreaterOrEqual 4  # 3 echoes + 1 unique
        $result.total_unique | Should -Be 2  # 1 ecoado + 1 unico
    }

    It "preserva todos os findings unicos" {
        $result = & pwsh -NoProfile -File $scriptPath -FindingsDir $fixtureDir 2>&1 | ConvertFrom-Json
        $result.groups | Where-Object { $_.occurrences -eq 3 } | Should -Not -BeNullOrEmpty
        $result.groups | Where-Object { $_.occurrences -eq 1 } | Should -Not -BeNullOrEmpty
    }

    It "consolidated_md inclui nota 'presente em N PRs' quando dedup" {
        $result = & pwsh -NoProfile -File $scriptPath -FindingsDir $fixtureDir 2>&1 | ConvertFrom-Json
        $result.consolidated_md | Should -Match "(?i)presente em|ecoado em|3 ocorr"
    }

    It "sources sao listados (pr2, pr3, pr4 ou similar)" {
        $result = & pwsh -NoProfile -File $scriptPath -FindingsDir $fixtureDir 2>&1 | ConvertFrom-Json
        $ecoed = $result.groups | Where-Object { $_.occurrences -eq 3 }
        $ecoed.sources.Count | Should -Be 3
    }

    It "edge case: pasta vazia retorna estrutura vazia" {
        $emptyDir = Join-Path $env:TEMP "dedup-empty-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $result = & pwsh -NoProfile -File $scriptPath -FindingsDir $emptyDir 2>&1 | ConvertFrom-Json
        $result.total_raw | Should -Be 0
        Remove-Item $emptyDir -Recurse -Force
    }
}
