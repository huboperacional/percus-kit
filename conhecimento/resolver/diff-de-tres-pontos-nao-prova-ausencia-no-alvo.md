## `git diff A...B` NÃO prova que o conteúdo falta em A {#diff-de-tres-pontos-nao-prova-ausencia-no-alvo}

`tags: git, diff, tres pontos, merge-base, worktree, branch stale, alarme falso, faxina, remocao, prova de ausencia, comm, ls-tree`

**Sintoma:** você compara uma branch antiga com o `main`, vê centenas de linhas de diff com arquivos
que parecem existir só nela, e conclui que há **trabalho não mergeado prestes a se perder**. Você
alarma o operador. Está errado.

**A forma abstrata:** `git diff A...B` (três pontos) mostra o que **B acrescentou desde a
divergência** — é `merge-base(A,B)..B`. Ele **não** compara as duas árvores. Se o mesmo conteúdo
entrou em A por outro caminho (squash, cherry-pick, reescrita), o diff de três pontos continua
grande, porque a base de comparação é o passado comum, não o presente de A.

**Caso medido (tiatendo, faxina de worktrees, 2026-08-30):** `git diff main...worktree-X` devolvia
14 arquivos e 1513 inserções, incluindo três arquivos de teste inteiros. Conclusão anunciada:
*"há trabalho fora do main, não é lixo"*. A comparação correta desfez o alarme:

```
git diff --stat main worktree-X        # DOIS pontos: arvores de verdade
 -> 107 arquivos, 233 insercoes, 21533 DELECOES
```

A branch estava **atrasada**, não adiantada. E o teste decisivo foi outro:

```
comm -13 <(git ls-tree -r --name-only main | sort) \
         <(git ls-tree -r --name-only worktree-X | sort)
 -> vazio: NENHUM arquivo existe so na branch
```

### O que fazer

- Para "o que a branch acrescentou desde que divergiu": `A...B` (três pontos). É o que a review de
  PR mostra, e é a pergunta certa **para revisar**, não para decidir remoção.
- Para "as duas árvores diferem?": `git diff A B` (dois pontos).
- Para "existe arquivo só em B?": `comm -13` sobre `git ls-tree -r --name-only` das duas. É a única
  das três que responde **prova de ausência**, que é o que uma remoção exige.
- Antes de remover worktree/branch: os três, nessa ordem. E preserve a branch — `git worktree
  remove` não a apaga, então a remoção fica reversível.

### Por que engana tanto

As duas sintaxes diferem por **um ponto**, produzem saída plausível nas duas, e a de três pontos é a
que aparece em toda documentação de PR — então é a que está na memória muscular. O erro não dá
mensagem: dá um número grande e convincente.

**Parente:** [ausencia-numa-tabela-so-e-prova-se-o-produtor-escreve-nela](ausencia-numa-tabela-so-e-prova-se-o-produtor-escreve-nela.md)
— mesma família: um comando devolveu resultado, o resultado não respondia a pergunta que eu fiz.
