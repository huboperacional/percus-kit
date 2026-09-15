## Print "em 1440 px" saiu com a tela errada: o zoom do navegador divide a viewport emulada {#zoom-do-navegador-muda-a-largura-medida-no-devtools}

`tags: chrome devtools mcp, emulate, resize_page, viewport, innerWidth, zoom, devicePixelRatio, print responsivo, 1440, 900, 390, largura css`

**Sintoma:** `resize_page`/`emulate` pedem 1440 px, mas o layout do print não bate com 1440; `innerWidth`
mede 1309. Em outra rodada, com a janela maximizada, `resize_page` recusa ("Restore window to normal state").

**Causa:** o navegador do operador estava com zoom de 110% (`devicePixelRatio` ≈ 1,1). A emulação define
pixels do dispositivo; a largura CSS vira `largura / 1,1`.

**O que fazer:** antes de qualquer print, meça `innerWidth` e `devicePixelRatio` com `evaluate_script`.
Compense na emulação: para 1440 CSS peça ~1584; para 900, ~990. Para mobile (`390x844x2,mobile,touch`) a
emulação já dá a largura CSS certa. Registre no relatório a largura MEDIDA, não a pedida, e verifique
`document.documentElement.scrollWidth <= innerWidth`. Ao terminar, limpe a emulação (`emulate` sem
`viewport`) — o navegador é o do operador.
