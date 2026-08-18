## Deploy na VPS Percus {#deploy-vps}

`tags: deploy, vps, traefik, docker, swarm, portainer, stack, rollback, producao, cadencia`

**Quando:** **fim de milestone**, **fim do dia**, ou **sob demanda** do operador — **nunca a cada
feature** (R24). Sempre com confirmação (R5) + smoke + rollback pronto.

**Passos (resumo — playbook completo em `comandos/DEPLOY.md`):**
1. Gate pré-deploy: o que vai está `[5-T]`; milestone passou no `milestone-review`; HANDOFF reflete; confirmação R5; sei a versão atual (rollback).
2. **De onde vem a imagem** — isso decide o resto do passo; o canon **não presume registry**:
   - **Imagem em registry:** `PUT /api/stacks/{ID}?endpointId=1` no **Portainer**
     (`https://painel.huboperacional.com.br`) com `stackFileContent` + `prune:true` + `pullImage:true`.
     Detalhe CSRF/swarmId em `02_INFRA` §10.
   - **Imagem buildada no próprio nó** (sem registry): build na VPS com a **mesma tag** que está no spec
     do serviço, e `docker service update --force --no-resolve-image --image <tag> <stack>_<svc>` —
     `--no-resolve-image` usa a imagem **local** em vez de tentar resolver digest no registry.
     O arquivo de stack do projeto (`docker-compose.swarm.yml` ou equivalente) continua sendo o
     **estado desejado**: bumpe o `image:` e **commite**, senão o próximo `stack deploy` limpo volta
     pro sha antigo — e o serviço em `:latest` re-resolve pra imagem stale no primeiro reschedule.
   - Só mudou config/secret? `ForceUpdate++` no serviço (restart sem rebuild) — vale nos dois caminhos.

   > **2026-07-28:** o GH Actions da org `huboperacional` está **desativado por decisão de custo**
   > (`build-and-push.yml` em `disabled_manually`), então **build-no-nó é o caminho corrente** onde havia
   > registry. O GHCR guarda imagens antigas: serve de **rollback profundo**, não de estado atual.
   > O procedimento **específico** de cada projeto mora no runbook DELE (ex.:
   > `Paid Midia Automation/docs/RUNBOOK_DEPLOY.md`) — este verbete é a **regra de decisão**, não a cópia.
3. **Smoke:** `curl -I https://<sub>.huboperacional.com.br` (não 5xx/520) + `docker service logs <stack>_<svc> --tail 50` + rota crítica.
4. Registrar no HANDOFF "deployado {data} — {o quê}".

**Comando (rollback Swarm — tenha pronto antes):**
```bash
docker service rollback <stack>_<servico>    # reverte pro spec anterior
# migration envolvida? testar `alembic downgrade -1` em dev ANTES de deployar.
```

**Armadilhas:** deploy per-feature (R24); 520 no curl = DNS "Proxied" no Cloudflare (tem que ser **DNS
only**, `02_INFRA` §8); pular smoke; migration sem `downgrade` testado; deployar o que não é `[5-T]` sem o
operador autorizar o risco.

**Ref:** `comandos/DEPLOY.md` (playbook), `02_INFRA_E_STACK_PERCUS.md` §6-10, R24.
