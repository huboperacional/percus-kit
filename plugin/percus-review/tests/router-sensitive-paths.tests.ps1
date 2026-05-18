#requires -Version 5.1
# Tests: router-sensitive-paths matches em paths que viraram regressao em 2026-05-18.
# Testa diretamente a logica de matching, sem rodar git diff.

Describe "review-router.ps1 — sensitive paths expansion (incidente 2026-05-18)" {
    BeforeAll {
        $script:routerPath = Join-Path $PSScriptRoot ".." "scripts" "review-router.ps1"
    }

    It "matches backend/alembic/versions/049_xyz.py" {
        # Inspect $sensitivePatterns no router e verifica match
        $routerContent = Get-Content $routerPath -Raw
        # Extrai array de patterns
        $patterns = [regex]::Matches($routerContent, "'(\([^']+\)[^']*)'")  | ForEach-Object { $_.Groups[1].Value }
        $testPath = "backend/alembic/versions/049_xyz.py"
        $matched = $false
        foreach ($p in $patterns) {
            if ($testPath -match $p) { $matched = $true; break }
        }
        $matched | Should -Be $true -Because "alembic/versions/ deveria estar coberto"
    }

    It "matches backend/app/api/v1/internal_tickets.py" {
        $routerContent = Get-Content $routerPath -Raw
        $patterns = [regex]::Matches($routerContent, "'(\([^']+\)[^']*)'")  | ForEach-Object { $_.Groups[1].Value }
        $testPath = "backend/app/api/v1/internal_tickets.py"
        $matched = $false
        foreach ($p in $patterns) {
            if ($testPath -match $p) { $matched = $true; break }
        }
        $matched | Should -Be $true -Because "api/v1/internal deveria estar coberto"
    }

    It "matches infra/domains.yaml" {
        $routerContent = Get-Content $routerPath -Raw
        $patterns = [regex]::Matches($routerContent, "'(\([^']+\)[^']*)'")  | ForEach-Object { $_.Groups[1].Value }
        $testPath = "infra/domains.yaml"
        $matched = $false
        foreach ($p in $patterns) {
            if ($testPath -match $p) { $matched = $true; break }
        }
        $matched | Should -Be $true -Because "infra/*.yaml deveria estar coberto"
    }

    It "matches backend/app/config.py" {
        $routerContent = Get-Content $routerPath -Raw
        $patterns = [regex]::Matches($routerContent, "'(\([^']+\)[^']*)'")  | ForEach-Object { $_.Groups[1].Value }
        $testPath = "backend/app/config.py"
        $matched = $false
        foreach ($p in $patterns) {
            if ($testPath -match $p) { $matched = $true; break }
        }
        $matched | Should -Be $true -Because "config.py deveria estar coberto"
    }

    It "matches backend/app/services/webhook/dispatcher.py" {
        $routerContent = Get-Content $routerPath -Raw
        $patterns = [regex]::Matches($routerContent, "'(\([^']+\)[^']*)'")  | ForEach-Object { $_.Groups[1].Value }
        $testPath = "backend/app/services/webhook/dispatcher.py"
        $matched = $false
        foreach ($p in $patterns) {
            if ($testPath -match $p) { $matched = $true; break }
        }
        $matched | Should -Be $true -Because "services/webhook/ deveria estar coberto"
    }

    It "ainda matches paths originais (não regrediu)" {
        $routerContent = Get-Content $routerPath -Raw
        $patterns = [regex]::Matches($routerContent, "'(\([^']+\)[^']*)'") | ForEach-Object { $_.Groups[1].Value }
        $matchedAuth = $false; $matchedPayment = $false; $matchedMigrations = $false
        foreach ($p in $patterns) {
            if ("backend/auth/handler.py" -match $p) { $matchedAuth = $true }
            if ("backend/payments/stripe.py" -match $p) { $matchedPayment = $true }
            if ("migrations/001_init.sql" -match $p) { $matchedMigrations = $true }
        }
        $matchedAuth | Should -Be $true
        $matchedPayment | Should -Be $true
        $matchedMigrations | Should -Be $true
    }

    It "NAO matches docs/README.md (não-regressão pra doc-only)" {
        $routerContent = Get-Content $routerPath -Raw
        $patterns = [regex]::Matches($routerContent, "'(\([^']+\)[^']*)'") | ForEach-Object { $_.Groups[1].Value }
        $testPath = "docs/README.md"
        $matched = $false
        foreach ($p in $patterns) {
            if ($testPath -match $p) { $matched = $true; break }
        }
        $matched | Should -Be $false -Because "doc files NAO deveriam virar sensitive"
    }
}
