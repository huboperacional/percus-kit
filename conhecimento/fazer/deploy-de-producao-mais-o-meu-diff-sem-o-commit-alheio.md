## Subir só o seu lote quando o commit de outra sessão ficou embaixo do seu: árvore = produção + o seu diff {#deploy-de-producao-mais-o-meu-diff-sem-o-commit-alheio}

`tags: deploy, git archive, tree-ish, write-tree, git apply --cached, GIT_INDEX_FILE, multi-sessao, commit alheio, R24, producao, rastreabilidade`

**Quando:** você tem autorização para subir **o seu** lote, e na hora de empacotar o
`git log <commit-em-producao>..HEAD -- <pastas do deploy>` mostra também um commit de outra sessão
**debaixo** do seu. `git archive HEAD` — ou do seu próprio hash — leva o trabalho dela para produção,
sem autorização e talvez enquanto ela prepara o deploy dela
([deploy-paralelo-sobrescreve-sem-aviso](../resolver/deploy-paralelo-sobrescreve-sem-aviso.md)).

**Passos:**

```bash
IDX=/tmp/indice-deploy; rm -f "$IDX"
GIT_INDEX_FILE="$IDX" git read-tree <commit-em-producao>
git diff --binary <pai-do-seu-commit> <seu-commit> | GIT_INDEX_FILE="$IDX" git apply --cached
TREE=$(GIT_INDEX_FILE="$IDX" git write-tree)
git diff --stat <commit-em-producao> "$TREE" -- app infra   # só os seus arquivos
git diff --stat "$TREE" <seu-commit> -- app infra           # só os do commit alheio
git -c core.autocrlf=false archive --format=tar.gz -o pacote.tgz "$TREE" app infra
```

`git archive` aceita árvore, não só commit. As duas conferências de `--stat` são a prova: a primeira
tem de listar só o que é seu; a segunda, só o que é da outra sessão. No script de build, ponha uma
trava que **aborta** se o pacote tiver um marcador do commit alheio (`grep -q <função nova dele>`).

**Armadilhas:**
- **Produção passa a rodar uma árvore que não é nenhum commit do master.** Registre no HANDOFF o
  hash da árvore, o commit do lote e o commit alheio que ficou de fora. O próximo deploy de master
  leva os dois.
- Se o `git apply --cached` falhar, o seu lote depende do commit alheio: pare e combine com a outra
  sessão em vez de forçar.
- Lote de vários commits: o diff vai do commit anterior ao seu primeiro até o seu último, e só serve
  se nenhum commit alheio estiver **no meio** dos seus.
- A árvore sintética não passou pela suíte como tal. Se o seu lote e o alheio não tocam os mesmos
  módulos, o build da imagem (typecheck) basta como gate; se tocam, rode a suíte num checkout da
  árvore antes.

**Ref:** LiliCalc, 2026-09-14. O lote `96c98eb` (seed e custo por 100 g) foi commitado em cima do
`3aaafa7`, de outra sessão, que mexe no webhook do Asaas e tinha sido commitado segundos antes. A
árvore `a634d24` = `89f4c71` (produção) + o lote; difere do master só nos dois arquivos do webhook, e
o pacote saiu sem o marcador do `3aaafa7`.
Relacionado: [commitar-por-indice-temporario-quando-outra-sessao-tem-staged](commitar-por-indice-temporario-quando-outra-sessao-tem-staged.md).
