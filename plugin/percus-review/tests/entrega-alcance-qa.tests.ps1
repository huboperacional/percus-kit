#requires -Version 5.1
# MDS, Lote B (pecas 4 e 8a): o G2 do CHECKLIST_FEATURE_NOVA.md ganha o bloco "Alcance"
# (navegacao + autonomia do papel) e a "Grade de QA".
#
# O custo que importa e atrito: o trilho P fica FORA (a checklist dele e autocontida e trata de
# tela que ja existe), o M entra so pelo ponteiro "+ G2" do item 9. Este teste prende o texto no
# G2, prende o P limpo e prova (sabotagem) que as assercoes reprovam quando a linha some.
# Fonte ASCII de proposito: acento entra por code point no regex (\u00e7 etc.).

Describe "G2 do CHECKLIST_FEATURE_NOVA: alcance e grade de QA (MDS, Lote B)" {

    BeforeAll {
        $script:raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
        $p = Join-Path $script:raiz 'checklists\CHECKLIST_FEATURE_NOVA.md'
        $script:texto = ''
        if (Test-Path -LiteralPath $p) { $script:texto = [IO.File]::ReadAllText($p) }

        # Recorte por TITULO: da linha do titulo ate o proximo titulo de nivel 1-3 (exclusivo).
        # Nunca por numero de linha: o arquivo e editado por outras tarefas.
        function Get-Secao {
            param([string]$Texto, [string]$TituloRegex)
            $m = [regex]::Match($Texto, "(?ms)^$TituloRegex.*?(?=^#{1,3}\s|\z)")
            if ($m.Success) { return $m.Value }
            return ''
        }

        # Devolve a lista de falhas do bloco Alcance num recorte G2 (vazia = conforme).
        function Test-AlcanceG2 {
            param([string]$Recorte)
            $falhas = @()
            $linhas = $Recorte -split "\r?\n"
            if (-not ($linhas | Where-Object { $_ -match '(?i)navega' -and $_ -match '(?i)onde o papel entra' })) {
                $falhas += 'navegacao: nenhuma linha com "navega" + "onde o papel entra"'
            }
            if (-not ($linhas | Where-Object { $_ -match '(?i)autonomia do papel' -and $_ -match '(?i)link colado' })) {
                $falhas += 'autonomia: nenhuma linha com "autonomia do papel" + "link colado"'
            }
            if (-not ($linhas | Where-Object { $_ -match '(?i)ponto de entrada' -and $_ -match '(?i)n\u00e3o se aplica' })) {
                $falhas += 'disparo: condicao "ponto de entrada novo" / "nao se aplica" ausente'
            }
            # O ponteiro do Uso fica na linha de abertura do bloco (nao em qualquer lugar do G2).
            if (-not ($linhas | Where-Object { $_ -match '\*\*Alcance\*\*' -and $_ -match 'Uso = R1\b' })) {
                $falhas += 'uso: linha "**Alcance**" sem o ponteiro "Uso = R1"'
            }
            if ($Recorte -match 'Criar X \u2192 F5') { $falhas += 'uso: copia do ciclo da R1 (R25)' }
            return ,$falhas
        }

        $script:g2 = Get-Secao $script:texto '### G2\.'
        $script:trilhoP = Get-Secao $script:texto '### Checklist do trilho P'
        $script:trilhoM = Get-Secao $script:texto '### Checklist do trilho M'
    }

    It "os recortes existem (anti-vacuidade)" {
        $script:texto.Length | Should -BeGreaterThan 500
        $script:g2 | Should -Match 'Verification'
        $script:g2 | Should -Not -Match '### G3'
        $script:trilhoP | Should -Match 'Trilho P'
        $script:trilhoM | Should -Match 'Trilho M'
    }

    Context "T3 - Alcance (navegacao + autonomia do papel)" {

        It "o G2 real passa nas assercoes do bloco Alcance" {
            $f = Test-AlcanceG2 $script:g2
            ($f -join '; ') | Should -BeNullOrEmpty
        }

        It "sabotagem: G2 sem a linha de autonomia reprova" {
            $sabotado = (($script:g2 -split "\r?\n") | Where-Object { $_ -notmatch '(?i)autonomia' }) -join "`n"
            $sabotado | Should -Not -Be $script:g2 -Because "a sabotagem precisa de fato remover uma linha"
            $f = Test-AlcanceG2 $sabotado
            ($f -join '; ') | Should -Match 'autonomia'
        }

        It "sabotagem: G2 sem o ponteiro Uso = R1 reprova" {
            $sabotado = $script:g2.Replace('Uso = R1', 'Uso conferido')
            $sabotado | Should -Not -Be $script:g2 -Because "a sabotagem precisa de fato trocar o ponteiro"
            $f = Test-AlcanceG2 $sabotado
            ($f -join '; ') | Should -Match 'Uso = R1'
        }

        It "sabotagem: G2 com a copia do ciclo CRUD da R1 reprova" {
            $f = Test-AlcanceG2 ($script:g2 + "`nCriar X " + [char]0x2192 + " F5 " + [char]0x2192 + " confere")
            ($f -join '; ') | Should -Match 'copia'
        }

        It "trilho M: o item 9 aponta G2" {
            $item9 = ($script:trilhoM -split "\r?\n") | Where-Object { $_ -match '^9\. ' }
            @($item9).Count | Should -Be 1
            $item9 | Should -Match '\bG2\b'
        }

        It "trilho P fica fora: sem G2 e sem autonomia (custo de atrito)" {
            $script:trilhoP | Should -Match 'Trilho P' -Because "sem recorte, as negacoes abaixo passam por vacuidade"
            $script:trilhoP | Should -Not -Match '\bG2\b'
            $script:trilhoP | Should -Not -Match '(?i)autonomia'
        }
    }
}
