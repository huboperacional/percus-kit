## Recharts: prop inline no `YAxis` com `width="auto"` reabre laço "Maximum update depth" — só o navegador vê {#recharts-yaxis-memo-prop-inline-reabre-laco-de-render}

`tags: recharts, react, render loop, maximum update depth, yaxis, width auto, react.memo, usePlotArea, jsdom, playwright, R23`

**Sintoma:** a página com gráfico do Recharts 3 abre em "This page couldn't load" no navegador, com
"Maximum update depth exceeded … setState inside useEffect" nascendo em
`ChartDataContextProvider.useEffect`. A suíte de componente (jsdom) segue 100% verde — o jsdom não
desenha o SVG e o laço nunca acontece lá.

**Causa (Recharts 3.8.1, lida no código):** `YAxis` é `React.memo(…, axisPropsAreEqual)` com
comparação **rasa**. `tick={{ fontSize: 11 }}` e `tickFormatter={(v) => …}` escritos no JSX chegam com
identidade nova a cada render do pai → o memo falha → `SetYAxisSettings` monta um `settings` novo e
despacha `replaceYAxis` → a largura medida do eixo `width="auto"` volta à padrão (60 px) → o
`useLayoutEffect` remede (ex.: 29 px) → a área de plotagem anda → um componente que lê `usePlotArea()` e
faz `setState` no pai re-renderiza o pai → props inline novas de novo → laço. A assinatura medida foi
a área oscilando entre DOIS estados exatos (x = 60 e x = 29, borda direita fixa) — não é ruído
sub-pixel, e arredondar não resolve.

**Correção:** toda prop de eixo/série do Recharts em **constante de módulo** (`const TICK = {…}`,
função top-level) ou `useCallback`/`useMemo` com dependências primitivas; o `data` do gráfico
memoizado por **assinatura primitiva** (`serie.join(",")`), nunca pela identidade de um array
recriado a cada render. Vale igual para `dot` de `Line`.

**Como provar:** sonda Playwright que abre a tela, espera o gráfico medido e falha se o console tiver
"Maximum update depth"; veja-a reprovar com as props inline de volta (mutante) antes de confiar.
Teste de componente não prova nada aqui.
