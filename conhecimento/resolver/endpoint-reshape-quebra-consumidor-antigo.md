## Endpoint muda o formato do payload pra um consumidor novo e quebra os consumidores antigos, silenciosamente (TS não pega, testes não pegam) {#endpoint-reshape-quebra-consumidor-antigo}

`tags: contract change, breaking change, endpoint reshape, migração de formato, tipo fraco em fetch, response.json() as any, consumidor esquecido, integration bug, grep por consumidor`

**Sintoma:** uma rota GET compartilhada por 2+ telas mudou de formato (`ResolvedPattern` flat →
`NamingConfig` aninhado) pra atender a UI nova que motivou a mudança. A tela nova funciona. Uma tela
ANTIGA que consome a MESMA rota, sem relação direta com quem mexeu na rota, quebra inteira com
`TypeError: Cannot read properties of undefined (reading 'X')` — só descoberto ao navegar até ela
num smoke manual, não em `tsc --noEmit` nem na suíte de testes.

**Causa raiz:** `fetch(...).then(r => r.json()).then(d => setState(d.campo))` não tem verificação de
tipo em runtime — o `.then` tipa `d` como o que o dev ESPERA, não o que a rota devolve de fato hoje.
`tsc` não pega porque o tipo do `.json()` é `any` (ou um cast otimista). Os testes não pegam porque
cada teste unitário mocka a rota com o formato que O PRÓPRIO teste já sabe que é certo — nenhum
testa o CONTRATO entre "o que a rota devolve" e "o que cada consumidor espera receber". Pior: se a
rota lê um valor gravado no banco (não só computado), qualquer SAVE feito pela UI nova já migra o
dado real pro formato novo — o bug fica latente até alguém salvar pela tela nova, não só ao fazer
deploy.

**Solução:** antes de mudar o formato de retorno de uma rota compartilhada, `grep` por TODOS os
fetches daquele path (`grep -rn "clientId}/rota-x"` ou equivalente) — não confie em "eu só mudei
a rota que a tela nova usa". Pra cada consumidor achado, decida explicitamente: (a) ele já converte
formato antigo↔novo (grep por `toXConfig`/`adapterFn` perto do fetch — sinal de que já é seguro), ou
(b) precisa do mesmo adaptador que o consumidor "correto" já usa. Ao corrigir, prefira o padrão
"nunca lança, aceita formato antigo OU novo" (uma função tipo `toNewFormat(raw, fallback)` que
detecta o shape em runtime — ex. checando a presença de uma chave só do formato novo) em vez de só
consertar o consumidor quebrado: outros consumidores futuros do mesmo dado herdam a mesma proteção.

**Como achar TODOS os consumidores quebrados, não só o primeiro:** depois de achar e corrigir um,
pergunte "quem MAIS lê essa mesma fonte de dado (mesma tabela/chave), sem passar pela rota que eu já
consertei?" — nesse caso, 2 outras rotas liam a mesma linha do banco via SQL raw direto, cast pro
tipo antigo, sem nenhuma relação de código com a rota já corrigida. `grep` pela CHAVE/tabela no banco
(não só pelo nome da rota) acha esses consumidores paralelos.
