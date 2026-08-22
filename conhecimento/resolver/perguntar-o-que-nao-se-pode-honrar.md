## Perguntar o que não se pode honrar é o mesmo defeito com outra roupa {#perguntar-o-que-nao-se-pode-honrar}

`tags: conversa, bot, oferta, cursor, pergunta sem resposta, precedencia, passo ativo, aviso, correcao de rota, decisao do operador, opcao escolhida muda na implementacao, afirmar em vez de perguntar`

**Origem:** tiatendo, 2026-08-21 (N34) — a opção escolhida pelo operador mudou de forma durante a
implementação, e o motivo vale mais que o caso.

**O defeito original:** o bot oferecia remontar um pedido encerrado. O cliente respondia **`sim`** —
e o `sim` era consumido por um passo ativo (uma desambiguação aberta no mesmo turno). A precedência
estava **certa** e era deliberada. O defeito era o **silêncio**: a oferta morria sem uma palavra, e
quem quis remontar não remontou **e não soube**.

Decisão: *avisar no mesmo turno*, com a redação sugerida terminando em **"quer remontar?"**.

**O que apareceu ao implementar:** no mesmo bloco em que o aviso sairia, a oferta é marcada como
`passed_over` — e o handler de resposta mata oferta passada **de propósito** (aceite tardio não pode
ressuscitar estado sem trilha). Logo:

- um `sim` no turno seguinte cairia **no vazio**;
- e enquanto o passo ativo vivesse, a precedência o consumiria **de novo** — o defeito original.

**A pergunta reproduzia exatamente o que ela ia consertar.** Trocaria um silêncio por uma promessa
falsa, que é pior: o cliente agora tem motivo para esperar.

- **O conserto:** o aviso **AFIRMA**. Diz o que aconteceu, **nomeia os itens e o valor**, e devolve
  a iniciativa (*"se quiser esses itens, é só me pedir de novo"*) — um caminho que funciona sempre,
  sem depender de cursor, sessão ou janela nenhuma.
- **A regra:** antes de escrever qualquer pergunta que o sistema faz, responda **"o que acontece com
  a resposta?"**. Se a resposta pode chegar quando não há mais quem a receba, a pergunta é decorativa
  — e decoração que promete é dano.
- **Quando a pergunta VALE:** só se você também construir o caminho que a honra (guardar o cursor
  até o passo ativo fechar). Isso costuma ser a opção que foi **recusada** por outro motivo — então a
  escolha real é *"afirmar"* ou *"reabrir a janela"*, nunca *"perguntar de graça"*.
- **Processo:** quando a implementação revela que a opção escolhida tem um custo que não estava na
  mesa, **entregue a forma honesta e declare a mudança de rota** — no código, no rastreamento e para
  quem decidiu. Escolha do operador feita sobre premissa incompleta não é escolha; é ratificação.
- **Prova:** um alvo de mutação que faz a fala **voltar a perguntar** tem que derrubar um teste
  dedicado. Sem ele a decisão vive só na prosa, e a próxima revisão de copy a desfaz sem saber.
