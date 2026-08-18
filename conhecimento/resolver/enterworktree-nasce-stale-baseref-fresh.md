## `EnterWorktree` (ferramenta nativa) nasce STALE quando `main` local está à frente de `origin` {#enterworktree-nasce-stale-baseref-fresh}

`tags: EnterWorktree, git worktree, worktree.baseRef, origin desatualizado, subagent-driven-development, worktree stale`

**Contexto:** projeto onde `main` local acumulou commits sem push (`origin/main` ficou pra trás —
comum quando o operador decide "manter local por enquanto"). Sessão usa a ferramenta nativa
`EnterWorktree` (não `git worktree add` manual) pra isolar uma frente de implementação.

**Sintoma:** o worktree recém-criado não tem os commits mais recentes do `main` local — `git log
--oneline HEAD..main` no worktree mostra dezenas/centenas de commits "faltando", incluindo trabalho
da MESMA sessão que acabou de ser commitado em `main` minutos antes.

**Causa raiz:** o comportamento default de `EnterWorktree` é `worktree.baseRef=fresh`, que cria a
branch nova a partir de `origin/<default-branch>`, não do HEAD local. Se `origin/main` está atrás
(sem push), o worktree nasce apontando pra essa versão antiga — silenciosamente, sem erro.

**Solução:** depois de criar o worktree, SEMPRE checar `git log --oneline HEAD..main | wc -l`
(rodado dentro do worktree, comparando contra o `main` do repo principal). Se não for zero:
`git merge main --ff-only` dentro do worktree, ANTES de qualquer outro trabalho — passo 0
obrigatório, não opcional. Confirmar depois com o mesmo `wc -l` (deve dar 0). Isso vale mesmo que o
worktree tenha acabado de ser criado na mesma sessão — a staleness não é sobre "worktree antigo",
é sobre a origem do branch base.

**Como pegar isso ANTES de perder trabalho:** não assuma que `EnterWorktree` reflete o estado atual
do repo só porque acabou de ser chamado. O check de staleness (`git log --oneline HEAD..main`) leva
2 segundos e evita implementar em cima de uma árvore desatualizada, depois descobrir no merge que
faltava metade do trabalho recente.

**Ref:** tiatendo, frente C13/C16 (sinal de troca de modo), sessão 2026-08-06 — worktree
`worktree-c13-c16-sinal-modo` nasceu 190 commits atrás de `main` local (que incluía toda a spec e
plano commitados minutos antes na mesma sessão); `git merge main --ff-only` corrigiu antes de
qualquer implementação.
