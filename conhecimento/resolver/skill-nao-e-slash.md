## Skill do plugin referida como slash command (`/percus-review:checkpoint`) — não existe {#skill-nao-e-slash}

`tags: skill, slash command, checkpoint, feature-flow, consult-knowledge, plugin, percus-review, namespace, invocacao, command not found, autocomplete, SKILLS_VS_COMMANDS`

**Sintoma:** um HANDOFF/doc/agente manda "rode `/percus-review:checkpoint`" (ou `/percus-review:feature-flow`, `/percus-review:consult-knowledge`…) e o command **não existe** — não aparece no autocomplete, "command not found".

**Causa raiz:** `checkpoint` e cia. são **skills**, não **slash commands**. No plugin `percus-review`, só o que está em `commands/*.md` é slash (review, milestone-review, deepseek-review, cross-claude-review, spec-analyze, install-git-hooks, version → `/percus-review:<nome>`; os 4 do conselho declaram `name: council:*` no frontmatter e têm namespace próprio a confirmar — ver `comandos/SKILLS_VS_COMMANDS.md`). O que está em `skills/<nome>/SKILL.md` (checkpoint, feature-flow, consult-knowledge, close-milestone, delegate-impl, auth-consumer, security-audit, tracking-audit, cookie-audit, pages-scan, port-allocate, catalog-publish) **não tem slash**. Agrava: o namespace de skill é **instável** — numa instalação real apareceu como `6.28.0:checkpoint` (a **versão** como namespace, não `percus-review:`), então nem `/6.28.0:checkpoint` é confiável entre bumps. O erro nasce de extrapolar `/percus-review:review` (que É command) pras skills.

**Solução:** skill invoca-se por **linguagem natural** — o user descreve a intenção ("faça o checkpoint deste milestone", "consulte o que já sabemos sobre X") e o **agente invoca via `Skill` tool**. Nunca escreva "rode `/percus-review:<skill>`" num doc/HANDOFF/template. Inventário completo (11 commands × 12 skills) + regra de ouro: `comandos/SKILLS_VS_COMMANDS.md`.

**Ref:** confusão diagnosticada 2026-07-11 (operador não achou `/percus-review:checkpoint`); inventário em `comandos/SKILLS_VS_COMMANDS.md`; regra R23.
