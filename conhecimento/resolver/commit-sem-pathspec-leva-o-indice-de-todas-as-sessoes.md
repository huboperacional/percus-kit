## `git add X && git commit -m` não é atômico: o commit leva o ÍNDICE inteiro, e em árvore compartilhada o índice é de todos {#commit-sem-pathspec-leva-o-indice-de-todas-as-sessoes}

`tags: git, commit, index, staged, arvore compartilhada, multi-sessao, autoria, corrida, reset --soft, R23`

**Sintoma:** você estagia **um** arquivo (`git add HANDOFF.md`), roda `git commit -m "..."` sem
pathspec, e o commit sai com **7 arquivos e 885 inserções** — o seu doc mais o backend inteiro de
outra sessão. Nenhum erro, nenhum conflito, exit 0. O `git status` da outra sessão fica limpo e o
trabalho dela aparece dentro de um commit de documentação que não o menciona.

**Causa raiz:** `git commit` sem caminho commita **o índice**, não "o que você acabou de estagiar".
Entre o seu `add` e o seu `commit` existe uma janela, e numa árvore compartilhada por duas sessões
**o índice é um só**. Quem estagia e demora (para rodar um review, por exemplo) paga o preço de
quem commita primeiro. Medido em 2026-09-10: a outra sessão estagiou seis arquivos às 23:11 para
que o revisor pudesse ler arquivo novo, foi rodar o review, e o commit alheio saiu às 23:12:22.

**O dano não é só de autoria.** Do lado de quem foi varrido, `git diff HEAD` e `git diff --cached`
ficam os **dois vazios**, e o review seguinte devolve `0 arquivo(s) / total=0` — que parece limpeza
e é ausência de medição. O código entrou na árvore **sem review**.

**A checagem que NÃO discrimina:** `git diff HEAD -- <meu-arquivo>` mostra o seu arquivo, certinho,
e é cego ao resto do índice. Quem discrimina é `git diff --cached --name-only` (o índice inteiro),
imediatamente antes de commitar.

**Correção:** enquanto houver outra sessão viva na mesma árvore, **sempre** `git commit -m '...' --
<pathspec>` — atenção à ordem: `-m` **antes** do `--`, senão a mensagem vira pathspec e o commit
falha com *"did not match any file(s) known to git"*. E não deixe arquivo estagiado parado
esperando processo demorado.

> ⚠️ **O pathspec resolve o ÍNDICE compartilhado, não o ARQUIVO compartilhado.** Se as duas sessões
> têm hunk no MESMO arquivo (`PLANO.md`, `HANDOFF.md`), o commit por caminho leva o disco daquele
> caminho e junta os dois hunks num commit só — ver
> [[commit-com-pathspec-leva-o-disco-nao-o-staged]]. Para arquivo compartilhado a saída é combinar
> a ordem por mensagem e editar depois que a outra commitar, ou aplicar só o próprio hunk por
> `git apply --cached`.

**Se já aconteceu:** `git reset --soft HEAD~1` devolve tudo ao índice sem perder nada, e aí o
commit por pathspec separa. ⚠️ **Só faça se o HEAD ainda for o SEU commit** — confira por
`git log --oneline -2` ANTES de tocar em qualquer coisa; se a outra sessão já commitou por cima,
resetar derruba o commit dela. E reescrever history debaixo de sessão viva é decisão dela também:
avise **antes**, não depois. No caso medido eu avisei depois, e a outra sessão tinha acabado de
escrever que não faria reset justamente por esse motivo — ela concordou com o desfecho, mas a
ordem certa era perguntar.
