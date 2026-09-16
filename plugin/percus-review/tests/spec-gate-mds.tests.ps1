#requires -Version 5.1
# MDS Lote A (pecas aprovadas em 2026-09-15): gate de spec do trilho G.
#
# T1 -- templates\spec-checklist.template.md, secao "Completude", ganha 2 itens:
#   * suficiencia: quem recebe a spec sem ter participado da conversa implementaria sem voltar a perguntar?
#   * artefatos-fonte: a estrutura do artefato que o pedido trouxe esta nos FR ou em "Entidades-chave"?
# Os dois itens ficam do lado do O QUE (a Fronteira WHAT/HOW do mesmo checklist barra "tabela"/"endpoint").
#
# T2 -- falseabilidade. Procedimento (V2) em v2\loops\spec.md: "violado quando ___" no Formato EARS e 2
# armadilhas nomeadas (enumeracao aberta, verbo que delimita). Checagem (V1) na secao "Clareza" do checklist:
# a pergunta curta + ponteiro para o loop; as armadilhas NAO sao copiadas para o checklist (R25).
#
# Cada asseracao e uma funcao que devolve a lista de falhas, para que o MESMO codigo rode contra o arquivo
# real (lista vazia) e contra um texto sabotado (lista nao-vazia). Sem o caso sabotado, um teste que casa
# por regex pode ficar verde por vacuidade (secao nao achada, regex que nunca falha).

