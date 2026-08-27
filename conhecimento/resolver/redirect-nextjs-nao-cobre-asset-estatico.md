## Redirect do Next.js despublica a página, não o arquivo estático que ela referenciava {#redirect-nextjs-nao-cobre-asset-estatico}

`tags: nextjs, next.config.js, redirects, public, static assets, despublicacao, SEO, brand leak, og:image, App Router`

**Contexto:** um conteúdo público foi despublicado via `redirects()` do `next.config.js`
(`{ source: '/blog/post-x', destination: '/', permanent: true }`), com teste e2e provando que a
URL da página redireciona corretamente. Uma semana depois, dois arquivos PNG referenciados de
dentro daquele post (`public/blog/mockups/*.png`) continuavam respondendo **200** por URL
direta — com conteúdo obsoleto/de marca errada visível pra quem tivesse o link ou o encontrasse
via cache de busca de imagens.

**Causa raiz:** `redirects()` casa contra o **caminho declarado no `source`**, path a path.
Nenhuma entrada da lista apontava para `/blog/mockups/*.png` — só para a página HTML e seus
slugs. Arquivo estático sob `/public` é servido pelo Next.js **independente** do roteamento de
página; ele só para de responder se o próprio arquivo for removido, ou se existir uma entrada de
`redirects()`/`rewrites()` que bata exatamente com aquele caminho.

**Por que ninguém viu antes:** o teste que prova a despublicação testa a **página** (`page.goto`
→ verifica `pathname` final), nunca o asset cru. `grep`/`toContain` também não pegam — o
vazamento não estava em texto de HTML nenhum, estava dentro de bytes de imagem. A guarda mais
óbvia (rodar o mesmo teste de redirect na URL do asset) só existe se alguém pensar em escrever
especificamente para essa classe de arquivo.

**Diagnóstico:**
1. Listar todo `<img src>` / referência de asset dentro do conteúdo que foi despublicado —
   `grep -rnE '\.(png|jpg|webp)"' <arquivo-de-conteudo>`.
2. Pra cada um, `GET` direto no caminho (`curl -I` ou `request.get` num teste) e conferir o
   status — **não** navegar pela página que o referenciava, que já está redirecionada.
3. Se responder 200, o arquivo está no `/public` e nenhuma entrada de `redirects()` cobre aquele
   caminho especificamente.

**Fix:** apagar o arquivo (se não houver reaproveitamento futuro) ou adicionar uma entrada de
`redirects()`/`rewrites()` que cubra o caminho exato do asset. Guarda de regressão: teste que
faz `GET` direto no caminho do asset e espera 404 — prova que o arquivo foi de fato removido, não
só desreferenciado.

**Ref:** Empresa Milionária, 2026-08-26 — mockups do WhatsApp com nome do produto de origem
sobreviveram ao despublicamento do post que os usava.
