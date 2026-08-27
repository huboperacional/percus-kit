## `ReactNode` (JSX) numa dependência de `useEffect` arrisca loop de render {#reactnode-em-dependencia-de-effect-arrisca-loop-de-render}

`tags: react, useEffect, dependency array, reactnode, jsx, referential equality, render loop, R23`

**Contexto:** um hook tipo `usePageHeader(title, subtitle)` que registra `{title, subtitle}` num
contexto React via `useEffect`, pra outro componente (ex.: um header compartilhado) consumir. A
tentação natural é tipar `subtitle` como `ReactNode` em vez de `string`, pra permitir formatação
rica (`<strong>`, `<em>`) — parecia estritamente mais flexível, sem custo.

**Risco real, não hipotético:** se alguma página passa JSX inline como subtitle
(`usePageHeader("Título", <>Texto com <strong>ênfase</strong></>)`), esse JSX é **recriado a cada
render** do componente pai — é um novo objeto, referencialmente diferente do anterior, mesmo com
conteúdo idêntico. Como `useEffect` compara dependências por `Object.is` (referência, não
estrutura), a dependência "mudou" a cada render → o efeito dispara de novo → chama `setState` no
contexto → o contexto muda → o provedor re-renderiza sua subárvore → a página que chamou o hook
re-renderiza → recria o MESMO JSX (nova referência de novo) → o efeito dispara de novo → ciclo.

Isso não é um loop instantâneo de "página trava" (React geralmente aguenta uns milissegundos de
re-render em cascata antes de qualquer aviso), mas é um re-render constante e evitável, e em
componentes mais pesados vira lag perceptível ou o aviso "Maximum update depth exceeded" do React
se algo no meio do caminho também disparar outro `setState` síncrono.

**Fix:** manter o tipo como `string` simples, não `ReactNode`. Se a página realmente precisa de
ênfase (negrito, itálico), perder a formatação rica é mais barato que arriscar o loop — ou, se a
formatação for indispensável, memoizar o JSX com `useMemo([deps estáveis])` no componente que o
declara, garantindo referência estável entre renders sem mudança real de conteúdo.

**Medido em Paid Media Automation (26/08):** `web/src/hooks/usePageHeader.ts` — cogitado
`subtitle?: ReactNode` pra preservar um `<strong>` em `page-flow/page.tsx`; revertido pra `string`
antes de propagar pras 12 páginas que usam o hook, e o subtítulo de `page-flow` perdeu o negrito
(virou texto plano). Review cross-provider (DeepSeek) sinalizou a perda de ênfase como
"preferência", não como bug — a troca por segurança foi aceita conscientemente.

**Regra que fica:** dependência de `useEffect`/`useMemo`/`useCallback` que pode receber JSX
inline é um cheiro — ou tipa como primitivo (`string`/`number`/`boolean`), ou documenta e garante
memoização na origem antes de aceitar `ReactNode` ali.
