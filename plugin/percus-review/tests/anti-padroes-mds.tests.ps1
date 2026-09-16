#requires -Version 5.1
# MDS, peca 11: o anti-padrao #14 (trava que confere lista curada) -- numeracao da lista MDS, nao a do
# canon -- entra ao fim do "Resumo dos anti-padroes mais comuns" de 01_REGRAS_INEGOCIAVEIS.md, com a
# numeracao que o proprio resumo tiver. O #10 (avisar usuario interno por canal externo) foi DESCARTADO
# na revisao; a guarda do descarte e heuristica (casa a expressao "canal externo" do MDS), nao trava a classe.
#
# O que esta guarda prende:
# - a numeracao do resumo e continua (1..N sem buraco nem repeticao), com N DERIVADO do arquivo --
#   escrever "36" ou "38" fixo aqui seria cometer o proprio #14;
# - o item da lista curada aponta R12 e um verbete de conhecimento/resolver que existe;
# - nenhum item proibe aviso interno por canal externo (descarte do #10);
# - todo caminho entre crases nos itens novos existe na raiz do kit (ponteiro morto nao vale).

Describe "anti-padroes MDS no resumo do canon (#14 entra, #10 descartado)" {

    BeforeAll {
        $script:raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
        $script:canon = [IO.File]::ReadAllText((Join-Path $script:raiz '01_REGRAS_INEGOCIAVEIS.md'))
        $script:xis = [string][char]0x274C

        function Get-SecaoResumo {
            param([string]$Texto)
            $m = [regex]::Match($Texto, '(?ms)^## Resumo dos anti-padr.es mais comuns[^\n]*\n(.*?)(?=^## |\z)')
            if (-not $m.Success) { return '' }
            return $m.Groups[1].Value
        }

        function Get-ItensResumo {
            param([string]$Secao)
            $padrao = '(?m)^(\d+)\. ' + [regex]::Escape($script:xis) + ' (.*?)\r?$'
            return @([regex]::Matches($Secao, $padrao) | ForEach-Object {
                [pscustomobject]@{ Numero = [int]$_.Groups[1].Value; Texto = $_.Groups[2].Value }
            })
        }

        # Devolve a lista de problemas de numeracao; vazia = continua 1..N.
        function Get-ProblemasNumeracao {
            param([object[]]$Itens)
            $problemas = @()
            if ($Itens.Count -eq 0) { return @('nenhum item') }
            for ($i = 0; $i -lt $Itens.Count; $i++) {
                $esperado = $i + 1
                if ($Itens[$i].Numero -ne $esperado) {
                    $problemas += "posicao $esperado tem o numero $($Itens[$i].Numero)"
                }
            }
            return $problemas
        }

        function Get-CaminhosCrase {
            param([string]$Linha)
            return @([regex]::Matches($Linha, '`([^`]+\.md)`') | ForEach-Object { $_.Groups[1].Value })
        }

        $script:secao = Get-SecaoResumo $script:canon
        $script:itens = Get-ItensResumo $script:secao
        $script:itemLista = @($script:itens | Where-Object { $_.Texto -match '(?i)lista curada' })
        $script:itemCanal = @($script:itens | Where-Object { $_.Texto -match '(?i)canal externo' })
    }

    It "o resumo existe e tem itens (anti-vacuidade)" {
        $script:secao.Length | Should -BeGreaterThan 500
        $script:itens.Count | Should -BeGreaterThan 30
    }

    It "a numeracao do resumo e continua 1..N, sem buraco nem repeticao" {
        (Get-ProblemasNumeracao $script:itens) | Should -BeNullOrEmpty
        # toda linha numerada da secao tem de ter sido reconhecida como item (sem item fora do formato)
        $numeradas = [regex]::Matches($script:secao, '(?m)^\d+\. ').Count
        $numeradas | Should -Be $script:itens.Count
    }

    It "o item da lista curada (#14) existe uma vez, cita R12 e um verbete de conhecimento/resolver que existe" {
        $script:itemLista.Count | Should -Be 1
        $script:itemLista[0].Texto | Should -Match '\(R12\b'
        # o numero citado aponta a regra certa: R12 e a de verificacao verificavel (ancora por titulo)
        $script:canon | Should -Match '(?m)^## R12\. Toda regra precisa de verifica' -Because "o item aponta R12 como ancora; renumeracao da regra tem de derrubar o ponteiro"
        $caminhos = @(Get-CaminhosCrase $script:itemLista[0].Texto | Where-Object { $_ -like 'conhecimento/resolver/*.md' })
        $caminhos.Count | Should -BeGreaterThan 0
        foreach ($c in $caminhos) {
            Test-Path -LiteralPath (Join-Path $script:raiz $c) | Should -BeTrue -Because "$c tem de existir no kit"
        }
    }

    It "o #10 do MDS (aviso interno por canal externo) continua descartado: nenhum item do resumo o proibe" {
        # Descarte da revisao do Lote C: o unico incidente achado ensina falha silenciosa de envio (MDS #5),
        # nao canal errado, e o projeto de origem manteve o canal externo para o operador por decisao propria.
        # Voltar com o item exige incidente da classe certa -- e editar esta guarda de proposito.
        # Deteccao: item cujo texto casa (?i)canal externo (a expressao do proprio MDS #10); texto com outra
        # redacao escapa desta guarda e fica para a revisao humana.
        $script:itemCanal.Count | Should -Be 0 -Because "o #10 foi descartado por falta de incidente da classe; nao entra por importacao"
    }

    It "todo caminho entre crases nos itens novos existe na raiz do kit" {
        $novos = @($script:itemLista)
        $novos.Count | Should -BeGreaterThan 0
        foreach ($item in $novos) {
            foreach ($c in (Get-CaminhosCrase $item.Texto)) {
                Test-Path -LiteralPath (Join-Path $script:raiz $c) | Should -BeTrue -Because "$c citado no item tem de existir"
            }
            $item.Texto | Should -Not -Match ('(?i)\.claude' + '-home') -Because "R25: arquivo efemero nao vira referencia do canon"
        }
    }

    It "sabotagem: o resumo real com o penultimo item removido falha na numeracao" {
        $ultimo = $script:itens[$script:itens.Count - 1].Numero
        $alvo = $ultimo - 1
        $sabotada = [regex]::Replace($script:secao, "(?m)^$alvo\. [^\n]*\n", '')
        $itensSabotados = Get-ItensResumo $sabotada
        $itensSabotados.Count | Should -Be ($script:itens.Count - 1)
        (Get-ProblemasNumeracao $itensSabotados) | Should -Not -BeNullOrEmpty
    }

    It "sabotagem: numero repetido tambem falha" {
        $repetida = @($script:itens) + @([pscustomobject]@{ Numero = $script:itens.Count; Texto = 'x' })
        (Get-ProblemasNumeracao $repetida) | Should -Not -BeNullOrEmpty
    }
}
