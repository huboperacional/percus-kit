## `git add` por caminho NÃO basta: o wrapper da review stageia depois de você {#add-por-caminho-nao-basta-o-wrapper-stageia-depois}

`tags: index compartilhado, git add seletivo, percus-review-auto, R11, sessoes concorrentes, staging, commit engoliu arquivo alheio, reset --soft, commit -C, N files changed`

**Sintoma:** você stageia por caminho (`git add a b c`), roda a review R11, commita — e o output diz **`6 files changed`** quando você stageou **3**. Os extras são docs vivos de outra sessão (`HANDOFF.md`, `docs/PLANO.md`, `docs/PENDENCIAS.md`), ou um `.md`/script untracked que não é seu. Nada avisa: o commit "passa", os hooks aprovam, e o único sintoma é aquele número.

**Causa raiz — e é a correção de uma receita que já está nesta base.** O verbete [mesclar-so-imediatamente-antes-do-commit](mesclar-so-imediatamente-antes-do-commit.md) prescreve *"`git add` por caminho, nunca `-A`, em repo com sessões concorrentes"*. **Isso não é suficiente**, e o caso de 2026-08-16 provou: eu usei add por caminho e ainda assim engoli trabalho alheio.

O motivo é que **`percus-review-auto.ps1` stageia por conta própria** — ele precisa que docs e arquivos novos estejam no índice para conseguir revisá-los. Então a sequência real é:

```
git add <meus 3>      →  índice = 3
pwsh percus-review…   →  índice = 3 + o que o wrapper achou   ← aqui
git commit            →  commita 6
```

`git add` seletivo protege contra o que **eu** escolho stagear. Não protege contra o que uma **ferramenta** stageia depois de mim. E como o índice é único por checkout, num repo com duas sessões o que a outra estiver escrevendo naquele instante entra junto.

**Solução:**
1. **Confira o índice DEPOIS da review, não antes:** `git diff --cached --name-only`. É uma linha e pega o caso inteiro. Aconteceu 3× no mesmo dia e a checagem pegou as 3 (`docs/PENDENCIAS.md`, um `scripts/measure*.py` e uma spec de outra frente).
2. **Trate o `N files changed` do output do commit como asserção.** Divergiu do que você stageou, é isto — investigue antes de seguir.
3. **Conserto, e é barato e seguro:** `git reset --soft HEAD~1` (não toca na árvore de trabalho, então o trabalho alheio volta a ser modificação não-commitada, intacta) + `git restore --staged <alheios>` + `git commit -C <sha-antigo>` para reaproveitar a mensagem. Faça **numa chamada só**, para encurtar a janela de corrida com a outra sessão.

⚠️ **Não use `git checkout`/`restore` no arquivo alheio para "limpar".** `--soft` e `--staged` mexem só no índice; qualquer coisa que escreva na árvore apaga o trabalho vivo da outra sessão em silêncio.

⚠️ **O mesmo vale para `Write` de arquivo inteiro num arquivo que a outra sessão está editando** — `Edit` cirúrgico, sempre. Um `Write` a partir de buffer velho é a versão do mesmo estrago fora do git.
