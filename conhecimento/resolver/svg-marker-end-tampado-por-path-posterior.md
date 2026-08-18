## SVG `marker-end` (seta) fica tampada por outra linha que cruza por cima — ordem de pintura no DOM {#svg-marker-end-tampado-por-path-posterior}

tags: svg marker-end z-order, arrowhead hidden, paint order svg path, stacking context path
element, arrow marker occluded, seta escondida atras da linha, z-index svg sem z-index real

**Sintoma:** num SVG com várias `<path>` cada uma com `marker-end` (seta na ponta), setas de
linhas "de baixo" (mais cedo no array/DOM) ficam parcial ou totalmente escondidas quando outra
linha "de cima" (mais tarde no DOM) cruza exatamente por cima do ponto onde a seta deveria
aparecer.

**Causa raiz:** SVG não tem `z-index` real fora de `<svg>` raiz — a ordem de pintura é estritamente
a ordem no DOM (quem vem depois pinta por cima de quem vem antes). Um `marker-end` é pintado como
parte do PRÓPRIO path que o declara, no momento em que ESSE path é pintado. Se um path B (mais
tarde no DOM) cruza geometricamente sobre o ponto de chegada de um path A (mais cedo), o corpo de B
cobre a seta de A, mesmo que A e B não tenham relação lógica nenhuma entre si — é pura coincidência
de ordem de desenho + posição geométrica.

**Solução:** separe o desenho em 2 passadas. 1ª passada: todos os paths com o CORPO da linha
(stroke visível, dasharray, etc.), SEM `marker-end`. 2ª passada, DEPOIS no DOM (portanto sempre por
cima): os MESMOS paths de novo, mas com `stroke="transparent"` (corpo invisível) e `marker-end`
setado — como é sempre a ÚLTIMA coisa pintada, a seta nunca fica atrás de nada. O corpo invisível
ainda "conta" pro browser desenhar o marker (browsers pintam marker mesmo com stroke transparente,
desde que não seja `stroke="none"`).

**Ref:** Paid Media Automation, sessão 2026-08-08 (cont.159) — mesmo protótipo do achado acima.
Operador reportou "as setinhas devem ficar acima das linhas, não por baixo" depois de ver setas
sumindo onde linhas de cores diferentes se cruzavam. Fix em
`web/src/app/dev-preview/page-flow/page.tsx`: `{lines.map(...)}` duplicado em 2 passadas.
