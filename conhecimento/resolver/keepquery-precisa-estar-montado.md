## CTA novo pra path interno perde `gclid`/`fbclid`/`utm_*` porque `<KeepQuery/>` nunca foi MONTADO nessa página {#keepquery-precisa-estar-montado}

`tags: KeepQuery, tracking, ad params, gclid, fbclid, utm, data-attribute, contrato de 2 lados, Next.js`

**Contexto:** ads4agencies-site, sessão 2026-08-04, AutoWorx v2 — o CTA de fechamento de cada
subpágina de serviço, antes `tel:`, virou link interno `/quote?service=<nome>`. O componente que
renderiza o botão já marca `data-keep-query` corretamente (condicional em `href.startsWith('/')`),
mas o param de anúncio (`gclid`/`fbclid`/`utm_*`) sumia ao clicar. Achado por review Cross-Claude
(subagente independente) ANTES do deploy, não pelo autor original da mudança.

**Causa raiz:** `data-keep-query` é um MARCADOR, não o mecanismo — quem faz o trabalho de verdade é
o `useEffect` do componente `<KeepQuery/>` (`components/window-tint-v2/KeepQuery.tsx`) rodando na
PÁGINA, reescrevendo o `href` de todo `<a data-keep-query>` com os params da URL de entrada. É um
contrato entre DOIS lugares: o componente que renderiza o link (marca o atributo) e o componente no
topo da página (executa a reescrita). Adicionar um link novo com o atributo certo não implica que o
segundo lado existe naquela página específica — `<KeepQuery/>` não é provider/contexto global, cada
rota tem que montá-lo individualmente. O próprio arquivo já documentava a lacuna em comentário
("mounted only on Home/About/Contact/FAQ... has the same latent gap") — só não tinha virado ação até
o review pegar.

**Sinal de alerta pra generalizar:** qualquer padrão "atributo marcador + componente que faz o
trabalho de verdade em outro lugar da árvore" (não só KeepQuery) quebra em silêncio quando alguém
adiciona o marcador numa página nova sem saber que o componente executor também precisa estar
montado ali. Ao adicionar QUALQUER CTA/link novo apontando pra path interno numa página que antes
só tinha `tel:`/`mailto:`/links externos, confirmar que a página monta o componente executor do
contrato.

**Solução:** montar `<KeepQuery/>` na página nova se ainda não montava. Testar de verdade, não
confiar só em ler código: `browser_navigate` na página com `?gclid=test123` na URL,
`browser_evaluate` lendo o `href` real do link depois do JS rodar — o param tem que aparecer no
destino.

**Ref:** ads4agencies-site, `WTV2ServiceDetailPage.tsx`, sessão 2026-08-04. Achado por review
Cross-Claude antes do deploy.
