## A corrida do backlog não reproduz hoje porque a TOPOLOGIA a serializa — segurança incidental, não desenho {#corrida-em-prod-mascarada-por-topologia-de-um-worker}

tags: race condition, last-write-wins, asyncio, event loop, replicas, uvicorn workers, lock,
seguranca incidental, topologia de deploy, read-modify-write, backlog, R23

**Sintoma:** o backlog descreve uma corrida real e plausível ("dois requests concorrentes
sobrescrevem o YAML/arquivo/registro — last-write-wins"), o código confirma que não há lock nenhum,
e mesmo assim ninguém nunca viu o defeito acontecer em produção. A tentação é tratar como "bug
latente que ninguém mediu" e sair implementando lock — ou, pior, concluir que o item é fantasma.

**Causa raiz:** num serviço FastAPI/asyncio com **1 réplica, 1 worker e nenhum `await` no meio do
read-modify-write**, o próprio agendador coopera contra a corrida: a função síncrona (abrir, ler,
mutar, escrever, fechar) roda até o fim **sem ceder o loop**, então o segundo request nem começa a
executar o trecho antes de o primeiro terminar. A serialização existe — mas é **efeito colateral da
topologia**, não garantia de desenho.

**Os quatro fatos que decidem, e cada um se mede em um comando:**

| fato | como medir | o que significa se mudar |
|---|---|---|
| réplicas | `grep -A2 replicas docker-compose.yml` / `docker service ls` | `2` ⇒ processos distintos, corrida REAL |
| workers do uvicorn | `grep -n "workers" Dockerfile run.py` | `--workers N>1` ⇒ idem, no mesmo host |
| threads | `grep -rn "threading.Thread\|ThreadPoolExecutor\|run_in_executor\|to_thread" <pkg>` | qualquer hit ⇒ paralelismo real dentro do processo |
| `await` no trecho crítico | ler a função inteira, do `open` ao `close` | um `await` no meio ⇒ ponto de cessão ⇒ corrida REAL já hoje |

Rota FastAPI declarada como `def` (não `async def`) também quebra a premissa: o framework a joga
num threadpool, e aí são threads de verdade.

**Como reportar (é isto que muda a decisão do operador):** não diga "não é reproduzível, fecha o
item"; diga **"não reproduz HOJE, por acidente de topologia, e volta no dia de qualquer um destes
quatro"**. O item continua legítimo — o que muda é a justificativa (blindar contra mudança de
topologia) e a escolha de mecanismo: lock distribuído (Redis, sobrevive a `replicas: 2`) versus lock
de processo (`threading.Lock`, morre calado na primeira réplica nova).

🔑 **O precedente que fecha o argumento:** nesta casa a MESMA dinâmica já foi paga uma vez — dedup e
rate-limit ficaram meses em fallback em-processo e só não quebraram porque `replicas: 1`, com o
achado registrado como *"a mina é escalar"*. Segurança incidental não é bug enquanto ninguém escala;
é dívida com data de vencimento desconhecida.

**Relacionado:** [gather não produz corrida](gather-nao-produz-corrida.md) — mesma mecânica (sem
ponto de cessão não há intercalação), do lado do TESTE em vez do lado da produção.

**Ref:** tIAtendo, `PENDENCIAS §00ab` (escrita de YAML de tenant sem lock), medido em 2026-09-09:
`replicas: 1`, `CMD uvicorn` sem `--workers`, zero hits de thread em `execution/`, e as 5 funções de
escrita 100% síncronas — 9 pontos de escrita sem lock, corrida não reproduzível hoje, item mantido
aberto e o desenho (distribuído × local) devolvido ao operador.
