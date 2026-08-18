## Build no VPS falha puxando imagem PÚBLICA do ghcr.io ("denied") + `${VAR}` do stack deploy é no-op {#ghcr-denied-stale-login}

`tags: ghcr docker denied login stale build vps pull imagem-publica stack-deploy`

**Sintomas (2 no mesmo deploy, Scraper-prospeccao 2026-07-19):**
1. `docker build` falha em `COPY --from=ghcr.io/astral-sh/uv:<tag>` com `failed to fetch oauth token: denied` — parece rate-limit ou imagem privada, mas a imagem é pública e o build já funcionou antes na mesma máquina.
2. `API_IMAGE=nova-tag docker stack deploy -c stack.yml <stack>` termina "update completed"… com a imagem VELHA. Nem `export` + `echo $API_IMAGE` provando a var setada muda nada.

**Causas:**
1. **Login VELHO no ghcr.io** em `/root/.docker/config.json` (`auths["ghcr.io"]` com token expirado). Docker manda a credencial podre e o registry NEGA — o pull anônimo teria funcionado.
2. O `docker stack deploy` do host **não interpola `${VAR:-default}` do ambiente** — reaplica o default do yml. Update "completed" com imagem velha = no-op silencioso.

**Solução:**
1. `docker logout ghcr.io` → rebuild (pull anônimo).
2. Não passar tag por env var: **editar o default no `deploy/stack.yml` (repo = fonte da verdade) → `scp` pro VPS → `docker stack deploy`**. SEMPRE conferir depois: `docker service inspect <svc> --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'` — replicas 1/1 não prova imagem nova.

**Ref:** Scraper-prospeccao, deploy `2026-07-19-nr1` (página niche-review). Memória: `reference_deploy_swarm_local_image_gotchas`.
