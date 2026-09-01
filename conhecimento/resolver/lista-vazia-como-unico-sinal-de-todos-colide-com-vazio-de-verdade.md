## Lista vazia como ÚNICO sinal de "todos selecionados" colide com "usuário escolheu zero" — o checkbox mestre nunca desmarca {#lista-vazia-como-unico-sinal-de-todos-colide-com-vazio-de-verdade}

`tags: multi-select, checkbox, sentinela, estado vazio, UX, filtro, ambiguidade de representacao, R23`

**Padrão comum, e a armadilha que ele carrega:** um multi-select com N opções representa "todas
selecionadas" como `selected = []` (lista vazia), em vez de listar as N ids — economiza estado e
evita que a tela filtre pra zero linhas quando ninguém tocou no controle ainda. Documentado
explicitamente como decisão de produto: "nunca existe 'nenhuma conta', que mostraria tabela vazia
sem explicar por quê".

**O defeito que essa decisão esconde:** se `[]` é o ÚNICO jeito de dizer "todas", não sobra
representação pra "usuário desmarcou tudo de propósito, quer escolher do zero". Dois sintomas
observáveis, achados os dois pelo operador ao vivo (não por teste, porque o teste também codificava
o defeito como comportamento esperado):

1. **O checkbox mestre ("Todas") nunca desmarca de verdade.** Clicar nele quando já é `[]` chama
   `onChange([])` — mesmo valor, nenhuma mudança de estado, o clique parece não fazer nada.
2. **Desmarcar a última conta que sobrava reverte pra "todas" em silêncio.** Ir desmarcando item por
   item até sobrar zero produz `[]` — que é EXATAMENTE a mesma forma de "todas" — e a tela
   reexibe tudo que acabou de ser tirado, sem aviso. "Desmarquei várias e continua aparecendo coisa
   de contas desmarcadas."

**A justificativa original geralmente já morreu antes do bug aparecer.** A razão de nunca deixar
`[]` genuinamente vazio ("mostraria tabela vazia sem explicar por quê") costuma ter sido resolvida
por OUTRO mecanismo entre a decisão original e o bug — aqui, uma mensagem de estado-vazio
("Nenhuma campanha com esses filtros") que já existia meses antes e cobria exatamente esse caso.
Confira se essa mensagem existe antes de aceitar a justificativa como ainda válida.

**Fix:** um sentinela distinto pra "zero, de propósito" (`NENHUMA = "__nenhuma__"`), nunca colidindo
com o `[]` canônico de "todas". Master vira um TOGGLE de verdade (indeterminado/parcial → todas;
já-todas → sentinela; já-sentinela → todas — mesma convenção do checkbox mestre do Gmail/Drive:
parcial soma até completo, não zera). Clique em item individual sempre limpa o sentinela primeiro.
**Armadilha ao introduzir o sentinela:** qualquer efeito que "poda" a seleção contra a lista de
opções válidas (ex.: remover ids que saíram de uma troca de fonte/conta) tem que EXPLICITAMENTE
preservar o sentinela — ele não é uma opção válida, e um filtro ingênuo (`prev.filter(id =>
opções.includes(id))`) o removeria como se fosse um id órfão, reintroduzindo o bug 2 por outra
porta.

**Teste que teria pego antes:** qualquer suíte que afirme `desmarcar a ÚNICA conta selecionada volta
pra 'todas'` como comportamento ESPERADO está testando o sintoma, não a intenção — questione essa
asserção antes de replicar o padrão num componente novo.
