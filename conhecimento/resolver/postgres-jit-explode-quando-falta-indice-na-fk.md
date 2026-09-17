## Query 150x mais lenta sem o trabalho mudar: JIT do Postgres compila porque o custo ESTIMADO estourou, e a causa é índice faltando na FK {#postgres-jit-explode-quando-falta-indice-na-fk}

tags: postgres, jit, jit_above_cost, explain analyze, indice faltando, foreign key, parent_id, seq scan, exists correlacionado, dashboard lento, plexco tasks, migration concurrently

**Sintoma:** uma cláusula nova (EXISTS correlacionado sobre a mesma tabela, do tipo "a linha tem
filha pendente?") mede **1309 ms** em produção, enquanto a versão anterior media 8,7 ms. O
`EXPLAIN ANALYZE` mostra `Execution Time` pequeno (~5 ms de trabalho real) e um bloco
`JIT: Timing: Generation… Emission…` somando quase tudo (1834 ms no caso medido). Se o endpoint faz N
dessas por request (um dashboard com ~10 indicadores), a tela vai a ~13 s — e o profile aponta "a
query nova", não "falta índice", o que manda a investigação para o lado errado (reescrever SQL,
trocar EXISTS por JOIN, materializar).

**Causa raiz:** o JIT do Postgres liga por CUSTO ESTIMADO, não por tempo real
(`jit_above_cost`, default 100000). Sem índice na coluna de FK usada pela subconsulta
(ex.: `tasks.parent_id`), o planner só tem Seq Scan para "filhas de X"; o custo estimado do plano
inteiro estoura o limiar e o PG **compila** a query antes de executá-la. A compilação custa ordens de
grandeza mais que a execução. O mesmo SQL, com índice, cai abaixo do limiar, não compila e roda em
~5 ms — mais rápido que a cláusula antiga que ele substituiu.

Detalhe que engana: FK **não cria índice** no Postgres (diferente do MySQL/InnoDB). Uma tabela pode
ter `parent_id REFERENCES tasks(id)` há anos, com todas as queries rápidas, até alguém escrever a
primeira que pergunta "quem são os filhos de cada linha".

**Como confirmar em 2 minutos (só leitura):**
1. `EXPLAIN (ANALYZE, BUFFERS)` da query. Se aparecer bloco `JIT:` com Generation/Emission grandes e
   `Execution Time` pequeno em comparação, é isto.
2. Confirme com `SET jit = off;` antes do EXPLAIN: se o tempo despenca, o trabalho nunca foi o
   problema.
3. Liste os índices da tabela (`\d tabela` ou `pg_indexes`) e procure a coluna da subconsulta.

**Conserto:** índice na coluna da FK, incluindo no índice as colunas do filtro da subconsulta
(`(parent_id, completed_at)` quando a pergunta é "filha PENDENTE"). Meça antes e depois **em
produção** criando o índice `CONCURRENTLY`, medindo e dropando `CONCURRENTLY` — é reversível e não
trava escrita.

`SET jit = off` no servidor **não** é o conserto: some o sintoma e deixa a query lenta pagando Seq
Scan em toda leitura.

**Armadilha da migration** (ver também o gotcha de `CREATE INDEX CONCURRENTLY`): `CONCURRENTLY IF NOT
EXISTS` checa só o NOME. Se um build anterior falhou no meio, fica um índice `indisvalid = false` que
não é usado pelo planner e faz o retry virar no-op — o deploy parece ok e a lentidão volta. Confira
depois de migrar:
`SELECT indisvalid FROM pg_index WHERE indexrelid = 'ix_nome'::regclass;` — se der `f`,
`DROP INDEX CONCURRENTLY ix_nome;` e rode de novo.

Medido em 2026-09-17 no Plexco Tasks (`mine_step_membership_clause` / `GET /dashboard/summary`):
1309 ms → 5,2 ms com `ix_tasks_parent_completed (parent_id, completed_at)`, migration 110.
