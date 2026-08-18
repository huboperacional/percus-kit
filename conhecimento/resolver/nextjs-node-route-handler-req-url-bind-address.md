## Rota Next.js (Node runtime) atrás de Traefik redireciona pra `0.0.0.0:PORT` em vez do host público {#nextjs-node-route-handler-req-url-bind-address}

`tags: next.js, output standalone, route handler, req.url, NextResponse.redirect, Traefik, reverse proxy, Docker Swarm, Edge Runtime vs Node runtime, NEXT_PUBLIC_SITE_URL`

**Contexto:** Route Handler App Router tipado com `Request`/`NextResponse` puro (não `NextRequest` —
house style deste codebase pra handlers Node-runtime), construindo um redirect relativo:
`NextResponse.redirect(new URL(caminho, req.url), {...})`. Deploy real: `output: standalone`, Docker
Swarm, Traefik na frente fazendo host-based routing.

**Sintoma:** em produção, o `Location` do redirect vinha `https://0.0.0.0:3000/...` — endereço interno
do bind do container, inatingível por qualquer client externo (imagem quebrada/redirect falho no
navegador). Em dev local (`next dev`, sem proxy) o mesmo código funcionava perfeitamente — só se
manifesta atrás de reverse proxy em produção, o que faz esse bug escapar de toda review de código e de
toda suíte de teste (`new Request('http://x/...')` nos testes sempre resolve `req.url` pro host de teste
fornecido, nunca reproduz o bind address real).

**Causa raiz:** `req.url` num Route Handler **Node-runtime** (`export const runtime = 'nodejs'`) não é
garantido refletir o `Host`/`X-Forwarded-Host` da requisição original quando o app roda via
`output: standalone` atrás de um proxy — pode resolver pro endereço/porta que o próprio servidor Node
escuta. Isso é diferente de `NextRequest` no **Edge Runtime** (ex.: `middleware.ts`), que reconstrói a
URL a partir dos headers encaminhados corretamente — um redirect idêntico (`new URL(caminho, req.url)`)
no middleware funciona sem problema; o mesmo padrão numa Route Handler Node-runtime não.

**Solução:** nunca resolver um redirect relativo contra `req.url` numa Route Handler Node-runtime que
roda atrás de proxy em produção. Usar uma env var pública fixa como base
(`process.env.NEXT_PUBLIC_SITE_URL ?? 'https://dominio-real.com'`) — o mesmo padrão que outras rotas do
mesmo projeto (`app/api/checkout/route.ts`) já usavam, precisamente por essa razão. Ao portar esse
padrão pra uma rota nova, greppar o codebase por `req.url` vs. `NEXT_PUBLIC_SITE_URL` nas rotas
irmãs ANTES de escrever a nova, em vez de reinventar.

**Como pegar isso ANTES de produção:** a suíte de testes não pega (constrói `Request` com host de teste
fixo). O jeito de achar é testar contra o deploy real pós-build: `curl -sD - <url> | grep -i location` e
conferir que o host do `Location` bate com o domínio público, não com `0.0.0.0`/`127.0.0.1`/porta
interna. Se o projeto tem um passo de verificação manual pós-deploy (tipo um ciclo `[5-T]`), incluir
essa checagem de redirect ali é mais barato que descobrir com um cliente reportando imagem quebrada.

**Ref:** ads4agencies-site, painel de admin AutoWorx, Task 19 (verificação pós-deploy), sessão
2026-08-06 — `app/api/asset/photo/[slotId]/route.ts`, achado ao vivo via `curl -D-` contra
`https://ads4agencies.com`, fix commit `002a233`, redeploy `v38→v39`.
