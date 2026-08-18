## `alembic upgrade head` não vê a migration nova: ela mora DENTRO da imagem {#alembic-head-mora-na-imagem}

`tags: alembic, migration, docker, deploy, ordem de deploy, upgrade head, docker cp, aditiva, rollback nao pareado, imagem, base64, md5`

**Contexto:** plano de deploy dizia "aplicar a migration ANTES da imagem" (correto em princípio: com a imagem nova primeiro, o código escreve numa tabela que ainda não existe e loga `relation does not exist` a cada tick). Rodei `docker exec <container-prod> alembic upgrade head` → **nenhuma saída, e `alembic current` continuou na revisão anterior**.

**Causa raiz:** o arquivo `versions/NNNN_*.py` é COPIADO para dentro da imagem no build. O container em produção roda a imagem ANTIGA, que não contém a revisão nova — para o alembic dela, a revisão anterior **é** o head. Não há erro: ele "aplica tudo até o head que conhece", que é nada. `alembic heads` confirma (mostra a revisão velha).

**Fix (quando a migration é ADITIVA):** injetar só o arquivo no container em execução e rodar ali —
`docker cp NNNN_x.py <container>:/app/alembic/versions/` → `docker exec <container> sh -c "cd /app && alembic heads && alembic upgrade head"`. É inócuo porque a imagem antiga não lê o objeto novo. O arquivo some no próximo deploy, quando a imagem nova já o traz.

**Transferir o arquivo sem SFTP/registry:** base64 em blocos por SSH e conferir MD5 dos dois lados — fatiar em ~20k chars, `printf "%s" "<chunk>" >> f.b64`, `base64 -d f.b64 > f.py`, `md5sum`. Sem o MD5 você não sabe se truncou.

**Se a migration NÃO for aditiva** (drop/alter destrutivo), o `docker cp` não resolve: aí a ordem é imagem→migration e você aceita a janela de erro, ou para o serviço. E lembre que `DROP` torna o rollback **pareado** — ver [rollback pareado](drop-table-rollback-pareado.md).

**Conferir sempre em `information_schema`/`pg_constraint`, nunca na saída do alembic.**

**Ref:** Paid Media Automation, migration `0029_crm_signal_state` (2026-07-29).
