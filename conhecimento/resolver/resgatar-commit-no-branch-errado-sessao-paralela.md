## Resgatar commit que caiu no branch errado por colisão de sessão paralela (sem perder o trabalho de nenhum dos dois lados) {#resgatar-commit-no-branch-errado-sessao-paralela}

`tags: git, branch errado, sessao paralela, working tree compartilhado, git branch, reset misto, nao-destrutivo, resgate de commit, colisao de sessoes`

**Sintoma:** um commit termina normalmente, mas o branch atual não era o esperado (outra sessão
tinha trocado de branch nesse working tree compartilhado, com mudanças já staged dela) — o commit
acabou de propósito em cima do trabalho alheio.

**Solução (não-destrutiva):** criar uma ref nova apontando pro commit certo
(`git branch <nome-novo> <sha>`), depois mover o branch errado de volta com reset MISTO — nunca
`--hard` — pro sha anterior ao commit que caiu no lugar errado. `git branch` só cria ref, não mexe
em nada. O reset misto move o ponteiro do branch e reseta o ÍNDICE pro estado anterior, mas NUNCA
toca o working tree — os arquivos que a outra sessão tinha modificado (agora "unstaged" em vez de
"staged") continuam com o conteúdo dela intacto, ela só precisa re-adicionar antes do próximo
commit dela. Confirme ANTES que o branch-alvo não está checked-out em nenhum worktree
(`git worktree list`) — se estiver, prefira `git fetch . origem:destino` em vez de mexer direto (
recusa com segurança se o destino estiver em uso).

**Lição maior:** isso só foi necessário porque a primeira task de uma execução subagent-driven
rodou no working tree COMPARTILHADO em vez de um worktree isolado — o próprio plano já mandava usar
worktree isolado desde o início. Criar o worktree ANTES da primeira task evita o problema inteiro.

**Ref:** Paid Media Automation, cont.157 (2026-08-07).
