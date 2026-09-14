# GUARDA: nenhum bloco do Pester declara BeforeAll, AfterAll, BeforeEach ou AfterEach duas vezes
# no mesmo nivel.
#
# Medido 2026-09-13 no Pester 5.7.1: com dois AfterAll no mesmo bloco, SO O SEGUNDO roda. O
# primeiro some calado -- sem erro, sem aviso, suite verde. Foi assim que o
# regras-do-canon-injetadas.tests.ps1 deixava o console em 65001 para os arquivos seguintes do
# mesmo balde do rodar-suite: o AfterAll que devolvia a codepage nunca executou, e os vizinhos
# passavam a rodar na codepage do terminal do agente, e nao na do harness.

BeforeAll {
    $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')).Path

    function Get-ChamadaDeBloco {
        param([System.Management.Automation.Language.Ast]$Ast)
        $Ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.CommandAst] -and
            $n.GetCommandName() -in @('BeforeAll', 'AfterAll', 'BeforeEach', 'AfterEach')
        }, $true)
    }

    function Find-BlocoDuplicado {
        # Devolve "<Nome> linhas <a>, <b>" para cada nome declarado mais de uma vez no MESMO
        # scriptblock dono (o corpo de um Describe/Context, ou o proprio arquivo).
        param([System.Management.Automation.Language.Ast]$Ast)
        $grupos = @{}
        foreach ($c in (Get-ChamadaDeBloco $Ast)) {
            $dono = $c.Parent
            while ($dono -and $dono -isnot [System.Management.Automation.Language.ScriptBlockAst]) { $dono = $dono.Parent }
            $chave = '{0}|{1}' -f $c.GetCommandName().ToLowerInvariant(), $dono.Extent.StartOffset
            if (-not $grupos.ContainsKey($chave)) { $grupos[$chave] = New-Object System.Collections.Generic.List[object] }
            $grupos[$chave].Add($c)
        }
        foreach ($g in $grupos.Values) {
            if ($g.Count -gt 1) {
                '{0} linhas {1}' -f $g[0].GetCommandName(), (($g | ForEach-Object { $_.Extent.StartLineNumber }) -join ', ')
            }
        }
    }

    function ConvertTo-AstDeTexto([string]$Texto) {
        $t = $null; $e = $null
        [System.Management.Automation.Language.Parser]::ParseInput($Texto, [ref]$t, [ref]$e)
    }
}

Describe "blocos de setup e teardown do Pester sao unicos por nivel" {

    It "o detector acusa dois AfterAll no mesmo Describe" {
        $ast = ConvertTo-AstDeTexto "Describe 'x' {`n  AfterAll { 1 }`n  BeforeAll { 2 }`n  AfterAll { 3 }`n  It 'y' { }`n}"
        @(Find-BlocoDuplicado $ast).Count | Should -Be 1
    }

    It "o detector NAO acusa o mesmo nome em niveis diferentes" {
        $ast = ConvertTo-AstDeTexto "AfterAll { 0 }`nDescribe 'x' {`n  AfterAll { 1 }`n  Context 'c' {`n    AfterAll { 2 }`n  }`n}"
        @(Find-BlocoDuplicado $ast).Count | Should -Be 0
    }

    It "nenhum arquivo de teste do kit declara o mesmo bloco duas vezes no mesmo nivel" {
        $arquivos = @(foreach ($c in 'plugin/percus-review/tests', 'tools/__tests__') {
            $p = Join-Path $script:kitRoot $c
            if (Test-Path $p) { Get-ChildItem $p -Filter '*.tests.ps1' -File -Recurse }
        })
        # Pisos bem abaixo do baseline medido em 2026-09-13 (56 arquivos, 107 blocos). Cair abaixo
        # deles e sinal de varredura no lugar errado ou parcial, que ">0" nao pegaria. Se a suite
        # encolher de verdade, ajuste o piso com a contagem nova -- nao o apague.
        $arquivos.Count | Should -BeGreaterThan 40 -Because "anti-vacuidade: sem arquivo varrido a guarda afere nada"

        $totalBlocos = 0
        $achados = @()
        foreach ($f in $arquivos) {
            $t = $null; $e = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$t, [ref]$e)
            $totalBlocos += @(Get-ChamadaDeBloco $ast).Count
            foreach ($d in @(Find-BlocoDuplicado $ast)) { $achados += "$($f.Name): $d" }
        }
        $totalBlocos | Should -BeGreaterThan 40 -Because "anti-vacuidade: o parser tem que achar os blocos que existem"
        $achados | Should -BeNullOrEmpty -Because "no Pester 5 so o ULTIMO bloco de mesmo nome roda; os anteriores somem calados"
    }
}
