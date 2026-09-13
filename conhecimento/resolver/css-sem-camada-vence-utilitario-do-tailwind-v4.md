## CSS sem camada vence utilitário do Tailwind v4, por mais específico que o utilitário seja {#css-sem-camada-vence-utilitario-do-tailwind-v4}

`tags: tailwind v4, cascade layers, @layer, especificidade, design system, panelkit, next.js, contraste, botao ilegivel, R23`

**Sintoma:** um elemento tem a classe utilitária certa e ela simplesmente não vale. O caso real:
um `<a class="... bg-gradient-to-r from-pink-500 to-violet-500 text-white">` renderizando com texto
**roxo escuro sobre gradiente rosa** — ilegível. `text-white` está na classe, o DevTools mostra a
regra, e ela perde.

**Reprodução real** (LiliFlow, 2026-09-12): o arquivo de tokens do design system trazia, solto no
topo do arquivo:

```css
a { color: var(--accent-text); text-decoration: none; }
```

Medido no navegador: `getComputedStyle(cta).color` devolvia `rgb(103, 51, 165)` em vez de
`rgb(255, 255, 255)`.

**Por que:** no Tailwind v4 os utilitários vivem dentro de `@layer utilities`. A regra do CSS em
cascade layers é que **qualquer declaração fora de camada vence qualquer declaração dentro de
camada**, independentemente de especificidade. Um seletor de tipo (`a`, especificidade 0-0-1) sem
camada derrota uma classe (0-1-0) em `@layer utilities`. Isso inverte a intuição que todo mundo
carrega do CSS pré-camadas.

O alcance não é local: enquanto essa regra existir sem camada, ela derruba o `text-white` de
**qualquer link estilizado como botão no app inteiro** — não só na tela onde o defeito apareceu.

**Conserto:** pôr a regra dentro de `@layer base`, para o utilitário voltar a mandar onde foi
escrito de propósito, e o padrão continuar valendo para link comum.

**A pegadinha do conserto — onde declarar a camada importa:** a ordem das camadas é fixada pela
**primeira aparição** do nome. O Tailwind registra `@layer theme, base, components, utilities` no
seu `@import "tailwindcss"`. Se você declarar `@layer base { ... }` num arquivo importado **antes**
do Tailwind, você registra `base` primeiro e reordena a cascata inteira (`base` passa na frente de
`theme`). Então:

```css
/* globals.css */
@import "../components/design-system/tokens.css";  /* tokens, sem @layer aqui */
@import "tailwindcss";                              /* registra a ordem das camadas */

@layer base {                                       /* DEPOIS do import: ordem ja definida */
  a { color: var(--accent-text); }
}
```

Mover a regra para depois do `@import "tailwindcss"` é o que fecha o caso sem efeito colateral.

**Como detectar sem adivinhar:** peça ao navegador quais regras casam com o elemento e qual cor cada
uma pede. Se aparecer um seletor de tipo genérico na lista, é ele.

```js
const el = document.querySelector('a.text-white');
[...document.styleSheets].flatMap(s => { try { return [...s.cssRules] } catch { return [] } })
  .filter(r => r.selectorText && r.style?.color && el.matches(r.selectorText))
  .map(r => r.selectorText + ' { color: ' + r.style.color + ' }');
// -> ["a { color: var(--accent-text) }"]
```

**Sinal de que você está neste caso:** o projeto tem um design system próprio com reset de elementos
(`a`, `p`, `h1`…) **e** usa Tailwind v4. Os dois convivem mal por padrão; o reset precisa estar em
`@layer base` para não atropelar utilitário.

**Como isto foi achado:** não foi lendo código. A classe estava certa no arquivo; só abrindo a
página no navegador e pedindo a cor computada é que o defeito apareceu.
