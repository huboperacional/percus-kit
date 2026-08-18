## Túnel SSH para Postgres no Swarm: conecta, mas o banco nunca responde {#tunel-postgres-swarm-ingress}

tags: tunel ssh, -L, postgres, swarm, docker, ingress, mesh, ConnectionResetError, WinError 64, timeout, asyncpg, connection was closed in the middle of operation, alembic current, DNS interno, service name nao resolve, overlay

**Contexto:** `ssh -f -N -L 15432:postgres_postgres:5432 vps` sobe sem erro, `netstat` mostra a
porta escutando, mas qualquer cliente falha — ora `ConnectionResetError [WinError 64]`, ora
timeout puro no handshake.

**Duas causas distintas, que aparecem juntas e se disfarçam:**

1. **O alvo do forward é resolvido no HOST remoto, não dentro do Swarm.** `postgres_postgres` é
   DNS interno da rede overlay; o host não o resolve. Confirme com
   `ssh vps "getent hosts postgres_postgres"` — se não vier nada, o túnel encaminha para lugar
   nenhum. O IP do container na overlay também não é roteável do host.
2. **O ingress mesh aceita o TCP e não entrega.** Com `-L 15432:localhost:5432` (alvo correto,
   já que `docker service ls` mostra `*:5432->5432/tcp`), o TCP conecta em 0,0s — e o Postgres
   nunca responde ao SSLRequest. Teste decisivo, que separa "não conectou" de "conectou e o
   servidor está mudo":

```bash
python -c "
import socket
s = socket.create_connection(('127.0.0.1', 15432), timeout=15)
s.sendall((8).to_bytes(4, 'big') + (80877103).to_bytes(4, 'big'))  # SSLRequest
s.settimeout(15)
print('resposta:', s.recv(1))
"
```

TCP abre e o `recv` estoura o tempo = o problema está **depois** do túnel.

**Solução de contorno:** fale com o banco por `docker exec` no container, que é caminho interno e
não passa pelo ingress.

**Solução de verdade:** publicar a porta em modo `host` em vez de `ingress`, no stack. ⚠️ **Só faça
isso se o Postgres não for compartilhado.** Se outros produtos usam o mesmo container, mudar o modo
de publicação afeta todos eles e vira decisão do operador.

**Não é problema de chave/autenticação.** Antes de mexer em chave SSH: o SSH autentica normalmente
(o mesmo alias funciona para `docker exec`). O que falha é a **entrega do TCP depois do túnel**.
Criar chave nova não muda nada.

**Solução VALIDADA para banco de teste/efêmero (2026-08-12):** container publicado **direto pelo
docker** (fora do Swarm) não passa pelo ingress, e o túnel comum alcança:

```bash
ssh vps-auto "docker run -d --rm --name pg_teste -e POSTGRES_PASSWORD=descartavel \
  -p 127.0.0.1:5433:5432 postgres:17"
ssh -N -L 15433:127.0.0.1:5433 vps-auto &      # túnel comum, mesma chave de sempre
# cliente local em localhost:15433 conecta normalmente (provado com asyncpg, PostgreSQL 17.10)
ssh vps-auto "docker rm -f pg_teste"           # teardown sem rastro
```

Publicar em `127.0.0.1` da VPS (nunca `0.0.0.0`) mantém o container invisível para a internet —
só o túnel alcança. É o caminho para suíte de integração (RLS, CheckConstraint, migration) quando
não há Docker local.

**Ref:** Empresa Milionária, Fase 0, 2026-08-11 (diagnóstico); Fase A, 2026-08-12 (spike do
container efêmero validado de ponta a ponta — `D:\Claud Automations\Empresa-Milionaria\docs\superpowers\plans\2026-08-12-fase-a-dominio-pj.md`, emenda da Task 12). O comando documentado no handoff anterior estava
errado desde sempre e nunca havia sido exercido — o banco só tinha sido testado por `docker exec`.
