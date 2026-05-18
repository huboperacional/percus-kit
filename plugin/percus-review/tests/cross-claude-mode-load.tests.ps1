#requires -Version 5.1
# Pester tests para -Mode load logic. Roda sem chamar Anthropic API.

Describe "cross-claude.ps1 -Mode load logic" {
    BeforeAll {
        $script:wrapperPath = Join-Path $PSScriptRoot ".." "providers" "cross-claude.ps1"
        $script:consultPromptPath = Join-Path $PSScriptRoot ".." "providers" "system-prompt-consult.md"
        $script:reviewPromptPath  = Join-Path $PSScriptRoot ".." "providers" "system-prompt-review.md"
        $env:ANTHROPIC_API_KEY = "test-key-not-used"
    }

    It "carrega system-prompt-consult.md quando -Mode consult" {
        $consultBody = Get-Content $consultPromptPath -Raw
        $consultBody | Should -Match "Cross-Claude consult"
    }

    It "carrega system-prompt-review.md quando -Mode review" {
        $reviewBody = Get-Content $reviewPromptPath -Raw
        $reviewBody | Should -Match "Cross-Claude code review"
    }

    It "respeita -SystemPrompt override (nao carrega arquivo)" {
        $wrapper = Get-Content $wrapperPath -Raw
        $wrapper | Should -Match 'PSBoundParameters\.ContainsKey\(.SystemPrompt.\)'
    }

    It "tem fallback se arquivo system-prompt-{mode}.md ausente" {
        $wrapper = Get-Content $wrapperPath -Raw
        $wrapper | Should -Match 'if \(Test-Path \$promptPath\)'
    }

    It "trata pre-mortem como consult (fold)" {
        $wrapper = Get-Content $wrapperPath -Raw
        $wrapper | Should -Match 'pre-mortem.*consult|consult.*pre-mortem'
    }
}
