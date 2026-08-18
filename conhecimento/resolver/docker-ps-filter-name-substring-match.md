## `docker ps --filter name=X` casa por SUBSTRING — pega sidecar cujo nome começa com X {#docker-ps-filter-name-substring-match}

`tags: docker, docker swarm, docker ps, filter name, container id, sidecar, redis, script one-shot, VPS deploy`

**Contexto:** deploy manual/scriptado num serviço Docker Swarm (`tiatendo_tiatendo`) que tem um
sidecar no mesmo stack com nome que COMEÇA pelo mesmo prefixo (`tiatendo_tiatendo-redis`). Script
pós-deploy captura `CID=$(docker ps -q -f name=tiatendo_tiatendo)` pra rodar `docker exec` de
verificação (health check, smoke, patch).

**Sintoma:** `docker ps -q -f name=tiatendo_tiatendo` devolve **duas** linhas (o app E o sidecar
Redis) — `$CID` vira uma string com newline embutido, e `docker exec "$CID" ...` falha de formas
confusas: às vezes erro de container não encontrado, às vezes tenta `exec` usando o ID errado como
se fosse o próprio comando (`executable file not found in $PATH` citando um hash de container).

**Causa raiz:** o filtro `--filter name=` do Docker é **substring match**, não igualdade exata.
`tiatendo_tiatendo` é literalmente um prefixo de `tiatendo_tiatendo-redis` (convenção comum de
nomear sidecars como `<service>-<sidecar>` dentro do mesmo stack), então qualquer script que confia
em "meu nome de serviço é único o bastante" quebra silenciosamente assim que o stack ganha um
segundo serviço com prefixo compartilhado.

**Solução:** nunca capturar `$CID` às cegas num script one-shot sem confirmar visualmente antes:
`docker ps --filter name=<X> --format '{{.ID}} {{.Image}} {{.Names}}'` pra ver quantas linhas voltam
e qual é qual. Filtro mais robusto: ancorar no separador do padrão Swarm
(`--filter name=<service>.` com PONTO final — só o próprio serviço tem esse ponto no padrão
`<service>.<slot>.<task>`, sidecars com nome-prefixo não têm) ou filtrar pela imagem
(`--filter ancestor=<repo>/<app>`) em vez do nome do serviço.

**Ref:** tiatendo, deploy `0.287.0` (N19/C13/C16), sessão 2026-08-06 — script de verificação pós-deploy
capturando `$CID` pra checar health/env dentro do container certo.
