## Sabotagem prova a PRIMEIRA asserção, não o teste {#sabotagem-prova-a-primeira-assercao-nao-o-teste}

`tags: guarda, sabotagem, mutation testing, falso verde, vacuidade, assercao, granularidade, denominador, cobertura, disciplina`

**Contexto.** Sabotar o alvo e exigir vermelho é a disciplina que separa guarda real de guarda
decorativa. Mas o vermelho tem **granularidade de uma asserção**: o `assert` que falha **aborta o
teste**, e todas as asserções abaixo dele **nunca executam**. Contar sabotagens por ARQUIVO ou por
TESTE e concluir "as guardas estão provadas" é usar uma medição como prova de outra que não
aconteceu — a mesma forma do defeito que a sabotagem existe para pegar.

**Caso medido (2026-09-06, Empresa Milionária).** Numa noite entreguei **22 asserções** com **8
sabotagens**. Cada sabotagem derrubou exatamente um teste, e por isso parecia cobertura boa. Ao
contar por asserção: **14 nunca foram exercidas**. No teste do job de anonimização são 7 asserções
em sequência e a sabotagem do `rollback` derruba a **primeira** (`anonimizadaEm is None`); as de
baixo (`razaoSocial`, `email`, `contagens`) seguem sem prova alguma — são corroborantes da mesma
condição, o que as torna defensáveis, e *defensável* é justamente o que não é medição.

**Como alcançar as de baixo.** É preciso uma sabotagem que **passe pelas primeiras**. No caso
acima, o dublê que injetava a falha **antes** de o caso de uso escrever não tinha nada pendente na
transação: o `rollback` não tinha o que desfazer, e a asserção "a empresa ficou intacta" passava
por vazio — trocar `rollback` por `commit` deixava os 3 testes **verdes**. Movendo a falha para
**depois** da escrita, o `rollback` virou a única coisa que separava o registro de ficar pela
metade, e a sabotagem passou a morder.

🔴 **O corolário que inverte o veredito:** sabotagem que **não** derruba nem sempre acusa o teste —
às vezes acusa o **conserto incompleto**. Na mesma noite, uma guarda nova passou `9 passed` com o
conserto que ela media sabotado, porque a função que restaurava o contexto do job deixava uma
variável de sessão valendo o último valor do laço anterior: o trecho seguinte funcionava **por
acidente**. Só depois de completar o conserto a sabotagem derrubou o teste. Antes de reescrever a
guarda, pergunte se o alvo ainda está sendo alcançado por outro caminho.

**Procedimento.**
1. Sabote **uma asserção por vez**, não um arquivo por vez.
2. Confirme que a sabotagem **foi aplicada**, imprimindo a linha alterada no destino —
   "rodei e deu vermelho" sem isso não distingue sabotagem que mordeu de sabotagem que não chegou.
3. Exija que caia **a asserção que você quis medir**, não qualquer vermelho: sabotagens diferentes
   derrubando sempre o mesmo teste são uma asserção provada, não N.
4. Para as que sobrarem, **declare o denominador**: *"22 asserções, 8 sabotagens, 14 sem
   exercício"*. Nunca escreva "todas provadas": o placar costuma ser medido e o cabeçalho
   escrito de memória — e é o cabeçalho que a próxima sessão lê.

**Relacionados.** [[a-sabotagem-prova-o-que-voce-imaginou]] cobre *quais classes* você amostra;
este cobre *quanto* um vermelho prova. [[guarda-verde-porque-nao-mede-nada]] ·
[[zero-so-vale-como-prova-com-controle-positivo]] ·
[[a-guarda-que-nao-pode-falhar-mora-no-instrumento]]
