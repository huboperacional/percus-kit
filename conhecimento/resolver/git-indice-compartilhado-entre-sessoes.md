## O ÍNDICE do git é compartilhado entre sessões — `git diff --cached` de antes do commit não prova o que entra {#git-indice-compartilhado-entre-sessoes}

`tags: git, index, staged, git add, git apply --cached, commit, multi-sessao, arvore compartilhada, race condition, R23`

**Contexto:** duas sessões no MESMO working tree, cada uma tentando isolar SÓ o próprio hunk num
arquivo que a outra também editou (ex.: `main.py` com um `include_router` de cada sessão). A
técnica correta para isso é `git apply --cached <patch-com-só-meu-hunk>` — ela toca só o ÍNDICE,
não a árvore de trabalho, então o arquivo em disco continua com os DOIS hunks intactos.

**O que ninguém nota:** `.git/index` é **um arquivo único no disco**, e as duas sessões escrevem
nele via processos `git` separados. Não há isolamento entre "eu confiro `git diff --cached` agora"
e "eu rodo `git commit` no próximo comando" — se a outra sessão rodar `git add`/`git reset`/
`git apply --cached`/`git commit` NO MEIO desse intervalo (mesmo que sejam só alguns segundos),
o índice que o seu `commit` de fato lê pode já não ser o que o seu `diff --cached` mostrou.

**Sintoma medido (Empresa Milionária, 2026-09-03):** sessão A isolou o próprio hunk em
`main.py`/`tenancy_rotas.py` via `git apply --cached`, conferiu `git diff --cached` (mostrou só o
hunk dela), e no passo seguinte `git diff --cached --stat` veio **vazio** — a sessão B tinha
rodado `git reset`/`git add` dela no meio. A sessão A refez a sequência inteira numa ÚNICA
chamada de shell encadeada (`reset && add && apply --cached && diff --stat`) pra reduzir a
janela, e MESMO ASSIM 4 arquivos dela (recém-`git add`ados, nunca commitados antes — por isso
sem conteúdo prévio no índice pra "proteger") foram varridos pro `git commit` **sem pathspec** da
sessão B, que captura literalmente "o que estiver no índice agora".

**Por que não foi um desastre:** nenhum conteúdo foi perdido nem misturado — os 4 arquivos
entraram no commit alheio **inteiros e corretos** (confirmado por `diff <(git show <hash>:<path>)
<arquivo-em-disco>`, saída vazia nas duas comparações). O problema é só de AUTORIA do commit
(mensagem/hash não mencionam o trabalho), não de integridade de dado.

**Mitigação:**
1. **Avisar a sessão concorrente por `SendMessage` ANTES** de qualquer sequência de
   `add`/`apply --cached`/`commit` num arquivo que ela também toca — pedir uma pausa de 1-2 min é
   mais barato que a corrida.
2. **A verificação que importa é DEPOIS do commit, não antes:** `git show <hash>:<arquivo> | diff -
   <(cat <seu-conteúdo-esperado>)` (ou simplesmente reler o `git show --stat` do hash que saiu) —
   nunca confie num `git diff --cached` de uma chamada anterior como prova do que o `commit`
   seguinte vai conter.
3. Se o conteúdo saiu correto mas no commit errado (como aconteceu aqui): **não desfaça** — mesma
   regra do [commit-com-pathspec-leva-o-disco-nao-o-staged](commit-com-pathspec-leva-o-disco-nao-o-staged.md).
   Avise a outra sessão com o hash, e se faltar algo seu (ex.: uma linha de registro que não coube
   no isolamento cirúrgico), complete com um commit pequeno separado.

**Relacionado:** [commit-com-pathspec-leva-o-disco-nao-o-staged.md](commit-com-pathspec-leva-o-disco-nao-o-staged.md)
(esse é sobre pathspec ignorar o índice; este é sobre o índice em si ser instável entre sessões) ·
[stash-scoped-por-pathspec-colapsa-staging-parcial.md](stash-scoped-por-pathspec-colapsa-staging-parcial.md)
(mesma classe de colisão de índice compartilhado, mecanismo de `stash` em vez de `apply --cached`).
