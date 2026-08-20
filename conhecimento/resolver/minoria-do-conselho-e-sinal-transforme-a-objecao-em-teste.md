## A minoria do conselho é sinal: transforme a objeção genérica na sua versão testável {#minoria-do-conselho-e-sinal-transforme-a-objecao-em-teste}

`tags: conselho, council, minoria, divergencia, 2/3, maioria, dissidencia, fact-check, sqlite postgres, varchar, medicao, contar votos, R11`

**Contexto:** conselho de 3 provedores devolve 2/3 numa direção. A regra do loop manda executar a
maioria e citar a divergência. O risco não está na regra — está em tratar o veredito como
**contagem de votos**, quando ele é **conjunto de hipóteses de custo desigual**.

**Sintoma:** a perna vencida diz algo genérico e fácil de descartar — *"teste em SQLite não prova
Postgres"*, *"esse módulo menor é design legítimo"*. Some no relatório como "divergência
minoritária", e a maioria vira ação.

**Os dois casos que geraram o verbete (Família Milionária, 2026-08-20, no mesmo dia):**

1. **A minoria estava certa e achou o bug.** Pergunta: "a escrita virou falsificável, isso encerra o
   item?" Maioria (2/3): encerra. Minoria: *"teste em SQLite não prova Postgres"*. Convertida na
   pergunta concreta — **qual diferença, exatamente, morde este código?** — apareceu:
   `numero` é `varchar(20)`, um JID tem 28 chars, **SQLite ignora largura de VARCHAR e Postgres
   não**. Provado contra o Postgres real em tabela `TEMP`:
   `ERROR: value too long for type character varying(20)`. O `except` best-effort engoliria a linha
   em produção. O bug teria entrado **junto com o commit que dizia fechar essa exata classe**.

2. **A minoria estava errada — e só dava pra saber medindo.** Pergunta: "alinhar dois vocabulários
   que divergiram?" Maioria: alinhar. Minoria: *"o menor é design legítimo, não defeito"*. A versão
   concreta era **os 8 foram escolha ou sobra?**, e a resposta estava no `git log`: o enum de 13
   nasceu em 10/04; o de 8 foi escrito **do zero** em 26/06, espelhando a prosa de outro parágrafo.
   Não houve estreitamento — houve re-escrita independente. **Ninguém decidiu excluir os 5.**

**O que fazer:**

- **Nunca decida por contagem.** 2/3 diz onde está o consenso, não onde está a verdade. O custo de
  investigar a dissidência é de minutos; o custo de ignorá-la é um bug que entra com o conserto.
- **Converta a objeção genérica na pergunta CONCRETA e verificável.** "SQLite ≠ Postgres" não é
  acionável; "qual diferença morde ESTE código?" é. "É design legítimo" não é acionável; "foi
  escolha ou sobra? o que diz a data de nascimento dos dois arquivos?" é.
- **A conversão é o trabalho** — e ela decide nos dois sentidos: no caso 1 confirmou a minoria, no
  caso 2 a refutou com evidência, o que é muito melhor que "a maioria ganhou".
- Registre o veredito da minoria **por escrito** junto com o desfecho. Quem lê depois precisa saber
  que a objeção foi endereçada, não silenciada.

**Ver também:** [[conselho-acerta-a-conclusao-e-erra-a-premissa]] — o espelho: a maioria acerta o
QUE e erra o PORQUÊ. Junto com este verbete, a regra fica: **nem maioria nem minoria são
argumento; a medição é.** · [[perna-conselho-nao-e-perna-morta]]
