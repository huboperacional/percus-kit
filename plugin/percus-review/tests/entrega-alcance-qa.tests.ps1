#requires -Version 5.1
# MDS, Lote B (pecas 4 e 8a): o G2 do CHECKLIST_FEATURE_NOVA.md ganha o bloco "Alcance"
# (navegacao + autonomia do papel) e a "Grade de QA".
#
# O custo que importa e atrito: o trilho P fica FORA (a checklist dele e autocontida e trata de
# tela que ja existe), o M entra so pelo ponteiro "+ G2" do item 9, e mudanca so no kit/canon nao
# tem tela. Este teste prende o texto no G2 (inclusive o cabecalho da Grade), prende o P limpo e
# prova (sabotagem) que as assercoes reprovam quando a linha some.
# Fonte ASCII de proposito: todo acento entra por code point DENTRO DE REGEX (\u00e7 etc.);
# por isso toda sabotagem com acento usa [regex]::Replace, nunca String.Replace.

Describe "G2 do CHECKLIST_FEATURE_NOVA: alcance e grade de QA (MDS, Lote B)" {

    BeforeAll {
        $script:raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
        $arqChecklist = Join-Path $script:raiz 'checklists\CHECKLIST_FEATURE_NOVA.md'
        $script:texto = ''
        if (Test-Path -LiteralPath $arqChecklist) { $script:texto = [IO.File]::ReadAllText($arqChecklist) }

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
            $abertura = @($linhas | Where-Object { $_ -match '^\*\*Alcance\*\*' })
            if ($abertura.Count -ne 1) {
                $falhas += "disparo: $($abertura.Count) linha(s) de abertura **Alcance**, esperado 1"
            } else {
                $a = $abertura[0]
                # Criterio unico de "tem tela": os 3 casos da revisao + a exclusao do kit/canon.
                if ($a -notmatch '(?i)tem tela') { $falhas += 'disparo: sem o criterio "tem tela"' }
                if ($a -notmatch '(?i)em tela existente') { $falhas += 'disparo: sem o caso "novo em tela existente"' }
                if ($a -notmatch '(?i)endpoint novo consumido por tela existente') { $falhas += 'disparo: sem o caso "endpoint novo consumido por tela existente"' }
                if ($a -notmatch '(?i)kit/canon' -or $a -notmatch '(?i)n\u00e3o tem tela') { $falhas += 'disparo: sem a exclusao "kit/canon nao tem tela"' }
                if ($a -notmatch '(?i)n\u00e3o se aplica') { $falhas += 'disparo: sem "nao se aplica" (sem N/A)' }
                # O ponteiro do Uso fica na linha de abertura do bloco (nao em qualquer lugar do G2).
                if ($a -notmatch 'Uso = R1\b') { $falhas += 'uso: linha "**Alcance**" sem o ponteiro "Uso = R1"' }
            }
            if ($Recorte -match 'Criar X \u2192 F5') { $falhas += 'uso: copia do ciclo da R1 (R25)' }
            return ,$falhas
        }

        # Devolve a lista de falhas da Grade de QA num recorte G2 (vazia = conforme).
        function Test-GradeG2 {
            param([string]$Recorte)
            $falhas = @()
            $linhas = $Recorte -split "\r?\n"

            # Cabecalho: quem a grade alcanca. E aqui que o atrito do P e do M sem tela e decidido.
            $cab = @($linhas | Where-Object { $_ -match '^\*\*Grade de QA\*\*' })
            if ($cab.Count -ne 1) {
                $falhas += "cabecalho: $($cab.Count) linha(s) **Grade de QA**, esperado 1"
            } else {
                if ($cab[0] -notmatch '(?i)trilho P, fora') { $falhas += 'cabecalho: nao exclui o trilho P' }
                if ($cab[0] -notmatch '(?i)trilho M, s\u00f3 se a entrega tem tela') { $falhas += 'cabecalho: nao condiciona o trilho M a ter tela' }
                if ($cab[0] -notmatch '(?i)mesmo crit\u00e9rio de tela do Alcance') { $falhas += 'cabecalho: nao usa o criterio de tela do Alcance' }
                if ($cab[0] -notmatch '`N/A: entrega sem tela`' -or $cab[0] -notmatch '(?i)grade inteira') {
                    $falhas += 'atrito: falta a permissao de um `N/A: entrega sem tela` para a grade inteira'
                }
            }

            foreach ($caixa in @('Visual', 'Seguran\u00e7a', 'Performance', 'Mobile', 'Regress\u00e3o')) {
                $achadas = @($linhas | Where-Object { $_ -match ('^- \[ \] \*\*' + $caixa + ':\*\*') })
                if ($achadas.Count -ne 1) { $falhas += "caixa ${caixa}: $($achadas.Count) linha(s) '- [ ]', esperado 1" }
            }
            function Get-Caixa([string]$Nome) { return (@($linhas | Where-Object { $_ -match ('^- \[ \] \*\*' + $Nome + ':') }) + @(''))[0] }

            $perf = Get-Caixa 'Performance'
            if ($perf -cnotmatch '\bSC\b' -or $perf -notmatch '`N/A: spec sem SC de tempo`') {
                $falhas += 'Performance: sem SC da spec ou sem o N/A escrito para spec sem SC (inventaria meta)'
            }
            $seg = Get-Caixa 'Seguran\u00e7a'
            if ($seg -notmatch '(?i)nega\S*\s+\(R7\)' -or $seg -match '(?i)tenant[^\r\n]*R7' -or $seg -match '(?i)security-audit') {
                $falhas += 'Seguranca: R7 aponta so a negacao ao papel (fato observado, nao skill)'
            }
            if ($seg -notmatch '(?i)se o projeto \u00e9 multi-tenant') { $falhas += 'Seguranca: tenant sem a condicao multi-tenant' }
            $mob = Get-Caixa 'Mobile'
            if ($mob -notmatch '(?i)celular' -or $mob -notmatch '\d+ px' -or $mob -notmatch '`N/A: [^`]+`' -or $mob -match '(?i)opera\u00e7\u00e3o cr\u00edtica|viewport estreita') {
                $falhas += 'Mobile: precisa ser marcavel (uso no celular pela spec, largura em px, N/A escrito)'
            }
            $reg = Get-Caixa 'Regress\u00e3o'
            if ($reg -notmatch '-Afetados' -or $reg -match '(?i)fluxo vizinho') {
                $falhas += 'Regressao: precisa de -Afetados e de acao marcavel (nao "fluxo vizinho")'
            }

            if ($Recorte -notmatch '`N/A: <motivo>`') { $falhas += 'N/A: forma unica `N/A: <motivo>` ausente' }
            if ($Recorte -match 'N/A\s*[-\u2013(]' -or $Recorte -match 'N/A,\s*motivo' -or $Recorte -match '(?i)N/A com motivo') {
                $falhas += 'N/A: separador divergente'
            }
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
            $sabotado = [regex]::Replace($script:g2, 'Uso = R1', 'Uso conferido')
            $sabotado | Should -Not -Be $script:g2 -Because "a sabotagem precisa de fato trocar o ponteiro"
            $f = Test-AlcanceG2 $sabotado
            ($f -join '; ') | Should -Match 'Uso = R1'
        }

        It "sabotagem: Alcance sem a exclusao do kit/canon reprova" {
            $sabotado = [regex]::Replace($script:g2, '(?i)kit/canon', 'backend')
            $sabotado | Should -Not -Be $script:g2
            ((Test-AlcanceG2 $sabotado) -join '; ') | Should -Match 'kit/canon'
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

    Context "T4 - Grade de QA (5 caixas com fato observavel)" {

        It "o G2 real passa nas assercoes da grade" {
            $f = Test-GradeG2 $script:g2
            ($f -join '; ') | Should -BeNullOrEmpty
        }

        It "sabotagem (revisao I3): cabecalho 'todos os trilhos' no lugar da condicao do M e da exclusao do P reprova" {
            $sabotado = [regex]::Replace($script:g2, 'trilho M, s\u00f3 se a entrega tem tela \(item 9 do M\); trilho P, fora', 'todos os trilhos')
            $sabotado | Should -Not -Be $script:g2 -Because "a sabotagem precisa de fato trocar o cabecalho"
            $f = (Test-GradeG2 $sabotado) -join '; '
            $f | Should -Match 'nao exclui o trilho P'
            $f | Should -Match 'nao condiciona o trilho M'
        }

        It "sabotagem: G2 sem a linha Mobile reprova" {
            $sabotado = (($script:g2 -split "\r?\n") | Where-Object { $_ -notmatch '\*\*Mobile:' }) -join "`n"
            $sabotado | Should -Not -Be $script:g2 -Because "a sabotagem precisa de fato remover uma linha"
            $f = Test-GradeG2 $sabotado
            ($f -join '; ') | Should -Match 'caixa Mobile'
        }

        It "sabotagem: Mobile com 'operacao critica em viewport estreita' reprova" {
            $sabotado = [regex]::Replace($script:g2, '(?m)^(- \[ \] \*\*Mobile:\*\*).*$', '$1 a operacao critica foi feita em viewport estreita.')
            $sabotado | Should -Not -Be $script:g2
            ((Test-GradeG2 $sabotado) -join '; ') | Should -Match 'Mobile'
        }

        It "sabotagem: Performance sem SC reprova" {
            $sabotado = [regex]::Replace($script:g2, '(?m)^(- \[ \] \*\*Performance:\*\*).*$', '$1 tempo de resposta abaixo de 200 ms.')
            $sabotado | Should -Not -Be $script:g2
            ((Test-GradeG2 $sabotado) -join '; ') | Should -Match 'Performance'
        }

        It "sabotagem: Performance sem o N/A escrito para spec sem SC reprova" {
            $sabotado = [regex]::Replace($script:g2, '(?m)^(- \[ \] \*\*Performance:\*\*).*$', '$1 medir o SC de tempo sempre.')
            $sabotado | Should -Not -Be $script:g2
            ((Test-GradeG2 $sabotado) -join '; ') | Should -Match 'Performance'
        }

        It "sabotagem: Seguranca com R7 no fim da frase do tenant reprova (revisao I1)" {
            $sabotado = [regex]::Replace($script:g2, '(?m)^(- \[ \] \*\*Seguran\u00e7a:\*\*).*$', '$1 papel sem permissao recebe negacao, e se o projeto e multi-tenant o dado de outro tenant nao aparece (R7).')
            $sabotado | Should -Not -Be $script:g2
            ((Test-GradeG2 $sabotado) -join '; ') | Should -Match 'Seguranca: R7'
        }

        It "sabotagem: Seguranca como 'rodei o security-audit' reprova" {
            $sabotado = [regex]::Replace($script:g2, '(?m)^(- \[ \] \*\*Seguran\u00e7a:\*\*).*$', '$1 rodei o security-audit.')
            $sabotado | Should -Not -Be $script:g2
            ((Test-GradeG2 $sabotado) -join '; ') | Should -Match 'Seguranca'
        }

        It "sabotagem: Regressao com 'fluxo vizinho' reprova" {
            $sabotado = [regex]::Replace($script:g2, '(?m)^(- \[ \] \*\*Regress\u00e3o:\*\*).*$', '$1 `scripts/rodar-suite.ps1 -Afetados` verde e o fluxo vizinho refeito.')
            $sabotado | Should -Not -Be $script:g2
            ((Test-GradeG2 $sabotado) -join '; ') | Should -Match 'Regressao'
        }

        It "sabotagem: sem a permissao de um N/A para entrega sem tela reprova" {
            $sabotado = [regex]::Replace($script:g2, '`N/A: entrega sem tela`', '`N/A: backend`')
            $sabotado | Should -Not -Be $script:g2
            ((Test-GradeG2 $sabotado) -join '; ') | Should -Match 'atrito'
        }

        It "sabotagem: separador de N/A divergente reprova" {
            ((Test-GradeG2 ($script:g2 + "`nN/A - entrega sem tela")) -join '; ') | Should -Match 'separador'
        }

        It "trilho M: o item 9 condiciona a grade a entrega com tela" {
            $item9 = ($script:trilhoM -split "\r?\n") | Where-Object { $_ -match '^9\. ' }
            @($item9).Count | Should -Be 1
            $item9 | Should -Match '(?i)\bG2\b.*tem tela'
        }

        It "trilho P fica fora da grade: sem Mobile e sem grade" {
            $script:trilhoP | Should -Match 'Trilho P' -Because "sem recorte, as negacoes abaixo passam por vacuidade"
            $script:trilhoP | Should -Not -Match '(?i)mobile'
            $script:trilhoP | Should -Not -Match '(?i)grade de QA'
        }

        It "G2 tem exatamente 7 caixas (2 do Alcance + 5 da Grade)" {
            # Sem teto de linhas de proposito (revisao M2): "G2 <= 15 linhas" foi criterio de entrega do
            # plano 2026-09-16 (T4), medido no relatorio, nao invariante. Um teto com 1 linha de folga so
            # seria subido sem criterio na proxima edicao. O que se prende e a estrutura: caixa nova no G2
            # e decisao de peso e tem de mudar este numero conscientemente.
            @(($script:g2 -split "\r?\n") | Where-Object { $_ -match '^- \[ \] ' }).Count | Should -Be 7
        }
    }
}
