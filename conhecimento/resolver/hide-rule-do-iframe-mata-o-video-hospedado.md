## Regra de esconder feita para um IFRAME também esconde o `<video>` que a substituiria {#hide-rule-do-iframe-mata-o-video-hospedado}

tags: css hide iframe, video sumiu, seletor largo demais, display none generico, troca de player

**Sintoma.** Um clipe ambiente (hero, faixa full-bleed) não aparece em nenhum celular. O código tem
os dois caminhos — arquivo próprio (`<video muted playsinline>`) e embed do YouTube (`<iframe>`) — e
o arquivo, sozinho, autoplaya no iOS sem problema. Mesmo assim nada se move.

**Causa.** A regra que esconde o clipe foi escrita quando só existia o iframe, e mira o **wrapper**
comum aos dois: `@media (prefers-reduced-motion:reduce),(pointer:coarse),(hover:none),(max-width:820px)
{ .layer{display:none} }`. As 3 últimas condições existem por defeitos que são **do iframe**: o iOS
recusa o autoplay dele, o player desenha os próprios controles por cima do H1 e engole o toque
destinado ao CTA. Um `<video>` local sem `controls` não tem chrome pra desenhar e o iOS **toca**. A
regra, porém, não distingue: migrar pra arquivo hospedado não muda nada enquanto ela seguir única.

**Correção.** Emitir a regra em função do caminho que vai renderizar. Só
`prefers-reduced-motion:reduce` para o arquivo (é promessa sobre MOVIMENTO, vale pros dois); a lista
inteira segue valendo para o iframe:
```
`@media ${video.videoSrc ? '(prefers-reduced-motion:reduce)' : LISTA_COMPLETA}{.${layerClass}{display:none}}`
```

**Como verificar (e por que o teste verde não basta).** A suíte pode passar inteira sem cobrir isso:
os testes existentes alimentavam só o caminho do iframe, então continuaram verdes com o bug vivo.
Duas provas valem:
1. **Vermelho→verde**: reverta a linha da divisão e rode o arquivo de teste — um caso, e só um, tem
   que falhar (asserte a AUSÊNCIA de `pointer:coarse`/`hover:none`/`max-width` na regra do arquivo).
2. **No navegador, no HTML SERVIDO** (não no código): num viewport de celular, `getComputedStyle` do
   layer tem que dar `display:block`, e `currentTime` tem que AVANÇAR entre duas leituras. "A tag
   está lá" não é prova de que toca.

**Detalhe que assusta e é inofensivo:** o React pode emitir `autoPlay=""`/`playsInline=""` em
camelCase no HTML. O parser de HTML normaliza nome de atributo pra minúsculo — medido no browser, as
propriedades `video.autoplay`/`video.playsInline` vêm `true`. Não "conserte" isso; confirme no DOM.

**Custo a declarar ao operador:** o clipe passa a ser baixado no celular (alguns MB por rota) onde
antes não baixava byte de vídeo. É decisão dele, não detalhe de implementação.
