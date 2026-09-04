## Playwright MCP: clique em `ref` vira seletor CSS genérico e erra o alvo em silêncio, sem lançar erro {#playwright-mcp-click-silencioso-em-spa-react}

`tags: playwright, mcp, browser automation, spa, react, aria snapshot, ref stale, cursor-pointer, scraping autenticado, click silencioso, browser_evaluate`

**Contexto:** scraping/exploração de uma SPA React autenticada (grid de ~40 cards estruturalmente
idênticos, cada um com um `<div className="... cursor-pointer">` clicável e um `<h3>`/texto interno)
via ferramentas MCP do Playwright (`browser_click` com `target: <ref>` de um `browser_snapshot`
anterior). O clique **não retorna erro nenhum** — a chamada MCP responde normal, o snapshot ficou
idêntico, a URL não mudou.

**Causa raiz:** a tradução de `ref` (ex.: `e111`) pra um comando Playwright real usa um
**seletor CSS derivado das classes Tailwind do elemento** (`.rounded-lg.border` ou
`.flex.items-center.p-6`), com `.first()` — não um `getByRole`/`data-testid` estável nem o DOM node
exato do snapshot. Numa grade de cards com classes praticamente idênticas, esse seletor casa o
**primeiro elemento da página inteira** com aquela combinação de classes, não necessariamente o card
que a IA pretendia clicar — em código gerado por Lovable/Tailwind isso costuma ser um elemento de
layout genérico (header, wrapper), sem handler de clique nenhum. Resultado: o clique "aconteceu",
só que em outra coisa, sem `onClick`, então nada muda e nenhum erro aparece.

**Diagnóstico:**
1. `browser_click` "funcionar" sem erro mas a página não mudar (mesma URL, mesmo snapshot) é o
   sintoma — não confundir com "o app não reagiu ao clique" ou "precisa de `wait_for`".
2. Rodar `browser_take_screenshot` logo depois confirma visualmente que nada mudou (mais rápido que
   reler o snapshot yaml inteiro).
3. Ler o código gerado (`### Ran Playwright code` no resultado da tool) — se o seletor for uma
   cadeia de classes Tailwind com `.first()`, é esse o problema, não o app.

**Fix:** usar `browser_evaluate` com uma função que localiza o elemento por **conteúdo de texto**
(o `h3`/heading que a IA já leu no snapshot) e sobe o DOM até achar o ancestral com a classe
`cursor-pointer` (ou o `role` clicável certo), chamando `.click()` nesse nó real — não no seletor
derivado:

```js
() => {
  const heading = Array.from(document.querySelectorAll('h3'))
    .find(h => h.textContent.trim() === 'Texto exato do card');
  let el = heading;
  while (el && !el.className?.toString().includes('cursor-pointer')) el = el.parentElement;
  el?.click();
}
```

Isso navega/abre o elemento certo de forma determinística, reutilizável pra qualquer card da mesma
grade só trocando o texto buscado — sem depender da estabilidade do seletor CSS gerado pela tool.

**Ref:** ADS4PROS-Site, sessão 2026-09-03/04 — exploração autenticada do "Outbound OS" da V4 Company
(playbook de vendas) pra construir `/playbook-comercial`; `browser_click` por `ref` não navegava pra
nenhum dos ~40 materiais até trocar pra `browser_evaluate` com busca por texto.
