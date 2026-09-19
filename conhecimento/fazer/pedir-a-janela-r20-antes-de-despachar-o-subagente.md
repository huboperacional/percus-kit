## Pedir a janela do R20 ANTES de despachar o subagente que precisa dela {#pedir-a-janela-r20-antes-de-despachar-o-subagente}

`tags: R20, external-action-guard, subagente, vps-test, janela 60 minutos, autorizacao, planejamento, desperdicio`

**Quando:** você vai despachar um subagente cujo trabalho depende de uma ação que o
`external-action-guard` bloqueia — tipicamente rodar a suíte de backend num Postgres remoto
(`vps-test.py`), mas vale para qualquer comando que o guard reconheça.

**O que acontece se não pedir antes:** o subagente escreve o código inteiro, chega na hora de provar
e volta `BLOCKED`. A autorização é **do operador** — nem o subagente nem o controlador podem criá-la
por conta própria. Resultado: uma rodada inteira de trabalho parada esperando um "sim" que poderia
ter sido pedido no começo, e o contexto do subagente esfriando enquanto isso.

**O que acontece se a janela vencer no meio:** a janela dura **60 minutos**. Uma rodada de
implementação com TDD mais suíte inteira (~13 min por execução) come isso fácil. O subagente termina
o código, roda o arquivo de teste, e quando vai rodar a suíte completa leva `BLOCK` — com a metade
da prova feita e a outra metade impossível. Medido em 2026-09-18 (Plexco Tasks, Task 18): a segunda
rodada de correção ficou com mypy limpo e **zero teste rodado**, e foi preciso acordar o operador
para uma segunda janela.

**Procedimento:**

1. **Antes** de compor o prompt do subagente, veja se a tarefa precisa da ação bloqueada. Se
   precisar, peça ao operador uma pergunta binária ("autoriza rodar X por 60 min? sim/não") e só
   despache depois do sim.
2. Crie a autorização com `percus-kit/scripts/autorizar-acao-externa.ps1 -Motivo "<cita o sim
   literal do operador>" -ProjetoRoot "<raiz do projeto>"` — o motivo tem que registrar de quem veio
   o sim e para quê.
3. **Diga no prompt do subagente quanto tempo resta** e mande ele reportar `BLOCKED` se vencer, com
   a instrução explícita de **não renovar sozinho**.
4. Se a rodada for longa (suíte inteira mais de uma vez), considere pedir a janela em duas etapas ou
   avisar o operador de que vai precisar renovar.
5. Autorização em lote pela noite/sessão existe: o operador pode dizer "renove sempre que vencer,
   só para este comando". Aí o controlador renova **citando esse sim** — é consentimento do
   operador, não autorrenovação.

**Não confunda com:** [[autorizar-acao-externa-bloqueada-no-meio-da-sessao]] (como destravar quando
já bloqueou) e [[agente-isolado-em-worktree-nao-ve-autorizacao-r20-do-projeto]] (o arquivo é lido a
partir do cwd persistido, não do worktree).
