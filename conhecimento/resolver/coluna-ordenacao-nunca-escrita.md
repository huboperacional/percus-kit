## Coluna usada como critério de ORDENAÇÃO/desempate que ninguém nunca escreveu {#coluna-ordenacao-nunca-escrita}

`tags: ORDER BY, desempate, tiebreak, coluna NULL, last_activity, comentario mente, spec nao implementada, criterio fantasma, NULLS LAST, ordenacao degenera, escolha nao-deterministica`

**Contexto:** existe um `ORDER BY <coluna> DESC NULLS LAST, <fallback>` decidindo algo que
importa (qual org/tenant/registro vence quando há mais de um candidato). O comentário ao lado
descreve a regra em prosa ("last-active wins"), a spec previa preencher a coluna, o model
declara, e há até teste afirmando que a coluna **existe**. Todo mundo cita a regra como fato —
inclusive em devolutiva pra outro time.

**Causa raiz:** **ninguém nunca escreveu a coluna.** A migração criou, a spec prometeu o
`UPDATE`, e o `UPDATE` nunca foi implementado. Com 100% NULL, o `NULLS LAST` joga todo mundo pro
fallback e a ordenação **degenera silenciosamente** no critério seguinte — normalmente
`created_at DESC`, que é "a linha criada por último vence, para sempre", sem relação nenhuma com
uso. O sistema tem um critério fantasma: documentado, testado na existência, morto no efeito.

**Como detectar em 10 segundos:** `grep` por quem faz `UPDATE ... SET <coluna>` / atribui o
campo. Zero ocorrências fora de migração/model/teste-de-existência ⇒ é fantasma. Depois confirme
no banco: `SELECT count(*) FILTER (WHERE <coluna> IS NOT NULL), count(*) FROM <tabela>`.

**Solução:** (a) implemente a escrita **ou** remova o degrau — mas não deixe os dois estados
conviverem; (b) garanta **ordem total** (último degrau único, tipo `id`), senão empate deixa a
decisão pra ordem física das linhas, que muda com `VACUUM`/restore; (c) **cuidado ao ligar a
escrita**: se o critério é auto-reforçado (grava no vencedor), ligar cimenta a primeira escolha
— só torne pegajosa a decisão que teve motivo, nunca a que saiu de empate, ou um bug reversível
vira grudado.

**Regra geral:** *ordenação por coluna só vale como fato depois de ver quem escreve nela.* Vale
para qualquer campo de "última atividade", "último acesso", `daily_time_local` e afins.

**Ref:** Plexco Tasks × Plexco Coach, ADR-0013 (2026-07-23). A coluna passou ~2 meses NULL
enquanto o comentário afirmava o contrário; o efeito real mandaria a tarefa do operador pra org
do cliente dele.
