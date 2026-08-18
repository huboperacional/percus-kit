## `Response`/`fetch` com corpo em status 204/205/304 lança TypeError — mesmo ArrayBuffer vazio não é `null` {#response-204-corpo-lanca-typeerror}

`tags: fetch, Response, NextResponse, 204 No Content, 205, 304, passthrough, proxy, BFF, TypeError, null body status, ArrayBuffer vazio, ArrayBuffer.byteLength zero nao e null`

**Contexto:** um BFF/proxy genérico que repassa qualquer resposta de upstream (`new Response(body,
{status: upstream.status, ...})`, `body = await upstream.arrayBuffer()`) funciona para todo status
que os callers existentes exercitam (200, 4xx, 5xx) — e quebra só quando um NOVO caller passa por um
endpoint que devolve **204/205/304**. O bug fica latente por meses: o helper compartilhado nunca foi
testado nesse caminho porque nenhum caller anterior batia nele.

**Sintoma:** `TypeError: Response constructor: Invalid response status code 204` (ou mensagem
equivalente em runtimes diferentes) ao construir `new Response(buf, {status: 204})` — mesmo quando
`buf` é um `ArrayBuffer` de **0 bytes**. A mensagem de erro não deixa óbvio que o problema é "corpo
presente", porque um buffer vazio não parece "ter corpo" pra quem lê o código.

**Causa raiz:** o Fetch spec proíbe corpo em respostas com status 204/205/304 ("null body status").
A implementação do `Response`/`NextResponse` verifica se `body !== null` — um `ArrayBuffer(0)` **não
é** `null`, é um valor válido (só que vazio), então a checagem de "tem corpo" dispara mesmo sem
nenhum byte de conteúdo. `body: undefined` também conta como presente em alguns runtimes; só `null`
explícito passa.

**Solução:** no passthrough genérico, checar o status ANTES de decidir o que passar como body:

```ts
const NULL_BODY_STATUSES = new Set([204, 205, 304]);
return new NextResponse(NULL_BODY_STATUSES.has(upstream.status) ? null : body, {
  status: upstream.status,
  statusText: upstream.statusText,
  headers: respHeaders,
});
```

Teste que prova (não só documenta) o fix: construir um `Response(null, {status: 204})` real e passar
pelo passthrough, sem mock do `Response` nativo — o bug só aparece com a implementação real do
runtime, um mock ingênuo de `Response` não reproduz a checagem do spec.

**Como achar isso ANTES de escrever código novo:** se você está criando um caller novo pra um
endpoint que pode devolver 204 (DELETE, PUT sem corpo de retorno) através de um helper de
passthrough JÁ EXISTENTE e compartilhado por outros callers, pergunte "algum caller anterior desse
helper já bateu em 204/205/304?" — se não, é caminho morto não coberto, não caminho testado.

**Ref:** achado no Task 6 da fatia "multiplicidade de destinos" (Paid Media Automation, 2026-08-03) —
`DELETE /destinations/[did]` e `PUT /destinations/[did]/secret` foram os primeiros callers de
`passthroughResponse` (`web/src/lib/tracking-client-auth.ts`) a devolver 204; `crm/signals` e
`excluded-domains` (callers anteriores) só bateram 200/4xx/5xx.
