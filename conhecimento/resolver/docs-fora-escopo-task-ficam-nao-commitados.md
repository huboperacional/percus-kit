## Subagent commita só os arquivos do PRÓPRIO task — docs/spec editados fora do escopo de nenhuma task ficam esquecidos no disco {#docs-fora-escopo-task-ficam-nao-commitados}

`tags: subagent-driven-development, git add seletivo, checkpoint, docs esquecidos, spec nao
commitado, orquestrador, branch compartilhada, git status`

**Contexto:** tiatendo, 2026-08-03/04. Numa frente conduzida via `subagent-driven-development`
(controller principal escreve spec/plano, dispara um subagent por task), cada subagent seguiu à
risca a instrução de "stage APENAS os arquivos desta task" (disciplina correta pra branch
compartilhada — evita puxar arquivo de outra sessão pro commit). Só que os arquivos de **spec e
plano** (`docs/superpowers/specs/*.md`, `docs/superpowers/plans/*.md`) e uma edição em
`docs/diferenciais.md` foram escritos pelo **controller**, não por nenhum subagent — e como
nenhuma task individual "possuía" esses arquivos no seu escopo declarado, ninguém os commitou.
Ficaram editados no disco por uma sessão inteira (4 tasks + revisões) até o checkpoint seguinte
rodar `git status` no repo inteiro e achar 5 arquivos com trabalho real, nunca versionados.

**Causa raiz:** a disciplina de "stage seletivo por task" (necessária e correta) tem um ponto
cego estrutural: ela protege contra commitar arquivo ALHEIO, mas não garante que TODO arquivo
PRÓPRIO seja commitado — se um arquivo não pertence ao escopo de nenhuma task individual (porque
foi escrito pelo orquestrador antes/entre as tasks), ele cai fora da rede de nenhum dos commits
parciais.

**Solução:** o orquestrador (quem escreve a spec/plano antes de disparar os subagents) é
responsável por commitar os PRÓPRIOS artefatos que ele mesmo criou — não delegar isso a nenhum
subagent, já que nenhum subagent tem esse arquivo no seu escopo. E antes de considerar uma frente
fechada (ou num checkpoint), rodar `git status --short` no repo INTEIRO (não só `git diff
--cached` de cada commit já feito) e perguntar explicitamente: "todo arquivo que EU editei nesta
sessão está commitado, ou só o que os subagents tocaram?"

**Relacionado:** [#duas-sessoes-plano-duplicado-worktree] — outra classe de problema de
coordenação entre múltiplos agentes/sessões escrevendo no mesmo repo, mesma lição de fundo:
verificar o estado real do git, não assumir que "rodou sem erro" implica "está tudo salvo".

**Ref:** tiatendo, sessão 2026-08-03/04, commit `2ba8f09` (5 arquivos: `docs/diferenciais.md` +
4 specs/planos de S5-cardápio-do-dia e roadmap-por-fases, commitados só no checkpoint seguinte).
