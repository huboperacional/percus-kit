## Volume nomeado do Docker Swarm nasce `root:root`; container non-root não consegue escrever {#swarm-named-volume-root-owned-vs-nonroot-container}

`tags: Docker Swarm, named volume, EACCES, non-root user, Dockerfile nextjs uid, persistent storage, deploy/stack.yml`

**Contexto:** `stack.yml` declara um volume nomeado (`volumes: - meu_volume:/app/storage`, sem
`external: true`) montado num serviço cujo `Dockerfile` roda como usuário não-root (`adduser --system
--uid 1001 nextjs` + `USER nextjs`, padrão de segurança do `next build` standalone).

**Sintoma:** primeira escrita real depois do deploy (ex.: um upload autenticado) falha com
`EACCES: permission denied, mkdir '/app/storage/...'` — mesmo com o volume aparecendo montado
corretamente (`docker inspect ... Mounts` mostra o bind certo) e o serviço "healthy".

**Causa raiz:** Docker Swarm cria o volume nomeado na primeira vez que algum serviço o monta, com dono
`root:root` no host (`/var/lib/docker/volumes/<stack>_<volume>/_data`). O processo dentro do container
roda como uid não-root (1001, por exemplo) — sem permissão de escrever/criar subdiretório ali.

**Solução:** depois do PRIMEIRO `docker stack deploy` que efetivamente cria o volume (confirmar com
`docker volume ls` que ele existe), rodar uma vez: `chown -R <uid-do-usuario-do-container>:<mesmo-gid>
/var/lib/docker/volumes/<stack>_<volume>/_data`. Só precisa rodar uma vez — o volume e a ownership
persistem entre deploys seguintes (a menos que o volume seja removido manualmente). Documentar esse
passo no runbook de deploy (comentário no `stack.yml`, ou script de provisionamento) pra próxima vez
que o volume for recriado do zero (novo VPS, disaster recovery) não redescobrir isso pela dor.

**Como pegar isso ANTES de assumir "deploy" = "pronto":** um serviço saudável (`docker service ps` /
healthcheck verde) não prova que a escrita funciona — healthcheck normalmente só bate num GET simples.
Testar a escrita de verdade (o upload/gravação real que a feature promete) faz parte do ciclo de
verificação pós-deploy, não é opcional só porque o container subiu saudável.

**Ref:** ads4agencies-site, painel de admin AutoWorx, Task 18/19, sessão 2026-08-06 — volume
`ads4agencies_autoworx_admin_storage`, container `nextjs` uid 1001, fix documentado em
`deploy/stack.yml` (ARMADILHA 3).
