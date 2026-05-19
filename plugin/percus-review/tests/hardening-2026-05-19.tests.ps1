#requires -Version 5.1
# Test suite de regressao pro doc consolidado 2026-05-19 (incidentes 2 + 3).
# Cobre Propostas F (hook cross-repo), G (diagnostic messages) e invariantes D+E
# (wrapper nao edita / nao cria branches autonomamente — barrar regressao em v6.8+).

Describe "Hardening 2026-05-19 — incidentes 2 (wrapper auto-edit) + 3 (hook cross-repo)" {
    BeforeAll {
        $script:pluginRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
        $script:hookPs1    = Join-Path $script:pluginRoot "hooks" "pre-commit-check.ps1"
        $script:hookSh     = Join-Path $script:pluginRoot "hooks" "pre-commit-check.sh"
        $script:hooksJson  = Join-Path $script:pluginRoot "hooks" "hooks.json"

        function Invoke-Hook {
            param([string]$command)
            $stdin = @{ tool_input = @{ command = $command } } | ConvertTo-Json -Compress
            # Capture output em $null pra que return $LASTEXITCODE seja o unico valor
            $stdin | & pwsh -NoProfile -File $script:hookPs1 *>$null
            return $LASTEXITCODE
        }
    }

    # =========================================================================
    Context "Proposta F — hook resolve repo target via git toplevel, nao CWD" {

        It "F1. parseia 'cd <dir> && git commit' do command" {
            $content = Get-Content $script:hookPs1 -Raw
            $content | Should -Match 'Get-CommitTargetDir'
            # Hook deve conter ambos os patterns de parse (cd e -C). Procuro literais.
            $content.Contains('cd\s') | Should -Be $true -Because "regex para cd <dir>"
            $content.Contains('-C\s') | Should -Be $true -Because "regex para git -C <dir>"
        }

        It "F2. resolve repo via 'git rev-parse --show-toplevel' do target parseado" {
            $content = Get-Content $script:hookPs1 -Raw
            $content | Should -Match 'rev-parse\s+--show-toplevel'
            # Deve usar git -C "$targetDir", nao git puro
            $content | Should -Match 'git\s+-C\s+"?\$targetDir'
        }

        It "F3. cross-repo: commit em repo SEM review fresco eh BLOQUEADO" {
            $tmpRoot = Join-Path ([IO.Path]::GetTempPath()) "percus-test-$(Get-Random)"
            try {
                $repoA = Join-Path $tmpRoot "repoA"
                $repoB = Join-Path $tmpRoot "repoB"
                New-Item -ItemType Directory -Force -Path $repoA, $repoB | Out-Null
                & git -C $repoA init -q
                & git -C $repoB init -q
                # Review fresco SO em repoA
                $reviewsA = Join-Path $repoA ".deepseek/reviews"
                New-Item -ItemType Directory -Force -Path $reviewsA | Out-Null
                "{}" | Out-File -Encoding utf8 -FilePath (Join-Path $reviewsA "fresh.jsonl")
                # repoB nao tem review nenhum
                $cmd = "git -C `"$repoB`" commit -m teste"
                $rc = Invoke-Hook -command $cmd
                $rc | Should -Be 2 -Because "commit em repoB sem review em repoB deve ser BLOQUEADO mesmo havendo review em repoA"
            } finally {
                Remove-Item -Recurse -Force $tmpRoot -ErrorAction SilentlyContinue
            }
        }

        It "F4. cross-repo: commit em repo COM review fresco eh LIBERADO" {
            $tmpRoot = Join-Path ([IO.Path]::GetTempPath()) "percus-test-$(Get-Random)"
            try {
                $repoB = Join-Path $tmpRoot "repoB"
                New-Item -ItemType Directory -Force -Path $repoB | Out-Null
                & git -C $repoB init -q
                $reviewsB = Join-Path $repoB ".deepseek/reviews"
                New-Item -ItemType Directory -Force -Path $reviewsB | Out-Null
                "{}" | Out-File -Encoding utf8 -FilePath (Join-Path $reviewsB "fresh.jsonl")
                $cmd = "git -C `"$repoB`" commit -m teste"
                $rc = Invoke-Hook -command $cmd
                $rc | Should -Be 0 -Because "commit em repoB com review fresco em repoB deve ser LIBERADO"
            } finally {
                Remove-Item -Recurse -Force $tmpRoot -ErrorAction SilentlyContinue
            }
        }
    }

    # =========================================================================
    Context "Proposta G — diagnostic messages incluem git root + searched path" {

        It "G1. mensagem de bloqueio inclui 'git root:' e 'searched:'" {
            $tmpRoot = Join-Path ([IO.Path]::GetTempPath()) "percus-test-$(Get-Random)"
            try {
                $repoB = Join-Path $tmpRoot "repoB"
                New-Item -ItemType Directory -Force -Path $repoB | Out-Null
                & git -C $repoB init -q
                $stdin = @{ tool_input = @{ command = "git -C `"$repoB`" commit -m x" } } | ConvertTo-Json -Compress
                $output = $stdin | & pwsh -NoProfile -File $script:hookPs1 2>&1
                $joined = $output -join "`n"
                $joined | Should -Match "git root:"
                $joined | Should -Match "searched:"
            } finally {
                Remove-Item -Recurse -Force $tmpRoot -ErrorAction SilentlyContinue
            }
        }

        It "G2. helper Write-BlockContext esta presente" {
            $content = Get-Content $script:hookPs1 -Raw
            $content | Should -Match "Write-BlockContext"
        }

        It "G3. mensagem inclui 'cwd:' quando CWD difere do git root" {
            $content = Get-Content $script:hookPs1 -Raw
            $content | Should -Match '\$cwd\s+-ne\s+\$repoRoot'
            $content | Should -Match 'cwd:'
        }
    }

    # =========================================================================
    Context "Invariante D — plugin nao registra hook que aplique Edit/Write" {

        It "D1. hooks.json NAO declara PostToolUse" {
            Test-Path $script:hooksJson | Should -Be $true
            $json = Get-Content $script:hooksJson -Raw | ConvertFrom-Json
            $json.hooks.PSObject.Properties.Name | Should -Not -Contain "PostToolUse" `
                -Because "incidente 2 atribuiu auto-rename a PostToolUse:Edit; canon nao registra hooks de mutacao"
        }

        It "D2. nenhum hook PreToolUse com matcher Edit/Write/MultiEdit/NotebookEdit" {
            $json = Get-Content $script:hooksJson -Raw | ConvertFrom-Json
            if ($json.hooks.PreToolUse) {
                foreach ($entry in $json.hooks.PreToolUse) {
                    $entry.matcher | Should -Not -Match '^(Edit|Write|MultiEdit|NotebookEdit)$' `
                        -Because "hook que intercepta Edit/Write pode aplicar mudancas — viola invariante D"
                }
            }
        }
    }

    # =========================================================================
    Context "Invariante E — nenhum script do plugin cria branches autonomamente" {

        It "E1. zero ocorrencias de 'git checkout -b'/'git switch -c'/'git branch <novo>' em scripts/hooks" {
            $scriptDirs = @(
                (Join-Path $script:pluginRoot "scripts"),
                (Join-Path $script:pluginRoot "hooks"),
                (Join-Path $script:pluginRoot "skills"),
                (Join-Path $script:pluginRoot "commands")
            ) | Where-Object { Test-Path $_ }

            $files = Get-ChildItem -Path $scriptDirs -Recurse -Include *.ps1, *.sh, *.cmd -ErrorAction SilentlyContinue
            $offenders = @()
            foreach ($f in $files) {
                $c = Get-Content $f.FullName -Raw
                # Tres padroes destrutivos. Excluir comentarios/heredoc seria custoso —
                # qualquer match estatico ja conta como offender (auditar manualmente
                # se finding for falso positivo).
                if ($c -match '\bgit\s+checkout\s+-b\b') { $offenders += "checkout -b: $($f.FullName)" }
                if ($c -match '\bgit\s+switch\s+-[cC]\b') { $offenders += "switch -c: $($f.FullName)" }
                # `git branch foo` mas NAO `git branch --list/-D/-d/-a/-r/--show-current/--all/--contains`
                if ($c -match '(?m)^\s*[^#].*\bgit\s+branch\s+(?!--|-[a-zA-Z]|\$)\S+') { $offenders += "branch <new>: $($f.FullName)" }
            }
            $offenders | Should -BeNullOrEmpty -Because "wrapper nao deve criar branches autonomamente (incidente 2)"
        }
    }

    # =========================================================================
    Context "PERCUS_HOOKS_DISABLED escape (Proposta H — regressao)" {

        It "H1. hook honra PERCUS_HOOKS_DISABLED=1" {
            $env:PERCUS_HOOKS_DISABLED = "1"
            try {
                $rc = Invoke-Hook -command "git commit -m teste"
                $rc | Should -Be 0 -Because "PERCUS_HOOKS_DISABLED=1 deve liberar sem checar reviews"
            } finally {
                Remove-Item env:PERCUS_HOOKS_DISABLED -ErrorAction SilentlyContinue
            }
        }
    }
}
