## `docker build` em cima de uma imagem delta bate `max depth exceeded` — rode em volume, não em camada nova {#docker-build-em-cima-de-imagem-delta-bate-max-depth}

`tags: docker, max depth exceeded, deploy delta, camadas, testrunner, docker run volumes, FROM encadeado`

**Sintoma:** `docker build` de uma imagem auxiliar (ex.: um "testrunner" com `pytest`+deps
instalado) usando `FROM <imagem-de-deploy-recém-promovida>` devolve
`docker: Error response from daemon: max depth exceeded` — mesmo a imagem-base tendo acabado de
ser construída com sucesso segundos antes.

**Causa raiz:** deploy por delta (`FROM <versão anterior> + COPY execution`) encadeia UMA camada
nova a cada versão, pra sempre — a cadeia nunca é achatada entre deploys. Cada imagem nova soma
sua própria profundidade à de TODAS as anteriores. Construir qualquer coisa `FROM` essa imagem
(mesmo só pra rodar testes, nunca pra promover) empurra a cadeia pro limite do storage driver
mais cedo do que se pensa — o limite é da árvore de camadas INTEIRA, não da imagem que você
acabou de construir.

**Por que passa despercebido até bater:** cada deploy individual continua funcionando (o
`docker build` do PRÓPRIO delta de produção tem profundidade N; o problema só aparece quando
ALGUÉM tenta empilhar MAIS UMA camada em cima — nesse caso, um testrunner efêmero pra rodar a
suíte na imagem exata promovida). O sintoma nasce no consumidor da imagem, não no deploy que a
criou, então o primeiro sinal costuma vir de um script auxiliar (harness de teste, imagem de
debug), não do pipeline de deploy principal.

**Solução (contorno imediato, sem reconstruir nada):** não crie uma imagem nova em cima da
promovida — rode um container efêmero da imagem promovida com o que falta (deps extras, arquivos
de teste) montado por **volume**, e instale/execute tudo dentro do processo do `docker run`, sem
`docker build`:

```bash
docker run --rm \
  -v /caminho/tests:/app/tests \
  -v /caminho/pytest.ini:/app/pytest.ini \
  -v /caminho/requirements-dev.txt:/app/requirements-dev.txt \
  --entrypoint sh <imagem-promovida> -c \
  "pip install --no-cache-dir pytest pytest-asyncio -r requirements-dev.txt && \
   python -m pytest tests/caminho/dos/testes_focais.py -q"
```

Isso não adiciona nenhuma camada à cadeia — a instalação de deps vive só na vida do container
efêmero, e some quando ele termina (`--rm`).

**Solução de fundo (não aplicada, registrada pra quando o limite bater no PRÓPRIO delta de
deploy):** achatar a cadeia periodicamente com uma base "flat" — `docker export`/`docker import`
(ou `docker build --squash`, se o daemon suportar) da imagem de produção atual, virando uma nova
base "burra" (sem histórico de camadas) a partir da qual os próximos deltas recomeçam a contar.
Medir a profundidade ANTES de decidir (`docker history <imagem> | wc -l` dá uma proxy — não é o
número exato que o storage driver usa, mas mostra a tendência) evita descobrir o limite no meio
de um deploy real.

**Ref:** tiatendo, imagem `ads4pros/tiatendo:0.334.0` (01/09/2026) — o `docker build` do PRÓPRIO
delta de deploy (`FROM 0.333.0 + COPY execution`) funcionou normalmente; foi o testrunner
auxiliar (`FROM 0.334.0`, pra rodar pytest) que bateu o limite.
