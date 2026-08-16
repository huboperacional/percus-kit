#requires -Version 5.1
# Pester tests para -Mode load logic. Roda sem chamar Anthropic API.

Describe "cross-claude.ps1 -Mode load logic" {
    BeforeAll {
        $script:wrapperPath = Join-Path $PSScriptRoot ".." "providers" "cross-claude.ps1"
        $script:orchPath = Join-Path $PSScriptRoot ".." "scripts" "council-orchestrator.ps1"
        $script:orchShPath = Join-Path $PSScriptRoot ".." "scripts" "council-orchestrator.sh"
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

    It "o router por modo do .ps1 e do .sh escolhem os MESMOS modelos" {
        # O conselho tem dois orquestradores (PowerShell e bash) com a mesma tabela escrita duas
        # vezes. Em 2026-08-15 o .ps1 subiu pra geracao 5 e o .sh ficou na 4 -- e foi empurrado
        # assim na 6.36.2, porque nada comparava os dois. Quem roda por bash usava outro conselho.
        $psSrc = Get-Content $orchPath -Raw
        $shSrc = Get-Content $orchShPath -Raw

        $psBloco = [regex]::Match($psSrc,
            '\$CrossClaudeModel = switch \(\$Mode\) \{(?<b>.+?)\n    \}', 'Singleline')
        $psBloco.Success | Should -BeTrue -Because "o switch do .ps1 precisa ser localizavel"
        # captura "modo { modelo }" ignorando linhas de comentario
        $psMapa = @{}
        foreach ($m in [regex]::Matches($psBloco.Groups['b'].Value,
                '(?m)^\s*"?(?<modo>[a-z\-]+|default)"?\s*\{\s*"(?<modelo>[^"]+)"\s*\}')) {
            $psMapa[$m.Groups['modo'].Value] = $m.Groups['modelo'].Value
        }

        # NAO ancorar no bloco `case "$MODE" in`: existem DOIS no arquivo (o primeiro e o parser
        # de argumentos) e um Match pega o primeiro -- foi assim que este teste nasceu verde-
        # vazio. Ancora na propria atribuicao, e exige valor "claude-*" pra nao capturar a linha
        # `--cross-claude-model) CROSS_CLAUDE_MODEL="$2"` do parser.
        $shMapa = @{}
        foreach ($m in [regex]::Matches($shSrc,
                '(?m)^\s*(?<modo>[a-z\-]+|\*)\)\s*CROSS_CLAUDE_MODEL="(?<modelo>claude-[^"]+)"')) {
            $modo = if ($m.Groups['modo'].Value -eq '*') { 'default' } else { $m.Groups['modo'].Value }
            $shMapa[$modo] = $m.Groups['modelo'].Value
        }

        # Anti-vacuidade dos dois lados: regex que parasse de casar deixaria o teste verde.
        $psMapa.Count | Should -BeGreaterThan 2 -Because "o .ps1 tem 4+ modos mapeados"
        $shMapa.Count | Should -BeGreaterThan 2 -Because "o .sh tem 4+ modos mapeados"
        ($psMapa.Keys | Sort-Object) -join ',' | Should -Be (($shMapa.Keys | Sort-Object) -join ',') `
            -Because "os dois orquestradores tem que cobrir os mesmos modos"
        foreach ($modo in $psMapa.Keys) {
            $shMapa[$modo] | Should -Be $psMapa[$modo] -Because "modo '$modo' divergiu entre .ps1 e .sh"
        }
    }
}
