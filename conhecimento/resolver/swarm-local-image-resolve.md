## Imagem local em Docker Swarm crash-loopa com "pull access denied" (sem registry) {#swarm-local-image-resolve}

`tags: docker swarm, stack deploy, imagem local, resolve-image never, pull access denied, repository does not exist, single node, sem registry, vps, 161.97.129.138, network_swarm_public, redis_redis, worker healthcheck, container parents, IndexError, config.py, deploy`

**Contexto:** deploy de um backend novo no VPS Swarm compartilhado (`161.97.129.138`, 1 nó, ~30 stacks, Traefik+Postgres+Redis compartilhados). Sem Docker local na máquina do dev e git **local-only** (sem remote) → build tem que rodar NO VPS.

**Sintomas e causas (cada um custou um ciclo):**
1. **Task fica `0/1`, container em "created"/"Starting", crash-loopa, `docker service logs` VAZIO.** `journalctl -u docker` mostra `pull access denied for <img>, repository does not exist`. **Causa raiz:** imagem construída LOCAL no nó não tem digest de registry; o Swarm tenta puxá-la de `docker.io` a cada (re)start de task. O `create` inicial pode rodar do local, mas os restarts pullam → nega. **Fix:** `docker stack deploy --resolve-image never -c stack.yml <stack>` (obrigatório p/ imagem local). Se o spec já quebrou, `docker stack rm` + redeploy limpo com a flag. Alternativa: referenciar a imagem pelo ID `sha256:...` (não pulla).
2. **App não boota — `IndexError` em `Path(__file__).resolve().parents[N]`.** Código calcula a raiz do repo por profundidade de path; no container a árvore é achatada (`/app/app/core/config.py` tem menos `parents` que o layout de dev `services/api/app/core/...`). **Fix:** guardar o índice — `_p = ...parents; root = _p[N] if len(_p) > N else Path("nonexistent")`. Em prod a config vem de env vars, não do `.env` em disco.
3. **Worker ARQ fica `0/1` pra sempre (mesmo rodando e conectado ao Redis).** O serviço herda o `HEALTHCHECK` do Dockerfile (que bate em `:8000/health`), mas o worker não sobe HTTP → unhealthy eterno, nunca vira Running. **Fix:** `healthcheck: test: ["NONE"]` no serviço worker do stack.
4. **Reachability das deps compartilhadas:** Redis desse VPS NÃO publica porta no host — só service-DNS na overlay (`redis://...@redis_redis:6379`); então TODOS os serviços que usam Redis (inclusive worker) precisam entrar na rede **`network_swarm_public`** (external). Postgres publica `161.97.129.138:5432` (dá pra usar via host). Traefik: entrypoint `websecure` + `certresolver=letsencryptresolver` (espelhar labels de um service irmão como `auth_service_api`).

**Diagnóstico geral:** quando o container "created"/log-vazio confunde, **rode a imagem à mão** (`docker run --rm --env-file .env --network network_swarm_public <img> <cmd>`) — separa "app/env quebrado" de "problema de orquestração do Swarm".

**Ref:** Scraper-prospeccao deploy 2026-07-10 (backend LIVE em `scraper.huboperacional.com.br`), commits `9b1da80`+`450a636`; `docs/DEPLOY.md` §Deploy executado; memória `reference_deploy_swarm_local_image_gotchas`.
