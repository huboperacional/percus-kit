#requires -Version 5.1
# Pester tests para -Mode load logic. Roda sem chamar Anthropic API.

Describe "cross-claude.ps1 -Mode load logic" {
    BeforeAll {
        $script:wrapperPath = Join-Path $PSScriptRoot ".." "providers" "cross-claude.ps1"
        $script:orchPath = Join-Path $PSScriptRoot ".." "scripts" "council-orchestrator.ps1"
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

    It "todo modelo que o router por modo produz esta no ValidateSet do orchestrator" {
        # PowerShell revalida o ValidateSet de um PARAMETRO a cada atribuicao aquela variavel,
        # nao so na entrada. Em 2026-08-15 o switch por modo passou a atribuir claude-sonnet-5 /
        # claude-opus-5 enquanto o ValidateSet ainda listava so a geracao 4: isso derruba o
        # council em TODA invocacao, nao apenas quando alguem usa -CrossClaudeModel. Nenhuma
        # checagem estrutural denuncia -- so runtime, ou este teste.
        # Ancorar o regex no parametro: o primeiro [ValidateSet(...)] do arquivo e o de $Mode.
        $orch = Get-Content $orchPath -Raw
        $set = [regex]::Match($orch,
            '\[ValidateSet\((?<set>[^\)]+)\)\]\s*\r?\n\s*\[string\]\$CrossClaudeModel', 'Singleline')
        $set.Success | Should -BeTrue -Because "o ValidateSet de CrossClaudeModel precisa ser localizavel"
        $permitidos = [regex]::Matches($set.Groups['set'].Value, '"([^"]*)"') |
            ForEach-Object { $_.Groups[1].Value }

        $bloco = [regex]::Match($orch,
            '\$CrossClaudeModel = switch \(\$Mode\) \{(?<b>.+?)\n    \}', 'Singleline')
        $bloco.Success | Should -BeTrue -Because "o switch por modo precisa ser localizavel"
        $produzidos = [regex]::Matches($bloco.Groups['b'].Value, '\{\s*"([^"]+)"\s*\}') |
            ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

        # Sem esta guarda, um regex que parasse de casar deixaria o teste verde por vacuidade.
        $produzidos.Count | Should -BeGreaterThan 0 -Because "o switch tem que produzir modelos"
        foreach ($modelo in $produzidos) {
            $permitidos | Should -Contain $modelo -Because "$modelo e atribuido pelo router"
        }
    }
}
