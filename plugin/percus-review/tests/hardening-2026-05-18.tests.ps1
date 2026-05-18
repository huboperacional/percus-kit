#requires -Version 5.1
# Test suite de regressao pro incidente Plexco Tasks 2026-05-18.
# Valida que mecanismos de defesa implementados em v6.7.0 estao presentes e funcionais.
# Testes estaticos (inspecao de codigo) — nao requerem API calls pagas.

Describe "Hardening 2026-05-18 — incident regression prevention" {
    BeforeAll {
        if (-not $env:PERCUS_CANON_DIR) {
            $env:PERCUS_CANON_DIR = "D:\Claud Automations\_Novo_Projeto"
        }
        $script:routerPath = Join-Path $PSScriptRoot ".." "scripts" "review-router.ps1"
        $script:factCheckPath = Join-Path $PSScriptRoot ".." "scripts" "fact-check.ps1"
        $script:orchPath = Join-Path $PSScriptRoot ".." "scripts" "council-orchestrator.ps1"
        $script:hookPath = Join-Path $PSScriptRoot ".." "hooks" "external-action-guard.ps1"
        $script:dedupPath = Join-Path $PSScriptRoot ".." "scripts" "dedup-findings.ps1"
        $script:canonPath = Join-Path $env:PERCUS_CANON_DIR "01_REGRAS_INEGOCIAVEIS.md"
    }

    # -------------------------------------------------------------------------
    Context "Cenario 1: Router sensitive_paths cobre alembic (causa raiz F1)" {
        It "1. alembic-only PR seria classificado sensitive (incidente 2026-05-18)" {
            $content = Get-Content $routerPath -Raw
            # Extrai patterns no formato '(...)' do array $sensitivePatterns
            $patterns = [regex]::Matches($content, "'(\([^']+\)[^']*)'") | ForEach-Object { $_.Groups[1].Value }
            $testPath = "backend/alembic/versions/099_test.py"
            $matched = $false
            foreach ($p in $patterns) { if ($testPath -match $p) { $matched = $true; break } }
            $matched | Should -Be $true -Because "alembic deveria estar em sensitive_paths apos F1 (incidente 2026-05-18)"
        }
    }

    # -------------------------------------------------------------------------
    Context "Cenario 2: fact-check filtra INFUNDADO" {
        It "2a. fact-check.ps1 existe e declara suporte a INFUNDADO (estatico)" {
            Test-Path $factCheckPath | Should -Be $true
            $content = Get-Content $factCheckPath -Raw
            $content | Should -Match 'INFUNDADO'
            $content | Should -Match 'filtered_output'
            $content | Should -Match 'cross-claude'
        }

        It "2b. input 'Sem findings criticos' retorna findings_total=0 (sem API call)" {
            $emptyInput = "Sem findings criticos.`n`nO diff e limpo."
            $raw = $emptyInput | & pwsh -NoProfile -File $factCheckPath 2>&1
            $json = $raw | Out-String | ConvertFrom-Json -ErrorAction SilentlyContinue
            # Script pode retornar via ConvertTo-Json: findings_total 0 ou skipped
            $json | Should -Not -BeNullOrEmpty -Because "fact-check deve retornar JSON valido sempre"
            $json.findings_total | Should -Be 0 -Because "sem findings criticos parseaveis"
        }
    }

    # -------------------------------------------------------------------------
    Context "Cenario 3: Council code injection + premise_validity (F2)" {
        It "3a. council-orchestrator aceita -CodeContextDir (F2 support)" {
            $content = Get-Content $orchPath -Raw
            $content | Should -Match "CodeContextDir"
        }

        It "3b. council-orchestrator parse premise_validity das respostas dos providers" {
            $content = Get-Content $orchPath -Raw
            $content | Should -Match "premise_validity"
        }

        It "3c. council-orchestrator agrega premise_validity_consensus" {
            $content = Get-Content $orchPath -Raw
            $content | Should -Match "premise_validity_consensus"
        }

        It "3d. system prompt anti-alucinacao instrui providers a validar claims antes de opinar" {
            $content = Get-Content $orchPath -Raw
            # Instrucao anti-alucinacao deve conter referencia explicita a validacao de premissa
            $content | Should -Match "INVALIDA_PREMISSA|premissa|ANTES de opinar"
        }
    }

    # -------------------------------------------------------------------------
    Context "Cenario 4: Doc-only PR nao regride para sensitive (negative test)" {
        It "4. doc-only PR (.md) nao e classificado como sensitive" {
            $content = Get-Content $routerPath -Raw
            $patterns = [regex]::Matches($content, "'(\([^']+\)[^']*)'") | ForEach-Object { $_.Groups[1].Value }
            $matchedReadme = $false
            $matchedHandoff = $false
            foreach ($p in $patterns) {
                if ("docs/README.md" -match $p) { $matchedReadme = $true; break }
                if ("HANDOFF.md" -match $p) { $matchedHandoff = $true; break }
            }
            $matchedReadme | Should -Be $false -Because "docs/README.md NAO eh sensitive"
            $matchedHandoff | Should -Be $false -Because "HANDOFF.md NAO eh sensitive"
        }
    }

    # -------------------------------------------------------------------------
    Context "Cenario 5+: defenses runtime" {
        It "5. external-action-guard hook bloqueia gh pr comment sem override (R20)" {
            Test-Path $hookPath | Should -Be $true
            Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
            $stdin = '{"tool_input":{"command":"gh pr comment 1 --body teste"}}'
            $stdin | & pwsh -NoProfile -File $hookPath 2>&1 | Out-Null
            $LASTEXITCODE | Should -Be 2 -Because "gh pr comment sem PERCUS_EXTERNAL_OVERRIDE deve ser bloqueado (R20)"
        }

        It "6. dedup-findings.ps1 usa hash MD5 e campo occurrences" {
            Test-Path $dedupPath | Should -Be $true
            $content = Get-Content $dedupPath -Raw
            $content | Should -Match "MD5|md5"
            $content | Should -Match "occurrences"
        }

        It "7. canon 01_REGRAS_INEGOCIAVEIS.md contem R20 com conteudo de acao externa publica" {
            Test-Path $canonPath | Should -Be $true
            $content = Get-Content $canonPath -Raw
            $content | Should -Match "## R20\."
            $content | Should -Match "a[cç][aã]o externa p[uú]blica"
        }
    }
}
