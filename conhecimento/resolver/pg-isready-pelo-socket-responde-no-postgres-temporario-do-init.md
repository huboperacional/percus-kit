## `pg_isready` pelo socket responde no Postgres TEMPORÁRIO do init e o `pg_restore` cai na troca {#pg-isready-pelo-socket-responde-no-postgres-temporario-do-init}

`tags: postgres, docker, pg_isready, pg_restore, ensaio, deploy, runbook, healthcheck, R23`

**Contexto:** ensaio de deploy que sobe um Postgres descartável (`docker run -d … postgres:17`),
espera ficar pronto, restaura o dump de produção e roda as migrations da imagem nova — o passo que
prova a virada e o rollback antes de tocar o servidor.

**O laço que engana:**

```bash
until docker exec ensaio-pg pg_isready -U app -d app; do sleep 1; done
docker cp /root/antes.dump ensaio-pg:/tmp/
docker exec ensaio-pg pg_restore -U app -d app --single-transaction /tmp/antes.dump
```

A imagem oficial do Postgres, no primeiro boot, roda o `initdb` e sobe um servidor **temporário**
para aplicar `/docker-entrypoint-initdb.d`. Esse servidor escuta **só no socket Unix**
(`listen_addresses=''`) e responde `accepting connections` ao `pg_isready`. Em seguida ele é
**parado** para o servidor definitivo subir. O `pg_restore` disparado nessa janela morre com exit 1.

**Sintoma (LiliCalc, deploy de 16/09):** `pg_restore` falhou duas vezes seguidas, sempre no mesmo
ponto. Pior que falhar: **sem parada explícita, o ensaio seguia** — as migrations rodavam num banco
VAZIO e todas as conferências passavam (`0` linhas na tabela nova, enum presente, imagem "Ready"),
dando um verde que não prova nada, porque não havia dado real nenhum.

**Correção:**

```bash
# TCP: só o servidor definitivo atende
i=0; until docker exec ensaio-pg pg_isready -h 127.0.0.1 -U app -d app; do
  i=$((i+1)); [ "$i" -ge 90 ] && { echo "postgres do ensaio não respondeu" >&2; exit 1; }; sleep 1; done
docker exec ensaio-pg pg_restore -U app -d app --single-transaction /tmp/antes.dump \
  || { echo "ABORTADO: pg_restore do ensaio falhou" >&2; exit 1; }
# e conferir as contagens restauradas antes de migrar
```

**Regra geral:** todo ensaio que restaura dado tem três travas — espera por **TCP**, `|| exit 1` no
restore, e **conferência das contagens** contra o backup. Ensaio que passa sobre banco vazio é pior
que ensaio que falha, porque vira autorização para subir.

Relacionado: [[prisma-dev-morre-quando-a-sessao-troca-de-contexto]],
[[pglite-serializa-queries-e-nao-prova-lock]].
