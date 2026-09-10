## `"use client"` importando de um módulo server-only arrasta segredo (ou o build) pro bundle {#use-client-importando-modulo-server-only-vaza-pro-bundle}

tags: nextjs, app-router, client-server-boundary, review, seguranca

**Sintoma.** Um componente `"use client"` só precisa de um TYPE ou de uma função
pura (ex.: `formatarValor`) de um arquivo — mas esse arquivo TAMBÉM exporta a
função que faz a chamada de API (com token/segredo de env var). O import parece
inocente porque só se usa o pedaço puro.

**Por que morde.** O bundler do Next não faz tree-shaking por USO dentro do
arquivo importado antes de decidir o que entra no bundle do client — ele olha o
módulo inteiro. Se esse módulo lê uma env var sem prefixo `NEXT_PUBLIC_`
(`process.env.GOOGLE_ADS_DEVELOPER_TOKEN`, por exemplo) em qualquer ponto
alcançável, o Next pode: (a) recusar o build (proteção real contra vazar
segredo), ou (b) na pior hipótese de configuração, deixar passar e mandar
código server-only pro browser — peso morto na melhor hipótese, exposição de
lógica/segredo na pior.

**O fix — mesmo padrão que já existia no lado Meta deste projeto antes de eu
repetir o erro do lado Google:** separar em DOIS arquivos.
- `*-tipos.ts` (ou similar): só `type`/`interface` e funções PURAS (sem
  `import` de biblioteca de rede, sem `process.env`). É o que o componente
  `"use client"` importa.
- `*-busca.ts` (ou `-conta.ts`): a função que chama a API, lê env var, faz
  `fetch`. Só um Server Component (página `async`, Route Handler) importa
  daqui.

**Gate barato que trava a regressão:** um teste que lê o `.tsx` do componente
client como texto e afirma que ele **não** importa do módulo server-only —
mais confiável que confiar em revisão visual, porque quem adiciona um import
novo não necessariamente vai relembrar a regra.

```ts
const fonte = readFileSync("Componente.tsx", "utf8");
expect(fonte).not.toMatch(/from ["']\.\/modulo-server-only["']/);
```

**Caso real** (Paid Media Automation, D4U, 2026-09-10). `ArvoreGoogle.tsx`
(`"use client"`) importava `type`s e `microsParaValor` de `google-arvore.ts`,
que também exportava `lerContasGoogleD4U` (chama `runGaql`, OAuth, `fetch` com
`GOOGLE_ADS_DEVELOPER_TOKEN`). Achado em review R11 antes do deploy; corrigido
extraindo `google-tipos.ts` puro. O build (na VPS, real) passou depois da
separação — não foi testado o que teria acontecido sem ela.
