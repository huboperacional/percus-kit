## Deadlock por ordem de lock ditada pelo corpo da requisição {#deadlock-por-ordem-de-lock-em-lote-do-corpo}

`tags: postgres, deadlock, select for update, lock ordering, lote, transacao, sqlalchemy, financeiro, atomicidade, sqlite mente`

**Contexto:** endpoint que recebe uma **lista** de itens e aplica cada um numa transação só,
reusando um caso de uso que já fazia `SELECT ... FOR UPDATE` do recurso. Funciona em todo teste,
funciona no uso normal, e **deadlocka em produção sob concorrência**.

**Causa raiz:** a ordem em que os locks são adquiridos passa a ser **a ordem que o cliente
mandou no corpo**. Duas requisições simultâneas, uma com `[A, B]` e outra com `[B, A]`, travam em
ordem oposta: cada uma segura o que a outra espera. O PostgreSQL detecta e **mata uma delas** —
no meio de uma escrita de dinheiro, com metade do trabalho feito e um erro de driver subindo como
500.

**Por que passa despercebido:** o caso de uso reusado está correto e em produção há meses. Ele
trava **um** recurso por chamada, e com um recurso não existe ordem. O defeito nasce da
composição, não da peça — e não aparece em teste nenhum, porque teste de endpoint é sequencial.

**Agravante de medição:** em **SQLite** — onde a maioria das suítes roda — `FOR UPDATE` é
**ignorado sem erro**. A suíte fica verde e não tem como ficar vermelha. Verde aqui não é
evidência de nada; o que vale é o plano do PostgreSQL.

**Duas correções, e a diferença entre elas importa:**

1. **Ordenar o laço** pelo id antes de processar. Barato, sem consulta extra. Custo escondido:
   a ordem de processamento deixa de ser a do corpo, então **qual item falha primeiro muda** — e
   se a resposta devolve os itens criados, ela precisa ser remapeada para a ordem original, que é
   contrato com o cliente.
2. **Pré-travar tudo numa consulta só**, `WHERE id IN (...) ORDER BY id FOR UPDATE`, antes de
   aplicar qualquer item. Uma ida a mais ao banco, e o laço fica **livre para seguir a ordem do
   corpo** — a resposta não precisa de remapeamento e o erro reportado é o da primeira linha que
   o usuário escreveu. No PostgreSQL o nó `LockRows` fica **acima** do `Sort`, então os locks
   saem na ordem pedida. Relock do que já se tem na mesma transação não espera nada, então o
   `FOR UPDATE` de dentro do caso de uso continua e não custa.

**Regra:** *ordem de aquisição de lock nunca pode ser um dado de entrada.* Se o cliente escolhe a
ordem, o cliente escolhe se haverá deadlock. Sempre que um laço trava N recursos, imponha uma
ordem total do lado do servidor — por id, e não por qualquer coisa que o corpo diga.

⚠️ **Cuidado ao consultar o conselho sobre isto:** a objeção "é redundante, o caso de uso já faz
`FOR UPDATE`" soa razoável e está errada — travar por item *na ordem do corpo* é exatamente a
origem do deadlock, não a proteção contra ele. Ver
[[conselho-acerta-a-conclusao-e-erra-a-premissa]].
