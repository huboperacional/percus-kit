## Banco novo para um segundo tenant quando a cadeia de migrations não roda do zero {#tenant-novo-cadeia-migrations-quebrada}

`tags: multi-tenant, duplicacao, pg_dump schema-only, migrations nao replayam, _migrations seed, GRANT matview, ALTER DEFAULT PRIVILEGES, REVOKE CONNECT PUBLIC, isolamento, least-privilege, Postgres`

**Origem:** Micro Investors, 2026-07-31 — provisionamento do 2º tenant por duplicação total.

Produto single-tenant precisava servir um segundo cliente com **separação física** (banco próprio +
stack própria). O caminho `tenant_id` em todas as tabelas foi descartado no pre-mortem. O primeiro
obstáculo foi inesperado: **as migrations não sobem um banco do zero** — a cadeia inicial referenciava
um schema (`auth`) que uma migration posterior **dropou**, então replayar quebra no meio.

**Receita que funcionou:**
1. `pg_dump --schema-only --no-owner --no-privileges` do banco vivo. **Os dois flags são o ponto:**
   sem eles o dump carrega os GRANTs da role do tenant A, e a credencial de um alcança o banco do
   outro — matando a separação que motivou o trabalho.
2. Role própria por tenant, com os mesmos grants. **`GRANT` nominal nas matviews:**
   `ALTER DEFAULT PRIVILEGES ... ON TABLES` **não cobre** `MATERIALIZED VIEW` (relkind `m`) — matview
   nova nasce ilegível e a falha só aparece no runtime da app.
3. **Semear a tabela de controle de migrations** com o que já foi aplicado, senão o runner considera
   o banco virgem e tenta replayar a cadeia que não roda.
4. **Re-aplicar o endurecimento que não vem no dump.** Tudo que foi feito com `GRANT`/`REVOKE` direto
   em produção (e não como migration) desaparece com `--no-privileges`. Se existe nota do tipo "se o
   DB for recriado, re-aplicar", é agora.
5. **`REVOKE CONNECT ON DATABASE ... FROM PUBLIC` nos DOIS bancos.** No Postgres o `PUBLIC` tem
   `CONNECT` por padrão: sem isso, **toda role de login do cluster** abre sessão no banco de todos.
   Ler não consegue (sem grant de tabela), mas enumera catálogo e consome slot.

**Como provar o isolamento (e não só afirmar):** teste as duas direções com **credenciais válidas**.
Testar com senha errada devolve `password authentication failed` e não prova nada sobre permissão — o
verde esperado é `FATAL: permission denied for database`. Fecha com a sentinela em
`pg_stat_activity`: cada API na sua base, com a sua role.

**Custos a assumir por escrito:** todo deploy sai em dose dupla; a migration precisa rodar nos dois
bancos (runner com o banco hardcoded vira dívida imediata); não existe visão consolidada entre
tenants; e o frontend, se assar config no build, precisa de **uma imagem por tenant** — com gate
**fail-closed** no build, porque o modo de falha silencioso é o frontend de um cliente falando com a
API do outro.

**Relacionado:** [#env-var-vence-dotenv] — as duas mordem por "o que está no arquivo não é o que está
valendo".
