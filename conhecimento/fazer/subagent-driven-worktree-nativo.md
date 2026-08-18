## Fechar subagent-driven-development num worktree nativo do harness (`EnterWorktree`) {#subagent-driven-worktree-nativo}

`tags: subagent-driven-development, worktree, EnterWorktree, ExitWorktree, merge, plano commitado, harness nativo`

**Quando:** você rodou `superpowers:subagent-driven-development` isolado num worktree criado via
tool nativo do harness (`EnterWorktree`, não `git worktree add` cru) e chegou no fim do plano
(`superpowers:finishing-a-development-branch`, opção "merge local").

**Passos:**
1. **Commite o arquivo do plano ANTES de despachar o 1º subagent.** `writing-plans` salva em
   `docs/superpowers/plans/<data>-<tema>.md` mas não commita por padrão — se você só escreveu com
   `Write` no diretório original e depois entrou no worktree, o arquivo **não existe lá** (worktrees
   nativos compartilham histórico do git, não arquivos não-commitados do checkout de origem).
   Subagents revisores que tentam ler o plano por path vão reportar "arquivo não existe" e cair pra
   avaliar só contra o texto colado no prompt — funciona, mas quebra a rastreabilidade e é fácil de
   só notar no meio da Task 4. `git add` + commit do plano é o passo 0, junto com o `git merge main
   --ff-only` de sincronização.
2. Dentro de uma sessão isolada em worktree nativo, `cd` pro checkout compartilhado é **bloqueado
   pelo próprio harness** (erro explícito: "session isolated... refusing to run"). Isso invalida o
   `MAIN_ROOT=$(...); cd "$MAIN_ROOT"; git merge <branch>` que `finishing-a-development-branch`
   assume — não existe esse `cd` livre aqui.
3. Pra fazer o merge local: `ExitWorktree(action: "keep")` primeiro (preserva branch+worktree em
   disco, sessão volta pro diretório original) → rode `git merge <branch> --ff-only` (ou merge
   normal) de lá → rode a suíte no resultado → só então `git worktree remove <path>` +
   `git worktree prune` + `git branch -d <branch>`.
4. Se o merge falhar ou você quiser voltar a iterar no worktree, `EnterWorktree(path: <path
   original>)` reentra nele — não precisa recriar.

**Armadilhas:** tentar seguir `finishing-a-development-branch` ao pé da letra sem o `ExitWorktree`
primeiro — todo comando `cd`+git fora do worktree vai ser recusado pelo harness, não é erro de
git. Esquecer o commit do plano é sutil: os primeiros subagents (Task 1-2) não notam porque você
colou o texto completo no prompt deles; só aparece quando um revisor tenta `git show`/ler o path
por conta própria pra checar algo que o prompt não cobriu.

**Ref:** sessão tiatendo 2026-08-06 (reconciliação de billing, `worktree-billing-reconciliacao`) —
achado pelo revisor de code-quality da Task 4 ("plan file não existe em lugar nenhum na história
deste worktree"), corrigido commitando o plano no meio da execução; o bloqueio de `cd` foi pego
direto pela mensagem de erro do harness ao tentar `finishing-a-development-branch` sem
`ExitWorktree`.
