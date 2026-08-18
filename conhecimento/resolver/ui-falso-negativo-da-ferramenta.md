## Verificar UI: o que "não aparece" no screenshot pode ser artefato da ferramenta, não bug (Micro Investors F2) {#ui-falso-negativo-da-ferramenta}

`tags: playwright, fullPage, screenshot, falso negativo, DOM, naturalWidth, getBoundingClientRect, tailwind v4, turbopack, chunk css, IACVT, var indefinida, canal alpha, png`

Três falsos-negativos numa sessão só, todos do mesmo tipo — **o instrumento mentiu, não o código**:

- **`fullPage: true` do Playwright distorce `position:absolute` + `mask-image`.** Uma foto no hero
  (absolute, com máscara em gradiente) **sumiu** do screenshot fullPage em prod e quase virou "bug de
  deploy". A prova real veio do **DOM**: `img.complete=true`, `naturalWidth=669`, `getBoundingClientRect`
  visível — e o screenshot de **viewport** mostrou a imagem. **Regra:** antes de declarar "não renderiza",
  cheque o DOM (complete/naturalWidth/rect/display computado); use fullPage pra composição geral, nunca
  como prova de que um elemento posicionado existe.

- **Tailwind v4 + Turbopack fragmenta o CSS em vários chunks no DEV.** Procurar `.bg-navy` no chunk que
  o `<link>` aponta e não achar NÃO significa que o utilitário não foi gerado (nem `.bg-primary` estava
  lá). **Verifique no CSS de PRODUÇÃO** (`.next/static/chunks/*.css` após o build) — é o que vai pro deploy.

- **Classe gerada ≠ classe que pinta.** `.bg-navy{background-color:var(--navy)}` só funciona se `--navy`
  existir no CSS servido; `var()` de variável indefinida invalida a declaração inteira (IACVT) e a regra
  vira no-op silencioso — o mesmo mecanismo que já derrubou a fonte pro Times New Roman neste projeto.
  **Verifique o PAR: a regra E a variável.**

- **Bônus (imagem):** um PNG que "parece ter fundo bege" pode ser recorte com alpha — a prévia compõe
  sobre fundo claro. Cheque o canal alpha (mapa de opacidade) ANTES de aplicar máscara/`multiply` pra
  "esconder o fundo": tratar um fundo que não existe só escurece o assunto.

**Ref:** Micro Investors F2 home (portal `v8`, 2026-07-18).