Describe "gate de spec -- pecas MDS no spec-checklist e no loop de spec" {

    BeforeAll {
        $script:raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path

        function Get-TextoCanon {
            param([string]$Relativo)
            $p = Join-Path $script:raiz $Relativo
            if (-not (Test-Path -LiteralPath $p)) { return "" }
            return [IO.File]::ReadAllText($p)
        }

        # Linhas entre o titulo '## <Titulo>' e o proximo titulo de nivel 2 (ou o fim do arquivo).
        function Get-Secao {
            param([string]$Texto, [string]$Titulo)
            $saida  = New-Object System.Collections.Generic.List[string]
            $dentro = $false
            foreach ($l in ($Texto -split "`r?`n")) {
                if ($l -match '^##\s') {
                    if ($dentro) { break }
                    if ($l -match ('^##\s+' + [regex]::Escape($Titulo))) { $dentro = $true }
                    continue
                }
                if ($dentro) { $saida.Add($l) }
            }
            return $saida.ToArray()
        }

        function Get-ItensSecao {
            param([string]$Texto, [string]$Titulo)
            return @(Get-Secao -Texto $Texto -Titulo $Titulo | Where-Object { $_ -match '^\s*- \[ \]' })
        }

        function Get-FalhasCompletude {
            param([string]$Texto)
            $falhas = @()
            $itens = @(Get-ItensSecao -Texto $Texto -Titulo 'Completude')
            if ($itens.Count -eq 0) { return @('secao Completude sem nenhum item - [ ]') }

            $suf = @($itens | Where-Object { $_ -match '(?i)sem ter participado' })
            if ($suf.Count -ne 1) { $falhas += "item de suficiencia: esperado 1, achado(s) $($suf.Count)" }

            $art = @($itens | Where-Object { $_ -match '(?i)artefato' -and $_ -match '(?i)estrutura' })
            if ($art.Count -ne 1) { $falhas += "item de artefatos-fonte: esperado 1, achado(s) $($art.Count)" }
            foreach ($l in $art) {
                if ($l -notmatch 'Entidades-chave') { $falhas += "artefatos-fonte nao aponta 'Entidades-chave': $l" }
            }

            foreach ($l in @($suf + $art)) {
                if ($l -match '(?i)\btabela\b|endpoint') { $falhas += "WHAT/HOW: item novo fala de tabela/endpoint: $l" }
            }
            return $falhas
        }

        # T2, dono do procedimento (V2): o loop ensina a falseabilidade e nomeia as 2 armadilhas.
        function Get-FalhasLoopSpec {
            param([string]$Texto)
            $falhas = @()
            $ears = (@(Get-Secao -Texto $Texto -Titulo 'Formato: EARS') -join "`n")
            if ($ears -notmatch '(?i)violado quando') { $falhas += "secao 'Formato: EARS' sem 'violado quando'" }
            $arm = (@(Get-Secao -Texto $Texto -Titulo 'Armadilhas') -join "`n")
            if ($arm -notmatch '(?i)enumera..o aberta') { $falhas += "secao 'Armadilhas' sem 'enumeracao aberta'" }
            if ($arm -notmatch '(?i)verbo que delimita') { $falhas += "secao 'Armadilhas' sem 'verbo que delimita'" }
            return $falhas
        }

        # T2, dono da checagem (V1): o checklist pergunta e APONTA para o loop; nao copia as armadilhas (R25).
        function Get-FalhasClareza {
            param([string]$Texto)
            $falhas = @()
            $clareza = (@(Get-ItensSecao -Texto $Texto -Titulo 'Clareza') -join "`n")
            if ($clareza -notmatch '(?i)violado quando') { $falhas += "secao 'Clareza' sem item 'violado quando'" }
            if ($clareza -notmatch [regex]::Escape('v2/loops/spec.md')) { $falhas += "secao 'Clareza' sem ponteiro para v2/loops/spec.md" }
            if ($Texto -match '(?i)enumera..o aberta') { $falhas += "checklist copia a armadilha 'enumeracao aberta' (mora so no loop)" }
            if ($Texto -match '(?i)verbo que delimita') { $falhas += "checklist copia a armadilha 'verbo que delimita' (mora so no loop)" }
            return $falhas
        }

        $script:specChecklist = Get-TextoCanon 'templates\spec-checklist.template.md'
        $script:loopSpec      = Get-TextoCanon 'v2\loops\spec.md'
    }

    Context "T1 -- suficiencia e artefatos-fonte (secao Completude)" {

        It "o checklist existe e tem conteudo (anti-vacuidade)" {
            Join-Path $script:raiz 'templates\spec-checklist.template.md' | Should -Exist
            $script:specChecklist.Length | Should -BeGreaterThan 300
            @(Get-ItensSecao -Texto $script:specChecklist -Titulo 'Completude').Count | Should -BeGreaterThan 4
        }

        It "Completude tem 1 item de suficiencia e 1 de artefatos-fonte, sem tabela/endpoint" {
            $falhas = @(Get-FalhasCompletude -Texto $script:specChecklist)
            $falhas.Count | Should -Be 0 -Because ($falhas -join "`n")
        }

        It "a forma unica N/A: <motivo> continua no checklist" {
            $script:specChecklist | Should -Match '`N/A: <motivo>`'
        }

        It "sabotagem: sem a linha de suficiencia, a asseracao falha" {
            $sab = (($script:specChecklist -split "`r?`n") | Where-Object { $_ -notmatch '(?i)sem ter participado' }) -join "`n"
            ($sab -split "`n").Count | Should -BeLessThan (($script:specChecklist -split "`r?`n").Count) -Because "a sabotagem precisa ter removido alguma linha"
            @(Get-FalhasCompletude -Texto $sab).Count | Should -BeGreaterThan 0
        }

        It "sabotagem: sem a linha de artefatos-fonte, a asseracao falha" {
            $sab = (($script:specChecklist -split "`r?`n") | Where-Object { -not ($_ -match '(?i)artefato' -and $_ -match '(?i)estrutura') }) -join "`n"
            ($sab -split "`n").Count | Should -BeLessThan (($script:specChecklist -split "`r?`n").Count) -Because "a sabotagem precisa ter removido alguma linha"
            @(Get-FalhasCompletude -Texto $sab).Count | Should -BeGreaterThan 0
        }

        It "sabotagem: item novo que fala de tabela faz a asseracao falhar (WHAT/HOW)" {
            $sab = $script:specChecklist -replace '(?i)(sem ter participado)', '$1 e sabe qual tabela usar'
            $sab | Should -Not -Be $script:specChecklist -Because "a sabotagem precisa ter alterado o texto"
            @(Get-FalhasCompletude -Texto $sab).Count | Should -BeGreaterThan 0
        }
    }

    Context "T2 -- falseabilidade e 2 armadilhas (loop de spec + Clareza)" {

        It "o loop de spec existe e tem conteudo (anti-vacuidade)" {
            Join-Path $script:raiz 'v2\loops\spec.md' | Should -Exist
            $script:loopSpec.Length | Should -BeGreaterThan 500
        }

        It "o loop tem 'violado quando' no Formato EARS e as 2 armadilhas nomeadas" {
            $falhas = @(Get-FalhasLoopSpec -Texto $script:loopSpec)
            $falhas.Count | Should -Be 0 -Because ($falhas -join "`n")
        }

        It "Clareza pergunta 'violado quando', aponta v2/loops/spec.md e nao copia as armadilhas" {
            $falhas = @(Get-FalhasClareza -Texto $script:specChecklist)
            $falhas.Count | Should -Be 0 -Because ($falhas -join "`n")
        }

        It "sabotagem: checklist que copia 'enumeracao aberta' faz a asseracao falhar" {
            $sab = $script:specChecklist + "`n- [ ] Nenhum FR usa enumera" + [char]0x00E7 + [char]0x00E3 + "o aberta.`n"
            @(Get-FalhasClareza -Texto $sab).Count | Should -BeGreaterThan 0
        }

        It "sabotagem: loop sem o bullet 'verbo que delimita' faz a asseracao falhar" {
            $sab = (($script:loopSpec -split "`r?`n") | Where-Object { $_ -notmatch '(?i)verbo que delimita' }) -join "`n"
            ($sab -split "`n").Count | Should -BeLessThan (($script:loopSpec -split "`r?`n").Count) -Because "a sabotagem precisa ter removido alguma linha"
            @(Get-FalhasLoopSpec -Texto $sab).Count | Should -BeGreaterThan 0
        }

        It "sabotagem: Clareza sem o ponteiro para o loop faz a asseracao falhar" {
            $sab = $script:specChecklist -replace [regex]::Escape('v2/loops/spec.md'), 'o loop de spec'
            $sab | Should -Not -Be $script:specChecklist -Because "a sabotagem precisa ter alterado o texto"
            @(Get-FalhasClareza -Texto $sab).Count | Should -BeGreaterThan 0
        }
    }
}
