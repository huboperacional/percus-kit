## Mudar rota/Host do Traefik (label) não pega com `service update --image` {#traefik-label-precisa-stack-deploy}

`tags: traefik label host rota service-update stack-deploy swarm routing`

tags: traefik, swarm, label, router rule, Host, docker service update, stack deploy, label-add, rota não aplica, env drop, rollout transiente

**Contexto:** adicionei um `Host()` novo na regra do router Traefik (label no compose) e rodei o deploy padrão (`docker service update --force --image`), mas a rota nova não apareceu.

**Causa raiz:** labels do Traefik vivem no **service spec**, setados no `docker stack deploy`. `docker service update --image` troca só a imagem — **não reaplica labels**. A regra fica a antiga.

**Solução:** pra mudar label/rota: **(a)** `docker service update --label-add "traefik.http.routers.X.rule=..." SERVICE` — cirúrgico, **não mexe em env/secrets** (ideal quando o compose tem token/senha); OU **(b)** editar o compose + `docker stack deploy --resolve-image never -c compose.yml STACK` — ⚠️ o stack deploy **reaplica todo o env do compose**, dropando variáveis que só foram `--env-add` (não escritas no compose). Backtick na regra via SSH: passar por variável single-quoted no remote (`RULE='Host(\`x\`)...'`; expansão de `$VAR` em aspas duplas não reinterpreta backtick). Após `service update`, **esperar convergir** antes de curlar (curl no meio do rollout pega a task velha → 404/conteúdo stale).

**Ref:** migração Painel Gestão Fases 1/4 2026-07-14.
