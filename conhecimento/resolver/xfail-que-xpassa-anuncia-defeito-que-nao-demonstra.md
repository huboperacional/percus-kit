## `xfail` que sempre xpassa é pior que teste nenhum {#xfail-que-xpassa-anuncia-defeito-que-nao-demonstra}

`tags: pytest, xfail, golden, llm, fixture, medição, assert fraco, teste vácuo`

**Sintoma:** você mede um defeito em produção, escreve o teste que o captura, marca `xfail` com a
evidência no `reason`… e ele **xpassa**. Aí você enriquece a fixture pra reproduzir, e ele xpassa de
novo.

**O que fazer:** TIRAR a marca. Um `xfail` que nunca falha anuncia um defeito que ele não demonstra
— quem ler o `reason` vai acreditar que o caso está coberto e monitorado, e não está. A evidência
de produção vai pro documento que gente lê (PLANO/HANDOFF/spec), e o teste fica asserindo só o que
de fato prova, com o limite escrito no docstring.

🪤 O motivo mais comum de não reproduzir é a **fixture pequena demais**: uma confusão entre entidades
vizinhas precisa da densidade do catálogo real (dezenas de itens que compartilham token e rótulo).
Com 6 ou 9 itens o modelo acerta.

Regra irmã, e vale mais que a economia de um teste vermelho: **nunca enfraquecer um assert para
acomodar variância de LLM**. Golden que reprova vira `xfail` com motivo ESCRITO e frente própria —
jamais um `>=`, um `in`, ou uma tolerância "por robustez". Foi um `>= 1` "por robustez" que deixou um
pedido de 3 itens chegar ao banco com 2.
