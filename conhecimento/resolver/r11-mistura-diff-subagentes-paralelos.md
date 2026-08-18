## Review R11 escopada ao WORKING TREE INTEIRO mistura o diff de 2 subagentes rodando em paralelo no mesmo worktree {#r11-mistura-diff-subagentes-paralelos}

`tags: subagent-driven-development, dispatching-parallel-agents, git worktree, git stash, git add especifico, deepseek-review, review-router, R11, diff cached working tree, contaminacao de diff, paralelizar implementacao serializar commit`

**Contexto:** operador pediu explicitamente pra "adiantar" 3 tasks independentes de uma feature em
paralelo (Família Milionária, feature Dívidas: Task 7 = texto de bot em Python, Tasks 8-9 = tela
frontend em TypeScript — frentes genuinamente disjuntas, zero overlap de arquivo). Dois subagentes
implementadores dispachados via `Agent` (mesma sessão, mesmo worktree, sem `isolation: "worktree"` —
avaliado e descartado porque worktrees aninhados nascem de `origin/main`, não do HEAD local com todo
o trabalho já commitado nesta sessão, ver gotcha irmã sobre `EnterWorktree`).

**Sintoma:** cada subagente foi instruído a implementar+testar mas NÃO commitar (deixando pro
controller). Quando o controller tentou revisar/commitar o primeiro subagente a terminar (Task 7,
3 arquivos Python), `review-router.ps1` reportou **4 arquivos**, não 3 — contando também
`AppSidebar.tsx`, que era o OUTRO subagente (Task 8-9, ainda rodando) mexendo num arquivo TypeScript
completamente não-relacionado. Rodar `deepseek-review.ps1` nesse estado teria mandado pro LLM um diff
misturando os dois trabalhos, ainda que só os 3 arquivos de Task 7 fossem staged — a review R11
ficaria endereçando um diff que não corresponde ao que de fato seria commitado.

**Causa raiz:** `review-router.ps1`/`deepseek-review.ps1` calculam o diff como `git diff --name-only
--cached` **+** `git diff --name-only` (sem `--cached`) — ou seja, staged **E** working-tree não
staged, do repositório INTEIRO. Não há conceito de "diff só do que EU pretendo commitar agora" — o
gate é cego a qual processo/agente tocou cada arquivo. Um `git add <arquivos específicos>` (em vez de
`-A`/`.`) protege o CONTEÚDO do commit (só o que foi staged entra), mas não protege o que a REVIEW
lê — o script de review lê o working tree inteiro independente do que está staged.

**Solução:** com os dois subagentes tendo terminado de escrever (nenhuma escrita concorrente rolando
mais — stash é perigoso enquanto um processo ainda pode gravar no mesmo arquivo), **primeiro confira
que nada do outro lote está staged** (`git diff --cached --name-only -- <paths do outro agente>` tem
que voltar vazio — `--keep-index` só preserva o que já está no índice, então se o outro lote foi
staged por engano, ex. um `git add .` acidental, ele continua visível pro `deepseek-review` via `git
diff --cached` mesmo depois do stash). Confirmado isso, isolar cada review/commit com `git stash push
--include-untracked --keep-index -m "<label>" -- <paths do OUTRO agente>` antes de rodar
`deepseek-review.ps1`, revisar/commitar o primeiro lote limpo, depois `git stash pop` pra trazer o
segundo lote de volta e repetir. **Cuidado 1**: se algo for staged/editado DEPOIS do primeiro `stash
push` (ex.: um fix aplicado num arquivo do lote 1 após um achado de R11), o `stash pop` do lote 2 pode
gerar um conflito de merge contra a versão mais nova já commitada do arquivo do lote 1 — resolver com
`git checkout --ours -- <arquivo>` (mantém a versão já commitada, correta) + `git add`, NUNCA aceitar
cegamente a versão do stash sem comparar primeiro (`git log -1 --stat` no arquivo pra confirmar que a
versão commitada já tem o conteúdo esperado antes de descartar o lado do stash). **Cuidado 2**: um
`stash pop` que termina em conflito NÃO remove a entrada da stash list automaticamente (diferente de
um pop sem conflito) — depois de resolver e `git add`, rode `git stash drop stash@{N}` explícito
(confira o índice certo com `git stash list` antes), senão a stash antiga fica pra trás e pode ser
reaplicada por engano numa sessão futura.

**Regra prática pra paralelizar com subagentes no mesmo worktree:** implementação PODE rodar em
paralelo quando os arquivos são genuinamente disjuntos (zero overlap). Commit/review NÃO pode — a
sequência segura é **implementar em paralelo, revisar/commitar em série**, com cada subagente
instruído a escrever+testar mas nunca `git add`/`git commit` (isso fica com o controller, que
sequencia manualmente via stash quando precisa isolar). Isolamento via `isolation: "worktree"` do
Agent tool resolveria isto de raiz, mas só quando o worktree filho nasce do HEAD local (não de
`origin/main`) — confirme isso antes de escolher essa rota em vez do stash manual.

**Ref:** Família Milionária, worktree `dividas-metas-desejos`, sessão 2026-08-05/06 — Tasks 7 (commit
`91e1966`) e 8-9 (commit `190638f`) da feature Dívidas, dispachadas em paralelo a pedido do operador.
