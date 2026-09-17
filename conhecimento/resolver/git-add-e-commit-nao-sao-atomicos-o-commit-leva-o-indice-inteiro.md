## `git add` e `git commit` não são atômicos: o commit leva o ÍNDICE inteiro, inclusive o que outra sessão estagiou {#git-add-e-commit-nao-sao-atomicos-o-commit-leva-o-indice-inteiro}

`tags: git, indice, staging, commit, pathspec, duas sessoes, arvore compartilhada, add -N, write-tree, R11`

**Sintoma:** você estagia a sua lista, roda o review, commita — e o commit leva arquivos que não são seus. Ninguém
errou o `git add`: entre o seu `add` e o seu `commit` passou tempo, e nesse intervalo **outra sessão na mesma árvore**
estagiou os arquivos dela. `git commit` sem pathspec grava o índice **como ele está no momento do commit**, não o que
você estagiou.

**Causa raiz:** o índice é um só por árvore de trabalho e não pertence a ninguém. O `add` escreve nele; o `commit` lê o
que estiver lá. As duas operações são separadas no tempo, e o R11 (ou qualquer revisão) mora **no meio** — em geral um
a cinco minutos, que é exatamente a janela de exposição.

**Reprodução real:** Empresa Milionária, agosto de 2026 — uma sessão deixou arquivos estagiados durante um review
inteiro e outra os levou no commit seguinte, que passou a conter trabalho alheio não revisado. Em 15/09/2026, duas
sessões voltaram a dividir a árvore e o problema reapareceu como pergunta de protocolo, não como acidente.

**Fix, na ordem de preferência:**
1. **`git commit -- <pathspec>`** ou `git add -- <lista>` **colado** ao commit, sem nada entre eles. Pathspec no commit
   ignora o resto do índice: é a única forma que não depende de tempo.
2. **Arquivo NOVO entra com `git add -N` durante a revisão** e só recebe `add` cheio nos segundos finais. Medido: com
   `-N` o índice guarda o caminho apontando para o **blob vazio** (`e69de29b…`), o `git diff` mostra o arquivo inteiro
   como adição — então o revisor LÊ o conteúdo — e `git write-tree`, que é o que um commit sem pathspec faz por dentro,
   **não leva o caminho**. Ou seja: visível para quem revisa, invisível para o commit da outra sessão.
3. **Conferir a lista nos DOIS sentidos antes do commit**: `diff <(printf '%s\n' $LISTA | sort) <(git diff --cached
   --name-only | sort)`. Ausência do alheio não basta; o que pega erro é a igualdade.

**Protocolo entre duas sessões na mesma árvore** (o que funcionou): quem vai commitar pede uma **janela**; a outra
confirma que está sem rastreado modificado e não toca no índice até receber o hash. Fora da janela, ninguém estagia.

**Ref:** Empresa Milionária (2026-08 e 2026-09-15). Irmãos:
[commit-sem-pathspec-leva-o-indice-de-todas-as-sessoes](commit-sem-pathspec-leva-o-indice-de-todas-as-sessoes.md) e
[infundado-por-arquivo-ausente-e-falha-de-medicao-nao-veredito](infundado-por-arquivo-ausente-e-falha-de-medicao-nao-veredito.md).
