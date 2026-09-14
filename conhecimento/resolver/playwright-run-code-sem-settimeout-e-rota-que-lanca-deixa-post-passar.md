## Script do Playwright MCP não tem `setTimeout`, e o handler de rota que lança deixa a rota presa e o POST passa {#playwright-run-code-sem-settimeout-e-rota-que-lanca-deixa-post-passar}

`tags: playwright, mcp, browser_run_code_unsafe, page.route, setTimeout, ReferenceError, unrouteAll, dado de teste, conferencia no navegador, rede lenta`

**Sintoma:** para ver o estado de envio de um botão, o script atrasa os POST com `page.route` e
`new Promise((r) => setTimeout(r, 1500))`. Resultado: `ReferenceError: setTimeout is not defined`.

**Causa:** o código do `browser_run_code_unsafe` roda num sandbox sem os timers globais do Node. O
erro estoura **dentro do handler da rota**, no primeiro POST. O script aborta — mas a rota continua
registrada na página e, medido, **o POST chegou ao servidor e gravou**: um ingrediente de teste ficou
na ficha, e só apareceu na contagem da tentativa seguinte.

**Correção:**
- atraso dentro do handler com `await page.waitForTimeout(1500)`;
- todo script começa com `await page.unrouteAll({ behavior: 'ignoreErrors' })` e termina com ele;
- depois de um script que falhou no meio, **liste o dado antes de repetir** e limpe o que a tentativa
  quebrada gravou (no caso, o item tinha a quantidade de teste, 12 g — use valores de teste
  reconhecíveis).

**Ref:** LiliCalc, conferência dos botões de envio (2026-09-14).
