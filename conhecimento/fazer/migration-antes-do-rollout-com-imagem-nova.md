## Rodar migration ANTES do rollout do backend (o deploy não faz isso por você) {#migration-antes-do-rollout-com-imagem-nova}

`tags: deploy, migration, alembic, docker, swarm, plexco, producao, ordem`

**O que quebra:** `plexco-deploy backend` **NÃO roda migration**. Se você chamar só ele, o backend
novo sobe consultando coluna que ainda não existe — 500 em toda rota que a toque, silenciosamente,
até alguém perceber.

Medido (2026-08-31, s161): rodei `plexco-deploy backend` com a migration 104 pendente. Por ~1 minuto
a produção ficou com código novo e schema velho; o cadastro público e a criação de organização
teriam dado 500. Não houve vítima por acaso de calendário, não por cuidado.

**Ordem correta:**

1. Dump antes de qualquer DDL.
2. **Migration, com a IMAGEM NOVA** — nunca `docker exec` no container em pé, que roda o código
   velho e para no head antigo **em silêncio**:

```bash
IMG=$(docker service inspect plexco_backend --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' | cut -d@ -f1)
docker run --rm --network network_swarm_public \
  --env-file /opt/plexco-v2/.env.migrator -w /app "$IMG" alembic upgrade head
```

3. Confirmar no banco (`SELECT version_num FROM alembic_version;`) **e** que a coluna existe.
4. Só então `plexco-deploy backend`.

**Pegadinha do ovo e da galinha:** o passo 2 precisa da imagem nova, que só existe depois do build.
Se o build vier junto do rollout, faça o build, rode a migration com a tag recém-criada, e só depois
atualize o serviço — ou aceite a janela e saiba que ela existe.

Relacionado: [Deploy na VPS Percus](../fazer/deploy-vps.md)
