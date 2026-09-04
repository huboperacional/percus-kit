## Docker secret provisionado NÃO vira env var sozinho pra um script avulso — só a app com `secrets_dir` faz essa ponte {#docker-secret-nao-vira-env-var-sozinho-em-script-avulso}

`tags: docker secret, swarm, pydantic, secrets_dir, os.environ, script avulso, cutover, pagarme, R23`

**Sintoma:** você provisiona um Docker Swarm secret (`docker secret create X - ` + `service update
--secret-add`), confirma que ele está montado no service (`docker service inspect` lista o secret,
`/run/secrets/X` existe no container) — e mesmo assim um script avulso rodado via `docker exec ...
python -m algum_modulo` erra `X não setada no ambiente`, ou lê string vazia de `os.environ.get("X")`.

**Causa raiz:** a ponte "arquivo em `/run/secrets/` → variável de ambiente que `os.environ` enxerga"
**não existe no SO** — é uma convenção que só o `pydantic-settings` (`BaseSettings` com
`secrets_dir="/run/secrets"`) implementa, e só *dentro da instância `Settings()` da própria app*.
Um script avulso que faz `os.environ.get("X")` direto (sem instanciar essa `Settings`) não ganha
esse comportamento de graça — ele lê o ambiente do processo puro, e o Docker secret nunca populou
o ambiente do processo, só o filesystem.

**Medido no cutover Pagar.me (Plexco Tasks, 2026-09-03):** `PAGARME_SECRET_KEY_LIVE` provisionado
como Docker secret, confirmado montado (`/run/secrets/PAGARME_SECRET_KEY_LIVE` existe, a própria
FastAPI app resolve certo via `Settings(secrets_dir=...)`). O script de setup
(`infra/pagarme_setup.py`, roda avulso via `docker exec $BK python -m infra.pagarme_setup --apply`,
**fora** do ciclo de vida da app) faz `os.environ.get("PAGARME_SECRET_KEY_LIVE", "")` puro — devolve
vazio, apesar do secret estar montado e correto.

**Discriminante, em uma linha:** o script lê `os.environ` direto (não instancia a `Settings` da
app)? Se sim, o secret **não vai aparecer** ali sozinho — precisa exportar manualmente na hora:

```bash
docker exec -e PYTHONPATH=/app "$BK" sh -c \
  'PAGARME_ENV=live PAGARME_SECRET_KEY_LIVE=$(cat /run/secrets/PAGARME_SECRET_KEY_LIVE) \
   python -m infra.pagarme_setup --apply'
```

O `$(cat ...)` roda **dentro** do `sh -c` remoto — o valor nunca passa pelo terminal/contexto de
quem disparou o comando, só pelo processo filho que o consome.

**Regra que fica:** confirmar "o secret está montado" (`service inspect`, `ls /run/secrets/`) prova
que a APP principal (a que instancia `Settings(secrets_dir=...)`) vai resolver certo. Não prova nada
sobre um script/comando avulso rodado por fora dessa app — cada um desses precisa da própria ponte
arquivo→env, explícita, no comando que o dispara.

Irmãos: [[401-em-wrapper-que-herda-env-nao-prova-nada-sobre-a-chave]] (mesma família — credencial
correta, caminho de propagação até o consumidor é que falha).
