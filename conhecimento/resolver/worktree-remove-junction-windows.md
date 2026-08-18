## `git worktree remove` falha com "Invalid argument" (não timeout) quando o worktree tem uma junction do Windows dentro {#worktree-remove-junction-windows}

`tags: git worktree, Windows, junction, mklink, node_modules, Invalid argument, remove failure`

**Contexto:** Paid Media Automation, sessão 2026-08-04/05 — um subagente rodando num worktree git
isolado (`isolation:"worktree"`, sem `npm install` automático) usou `mklink /J` pra apontar
`web/node_modules` pro `node_modules` do repo PRINCIPAL, evitando um install lento só pra rodar
`tsc`/`vitest`. Depois do trabalho concluído, `git worktree remove --force` nesse worktree
específico falhou com `error: failed to delete '...': Invalid argument`.

**Causa raiz:** o deletador recursivo do `git worktree remove` no Windows não sabe lidar direito com
um reparse point (junction) no meio da árvore que está apagando — outros worktrees com
`node_modules` REAL (grande, mas uma cópia normal) só ficavam LENTOS pra apagar (terminavam sozinhos
em segundo plano depois de alguns minutos, não é erro de verdade); a junction dá erro imediato e
consistente, não timeout.

**Solução:** antes do `git worktree remove`, desfazer a junction com `cmd /c rmdir
"<worktree>\web\node_modules"` — isso desfaz só o reparse point (unlink puro), **não** recursa pro
alvo (confirmado contando itens no `node_modules` do repo principal antes/depois: mesma contagem).
Só então `git worktree remove --force` funciona normal. Se `git worktree remove` falhar com
"Invalid argument" especificamente (não um timeout que se resolve esperando), suspeitar de
junction/symlink dentro do worktree antes de qualquer outra hipótese.
