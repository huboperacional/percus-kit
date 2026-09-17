## `page.evaluate` dentro do `page.route` de uma NAVEGAÇÃO trava — leia o `sessionStorage` depois, na mesma aba {#playwright-evaluate-no-handler-de-navegacao-trava}

`tags: playwright, e2e, page.route, page.evaluate, navegação, location.assign, sessionStorage, oauth, redirect, timeout, frame detached`

**Sintoma:** para provar que a tela grava algo no `sessionStorage` ANTES de `window.location.assign(urlExterna)`, o teste
intercepta a URL externa (`page.route('https://accounts.google.com/**', ...)`) e, dentro do handler, faz
`await page.evaluate(() => sessionStorage.getItem(chave))`. O teste estoura o tempo: `page.evaluate: Test timeout of 30000ms
exceeded. while running route callback` e, junto, `page.waitForURL: net::ERR_ABORTED; maybe frame was detached?`. A tela está
certa. Medido em 2026-09-16 (Empresa Milionária, Task 17 da guarda do documento, spec escrito por subagente e nunca rodado).

**Causa raiz:** o handler roda com a navegação do quadro principal suspensa pela interceptação. O documento antigo está
saindo, e o `evaluate` espera um contexto de execução que só existiria depois de a navegação terminar. Mas a navegação só
termina quando o handler chama `route.fulfill`. É um impasse: o handler espera a página e a página espera o handler.

**Solução:**

1. No handler, só `route.fulfill` (um HTML de dublê). Nada de `page.evaluate`.
2. Depois do `waitForURL(externa)`, **volte à origem do app NA MESMA ABA** (`page.goto('/algum-estatico.txt')`) e leia o
   `sessionStorage` ali. O `sessionStorage` é da aba e da origem e sobrevive à ida e volta por outra origem, que é
   exatamente o caminho real de um OAuth.
3. Com isso se prova "gravado antes de a página sair". Não se prova a ordem síncrona gravar → `assign` dentro do mesmo tique:
   JS depois do `assign` no mesmo tique também roda. Declare isso. A sabotagem que discrimina é gravar depois de um `await`.
4. Antes do clique, afirme que o item **não** existe (controle negativo), senão uma semeadura esquecida passa por gravação.
