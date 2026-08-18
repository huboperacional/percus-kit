## Duas sessões trabalham na mesma spec sem saber uma da outra — plano completo já existia, commitado num worktree isolado {#duas-sessoes-plano-duplicado-worktree}

`tags: git worktree, sessao paralela, subagent-driven-development, plano duplicado, checkpoint, HANDOFF desatualizado, council-pre-mortem, reconciliacao, ps aux`

**Contexto:** sessão Scraper-prospeccao 2026-08-03. Pedido: "escreva o plano técnico" pra uma spec
já aprovada. Comecei a escrever um plano do zero, achei uma cópia solta (não-commitada) do MESMO
plano no meio do caminho — assumi que era rascunho de sessão anterior interrompida, li e
reconciliei contra ela, rodei council-pre-mortem, atualizei HANDOFF/PLANO como se estivesse tudo
pronto pra execução a partir dali.

**Sintoma:** quando o operador perguntou "não sei mais o que estamos rodando aqui e na outra
sessão", `git worktree list` revelou um worktree isolado (`.worktrees/<nome>`, branch própria) com
**Task 1 e 2 de 12 já commitadas** e seu PRÓPRIO council-pre-mortem já rodado — 2 rounds, achando
problemas diferentes dos que eu tinha achado na cópia solta. `ps aux` confirmou um processo Python
rodando DENTRO do worktree no momento da checagem — execução real, não histórico. A cópia solta que
eu vinha editando desapareceu do disco no meio da investigação (causa não identificada, sem perda
real — o conteúdo autoritativo sempre esteve commitado no worktree).

**Causa raiz:** o protocolo de início de sessão (ler `HANDOFF.md` + `docs/PLANO.md`) não inclui
checar `git worktree list`. Um worktree isolado criado por uma sessão anterior (padrão
"subagent-driven plan execution", já documentado no próprio repo num commit
`chore: ignore .worktrees/`) é invisível pra quem só lê os arquivos de tracking da branch
principal — o worktree tem seu PRÓPRIO `HANDOFF.md`/`docs/PLANO.md`, nunca sincronizado de volta
pra branch principal até o merge final.

**Solução:** antes de escrever um plano técnico novo (ou qualquer trabalho de escopo grande),
rodar `git worktree list` — não só `git log`/`git status` da branch atual. Se existir um worktree
com branch relacionada ao tema, ler o `docs/PLANO.md`/`HANDOFF.md` DENTRO dele (arquivos
separados, não compartilhados) antes de qualquer coisa. `ps aux | grep <nome-do-worktree>`
confirma se há execução ativa AGORA (não só histórico de commits) — evita editar em cima de um
processo em andamento. Ao reconciliar achados de duas fontes paralelas, aplicar as correções
DENTRO do worktree real (ele é a fonte da verdade), nunca só documentar na branch principal como
se fosse lá que a execução acontece.

**Ref:** sessão Scraper-prospeccao 2026-08-03, frente "motor de coleta multi-provider" — commits
`77fc204` (correção aplicada no worktree real) e `b30a906` (correção do HANDOFF/PLANO da branch
principal, virando ponteiro em vez de descrever estado falso).
