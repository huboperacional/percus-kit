## Sem `relationship()`, o unit of work NÃO ordena INSERTs entre tabelas pela FK — flush explícito do pai antes do filho {#unit-of-work-sem-relationship-nao-ordena-insert-por-fk}

`tags: sqlalchemy, unit of work, flush, foreign key, fk composta, relationship, insert order, IntegrityError, FOREIGN KEY constraint failed, autoflush, R23`

**Sintoma:** um caso de uso cria pai e filho (ex.: `VersaoFormulario` e as linhas de
`DefinicaoDaVersao` que apontam para ela) na MESMA sessão e chama `flush()` uma vez.
O banco recusa com `FOREIGN KEY constraint failed` (SQLite) ou violação de FK
(Postgres imediato) — **no INSERT do filho, com o pai pendente no mesmo flush**. O
mesmo par inserido "à mão" com dois flushes passa, o que faz o defeito parecer
intermitente ou culpa do savepoint.

**Causa raiz:** o unit of work do SQLAlchemy ordena INSERTs entre TABELAS diferentes
usando as dependências declaradas por **`relationship()`** — não pelas
`ForeignKeyConstraint` da tabela. `sqlalchemy.sql.util.sort_tables()` até devolve a
ordem certa (ele lê as FKs), mas o flush não passa por ele para mappers sem
relacionamento: sem `relationship()`, não há aresta entre os nós de persistência e a
ordem entre as duas tabelas é arbitrária. Num projeto que, por padrão da casa, declara
modelos SEM `relationship()` (FKs compostas explícitas, consultas sempre por
`select`), todo par pai–filho criado no mesmo flush é uma emboscada armada.

**Armadilha dentro da armadilha:** `autoflush=False` (comum em sessão async) esconde o
problema até o pior momento — um `SELECT` no meio do caso de uso não descarrega o pai
pendente, e o flush final carrega as duas tabelas juntas.

**Correção (medida em Empresa Milionária, 2026-08-30, fatia 2b da V2.2):** flush
explícito do PAI antes de `add()` dos filhos, com comentário no ponto dizendo por quê:

```python
session.add(versao)
# A versão PRECISA de flush próprio antes das fotos: os modelos da casa não
# declaram relationship(), e sem ela o unit of work não ordena INSERTs entre
# tabelas pela FK — no mesmo flush, a foto entraria antes da versão.
await session.flush()
session.add_all([DefinicaoDaVersao(versaoId=versao.id, ...) for ...])
```

**Como reconhecer que é ISTO e não FK errada:** inserir o mesmo par com dois flushes
manuais passa; `sort_tables()` das duas tabelas devolve a ordem certa; o statement que
falha (em `erro.__cause__.statement`) é o INSERT do FILHO com params válidos.

**O que NÃO fazer:** adicionar `relationship()` só para consertar a ordem — muda o
padrão do projeto inteiro por causa de um ponto; e não confundir com savepoint:
`begin_nested()` não tem participação (o erro reproduz sem ele).
