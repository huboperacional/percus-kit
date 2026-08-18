## `/percus-review:review` e `/spec-analyze` recusam invocação do agente via Skill tool — reservados pro operador {#percus-review-recusa-skill-tool}

tags: disable-model-invocation skill blocked, review command cannot be invoked by agent, spec
analyze requires explicit user invocation, council gate reserved for operator, canon 6.35.0 skill
restriction

**Sintoma:** chamar `Skill({skill: "percus-review:review"})` (ou `percus-review:spec-analyze`)
programaticamente devolve erro explícito: *"cannot be used with Skill tool due to
disable-model-invocation... Do not replicate this skill's workflow by other means — it is reserved
for explicit user invocation."* Isso quebra fluxos que antes funcionavam (ex.: bypass via
`review-router.ps1`/`deepseek-review.ps1` direto por Bash, documentado em versões antigas desta
base como workaround válido).

**Causa raiz:** mudança de canon (6.34.1→6.35.0 na máquina onde foi observado) endureceu o gate
R11/`[S]` — o objetivo é impedir que o próprio agente se autoconceda a revisão que deveria vir de
uma decisão do operador. A mensagem de erro é uma instrução explícita, não um bug: pede
textualmente pra NÃO replicar o workflow por outro meio.

**Solução:** não contornar (nem com script direto, nem repetindo a lógica manualmente) — isso
violaria a instrução explícita do próprio gate. Fluxo correto: avisar o operador que o commit/spec
está pronto mas precisa de `/percus-review:review` (ou `/spec-analyze`) rodado por ELE. Quando o
operador digita o slash command, o conteúdo do comando é injetado no contexto da conversa (bloco
`<command-name>`/`<command-message>`) — isso É uma invocação explícita do usuário, diferente de o
agente chamar via Skill tool, e o agente PODE seguir as instruções injetadas normalmente (rodar os
scripts que o comando manda, interpretar o resultado, fazer fact-check de CRITICAL antes de aceitar
— guardrail R20). O hook de pre-commit aceita a entry gerada por esse fluxo exatamente como
aceitaria a de uma sessão manual.

**Ref:** Família Milionária, sessão 2026-08-08 — bloqueado 3x (`/percus-review:review` 2x,
`/percus-review:spec-analyze` 1x), resolvido todas as vezes pedindo pro operador rodar o slash
command explicitamente. Ver também memória local `percus_review_skill_bypass` (atualizada nesta
sessão, memória antiga sugeria o bypass agora proibido).
