## Tag de plano aberta que já foi entregue sob OUTRO número de migration {#migration-numero-reciclado}

`tags: plano, tag aberta, pendencia falsa, migration numerada, numero reciclado, obra ja entregue, auditoria de plano, frente fossil, arqueologia, PLANO.md, drift de plano`

**Sintoma:** o plano tem dezenas de tags abertas de meses atrás. Parecem trabalho pendente, mas ninguém lembra de tê-las abandonado — e a feature parece existir em produção.

**Causa raiz:** planos antigos citam a obra pelo **número da migration** (`054`, `055`). Quando aquela frente parou, os números foram **reciclados** por frentes posteriores. A obra acabou sendo entregue depois, sob outro número e outro nome — e a tag antiga ficou aberta apontando para um identificador que hoje significa outra coisa. Ninguém fechou porque ninguém sabia que já estava feito.

**Solução:**
1. **Não julgue frente antiga por data.** "Parado há 6 semanas" não distingue abandono de obra-entregue-por-outra-rota. Ausência de sinal não é sinal.
2. Verifique **cada tag aberta contra o código, o banco e as migrations** — nunca por memória nem pelo texto do plano. Agentes de busca em paralelo tornam isso barato.
3. Trate número de migration citado em plano como **referência frágil**: confirme pelo **efeito** (tabela/coluna/flag existe? rota responde?), não pelo número.
4. O veredito útil tem três valores, não dois: **VIVA · FÓSSIL · PARCIAL**. Parcial é o caso comum — a maior parte entregue, um resto real.
5. Ao mover pro histórico, **feche a conta por soma de linhas** (antes = depois + movido ± cabeçalhos). Sem isso, "limpeza" e "perda silenciosa" são indistinguíveis.

**Ref:** tiatendo, 2026-07-20 — auditoria de 4 frentes: 221 linhas fósseis, mas **6 pendências eram reais**. Commit `65140c7`.
