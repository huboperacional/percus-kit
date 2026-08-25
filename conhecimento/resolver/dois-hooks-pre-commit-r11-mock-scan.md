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

**Detalhe mecânico que custou 2 tentativas (Família Milionária, 2026-08-25):** o `mock-scan`
detecta o escape via regex `-m\s+"([^"]+)"` com `[regex]::Match` — **só o PRIMEIRO** `-m "..."` do
comando, não todos. Um `git commit -m "assunto" -m "corpo" -m "MOCK-OK: motivo"` com o marcador no
3º `-m` FALHA silenciosamente (o hook nunca olha ali). Precisa estar dentro do PRIMEIRO `-m` (pode
ser um único `-m "assunto\n\ncorpo\n\nMOCK-OK: motivo"` com quebras de linha reais). E `dois-hooks`:
há também um hook NATIVO separado (`.githooks/pre-commit`, instalado por
`percus-review:install-git-hooks`) que impõe o TTL de 5min do R11 lendo `.deepseek/reviews/*.jsonl`
por `mtime` — um review real rodado >5min antes (ex.: por causa de uma pergunta ao operador no meio)
bloqueia mesmo com achados tratados; a solução é rodar o review de novo IMEDIATAMENTE antes do commit,
sem nenhuma pausa (nem uma pergunta) entre as duas chamadas.
