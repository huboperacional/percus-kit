## `<title>` dentro de `<circle>`/`<path>` de um SVG causa hydration mismatch reproduzível {#svg-title-dentro-de-circle-path-quebra-hidratacao}

`tags: React, hydration mismatch, SVG, title, Next.js Server Component, tooltip, dataviz`

**Sintoma:** um gráfico SVG feito à mão (Server Component renderizando `<circle>`/`<path>` com um
`<title>` filho pra servir de tooltip nativo do navegador) dispara *"Hydration failed because the
server rendered HTML didn't match the client"* no console, reproduzível em navegação limpa (não é
falso-positivo de HMR/Fast Refresh) — medido via Playwright contra um dev server recém-reiniciado,
não só suspeitado.

**Causa:** não identificada com certeza (não é ausência de full-ICU do Node — testado, `Intl` local
formata `pt-BR` corretamente). O padrão comum aos dois gráficos que quebraram foi `<title>` como
filho direto de `<circle>`/`<path>` misturando texto literal e `{expressao}` — remover o `<title>`
elimina o mismatch nos dois casos.

**Como resolver:** não conte com hover nativo via `<title>` dentro de marca SVG num Server Component
Next.js — troque por rótulo `<text>` visível (mais adequado a relatório estático/impresso de
qualquer forma, que é o contexto onde isso apareceu: um relatório de cliente sem necessidade de
interação). Se precisar de tooltip de verdade, isole num Client Component com estado próprio
(`onMouseEnter`/`onMouseLeave` + elemento posicionado), não `<title>` puro. Sempre valide gráfico SVG
novo com Playwright contra um dev server limpo (não só o output do build) antes de considerar
pronto — o hydration mismatch só aparece no client, o build/tsc não pega.
