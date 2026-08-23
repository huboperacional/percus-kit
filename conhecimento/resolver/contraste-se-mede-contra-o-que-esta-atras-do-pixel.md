## Contraste se mede contra o que está ATRÁS do pixel, não contra o componente de onde a regra foi copiada {#contraste-se-mede-contra-o-que-esta-atras-do-pixel}

`tags: contraste, WCAG, AA, acessibilidade, selo, badge, position absolute, CSS, medicao, tema escuro, screenshot, guarda visual, falso verde`

**Contexto:** um selo ("EM BREVE") foi acrescentado a um cartão branco de tabela de preços. O
contraste foi calculado do jeito certo — fundo do selo composto sobre o fundo do cartão, tinta por
cima — e deu **5,42:1**, folga confortável sobre o mínimo de 4,50 para texto pequeno. O comentário
no CSS registrou a medição. A foto mostrou um **borrão cinza ilegível**.

**Causa raiz:** o selo é `position: absolute; top: -13px`. Ele **flutua FORA do cartão**, sobre o
fundo escuro da seção. O pixel que o olho vê não tem o branco do cartão atrás — tem o escuro da
seção. Um fundo de `tinta-escura / 8%` sobre escuro é tinta escura no escuro, e a medição, feita
contra o branco, descrevia uma composição que nunca acontece na tela.

**Por que ninguém viu antes:** a regra foi **copiada de um componente irmão** que fica *dentro* do
cartão, onde a medição valia. Copiar CSS carrega junto a premissa de fundo, e a premissa não aparece
no código copiado — ela mora no layout. `tsc` passa, teste de texto passa, e a única guarda que
existia (a medição comentada) afirmava o valor errado com aparência de rigor.

**Como pegar:**
1. Antes de medir, pergunte **qual elemento pinta o pixel atrás deste**. `position: absolute`,
   `transform`, portal e `z-index` movem o elemento para fora do pai visual — o pai do DOM deixa de
   ser o fundo.
2. Meça no navegador, não no papel: `getComputedStyle(el).backgroundColor` do elemento **e do que
   está atrás**, e a razão entre os dois.
3. **Tire a foto.** Nesta classe, a foto é o único instrumento que não herda a premissa errada.

**Conserto que funciona:** tornar o chip **opaco**. Fundo translúcido faz o contraste depender do
que está atrás — e o que está atrás muda com o layout, com o tema e com o scroll. Branco a 90% com
tinta a 82% dá 13,1:1 e para de depender do fundo. Opacidade é o que transforma uma medição frágil
numa medição verdadeira em qualquer posição.

**Armadilha irmã:** o inverso também morde. Numa página cujo bloco de identidade **reaponta tokens**,
uma seção declarada `bg-dark-900` pode renderizar CLARA. Ali, três parágrafos em `text-slate-400` e
`text-slate-500` — colapsados pela mesma contra-regra `!important` no mesmo cinza — davam **4,34:1**,
reprovando por 16 centésimos. A classe do Tailwind nomeia a cor do tema ESCURO; quem traduz para o
claro é a contra-regra. **O número menor pode ser o texto mais escuro**, e só a medição em runtime
mostra isso.

Ver também: [[o-screenshot-pega-o-que-a-guarda-nao-ve]].
