## `git reset --soft` numa árvore compartilhada abre uma janela pra outro commit aterrissar no pai errado {#reset-soft-abre-janela-pra-commit-alheio-em-arvore-compartilhada}

`tags: git, arvore compartilhada, multiplas sessoes, reset --soft, race condition, autoria de commit, acusacao sem medir, shared working tree, multi-agent`

**Contexto:** múltiplas sessões de agente trabalham na MESMA árvore de trabalho (mesmo
`.git`, mesmo diretório) — cada uma faz seus próprios commits com pathspec explícito pra não
misturar arquivos de outra sessão. Uma sessão (A) tinha commitado por engano um arquivo que já
estava `staged`/deletado por outra sessão (B) — resultado de outra corrida do índice
compartilhado. Pra desfazer, A rodou `git reset --soft HEAD~1`. Segundos depois, A viu um commit
novo no topo do histórico e concluiu, **sem medir**, que um subagente seu tinha escrito aquele
commit por engano — e quase pediu pra desfazer um commit legítimo de B.

**Causa raiz:** `git reset --soft HEAD~1` move o `HEAD` (e o ref do branch) de volta pro
commit-pai **por um instante mensurável** — o tempo entre o `reset` e o próximo `commit` da
mesma sessão A. Se a sessão B já tinha um `git commit` em andamento (mensagem escrita, arquivos
staged) mirando naquele mesmo branch, e ele executa DENTRO dessa janela, o commit de B aterrissa
limpo em cima do commit-pai comum — produzindo um hash novo que, visto de fora, "apareceu logo
depois do meu reset". A ordem temporal (reset → aparece commit novo) sugere causalidade que não
existe: o commit de B já estava em andamento antes do reset, só concluiu durante a janela aberta
por ele.

**Por que ninguém viu antes:** git não registra "quem" (qual sessão/processo) fez um commit —
só o autor da config, que é o mesmo em toda sessão da mesma máquina. Sem essa distinção, a única
pista disponível é o timing relativo, que é exatamente o que engana aqui. A sessão A tinha
motivo real pra suspeitar (ela sabia que tinha acabado de mexer no histórico), mas não tinha
prova.

**Diagnóstico antes de acusar autoria de commit alheio numa árvore compartilhada:**
1. `git show -s --format="%B" <hash>` — comparar a mensagem **byte a byte** com o que a outra
   sessão diz ter escrito. Mensagem gerada por outra fonte quase nunca bate palavra por palavra.
2. `git show -s --format="%ad"` — o timestamp do commit é o instante em que o `git commit`
   rodou. Casa com o log da sessão que alega autoria (ela tem o tool-call e o output real na
   própria transcrição)?
3. `git show --stat <hash>` — o conjunto de arquivos bate com o que a sessão que alega autoria
   pretendia commitar (mesmo pathspec)?

Bateram os três → o commit é legítimo, não precisa de `amend` nem de reversão. **Não confie só
em "apareceu na hora errada".**

**Fix / prevenção:** evitar `git reset --soft`/`--mixed`/`--hard` numa árvore compartilhada
sempre que possível — preferir um novo commit corretivo (`git revert` ou um commit que remove o
arquivo indevido) em vez de mover o `HEAD` pra trás, porque mover o `HEAD` cria a janela de
corrida descrita acima mesmo quando a intenção é só "desfazer meu próprio erro local".

**Ref:** Empresa Milionária, 2026-08-26 — sessão RLS reverteu a acusação depois do fact-check
acima; nenhum commit foi desfeito.
