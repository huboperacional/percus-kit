## Migração de schema vai subir e o entrypoint roda `alembic upgrade || continuing` (fail-open) {#migracao-entrypoint-fail-open}

`tags: migration alembic entrypoint fail-open upgrade schema deploy silencioso`

**Sintoma / risco:** o entrypoint do container roda a migração no start, mas **fail-open**:

```sh
alembic upgrade head || echo "[entrypoint] WARNING: alembic upgrade failed (continuing)"
exec "$@"
```

A ordem dentro do container está certa (migração antes do app). O problema é o `||`: se a migração
falhar (permissão, lock, DDL inválido), o container **sobe assim mesmo** — e o ORM da imagem nova
mapeia colunas que não existem → `select(Model)` estoura → **derruba TODO o tráfego**, não só a
feature nova. Um WARNING no log é a única pista.

**Não resolve:** "rodar a migração manualmente antes do deploy" — o arquivo da migração só existe
**na imagem nova**; o container velho não a tem. E `docker service update` não te dá um hook entre
"pull" e "start".

**Resolve — prove o DDL ANTES, contra o banco real, sem persistir:** rode o DDL de verdade dentro de
uma transação e faça `ROLLBACK`. Se faltar permissão/o SQL for inválido, você descobre agora e não
no fail-open.

```python
tx = conn.transaction(); await tx.start()
try:
    await conn.execute("ALTER TABLE t ADD COLUMN IF NOT EXISTS c BOOLEAN NOT NULL DEFAULT false")
    await conn.execute("UPDATE t SET c = (...)")          # o backfill real
    print(await conn.fetchval("SELECT count(*) FROM t WHERE c"))   # confere o resultado
finally:
    await tx.rollback()                                    # nada persistido
```

Cheque junto: `SELECT current_user`, `SELECT tableowner FROM pg_tables WHERE tablename='...'`
(o erro clássico é "must be owner of table"), `SELECT version_num FROM alembic_version`, e se o env
que gateia a migração (ex.: `DATABASE_URL_SYNC`) está setado — **se não estiver, a migração nem roda**
e o app sobe com ORM quebrado do mesmo jeito.

**Depois do deploy, verifique o efeito, não o "convergiu":** `docker service logs | grep 'Running upgrade'`
+ probe do `alembic_version` + probe do backfill (a invariante que ele deveria preservar).

**Corolário:** o fail-open é **pré-existente e sobrevive** ao seu deploy. Provar o DDL protege ESTA
migração, não a próxima. Registre como follow-up (trocar por `set -e`/healthcheck) em vez de dar por
resolvido.

**Ref:** Paid Media `services/tracking/entrypoint.sh:22`, migração 0020 (cont.104 2026-07-15).
Achado pelo Cross-Claude no milestone-review — o DeepSeek não pegou.
