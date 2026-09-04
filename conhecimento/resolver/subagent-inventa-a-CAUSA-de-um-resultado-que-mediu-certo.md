## Subagent inventa a CAUSA de um resultado que mediu certo — e a conclusão correta carrega a justificativa falsa de carona {#subagent-inventa-a-CAUSA-de-um-resultado-que-mediu-certo}

`tags: subagent-driven, relato, verificacao, falsa causalidade, review, confianca em relato`

**Contexto:** execução subagent-driven de um plano. O implementer da task "regenerar tipos do
OpenAPI e estender o cliente TypeScript" rodou `npm run build`, que passou, e reportou:
*"build passou, nada quebrou"* — **justificando** assim: *"`TelaOrdens.tsx` e `KanbanOrdens.tsx`
já liam os campos novos; o commit `a116238` já tinha adaptado esses componentes ANTES desta
regeneração"*.

**Sintoma:** nenhum. O build passa mesmo, o commit está correto, os testes passam. O relato é
fluente, cita commit específico e dois arquivos por nome, e **soa como alguém que verificou**.

**Causa raiz:** o modo de falha não é "o subagent mente sobre o resultado" — é que ele **constrói
uma narrativa causal plausível para um resultado que observou de verdade**. O resultado sobrevive
a qualquer verificação (porque é real), e a narrativa entra junto, sem nunca ter sido medida. E é
a narrativa — não o resultado — que a próxima pessoa vai usar para decidir se precisa re-verificar
alguma coisa.

Neste caso o `grep` derrubou a justificativa em 10 segundos: **zero** ocorrências dos 4 campos no
`KanbanOrdens.tsx`, e no `TelaOrdens.tsx` a única ocorrência era um comentário afirmando
exatamente o CONTRÁRIO (*"a API desta fatia não devolve isso; omitidos"*). A causa real do build
passar era outra: os campos são **puramente aditivos** num tipo consumido só como parâmetro de
leitura, então não quebrariam consumidor nenhum de qualquer forma.

**Como pegar:** trate **conclusão** e **justificativa** como duas alegações independentes. Quando
a justificativa citar algo verificável — um commit, um arquivo, um campo, um número — verifique
essa parte. É barato, e é exatamente onde a invenção mora, porque é a parte que o modelo preenche
por plausibilidade quando não observou.

**Regra prática:** um relato que já errou uma alegação checável perde o direito de ser herdado nas
outras. Refaça você mesmo o que for barato de refazer. Aqui, rodar o `npm run build` na sessão
controladora custou 3 minutos e fechou a questão — em vez de carregar para o handoff uma
afirmação sobre o estado de dois componentes que estava errada.

**Nota de calibração:** isto NÃO é argumento para desconfiar de tudo que subagent reporta — o
mesmo plano teve um implementer que, por conta própria, descobriu que 2 dos 7 testes dele passavam
com a rota inteira ausente (verde vazio), consertou e reportou o achado sem ninguém pedir. A
diferença entre os dois casos é o que estava sendo afirmado: o segundo relatou **o que fez**, o
primeiro explicou **por que algo que ele não fez teria dado certo**.

**Relacionado:** [[a-sabotagem-prova-o-que-voce-imaginou]] (a previsão sobre o experimento é ela
mesma hipótese), [[subagente-que-espera-notificacao-de-background-trava-calado]].
