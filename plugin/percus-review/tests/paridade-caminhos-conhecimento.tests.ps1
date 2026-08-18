#requires -Version 5.1
# A definicao de "o que e area de conhecimento" e "o que e monolito aposentado" vive em TRES
# implementacoes, em duas linguagens:
#
#   1. v2/gates/percus-gate.sh          -> _AREAS_CONHECIMENTO (shell) + regex do bloco 2c
#   2. scripts/gerar-indice-conhecimento.ps1 -> array $areas (PowerShell)
#   3. plugin/percus-review/hooks/knowledge-write-guard.ps1 -> regex do hook
#
# Divergencia silenciosa entre copias e a classe que este kit ja pagou caro (#regra-duplicada-ps1-sh),
# e ela apareceu DUAS vezes so nesta migracao: o gerador cobria 2 areas e o gate 4 (trava sem
# saida), e o guard cobria 2 e prometia 4 no proprio comentario.
#
# Nao da pra extrair um arquivo unico de config sem que shell e PowerShell tenham um parser
# comum -- entao a garantia e este teste: as tres fontes tem de concordar sobre o MESMO conjunto.

Describe "paridade das 4 areas de conhecimento entre gate, gerador e guard" {
    BeforeAll {
        $script:kit    = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:gate   = Get-Content (Join-Path $script:kit "v2\gates\percus-gate.sh") -Raw
        $script:gerador= Get-Content (Join-Path $script:kit "scripts\gerar-indice-conhecimento.ps1") -Raw
        $script:guard  = Get-Content (Join-Path $script:kit "plugin\percus-review\hooks\knowledge-write-guard.ps1") -Raw

        $script:esperado = @(
            "conhecimento/resolver"
            "conhecimento/fazer"
            "referencia/conhecimento/resolver"
            "referencia/conhecimento/fazer"
        )
    }

    It "o gate declara exatamente as 4 areas" {
        $m = [regex]::Match($script:gate, '_AREAS_CONHECIMENTO="(?<v>[^"]+)"')
        $m.Success | Should -Be $true -Because "sem _AREAS_CONHECIMENTO nao ha o que comparar"
        $areas = @($m.Groups['v'].Value -split '\s+' | Where-Object { $_ })
        ($areas | Sort-Object) -join "|" | Should -BeExactly (($script:esperado | Sort-Object) -join "|")
    }

    It "o gerador de indice cobre as MESMAS 4 areas" {
        # Um verbete numa area que o gate afere e o gerador ignora vira trava sem saida: o bloco
        # 2d exige INDICE.md sincronizado, nenhum script o gera, e edita-lo a mao e barrado pelo
        # guard. Foi exatamente o cenario apontado pelo R11 em 2026-08-18.
        $pares = [regex]::Matches($script:gerador, 'Raiz\s*=\s*"(?<r>[^"]+)"\s*;\s*Nome\s*=\s*"(?<n>[^"]+)"')
        $areas = @($pares | ForEach-Object { "$($_.Groups['r'].Value)/$($_.Groups['n'].Value)" })
        ($areas | Sort-Object) -join "|" | Should -BeExactly (($script:esperado | Sort-Object) -join "|")
    }

    It "o guard reconhece INDICE.md das 4 areas -- e nao so das duas de conhecimento/" {
        # Assercao COMPORTAMENTAL, nao textual: compara o que a regex do hook aceita, nao como
        # ela esta escrita. Regex equivalente com grafia diferente continua valendo.
        $m = [regex]::Match($script:guard, "ehIndice\s*=\s*\`$normalizado -match '(?<re>[^']+)'")
        $m.Success | Should -Be $true
        $re = $m.Groups['re'].Value
        foreach ($a in $script:esperado) {
            "$a/INDICE.md"                    | Should -Match $re -Because "area $a nao coberta pelo guard"
            "D:/qualquer/raiz/$a/INDICE.md"   | Should -Match $re -Because "caminho absoluto de $a nao coberto"
        }
        "conhecimento/resolver/verbete.md" | Should -Not -Match $re -Because "verbete comum nao pode ser barrado"
    }

    It "o guard reconhece o monolito aposentado nas duas raizes" {
        $m = [regex]::Match($script:guard, "ehMonolito\s*=\s*\`$normalizado -match '(?<re>[^']+)'")
        $m.Success | Should -Be $true
        $re = $m.Groups['re'].Value
        foreach ($raiz in @("conhecimento", "referencia/conhecimento")) {
            "$raiz/COMO_RESOLVER.md"           | Should -Match $re
            "$raiz/COMO_FAZER.md"              | Should -Match $re
            "D:/x/$raiz/COMO_RESOLVER.md"      | Should -Match $re
        }
        "conhecimento/resolver/algo.md" | Should -Not -Match $re
    }
}
