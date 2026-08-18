## `DROP COLUMN` no rollback falha: uma view `SELECT *` depende da coluna nova {#down-migration-view-select-star}

tags: migration down, rollback, drop column, view depends on column, select star, cascade, orders_real, downgrade nao testado

**Sintoma:** o `up` da migration aplica limpo, mas o `down` estoura: `ERROR: cannot drop column X of table T because other objects depend on it / DETAIL: view V depends on column X`. Só aparece se você **rodar o down de verdade** — quem só lê o SQL não vê.

**Causa raiz:** views criadas como `SELECT * FROM tabela` **congelam as colunas na criação**, mas se a view for recriada (`CREATE OR REPLACE`) em algum momento DEPOIS de a coluna existir, ela passa a depender dela. Aí o `DROP COLUMN` seco fica bloqueado. A dependência depende da ORDEM histórica das migrations naquele banco — então pode falhar em prod e passar num banco fresco (ou o contrário).

**Solução:** no `down`, **derrubar a view, tirar a coluna e RECRIAR a view** com a definição da migration que é a fonte dela. ⚠️ **Nunca `DROP COLUMN ... CASCADE`**: "resolve" o erro e deixa o banco SEM a view — quebra consultas dependentes muito depois, longe da causa. Prove o ciclo completo em banco efêmero: **fresh → up → down → up → up** (a última repetição prova idempotência).

**Ref:** tiatendo mig 105 vs view `orders_real` (2026-07-26); `execution/database/migrations/105_nightly_reset_down.sql`. Parente de [#migration-numero-reciclado](migration-numero-reciclado.md).

---

---
