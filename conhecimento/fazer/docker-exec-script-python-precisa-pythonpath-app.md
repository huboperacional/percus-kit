## `docker exec <container> python scripts/foo.py` numa imagem FastAPI dá `ModuleNotFoundError: app` sem `PYTHONPATH` explícito {#docker-exec-script-python-precisa-pythonpath-app}

`tags: docker exec, PYTHONPATH, ModuleNotFoundError, scripts, one-off script, migração de dados, sys.path, WORKDIR`

**Sintoma:** um script em `backend/scripts/foo.py` que faz `from app.database import async_session`
(ou qualquer `from app.*`) roda limpo quando importado dentro da suite de testes, mas falha com
`ModuleNotFoundError: No module named 'app'` quando disparado via `docker exec <container> python
scripts/foo.py` — mesmo com `WORKDIR /app` no Dockerfile e `app/` existindo em `/app/app/`.

**Causa raiz:** `python <script>.py` adiciona ao `sys.path[0]` o diretório **do próprio script**
(`/app/scripts`), não o `cwd` do processo (`/app`). `WORKDIR /app` no Dockerfile controla o `cwd`,
não o `sys.path` — os dois são coisas diferentes. Sem `PYTHONPATH=/app` (ou `/app/app` sendo um
pacote alcançável a partir de `/app/scripts`), `import app` nunca resolve, mesmo com o pacote
fisicamente ao lado.

**Fix:** `docker exec -e PYTHONPATH=/app <container> python scripts/foo.py <args>` — uma flag,
resolve na hora. Alternativa equivalente sem tocar no `docker exec`: `python -m scripts.foo` (roda
como módulo, a partir do `cwd`, que aí sim entra no `sys.path`) — mas exige `scripts/__init__.py`
(este repo já tem) e trocar a chamada em todo lugar que a documenta.

**Sinal de que outros scripts do repo têm o mesmo problema silencioso:** o docstring de
`backend/scripts/seed_wa_enrollments.py` documenta o uso como `docker exec <backend> python
scripts/seed_wa_enrollments.py` sem `-e PYTHONPATH=/app` — ou o container tem `PYTHONPATH` setado
por fora (não estava, medido: `env | grep -i python` devolveu vazio) e portanto o docstring está
desatualizado/nunca testado nesse exato container, ou quem rodou historicamente sempre passou o
`-e` na mão sem documentar. Vale conferir antes de copiar o comando do docstring literalmente.

**Ref:** Plexco Tasks, import de dados eKyte→ADS4PROS (`backend/scripts/import_ekyte_ads4pros.py`,
2026-08-31) — `docker exec fe16daeeb246 python scripts/import_ekyte_ads4pros.py` falhou com
`ModuleNotFoundError: app`; `docker exec -e PYTHONPATH=/app fe16daeeb246 python scripts/...` rodou
limpo (dry-run e depois `--apply`, 70 tarefas criadas).
