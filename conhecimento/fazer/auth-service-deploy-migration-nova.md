## Deploy do auth-service com migration nova (`auth-service-deploy.sh`) {#auth-service-deploy-migration-nova}

`tags: auth-service, deploy, alembic, migration, skip-migration-check, git pull, origin main, rollout, health 502, health 504, rolling restart, secret reconcile`

**Quando:** commit que adiciona código E uma migration Alembic nova ao mesmo tempo (ex.: registrar
uma audience nova) e o deploy vai por `auth-service-deploy` (symlink pro script versionado em
`D:\Claud Automations\auth-service\deploy\scripts\`).

**O que o script NÃO faz (armadilha #1):** ele só **compara** o head esperado (maior arquivo em
`alembic/versions/`) contra `alembic_version` no banco, lido via `docker exec` no container **que
já está rodando** (a imagem VELHA). Se divergir, ele **aborta** com `FATAL: migration head
divergence` e sugere `docker exec "$C" python -m alembic upgrade head` — mas essa sugestão só
funciona se o container atual **já tiver** o arquivo da migration nova no disco, o que não é o caso
na primeira vez (a migration só existe na imagem NOVA, ainda não buildada).

**Armadilha #2:** o script começa com `git pull --ff-only origin main` — ele deploya o que está no
**GitHub remoto**, não o seu working tree local. Um commit local sem `push` simplesmente não entra
no deploy (o script segue em frente com o código antigo, sem avisar que "ignorou" seu commit).

**Passos corretos, nessa ordem:**
1. `git push origin main` (o commit com código + migration precisa estar no remoto).
2. `auth-service-deploy --skip-migration-check` — deixa o script **buildar e fazer o rollout** da
   imagem nova mesmo com o head divergente. Seguro **só se a migration for puramente aditiva**
   (`INSERT ... ON CONFLICT DO NOTHING`, sem DDL que quebre queries do código velho ainda em voo
   durante o rolling update).
3. **Depois** do rollout convergir, rode a migration contra o container **novo**:
   ```bash
   C=$(docker ps --filter name=auth_service_api --format '{{.Names}}' | head -1)
   docker exec "$C" python -m alembic upgrade head
   ```
   Confira o log: tem que aparecer `Running upgrade <de> -> <para>, <mensagem>` — se não aparecer
   nada além das duas linhas de `Context impl`/`transactional DDL`, a migration **não rodou**
   (alembic achou que já estava em head porque leu o arquivo errado) — verifique direto no banco
   (`SELECT version_num FROM alembic_version`) antes de seguir.
4. Reconfirme com o critério de pronto do seu pedido (query da row, `cors-smoke.sh`, endpoint real).

**🔴 Armadilha #2b — `alembic_version.version_num` é `VARCHAR(32)`.** Nome de revision com mais de
32 caracteres passa em tudo (arquivo criado, imagem buildada, rollout OK) e só explode no **UPDATE
final** do `upgrade`, com `StringDataRightTruncation`. A transação reverte inteira — banco fica no
head anterior, sem aplicação parcial —, mas você já queimou um build+rollout. **Conte os caracteres
antes**, e se precisar renomear, mude o **nome do arquivo e o campo `revision` juntos**: o script
deriva o head esperado do nome do arquivo, então mudar só um faz o head check comparar coisas
diferentes. Caso real: `024_ads4pros_site_audience_backfill` (35) → `024_ads4pros_site_backfill`
(26), auth-service 2026-08-14. A convenção `NNN_nome_descritivo` do projeto já roça o teto —
`023_empresa_milionaria_audience` tem 31.

**Armadilha #3 (não entre em pânico):** logo após `docker service update --force --image ...`, o
smoke do PRÓPRIO script (`sleep 3` + `curl /health`) costuma pegar a janela do rolling restart —
**502/504 nos primeiros ~30-60s são normais**, os dois replicas ainda estão de pé/derrubando.
Antes de tratar como outage: `docker service ps auth_service_api` (replicas `Running` há segundos =
janela normal) + `curl /health` de novo depois de meio minuto. Só é incidente real se continuar
falhando depois disso.

**Ref:** registro da audience `empresa-milionaria`, auth-service 2026-08-14 (commit `b66b306`,
deploy `deploy-1786709899`). Script: `deploy/scripts/auth-service-deploy.sh` (comentário no topo do
próprio arquivo documenta o fluxo, mas não a ordem skip-check→build→migrate-pós-rollout).
