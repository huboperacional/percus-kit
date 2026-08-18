## Várias linhas SVG tracejadas sobrepostas, com fases diferentes, parecem 1 linha SÓLIDA {#svg-dasharray-sobreposto-parece-solido}

tags: svg stroke-dasharray, dashed line looks solid, multiple paths same segment overlap, path
phase offset, bundled diagram lines, bus diagram svg, sankey trunk line, diagrama de fluxo linhas
sobrepostas, tronco compartilhado

**Sintoma:** um diagrama SVG com várias linhas tracejadas (`stroke-dasharray`) que compartilham um
trecho visual comum (ex.: várias origens convergindo num "tronco"/trilho antes de entrar num alvo
único) — o trecho COMPARTILHADO aparece como linha SÓLIDA, mesmo com `stroke-dasharray` aplicado
em todos os `<path>`. Trechos NÃO-compartilhados (só 1 linha passando) continuam tracejados
normalmente — só o ponto de overlap "perde" o tracejado.

**Causa raiz:** cada `<path>` tem seu próprio `stroke-dasharray` com fase iniciando em `M` (o começo
daquele path específico). Quando N paths diferentes redesenham o MESMO segmento visual (cada um
percorrendo até ali por uma distância própria, diferente das outras), a fase do tracejado de cada
um cai em pontos diferentes ao longo do segmento compartilhado. O olho humano vê a UNIÃO de todas
as fases sobrepostas — em qualquer ponto do segmento, quase sempre AL menos um dos N paths está na
fase "on" (traço visível), cobrindo os gaps dos outros. O resultado visual é indistinguível de uma
linha sólida, mesmo que cada path individual esteja corretamente tracejado.

**Como confirmar:** inspecione os atributos `d` dos `<path>` via `document.querySelectorAll('svg
path')` — se múltiplos paths têm o MESMO segmento de coordenadas (total ou parcial) mas comprimentos
totais diferentes (logo fases de dash diferentes), essa é a causa.

**Solução:** não deixe N origens redesenharem o MESMO trecho compartilhado. Separe o desenho em: (1)
um "stub" curto e individual por origem (da própria origem até o ponto de junção, sem repetir o
trecho comum) e (2) UM path só pro trecho compartilhado (tronco/trilho + entrada final no alvo),
desenhado uma única vez. Isso também resolve de graça o problema irmão de setas duplicadas (várias
`marker-end` empilhadas no mesmo alvo) — só o path do trecho compartilhado precisa de seta.

**Ref:** Paid Media Automation, sessão 2026-08-08 (cont.159) — protótipo `/dev-preview/page-flow`
(`web/src/app/dev-preview/page-flow/page.tsx`), rota "D" até o card de Lead: 7-8 origens
redesenhavam o trilho horizontal + subida final inteiros, cada uma por cima da outra — operador
reportou "a linha azul não fica tracejada, parece linha sólida". Fix: trechos individuais (stub,
sem seta) + 1 trecho comum (trilho+subida+entrada, com seta), campo novo `FlowLine.noArrow` pra
marcar os que não devem receber marcador.
