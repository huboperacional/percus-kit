## View `SELECT *` congela colunas na criação — prod "funciona" e instalação fresca quebra (e a suíte verde não te conta) {#view-select-star-congela-colunas}

`tags: postgres, view, SELECT *, CREATE OR REPLACE VIEW, migration, instalacao fresca, fresh install, schema drift, column does not exist, schema_migrations, ledger de migration, idempotente, testes skipped em silencio, suite verde falsa, pg efemero, pgvector`

**Sintoma:** validação de feature nova em pg efêmero (instalação FRESCA via `setupDatabase()`): `column o.payment_method does not exist` num caminho central (`listUnpaid`), mais fixtures inserindo colunas inexistentes (`tenants.company_name`). Em PROD tudo funciona há semanas. A tabela TEM a coluna; a **view** (`orders_real AS SELECT * FROM orders`, criada na migration 041) não — view congela o conjunto de colunas NA CRIAÇÃO, e a coluna nasceu na 068.

**Causa (dupla):**
1. **Era pré-ledger mascarou o drift:** até o ledger `schema_migrations` existir (2026-07-05 no tiatendo), toda migration re-executava idempotente a cada deploy — o `CREATE OR REPLACE VIEW` da 041 se re-aplicava e "via" as colunas novas. Com o ledger, cada migration roda 1× na ordem → instalação fresca congela a view pré-068. **Prod e fresh divergem sem ninguém mudar uma linha.**
2. **A suíte "verde" não provava nada disso:** o guard de segurança (dbSafety esvazia DSN sem "test" no nome) fez os `needs_db` PULAREM em silêncio em toda máquina local — "4533 passed / 0 failed" com o coração de banco não-verificado. Fixtures fósseis (colunas de um schema antigo de outro produto) sobreviveram meses assim.

**Solução:**
1. Migration nova que re-emite o `CREATE OR REPLACE VIEW` (re-congela com as colunas atuais; append de colunas no fim é permitido pelo Postgres, prefixo preservado porque a view veio de `SELECT *` da MESMA tabela). Em prod tende a ser no-op.
2. Grep de auditoria: `CREATE .*VIEW` + `SELECT \*` nas migrations — toda view assim é uma bomba de fresh-install se a tabela ganhar coluna depois.
3. O número "X passed" de suíte só vale com a contagem de SKIPPED ao lado; gate real de feature de banco = pg efêmero (pgvector!) + `setupDatabase()` + pytest no container. Baseline pra separar "eu quebrei" de "já estava quebrado": mesmos testes com o código DA IMAGEM de prod, montando só `tests/` por cima.

**Ref:** tiatendo, 2026-07-20, Task 7 da venda manual (migration `101_refresh_orders_real_view.sql`). Memória: `project-venda-manual-caixa-2026-07-20`.
