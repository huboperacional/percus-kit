## Migration do Plexco Tasks em produção: `docker run` da imagem NOVA, não `docker exec` {#plexco-migration-com-imagem-nova}

`tags: plexco tasks, alembic, migration, deploy, docker run, docker exec, network_swarm_public, pg_dump, plexco-deploy, env.migrator, swarm`

**Quando:** commit que traz migration Alembic nova no Plexco Tasks. A regra da casa é *migration
ANTES do rollout do backend* — mas o jeito óbvio de fazer isso está errado.

**A armadilha.** `docker exec <container-em-pé> alembic upgrade head` roda o código **ANTIGO**: o
container em produção não tem os arquivos das migrations novas, então o `upgrade head` dele para no
head antigo **em silêncio**, sem erro. Você acha que migrou e não migrou.

**Sequência correta** (medida na s160, migrations 102/103):

```bash
# 0. dump ANTES — o container do postgres nao aceita socket sem senha
PG=$(docker ps --format '{{.Names}}' | grep '^postgres_postgres' | head -1)
docker exec -e PGPASSWORD='<senha do plexco_v2_app>' $PG \
  pg_dump -h 127.0.0.1 -U plexco_v2_app -Fc plexco_v2 > /root/plexco_v2_pre_<coisa>_$(date +%s).dump

# 1. build da imagem com o codigo novo (mesmo caminho do plexco-deploy)
git -C /opt/plexco-v2 fetch --quiet origin master
rm -rf /opt/plexco-build && mkdir -p /opt/plexco-build
git -C /opt/plexco-v2 archive origin/master | tar -x -C /opt/plexco-build
cd /opt/plexco-build/backend && docker build -q -t plexco/backend:<TAG> .

# 2. migration com a imagem NOVA, em container efemero
docker run --rm --network network_swarm_public \
  --env-file /opt/plexco-v2/.env.migrator -w /app \
  plexco/backend:<TAG> alembic upgrade head

# 3. so entao o rollout
docker service update --force --image plexco/backend:<TAG> plexco_backend

# 4. frontend pelo wrapper (ele tem o smoke que confere as chaves DENTRO da imagem)
plexco-deploy frontend
```

**Detalhes que custam tempo se você não souber:**

- **A rede é `network_swarm_public`**, não `plexco_default` (que não existe). Descobrir com:
  `docker inspect <container-do-backend> --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'`.
- `plexco-deploy backend` faz **build + rollout juntos**, então para migration é preciso partir os
  passos como acima. Para o frontend, use o wrapper — o smoke dele (chave do Maps / pública da
  Pagar.me presentes no bundle) roda **antes** do rollout e aborta se a imagem saiu vazia.
- O `.env.migrator` fica no **host** (`/opt/plexco-v2/.env.migrator`, papel `plexco_v2_migrator`) e
  é passado por `--env-file` — nunca vai em service nenhum.

**Depois:** verifique o efeito com SQL, não com o log. Na s160, a prova de que a RF-8 funcionou foi
`SELECT count(*)` de tarefas com status fora do catálogo do próprio projeto — **zero**, contra 5
antes.

Irmão de outro produto: [Deploy do auth-service com migration nova](auth-service-deploy-migration-nova.md)
— mesma classe de armadilha, script e caminhos diferentes.
