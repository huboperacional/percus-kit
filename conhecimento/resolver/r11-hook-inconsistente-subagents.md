## Hook R11 (`PreToolUse` de review antes de commit) tem enforcement inconsistente pra subagents via Agent/Task tool {#r11-hook-inconsistente-subagents}

`tags: R11, pre-commit hook, PreToolUse, subagent-driven-development, plugin hooks, enforcement gap`

**Contexto:** ADS4PROS-Site, sessão 2026-08-04, executando `superpowers:subagent-driven-development`
(8 tasks + 3 fixes, cada uma com implementer subagent + spec-review + quality-review, todos
commitando via `git commit` dentro do próprio subagent). O hook R11 (`hooks/hooks.json` do plugin
`percus-review`, `PreToolUse` casando `Bash|PowerShell` → `pre-commit-check.cmd`) bloqueia a
**sessão principal** de forma confiável — já tinha acontecido 2x na mesma sessão antes disso, sempre
exigindo `/percus-review:review` fresco (<5min) pra destravar. Ao dispatchar subagents pra
implementar+commitar cada task do plano, o comportamento foi **inconsistente**: dois subagents
seguidos, no mesmo repo, mesmo hook instalado — um teve o `git commit` bloqueado normalmente
("review too old", teve que rodar fresco antes de conseguir), outro passou direto sem o hook
disparar nenhuma vez.

**Causa raiz:** não identificada com certeza (não investigado a fundo pra não desviar do objetivo
da sessão). Hipóteses não descartadas: hooks `PreToolUse` registrados via plugin podem não propagar
de forma garantida pro contexto de execução de subagents dispatchados via Agent/Task tool
(dependendo de como o harness isola/herda o processo do subagent), OU há uma condição de corrida
entre subagents concorrentes/dispatch rápido que faz o hook não disparar em alguns casos.

**Sinal de alerta pra generalizar:** ao orquestrar subagents que commitam código em qualquer repo
com hook de pre-commit obrigatório (Percus ou não), **não assumir que o hook é um gate garantido**
só porque funciona de forma confiável na sessão principal — testar (ou instruir explicitamente o
subagent a rodar a review manualmente de qualquer forma, review-ou-não-review) antes de confiar
nessa camada como única linha de defesa.

**Solução:** instruir todo subagent que vai commitar a rodar `/percus-review:review` (ou o wrapper
DeepSeek/cross-claude direto) explicitamente ANTES do `git commit`, independente do hook — às vezes
vai ser redundante (o hook bloquearia mesmo), às vezes é a única camada real de defesa que roda. E
pedir pro subagent colar o **output bruto** da review no relatório de volta (não só a conclusão
"passou"/"falso positivo"), pra o controller poder auditar achados de segurança dispensados sem
confiar cegamente no auto-julgamento do subagent.

**Relacionado:** memória de projeto `feedback_r11_hook_nao_propaga_subagentes` (ADS4PROS-Site).

**Ref:** ADS4PROS-Site, sessão 2026-08-04, feature `assinatura.ads4pros.com` (commits `9e58c17`
bloqueado normalmente vs. commit da Task 5/CopyButton passando sem o hook disparar).
