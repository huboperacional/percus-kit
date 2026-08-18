## Medi a silhueta por subtração de fundo e ela mentiu (objeto e fundo com a mesma luminosidade) {#mascara-fundo-objeto-mesma-luminancia}

`tags: imagem, visao, mascara, subtracao de fundo, background subtraction, silhueta, bounding box, luminancia, contraste, render, foto de estudio, carro preto, falso negativo, metrica quebrada, olhar antes de medir`

**Sintoma:** uma métrica de geometria sobre imagem (altura, silhueta, linha do teto, bounding box) devolve "quase não mudou" para duas imagens que, a olho nu, são **claramente objetos diferentes** — ou o contrário, acusa mudança enorme onde nada mudou. A conta roda sem erro e o número parece plausível.

**Causa raiz:** a máscara sai de **subtração de fundo** (`|pixel - cor_de_fundo| > limiar`), e isso só separa objeto de fundo quando os dois têm **luminosidade diferente**. Objeto escuro sobre fundo escuro (ou claro sobre claro) mata a premissa: a máscara passa a marcar o **degradê/vinheta do próprio fundo** e a ignorar o objeto. O resultado deixa de descrever o objeto e passa a descrever a iluminação da cena.

**Como detectar sem precisar de olho treinado** — a máscara denuncia sozinha se você imprimir os extremos:
- a borda detectada **encosta na borda da imagem** (`topo y=0`, `base y=altura-1`): o fundo entrou na máscara;
- a área marcada é implausível (perto de 0%, ou perto de 100%);
- a bounding box tem a largura inteira do quadro.

Imprima **sempre** o extremo junto com a média. Foi `ponto mais alto do teto: y=0` que denunciou — `y=0` é a borda de cima da imagem, não o topo de objeto nenhum — e o número da média, sozinho, parecia perfeitamente razoável.

**Solução:**
1. **Olhe a imagem antes de calcular.** Duas imagens abertas lado a lado resolvem em segundos o que a métrica errou, e calibram qual conta vale a pena escrever. Métrica sobre imagem é para **medir** uma diferença que você já viu, não para **descobrir** se ela existe.
2. Se precisar de máscara mesmo: segmente por **gradiente/borda** (Sobel, Canny) em vez de por cor absoluta — borda sobrevive a objeto e fundo da mesma luminosidade. Ou use o **canal alfa**, se o render tiver.
3. Diferença **entre duas imagens** (`|A - B| > limiar`) continua válida nesse cenário e responde "o que mudou e onde" — foi ela que deu a resposta certa (23,7% dos pixels, concentrados na carroceria, com fundo e sombra intactos). O que quebra é medir **geometria absoluta de um objeto** contra o fundo.

**Ref:** AutoWorx, 2026-08-15 — comparação Model Y × Model 3 (carro **preto** sobre fundo de estúdio **escuro**). A métrica de linha de teto disse "1–2% mais baixo, silhueta praticamente igual"; as imagens mostravam um crossover e um sedan. Relacionado: `#reproduzir-antes-de-fixar` (hipótese errada de root cause), memória `reference_configurador_renders_derivam_da_mesma_base`.
