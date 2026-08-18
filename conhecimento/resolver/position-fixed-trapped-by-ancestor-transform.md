## `position: fixed` renderiza preso dentro de um card em vez da viewport inteira {#position-fixed-trapped-by-ancestor-transform}

`tags: CSS, position fixed, containing block, transform, lightbox, modal, overlay, portal, createPortal, React, hover transform`

**Contexto:** um lightbox/modal de foto (`position: fixed; inset: 0`) renderizado como filho direto
de um card que tem `transform` no `:hover` (`.admin-card:hover { transform: translateY(-2px); }` —
efeito comum de "levantar" o card ao passar o mouse). Clique na miniatura abre o overlay.

**Sintoma:** ao abrir o lightbox com o mouse ainda em cima da miniatura (cenário normal — o clique
que abre o overlay deixa o cursor exatamente ali), o overlay de tela cheia renderizava PRESO dentro
da caixa do card, não cobrindo a viewport — como se `position: fixed` tivesse virado
`position: absolute` relativo ao card.

**Causa raiz:** é exatamente isso que acontece. Qualquer ancestral com `transform` (ou `filter`,
`perspective`, `will-change: transform`, `contain: layout/paint`) ATIVO no momento vira um novo
"containing block" pra descendentes `position: fixed` — eles passam a ser posicionados relativos a
esse ancestral, não à viewport. Como o `:hover` do card ainda está ativo (cursor não saiu da
miniatura), o `transform` está aplicado exatamente quando o overlay tenta abrir.

**Solução:** renderizar o overlay via `createPortal(overlay, document.body)` (React) em vez de deixá-lo
como filho normal da árvore — isso tira o elemento do DOM subtree do card por completo, imune a
qualquer `transform`/`filter` de qualquer ancestral, presente ou futuro. Não dá pra resolver só
tirando o `transform` do hover (perderia o efeito visual) nem só mudando `position` (é o comportamento
correto do CSS, não um bug de valor errado).

**Como pegar isso antes de declarar pronto:** testar abrindo o overlay com o mouse ainda sobre o
elemento que o disparou (não mover o mouse pra fora antes de clicar) — é exatamente esse o caminho
que reproduz o bug; testar só com screenshot pós-clique-e-mouse-longe pode passar batido.

**Ref:** ads4agencies-site, redesign do painel de admin AutoWorx, sessão 2026-08-06 — feature de
lightbox de foto pedida ao vivo pelo operador, `components/admin/PhotoFieldCard.tsx`, achado
imediatamente no primeiro teste ao vivo via Playwright screenshot.
