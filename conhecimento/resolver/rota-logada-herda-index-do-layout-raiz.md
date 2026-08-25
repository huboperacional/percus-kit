## Tela logada pede indexação porque `'use client'` não exporta `metadata` {#rota-logada-herda-index-do-layout-raiz}

`tags: SEO, noindex, robots, metadata, Next.js, App Router, use client, layout raiz, canonical, robots.txt, Disallow, barra final, trailing slash, area logada, admin indexavel, maxRedirects, guarda que segue redirect`

**Origem:** Empresa Milionária, 2026-08-25 — medido em produção logo depois de um deploy, ao
conferir os sinais de indexação de outra correção.

**Sintoma:** rotas de área logada respondem **200** declarando `<meta name="robots"
content="index, follow">`, com `canonical` e `<title>` **da home**. No caso medido eram
**19 rotas**, uma delas `/admin`. Nada acusa: não aparece na tela, no `tsc`, no build nem no
console. O `robots.txt` parece cobrir e não cobre.

**Causa raiz — duas, e as duas silenciosas:**

1. **`'use client'` não pode exportar `metadata`.** No App Router, `metadata` só existe em
   módulo server. Uma `page.tsx` client não declara nada, e a rota **herda o `robots` do layout
   raiz** — que num produto com landing é `index, follow`. Não é descuido de ninguém: escreveram
   a landing, e as telas herdaram a decisão dela.

2. **`Disallow: /admin/` não casa com `/admin`.** A regra com **barra final** só casa com o que
   começa por `/admin/`; a URL que o framework serve é `/admin`, sem barra.

📌 **E mesmo casando, `Disallow` não resolveria** — ele impede o **crawl**, e impedir o crawl
impede justamente a leitura do `noindex` que tiraria a página do índice. URL bloqueada por
`robots.txt` ainda pode aparecer no índice, sem descrição, se houver link para ela. **O sinal
que resolve é o `meta robots`, na página.** Depois de pôr `noindex`, o `Disallow` da mesma rota
passa a atrapalhar: remova um ou outro, nunca os dois juntos.

**Solução:**

1. `layout.tsx` **server** por rota, aditivo, só com o `robots`:
   ```tsx
   export const metadata: Metadata = { robots: { index: false, follow: false } }
   export default function Layout({ children }) { return <>{children}</> }
   ```
2. **Rota cujo layout já é client** (o típico: o layout faz o redirect de sessão) — extraia o
   corpo para um componente client irmão e deixe o layout server envolvendo-o. Comportamento
   idêntico, e é a única forma de a rota poder declarar `metadata`.
3. **Route group** (`(pf)/`) resolve com um arquivo só — mas exige `git mv` das pastas. **Em
   repo com sessões concorrentes na mesma árvore, prefira os layouts aditivos:** mover pasta que
   outra sessão está editando é conflito garantido.
4. **O desenho correto é o inverso** — layout raiz `noindex`, públicas abrindo por exceção
   ("fechado por padrão"). Só faça com guarda dos dois lados no lugar: errar uma pública tira a
   landing do buscador, e o dano só aparece dias depois.

**A guarda, e ela tem uma armadilha própria:**

Varra as rotas **lidas do disco** (`src/app/`) menos as do **`sitemap.xml` real** — nenhuma das
duas listas digitada, senão a guarda envelhece calada e tela nova nasce indexável.

⚠️ **Use `maxRedirects: 0`.** Sem isso a guarda segue o redirect, lê o `meta robots` do
**destino** e o atribui à **rota de origem**. Aconteceu na primeira execução: uma rota que
responde **308** (correta) foi acusada de pedir indexação, com o `index, follow` que era da
home. **Guarda que segue redirect mede a página errada** — vale igual para `canonical`, `og:*`
e `hreflang`. Trate 3xx como 404: quem responde ao buscador é outra URL.

Relacionado: [pipe-mascara-o-codigo-de-saida](pipe-mascara-o-codigo-de-saida.md) — o placar
desta guarda foi lido de um `| tail` e voltou `exit code 0` sobre um teste que falhava.
