## `docker stack deploy` rola serviços pra trás quando o swarm.yml está com pins stale {#stack-deploy-swarm-pins-stale}

`tags: docker swarm, stack deploy, docker-compose.swarm.yml, image pin, sha, rollback, service update, drift, deploy, ENOMEM, GHCR`

**Contexto:** deploy de um serviço (web) via `docker stack deploy -c docker-compose.swarm.yml <stack>` (comando padrão do runbook). Em vez de só atualizar o web, o comando **rolou web+tracking+worker pra trás** pra versões antigas — o worker ficou 0/1 (down) ~2min. O site continuou de pé (imagem velha), mas foi regressão.

**Causa raiz:** `docker stack deploy` reconcilia **TODOS** os serviços do stack pro que o swarm.yml declara. O swarm.yml estava **stale**: pinava shas antigos (`sha-afb0299`, tag `onda6`) porque deploys recentes foram feitos com `docker service update --image sha-NOVO <svc>` direto — e isso **NÃO atualiza o swarm.yml**. Então o arquivo de deploy divergiu do que rodava em prod, e o stack deploy "corrigiu" tudo pro estado velho do arquivo (incl. uma tag `onda6` que nem existia mais → 0/1).

**Solução:** (1) diagnóstico — comparar `grep image: docker-compose.swarm.yml` com `docker service ls --format '{{.Name}} {{.Image}}'`; se divergirem, o stack deploy vai rolar pro yml. (2) recovery imediato — restaurar cada serviço com `docker service update --with-registry-auth --image ghcr.io/.../paid-media-<svc>:sha-<correto> paid-media_<svc>` (os shas corretos vêm do STATUS.md/últimos deploys; confirmar que são commits reais com `git log --oneline -1 <sha>`). (3) fix da raiz — editar os pins do swarm.yml pros shas que rodam em prod e commitar, pra o `docker stack deploy` voltar a ser seguro. **REGRA: antes de `docker stack deploy`, sempre conferir `docker service ls` vs pins do yml; se for só um serviço, prefira `docker service update --image` (não toca os outros).**

**Ref:** Paid Media Automation deploy da reestruturação da aba Tracking (2026-07-14, cont.100); fix `6192c82`; [[reference_swarm_yml_is_deploy_file]], [[reference_deploy_traps]].
