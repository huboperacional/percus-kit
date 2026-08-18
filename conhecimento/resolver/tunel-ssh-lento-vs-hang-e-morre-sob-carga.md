## Teste "travado" via túnel SSH pode ser lento de verdade, não hang — e o túnel morre sob carga sustentada {#tunel-ssh-lento-vs-hang-e-morre-sob-carga}

`tags: ssh tunnel, postgres, asyncpg, timeout, hang, teste lento, faulthandler, connection refused, sqlalchemy nullpool`

**Contexto:** sessão Scraper-prospeccao 2026-08-03/04, Task 11 do plano "motor de coleta
multi-provider". `pytest tests/test_places_worker.py::test_places_query_uses_grid_search_when_target_exceeds_google_cap`
ficava sem nenhum output novo por 10-16 minutos — parecia travado.

**Sintoma:** processo pytest vivo, ~0-2% de CPU (não é loop infinito, é espera de I/O), sem
avançar. Diagnóstico ingênuo ("deve ser deadlock no código") levaria a caçar bug de concorrência
que não existe (o worker é sequencial, sem `asyncio.gather`).

**Causa raiz — duas coisas empilhadas, cada uma real:** (1) um bug genuíno no MOCK do teste
(`get_details` com `return_value` fixo em vez de `side_effect` variando por `place_id`) fazia ~90
resultados de grid colapsarem em upserts repetidos contra o MESMO contato — não travava, mas era
lento à toa e não testava o que alegava. (2) mesmo corrigido, o teste ainda fazia ~180 commits
reais sequenciais via túnel SSH pro Postgres do VPS, a ~1,5-2s cada (medido com script standalone
`faulthandler.dump_traceback_later(N)` + prints de progresso por chamada) — genuinely lento
(~5-8min), não hang. Por fim, sob carga sustentada de HORAS (múltiplas rodadas de suíte grandes
na mesma sessão), o processo `ssh -f -N -L` do túnel **morreu de verdade** 3 vezes (`ssh: connect
... Connection timed out` do lado do cliente; depois disso qualquer `asyncpg.connect()` novo falha
com `TimeoutError`/`ConnectionRefusedError` em cascata pro resto da suíte).

**Solução:** (1) antes de assumir "travou", instrumentar com
`faulthandler.dump_traceback_later(N, exit=False)` + prints de progresso por chamada num script
standalone que replica o cenário fora do pytest — isola rápido se é hang real (stack parado no
mesmo ponto) ou I/O genuinamente lento (progresso visível, só devagar). (2) medir latência real de
round-trip com um engine `NullPool` isolado (`SELECT 1` × N) antes de suspeitar do código — se o
round-trip isolado também está lento/alto, é o túnel, não a lógica. (3) se o processo `ssh` do
túnel sumiu (`Get-Process -Id <pid>` vazio) ou uma nova tentativa de conexão dá "Connection timed
out" na porta 22 (não "refused" — timed out é rede, refused é o daemon recusando), religar:
`ssh -f -N -L 15432:<host-vps>:5432 root@<vps>` e confirmar com `Test-NetConnection` + 1 round-trip
antes de retomar. (4) NUNCA rodar 2 suítes/scripts pesados em paralelo contra o mesmo túnel —
agrava a lentidão real a ponto de parecer travamento. (5) pra suítes de ~900 testes que legitimamente
levam horas, aceitar que o túnel pode cair NO MEIO — se 670+ testes já rodaram verdes antes da
queda e o resto são só `TimeoutError`/`ConnectionRefusedError` em cascata (não asserções falhas
distintas), é 1 evento de infra, não N bugs — não precisa relançar a suíte inteira de novo se cada
arquivo relevante já foi verificado individualmente com túnel saudável.

**Ref:** sessão Scraper-prospeccao 2026-08-03/04, Task 11+review final do plano "motor de coleta
multi-provider" (commits `e217451`, `5585791`).
