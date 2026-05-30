#requires -Version 5.1
# Testes do hook crud-evidence-warn (R2 / v6.12.0).
#
# Hook PreToolUse:Bash, WARN-ONLY (exit 0 sempre — nunca bloqueia).
# Quando o staged diff de PLANO.md/HANDOFF.md ADICIONA uma feature em [5-T] e o
# comando `git commit` NAO contem o trailer `CRUD-verified: YYYY-MM-DD`, avisa
# (stderr + log .deepseek/crud-warn.log) que o ciclo F5 (R1) precisa ser confirmado.
#
# Sem promocao automatica warn->block (decisao do conselho registrada no plano
# v6.11->v7.0). Aqui validamos: warn dispara quando deve, fica silencioso quando
# o trailer esta presente, e NUNCA retorna exit != 0.

Describe "crud-evidence-warn hook (R2 trailer warn-only)" {
    BeforeAll {
        $script:hook = Join-Path $PSScriptRoot ".." "hooks" "crud-evidence-warn.ps1"

        function New-PlanoRepo {
            param(
                [string]$Content,
                [string]$BaseContent = $null,
                [string]$RelPath = "docs/PLANO.md"
            )
            $repo = Join-Path ([IO.Path]::GetTempPath()) "crudwarn-test-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $repo | Out-Null
            & git -C $repo init -q
            & git -C $repo config user.email "t@t.t"
            & git -C $repo config user.name "t"
            & git -C $repo config commit.gpgsign false
            $full = Join-Path $repo $RelPath
            $dir = Split-Path $full -Parent
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            $enc = New-Object System.Text.UTF8Encoding($false)
            if ($null -ne $BaseContent) {
                # Cria versao base committada, depois aplica a versao staged (modificacao).
                [System.IO.File]::WriteAllText($full, $BaseContent, $enc)
                & git -C $repo add -A
                & git -C $repo commit -q -m "base" | Out-Null
            }
            [System.IO.File]::WriteAllText($full, $Content, $enc)
            & git -C $repo add -A
            return $repo
        }

        function Invoke-CrudWarn {
            param(
                [string]$Repo,
                [string]$Message = "feat: alguma coisa",
                [switch]$WithTrailer,
                [switch]$Amend,
                [string]$RawCommand
            )
            if ($RawCommand) {
                $cmd = $RawCommand
            } elseif ($Amend) {
                $cmd = "cd `"$Repo`" && git commit --amend --no-edit"
            } else {
                $body = $Message
                if ($WithTrailer) { $body = "$Message`n`nCRUD-verified: 2026-05-30 14:30" }
                # -F via here-string nao da; usamos -m simples. O hook so precisa ver
                # a string 'CRUD-verified: <data>' em algum lugar do comando.
                $cmd = "cd `"$Repo`" && git commit -m `"$body`""
            }
            $stdin = @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            $out = $stdin | & pwsh -NoProfile -File $script:hook 2>&1
            return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
        }
    }

    It "existe" {
        Test-Path $hook | Should -Be $true
    }

    Context "Warn dispara quando [5-T] e adicionado sem trailer" {
        It "1. PLANO novo com feature [5-T] sem trailer -> warn, mas exit 0" {
            $repo = New-PlanoRepo -Content @'
## Frente: Auth

- `[5-T]` Login OTP — testado nesta sessao
- `[4-C]` Cadastro — falta CRUD
'@
            try {
                $r = Invoke-CrudWarn -Repo $repo
                $r.Code | Should -Be 0 -Because "warn-only NUNCA bloqueia"
                $r.Out | Should -Match "(?i)CRUD-verified"
                $r.Out | Should -Match "Login OTP"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "2. transicao [4-C] -> [5-T] em PLANO existente sem trailer -> warn" {
            $repo = New-PlanoRepo -BaseContent @'
## Frente: Auth

- `[4-C]` Login OTP — falta CRUD
'@ -Content @'
## Frente: Auth

- `[5-T]` Login OTP — testado agora
'@
            try {
                $r = Invoke-CrudWarn -Repo $repo
                $r.Code | Should -Be 0
                $r.Out | Should -Match "Login OTP"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "3. HANDOFF.md marcando [5-T] sem trailer tambem dispara warn" {
            $repo = New-PlanoRepo -RelPath "HANDOFF.md" -Content @'
## Status de Features

| Frente | Feature | Status | Proxima |
|--------|---------|--------|---------|
| Auth | Login OTP | `[5-T]` | — |
'@
            try {
                $r = Invoke-CrudWarn -Repo $repo
                $r.Code | Should -Be 0
                $r.Out | Should -Match "(?i)CRUD-verified"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "4. grava log em .deepseek/crud-warn.log" {
            $repo = New-PlanoRepo -Content "## Frente: X`n`n- ``[5-T]`` Feature Y — ok"
            try {
                Invoke-CrudWarn -Repo $repo | Out-Null
                $log = Join-Path $repo ".deepseek/crud-warn.log"
                Test-Path $log | Should -Be $true
                (Get-Content $log -Raw) | Should -Match "Feature Y"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }
    }

    Context "Silencioso quando trailer presente ou nao ha [5-T]" {
        It "5. [5-T] adicionado COM trailer CRUD-verified -> sem warn" {
            $repo = New-PlanoRepo -Content "## Frente: X`n`n- ``[5-T]`` Login OTP — testado"
            try {
                $r = Invoke-CrudWarn -Repo $repo -WithTrailer
                $r.Code | Should -Be 0
                $r.Out | Should -Not -Match "(?i)percus:warn"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "6. diff sem nenhuma transicao [5-T] -> sem warn" {
            $repo = New-PlanoRepo -Content @'
## Frente: X

- `[4-C]` Login OTP — falta CRUD
- `[2-E]` Cadastro — endpoint ok
'@
            try {
                $r = Invoke-CrudWarn -Repo $repo
                $r.Code | Should -Be 0
                $r.Out | Should -Not -Match "(?i)percus:warn"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "7. [5-T] ja existia na base (nao e adicao neste commit) -> sem warn" {
            $repo = New-PlanoRepo -BaseContent "## Frente: X`n`n- ``[5-T]`` Login OTP — ja testado antes" `
                                  -Content "## Frente: X`n`n- ``[5-T]`` Login OTP — ja testado antes`n- ``[2-E]`` Nova feature"
            try {
                $r = Invoke-CrudWarn -Repo $repo
                $r.Code | Should -Be 0
                $r.Out | Should -Not -Match "(?i)percus:warn"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }
    }

    Context "Escapes e robustez" {
        It "8. comando que nao e git commit -> exit 0 silencioso" {
            $repo = New-PlanoRepo -Content "## Frente: X`n`n- ``[5-T]`` Feature — ok"
            try {
                $r = Invoke-CrudWarn -Repo $repo -RawCommand "cd `"$repo`" && git status"
                $r.Code | Should -Be 0
                $r.Out | Should -Not -Match "(?i)percus:warn"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "9. git commit --amend --no-edit -> skip (exit 0, sem warn)" {
            $repo = New-PlanoRepo -BaseContent "## Frente: X`n`n- ``[4-C]`` F — x" `
                                  -Content "## Frente: X`n`n- ``[5-T]`` F — x"
            try {
                $r = Invoke-CrudWarn -Repo $repo -Amend
                $r.Code | Should -Be 0
                $r.Out | Should -Not -Match "(?i)percus:warn"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "10. PERCUS_SKIP_CRUD_WARN=1 -> silencioso mesmo com [5-T]" {
            $repo = New-PlanoRepo -Content "## Frente: X`n`n- ``[5-T]`` Feature — ok"
            try {
                $env:PERCUS_SKIP_CRUD_WARN = "1"
                $r = Invoke-CrudWarn -Repo $repo
                Remove-Item env:PERCUS_SKIP_CRUD_WARN -ErrorAction SilentlyContinue
                $r.Code | Should -Be 0
                $r.Out | Should -Not -Match "(?i)percus:warn"
            } finally {
                Remove-Item env:PERCUS_SKIP_CRUD_WARN -ErrorAction SilentlyContinue
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }

        It "11. stdin vazio -> exit 0 (graceful)" {
            $out = "" | & pwsh -NoProfile -File $script:hook 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "12. projeto sem .git -> exit 0 (graceful)" {
            $tmp = Join-Path ([IO.Path]::GetTempPath()) "crudwarn-nogit-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $tmp | Out-Null
            try {
                $r = Invoke-CrudWarn -Repo $tmp
                $r.Code | Should -Be 0
            } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
        }
    }
}
