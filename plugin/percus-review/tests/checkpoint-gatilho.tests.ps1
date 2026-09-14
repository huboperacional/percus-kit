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

        # Secao do markdown: do titulo (prefixo ASCII) ate o proximo titulo de nivel igual ou maior.
        function Get-Secao {
            param([string]$Prefixo)
            $i = $script:texto.IndexOf($Prefixo, [StringComparison]::Ordinal)
            if ($i -lt 0) { return "" }
            $nivel = ([regex]::Match($Prefixo, '^#+')).Value.Length
            $resto = $script:texto.Substring($i + $Prefixo.Length)
            $mm = [regex]::Match($resto, '(?m)^#{1,' + $nivel + '} ')
            if ($mm.Success) { return $Prefixo + $resto.Substring(0, $mm.Index) }
            return $Prefixo + $resto
        }
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

    # Decisao do operador em 2026-09-14: so o operador inicia checkpoint e manda abrir sessao nova.
    # Medido no mesmo dia: sessao com 244k tokens (26% de uma janela de 1M) recebeu do hook "rode
    # percus-review:checkpoint e encerre em RESET", fez checkpoint e mandou o operador abrir sessao
    # nova sem ele pedir. A skill obedecia por tres portas: o hook como gatilho na description, os
    # gatilhos automaticos em "Quando rodar" e o reset obrigatorio do passo 5.

    It "a description so tem o operador como gatilho (sem milestone, sem hook, sem contexto crescendo)" {
        $script:description | Should -Not -Match '(?i)milestone|context-budget|contexto cresceu|contexto ficando grande' `
            -Because "description e o que dispara a skill; gatilho que nao seja o operador vira checkpoint por conta propria"
    }

    It "a description diz que o agente nunca inicia checkpoint nem manda abrir sessao nova" {
        $script:description | Should -Match '(?i)nunca inicia checkpoint por conta pr.pria'
        $script:description | Should -Match '(?i)abrir sess.o nova sem o operador pedir'
    }

    It "Quando rodar lista so pedidos do operador" {
        $s = Get-Secao '## Quando rodar'
        $s.Length | Should -BeGreaterThan 100 -Because "anti-vacuidade: a secao tem que existir"
        $s | Should -Not -Match '(?i)milestone|context-budget|contexto ficando grande|PreCompact|hook'
        $s | Should -Match '(?i)checkpoint'
        $s | Should -Match '(?i)fechar ou limpar a sess.o'
    }

    It "O que o agente NAO faz inclui iniciar checkpoint e mandar abrir sessao nova" {
        $s = Get-Secao '## O que o agente'
        $s.Length | Should -BeGreaterThan 100 -Because "anti-vacuidade"
        $s | Should -Match '(?i)n.o inicia checkpoint por conta pr.pria'
        $s | Should -Match '(?i)n.o manda abrir sess.o nova'
    }

    It "o passo 5 so fala de sessao nova quando o operador pediu" {
        $s = Get-Secao '### 5.'
        $s.Length | Should -BeGreaterThan 100 -Because "anti-vacuidade"
        $s | Should -Not -Match '(?i)obrigat|n.o retome o trabalho' -Because "reset obrigatorio foi a porta que mandou abrir sessao nova sem pedido"
        $s | Should -Match '(?i)operador pediu'
    }

    It "nenhum resto da politica antiga: reset obrigatorio, horas na saida, checkpoint proativo" {
        $script:texto | Should -Not -Match 'RESET OBRIGAT'
        $script:texto | Should -Not -Match '\{H\}h' -Because "hora de parede saiu da politica na 6.52.0 e sobrou na saida esperada"
        $script:texto | Should -Not -Match '(?i)fa.a no milestone, proativo'
        $script:texto | Should -Not -Match '(?i)checkpoint sem reset em sess.o avisada'
        $script:texto | Should -Not -Match '(?i)\(agente\) roda isto'
    }
}
