## Mostrar a imagem nova com dado real de produção ANTES do deploy, só no seu navegador (cookie no Traefik) {#print-de-imagem-nova-com-dado-de-producao-por-cookie-no-traefik}

`tags: traefik, swarm, print antes do deploy, aprovacao de layout, cookie, HeadersRegexp, priority, service create, env-file, rede overlay, preview com dado real`

**Quando:** o operador precisa aprovar prints de uma tela nova com dado real antes do deploy, e não existe
banco local com dado (Postgres de prod não é roteável de fora) nem ambiente de staging.

**Passos (Swarm + Traefik v2.11, validado 15/09/2026):**
1. Build da imagem na VPS a partir de worktree temporário (código por `git bundle` se o push ainda não foi
   autorizado); anote e restaure `vm.overcommit_memory` ao valor ORIGINAL (não assuma 0).
2. Copie o env do serviço de produção sem imprimir:
   `docker service inspect <svc> --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | python3 -c 'import json,sys;print("\n".join(json.load(sys.stdin)))' > /root/teste.env` (chmod 600).
3. Crie o serviço temporário na MESMA rede do Traefik:
   `docker service create --detach --name <svc>-teste --network <rede_traefik> --env-file /root/teste.env --label traefik.enable=true --label 'traefik.http.routers.teste.rule=Host(`dominio`) && HeadersRegexp(`Cookie`, `nome_do_cookie=1`)' --label traefik.http.routers.teste.priority=1000 --label traefik.http.routers.teste.entrypoints=websecure --label traefik.http.routers.teste.tls.certresolver=<resolver> --label traefik.http.services.teste.loadbalancer.server.port=3000 <imagem-nova>`
4. No navegador logado (DevTools MCP): `document.cookie = "nome_do_cookie=1; path=/; secure; samesite=lax"`, recarregue e confirme um texto que só existe na versão nova.
5. Tire os prints (ver [[zoom-do-navegador-muda-a-largura-medida-no-devtools]]). Nova rodada = `docker service update --no-resolve-image --image <nova> <svc>-teste`.
6. Limpe tudo: `docker service rm <svc>-teste`, apague o env copiado, bundles, logs e worktrees; apague o cookie.

**Por que funciona sem risco para os outros:** só requisições com o cookie casam o router de prioridade
alta; o resto do tráfego segue no serviço de produção. Nenhuma porta é publicada. O serviço de teste usa o
banco REAL — trate como produção (sem ações de escrita além do necessário para o print).
