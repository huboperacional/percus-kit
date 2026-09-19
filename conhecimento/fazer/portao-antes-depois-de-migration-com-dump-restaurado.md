## Portão antes/depois de migration, sobre dump restaurado {#portao-antes-depois-de-migration-com-dump-restaurado}

`tags: deploy, migration, postgres, docker, prisma, lilicalc, producao, ensaio, portao`

**O problema:** a migration promete não mudar número nenhum de dado já gravado (preço, saldo, total).
Prometer é grátis. Provar exige comparar um retrato de **antes** com um de **depois** — e as duas
tentativas ingênuas falham:

- **Rodar o retrato contra produção antes de migrar** exige que o script já esteja na imagem **que
  está no ar**, e ele nunca está: ele nasceu junto da migration. Rodá-lo a partir da imagem nova
  contra produção significa `docker run` com `--entrypoint` trocado para o entrypoint não migrar
  antes da hora — fazível, mas é comando novo, não ensaiado, na hora de maior risco.
- **Pular o retrato** e confiar no teste local: o banco de desenvolvimento não tem as formas de dado
  que produção tem, e é justo nelas que o preço muda calado.

**O que funciona — e já era a prática, bastava ler o runbook anterior:** o retrato roda **duas vezes
contra uma cópia de produção**, num Postgres descartável, e produção não é tocada até o portão passar.

```sh
# 1. Dump de producao (antes de qualquer DDL).
docker exec "$PG_PROD" sh -c 'pg_dump -Fc "$URL" > /tmp/p.dump'

# 2. Postgres descartavel NA MESMA VERSAO de producao (pg17 != pg16 em detalhe que morde).
docker run -d --name ensaio-pg --network ensaio-net -e POSTGRES_PASSWORD=x -e POSTGRES_DB=app <mesma-imagem-de-producao>

# 3. Esperar pela porta TCP, nunca pelo socket -- ver {#pg-isready-pelo-socket-responde-no-postgres-temporario-do-init}
until docker exec ensaio-pg pg_isready -h 127.0.0.1 -U postgres -d app; do sleep 1; done

# 4. Restaurar COM PARADA. Sem isto, as migrations rodam em banco vazio e o ensaio "passa" sem provar nada.
docker exec ensaio-pg pg_restore -U postgres -d app --no-owner --no-acl /tmp/p.dump || exit 1
#    e conferir as contagens contra producao (3 contas / 5 fichas / 36 insumos, etc.)

# 5. Retrato ANTES: imagem NOVA, banco AINDA nao migrado.
docker run --rm --network ensaio-net -e DATABASE_URL="$URL_ENSAIO" -v /root/saida:/saida \
  --entrypoint /bin/sh <imagem-nova> -c 'cd /app && ./node_modules/.bin/tsx prisma/conferir.ts --saida /saida/antes.json'

# 6. Migrar e rodar as assercoes do schema (CHECK, indice, ON DELETE, defaults).
# 7. Retrato DEPOIS, mesmo banco.
# 8. PORTAO: diff dos ARQUIVOS. Diferente => nao sobe.
# 9. Rollback: a imagem ANTIGA conversa com o banco migrado? (`prisma migrate status` dela)
```

**A armadilha que fez o portão falhar por defeito do script, não da migration:** capturar o retrato
pelo **`stdout`** do script. O script imprime resumo e distribuição junto do JSON, e o `diff` acusou
diferença nas **linhas de log** ("colunas ainda não existem" antes × "distribuição" depois) enquanto
os números eram idênticos. O retrato tem de sair para um **arquivo em volume montado**
(`-v /root/saida:/saida --saida /saida/antes.json`) e o `diff` comparar os arquivos.

Isso vale como elogio ao portão: ele **falhou fechado** e parou o deploy. Portão que falha aberto é
pior que portão nenhum.

**Duas afirmações que não se pode confundir no registro do deploy:**

- "a imagem anterior **conversa com o banco migrado**" — isso se ensaia, e é o que costuma quebrar um
  rollback depois de migration.
- "o **rollback foi ensaiado**" — isso exigiria executar o `docker service update` de volta. Se não
  foi executado, escrever "ensaiado" é afirmar mais do que se fez, e o runbook passa a mentir
  exatamente para quem vai usá-lo sob pressão.

**Por que a migration aditiva torna o rollback de um comando:** o Prisma monta `SELECT` com lista
explícita de colunas, então a imagem anterior roda sobre o banco novo ignorando coluna e tabela que
não conhece. Só vale se a migration **não** tiver `UPDATE`, `DELETE`, `DROP` nem `NOT NULL` sem
default. Marque a imagem que está no ar com nome próprio **durante** o rollout
(`docker tag atual app:antes-<feature>`) e registre que a tag foi criada — senão o comando de
rollback aponta para algo que talvez não exista.

Medido em 2026-09-19 (LiliCalc, embalagem por insumo): portão em 0 diferenças nas 5 fichas reais,
asserções OK dos dois lados, e o ensaio revelou que **4 das 5 fichas de produção** já estavam
travadas por um bug anterior — informação que só apareceu porque o retrato rodou sobre dado real.

Relacionados: {#migration-antes-do-rollout-com-imagem-nova},
{#rollback-de-migration-restore-atomico-em-duas-etapas},
{#pg-isready-pelo-socket-responde-no-postgres-temporario-do-init},
{#empacotar-deploy-do-commit-nao-da-arvore}.
