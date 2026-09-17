## Valor esperado lido da MESMA constante que a sabotagem altera — o teste de igualdade fica verde {#esperado-lido-da-constante-sabotada-deixa-o-teste-verde}

`tags: sabotagem, teste de igualdade, constante, valor esperado, falso verde, oauth, escopo, url exata, guarda que nao discrimina`

**Sintoma:** o plano manda sabotar uma constante (ex.: acrescentar `" openid"` a `ESCOPO_DO_DRIVE`) e diz que **dois**
testes caem. Cai só um. O que ficou verde é justamente o que comparava a URL inteira "por igualdade".

**Causa raiz:** o teste montava o valor esperado **importando a constante do próprio módulo**:
`"scope": [ESCOPO_DO_DRIVE]`. Sabotada a constante, produto e expectativa mudam juntos, e a igualdade continua
verdadeira. A asserção é exata na forma e vazia no conteúdo: ela prova que a URL usa a constante, não que a constante
está certa.

**Por que engana:** "comparação por igualdade" é o antídoto conhecido contra `in` frouxo, então o teste parece o mais
forte do arquivo. E sem a sabotagem, ele está verde pelo motivo certo — nada no código denuncia.

**Como resolver:** no lado **esperado**, escreva o **literal** do que a regra exige
(`"https://www.googleapis.com/auth/drive.file"`), nunca a constante do módulo sob teste. Use a constante só onde o teste
quer provar "o produto usa a fonte única". Se a sabotagem puder atingir a constante **ou** o ponto de uso, sabote os dois
separadamente — na medição de 2026-09-16 (Empresa Milionária, guarda do documento, Task 3) a constante derrubou 4 testes
e o ponto de uso só 2.

**Como confirmar que era isso:** sabote a constante e liste o que ficou verde; para cada teste verde que deveria cair,
procure o nome da constante no lado esperado da asserção.

Relacionado: [[discriminador-parcial-reintroduz-bug]] · [[instrumento-herda-a-constante-que-o-produto-ja-corrigiu]].
