## SDD em árvore compartilhada: o `BASE` do `review-package` fica errado se gravado antes do dispatch {#sdd-review-package-base-em-arvore-compartilhada}

`tags: subagent-driven-development, review-package, arvore compartilhada, multi-sessao, BASE, HEAD, git log, diff isolado`

**Sintoma:** seguindo `superpowers:subagent-driven-development` numa árvore com várias sessões
concorrentes commitando na MESMA branch, o `BASE` que a controller grava com `git rev-parse HEAD`
antes de despachar o implementador já não é mais o pai do commit da task quando o implementador
termina — outra sessão commitou algo no meio. Rodar `scripts/review-package PLAN_FILE BASE HEAD`
com esse `BASE` antigo produz um diff que mistura o trabalho da task com o commit alheio que
entrou no meio, e o task-reviewer recebe um pacote de review que não é só da task dele.

**Por que acontece:** o protocolo do skill assume implicitamente uma branch isolada (worktree por
plano) — em produção real, várias sessões Percus podem estar todas commitando na mesma branch
principal ao mesmo tempo (achado numa sessão com 7+ sessões concorrentes na mesma árvore,
`empresa-milionaria`). `git rev-parse HEAD` antes do dispatch e o HEAD real no momento do
`review-package` divergem sempre que alguém mais commitou nesse intervalo — e o intervalo inclui
o tempo inteiro que o implementador passa rodando.

**Fix:** nunca confie no `BASE` gravado antes do dispatch. Depois que o implementador reporta
`DONE` com um commit `<hash>`, gere o `review-package` com:

```bash
git log --oneline -1 <hash>^   # confirma quem é o pai real
scripts/review-package PLAN_FILE <hash>^ <hash>
```

Ou seja: **o `BASE` é sempre o pai DIRETO do commit que a própria task fez**, nunca um hash
gravado num momento anterior. Isso isola o diff corretamente mesmo que 5 outras sessões tenham
commitado no meio — o `review-package` mostra só o `1 commit(s)` da task, como esperado.

Mesma lógica vale pro fix-loop: o `FIX_BASE` do re-review escopado é o pai direto do commit de
fix, não o `HEAD` que a controller tinha antes de despachar o round de fix.

**Achado irmão:** uma mudança num arquivo de teste COMPARTILHADO (helper de mock usado por várias
specs, ex.: `pjMock.ts`) só é segura se verificada contra a SUÍTE INTEIRA do domínio, não só o
spec da task que a motivou — um implementador pode reportar "verifiquei só contra este spec" como
concern explícito, e rodar a suíte completa antes de aceitar a task como pronta é o que pega a
regressão silenciosa em specs alheios (achado real: mudança em `pjMock.ts` pra suportar um novo
teste quebrou 3 testes de busca-debounced em outro arquivo, só visível rodando `npx playwright
test -c playwright.pj.config.ts` sem filtro).

**Ref:** Empresa Milionária, sessão `empresa-milionaria-fb`, 2026-08-28 — execução do plano
`docs/superpowers/plans/2026-08-28-relatorio-pj-frontend.md` via `subagent-driven-development`,
5 das 8 tasks fechadas tiveram BASE interleaved por sessão concorrente; achado da regressão em
`pjMock.ts` na Task 8.
