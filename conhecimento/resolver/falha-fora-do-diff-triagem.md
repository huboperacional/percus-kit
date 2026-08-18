## Falha na suite completa fora do teu diff → triar pollution/pré-existente ANTES de assumir culpa {#falha-fora-do-diff-triagem}

`tags: pytest, suite completa, falha fantasma, ordering pollution, pre-existente, MultipleResultsFound, db de teste sujo, rodar isolado, git checkout base, fixture autouse, seed idempotente`

**Contexto:** auth-service /sso hardening (2026-07-14). A suite full deu `830 passed, 2 failed`, mas as 2 falhas eram em módulos que eu NÃO toquei (`tests/contracts/test_magic_v2.py` TTL + `test_resolve_org_v2.py` audit). Meu diff só mexeu em `redirect.py`/`sso`/`session` + testes deles. Assumir "quebrei algo" teria feito eu perseguir fantasma.

**Resolução — 2 checagens baratas, nesta ordem, antes de tocar em qualquer coisa:**
1. **Rodar as falhas ISOLADAS** (só elas, `pytest path::Class::test`). Se **passa isolada mas falha na suite** → é **ordering-pollution** (estado de DB/singleton deixado por outro teste no mesmo processo), não regressão tua. (Foi o caso do `test_resolve_org_v2` audit.)
2. **Rodar a falha que persiste isolada em `main` LIMPO** (tudo commitado → `git checkout <base>` detached, roda o único teste, `git checkout <branch>` de volta). Se **falha igual em main sem o teu diff** → é **pré-existente**, não tua. (Foi o `test_magic_v2` TTL: `MultipleResultsFound` = linhas duplicadas no DB de teste `percus_auth_test`, presente em `main`.)

**Regra:** `N passed, M failed` numa suite grande NÃO é "quebrei M" — é "M falham NESTE estado de DB/ordering". `MultipleResultsFound`/`.one()`/`scalar_one()` estourando é quase sempre **dado sujo acumulado no DB de teste compartilhado** (INSERTs de testes sem cleanup ao longo do tempo), não código. Um `UPDATE`-only seed (como o meu `_seed_sso_origins`) NUNCA cria duplicata — descarta essa hipótese de cara.

**Blindagem do próprio teste (pre-mortem pegou):** teste DB-gated que depende de estado de linha (origins, ttl) num DB compartilhado é frágil. Semeie o estado que ele assume com um **fixture autouse idempotente (UPDATE)** — remove o acoplamento oculto e evita false-pass/false-fail por drift do DB. Cross-ref feedback_subagent_db_tests_env.

**Ref:** auth-service /sso hardening (2026-07-14) — `830 passed, 2 failed`, ambas alheias ao diff. Memória `feedback_subagent_db_tests_env`.
