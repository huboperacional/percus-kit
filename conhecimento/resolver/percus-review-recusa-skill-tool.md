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

---

### ✅ REVOGADO em 2026-08-19 (canon 6.40.0) — as travas foram REMOVIDAS

`disable-model-invocation` saiu dos seis comandos (`review`, `deepseek-review`,
`cross-claude-review`, `milestone-review`, `spec-analyze`, `version`). O fluxo descrito acima —
"avise o operador e peça que ELE digite o slash command" — **não vale mais**: o agente invoca
direto.

**Por que caiu.** A trava cobrava um custo real e não entregava a garantia que a justificava:

- **Não impedia auto-aprovação.** Ela bloqueia só a *Skill tool*. O script por baixo
  (`deepseek-review.ps1`) sempre foi chamável por Bash — e foi chamado ~6 vezes numa única sessão
  de 2026-08-19, com o hook R11 exigindo review a cada commit. Regra de honra, não enforcement.
- **O marcador é forjável.** Um `latest.jsonl` encontrado no disco nessa mesma sessão trazia
  `provider: cross-claude` e `model: claude-sonnet-5`: foi escrito **à mão por um agente**, sem
  nenhuma chamada ao provedor acontecer. O que libera o commit pode existir sem review nenhuma.
- **O custo era um round-trip humano por commit**, num ciclo em que o overhead já era fixo (~5 min
  entre suíte de 184 s e review de 60–90 s) e não proporcional ao tamanho da mudança.

🔑 **A lição é sobre a forma do controle, não sobre revisar ou não.** Fricção que depende de boa-fé
não é controle — é imposto. Ou o mecanismo é verificável (marcador assinado, invocação registrada
de forma não forjável), ou ele é só atrito com aparência de garantia. Manter o meio-termo é o pior
dos casos: paga-se o preço todo dia e não se recebe a integridade nenhum dia.

A revisão em si **continua obrigatória** — o que mudou foi quem pode disparar, e (na 6.40.0) o fato
de a validade passar a ser o hash do diff em vez do relógio. Ver
[[marcador-otimizado-pro-hook-apaga-o-historico-do-medidor]].
