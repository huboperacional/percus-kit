## Diff só da rodada de fix quando o implementador não commita: tree temporária com `write-tree` {#diff-so-da-rodada-de-fix-quando-o-implementador-nao-commita}

`tags: git, write-tree, read-tree, GIT_INDEX_FILE, subagente, review, rodada de fix, re-review, working tree, sem commit, hooks, R11, R23`

**Quando:** num fluxo subagent-driven em que o implementador **não pode commitar** (hooks de
pre-commit bypassados por subagente; o controlador roda review, suíte e commita), a re-revisão
escopada precisa do diff **só da rodada de fix** — e não existe "HEAD que o revisor viu", porque o
estado revisado nunca virou commit.

**O que NÃO fazer:** `git stash create` snapshota o estado **atual** (se o implementador já começou
a editar, vem contaminado); commit descartável em worktree dispara os hooks (mock-scan, types-check,
`pre-commit-check` exigindo review nos últimos 5 min) e `--no-verify` é proibido; `git checkout --`
destrói trabalho não commitado.

**Receita (Plexco Tasks, 2026-09-05, usada em 5 fatias):**

```bash
# 1. ANTES de despachar a rodada de fix: o pacote de review ja contem `git diff -U10 HEAD`
#    do estado revisado. Extraia so o patch:
sed -n '/^diff --git/,$p' review-BASE..worktree.diff > reviewed.patch
# 2. Reconstrua o estado revisado como TREE num indice temporario (working tree intocada):
export GIT_INDEX_FILE=/tmp/reviewed.idx
git read-tree BASE_COMMIT && git apply --cached reviewed.patch && TREE=$(git write-tree)
unset GIT_INDEX_FILE
echo "$TREE" > task-N-reviewed-tree.sha
# 3. DEPOIS da rodada de fix, o diff so da rodada (tree-ish vs working tree):
git diff --stat "$TREE"; git diff -U10 "$TREE"
```

Zero commit, zero hook, zero mutação. A tree fica no object store até o próximo `gc` (semanas);
guarde o SHA no ledger. Sanidade: `git diff --stat "$TREE"` logo após criar tem que sair **vazio**
(a tree bate com a working tree revisada).

**Por que importa:** sem isso o re-revisor recebe o diff inteiro de novo e "re-revisa" o que já
passou, ou o controlador aceita a rodada de fix sem prova de que só o pedido mudou.
