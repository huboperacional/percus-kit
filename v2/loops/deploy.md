# Loop: deploy — subir sem drama

**Cadência:** ao fechar milestone, no fim do dia, ou sob demanda. **Nunca por feature.**

**Autonomia:** deploy e mutação de prod (env, restart, redeploy, rollback, migration com `downgrade` testado) são **autônomos** — execute, não peça permissão. Só destruição irreversível de dado confirma.

## Antes de subir

1. O que vai está `[5-T]` e passou no review de marco.
2. Você sabe a **versão atual** — sem ela não existe rollback.
3. Migration envolvida? `downgrade` testado em dev **antes**.

## Depois de subir

Smoke **real** (não "o container subiu") e registro no `HANDOFF`: *deployado {data} — {o quê}*.

## Higiene de CI — onde a cota realmente vaza

O medidor mensal é **minuto de Actions** e **transferência de Packages**. `git push` em si **não custa nada**: otimize o **gatilho**, não a frequência de push.

| Sintoma | Ação |
|---|---|
| Workflow falhando 100% há semanas | **Desligue** (`workflow_dispatch`) com comentário do porquê |
| Roda em toda branch **e** em PR | Filtre a branch — hoje são dois runs pro mesmo commit |
| Commit de doc dispara build | `paths-ignore: ['**/*.md', 'docs/**']` |
| Dois pushes seguidos, dois runs | `concurrency` + `cancel-in-progress` |
| Imagem trafega GHCR→VPS a cada deploy | Build no próprio VPS: minuto grátis, zero transferência |

**Verde que nunca aparece é sinal morto** — ninguém olha, e você paga por ele.

## Armadilhas

- `docker stack deploy` reconcilia **todos** os serviços com o `swarm.yml`: pin velho no arquivo **rola serviço pra trás**. Um serviço só → `docker service update --image`.
- Label de Traefik (rota/Host) **não** pega com `service update`; exige `stack deploy`.
- `NEXT_PUBLIC_*` é assado no **build**, não no runtime do compose.
