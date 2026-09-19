## Régua de comparação que exige "mesma medição" acaba escondendo dia com número — e some com dinheiro do total {#regua-de-comparacao-que-exclui-dia-esconde-dinheiro}

`tags: relatorio, comparacao, cobertura, total, honestidade, operador, R23`

**Sintoma:** o relatório mostra o dia com número na tabela, mas **sem variação** ("— —"), e o total
do período é menor que a soma das linhas que estão na tela. Num caso real: o dia de ontem sem
comparação nenhuma, o anterior comparado com um dia **oito dias** atrás, e o total da semana somando
5 de 7 dias — US$ 6,3 mil a menos que a soma visível.

**Causa:** uma régua bem-intencionada — "só comparo/somo dias com o MESMO conjunto de fontes
medidas" — criada para impedir uma queda falsa quando uma fonte entra ou sai da coleta. Ela resolve
esse caso e produz outro pior: qualquer dia com um buraco de coleta diferente do resto vira um dia
**sem par**, e um dia sem par não compara nem entra no total.

**O teste que separa as duas coisas:** pergunte o que o número afirma.
- *"Este dia cresceu X% sobre o anterior"* — comparar populações diferentes realmente mente;
- *"O período investiu Y"* — aqui não há mentira nenhuma em somar o que foi medido; o que mente é
  **omitir** um dia que está na tela logo acima, sem dizer que ele ficou de fora.

**Regra que o operador escolheu (e que vale de padrão):** o dia compara com o **dia anterior** e o
total soma **todo dia que tem número**; a lacuna continua dita — na nota do dia (quem faltou) e num
sinalizador de "não completo" —, mas nunca vira dia a menos na conta. "Piso" fica reservado para
período em que algum dia **não tem número nenhum**, que é o único caso em que a soma é mesmo um piso.

**Efeito colateral que precisa entrar junto:** a mesma régua costuma alimentar mais de uma tela.
Procure TODOS os consumidores antes de mexer (no caso real eram três: o aviso de piso, a frase de
completude e o texto do cartão), senão a tela passa a dizer *"o total soma 7 de 7 dias — os outros
não têm cobertura, o número é um PISO"*, uma frase que se desmente sozinha.
