#requires -Version 5.1
# Guarda do GATILHO da skill `checkpoint`.
#
# Pedido do operador em 2026-09-12, literal: "quando eu falar checkpoint: termine a tarefa
# atual, atualize todos os arquivos, e facamos o clear". A skill ja existia e ja fazia a parte
# do meio; faltava (a) disparar quando ele diz a palavra, (b) terminar a tarefa antes, e (c)
# dizer de cara que o agente NAO executa o clear.
#
# Por que testar TEXTO aqui, se em geral medir rotulo e o defeito que este repo persegue: numa
# skill o texto E o artefato. A `description` do frontmatter e literalmente o que faz o Claude
# Code disparar a skill -- nao ha runtime por tras dela pra medir. Entao asserir o texto nao e
# proxy de comportamento: e a superficie de comportamento. O que este arquivo impede e alguem
# reescrever a description e derrubar o gatilho sem perceber.

Describe "gatilho da skill checkpoint" {

    BeforeAll {
        $script:skillPath = Join-Path (Split-Path $PSScriptRoot -Parent) "skills\checkpoint\SKILL.md"
        $script:texto = if (Test-Path $script:skillPath) { [IO.File]::ReadAllText($script:skillPath) } else { "" }

        # A description e o que dispara a skill. Extrai so ela, do frontmatter YAML.
        $m = [regex]::Match($script:texto, '(?ms)^---\s*\r?\n.*?^description:\s*(?<d>.+?)\r?\n(?:^[a-z_]+:|^---)')
        $script:description = if ($m.Success) { $m.Groups['d'].Value } else { "" }
    }

    It "a skill existe" {
        Test-Path $script:skillPath | Should -BeTrue
        $script:texto.Length | Should -BeGreaterThan 500 -Because "anti-vacuidade: arquivo vazio faria todo Should -Match abaixo passar por engano"
    }

    It "a description tem a description extraida (anti-vacuidade do regex)" {
        $script:description | Should -Not -BeNullOrEmpty -Because "se o regex do frontmatter parar de casar, os testes de gatilho aferem string vazia"
        $script:description.Length | Should -BeGreaterThan 80
    }

    It "DISPARA quando o operador diz a palavra -- o gatilho lexical esta na description" {
        # Sem isto a skill so dispara por milestone/hook, e o pedido do operador ("quando eu
        # falar checkpoint") nao tem mecanismo nenhum: fica dependendo de o agente lembrar.
        $script:description | Should -Match 'operador (diz|falar|disser)|quando (eu|o operador)' `
            -Because "o gatilho pedido e a PALAVRA dita pelo operador, e description e onde isso dispara"
        $script:description | Should -Match '(?i)checkpoint'
    }

    It "a description declara que o agente NAO executa o clear" {
        # O operador pediu "facamos o clear". O agente nao tem ferramenta pra isso, e slash
        # command nao funciona no VSCode dele. Se a skill nao disser isso na description, ele
        # fica esperando um clear que nunca vem.
        $script:description | Should -Match '(?i)n[aã]o executa|n[aã]o roda|quem d[aá] o|e do operador|é do operador' `
            -Because "limite real tem que estar na porta de entrada, nao enterrado no passo 5"
        $script:description | Should -Match '(?i)/clear|reset'
    }

    It "manda TERMINAR A TAREFA ATUAL antes de sincronizar arquivos" {
        # Primeira parte do pedido, e a que faltava por inteiro: checkpoint que interrompe
        # tarefa pela metade sincroniza arquivos descrevendo um estado quebrado.
        $script:texto | Should -Match '(?i)termine a tarefa atual|terminar a tarefa atual' `
            -Because "o operador pediu isto primeiro, antes de atualizar arquivos"
    }

    It "o passo de terminar a tarefa vem ANTES do passo de sincronizar arquivos" {
        $iTerminar = $script:texto.IndexOf("Termine a tarefa atual", [StringComparison]::OrdinalIgnoreCase)
        $iSync     = $script:texto.IndexOf("Sincronizar os arquivos de estado", [StringComparison]::OrdinalIgnoreCase)
        $iTerminar | Should -BeGreaterThan -1
        $iSync     | Should -BeGreaterThan -1
        $iTerminar | Should -BeLessThan $iSync -Because "ordem importa: sincronizar primeiro registra um estado que ainda vai mudar"
    }

    It "diz o que fazer quando a tarefa NAO pode ser terminada" {
        # Sem esta saida, "termine a tarefa atual" vira ou pressa (fechar mal pra poder
        # checkpointar) ou travamento (nao checkpointar nunca).
        $script:texto | Should -Match '(?i)n[aã]o d[aá] pra terminar|n[aã]o for poss[ií]vel terminar|nao puder ser terminada' `
            -Because "tarefa que nao fecha tem que virar proximo-passo declarado, nao fingimento"
    }
}
