## Reprovação de gate em arquivo que a sua mudança não toca: rode de novo ANTES de investigar {#gate-falso-negativo-por-rede}

`tags: gate falso negativo, CORS de terceiro, Google Maps widget, verify-render, reprovacao fora do escopo do diff, flaky por rede, rode de novo, recurso externo`

`verify-render` reprovou um site com 3 erros de console vindos do widget do Google Maps (CORS em
`maps.googleapis.com`). O site era de um archetype que a mudança nem tocava. **Segunda passada: 6/6
verde, sem alterar uma linha.**

Gate que depende de recurso externo (mapa, fonte, embed, CDN de terceiro) tem falso negativo por
rede. O sinal barato de que é isso: **a reprovação é num alvo fora do escopo do diff**. Reexecutar
custa segundos; investigar custa a sessão. Mesma família de
Taxa alta de falha em lote = instrumento suspeito.
