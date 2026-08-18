## Subir uma migration Alembic {#migration-alembic}

`tags: alembic, migration, schema, postgres, banco, upgrade, R6`

**Quando:** criar/alterar tabela (gate `[0]→[1-S]` do feature-flow).

**Passos:**
1. Gere a revision: `alembic revision -m "descricao"` (ou `--autogenerate` se os models batem).
2. Revise o `upgrade()`/`downgrade()` gerado — autogenerate erra em índices/enums.
3. Aplique: `alembic upgrade head`.
4. Verifique a tabela existe: `psql -c "\d nova_tabela"`.
5. Atualize o PLANO → `[1-S]`.

**Armadilhas:** SQL bruto sem Alembic = violação R6 (CRITICAL no review); sempre ter `downgrade`
rastreável; rodar em pasta sensível (`migrations/`) escala o review pra duplo/triplo. Se a row **já
existe em prod** (inserida à mão num incidente), veja [migration de backfill](migration-backfill.md) —
a regra do `downgrade` simétrico se INVERTE ali.
