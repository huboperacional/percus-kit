## O screenshot pega o que a guarda não vê — e o que ele pega é sempre a premissa, nunca o valor {#o-screenshot-pega-o-que-a-guarda-nao-ve}

`tags: screenshot, evidencia, R1, guarda estatica, falso verde, tsc, suite verde, vazamento de marca, wordswap, voz do produto, layout`

**Contexto:** três defeitos de superfície pública, no mesmo dia, com `tsc` limpo, suíte verde,
guardas de varredura verdes e medições de layout batendo. Os três só apareceram na foto.

**Os três, e o que cada um ensina:**

1. **Preço de três dígitos quebrando em duas linhas** num cartão de tabela. Os cartões de dois
   dígitos não quebravam, então a grade media larguras **iguais** e alturas **iguais** — a medição
   confirmava que estava certo. O que quebrava era o conteúdo dentro da caixa, e a medição olhava a
   caixa.
2. **Selo ilegível** por contraste medido contra a superfície errada — ver
   [[contraste-se-mede-contra-o-que-esta-atras-do-pixel]].
3. **Voz de pessoa física numa página de produto B2B**: um título dizia *"sua vida financeira"*.
   Empresa não tem vida financeira; pessoa tem. Escapou de **toda** varredura porque não continha
   nome de marca, nome de parente nem exemplo doméstico — o vazamento estava **só no sujeito da
   frase**.

**A regra que os três compartilham:** guarda estática verifica **valores** — esta string está
presente, aquele número bate com o catálogo, este arquivo não cita aquele. Ela não verifica
**premissas** — que o texto caiba, que o fundo seja o esperado, que a frase fale com quem paga. E
premissa errada é exatamente o que sobrevive a uma troca de valores.

**Corolário prático, e é o que dói:** *"a suíte está verde"* nunca significa *"a tela está certa"*.
Significa *"nenhum valor que eu sei conferir está errado"*. Depois de qualquer mudança visível, a
foto é o único instrumento que não herda as premissas do código.

**Como fotografar de modo que a foto valha:**
- **Confira que o CSS carregou** antes de guardar a imagem como evidência. Página sem estilo mostra
  o texto certo e passaria numa conferência rápida — ver
  [[build-de-producao-envenena-o-dev-server]].
- **Confira a porta no log do próprio processo.** Com várias sessões na mesma árvore, a 3000 pode
  ser de outra pessoa, e você fotografa a árvore alheia achando que é a sua.
- **Meça no navegador junto com a foto** (`getClientRects().length` para quebra de linha, razão de
  contraste calculada do `getComputedStyle` real). A foto mostra que há algo errado; a medição diz
  o quanto, e vira o número que entra no comentário.
- **Guarde também a foto do estado DEFEITUOSO.** Sem ela, "o screenshot mostra a tela certa" não
  prova que o screenshot pegou alguma coisa.

**Quando o vazamento é de voz, o nome certo é o disfarce.** Trocar o nome do produto de origem pelo
novo num texto sobre gasto doméstico não o torna um texto do domínio novo — só o torna invisível
para quem procura pelo nome. Guarde a persona, o exemplo e o **sujeito da frase**, não só a marca.

Ver também, em `conhecimento/fazer/`: **guarda-que-acusa-texto-correto-e-desligada**.
