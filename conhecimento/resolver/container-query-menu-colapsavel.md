## Layout que depende de menu lateral colapsável: `@container`, não media query {#container-query-menu-colapsavel}

`tags: css, container query, container-type, inline-size, media query, menu lateral, sidebar colapsavel, largura util, preview mente, responsivo, layout`

Um componente precisava rearranjar-se quando ficava estreito. O reflexo é `@media (max-width: …)` —
e estaria **errado metade das vezes**: a tela tinha menu lateral de largura variável (68px recolhido
/ 248px expandido). Com o menu aberto a 1920 o componente é mais estreito do que com o menu fechado a
1280, mas a media query enxerga só a janela e responde igual nos dois casos.

**Regra:** quando a largura útil do componente depende de algo que não é a janela (menu colapsável,
painel lateral, split view), o gatilho é `container-type: inline-size` no ancestral + `@container`.
A pergunta que decide: *"a largura deste componente muda sem a janela mudar?"* Se sim, media query
é a ferramenta errada.

**Ao medir o resultado, simule a casca real** (menu + conteúdo) no preview. Um preview que renderiza
o componente solto numa página de 1800px mente sobre a largura da coluna — e foi o que fez a primeira
rodada ser aprovada no preview e recusada na tela.

Visto em: tiatendo, 2026-07-28 (card do quadro de pedidos, `0.257.0`).
