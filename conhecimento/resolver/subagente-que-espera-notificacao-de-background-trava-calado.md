## Subagente que dispara trabalho longo em background e espera notificação trava CALADO {#subagente-que-espera-notificacao-de-background-trava-calado}

`tags: subagente, sdd, background, deadlock, suite longa, turno morto, dispatch, harness, retomada`

**Sintoma:** um subagente "termina" com uma frase do tipo *"vou aguardar a suíte em background me
notificar para então finalizar o commit"*. Nada foi commitado. O trabalho está no disco, o turno
morreu, e o controlador recebe um relatório que não é relatório.

**Causa raiz:** a notificação de conclusão de tarefa em background vai para **quem despachou** — o
controlador —, não para o subagente que a iniciou. Quando o subagente encerra o turno, ele não
volta sozinho. Ele fica esperando um evento que, para ele, nunca acontece.

**Por que reincide mesmo com aviso:** dizer em prosa *"a espera acontece dentro do seu turno"* **não
basta** — isso foi escrito, em negrito, num briefing, e o mesmo deadlock aconteceu na task seguinte.
O modelo lê a frase como preferência de estilo, não como propriedade do ambiente.

**Conserto no dispatch — instrução operacional, não conselho:**

> **NÃO use execução em background para a suíte.** Rode em primeiro plano e espere terminar dentro
> do seu turno. Ela demora vários minutos; isso é esperado e **não** é motivo para encerrar.

**Conserto quando já travou (custo baixo, se você medir antes de agir):**
1. `git log --oneline -1` e `git status --porcelain` no worktree — o trabalho quase sempre está **no
   disco**, não commitado. Nada se perdeu.
2. Confirme se o processo longo está mesmo rodando (ex.: `docker ps` do container efêmero). Nos dois
   casos observados, **não estava** — a espera era por um processo que já tinha morrido junto com o
   turno.
3. Retome o subagente com o estado medido em mãos ("HEAD em X, arquivo Y modificado às HH:MM, nenhum
   container de pé") e a ordem de rodar em primeiro plano.

**Observado em:** tiatendo, frente cidade-inteira (2026-08-19/20), **duas vezes** — na task dos três
estados da zona e na suíte de mutação.

Ver [subagent-driven-worktree-nativo](../fazer/subagent-driven-worktree-nativo.md).
