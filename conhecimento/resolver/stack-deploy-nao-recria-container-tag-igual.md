## `docker stack deploy` atualiza labels do Traefik mas não recria o container quando a tag da imagem não muda — precisa `service update --force` depois {#stack-deploy-nao-recria-container-tag-igual}

`tags: docker swarm, stack deploy, service update --force, image tag latest, rolling update, traefik labels`

**Contexto:** ADS4PROS-Site, sessão 2026-08-04, deploy de uma feature nova (`assinatura.ads4pros.com`)
que exigia mudança em `docker-compose.yml` (novo host + middleware Traefik) E uma imagem nova
(código novo, mesma tag `ads4pros-lp:latest`). Fluxo: `docker build` local na VPS (gera imagem nova
com hash diferente, mesma tag) → `docker stack deploy -c docker-compose.yml ads4pros-lp`. O deploy
"funcionou" (sem erro), `docker service inspect` confirmou que os labels novos do Traefik (a regra
de host nova) foram aplicados corretamente — mas `docker service ps` continuava mostrando a MESMA
task ID de 3 dias atrás, e `docker inspect` do container confirmou: `Created` continuava sendo de 3
dias antes. A imagem nova (com o código da feature) nunca chegou a rodar.

**Causa raiz:** Docker Swarm compara a SPEC do serviço pra decidir se recria o task. Mudança de
labels é, sim, uma mudança de spec — e nesse caso específico ela FOI aplicada (confirmado via
`docker service inspect`). Mas Swarm não detecta automaticamente que uma tag de imagem já conhecida
(`ads4pros-lp:latest`) agora aponta pra um conteúdo diferente — ele não resolve o digest de novo só
porque a tag já está "resolvida" no seu cache de spec. `docker service update --force` existe
exatamente pra esse caso: força Swarm a re-resolver a referência de imagem e recriar o task, mesmo
com a string da tag inalterada.

**Sinal de alerta pra generalizar:** depois de QUALQUER `docker stack deploy` que envolve build local
de imagem com tag fixa (`:latest` ou qualquer tag reaproveitada, sem digest/registry), **não confiar
que "o comando rodou sem erro" implica "o container novo está rodando"** — checar
`docker inspect <container> --format '{{.Created}}'` (ou `docker service ps` com atenção ao timestamp
"Running X ago") pra confirmar que a recriação realmente aconteceu antes de considerar o deploy
concluído.

**Solução:** depois de `docker build` + `docker stack deploy` com tag fixa reaproveitada, sempre
rodar `docker service update --force <service>` em seguida (não é redundante — trata exatamente esse
gap) e só então validar `Created`/timestamp do container antes de dar o deploy como confirmado.
Cuidado com o aviso já documentado em [[reference_deploy_sequence]] (memória de projeto): não
combinar `service update --force` com `stack deploy` NA MESMA invocação/rodada (dá "update out of
sequence") — rodar em sequência, um depois do outro, é seguro; simultâneo/mesma chamada não.

**Ref:** ADS4PROS-Site, sessão 2026-08-04, deploy de `assinatura.ads4pros.com` — task
`9tahrhjf9rou251m8j5q4mce7` continuou "Running 3 days ago" após `stack deploy` sozinho; resolvido
com `docker service update --force ads4pros-lp_app` na sequência, container recriado com timestamp
correto e feature nova confirmada em produção.
