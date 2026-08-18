## Última página do path terminar em dígito é assinatura estrutural de "página de detalhe de catálogo" — genérico, não depende do CMS {#url-trailing-digit-catalog-detail-page}

tags: url pattern, deteccao generica, pagina de produto, pagina de imovel, catalog detail page,
agrupar paginas, page-flow, heuristica sem hardcode de dominio, praedium, wordpress, shopify

**Contexto:** grafo/lista de páginas navegadas por sessão (Fluxo de Páginas) tinha uma "cauda longa"
de páginas de ficha-de-produto/imóvel poluindo a visualização (274 páginas distintas, a maioria com
1-2 sessões cada). Pedido explícito do operador: "não hardcode pro CMS específico (Praedium) — tem
que identificar sozinho". Confundir isso com o problema geral de "cauda longa de baixo tráfego" (que
já tinha solução própria, agrupamento por peso) seria perder a informação de que essas páginas são
TODAS da MESMA categoria estrutural (fichas de um catálogo), não só "baixo tráfego disperso".

**Causa raiz / por que dá pra generalizar:** qualquer catálogo paginado (CMS de imóveis, e-commerce,
diretório) cedo ou tarde precisa de um identificador único por item na URL — e o jeito mais comum de
resolver isso, INDEPENDENTE da stack (WordPress, Shopify, Praedium, Next.js customizado), é sufixar o
slug com um ID numérico (`...-id-2001`, `.../product/123`, `.../p2001`). Páginas de LISTAGEM/filtro do
mesmo site, em contraste, quase sempre terminam em palavra (`3-quartos`, `ate-750-mil`, `mais-vendidos`)
porque são compostas de filtros humanos, não de uma chave primária de banco.

**Solução:** heurística estrutural de uma linha, sem tabela de exceção por CMS:

```ts
function isCatalogDetailPage(label: string): boolean {
  return /\d+\/?$/.test(label); // último segmento do path termina em dígito
}
```

Valide contra o dado real do tenant antes de confiar: agrupe por primeiro segmento do path entre os
matches — se 100% caem sob o MESMO segmento raiz (ex. todos sob `/imovel/...`), é sinal forte de que a
heurística achou o padrão certo, não ruído. Rode também o caminho negativo: liste os labels que TÊM
algum dígito mas NÃO batem na regex (ex. `ate-750-mil`) — se nenhum desses vira falso-positivo, a
heurística está discriminando path-de-filtro vs path-de-registro corretamente.

**Ref:** Paid Media Automation, sessão 2026-08-07 (cont.158). Validado contra 274 páginas reais da
Imobiliária Uni: 177 matches, 100% sob `/imovel/...`, zero falso-positivo nas páginas de filtro
(`web/src/app/dev-preview/page-flow/page.tsx`, `isCatalogDetailPage`).
