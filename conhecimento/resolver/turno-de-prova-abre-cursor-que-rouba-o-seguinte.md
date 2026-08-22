## O turno que você escolhe para PROVAR abre um cursor que rouba o turno seguinte {#turno-de-prova-abre-cursor-que-rouba-o-seguinte}

`tags: prova, [5-T], turno real, cursor, pendencia, disambig, receita de teste, precedencia, evidencia, smoke, relogio real`

**Sintoma:** você monta uma prova de ponta a ponta de N turnos, gasta horas de relógio real
preparando o estado, roda — e o último turno responde **outra coisa**. Não é bug do que você
consertou: o turno anterior abriu uma **pendência** (uma pergunta do sistema ao usuário), e a
resposta ambígua do usuário (`"sim"`) pertence a ela, não à sua feature.

**Causa raiz:** sistemas conversacionais têm vários *cursores* (pendência de desambiguação, oferta
de upsell, oferta de remontagem, sub-fluxo de endereço) e uma **ordem de precedência** entre eles.
Essa ordem é deliberada e costuma estar certa — passo ativo vence oferta, porque o oposto já foi bug
de produção. O que quebra não é o sistema: é a **receita da prova**, que escolheu um estímulo capaz
de abrir um cursor concorrente.

**O caso (tiatendo, prova do N26, 2026-08-21):** a receita era *(1)* fazer uma pergunta — o carrinho
ocioso tem de sobreviver; *(2)* pedir um item — o carrinho é encerrado e o bot **oferece remontar**;
*(3)* dizer `"sim"` — o pedido volta. Os turnos 1 e 2 saíram perfeitos, com quatro instrumentos
independentes batendo. No turno 3, o `"sim"` foi consumido por uma **desambiguação de tamanho**: o
item escolhido para o turno 2 (*"quero uma pizza"*) tinha duas variantes, e perguntar *"Grande ou
Média?"* criou um passo ativo. O código até **antecipa** o caso, em comentário, com um exemplo quase
idêntico. Custo: 3h30 de relógio real, e o aceite ficou sem prova de turno real (tinha cobertura
automatizada, o que salvou o `[5-T]` da parte que importava).

**Como evitar — três perguntas antes de gastar o relógio:**

1. **O estímulo do turno N abre alguma pendência?** Rode o predicado que decide isso (aqui: o item
   tem irmãos de variante?) **antes**, não depois. É uma consulta de um segundo contra o dado real.
2. **Existe precedência declarada entre o cursor que eu quero exercitar e os outros?** Procure no
   código por comentários do tipo "tem precedência" perto do seu cursor — quem já pagou o bug
   costuma ter deixado escrito.
3. **Escolha o estímulo mais BURRO que ainda dispara a sua guarda.** Se a guarda dispara com
   qualquer item, escolha o item **sem variantes**. Estímulo rico testa mais coisas ao mesmo tempo —
   e é exatamente por isso que ele contamina a leitura.

🔑 **E a regra que sobra:** valide a receita **executando os predicados** que ela pressupõe, não só
lendo os passos. Eu validei um deles (o que decide preservar × encerrar, e ele estava certo nos dois
turnos) e **não** validei o que decide se o turno abre pendência. A prova falhou exatamente na
dimensão que não foi medida antes.

**Relacionado:** [[fixture-que-mente-faz-a-mutacao-mentir-junto]] · a família *"resultado certo NÃO
prova que o seu caminho rodou"* — aqui o inverso: o caminho certo rodou, e o **turno de prova** é que
mediu outro cursor.
