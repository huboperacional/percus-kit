## n8n `$('Node').item` (paired item) aborta com "Multiple matches found" assim que o fluxo carrega 2+ itens {#n8n-paired-item-multiple-matches}

`tags: n8n, paired item, Multiple matches found, pairedItemMultipleMatchesCodeNode, $('Node').item, LIMIT, fan-out, multi-tenant, canal, workflow quebra depois de agir`

**Sintoma:** o workflow rodou meses sem problema e passa a abortar com
`Multiple matches found` / `pairedItemMultipleMatchesCodeNode` logo depois de você **habilitar o
segundo** de alguma coisa (segundo canal, segunda conta, segundo cliente).

**Causa raiz:** `$('Nome do Node').item` (singular) só resolve quando existe **um** item no fluxo —
é uma referência ao item *pareado* com o atual. Um node de origem com `LIMIT 20` (ou sem `LIMIT`
nenhum) devolvia 1 linha enquanto só existia um registro habilitado; com dois, o n8n não consegue
decidir qual item corresponde e aborta.

**O que torna isso grave:** o erro estoura **no meio do fluxo**, geralmente num node de
`UPDATE`/release **depois** do node que já executou a ação externa (o POST/PATCH que manda a
mensagem, cobra o cartão, cria o registro). O efeito colateral já aconteceu e o estado local fica
inconsistente, porque a linha que ia registrar/limpar nunca rodou.

**Solução:** decida qual é a verdade e torne-a explícita.
- Se o desenho real é "um por execução" (worker com schedule frequente), ponha `LIMIT 1` na origem
  **e documente no artefato** que N nodes dependem disso.
- Se o desenho é fan-out de verdade, tire o `.item` e use `$('Node').all()[$itemIndex]` /
  `itemMatching()`.

**Armadilha do `LIMIT 1` ingênuo (custa um segundo bug):** com `ORDER BY <proximo_horario> LIMIT 1`,
qualquer caminho que **não avance** esse campo faz o registro escolhido vencer a ordenação **para
sempre** e matar os outros de fome, em silêncio. Audite TODOS os caminhos de saída (fila vazia,
falha, cancelamento) — se um deles só limpa o lock sem empurrar o horário, é starvation. Um sintoma
que denuncia: dois nodes irmãos de "release" com queries diferentes, um com `next_send_at = NOW()` e
outro sem. Reforce a origem com `EXISTS(<tem trabalho de verdade>)` e um predicado de lock, para não
selecionar quem não tem o que fazer.

**Ref:** Kommo-Disparo-WhatsApp, 2026-08-12. `Find Due Channels` com `LIMIT 20` + 7 nodes usando
`.item`: ao habilitar o 2º canal de WhatsApp, toda execução que chegava no disparo abortava **depois
do PATCH que aciona o bot**. O `LIMIT 1` corrigiu isso e introduziu a starvation descrita acima,
pega no review antes de ir pra produção.
