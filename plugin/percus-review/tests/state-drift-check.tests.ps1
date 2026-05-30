#requires -Version 5.1
# Testes do hook state-drift-check (R2 / R8 / v6.12.0).
#
# Hook Stop event. BLOQUEIA (exit 2) o encerramento da sessao quando uma feature
# tem tag de status DIVERGENTE entre docs/PLANO.md (fonte da verdade) e HANDOFF.md.
# Ex: feature "Login OTP" e [5-T] no PLANO mas [3-H] no HANDOFF -> drift documentado
# = mentira no estado. Resolve antes de encerrar.
#
# Conservador por design (fail-open): se nao consegue parsear/casar nomes com
# confianca, NAO bloqueia. So bloqueia em divergencia confiavel (mesmo nome
# normalizado, tags diferentes). Falha graceful: qualquer erro -> exit 0.
#
# Skip: $env:PERCUS_SKIP_DRIFT_CHECK=1 (ou $env:PERCUS_HOOKS_DISABLED).

Describe "state-drift-check hook (R2 PLANO vs HANDOFF)" {
    BeforeAll {
        $script:hook = Join-Path $PSScriptRoot ".." "hooks" "state-drift-check.ps1"

        function New-DriftRepo {
            param(
                [string]$Plano,
                [string]$Handoff,
                [string]$Subdir = "docs"   # "" = raiz
            )
            $repo = Join-Path ([IO.Path]::GetTempPath()) "drift-test-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $repo | Out-Null
            $enc = New-Object System.Text.UTF8Encoding($false)
            $base = if ($Subdir) { Join-Path $repo $Subdir } else { $repo }
            if ($Subdir -and -not (Test-Path $base)) { New-Item -ItemType Directory -Force -Path $base | Out-Null }
            if ($null -ne $Plano)   { [System.IO.File]::WriteAllText((Join-Path $base "PLANO.md"),   $Plano,   $enc) }
            if ($null -ne $Handoff) { [System.IO.File]::WriteAllText((Join-Path $base "HANDOFF.md"), $Handoff, $enc) }
            return $repo
        }

        function Invoke-Drift {
            param([string]$Repo)
            $stdin = @{ cwd = $Repo; transcript_path = "" } | ConvertTo-Json -Compress
            $out = $stdin | & pwsh -NoProfile -File $script:hook 2>&1
            return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
        }

        # Helpers de conteudo realista ----------------------------------------
        $script:Legenda = @'
## Legenda

| Tag | Significado | Condicao |
|-----|-------------|----------|
| `[0]` | Planejada | — |
| `[5-T]` | Testado | ciclo CRUD F5 |

'@
        function Plano {
            param([string]$Body)
            return $script:Legenda + "## Frente: Auth`n`n" + $Body + "`n"
        }
        function Handoff {
            param([string]$Rows)
            return @"
# Handoff

## Status de Features

| Frente | Feature | Status | Proxima |
|--------|---------|--------|---------|
$Rows

## Credenciais e arquivos externos

| Arquivo | Status | Onde |
|---|---|---|
| credentials.json | OK | GCP |
"@
        }
    }

    It "existe" {
        Test-Path $hook | Should -Be $true
    }

    Context "Concordancia -> nao bloqueia" {
        It "1. PLANO e HANDOFF concordam em todas as features -> exit 0" {
            $repo = New-DriftRepo -Plano (Plano "- ``[5-T]`` Login OTP — testado`n- ``[3-H]`` Cadastro — hook ok") `
                                  -Handoff (Handoff "| Auth | Login OTP | ``[5-T]`` | — |`n| Auth | Cadastro | ``[3-H]`` | hook |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 0
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "6. nomes com marcacoes visuais + acentos normalizam e concordam -> exit 0" {
            $repo = New-DriftRepo -Plano (Plano "- ``[5-T]`` ✓ ✅ Importacao de leads — testado") `
                                  -Handoff (Handoff "| Dados | Importacao de leads | ``[5-T]`` ✓ | — |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 0
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "7. tabela de Legenda no PLANO nao e parseada como feature (sem falso drift)" {
            # Legenda tem `[5-T]` e `[0]` em linhas de TABELA; nao devem virar features.
            $repo = New-DriftRepo -Plano (Plano "- ``[3-H]`` Relatorios — hook ok") `
                                  -Handoff (Handoff "| Rel | Relatorios | ``[3-H]`` | — |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 0 -Because "linhas da Legenda sao tabela, nao bullets de feature"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }
    }

    Context "Divergencia -> bloqueia (exit 2)" {
        It "2. [5-T] no PLANO vs [3-H] no HANDOFF -> exit 2 nomeando feature + tags" {
            $repo = New-DriftRepo -Plano (Plano "- ``[5-T]`` Login OTP — testado") `
                                  -Handoff (Handoff "| Auth | Login OTP | ``[3-H]`` | hook |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 2
                $r.Out | Should -Match "Login OTP"
                $r.Out | Should -Match "5-T"
                $r.Out | Should -Match "3-H"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "11. multiplas features, so 1 divergente -> bloqueia nomeando a certa" {
            $repo = New-DriftRepo -Plano (Plano "- ``[5-T]`` Login OTP — testado`n- ``[4-C]`` Dashboard — falta CRUD") `
                                  -Handoff (Handoff "| Auth | Login OTP | ``[5-T]`` | — |`n| UI | Dashboard | ``[2-E]`` | hook+comp |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 2
                $r.Out | Should -Match "Dashboard"
                $r.Out | Should -Not -Match "Login OTP"   # essa concorda, nao deve ser citada
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "10. arquivos na RAIZ (sem docs/) tambem sao detectados -> drift bloqueia" {
            $repo = New-DriftRepo -Subdir "" -Plano (Plano "- ``[5-T]`` Webhook — testado") `
                                  -Handoff (Handoff "| Int | Webhook | ``[2-E]`` | hook |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 2
                $r.Out | Should -Match "Webhook"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }
    }

    Context "Conservador / graceful / escapes" {
        It "3. feature so no PLANO (ausente no HANDOFF) -> nao bloqueia" {
            $repo = New-DriftRepo -Plano (Plano "- ``[5-T]`` Login OTP — testado`n- ``[1-S]`` Feature Nova — schema") `
                                  -Handoff (Handoff "| Auth | Login OTP | ``[5-T]`` | — |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 0 -Because "feature sem par nao pode ser comparada (conservador)"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "4. HANDOFF ausente -> exit 0 (graceful)" {
            $repo = New-DriftRepo -Plano (Plano "- ``[5-T]`` Login OTP — testado") -Handoff $null
            try {
                Invoke-Drift -Repo $repo | Select-Object -ExpandProperty Code | Should -Be 0
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "5. PLANO ausente -> exit 0 (graceful)" {
            $repo = New-DriftRepo -Plano $null -Handoff (Handoff "| Auth | Login OTP | ``[5-T]`` | — |")
            try {
                Invoke-Drift -Repo $repo | Select-Object -ExpandProperty Code | Should -Be 0
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "8. PERCUS_SKIP_DRIFT_CHECK=1 -> exit 0 mesmo com drift" {
            $repo = New-DriftRepo -Plano (Plano "- ``[5-T]`` Login OTP — testado") `
                                  -Handoff (Handoff "| Auth | Login OTP | ``[3-H]`` | hook |")
            try {
                $env:PERCUS_SKIP_DRIFT_CHECK = "1"
                $r = Invoke-Drift -Repo $repo
                Remove-Item env:PERCUS_SKIP_DRIFT_CHECK -ErrorAction SilentlyContinue
                $r.Code | Should -Be 0
            } finally {
                Remove-Item env:PERCUS_SKIP_DRIFT_CHECK -ErrorAction SilentlyContinue
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }

        It "9. stdin vazio -> exit 0 (graceful)" {
            $out = "" | & pwsh -NoProfile -File $script:hook 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "12. nenhum dos dois arquivos existe -> exit 0" {
            $repo = New-DriftRepo -Plano $null -Handoff $null
            try {
                Invoke-Drift -Repo $repo | Select-Object -ExpandProperty Code | Should -Be 0
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }
    }
}
