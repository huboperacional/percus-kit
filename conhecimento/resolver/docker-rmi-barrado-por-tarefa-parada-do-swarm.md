## `docker rmi` da imagem de rollback falha com "container is using its referenced image" mesmo com o serviço em outra imagem {#docker-rmi-barrado-por-tarefa-parada-do-swarm}

tags: docker, swarm, rmi, imagem, rollback, limpeza, task history, conteiner parado, vps

**Sintoma.** Depois de um deploy conferido, a limpeza da imagem antiga falha:
`conflict: unable to remove repository reference "app:anterior" (must force) - container 01c89d6556cb is using its referenced image`.
O `docker service inspect` mostra o serviço na imagem nova, e `docker ps` (sem `-a`) não lista nada na antiga.

**Causa.** O Swarm guarda as **tarefas antigas** do serviço como contêineres parados (histórico de
tarefas, `task-history-limit`, 5 por padrão): a réplica que rodou antes de cada `service update`, a que
saiu com erro e foi substituída, e até uma tarefa só `Created` que nunca subiu. Esses contêineres
continuam referenciando a imagem com que nasceram, e o `rmi` recusa.

**Correção.** Liste o que prende a imagem, confira que **nada está rodando**, e só então apague os
contêineres e a imagem — sem `--force`, que tiraria a tag de uma imagem em uso sem avisar:
```bash
docker ps -a --filter ancestor=app:anterior --format '{{.ID}} {{.Names}} {{.Status}}'
# todos "Exited" ou "Created"? então:
docker rm <ids>
docker rmi app:anterior
```
Se aparecer um `Up`, **pare**: a imagem ainda está servindo algo (outra réplica, outro serviço).

**Verificação.** `docker images app` sem a tag antiga, o serviço ainda na imagem nova
(`docker service inspect <svc> --format '{{.UpdateStatus.State}} {{.Spec.TaskTemplate.ContainerSpec.Image}}'`)
e a rota principal em 200 depois da limpeza.

Visto em 15/09/2026 (LiliCalc): três tarefas paradas de `lilicalc_web` (duas `Exited (1)`, uma `Created`)
prendiam `lilicalc:botoes-envio`, uma imagem que já não rodava fazia duas horas.
