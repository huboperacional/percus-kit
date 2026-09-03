## Gate `-m postgres`: módulo que monta RECORTE parcial e zera vazio no teardown vaza schema incompleto pro próximo módulo {#gate-postgres-schema-parcial-vaza-para-modulo-seguinte}

`tags: postgres, pytest, fixture, teardown, schema, alembic, create_all, module-scope, R23`

**Contexto:** suíte de testes `-m postgres` com vários módulos, cada um com sua própria fixture de
preparo de schema — alguns via `alembic upgrade head` (schema COMPLETO, é como produção nasce),
outros via `Base.metadata.create_all(tables=recorte)` (RECORTE parcial, prova que o dialeto aceita
o DDL do metadata independente da migration — objetivo de teste DIFERENTE, não um atalho).

**O que ninguém nota:** módulos que fazem `create_all(tables=recorte)` no setup e não têm nenhum
zero-e-remontagem completo no teardown DEIXAM O SCHEMA DO JEITO QUE ESTAVA — se o teardown desse
módulo chama só "zerar/DROP SCHEMA CASCADE" (sem remigrar), o próximo módulo da suíte que **não
tenha fixture de schema própria** (presume herdar um schema já completo de quem rodou antes)
encontra um banco VAZIO em vez das dezenas de tabelas esperadas.

**Sintoma medido (Empresa Milionária, 2026-09-03):** `test_isolamento_fk_postgres.py` era o único
de 7 módulos `postgres` que montava recorte (9-10 tabelas) E zerava (`DROP SCHEMA... CASCADE`) no
teardown sem remigrar. `test_producao_fatia0_postgres.py`/`test_producao_fatia1_postgres.py` não
tinham fixture de schema própria nenhuma — dependiam de herdar o schema completo de quem rodasse
antes. Quando a ordem de coleta colocava o módulo do recorte logo antes, o resultado era "5 failed
com 1 tabela e 5 passed com 60" — a MESMA suíte, dois resultados, dependendo só da ordem.

**Por que não é óbvio:** os outros 6 módulos da suíte JÁ seguiam a convenção certa (zerar E
remigrar completo no SETUP, sem zerar de novo no teardown — então o schema completo sobrevive
naturalmente pro próximo). O módulo do recorte parecia seguir a mesma convenção ("zera no fim,
como os outros fazem no início") mas zerava SEM remontar — a assimetria (zero vazio vs. zero
seguido de upgrade) é fácil de não notar lendo o código de um módulo isolado.

**Fix:** módulo que monta recorte parcial ganha uma função de teardown PRÓPRIA que zera E remigra
o schema INTEIRO (`alembic upgrade head`), nunca só zera. O `zerarSchema` genérico do preparo NÃO
deve mudar para sempre remigrar — se mudasse, `create_all(checkfirst=True)` do próprio módulo do
recorte encontraria as tabelas já criadas pela migration e nunca emitiria o DDL que o teste existe
para provar (o teste passaria vazio, sem nunca ter exercitado o caminho real).

**Detalhe de implementação, se a fixture do recorte for `async def`:** `alembic upgrade head`
aciona `env.py`, que chama `asyncio.run()` por dentro — chamado de dentro de um event loop já
rodando (a fixture async), estoura "asyncio.run() cannot be called from a running event loop".
Sobe pra outra thread com `asyncio.to_thread(funcao_sincrona_do_upgrade, url)`.

**Como confirmar sem banco real:** o comportamento contra Postgres precisa de Postgres de verdade
— mas a FIAÇÃO (ordem zerar→upgrade, restauração de variável de ambiente tipo `ALEMBIC_URL`) se
prova offline com `monkeypatch` nas duas chamadas, sabotando a ordem pra confirmar que a asserção
morde antes de aceitar o verde.

**Relacionado:** nenhum verbete irmão ainda — é a primeira vez que esta classe (fixture de
teardown parcial vs. completo, module-scope) foi medida e nomeada neste canon.
