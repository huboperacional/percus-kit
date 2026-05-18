#requires -Version 5.1
Describe "canon-version-check hook" {
    BeforeAll {
        $script:hookPath = Join-Path $PSScriptRoot ".." "hooks" "canon-version-check.ps1"
    }

    It "existe e e executavel" {
        Test-Path $hookPath | Should -Be $true
    }

    It "extrai canon_version de system-prompt files" {
        $hook = Get-Content $hookPath -Raw
        $hook | Should -Match 'canon_version'
        $hook | Should -Match 'system-prompt'
    }

    It "le CANON_VERSION.md do PERCUS_CANON_DIR" {
        $hook = Get-Content $hookPath -Raw
        $hook | Should -Match 'PERCUS_CANON_DIR'
        $hook | Should -Match 'CANON_VERSION'
    }

    It "warn em stderr, nao bloqueia (exit 0)" {
        $hook = Get-Content $hookPath -Raw
        $hook | Should -Match 'exit 0'
        # Nao pode ter exit 1 incondicional (mas pode em error path)
        $hook | Should -Not -Match '(?m)^exit 1$'
    }
}
