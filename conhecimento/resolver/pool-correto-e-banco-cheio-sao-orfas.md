## Pool com geometria correta e banco cheio ao mesmo tempo = conexões órfãs {#pool-correto-e-banco-cheio-sao-orfas}

`tags: postgres, pg_stat_activity, conexoes, pool, sqlalchemy, asyncpg, orfas, max_connections, tcp_keepalive, idle_session_timeout, cluster compartilhado, dispose, lifespan`

**Contexto:** o Postgres compartilhado bate o teto (`202/200`) e container novo começa a morrer nas
migrations do boot. O suspeito óbvio é "o app está com pool grande demais".

**Não conclua pelo `pg_stat_activity` sozinho. Meça os DOIS lados:**

1. Quantas o cliente REALMENTE segura:
   `docker exec <cid> cat /proc/net/tcp /proc/net/tcp6 | grep -c 1538` (5432 = 0x1538)
2. Quantas o servidor acha que existem:
   `select usename, count(*) from pg_stat_activity group by 1 order by 2 desc`

**A diferença é a contagem de órfãs** — conexões que o servidor mantém abertas e das quais nenhum
processo do seu lado tem o socket. Medido uma vez: 30 sockets no container (2 workers × `pool_size`
15, geometria CORRETA) contra **111** no servidor = 81 órfãs. Diminuir o pool ali teria sido remendo
no lugar errado.

**Dois sinais que confirmam órfã:**
- **Última query = `ROLLBACK`** em todas: assinatura de conexão devolvida ao pool, não em uso.
- **Idade máxima ≈ `net.ipv4.tcp_keepalive_time`** (default 7200s = 2h). Se nada passa de ~2h e
  `tcp_keepalives_idle`/`idle_session_timeout` estão em `0`, quem colhe é o kernel — o app nunca
  fechou.

**Causa raiz frequente em FastAPI/SQLAlchemy async:** o `lifespan` não chama `engine.dispose()`.
Todo SIGTERM (deploy, restart, scale) **abandona o pool inteiro** em vez de fechá-lo.

**Conserto, em duas camadas:**
- App: `await engine.dispose()` no shutdown do lifespan. Prove que RODA lendo o log do container que
  recebeu SIGTERM — não confie na suíte verde.
- Banco, como rede: `ALTER ROLE <app> SET idle_session_timeout = '5min'`. Seguro porque
  `pool_pre_ping=True` substitui a conexão morta de forma transparente.

**Armadilha de atribuição:** em Swarm, `client_addr` **não** identifica o container — todos na mesma
overlay aparecem com o IP do endpoint da rede. Quem identifica é o `usename`.
