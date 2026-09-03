## RUNBOOK_DEPLOY.md documenta um fluxo GHCR desativado — build real é local na VPS {#runbook-deploy-ghcr-documenta-ci-desativado}

`tags: RUNBOOK_DEPLOY, GHCR, github actions, docker build, docker-compose.swarm.yml, drift de doc, Paid Media Automation`

**Sintoma:** você faz `git push origin master` esperando que `.github/workflows/build-and-push.yml`
builde e publique as imagens em `ghcr.io/huboperacional/paid-media-*` (como `RUNBOOK_DEPLOY.md` §11
descreve), e nada acontece — `gh run list` não mostra nenhuma run nova pro seu push.

**Causa:** o workflow está `state: "disabled_manually"` desde algum ponto antes de 28/07/2026
(confirmado via `gh api repos/<org>/<repo>/actions/workflows` — `gh workflow list` só mostra os
workflows `active`, então o `disabled_manually` fica invisível ali). `test.yml` também está
desativado; só `playwright-prod-smoke` continua ativo. O `docker-compose.swarm.yml` já documenta a
decisão em comentário no serviço `web`: *"GHCR desativado por decisao do operador, nao por
falha"* — a imagem é referenciada como tag LOCAL sem prefixo de registry (ex.:
`paid-media-web:saidas-438e9fae`), não `ghcr.io/...`.

**Como resolver:** não confie em `RUNBOOK_DEPLOY.md` §11 pra saber o fluxo corrente — ele ficou
desatualizado depois da decisão de desativar o GHCR. O fluxo real (single-node swarm, então não
precisa de registry): SSH/`vps_exec.py` na VPS → `cd /opt/paid-media && git pull origin master` →
`docker build -t paid-media-web:<label>-<shortsha> -f web/Dockerfile web/` → conferir com
`git merge-base --is-ancestor <sha-em-prod> HEAD` antes → `docker service update --image
paid-media-web:<label>-<shortsha> paid-media_web`. Documente o pin novo em comentário no
`docker-compose.swarm.yml` (rollback = pin anterior) e commit — é a única fonte viva de "que tag
está no ar", já que o arquivo pode estar em drift do `service ls` real (medido 03/09: o compose
declarava `fluxo-9a717e9a`, o `service ls` mostrava `saidas-438e9fae`).

Relacionado: [[image_tag_can_lie_when_head_moves]] (mesma família — não confiar em texto estático
sobre o que está de fato rodando).
