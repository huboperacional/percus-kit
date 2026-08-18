## Lição escrita em prosa não impede reincidência — o conserto tem que morar num gate {#licao-em-prosa-reincide}

`tags: e2e, playwright, teste que escreve em producao, afterEach, globalTeardown, cleanup, licao aprendida, post-mortem, reincidencia, dado de cliente, lixo de teste`

**Origem:** Família Milionária, 2026-07-28 → 2026-07-31 (a mesma falha, duas vezes, a segunda pior).

Em 28/07 o e2e autenticado deixou lixo em produção e o post-mortem registrou a lição certa: *"spec de
CRUD contra prod precisa de cleanup em `afterEach`, não no fim do corpo do teste"*. O lixo foi
limpo. **Em 31/07 aconteceu de novo, maior**: 62 lançamentos falsos somando R$ 162.000 na conta do
operador, contra R$ 84.000 de dado real — e **56 deles nem foram criados pelo teste**, foram
materializados pelo scheduler a partir de 4 recorrências que sobreviveram a um teste vermelho.

A lição estava escrita e mesmo assim reincidiu, porque **dependia de alguém lembrar**.

- **A regra:** quando a mesma falha reincide, não reescreva a lição — mude o lugar dela. Cleanup
  pertence ao **config** (`globalTeardown`, que roda passando ou falhando e cobre até spec que ainda
  não existe), não a um hábito por spec. Doc não é enforcement.
- **Ordem importa no sweep:** apague o **template de recorrência ANTES** dos lançamentos. Enquanto o
  template vive, o scheduler repõe o que você acabou de apagar.
- **O filtro que autoriza apagar em produção é o código mais perigoso do repo** — isole numa função
  própria, com teste próprio, afirmando contra os **nomes REAIS** do banco. Use `startsWith`, não
  `includes`: é a diferença entre limpar teste e destruir dado de cliente.
- **Sintoma-assinatura:** o dashboard do dono mostra dado com prefixo de teste; o volume do lixo
  supera o real; e a conta "cresce sozinha" entre rodadas (é recorrência materializando).
- **A doença por trás do sintoma:** suíte autenticada apontando pra **produção** com token de gente
  real. Cleanup é curativo; usuário de teste em faixa reservada é a cura.
