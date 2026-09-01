## Suíte contra Postgres efêmero não fecha via túnel SSH — rode de DENTRO da VPS {#suite-postgres-via-tunel-nao-fecha-rode-de-dentro-da-vps}

`tags: postgres, ssh tunnel, docker, vps, pytest, latencia, round-trip, container efemero`

**Contexto:** Empresa Milionária, 31/08/2026. `pytest -m postgres` (59 testes, contra container
efêmero na VPS, procedimento documentado) não fechou em **nenhuma** das três tentativas via túnel
SSH local (`ssh -N -L 5598:...` + processo Python rodando na máquina do operador) — nem em ~20min,
nem em 60min, em três sessões Claude Code diferentes no mesmo dia. Cada tentativa foi interrompida
sem saber se era travamento (hang) ou só lentidão — ver `tunel-ssh-lento-vs-hang-e-morre-sob-carga`
para como DIAGNOSTICAR essa dúvida quando ela importa.

**O que resolveu, sem precisar diagnosticar:** rodar o `pytest` de **dentro da própria VPS**, não
mais tunelando a conexão de banco pra fora. Mesma suíte, mesmo container Postgres, zero mudança de
teste — só o processo Python que fala com o banco passou a rodar NA MESMA REDE DOCKER do Postgres
em vez de atravessar `internet → SSH → VPS` a cada query. Fechou em **82–88 segundos**, quatro
rodadas seguidas.

**Por que a diferença é tão grande:** o gargalo nunca foi o Postgres processando — é o round-trip
de REDE por query (medido à parte: ~470ms por round-trip pelo túnel). Uma suíte de isolamento
multi-tenant faz muitas queries pequenas (uma por asserção de RLS); a latência do túnel se
multiplica por todas elas, e SSH tunneling adiciona handshake TCP+criptografia em cada ida-e-volta
que uma conexão local/mesma-rede não paga.

**Como montar sem arriscar o banco de produção nem vazar credencial** (os dois erros óbvios que a
tentação de "atalho" produz):

1. **Rede Docker isolada e nova** (`docker network create <nome>-<timestamp>`, tipo `bridge`
   local) — nunca a rede overlay do swarm de produção. Containers numa bridge local não enxergam
   os serviços do swarm por padrão; é a isolação, não um acidente feliz.
2. **Postgres descartável nessa rede**, sem publicar porta nenhuma — a comunicação é interna à
   rede Docker (resolução de nome do container funciona nativamente em rede bridge definida pelo
   usuário).
3. **NUNCA rode dentro do container da aplicação de produção**, mesmo que ele já tenha
   `DATABASE_URL`/dependências prontas e pareça o atalho óbvio: (a) ele roda o código DEPLOYADO,
   não o checkout atual — testaria uma versão errada; (b) se a suíte fizer qualquer `DROP
   SCHEMA`/limpeza destrutiva e a resolução de URL escorregar pro `DATABASE_URL` real por
   qualquer motivo (variável herdada, fallback do settings), o alvo é o banco de PRODUÇÃO.
4. **Leve o checkout por `tar`/`scp` excluindo explicitamente `.env*` e a venv/`node_modules`** —
   copiar a pasta inteira deposita credencial em texto claro num caminho novo da VPS que sobrevive
   ao container (`--rm` limpa o container, não o disco do host).
5. Container de execução **descartável** (`docker run --rm`, imagem genérica tipo `python:3.12`),
   nunca um container de longa duração já em uso por outra coisa.
6. **Derrubar tudo no mesmo bloco de comandos** ao final — container, rede, diretório do checkout
   no host — não em etapa separada; tentativas anteriores foram interrompidas por tempo, e limpeza
   acoplada sobrevive a isso.

**Quando vale o trabalho extra:** só quando a suíte via túnel já falhou em fechar mais de uma vez
E o ganho de latência é o suspeito principal (muitas queries pequenas, não poucas queries grandes).
Pra uma suíte pequena ou rodada única, o túnel documentado é mais simples e continua correto.

**Ref:** sessão Empresa Milionária, 31/08/2026 (commits `cde748b`, `8da5c3e` no repo do projeto).
