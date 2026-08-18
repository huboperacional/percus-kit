## Dois hooks de pre-commit diferentes bloqueiam por motivos diferentes {#dois-hooks-pre-commit-r11-mock-scan}

tags: pre-commit, hook, mock-scan, R11, review, TODO, bloqueio, git commit

**Sintoma:** review R11 (`/percus-review:review`) passou sem achado, mas `git commit` ainda falha.
Fácil assumir que é o MESMO gate de review falhando de novo (e re-pedir review ao operador à toa,
perdendo tempo).

**Causa raiz:** existe um segundo hook, `mock-scan-pre-commit`, independente do R11 — ele varre o
diff por marcadores tipo `// TODO`/mock e bloqueia mesmo que o TODO seja PRÉ-EXISTENTE (não
introduzido pelo seu diff atual).

**Solução:** leia a mensagem do hook com atenção — ela cita o arquivo:linha exato — antes de
assumir que é o mesmo bloqueio de review R11. Resolver exige ou tocar o TODO pré-existente (fora do
escopo original da tarefa) ou pedir autorização explícita do operador pra um prefixo tipo
`MOCK-OK: <motivo>` — não é algo que o agente deve se autorizar sozinho.

**Ref:** Paid Media Automation, sessão cont.157 (2026-08-07) — trilha do título isolado bloqueada
por TODO em `approvals/page.tsx:138`, não relacionado ao diff da tarefa em andamento.
