## Estreitar a janela do desktop NÃO prova mobile — sem `<meta viewport>` a página renderiza a 980px e encolhe {#estreitar-a-janela-nao-prova-mobile-sem-meta-viewport}

`tags: responsivo, mobile, viewport, meta viewport, doctype, quirks mode, revisao visual, devtools, emulacao de dispositivo, falso verde, R23`

**Sintoma:** a página foi revisada "em 375px", as media queries disparam, o layout empilha bonito, o
screenshot fica perfeito — e **no celular de verdade o site aparece inteiro, minúsculo, com texto
ilegível**. Ninguém entende, porque a revisão passou.

**Causa raiz:** existem **duas larguras diferentes** e a revisão mediu a errada.

- Ao **estreitar a janela do desktop**, a viewport CSS acompanha a janela. A 375px de janela, a
  viewport é 375px, `@media (max-width:560px)` dispara, e tudo parece certo.
- No **celular**, sem `<meta name="viewport">`, o navegador assume a *viewport layout* padrão de
  **980px**, renderiza a página nessa largura e depois **encolhe a imagem inteira** para caber na
  tela. As media queries de mobile **nunca disparam**, porque para o CSS a viewport tem 980px.

O defeito é invisível justamente no método de revisão mais comum. Um `document.documentElement.
scrollWidth <= window.innerWidth` também passa, porque os dois valores são 980.

**Como detectar em um comando:** dentro da página, com emulação de dispositivo ligada:

```js
window.innerWidth  // 980 => falta o meta viewport. ~375 => ok
document.compatMode // "BackCompat" => quirks mode, falta o doctype
```

`window.innerWidth === 980` com o dispositivo emulado a 375px é a assinatura exata do defeito.

**Correção — duas linhas, e as duas importam:**

```html
<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
```

O `<meta viewport>` resolve o encolhimento. O `<!doctype html>` tira a página do **quirks mode**
(`compatMode === "BackCompat"`), onde o modelo de caixa e a herança de `line-height` em tabela mudam
de comportamento. São defeitos independentes que costumam andar juntos, porque quem esqueceu um
esqueceu o outro.

**Regra de revisão:** protótipo em HTML solto (fora de framework) **não tem** essas linhas por
padrão — nenhum boilerplate as injeta. Antes de aprovar responsividade, **emule o dispositivo**
(`Emulation.setDeviceMetricsOverride`, ou o modo dispositivo do DevTools) em vez de arrastar a borda
da janela, e confirme `window.innerWidth` no valor esperado. Redimensionar a janela responde
"o CSS está certo?"; só a emulação responde "o celular vai ver isso?".

Relacionado: [[o-screenshot-pega-o-que-a-guarda-nao-ve]].
