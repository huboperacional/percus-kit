## Rodar testes que dropam tabelas contra Postgres efêmero isolado (sem Docker/PG local, nunca prod) {#pg-efemero-testes-destrutivos}

`tags: pytest, integração, TEST_DATABASE_URL, postgres, pgvector, docker swarm, throwaway, ephemeral, setupDatabase, runMigrations, ledger, cash, fixture drop table, in-container, lead_profiles does not exist, working-tree mount`

**Contexto:** fixtures de integração (ledger/caixa) fazem `DROP TABLE ... CASCADE` + `runMigrations()` — precisam de Postgres real mas NUNCA podem tocar prod. Máquina local sem Docker nem PG; a imagem de prod (`ads4pros/tiatendo:0.20x`) não tem pytest e carrega o `execution/` do último deploy (não o working-tree com o código novo/uncommitted).

**Procedimento (via ssh no VPS que tem Docker):**
1. Rede + PG descartável: `docker network create ledgertest-net`; `docker run -d --name pg-ledger --network ledgertest-net -e POSTGRES_PASSWORD=test -e POSTGRES_DB=tiatendo_ledger_test pgvector/pgvector:pg17`; esperar `docker exec pg-ledger pg_isready -U postgres`.
2. **Pré-buildar o schema base ANTES do pytest** — o fixture só dropa+runMigrations e ASSUME a base existente: `docker run --rm --network ledgertest-net -v /root/wt/execution:/app/execution -e DATABASE_URL=<dsn> <img> python -c "import asyncio; from execution.database.setupDb import setupDatabase; asyncio.run(setupDatabase())"`. Sem isso: `relation "lead_profiles" does not exist` (a base vem do `setupDb.SCHEMA`, NÃO das migrations numeradas 030+).
3. Rodar pytest num throwaway com o **working-tree montado** (`-v /root/wt/execution:/app/execution -v .../tests:/app/tests -v .../scripts:/app/scripts`) + `TEST_DATABASE_URL`=`DATABASE_URL`=dsn efêmero + `pip install -q pytest pytest-asyncio` (não vem na imagem prod).
4. Cleanup SEMPRE (mesmo em falha): `docker rm -f pg-ledger; docker network rm ledgertest-net`.

**Gotchas:** (a) working-tree via `tar cf - --exclude=__pycache__ execution tests scripts | ssh 'cd /root/wt && tar xf -'` — `git archive HEAD` NÃO pega uncommitted; (b) `docker run ... | tail` mascara o exit-code do pytest (vira o do `tail`) → redirecionar pra arquivo, checar `$?` e grep do sumário; (c) guard nos fixtures: `pytest.skip` se o nome do db do dsn não contém "test" (defesa contra apontar pra prod); (d) ao delta-deployar, incluir `scripts/` no COPY se o operador for rodar backfill (o delta que só copia `execution/` deixa `scripts/backfillLedger` de fora).

**Ref:** tiatendo ledger F1+F2 `[5-T]` (2026-07-14); `tests/restaurant/test_ledgerService_integration.py`, `test_ledgerDualWrite.py`. `project-ledger-t3-f1-2026-07-14`
