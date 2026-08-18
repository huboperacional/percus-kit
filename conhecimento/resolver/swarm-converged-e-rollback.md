## `service update` diz "converged" mas o serviço continua na imagem VELHA (rollback silencioso) {#swarm-converged-e-rollback}

`tags: docker swarm, service update, converged, rollback_completed, UpdateStatus, healthcheck, CRLF, entrypoint.sh, exec no such file or directory, shebang, no-resolve-image, force, deploy, windows, tar, gate de imagem`

**Contexto:** deploy de imagem construída no próprio VPS (sem registry). `docker service update --image ... --no-resolve-image` respondeu `verify: Service X converged` — e o serviço continuou rodando a tag antiga, com a task de 3 horas atrás intacta. `--force` também "convergiu" sem trocar nada.

**Causa raiz:** o swarm SUBIU a task nova, ela reprovou no healthcheck, ele reverteu, e a mensagem `converged` é sobre **o rollback ter convergido**, não sobre o update ter dado certo. O sinal está em `docker service inspect X --format "{{.UpdateStatus.State}}"` → **`rollback_completed`**. `docker service ls` mostra a imagem do spec vigente (a velha), o que reforça a ilusão de que o comando não foi executado.

**Por que a task nova morria:** `exec /usr/local/bin/entrypoint.sh: no such file or directory` — o arquivo EXISTE. O shebang estava `#!/bin/sh` seguido de CR+LF, então o kernel procurava um interpretador com `\r` no nome. O contexto de build tinha sido empacotado no Windows. Diagnóstico: `file entrypoint.sh` → *"with CRLF line terminators"*, ou `head -c 20 entrypoint.sh | od -c` mostrando o `\r`.

**Fix:** `sed -i "s/\r$//" entrypoint.sh && chmod +x entrypoint.sh` no contexto, rebuildar. Varrer o contexto inteiro em busca de outros `.sh` com CR antes.

**Duas armadilhas que amplificam:**
1. **Gate de conteúdo não vê fim de linha.** Seis gates do tipo `docker run --entrypoint sh <img> -c "test -f ... && grep -q ..."` passaram TODOS na imagem morta. O único gate que pega é **subir o container e bater no health**: `docker run -d --env-file <env real> --network <rede real> <img>`, esperar ~20s, `docker ps --format "{{.Status}}"` (tem que dizer `healthy`) + `curl -sf localhost:8000/health`. Fazer isso ANTES do `service update`, sempre.
2. **Serviço SEM healthcheck aceita a imagem morta em silêncio.** O serviço irmão (worker ARQ, sem healthcheck) engoliu a mesma imagem quebrada e reportou `1/1` + `completed`. Ou seja: o serviço que tinha healthcheck protegeu mentindo "converged"; o que não tinha desprotegeu dizendo a verdade. **Depois de qualquer deploy, confira `UpdateStatus.State == completed` E `service ps` mostrando task nova ("Running N seconds ago"), serviço por serviço.**

**Env real sem vazar segredo:** `docker inspect <container-rodando> --format "{{range .Config.Env}}{{println .}}{{end}}" > /tmp/x.env` e usar `--env-file`. A rede certa vem de `docker inspect <container> --format "{{range $k,$v := .NetworkSettings.Networks}}{{println $k}}{{end}}"` — chutar `<stack>_default` falha (aqui era `network_swarm_public`).

**Ref:** Paid Media Automation, deploy `crm-140bebb` (2026-07-29). Relacionado: [imagem local sem registry](swarm-local-image-resolve.md), [build pipe mascara exit](deploy-pipe-mascara-exit.md).
