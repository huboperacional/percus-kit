## Rollback de migration com dump: restore atômico em duas etapas, senha por stdin {#rollback-de-migration-restore-atomico-em-duas-etapas}

`tags: rollback, migration, pg_restore, psql, single transaction, ON_ERROR_STOP, pipe, EOF, commit parcial, pgpass, fe_sendauth, senha, stdin, docker exec, swarm, R5, R24, ensaio`

**Quando usar:** deploy cuja migration derruba coluna ou enum. Voltar só a imagem sobre o banco
migrado quebra o app; o rollback passa a ser "restaurar o dump de antes **e** voltar a imagem".

**A armadilha do pipe.** Isto parece atômico e não é:

```bash
{ echo 'DROP TABLE ...;'; pg_restore --clean --if-exists -f - antes.dump; } | psql -1 -v ON_ERROR_STOP=1 ...
```

Se o `pg_restore` morrer no meio, o `psql` recebe fim de arquivo — não erro — e dá `COMMIT` no
pedaço que chegou. O `ON_ERROR_STOP` só para em erro de SQL.

**Forma certa, em duas etapas:**

```bash
# 1. gera o SQL completo; não toca o banco
docker exec "$PG" pg_restore --clean --if-exists -f /tmp/rollback.sql /tmp/antes.dump
docker exec "$PG" sh -c '{ echo "DROP TABLE IF EXISTS \"tabela_nova\" CASCADE;"; cat /tmp/rollback.sql; } > /tmp/rollback-completo.sql'
# 2. aplica tudo numa transação; qualquer erro desfaz o DROP junto
docker exec -e PGPASSFILE=/tmp/.pgpass "$PG" psql -1 -v ON_ERROR_STOP=1 -U <usuario> -d <banco> -f /tmp/rollback-completo.sql
```

O `DROP TABLE` da tabela criada pela migration vem antes porque o dump não a conhece: o `--clean`
só apaga o que está no dump, e a tabela que sobrasse faria o próximo deploy falhar no `CREATE TABLE`.

**Senha: o Postgres pode pedir senha até pelo socket local, inclusive para o superusuário**
(`fe_sendauth: no password supplied`). Tire a senha do secret do app e entregue por stdin num
`.pgpass` 600 dentro do contêiner do Postgres — nunca na linha de comando, nunca na tela:

```bash
docker exec "$CID" sh -c 'set -a; . /run/secrets/<env>; set +a; printf %s "$DATABASE_URL"' \
  | sed -E 's#^[^:]+://[^:]+:(.*)@[^@]*$#\1#; s/[\\:]/\\&/g' \
  | docker exec -i "$PG" sh -c 'umask 077; read -r s; printf "*:*:*:<usuario>:%s\n" "$s" > /tmp/.pgpass'
```

Remova o `.pgpass` no fim do deploy. Se a senha vier com `%xx` na URL, decodifique antes — um
`select 1` pelo `.pgpass` antes do backup pega isso cedo.

**Antes do passo destrutivo (R5):** pare o app primeiro (`docker service scale <servico>=0`,
reversível), só então conte o que o restore descartaria (linhas criadas depois da hora UTC do
backup) e siga só com o "sim" do operador. Contar com o app no ar deixa uma janela em que o que foi
gravado depois da contagem some sem entrar no número mostrado.

**Ensaie antes de subir (R24):** Postgres descartável da mesma versão, em rede `--internal`, com
cópia do dump real. Aplique a migration com a imagem nova (com o entrypoint real, não
`--entrypoint sh`), rode o rollback acima e confirme que `prisma migrate status` da imagem **velha**
diz "up to date". Remova contêiner e rede no fim.

**Ref:** LiliCalc, deploy da Fase 8 (2026-09-14): o pipe foi trocado pelas duas etapas antes de
produção; ensaio com 657 linhas de SQL e estado idêntico ao do backup. Relacionado:
[git-archive-windows-crlf-mata-entrypoint](../resolver/git-archive-windows-crlf-mata-entrypoint.md),
[swarm-converged-e-rollback](../resolver/swarm-converged-e-rollback.md),
[latest-anula-rollback-do-swarm](../resolver/latest-anula-rollback-do-swarm.md).
