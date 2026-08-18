## CSS Grid `auto-fit` estica item único/par pra largura total quando sobram poucos itens {#css-grid-autofit-estica-item-unico}

`tags: CSS Grid, auto-fit, auto-fill, minmax, galeria, grid-template-columns, layout quebrado`

**Contexto:** ads4agencies-site, sessão 2026-08-04, `WTV2ProofGallery.tsx` (galeria "More From Our
Shop" de cada subpágina de serviço) — quando sobravam só 1-2 fotos depois de tirar a 1ª pro slot de
destaque, a foto restante renderizava ocupando a largura INTEIRA do container (ou 2 fotos gigantes),
parecendo foto quebrada, não "grid com poucas fotos". Reportado 2x pelo operador na mesma sessão
("já te expliquei").

**Causa raiz:** `grid-template-columns:repeat(auto-fit,minmax(Npx,1fr))` — `auto-fit` colapsa as
colunas implícitas VAZIAS (as que caberiam mas não têm conteúdo) e redistribui o espaço delas pras
colunas que TÊM conteúdo, porque o `1fr` do `minmax` reparte o espaço livre entre as faixas que
sobram. Com 6 colunas cabendo e só 1 item real, as outras 5 colapsam e a 1ª cresce pra ocupar as 6.
`auto-fill` faz a mesma conta de quantas colunas cabem, mas NÃO colapsa as vazias — ficam lá sem
conteúdo, o item real fica no tamanho normal, sobra espaço em branco ao lado.

**Sinal de alerta pra generalizar:** qualquer `repeat(auto-fit,minmax(...,1fr))` aplicado a um grid
cujo número de itens VARIA e pode legitimamente ser 1 (ex.: lista derivada tirando a 1ª entrada pro
slot de destaque) é candidato — testar especificamente o caso de 1 item antes de considerar pronto.

**Solução:** trocar `auto-fit` → `auto-fill` quando a intenção é "cada item no tamanho normal, não
importa quantos couberem" (típico de galeria/proof-gallery). Manter `auto-fit` só quando a intenção
REALMENTE é "os itens existentes devem crescer pra preencher a largura toda" (ex.: grid de cards de
preço onde 3 cards devem ocupar a largura inteira igualmente).

**Ref:** ads4agencies-site, `WTV2ProofGallery.tsx`, sessão 2026-08-04 (AutoWorx v2).
