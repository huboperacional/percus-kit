## Canonical absoluto no layout do Next desindexa TODAS as rotas filhas {#next-canonical-layout-herdado}

`tags: next.js, app router, metadata, canonical, alternates, hreflang, seo, desindexacao, layout, heranca, openGraph, i18n, next-intl`

**Contexto:** portal Next (App Router) com varias rotas. Todas serviam `<link rel="canonical" href="https://dominio.com">` -- a RAIZ -- inclusive `/platform`, `/investors`, `/portfolio` e os equivalentes de outro locale. Efeito: cada rota diz ao Google que e' **duplicata da home**, e some do indice em favor de `/`.

**Causa raiz:** o `layout.tsx` declarava `alternates: { canonical: "https://dominio.com" }` como string ABSOLUTA. Metadata de layout no App Router e' **herdada** por toda pagina que nao sobrescreve -- e nenhuma pagina sobrescrevia. Mesmo defeito no `openGraph.url`. Como bonus, nenhuma rota emitia `hreflang`.

**Solução:** o layout NAO declara canonical (so `metadataBase`); cada pagina declara o seu no `generateMetadata`, via helper unico que tambem gera o `languages` (hreflang):
```ts
export const alternatesFor = (locale: string, path = "") => ({
  canonical: absoluteUrl(locale, path),
  languages: Object.fromEntries(routing.locales.map(l => [l, absoluteUrl(l, path)])),
});
```
Centralizar a regra de prefixo de locale num modulo so (`lib/seo.ts`): ela estava reimplementada em 3 lugares (sitemap, pagina de detalhe e implicitamente no layout), e foi essa dispersao que deixou o bug passar.

**Como verificar (o grep ingenuo mente):** o Next serializa o atributo como **`hrefLang`** (camelCase do JSX), entao `grep hreflang` case-sensitive da ZERO mesmo com a tag presente. Nome de atributo em HTML e' case-insensitive, entao esta correto -- use `grep -i`. Checar rota a rota:
```bash
for p in "" /platform /investors /pt/platform; do
  curl -s "https://DOMINIO$p" | grep -oiE '<link rel="canonical" href="[^"]*"'
done
```
Cada rota tem que devolver o canonical DELA, nao a raiz.

**Ref:** Micro Investors, `[5-T]` do F4 (2026-07-22) -- pego no smoke de SEO, dias depois de a pagina ir ao ar. Nenhuma review por-commit pegou: o layout estava "certo" isoladamente; o defeito so existe na HERANCA.
