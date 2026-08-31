## `git checkout <branch> -- .` sobrescreve a árvore INTEIRA em silêncio, revertendo trabalho não relacionado {#git-checkout-branch-dashdash-dot-sobrescreve-arvore-inteira}

tags: git, checkout, merge, worktree, recuperação, working tree, index, stash, reset --hard, comando destrutivo, silencioso

**Sintoma:** no meio de um `git merge --no-commit` (staged mas não commitado) de um branch de feature
não relacionado, rodei `git checkout <branch> -- .` querendo inspecionar algo do branch — e todos os
arquivos do working tree e do index foram substituídos pelo conteúdo desse branch, **inclusive
arquivos que o branch nunca tocou**: um arquivo tracked no HEAD atual mas ausente do branch alvo
volta para a versão que existia no **merge-base** (o ancestral comum), não para a versão do HEAD
atual — silenciosamente revertendo dezenas de commits de trabalho de sessão que não tinham NADA a
ver com o branch sendo inspecionado. Nenhum aviso, nenhum erro — o comando "funcionou".

**Causa raiz:** `git checkout <ref> -- <pathspec>` faz exatamente o que o nome diz — "traga o
conteúdo desses paths de `<ref>` pro working tree + index" — e `.` como pathspec significa "TODOS os
paths rastreados dentro do diretório atual", não "os paths que `<ref>` modifica". Um arquivo que
`<ref>` nunca tocou ainda EXISTE nele (herdado do ancestral comum), então `checkout -- .` traz essa
versão antiga de volta, mascarando qualquer trabalho feito nesse arquivo depois da divergência dos
dois branches. O erro mental é tratar `checkout <branch> -- .` como "aplicar o DIFF do branch" —
na verdade é "substituir a árvore inteira pela SNAPSHOT do branch".

**Solução:** nunca use `checkout <branch> -- .` (ou `--all`/`-- <dir>` amplo) pra "dar uma olhada"
num branch — use `git show <branch>:<path>` (um arquivo só, read-only, não toca o working tree) ou
`git diff HEAD..<branch>` pra comparar sem mutar nada. Se precisar mesmo trazer arquivos específicos
de outro branch, liste os paths exatos (`checkout <branch> -- path/a path/b`), nunca `.`/glob amplo.
**Recuperação, se já aconteceu:** `git checkout HEAD -- .` restaura tracked paths pro estado do
commit atual, mas pode deixar "adições" órfãs (paths que existiam no branch alvo mas não em HEAD)
staged como `A` — segue com `git reset --hard HEAD` pra garantir working tree + index 100%
idênticos ao HEAD antes de continuar qualquer operação. Se havia um merge em andamento (`--no-commit`)
que você precisa preservar, `git stash` ANTES do reset e `git stash pop` depois — mas note que
`git reset --hard` limpa o estado `MERGE_HEAD`, então o commit subsequente sai como commit normal
(1 pai), não como merge commit de verdade (2 pais); o conteúdo fica correto, só o histórico perde a
marca formal de "isto foi um merge" — aceitável se você documentar isso na mensagem do commit.

**Ref:** tiatendo, sessão 2026-08-28 — merge de `worktree-vertical-router-pricing-negociacao`
(branch de feature, `execution/dashboard/*`) enquanto uma sessão de P0 de restaurante tinha commits
recentes em `execution/engine/restaurantCartDiff.py`, `HANDOFF.md`, `tests/restaurant/*`. Rodei
`git stash && git checkout <branch> -- .` — o stash preservou o merge staged, mas o checkout
reverteu TODOS os arquivos P0 (não tocados pelo branch de feature) pra sua versão no merge-base,
~15 commits atrás. Detectado pelo próprio harness (nota automática "arquivo mudou desde a última
leitura"), recuperado com `git checkout HEAD -- .` + `git reset --hard HEAD` + `git stash pop`,
verificado byte a byte (`git diff HEAD -- <arquivos P0>` vazio) antes de prosseguir. Nenhum commit
chegou a ser feito com o estado corrompido.
