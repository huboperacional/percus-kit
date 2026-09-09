## `git commit --amend` sem pathspec leva o ÍNDICE INTEIRO — e pode emendar o commit errado se o HEAD andou {#amend-sem-pathspec-leva-o-indice-inteiro-e-pode-emendar-o-commit-errado}

`tags: git, commit, amend, pathspec, staged, index, HEAD, arvore compartilhada, multi-sessao, autoria, R23`

**Sintoma:** você commita seus arquivos com pathspec explícito (certo, per
`commit-com-pathspec-leva-o-disco-nao-o-staged`), percebe que a MENSAGEM saiu corrompida
(ex.: crase dentro de `-m "..."` virou substituição de comando no shell, ver
`aspas-no-commit-m-truncam-a-mensagem`), e roda `git commit --amend -F arquivo.txt` **sem
pathspec** só para trocar o texto. `git show --stat` do resultado mostra o DOBRO de arquivos
que você commitou, incluindo caminhos de outra sessão que nunca tocou.

**Causa raiz, dois mecanismos empilhados, numa árvore compartilhada por várias sessões:**

1. **`--amend` sem pathspec usa o ÍNDICE INTEIRO**, não o pathspec do commit original — ele
   não "reabre" o commit anterior e deixa você editar só a mensagem; ele constrói uma árvore
   nova a partir de **tudo que estiver staged agora**. Se outra sessão rodou `git add` dos
   arquivos dela (índice é global) entre o seu commit e o seu amend, os arquivos dela entram
   junto — mesmo que sua intenção fosse só o texto da mensagem.
2. **`--amend` opera no HEAD ATUAL, não no commit que você acabou de fazer.** Numa árvore com
   várias sessões commitando em sequência rápida, o HEAD pode ter avançado (outra sessão
   commitou por cima) no intervalo entre o seu `commit` e o seu `commit --amend`. Você não
   emenda o SEU commit — emenda o que estiver no topo agora, absorvendo o conteúdo dele
   também.

Os dois se combinam: `git commit --amend -F msg.txt` sem pathspec, rodado alguns minutos
depois do commit original (tempo suficiente para outra sessão commitar E stagear algo novo),
produz um commit com a SUA mensagem, um PAI que não é o commit que você fez, e um conteúdo
que inclui trabalho alheio não revisado por você.

**Solução, antes de qualquer `--amend` numa árvore compartilhada:**
1. **Confirme que HEAD ainda é o commit que você quer emendar** — `git log -1 --format=%H`
   tem que bater com o hash que o `git commit` anterior devolveu. Se mudou, não emende: o seu
   commit já é passado, e "consertar a mensagem" vira "reescrever a história de outra sessão".
2. **Confirme que o índice está limpo** — `git diff --cached` (vazio = índice bate com HEAD).
   Se não estiver vazio, alguém stageou algo depois do seu commit; NÃO amende nesse estado.
3. Se só a mensagem importa e o risco de rodar `--amend` é alto, **considere não corrigir** —
   uma crase faltando na mensagem é cosmético; reescrever histórico compartilhado por engano
   não é. Peso do conserto < peso do risco, na maioria dos casos.
4. **Se já aconteceu:** `git reset --soft <hash-do-seu-commit-original>` desfaz o amend sem
   perder NADA — tudo que o amend tinha a mais volta pro índice como staged, exatamente como
   estava antes, pronto para a outra sessão commitar o dela separadamente. Avise a outra
   sessão IMEDIATAMENTE (ela pode estar no meio de tentar commitar o que "sumiu" do
   `git status" dela).

**Medido:** Empresa Milionária, 2026-08-31. `git commit --amend -F msg.txt` (só pra trocar
mensagem corrompida por crase) emendou o commit de OUTRA sessão que tinha acabado de entrar
no meio, carregando junto 9 arquivos dela (staged, aguardando o `git add` dela terminar de
passar por um hook). `git reset --soft` recuperou os dois lados sem perda; a outra sessão
recommitou o dela em separado, mensagem própria, minutos depois.

**Relacionado:** `commit-com-pathspec-leva-o-disco-nao-o-staged` (mesmo gênero de armadilha,
mecanismo diferente — aquele é sobre COMMIT normal com pathspec lendo disco; este é sobre
AMEND sem pathspec lendo o índice inteiro e possivelmente o commit errado).
