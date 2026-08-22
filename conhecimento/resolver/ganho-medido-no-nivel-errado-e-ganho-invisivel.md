## Ganho medido no nível errado é ganho invisível {#ganho-medido-no-nivel-errado-e-ganho-invisivel}

`tags: denominador, medicao, populacao, nivel de entidade, ganho invisivel, cobertura, backlog, priorizacao, R23, superficie de leitura`

**Contexto:** uma medição diz que X% de um problema está resolvido por uma mudança, o operador
aprova com base nesse número, a mudança entra — e **nada muda na tela**. O número estava certo; a
população em que ele foi medido não era a que o produto lê.

**Caso concreto:** "14 tokens somam 46% de todos os tokens não reconhecidos da carteira" era
verdade sobre os **1.173 nomes** de campanha + conjunto + criativo. Mas **toda** a superfície do
produto consultava só `campaigns` — 5 rotas/telas, todas lendo a mesma tabela. Filtrando pela
população que alguma rota lê:

```
nível      não reconhecidos   alguma rota lia?
campaign        186                 SIM
adset           263                 não
creative        219                 não
```

Das 4 famílias de vocabulário confirmadas pelo operador, **3 viviam exclusivamente em conjunto e
criativo**. Semeá-las era dado certo com efeito **zero** — 44 de 568 peças estavam onde alguém olha.

**Causa raiz:** "quantas ocorrências existem" e "quantas o produto mostra" são perguntas
diferentes, e a primeira é a fácil de medir. O denominador default de um dump é a tabela inteira; o
denominador que importa é a interseção com o que algum leitor consome.

**Como diagnosticar antes de construir:**

1. Enumere os **leitores** por grep (`prisma.<tabela>.findMany`, o endpoint, o componente) — não de
   memória. Cinco leitores lendo a mesma tabela parecem cinco superfícies e são uma.
2. Refaça a medição **filtrada por essa população**. Se o ganho cair para perto de zero, a fatia que
   vale não é a que você ia fazer: é a que faz algum leitor enxergar o resto.
3. Trave a frase em teste. *"Estas famílias têm 0 ocorrência no nível que o produto lê"* envelhece
   calada; como gate, ela reprova exatamente no dia em que deixar de ser verdade — que é o dia em
   que o trabalho anterior passa a valer.

**O que NÃO fazer:** não cancele a fatia de dado só porque o ganho visível é zero. O dado estava
certo e custava pouco; o erro seria **anunciá-lo como ganho**. Entregue, e diga na mesma frase que
ele não move a tela hoje e o que o destrava.

**Sinal de que você caiu nisto:** o commit diz "resolve N% de X" e a medição de N usou `SELECT
count(*) FROM <tabela>` sem nenhum `JOIN` com quem lê.

Relacionado: [[campo-escrito-nunca-lido-mente-quando-alguem-depende]],
[[medir-antes-de-escrever-a-justificativa]].
