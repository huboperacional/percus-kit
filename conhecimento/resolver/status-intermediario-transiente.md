## Transição automática nova torna um status intermediário TRANSIENTE e mata todo leitor por igualdade {#status-intermediario-transiente}

`tags: status, state machine, transicao automatica, where status =, codigo morto, suite verde, mock esconde drift, notificacao, dispatch`

**Contexto:** tiatendo, frente "estações de preparo" (2026-07-23). O pedido passou a ir de `confirmed` pra `in_kitchen`/`ready` **dentro da mesma transação** da confirmação. Nenhum pedido descansa mais em `confirmed`. Três leitores que perguntavam `status = 'confirmed'` viraram código morto **em silêncio**, com a suíte 100% verde: o sino de "novo pedido" do dashboard ficaria mudo pra sempre em todo tenant, e o comprovante Pix validado deixava o pedido como pendente no caixa (risco de cobrar de novo na entrega).

**Causa raiz:** inserir uma transição automática **remove um estado de repouso** do sistema, mas ninguém audita quem lia aquele estado. Sobrevivem só os leitores que usam *conjunto* de status (`IN (...)`, `NOT IN (...)`); morrem os que usam **igualdade**. E os testes não pegam porque tipicamente mockam o status antigo ou testam a função pura, nunca a query.

**Solução:** ao introduzir qualquer transição automática, faça um grep do estado que deixou de ser terminal (`= 'X'`, `== "X"`) em TODO o código — incluindo notificações, KPIs, relatórios e crons — antes de fechar a frente. Prefira perguntar pelo **fato** (`confirmed_at IS NOT NULL`) e não pelo **estado** (`status = 'confirmed'`). Desconfie de teste cujo mock devolve status fixo: ele passa exatamente quando a produção quebra.

**Ref:** tiatendo PROD `0.244.0`, ADR-0013; memória de projeto `feedback-confirmed-virou-status-transiente`.
