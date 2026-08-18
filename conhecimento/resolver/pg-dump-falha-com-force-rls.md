## `pg_dump` falha e `DELETE` é recusado num banco com `FORCE ROW LEVEL SECURITY` {#pg-dump-falha-com-force-rls}

tags: RLS, row level security, FORCE, pg_dump, backup, restore, DELETE, FK, foreign key, FOR KEY SHARE, permission denied, REVOKE, imutabilidade, timeline, LGPD, exclusao de dados, multi-tenant, superuser

Duas consequências operacionais do `FORCE ROW LEVEL SECURITY` que só aparecem meses depois
de a política ser escrita, e nenhuma delas é bug — são o desenho cobrando.

### 1. `pg_dump` como dono da tabela **falha**

```
pg_dump: error: query would be affected by row-level security policy for table "baixas"
HINT: To disable the policy for the table's owner, use ALTER TABLE NO FORCE ROW LEVEL SECURITY.
```

Sem `FORCE`, o dono ignora a política e o dump passa. **Com** `FORCE` — que é o que torna a
RLS real, ver `#rls-sem-force-dono-ignora-politica` — o dono obedece, e um dump é uma leitura
sem contexto de tenant declarado. Logo: nenhuma linha, ou erro.

**Solução:** dumpe como **superuser** (`-U postgres`), a única role que ignora RLS. Não
desligue o `FORCE` para fazer backup — isso troca uma inconveniência de operação por um furo
de isolamento permanente.

```bash
docker exec "$container" sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U postgres -d meu_banco -Fc' > arquivo.dump
```

⚠️ **O modo de falhar silencioso é o perigoso.** Um script de backup com `set +e`, ou sem
checar tamanho mínimo do arquivo, grava **dump vazio** todo dia e ninguém percebe até
precisar restaurar. Sempre: checar o exit code E um piso de bytes, e apagar o arquivo se
qualquer um reprovar.

### 2. `DELETE` na tabela-pai é recusado se alguma filha teve `UPDATE/DELETE` revogado

```
ERROR: permission denied for table eventos_titulo
CONTEXT: SQL statement "SELECT 1 FROM ONLY "public"."eventos_titulo" x
         WHERE $1 OPERATOR(pg_catalog.=) "empresa_id" FOR KEY SHARE OF x"
```

Padrão comum em auditoria/timeline: `REVOKE UPDATE, DELETE` numa tabela de eventos para
torná-la imutável no nível do banco. O efeito colateral: apagar uma linha **referenciada**
por ela dispara a checagem de integridade, que faz `SELECT ... FOR KEY SHARE` na filha para
travá-la — e **lock de linha exige privilégio de UPDATE**. Sem ele, a exclusão do pai morre.

Não é a RLS desta vez, é o `REVOKE` — mas anda junto com ela porque as duas nascem da mesma
decisão de endurecer o banco.

**Solução para uma exclusão pontual** — conceder e devolver **dentro da mesma transação**,
já que `GRANT`/`REVOKE` são transacionais no PostgreSQL, então a janela não existe fora dela
e um erro no meio desfaz tudo junto:

```sql
BEGIN;
GRANT UPDATE, DELETE ON eventos_titulo TO app_user;
DELETE FROM ...;            -- filhos, depois pais, na ordem das FKs
REVOKE UPDATE, DELETE ON eventos_titulo FROM app_user;
COMMIT;
```

Confira os privilégios **depois** do commit, em vez de confiar: um `REVOKE` que não rodou
deixa a imutabilidade desligada em produção sem nenhum sinal.

⚠️ **Se o produto tem requisito de exclusão de dados (LGPD, "apagar minha conta",
encerramento de contrato), isto é bloqueio de requisito e não curiosidade de operação:** o
código da aplicação **não consegue** apagar a entidade-raiz. Descubra na especificação, não
no primeiro cancelamento. Caminhos: role de manutenção separada com o privilégio, um
`SECURITY DEFINER` que faça a exclusão, ou aceitar anonimização em vez de exclusão física —
os três são decisão de arquitetura, e a hora de tomá-la é quando o `REVOKE` é escrito.

**Ref:** Empresa Milionária, 2026-08-17 — os dois achados apareceram na mesma tarefa (apagar
duas empresas duplicadas de produção). O `FORCE` e o `REVOKE` vieram da Task 12/ADR-0003 e
estão certos; o que faltava era saber o que eles custam depois. Entradas irmãs:
`#rls-sem-force-dono-ignora-politica`, `#psql-sem-contexto-mede-rls-nao-o-dado`.
