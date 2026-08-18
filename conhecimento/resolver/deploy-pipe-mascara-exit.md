## Deploy: `docker build ... | tail && service update` mascara build falho → outage {#deploy-pipe-mascara-exit}

`tags: deploy, docker build, pipe, exit code, tail, swarm, service update, outage, 404, rollback, ci`

**Contexto:** deploy num VPS Docker Swarm encadeando `docker build ... | tail -25 && docker service update --image X --force`. O `npm install` do build falhou (blip de rede), mas o `service update` rodou mesmo assim → Swarm parou a task antiga pra subir uma imagem inexistente → **404 em prod (~1min)**.

**Causa raiz:** o exit code de um **pipeline** é o do ÚLTIMO comando (`tail`, sempre 0). O `&&` viu "sucesso" e seguiu pro update, apesar do `docker build` ter falhado.

**Solução:** build e `service update` em passos **SEPARADOS**. Capturar `docker build ...; echo BUILD_EXIT=$?` e só atualizar o service se `BUILD_EXIT=0` (nunca `build | tail && update`). Ter o **rollback declarado** antes de deployar (`docker service update --image <versao-anterior> --force <service>` converge ~5s; as imagens antigas ficam no host — `docker image ls`). Blip de npm no build é transitório → retry do build isolado resolve.

**Ref:** huboperacional-site deploy v0.3.4 (2026-07-14); memória de projeto `deploy-vps-gotchas`.
