## Índice/constraint criado por `op.execute()` na migration é invisível ao `Base.metadata.create_all()` {#indice-de-banco-por-op-execute-invisivel-ao-metadata}

`tags: sqlalchemy, alembic, migration, sqlite, postgresql, indice parcial, partial index, create_all, teste que nao testa nada, race condition, suite e producao montam schemas diferentes`

**Contexto:** projeto com Postgres em produção via `alembic upgrade head` e suíte de testes que
monta o schema via `Base.metadata.create_all()` (SQLite ou Postgres de teste) — padrão comum
quando a suíte precisa ser rápida e não pode depender de rodar a cadeia de migrations inteira a
cada execução. Um índice único **parcial** (`CREATE UNIQUE INDEX ... WHERE tipo = 'x'`) foi
escrito como `op.execute(...)` numa migration nova, pra fechar uma corrida (duas transações
concorrentes ambas veem "não existe ainda" antes de qualquer uma commitar, e as duas inserem).

**Causa raiz:** `op.execute()` é DDL bruto, arbitrário, sem representação em objeto Python
nenhum. `Base.metadata.create_all()` **nunca lê `op.execute()`** — só lê `Table`/`Column`/
`Constraint`/`Index` declarados no modelo ORM. Um teste que sabotava a guarda (dois `INSERT`
diretos, bypassando o caso de uso) **passou verde tanto com a proteção quanto sem ela** — não
sabotou nada de verdade, porque o índice nunca existiu na suíte pra começo de conversa.

**Por que isto é pior que a maioria dos casos de "modelo × migration divergem":** guardas de
COLUNA (nome, tipo, largura) geralmente já têm teste dedicado comparando os dois lados
(`Base.metadata` vs DDL das migrations, offline). Índice/trigger/constraint criado por SQL bruto
está **fora do raio dessas guardas** — elas comparam colunas, não os efeitos colaterais de um
`op.execute()`. Isto é invisível não só à suíte, mas à própria guarda que existe pra achar esse
tipo de divergência.

**Diagnóstico:** depois de escrever qualquer guarda de banco (índice único, trigger, constraint
via SQL bruto), **tente quebrá-la de propósito** contra a suíte (dois `INSERT` diretos bypassando
a camada de aplicação) — se o teste sabotado passa igual com e sem a proteção presente no código,
a guarda não está sendo exercida pela suíte, mesmo que exista de verdade em produção.

**Fix:** declarar o MESMO objeto também no modelo SQLAlchemy, não só na migration.
Para índice parcial: `sa.Index(nome, coluna, unique=True, postgresql_where=text("..."),
sqlite_where=text("..."))` no `__table_args__` — os dois dialect kwargs, porque a suíte
(SQLite) e a produção (Postgres) precisam da mesma regra, cada um na sintaxe do próprio
dialeto. Os dois lugares (migration com SQL bruto para o deploy real + `Index` no modelo para
`create_all()` da suíte) precisam existir e dizer a MESMA coisa — nenhum dos dois sozinho basta.

**Ref:** Empresa Milionária, Liquidação Fase 1 (2026-08-27) — índice
`ux_conta_compensacao_por_empresa`, achado pelo review cross-provider antes do commit, não em
produção.
