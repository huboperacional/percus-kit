## `docker stack` não lê o `.env`, e `${VAR:?msg}` com hífen na mensagem vira DEFAULT — renderize e compare com o spec vivo antes do deploy {#docker-stack-nao-le-env-e-hifen-no-interrogacao-vira-default}

`tags: docker, swarm, stack deploy, docker-compose, interpolacao, env, dotenv, deploy, R23`

Três armadilhas medidas juntas (tiatendo §00ai, 13/09/2026, Docker 28.5.2 na VPS), as três mudas.

**1. A stack não lê o `.env`.** `docker compose` carrega o `.env` do diretório do projeto;
`docker stack deploy` e `docker stack config` **não**. Canário com `.env` ao lado do compose e a
variável fora do shell: `rc=1`, `required variable X is missing a value` — com o `cwd` no diretório
ou com o compose por caminho absoluto. Com a variável no shell, o valor vem do shell.
Consequência: script de deploy que só exporta `IMAGE` não serve para compose que interpola segredo
do `.env`. E carregar o `.env` com `source` quebra em valor sem aspas com `&`, `;`, `|` ou `(` —
passe o ambiente por um parser (ex.: Python lendo só as chaves que o compose referencia).

**2. `:?` com hífen na mensagem NÃO recusa.** O template do Docker CLI testa o default `-` **antes**
do `:?`. `${X:?faltou-algo}` é lido como "variável `X:?faltou`, default `algo`": o deploy segue e
grava o texto `algo` no lugar do valor. Medido: com a variável no shell valendo `veio-do-shell`, o
render de `${X:?faltou-com-hifen}` deu `com-hifen`. Num `--requirepass`, isso é uma senha conhecida.
Trava: teste que lê o texto CRU do compose e reprova `-` dentro de qualquer `${VAR:?...}`. Um modelo
de interpolação escrito à mão no teste não pega — ele implementa o `:?` do jeito certo, e o Docker não.

**3. Teste local verde não diz o que o deploy vai APLICAR.** `docker stack deploy` reconcilia o
serviço inteiro contra o compose, e serviço mexido por `docker service update` (`--env-add`,
`--update-order`, `--args`) diverge do arquivo em silêncio. No caso: `update_config.order` vivo
`start-first` × compose `stop-first` (o deploy voltaria a derrubar o bot num boot que falhe), uma
flag `1` × `true`, uma versão `0.345.0` × a imagem inteira — com 32 testes verdes e mutação 13/13.
**Prova antes do deploy:** `docker stack config -c docker-compose.yml` com o MESMO ambiente que o
deploy vai usar, parseado e comparado campo a campo com `docker service inspect` (env e args por
sha256, nunca impressos). Deploy só com zero diferença, travado no sha do relatório revisado.

**Depois do deploy:** compare `Spec` × `PreviousSpec` do `docker service inspect` — é o "nada mudou"
honesto. Mesmo com env idêntica, a tarefa pode ser RECRIADA: a stack reordenou os `Mounts` (os mesmos
5, em outra ordem) e isso muda o `TaskTemplate`; `--resolve-image never` não evita. Com `start-first`
não houve queda — com `stop-first` teria havido.
