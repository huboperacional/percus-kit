## Subagente que espera Monitor/comando em background encerra o turno e nunca acorda — e limite de sessão da API pode deixá-lo parado com o código mutado {#subagente-em-background-nao-acorda-com-notificacao}

`tags: subagente, background, monitor, notificacao, agent, sdd, limite de sessão, rate limit, 429, gate mutado, R23`

**Sintoma 1:** um subagente implementador disparado em background devolve "aguardando a notificação do monitor X com o
resultado do RED" e para. Nada acontece depois: a notificação de um comando em background **não acorda um subagente que já
encerrou o turno** — ele só volta quando alguém manda mensagem a ele.

**Como evitar:** no dispatch, diga com todas as letras "não use Monitor nem comando em background para esperar; rode em
primeiro plano com timeout longo (até 600 s), gravando a saída num log e lendo o `tail`". Suíte que passa de 10 min: rode
em blocos em primeiro plano (e diga isso no relatório), nunca em background. Se já parou: retome por mensagem mandando ler
a saída gravada ou rodar de novo em primeiro plano.

**Sintoma 2** (paid-media, 2026-09-14): o limite de sessão da API (HTTP 429, "session limit") derrubou três subagentes ao
mesmo tempo. Um estava no passo "ver o gate reprovando" — **com a mutação aplicada no arquivo** — e morreu antes de
restaurar. O relatório não dizia nada; só a medição do worktree (`git diff`, `grep` da linha do gate) mostrou.

**How to apply:** depois de qualquer queda de subagente, **meça o worktree antes de retomar** (`git status`, `git diff`,
presença das linhas que os gates mutam) e mande a retomada começar pela restauração. Com várias frentes em paralelo,
priorize o caminho crítico com prazo e adie o trabalho pesado (Opus, planos grandes) até ele andar — a próxima queda de
limite custa menos se só uma frente estiver no ar.
