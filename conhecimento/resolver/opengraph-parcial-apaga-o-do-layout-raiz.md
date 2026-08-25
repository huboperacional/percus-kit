## `openGraph` parcial na página APAGA o do layout raiz — e o conserto de um campo derruba os irmãos {#opengraph-parcial-apaga-o-do-layout-raiz}

`tags: next.js, app router, metadata, openGraph, og:image, og:url, card de compartilhamento, seo, heranca, merge, objeto declarativo, regressao, whatsapp, conserto que quebra vizinho`

**Origem:** Empresa Milionária, 2026-08-25 — descoberto **um dia depois** de o defeito ser
introduzido pela correção de um campo vizinho.

**Sintoma:** compartilhar uma página no WhatsApp/LinkedIn/Facebook mostra card **sem imagem**.
Nada acusa: a página renderiza, o `tsc` passa, o build passa, e a guarda de SEO que existia
ficou **verde**.

**Causa raiz:** no App Router, `openGraph` declarado numa página **substitui o objeto inteiro**
do layout raiz — **não** mescla campo a campo. Declarar

```ts
openGraph: { url: `${BASE_URL}/termos` },   // só a url
```

apaga `images`, `type`, `locale`, `siteName` e tudo mais que o raiz declarava.

📌 **E o gatilho foi um conserto.** No dia anterior, seis rotas ganharam `openGraph.url` porque
o card mostrava a URL da home. O conserto funcionou e **derrubou os vizinhos**: 7 de 10 páginas
públicas perderam `og:image`, incluindo a de cadastro — a porta de conversão.

**Como se mede:** conte as tags, não confira uma. Uma página intocada servia **7** `og:`; a
"consertada" servia **3**.

```bash
curl -s https://dominio/rota | grep -o '<meta property="og:[a-z_]*"'
```

**Solução:** um **helper** que monta o objeto completo, e páginas que só passam o que muda:

```ts
export function ogDaPagina({ caminho, titulo, descricao }) {
  return { type: 'website', locale: 'pt_BR', siteName: '…',
           url: `${BASE_URL}${caminho}`, images: [{ url: '/og-image.png', width: 1200, height: 630 }],
           ...(titulo ? { title: titulo } : {}), ...(descricao ? { description: descricao } : {}) }
}
```

Quem só precisa trocar a `url` não deveria ter de **lembrar** de redigitar `images` — então não
redigita.

**A guarda tem de medir o CONJUNTO.** A que existia comparava `og:url` com `canonical`: media
**o campo consertado**, e o estrago estava ao lado. A nova exige `og:title`, `og:description`,
`og:image`, `og:type` e `og:site_name` em cada rota do `sitemap.xml` real.

🔑 **A lição maior, que vale além de SEO:** *conserto de um campo de objeto declarativo apaga os
irmãos.* Vale para qualquer merge raso — `openGraph`, `alternates`, `icons`, config de
biblioteca, objeto de tema. Depois de mexer num campo, **meça o objeto inteiro**, não o campo.

Relacionado: [next-canonical-layout-herdado](next-canonical-layout-herdado.md) — a face oposta,
em que o layout declara e a página **não** sobrescreve.
