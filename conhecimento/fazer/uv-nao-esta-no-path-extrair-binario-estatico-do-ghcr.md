## Rodar `uv sync`/alembic/pytest num Postgres efêmero quando `uv` não está no PATH do host {#uv-nao-esta-no-path-extrair-binario-estatico-do-ghcr}

`tags: uv, astral, docker, pg-real, harness, pytest, alembic, TEST_DATABASE_URL, ci-substituto, static binary, ghcr, python:3.12-slim, VPS`

**Contexto:** projeto Python com `uv.lock` + `[tool.uv] dev-dependencies` (pytest, psycopg2-binary etc.
declarados aí), Dockerfile de produção instala `uv` só DENTRO do build stage via
`COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv` e roda `uv pip install --system`
(sem venv, sem dev-deps). Rodar `which uv` na VPS host retorna vazio — `uv` nunca foi instalado
fora de container nenhum.

**Procedimento** (Postgres efêmero isolado de prod + `uv sync` real, com dev-deps):
1. Rede própria: `docker network create <nome>-net`.
2. Postgres efêmero na rede: `docker run -d --name <nome>-pg --network <nome>-net -e POSTGRES_PASSWORD=test -e POSTGRES_DB=<db> postgres:17`; esperar `docker exec <nome>-pg pg_isready -U postgres`.
3. Extrair o binário estático do `uv` **pro filesystem do HOST** (não dentro de container nenhum):
   `docker create --name uv-src ghcr.io/astral-sh/uv:latest && docker cp uv-src:/uv ./uv-bin && docker rm uv-src && chmod +x ./uv-bin`.
4. Rodar tudo num `python:3.12-slim` throwaway, na MESMA rede do Postgres, com o source E o binário
   bind-montados: `docker run --rm --network <nome>-net -v <source>:/app -v $(pwd)/uv-bin:/usr/local/bin/uv -e DATABASE_URL="postgresql+asyncpg://postgres:test@<nome>-pg:5432/<db>" -w /app python:3.12-slim bash -c "uv sync --quiet && uv run alembic upgrade head && uv run pytest -q"`.
5. Cleanup sempre: `docker rm -f <nome>-pg; docker network rm <nome>-net`.

Passo 4 usa o **nome do container** do Postgres como host (`<nome>-pg:5432`), não `localhost` — são
containers diferentes na mesma rede Docker, não a mesma máquina.

**Gotchas:** (a) uma imagem `postgres:17` recém-criada NÃO tem extensões como `uuid-ossp` — se
alguma migration antiga do histórico depender de `uuid_generate_v4()`, ela quebra antes de chegar
na migration que você quer testar; rode `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";` via
`docker exec <nome>-pg psql -U postgres -d <db> -c '...'` ANTES do alembic se isso acontecer — não
é sinal de que sua migration está errada, é gap de setup do Postgres novo; (b) pytest pode passar
mesmo com o alembic quebrado numa migration ANTIGA, porque fixtures costumam usar
`Base.metadata.create_all()` (via SQLAlchemy models), não o alembic — então "pytest verde" não
prova que a migration aplica do zero; teste os dois separadamente; (c) sempre teste
`alembic downgrade -1` também, não só o upgrade — é rápido e pega migration que esquece de reverter
uma coluna.

**Ref:** Plexco Tasks, feature "tema por organização" (mig 105, 2026-08-31) — 31/31 pytest +
upgrade/downgrade verificados antes do deploy real em produção.
