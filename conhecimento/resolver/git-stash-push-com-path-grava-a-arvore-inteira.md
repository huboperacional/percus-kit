## `git stash push -- <path>` grava a árvore INTEIRA, e o pop corrompe o que você já commitou {#git-stash-push-com-path-grava-a-arvore-inteira}

`tags: git, stash, pathspec, conflito, UU, escopo de commit, review, arquivo corrompido, marcadores de conflito`

**Quando morde:** você quer rodar a review (ou o commit) **só sobre um subconjunto** dos arquivos
modificados, então guarda o resto com `git stash push -- <caminho>`, commita o escopo limpo, e
depois faz `git stash pop` pra recuperar.

**Sintoma:** o pop falha com

```
error: could not write index
HANDOFF.md: needs merge
The stash entry is kept in case you need it again.
```

e o arquivo — **que você acabou de commitar corretamente** — fica na árvore com marcadores de
conflito (`<<<<<<<`), maior do que era, e reprovando qualquer gate de tamanho.

**Causa raiz:** o `-- <pathspec>` controla **o que é REVERTIDO na árvore de trabalho**, não o que é
gravado. O commit de stash registra o estado de **todos** os arquivos modificados naquele instante.
Então, se entre o `push` e o `pop` você **commitou** algum desses outros arquivos, o pop tenta
aplicar por cima a versão **pré-commit** deles — e conflita com o que virou HEAD.

```
git stash push -- spec.md      # arvore: spec revertida. STASH: spec + HANDOFF + PLANO + PENDENCIAS
git commit  HANDOFF PLANO PENDENCIAS
git stash pop                  # tenta restaurar HANDOFF PRE-commit -> CONFLITO
git stash show --name-only stash@{0}   # <- confirma: 4 arquivos, nao 1
```

**Conserto (cirúrgico, sem perder nada):**

```bash
git checkout HEAD -- <arquivo-conflitado>          # volta a versao COMMITADA, correta
git checkout stash@{0} -- <o-caminho-que-voce-queria>   # recupera SO o que interessa
git stash drop stash@{0}
```

Depois confira que o conflito sumiu de verdade: `grep -c '^<<<<<<<' <arquivo>` tem que dar `0`, e o
contador de linhas tem que bater com o do commit.

**Como evitar:** para escopar uma review/commit, prefira **não mexer na árvore**:

- rode a review com `-Base <ref>` quando o wrapper aceitar, em vez de esconder arquivos;
- ou faça o `stash push -- <path>` **e o `pop` antes de qualquer commit** — nunca commite com stash
  pendente que contenha arquivos que você vai commitar;
- ou commite em ordem: primeiro o subconjunto grande, depois o pequeno, sem stash nenhum.

**Sinal de que já entrou nessa:** `git stash show --name-only stash@{0}` lista **mais arquivos do
que você passou no pathspec**. Confira isso ANTES do pop — é gratuito e evita o conflito.

**Ref:** [commit-com-review](../fazer/commit-com-review.md) (ordem de commit e escopo).
