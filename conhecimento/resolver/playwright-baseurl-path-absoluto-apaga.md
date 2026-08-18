## Playwright `request.newContext({baseURL})` + rota com `/` no início APAGA o path inteiro do baseURL (silencioso, 404 em tudo) {#playwright-baseurl-path-absoluto-apaga}

tags: playwright apirequestcontext, baseurl, new URL path base, whatwg url resolution, leading
slash relative path, ctx.get 404, teardown nunca limpou, global-teardown silently broken,
request.newContext baseURL bug, url absoluta vs relativa

**Sintoma:** um `APIRequestContext` criado com `request.newContext({ baseURL: 'https://api.exemplo.com/api/v1' })`
(sem `/` no fim) faz `ctx.get('/recurso/')` (rota COM `/` no início) e recebe **404** — mesmo com
token válido, mesmo o endpoint existindo de verdade (confirmado batendo a MESMA URL com `curl`
manualmente: 200 OK). O erro não aparece como falha de auth (401/403) — é um 404 limpo, `{"detail":
"Not Found"}`, porque a requisição de fato chegou no servidor, só que num path errado.

**Causa raiz:** Playwright resolve `baseURL` + rota via `new URL(givenURL, baseURL)`
(`playwright-core/lib/utils/isomorphic/urlMatch.js::resolveBaseURL`) — semântica WHATWG padrão do
construtor `URL`. Quando `givenURL` começa com `/` (path absoluto), o resultado **descarta o path
inteiro do `baseURL`**, mantendo só o origin (protocolo+host+porta):
```js
new URL('/metas/', 'https://api.exemplo.com/api/v1')  // -> 'https://api.exemplo.com/metas/'  (sem /api/v1!)
new URL('metas/',  'https://api.exemplo.com/api/v1/')  // -> 'https://api.exemplo.com/api/v1/metas/'  (correto)
```
Isso é comportamento **documentado do próprio `URL()` do JS/WHATWG** — não é bug do Playwright, mas
a combinação "`baseURL` sem `/` final" + "rota com `/` inicial" (a forma mais intuitiva de escrever
as duas coisas) produz esse resultado contra-intuitivo silenciosamente. Não falha no request feito
manualmente com string concatenada (`${API_BASE}${rota}`) — só quando se depende do parâmetro
`baseURL` do `newContext`/`APIRequestContext` pra fazer a junção.

**Por que é fácil passar 3 semanas sem notar:** se o código que usa esse `ctx` for justamente uma
rede de segurança/teardown que só roda condicionalmente (ex.: só depois de uma suíte autenticada
rodar de verdade) e o "caminho feliz" raramente é exercitado (porque outra dependência — ex. um
token manual — está quebrada há tempos), o 404 nunca aparece nos logs de ninguém. Confirmado numa
sessão real: um `globalTeardown` de e2e escrito assim **nunca limpou um único registro** desde que
foi escrito, porque a suíte autenticada ficou travada em outro problema (token manual) por semanas
— quando o outro problema foi resolvido e o teardown finalmente rodou de verdade, todos os 6
recursos que ele tentava listar vieram 404.

**Solução:** não confie no `baseURL` do context pra rotas com `/` no início. Duas opções:
1. Sempre montar a URL absoluta na mão (`${API_BASE}${rota}`, concatenação de string simples) e
   não passar `baseURL` pro `newContext` — mais explícito, impossível de resolver errado.
2. Se quiser manter `baseURL`, garanta que ele termine em `/` E que toda rota NÃO comece em `/`
   (`baseURL: '.../api/v1/'` + `ctx.get('metas/')`) — mais frágil (fácil esquecer o `/` em um dos
   dois lados de novo no futuro), prefira a opção 1.

Diagnóstico rápido pra confirmar que é isso: reproduza fora do Playwright com `new URL(rota, baseURL).href`
num REPL de Node — se o resultado não contém o path do `baseURL`, é essa causa.

**Ref:** Família Milionária, sessão 2026-08-07 — implementação da conta E2E sintética
(`docs/superpowers/plans/2026-08-07-e2e-synthetic-account.md`, Task 7). `global-teardown.ts`
(rede de segurança que apaga dado `[E2E]` de produção pós-e2e) 404ava em TODAS as 6 listagens;
confirmado lendo o source de `playwright-core` + repro isolado em Node fora do test runner. Fix:
`familia-frontend/tests/e2e/global-teardown.ts` (commit `8105db1`), URLs absolutas.
