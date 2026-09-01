## Guarda idempotente de migration (`IF NOT EXISTS ... pg_constraint`) não escopada por schema engana fixture de teste isolado {#guarda-idempotente-de-migration-nao-escopada-por-schema-engana-fixture-isolado}

`tags: postgres, pg_constraint, schema isolado, fixture de teste, ON CONFLICT, idempotência de migration, search_path, probe schema`

**Sintoma:** um fixture de teste que replica statements reais de uma migration (`_upgrade_statements`,
padrão já estabelecido neste repo — extrai `op.execute(...)` do arquivo `.py` real e roda contra um
schema `probe_<uuid>` isolado) cria a tabela e suas colunas com sucesso, mas uma constraint `UNIQUE`
que a MESMA migration deveria criar simplesmente não aparece no schema isolado — sem erro nenhum. O
código que depende dela (`INSERT ... ON CONFLICT (colunas)`) falha depois, em runtime, com
`asyncpg.exceptions.InvalidColumnReferenceError: there is no unique or exclusion constraint matching
the ON CONFLICT specification`.

**Causa raiz:** a guarda de idempotência da migration (para poder rodar `alembic upgrade` de novo sem
duplicar) tipicamente é:

```sql
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'nome_da_constraint'
    ) THEN
        ALTER TABLE tabela ADD CONSTRAINT nome_da_constraint UNIQUE (...);
    END IF;
END $$;
```

`pg_constraint.conname` é um catálogo **do banco inteiro**, não por schema — a consulta acima não
junta com `pg_class`/`pg_namespace` pra restringir à tabela do schema atual. Em produção isso nunca
importa (só existe UMA tabela com esse nome, num schema só). Mas um fixture de teste que roda a MESMA
migration dentro de um schema `probe_xxx` — ao lado de uma produção real que JÁ TEM essa constraint
no schema de sempre — encontra um "já existe" que não é sobre o schema isolado: é sobre a tabela real
de produção. A guarda conclui "não precisa criar" e pula, silenciosamente, dentro do schema isolado
onde ela realmente faltava.

**Por que passa despercebido:** a tabela e as colunas se criam normalmente (o `CREATE TABLE
IF NOT EXISTS`/`ALTER TABLE ADD COLUMN IF NOT EXISTS` resolvem contra o schema atual via
`search_path`, então esses funcionam). Só a constraint falha, e só aparece quando algum código que
depende dela (`ON CONFLICT`) roda pela primeira vez contra esse fixture — o que pode ser numa task
POSTERIOR à que criou/testou a migration em si (a task que só testa "as colunas existem" nunca
dispara o `ON CONFLICT`, então nunca vê o problema).

**Solução:** no fixture de teste, depois de replicar os statements reais da migration, adicionar uma
segunda guarda **escopada ao schema atual**, redundante de propósito:

```sql
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE c.conname = 'nome_da_constraint'
          AND n.nspname = current_schema()
    ) THEN
        ALTER TABLE tabela ADD CONSTRAINT nome_da_constraint UNIQUE (...);
    END IF;
END $$;
```

Não editar a migration original (ela já rodou em produção — mexer nela não muda nada lá, só quebra a
suposição de que uma migration aplicada é imutável). O fix mora no fixture de teste, que é o único
lugar onde a ambiguidade schema-vs-database-wide realmente aparece.

**Ref:** Paid Media Automation, fila #7 (`docs/superpowers/plans/2026-09-01-importacao-local-hubspot-dre.md`),
Task 3, achado ao rodar `test_crm_hubspot_persistence.py` pela primeira vez contra Postgres real
dentro do container `tracking` de produção (a checagem local só via `SKIPPED`, nunca teria pego isso
— só a verificação contra Postgres real revelou o defeito). Migration afetada:
`0007_hubspot_attribution.py` (`uq_crm_deals_tenant_crm_deal`), fixture:
`services/tracking/tests/conftest.py::db_session_migrado_ate_0048`.
