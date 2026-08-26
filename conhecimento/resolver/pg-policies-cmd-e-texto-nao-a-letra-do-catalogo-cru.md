## `pg_policies.cmd` devolve o comando por extenso (`'SELECT'`), não a letra do `pg_policy.polcmd` (`'r'`) {#pg-policies-cmd-e-texto-nao-a-letra-do-catalogo-cru}

tags: postgres, row level security, pg_policies, pg_policy, polcmd, harness, script de auditoria,
FOR SELECT, catalogo, view do sistema

**O padrão que engana:** um script de auditoria de RLS (rodando `SELECT ... cmd ... FROM
pg_policies`) precisa identificar se uma política é `FOR SELECT`. A documentação e a memória de
quem já mexeu no catálogo cru levam a comparar `cmd == 'r'` — que é o código de uma letra que o
PostgreSQL usa **internamente** pra `SELECT`/`INSERT`/`UPDATE`/`DELETE`/`ALL` (`'r'`, `'a'`, `'w'`,
`'d'`, `'*'`).

**O buraco:** essa letra existe só na coluna `polcmd` do catálogo cru `pg_policy` (tipo `"char"`).
A **view** `pg_policies` — a que qualquer script de auditoria normal consulta, porque já vem com
`tablename`/`policyname`/`qual`/`with_check` legíveis — expõe a mesma informação como **texto por
extenso**: `'SELECT'`, `'INSERT'`, `'UPDATE'`, `'DELETE'`, `'ALL'`. Comparar contra `'r'` nessa view
nunca bate — toda política `FOR SELECT` real passa como "comando errado", um falso positivo
silencioso.

```sql
-- Catalogo cru: polcmd e' char de 1 letra
SELECT polname, polcmd FROM pg_policy WHERE polrelid = 'minha_tabela'::regclass;
--  polname | polcmd
-- ---------+--------
--  minha_p | r

-- View do sistema: cmd e' texto por extenso -- MESMA politica, coluna diferente
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'minha_tabela';
--  policyname | cmd
-- ------------+--------
--  minha_p    | SELECT
```

**Regra prática:** antes de escrever a comparação, confira contra QUAL relação o script está
selecionando (`pg_policies` vs `pg_policy`) — não assuma pelo nome da coluna (`cmd` numa view,
`polcmd` no catálogo, mas o valor comparável muda de formato, não só de nome). Se o script já
seleciona de `pg_policies` (o caso comum, porque ela já faz o join com `pg_class`/`pg_namespace`
pra dar nome de tabela legível), compare contra a string por extenso.

**Como isso foi achado:** rodando o script real contra Postgres 17.10 (não em teoria) — a primeira
rodada com `cmd == 'r'` produziu um achado falso pra uma política que o teste de DDL, em paralelo,
já confirmava ser `FOR SELECT` de verdade. A segunda rodada, com `!= 'SELECT'`, ficou limpa. Prova
por leitura de código sozinha (sem rodar contra banco real) teria deixado passar — a diferença só
aparece na execução real.

**Ref:** Empresa Milionária, Frente A (primeiro acesso via WhatsApp provado), Task 6 do plano
`2026-08-26-primeiro-acesso-rls-whatsapp-provado`, 2026-08-26. `scripts/harness_schema_rls.py`.
