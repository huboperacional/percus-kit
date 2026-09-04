## Migration em prod com least-privilege: precisa da imagem NOVA *e* da credencial `migrator`, as duas ao mesmo tempo {#migration-imagem-nova-e-credencial-migrator-juntas}

`tags: alembic, migration, docker run, least-privilege, env-file, deploy, docker exec, permission denied, DATABASE_URL, role, docker service update`

**Contexto:** repo com least-privilege de banco já cutovado — o serviço em produção conecta com
uma role de aplicação (`*_app`, sem DDL), e existe uma role separada dona do schema (`*_migrator`)
só para migrations. `docker exec <container-em-pé> alembic upgrade head` falha, mas o erro
**muda** dependendo de qual dos dois problemas você bate primeiro:

1. `docker exec` no container que já está de pé roda a imagem ANTIGA — não tem o arquivo da
   migration nova (ver [alembic-head-mora-na-imagem](alembic-head-mora-na-imagem.md)). Sem erro,
   só fica parado no head velho.
2. Resolvido o (1) com `docker run` de uma imagem NOVA recém-buildada — `OSError: Connect call
   failed ('127.0.0.1', 5432)` ou `permission denied for schema public`. A `DATABASE_URL` do
   `.env`/entrypoint do serviço aponta pra role de app (sem DDL, às vezes nem resolve
   `localhost` corretamente fora do contexto Swarm do serviço).

**Causa raiz do (2):** a credencial de migration não é a mesma da app, e não está no `.env`
genérico do host — normalmente foi injetada no serviço via `docker service update --env-add`
(invisível pra quem só lê o compose) ou vive num arquivo dedicado no host
(`.env.migrator`, `600`, só `DATABASE_URL=<role migrator>`).

**Fix — os dois problemas resolvidos juntos, um comando:**
```bash
docker run --rm --network <rede-do-swarm> \
  --env-file /caminho/no/host/.env.migrator \
  <imagem>:<tag-recem-buildada> alembic upgrade head
```
`docker run` cria um container efêmero da imagem NOVA (resolve o 1), e `--env-file` sobrepõe
qualquer `DATABASE_URL` que a imagem traga embutida, injetando a role certa (resolve o 2) — sem
deixar a senha visível em `docker ps`/histórico de shell.

**Como achar a rede certa:** `docker inspect <container-do-serviço-real> --format
'{{json .NetworkSettings.Networks}}'` — não adivinhe o nome (`_default` raramente é o certo num
Swarm com múltiplas redes).

**Ordem que importa:** migration roda **antes** do `docker service update --force --image
<mesma-tag>`, reusando a MESMA tag que você acabou de testar — nunca buildar de novo pro rollout
(imagem diferente da que rodou a migration é a mesma classe de risco do
[build-dir-compartilhado-tag-nova](build-dir-compartilhado-tag-nova.md)).

**Ref:** Plexco Tasks, migration `106_notif_archived_at` (2026-09-03/04, s165).
