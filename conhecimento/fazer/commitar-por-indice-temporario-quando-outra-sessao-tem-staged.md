## Commitar só os seus caminhos com o índice de outra sessão cheio: índice temporário a partir do HEAD {#commitar-por-indice-temporario-quando-outra-sessao-tem-staged}

`tags: git, commit, GIT_INDEX_FILE, indice temporario, read-tree, index, staged, arvore compartilhada, multi-sessao, git rm --cached, pathspec, corrida, R11`

**Quando:** outra sessão deixou arquivo staged no índice compartilhado e você precisa commitar agora
— principalmente se o seu commit inclui **tirar do índice** arquivo que continua no disco
(`git rm --cached`), coisa que o commit por caminho não expressa, porque o pathspec lê o disco (ver
[commit-com-pathspec-leva-o-disco-nao-o-staged](../resolver/commit-com-pathspec-leva-o-disco-nao-o-staged.md)).

**Passos:**

```bash
IDX=/tmp/indice-meu; H=$(git rev-parse HEAD)
rm -f "$IDX"
GIT_INDEX_FILE="$IDX" git read-tree HEAD                  # índice novo = HEAD, nada da outra sessão
GIT_INDEX_FILE="$IDX" git add -- ':(literal)<caminho meu>' ...
GIT_INDEX_FILE="$IDX" git rm -r -q --cached -- <o que sai do índice>
GIT_INDEX_FILE="$IDX" git diff --cached --name-only       # tem de ser exatamente a sua lista
[ "$(git rev-parse HEAD)" = "$H" ] || exit 1              # HEAD andou: remonte do zero
GIT_INDEX_FILE="$IDX" git commit -F mensagem.txt
git reset -q -- ':(literal)<caminho meu>' ... <o que saiu> # realinha o índice REAL
git show --stat HEAD                                      # a prova do que entrou
```

**O último `git reset` não é opcional.** O índice real ainda tem os seus caminhos na versão de antes
do commit. Sem realinhar, o próximo `git commit` sem pathspec da outra sessão commita essa versão
velha e **reverte o seu commit** sem ninguém ver. O `reset -- <caminhos>` só toca as suas entradas;
o que a outra sessão estagiou fica onde está.

**Armadilhas:**
- `:(literal)` em caminho com `[id]` ou `(app)`: sem ele o colchete vira glob e o caminho não casa.
- O `git diff --cached` antes do commit não prova nada sobre o índice compartilhado
  ([git-indice-compartilhado-entre-sessoes](../resolver/git-indice-compartilhado-entre-sessoes.md)),
  mas sobre o temporário prova: ninguém mais escreve nele.
- O hook R11 continua valendo — o comando ainda é `git commit` — e o HEAD re-conferido fecha a
  corrida de [blob-seletivo-de-index-congela-um-head-que-ja-mudou](../resolver/blob-seletivo-de-index-congela-um-head-que-ja-mudou.md).

**Ref:** LiliCalc, 2026-09-14. A primeira tentativa, pelo índice compartilhado, abortou na trava:
`webhook.ts` e `webhook.test.ts` estavam staged por outra sessão. Na segunda, pelo índice
temporário, entraram exatamente os 18 caminhos do lote (8 arquivos e 10 fotos tiradas do índice); a
outra sessão tinha commitado segundos antes, e o `reset` final deixou o índice real limpo.
Relacionado: [commit-sem-pathspec-leva-o-indice-de-todas-as-sessoes](../resolver/commit-sem-pathspec-leva-o-indice-de-todas-as-sessoes.md).
