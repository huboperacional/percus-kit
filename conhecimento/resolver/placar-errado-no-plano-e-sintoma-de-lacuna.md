## Placar errado no plano é sintoma de lacuna, não erro de contagem {#placar-errado-no-plano-e-sintoma-de-lacuna}

`tags: plano, TDD, placar, Expected PASSED, pytest --collect-only, gate ausente, teste gemeo, canario, drift de documento, R2`

**Contexto:** um plano de implementação declara, em cada task, quantos testes devem passar
(*"Expected: 17 PASSED"*). Ao executar, o número real foi outro em **cinco** tasks seguidas:
17→23, 15→16, 17→22, 26→31, e um par 21/24 que era 26/22.

**A tentação errada:** ajustar o número do plano para o que a execução deu. Isso "fecha a conta" e
esconde o que o desvio estava dizendo. Pior ainda é o inverso — apagar um teste para bater no número
escrito, que foi o risco explícito registrado num dos casos.

**O que o desvio realmente significa, em ordem de frequência:**
1. **O número foi contado de cabeça** ao escrever o plano, nunca medido. É o caso mais comum e o
   mais inofensivo: corrija com `pytest --collect-only`.
2. **O plano envelheceu**: a task ganhou casos durante a implementação (um achado de review, um
   mutante novo) e a linha não acompanhou. Corrija a linha.
3. 🔴 **Há uma LACUNA real**, e o número está apontando para ela. Foi o que aconteceu na Task 6: o
   plano dizia 22 e o real era 21, porque o caso 22 (um desempate `id DESC` do `DISTINCT ON`) tinha
   ganhado canário SQL e mutante, **mas não ganhou o teste `pytest` gêmeo**. O "22" era a memória
   de um caso que existia num gate e faltava no outro.
4. **O número foi herdado de outra task** e propagou o erro. O placar da Task 9 dizia
   *"26 = 17 da Task 6 + 9 novos"*; quando a Task 6 virou 22, o 26 continuou lá, e depois virou 30
   quando devia ser 31. Placar derivado herda erro duas vezes.

**Procedimento:**
- Ao ESCREVER o plano: não escreva número que você não mediu. Se o arquivo ainda não existe, deixe
  a linha sem número e mande medir — *"meça com `pytest --collect-only` ao escrever, e só então
  escreva o número aqui"* é mais útil que um palpite.
- Ao EXECUTAR: quando o número não bater, pergunte **por que** antes de corrigir. Conte os casos do
  plano à mão e compare com os do código; a diferença tem nome.
- Nunca apague teste para fechar conta. Se o plano tem mais casos que o código, o código está
  faltando um.
- Placar derivado (*"N da task anterior + M novos"*) é dívida: quando a anterior muda, este mente
  em silêncio. Prefira mandar medir.

**Sintoma irmão, e a mesma raiz:** um gate que o plano descreve como *"confira à mão que X"*. Isso
não é gate — na Task 7, a injeção que o plano mandava conferir manualmente deixava os 21 testes de
então **todos verdes**. Todo "confira à mão" no plano é um teste que falta escrever.

**Quando os dois gates de uma task vivem em ferramentas diferentes** (aqui: `pytest` para a lógica e
canário SQL para o banco), eles divergem sem que nada acuse. Conte os casos dos dois e compare —
foi exatamente essa comparação que achou a lacuna.

Relacionados: [[a-sabotagem-prova-o-que-voce-imaginou]]
