## `console.log(objeto)` trunca aninhamento como `[Object]` e esconde o erro real de uma integração que "falhou sem motivo" {#console-log-objeto-trunca-oculta-erro}

`tags: node console.log truncamento, object depth padrao, log estruturado incompleto, erro escondido no log, util inspect depth, debugging as cegas`

**Sintoma:** um log estruturado (`console.log('[evento]', { ...campos, resultado: {...aninhado} })`)
mostrava o campo aninhado como `resultado: { upsert: [Object], note: [Object] }` — sem nenhum
detalhe do que de fato aconteceu (`ok`, `error`, `status`). Impossível diagnosticar uma falha de
integração externa só olhando o log em produção; precisou reproduzir a chamada manualmente pra
descobrir o erro real.

**Causa raiz:** `console.log` do Node usa `util.inspect` por baixo dos panos, que por padrão só
desce **2 níveis** de profundidade em objetos aninhados antes de substituir por `[Object]`/`[Array]`.
Um objeto de resultado com 2+ níveis de aninhamento (comum em respostas de API — `{ upsert: { ok,
status, data: {...} }, note: {...} }`) estoura esse teto silenciosamente. Não há warning, não há
erro — o log simplesmente perde informação, e quem lê não tem como saber que perdeu.

**Solução:** pra log estruturado que vai ser lido depois (arquivo, `docker service logs`, sistema de
observabilidade), nunca passar o objeto direto pro `console.log` — usar `console.log('[tag]',
JSON.stringify(objeto))`. `JSON.stringify` não tem teto de profundidade (serializa tudo, exceto
referências circulares). Alternativa se precisar manter objeto navegável no terminal interativo:
`console.log(util.inspect(objeto, { depth: null }))`.

**Trade-off:** `JSON.stringify` perde a formatação colorida/indentada do `util.inspect` no terminal
— pra debugging interativo local, `depth: null` é mais legível; pra log de produção que vai ser
grepado/parseado depois, `JSON.stringify` (uma linha, sem truncamento) é estritamente melhor.

**Ref:** ADS4PROS-Site, sessão 2026-08-05 (`app/api/proposal-accept/route.ts` — log `[proposal-accept]`
escondia o motivo real da falha do GHL atrás de `[Object]`, atrasou o diagnóstico do incidente de
credenciais vazias).
