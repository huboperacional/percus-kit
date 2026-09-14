## Conferir tela do Next por `fetch` + `DOMParser` acusa erro e alerta que não existem {#conferencia-por-html-conta-o-anunciador-do-next-e-o-404-embutido}

`tags: next.js, app router, rsc payload, DOMParser, textContent, innerText, role=alert, next-route-announcer, falso positivo, smoke test, playwright, conferencia`

**Sintoma 1:** um smoke test busca o HTML de cada tela com `fetch`, e procura
`/Unhandled Runtime Error|Application error|This page could not be found/`. Resultado: **as seis
telas deram "erro"**, todas com status 200 e o `h1` certo.

**Causa:** o App Router embute no payload RSC, dentro de `<script>`, o título do not-found
(`404: This page could not be found.`) em **toda** página. E o documento do `DOMParser` não tem
layout: `innerText` não existe, e o `textContent` do body inclui o texto dos scripts.

**Sintoma 2:** na página viva, a contagem de `[role=alert]` tem **um a mais** do que o HTML servido.
Um "2 → 1 alertas" parecia sobra de aviso de erro, e era o `next-route-announcer` do Next.

**Correção:**
- procure erro por marcador de interface — o `h1` esperado, o overlay `nextjs__container_errors` — ou
  pelo status HTTP, nunca por texto solto do HTML;
- compare contagens contra **a mesma página sem a condição** (a linha de base), não contra zero. No
  caso: sem `?erro=` o HTML tinha 0 alertas; com ele, 1; na página viva, cada um mais o anunciador.

**Ref:** LiliCalc, conferência dos botões de envio (2026-09-14).
