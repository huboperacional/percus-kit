## Pesquisa externa: "não achei" ≠ "não existe", e quase nunca é o layout mobile {#nao-achei-nao-e-nao-existe-em-pesquisa-web}

tags: pesquisa, concorrente, scraping, preco, mobile, desktop, user agent, sitemap, 403, benchmark, mercado

**Sintoma.** Um levantamento de concorrentes volta com muitos "não publica preço" e "não tem a
feature". A hipótese natural é que o layout **mobile** esteja escondendo conteúdo (acordeão fechado,
tabela truncada), e a correção óbvia é refazer tudo forçando desktop.

**Causa raiz — a hipótese do mobile é FALSA, e foi medida.** Baixando as MESMAS URLs com UA mobile
e UA desktop e comparando o texto: **delta de 0% em 5 de 6 sites**; o único delta (2,1%) era menu de
navegação, sem preço. Acordeão fechado é CSS — o conteúdo sempre vem no HTML. E só **1 de 15** alvos
devolvia 403 de verdade.

**As 4 causas reais, em ordem de frequência:**

1. **URL errada.** `/planos` dá 404 e a real é `/home/planos/`; ou é `/plano` **no singular**. Sozinha,
   essa causa transformou "preço só existe em review de terceiro" em preço oficial confirmado.
2. **Landing vertical fora do sitemap.** A home e a página-mãe de funcionalidades têm ZERO menção à
   feature; ela só existe na página de segmento, alcançável apenas pelo nav. Sitemap quebrado
   (1 entrada, `lastmod` de 3 anos atrás) é comum e faz o crawl inteiro passar ao largo.
3. **Slug enganoso.** Varra o **texto** por `R$`/`$`, não o nome da URL: uma tabela de preço por
   terminal vivia em `/smart-pos/`, e o sitemap de 2.752 URLs não tinha nenhuma página de preços.
4. **Domínio morto ou errado.** Um `.com.br` redirecionava para **um arquivo PNG**; dois outros eram
   NXDOMAIN (o real era `.com`). **4 de 19 alvos não eram sequer avaliáveis** — e nenhum veredito
   anterior sobre eles significava coisa alguma.

**E leia o que RENDERIZA, não só o texto.** Três armadilhas medidas: ✓/✗ escritos como
`<i class="icon-check">` **somem** na extração de texto (produz "não tem" falso); uma página carrega
7 preços no DOM dos quais **só 2 renderizam** (produz preço falso); e um domínio que usa `/<slug>`
para storefront devolve **HTTP 200 com um cardápio de restaurante** em `/planos` — um regex de `R$`
ali inventa preço com aparência de fato.

**Solução de processo.** Antes de escrever "não publica" ou "não tem": tente as variantes de URL,
entre pelas landings de segmento (não só pelo sitemap), varra o texto por moeda, confirme que o
domínio existe. E **separe sempre "não achei" de "não existe" no relatório** — a diferença é o valor
inteiro do levantamento. Uma afirmação estratégica publicada com base num "não achei" precisou de
correção pública no mesmo dia.

**Ref:** tiatendo, 2026-08-16 (pesquisa de precificação, 60+ concorrentes; re-verificação com
controle mobile×desktop).
