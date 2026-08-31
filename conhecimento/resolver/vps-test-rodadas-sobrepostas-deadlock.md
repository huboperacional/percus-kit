## Duas rodadas de `vps-test.py` ao mesmo tempo DEADLOCKAM (e imitam flakiness de outro arquivo) {#vps-test-rodadas-sobrepostas-deadlock}

`tags: teste, pytest, vps, postgres, deadlock, flaky, truncate, conftest, timeout, plexco`

**Sintoma:** a suíte falha em testes de um arquivo que você **não tocou** — tipicamente com asserção
de contagem (`assert len(sent) == 1` em `test_avisos_emitters_db.py`). Rodar o arquivo isolado passa.
Rodar junto com o seu passa. Parece flakiness do arquivo alheio.

**Causa:** `vps-test.py` **não isola runs**. Cada `docker run` recebe literalmente o mesmo
`DATABASE_URL=postgresql+asyncpg://postgres:postgres@plexco-test-pg:5432/plexco_test`. Como o
`conftest` dá `TRUNCATE` nas tabelas entre testes, duas suítes simultâneas travam uma na outra.

Medido (2026-08-31): `TRUNCATE audit_log, ...` em `wait_event_type=Lock` de um lado, `INSERT INTO
audit_log` em `Lock` do outro, e uma terceira conexão `idle in transaction`. As duas rodadas
passaram de **16min** contra ~11min normais e **não terminariam**.

**Como a sobreposição nasce sem você perceber:** você dá `timeout` menor que a duração da suíte. O
timeout mata o processo **local**; o harness diz "movido para background"; e você inicia a próxima.
Mas o `pytest` **remoto continua rodando**. Matar o lado de cá não mata o lado de lá.

**Confirmar antes de acusar flakiness:**

```bash
ps aux | grep -c "[p]ytest"          # na VPS; >2 = sobreposição
docker exec plexco-test-pg psql -U postgres -tAc \
  "SELECT pid, state, wait_event_type, left(query,50) FROM pg_stat_activity WHERE datname='plexco_test';"
```

**Limpar quando já travou:**

```bash
docker ps --format '{{.ID}} {{.Image}}' | grep 'python:3.12-slim' | awk '{print $1}' | xargs -r docker kill
docker exec plexco-test-pg psql -U postgres -tAc \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='plexco_test' AND pid <> pg_backend_pid();"
```

**Regra:** a suíte leva **10-12min**. Nunca dê `timeout` menor — use background e espere a
notificação. Nunca inicie a segunda antes de a primeira acabar de verdade. Antes de concluir
"flaky", confirme que só havia **uma** rodada: flakiness e interferência têm consertos opostos.
