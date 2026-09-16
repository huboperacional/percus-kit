#requires -Version 5.1
# Fase 4, decisao 1 do operador (MDS, "N/A escrito" estendido aos checklists de feature).
#
# Ate a Fase 3, o N/A por escrito so era exigido nos 4 gatilhos do dia 1 (templates\CLAUDE.template.md).
# Nas checklists condicionais de feature o motivo era so falado ("declare em voz alta"), nunca escrito --
# item pulado sem marca e sem motivo e item esquecido, e isso precisava estar no texto, nao so na memoria
# de quem executou. Esta guarda prende a forma unica `N/A: <motivo>` nos dois arquivos que a decisao
# aponta, e prova que a frase antiga ("declare em voz alta o porque") nao voltou.

Describe "N/A escrito nos checklists de feature (decisao MDS, Fase 4)" {

    BeforeAll {
        $script:raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path

        function Get-TextoCanon {
            param([string]$Relativo)
            $p = Join-Path $script:raiz $Relativo
            if (-not (Test-Path -LiteralPath $p)) { return "" }
            return [IO.File]::ReadAllText($p)
        }

        $script:checklistFeature = Get-TextoCanon 'checklists\CHECKLIST_FEATURE_NOVA.md'
        $script:specChecklist    = Get-TextoCanon 'templates\spec-checklist.template.md'
    }

    It "os dois arquivos existem e tem conteudo (anti-vacuidade)" {
        $script:checklistFeature.Length | Should -BeGreaterThan 500
        $script:specChecklist.Length    | Should -BeGreaterThan 300
    }

    It "CHECKLIST_FEATURE_NOVA.md exige a forma escrita N/A: <motivo> no cabecalho do fluxo" {
        $script:checklistFeature | Should -Match '`N/A: <motivo>`' `
            -Because "item pulado precisa de motivo escrito, nao so falado em voz alta"
    }

    It "CHECKLIST_FEATURE_NOVA.md usa a mesma forma no G-DELEGA (motivo de nao delegar)" {
        $script:checklistFeature | Should -Match 'N/A: implementa..o local' `
            -Because "o motivo de manter a implementacao local tambem precisa ficar escrito, nao so declarado"
    }

    It "spec-checklist.template.md exige a forma escrita N/A: <motivo> para item que nao se aplica" {
        $script:specChecklist | Should -Match '`N/A: <motivo>`' `
            -Because "item de spec-checklist que nao se aplica tem que registrar o motivo por escrito"
    }

    It "nenhum dos dois arquivos ainda pede so a declaracao falada" {
        $script:checklistFeature | Should -Not -Match '(?i)declare em voz alta o porqu' `
            -Because "a frase antiga (motivo so falado) foi substituida pelo N/A escrito"
        $script:checklistFeature | Should -Not -Match '(?i)declare em voz alta o motivo:' `
            -Because "o G-DELEGA tambem trocou a declaracao falada pelo registro escrito"
        $script:specChecklist | Should -Not -Match '(?i)declare em voz alta o porqu|(?i)declare em voz alta o motivo:' `
            -Because "o spec-checklist tambem nao pode voltar a pedir so declaracao falada"
    }

    It "a forma e unica -- nenhuma variante conhecida (virgula/parenteses/hifen/'com motivo') aparece" {
        # Escopo desta guarda: hoje 'N/A' so aparece nestes dois arquivos no contexto desta
        # decisao (item pulado de checklist), sem nenhum outro uso legitimo (tabela de status,
        # sigla generica etc.) -- conferido na Fase 4 antes deste teste existir. Por isso o teste
        # rejeita SO as variantes de separador conhecidas do resto do canon ('N/A,', 'N/A com
        # motivo', 'N/A -', 'N/A (') em vez de exigir ':' logo apos todo 'N/A' do arquivo; se um
        # uso legitimo de 'N/A' sem separador for adicionado depois, este teste nao quebra por
        # acidente.
        foreach ($par in @(
            @{ Nome = 'checklists\CHECKLIST_FEATURE_NOVA.md';   Texto = $script:checklistFeature }
            @{ Nome = 'templates\spec-checklist.template.md';   Texto = $script:specChecklist }
        )) {
            $par.Texto | Should -Not -Match 'N/A,\s*motivo'    -Because "$($par.Nome): forma antiga com virgula (v2/referencia/discovery-camadas.md usa essa, nao aqui)"
            $par.Texto | Should -Not -Match '(?i)N/A com motivo' -Because "$($par.Nome): forma antiga em prosa (templates/CLAUDE.template.md usa essa, nao aqui)"
            $par.Texto | Should -Not -Match 'N/A\s*[-–(]'       -Because "$($par.Nome): separador divergente (hifen/parenteses) nunca foi a forma adotada aqui"
        }
    }
}
