#requires -Version 5.1
# Fase 5: sdd-conferir.ps1 vira passo OBRIGATORIO do controlador por tarefa, antes de revisar ou
# integrar (medido: .ps1 novo com acento e sem BOM passou por 2 revisoes seguidas na Fase 3/4 e so a
# suite inteira pegou, horas depois). Ate a Fase 4 o template so "apontava o uso" (frase fraca, sem
# mandar rodar); esta guarda prende a frase que MANDA rodar antes de revisar/integrar, e a linha do
# bloco do revisor que recebe o RESUMO pronto.

Describe "Template de despacho exige sdd-conferir antes de revisar/integrar (Fase 5)" {

    BeforeAll {
        $script:raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path

        function Get-TextoCanon {
            param([string]$Relativo)
            $p = Join-Path $script:raiz $Relativo
            if (-not (Test-Path -LiteralPath $p)) { return "" }
            return [IO.File]::ReadAllText($p)
        }

        $script:despacho = Get-TextoCanon 'templates\DESPACHO_SUBAGENTE.template.md'
    }

    It "o template existe e tem conteudo (anti-vacuidade)" {
        $script:despacho.Length | Should -BeGreaterThan 500
    }

    It "manda rodar sdd-conferir.ps1 ao receber DONE, antes de revisar ou integrar" {
        $script:despacho | Should -Match 'PASSO OBRIGAT.RIO' `
            -Because "ate a Fase 4 o texto so apontava o uso (fraco); agora manda rodar"
        $script:despacho | Should -Match 'ao receber DONE' `
            -Because "o gatilho e o DONE da tarefa, nao o fim do milestone"
        $script:despacho | Should -Match 'antes de mandar revisar\s*\n?\s*> ou integrar' `
            -Because "tem que rodar ANTES da revisao, nao depois -- revisor nao e lugar de achar encoding"
    }

    It "diz que FALHA devolve ao implementador antes da revisao" {
        $script:despacho | Should -Match 'FALHA.*devolve ao implementador antes da revis' `
            -Because "revisao nao e lugar de achar encoding -- FALHA volta pro implementador primeiro"
    }

    It "explica que AVISO r11-marcador em worktree irmao e esperado, nao falha" {
        $script:despacho | Should -Match 'AVISO r11-marcador' `
            -Because "a checagem so ve o marcador do proprio worktree -- irmao sempre vai dar AVISO"
        $script:despacho | Should -Match 'n.o . falha' `
            -Because "sem essa frase alguem vai tratar o AVISO esperado como bloqueio"
    }

    It "o bloco do revisor recebe o RESUMO do sdd-conferir junto do review-package" {
        $script:despacho | Should -Match 'revisor recebe o RESUMO do .sdd-conferir.' `
            -Because "o revisor nao deve gastar tempo com encoding/fim de linha -- isso ja foi conferido"
    }

    It "o bloco copiavel (entre os cercas de codigo) continua ate 40 linhas" {
        $texto = $script:despacho -split "`r?`n"
        $inicioFence = ($texto | Select-String -Pattern '^```text$' | Select-Object -First 1).LineNumber
        $fimFence = ($texto | Select-String -Pattern '^```$' | Select-Object -First 1).LineNumber
        $inicioFence | Should -Not -BeNullOrEmpty -Because "o template tem que ter um bloco de codigo copiavel"
        $fimFence | Should -Not -BeNullOrEmpty
        $linhasBloco = $fimFence - $inicioFence - 1
        $linhasBloco | Should -BeLessOrEqual 40 -Because "contrato do template: despacho copiavel cabe em ate 40 linhas"
    }
}
