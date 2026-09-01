## `window.location`/`navigator` no CORPO de um componente `'use client'` quebra SSR {#window-location-no-corpo-de-use-client-quebra-ssr}

`tags: nextjs, use client, ssr, prerender, window is not defined, referenceerror, app router`

**Sintoma:** um componente `'use client'` (Next.js App Router) lê `window.location.origin` (ou
qualquer outra API só-de-browser) direto no CORPO da função — não dentro de um `useEffect`, não
dentro de um handler de evento. `tsc` passa limpo, os testes RTL/vitest passam (jsdom já injeta
`window`), o componente PARECE certo. Em produção, qualquer página que renderiza esse componente no
server (SSR ou prerender do App Router) quebra com `ReferenceError: window is not defined` — mesmo
sendo `'use client'`.

**Causa raiz:** `'use client'` não significa "nunca roda no servidor" — significa "este componente
também roda no browser" (hidrata). O Next.js App Router ainda faz **1 passagem de SSR/prerender no
servidor** pra gerar o HTML inicial de QUALQUER página, `'use client'` incluído. `window`/`navigator`
não existem nesse ambiente Node — só existem depois da hidratação, no browser de verdade.

**Por que passa despercebido:** jsdom (o ambiente dos testes) já injeta um `window` global fake, então
`npx vitest run` nunca reproduz o erro. `tsc` também não pega — `window.location.origin` é
type-válido. O único jeito de pegar isso antes de produção é review de código (humano ou LLM) ou
testar a página renderizando de verdade no servidor.

**Fix:** mover QUALQUER leitura de `window`/`document`/`navigator` (fora de handlers de evento) pra
dentro de: (a) um handler de clique/evento (só roda em resposta a interação do usuário, sempre no
client), ou (b) um `useEffect` (só roda depois do mount no client, nunca durante SSR). Nunca deixar
essas leituras no corpo direto da função do componente, mesmo que ele já tenha `'use client'` no
topo.

**Exemplo do bug** (`task-detail-header.tsx`, achado por review R11 antes do deploy — Plexco Tasks,
2026-09-01):
```tsx
'use client'
export function TaskDetailHeader({ task }) {
  // QUEBRA SSR: roda no server render, window nao existe
  const taskLink = `${window.location.origin}/projects/${task.projectId}?task=${task.id}`

  function handleCopyLink() {
    navigator.clipboard.writeText(taskLink)
  }
  ...
}
```
Fix: mover o `window.location.origin` pra dentro de uma função helper chamada DENTRO do handler:
```tsx
function getTaskLink() {
  return `${window.location.origin}/projects/${task.projectId}?task=${task.id}`
}
function handleCopyLink() {
  navigator.clipboard.writeText(getTaskLink()) // so roda em resposta a clique
}
```

**Como confirmar que o fix funcionou:** o teste unitário sozinho não prova (jsdom mascara o
problema) — precisa a página carregar de verdade em produção (ou `next build && next start` local)
sem `ReferenceError` no log do servidor.
