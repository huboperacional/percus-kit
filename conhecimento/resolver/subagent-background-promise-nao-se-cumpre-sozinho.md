## Subagente que promete "reporto quando terminar" um comando em background não retoma sozinho — precisa de outro SendMessage {#subagent-background-promise-nao-se-cumpre-sozinho}

`tags: subagent-driven-development, Agent tool background, run_in_background dentro de subagent, TaskOutput no task found, falsa promessa de auto-relatorio, controller precisa cutucar, notificacao nao dispara, code-quality reviewer travado`

**Sintoma:** o controller despacha um subagent (via Agent tool, ex.: revisor de qualidade de código
dentro de `subagent-driven-development`) que precisa rodar um comando demorado (ex.: suíte de testes
completa, ~7min) pra concluir seu próprio trabalho. O subagent roda esse comando via seu Bash tool
com `run_in_background`, e responde ao controller algo como "vou aguardar terminar e reportar
automaticamente — não vou ficar consultando". O turno do subagent **termina ali** (a
task-notification que chega pro controller já vem com `status: completed`). Nenhuma notificação nova
chega quando o comando em background de fato termina — o trabalho fica parado indefinidamente até o
controller (ou o operador) notar e agir. `TaskOutput(task_id=<agentId do subagent>, block=false)`
retorna `No task found with ID`, confirmando que não há nada rastreável rodando daquele lado.

**Causa raiz:** a promessa "vou reportar quando terminar" só se cumpre se o PRÓPRIO subagent for
re-acordado por uma notificação do seu comando em background — e essa auto-retomada não é garantida
pelo harness. Um `run_in_background` de Bash chamado *dentro* de um subagent não tem, por padrão, o
mesmo mecanismo de "aguarde e seja notificado sem polling" que o controller top-level tem pra Agents
despachados por ele. O resultado observável: o subagent "para de existir" (turno encerrado) sem que
o comando backgrounded o traga de volta sozinho.

**Solução:** o controller não deve confiar na promessa de auto-retomada de um subagent que
backgrounded algo internamente. Sinal de alerta: a task-notification do subagent chega com
`status: completed`, mas o `<result>` diz algo como "vou reportar quando terminar" / "standing by" —
ou seja, o subagent claramente não terminou o TRABALHO, só terminou o TURNO. Nesse caso, o controller
precisa mandar um `SendMessage` de follow-up explícito pro mesmo agente (usando o `agentId` — nomes
continuam funcionando depois que o agente "termina"), pedindo status atual ou — melhor, se o comando
é curto o bastante pra caber num turno — pedindo pra rodar de novo em **foreground** dessa vez (sem
`run_in_background`), garantindo que o turno do subagent só encerre depois do resultado real chegar.

**Trade-off:** pedir foreground custa mais tempo de espera bloqueada nesse `SendMessage` específico
(o controller fica esperando o subagent inteiro, não só um resultado assíncrono), mas é estritamente
mais confiável que apostar numa retomada automática que pode não vir — vale a troca pra comandos de
verificação de poucos minutos (ex.: suíte de testes). Pra comandos MUITO longos (dezenas de minutos),
considere em vez disso reestruturar o trabalho pra o CONTROLLER rodar o comando demorado ele mesmo
(via `Bash` com `run_in_background=true`, que o controller sabe aguardar sem polling de verdade) e só
passar o resultado pro subagent revisar, em vez de delegar o comando longo pro subagent rodar sozinho.

**Ref:** tiatendo, sessão 2026-08-05/06 (N19 — code-quality reviewer subagent dentro de
`subagent-driven-development`; precisou de 3 rodadas de `SendMessage` de follow-up até o resultado
real da suíte completa de testes chegar — cada uma reportando "vou avisar quando terminar" sem de
fato retomar sozinha).
