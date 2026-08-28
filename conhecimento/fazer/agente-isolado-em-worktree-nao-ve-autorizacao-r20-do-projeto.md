## Agente dispatchado com `isolation:"worktree"` não vê a autorização R20 do projeto {#agente-isolado-em-worktree-nao-ve-autorizacao-r20-do-projeto}

`tags: R20, external-action-guard, isolation worktree, Agent tool, .percus, acao-externa-autorizada.json, subagent`

**Sintoma:** o controller autoriza uma ação externa (`autorizar-acao-externa.ps1`) e despacha um
subagente pra executá-la via `python scripts/vps_exec.py`. O subagente bate no guard bloqueado, e o
arquivo de autorização que ele lê **não é o que o controller acabou de criar** — é um arquivo de
outra tarefa, de dias atrás, num caminho diferente (ex.: `percus-kit\scripts\.percus\...` em vez de
`<raiz-do-projeto>\.percus\...`).

**Causa:** o subagente foi dispatchado com `isolation: "worktree"` (parâmetro do Agent tool). Isso
dá a ele uma cópia isolada da árvore git — mas o guard lê `.percus/acao-externa-autorizada.json`
relativo ao **working directory do processo**, não ao repo lógico. Num worktree isolado, esse
caminho relativo resolve pra outro lugar (ou pra uma cópia stale, se `.percus/` estiver no
`.gitignore` e não tiver sido recriado no worktree novo) — o subagente literalmente não enxerga a
autorização que o controller acabou de gravar na árvore principal.

**Como resolver:** não use `isolation: "worktree"` pra tarefas que só LEEM produção (investigação,
diagnóstico, puxar métrica) — isso nunca precisou de isolamento de working tree pra começo de
conversa (isolamento existe pra mutação concorrente de arquivos, não pra leitura). Dispatch o
subagente **sem** `isolation`, trabalhando direto no diretório real do projeto
(`d:\Caminho\Real\Do\Projeto`), na mesma árvore onde o controller rodou
`autorizar-acao-externa.ps1`.

**Como confirmar que é isso antes de re-autorizar à toa:** o erro do subagente vai citar um
`motivo` e `autorizado_em` que **não batem** com o que o controller acabou de criar (motivo de
outra tarefa, ou uma data/hora muito mais antiga que os últimos 60 min). Se o motivo/timestamp
batem mas ainda assim bloqueia, aí sim é o caso normal (`autorizar-acao-externa-bloqueada-no-meio-
da-sessao`) — expirou ou o guard tem estado próprio.

**Não faça:** o subagente rodar `autorizar-acao-externa.ps1` sozinho pra "resolver" — o script é
explícito que só o agente chama isso depois de confirmação do operador NA CONVERSA, e um subagente
sem esse contexto direto não deveria decidir isso por conta própria; ele deve reportar BLOCKED e
devolver pro controller.

**Ref:** Paid Media Automation, sessão de reconciliação D4U (2026-08-28) — um agente Explore
dispatchado com `isolation:"worktree"` pra investigar o Relatório de Vendas leu
`percus-kit\scripts\.percus\acao-externa-autorizada.json` (motivo de uma tarefa 0-FUNIL de 7 dias
antes) em vez do `.percus` do projeto que o controller tinha acabado de autorizar minutos antes.
Redispatch sem `isolation`, no diretório real do projeto, resolveu de primeira.
