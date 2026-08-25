## Clique não dispara em `/dev-preview` sob Playwright — verifique se o React hidratou ANTES de suspeitar do código {#clique-nao-dispara-em-dev-preview-verifique-hidratacao-antes-do-codigo}

`tags: playwright, dev-preview, next.js, turbopack, hidratacao, hmr, websocket, click, onclick, evento-nao-dispara, react-devtools-hook, mcp-playwright, R23`

**Sintoma:** um botão/div `onClick` numa página `"use client"` (rota `/dev-preview/...`) não reage a
clique nenhum via MCP Playwright — nem `browser_click` na accessibility name, nem `element.click()`
via `browser_evaluate`, nem trocar `<div role="button">` por `<button>` real muda o resultado. O
console mostra só `WebSocket connection to '.../_next/webpack-hmr...' failed:
net::ERR_INVALID_HTTP_RESPONSE`, repetido em loop, sem erro de compilação e sem warning de
hidratação. A página RENDERIZA certo visualmente (screenshots saem corretos).

**Causa raiz:** em alguns ambientes sandboxed, o handshake do WebSocket de HMR do Turbopack falha
persistentemente contra o dev server local — e, no mesmo processo, o React **nunca hidrata** a
árvore (o HTML servido pelo SSR fica como está; nenhum listener de evento é anexado). O
`react-devtools` global hook ainda é injetado (por isso a mensagem "Download the React DevTools"
aparece no console), mas nenhum *renderer* se registra nele. Como a hidratação falha SEM lançar
warning nem erro visível — só o WS de HMR reclama, e isso já é ruído esperado neste tipo de
ambiente —, a suspeita natural cai sobre o próprio markup (`role="button"` em vez de `<button>`,
`stopPropagation` num link aninhado, z-index) quando na verdade nada no código está errado.

**Diagnóstico (confirma em 1 chamada, sem editar código):**

```js
() => {
  const hook = window.__REACT_DEVTOOLS_GLOBAL_HOOK__;
  const renderers = hook ? Array.from(hook.renderers?.values?.() || []) : [];
  const root = document.querySelector('main') || document.body.firstElementChild;
  return {
    temHook: !!hook,
    qtdRenderers: renderers.length,          // 0 = React nunca montou
    rootTemFiber: root ? Object.keys(root).some(
      k => k.startsWith('__reactFiber') || k.startsWith('__reactContainer')
    ) : false,                                // false = nenhum nó tem o React como dono
  };
}
```

`temHook: true` + `qtdRenderers: 0` + `rootTemFiber: false` = confirmado — é ambiente, não código.
Se `qtdRenderers > 0`, a causa é outra (aí sim suspeite do markup).

**Solução:** não há correção de código a fazer. Mate o processo do dev server (`Stop-Process` na
porta) e suba de novo — às vezes limpa; se persistir, é limitação estrutural do ambiente/proxy de
rede entre o browser controlado e o dev server, e a verificação de interatividade tem que sair da
sessão automatizada: peça pro operador testar o link ele mesmo no navegador real dele. Trate
screenshots deste ambiente como prova de **layout**, nunca de **interação**.

**Ref:** achado 2026-08-25, sessão Paid Media Automation, ao montar um mockup DRE em
`web/src/app/dev-preview/reuniao-colunas/page.tsx` — dois redesenhos de `<div role="button">` para
`<button>` nativo não mudaram nada até este diagnóstico apontar a causa real.
