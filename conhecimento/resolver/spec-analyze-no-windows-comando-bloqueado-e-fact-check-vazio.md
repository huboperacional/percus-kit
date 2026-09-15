## `spec-analyze` no Windows: o comando da skill é barrado inteiro, a reinvocação degrada as pernas, o Llama julga spec cortada e o fact-check audita zero {#spec-analyze-no-windows-comando-bloqueado-e-fact-check-vazio}

`tags: conselho, spec-analyze, council-orchestrator, analyze, harness, remove-item, caminho com espaco, scratchpad, cross-claude, cross-claude-file, reinvocacao, deepseek, finish_reason length, groq-llama, truncamento, CRITICAL, fact-check, findings_total 0, falso verde, windows, R23`

**Quando:** rodando `/percus-review:spec-analyze` (plugin 6.53.0) no Claude Code em Windows, com o
projeto em `D:\Claud Automations\…` e sem `ANTHROPIC_API_KEY` no ambiente.

**Sintoma:** quatro falhas em sequência. Nenhuma dá erro claro. No fim, a spec parece analisada e
verificada, e não foi.

**Armadilhas:**

1. **O comando da skill não roda.** O one-liner PowerShell (`Copy-Item` da spec para `$env:TEMP`,
   orchestrator, `Remove-Item`) é recusado inteiro pela trava do harness:
   `Remove-Item on system path 'D:\Claud' is blocked`. A trava corta o caminho no espaço e toma
   `D:\Claud` por caminho de sistema. Nada executa, nem a cópia.
   **Contorno:** copiar a spec para o scratchpad da sessão (descartável, nome único) e não chamar
   `Remove-Item`.

2. **A reinvocação chama DeepSeek e Llama de novo, e pode sair pior.** Sem a chave, o orchestrator
   emite `__PERCUS_NEEDS_CROSS_CLAUDE__` e o Cross-Claude vai por subagente. Reinvocar com
   `-CrossClaudeFile` é uma chamada completa. Numa das specs, as duas pernas degradaram na segunda
   chamada: DeepSeek com resposta vazia (gastou o teto de 16000 tokens raciocinando,
   `finish_reason=length`) e groq-llama com `error`.
   **Contorno:** disparar o subagente Cross-Claude ANTES e rodar o orchestrator uma vez só, já com
   `-CrossClaudeFile`. Se já rodou sem ele, guardar o JSON da primeira rodada e usar as respostas dela.

3. **O Llama julga uma spec cortada.** A perna groq-llama tem teto próprio de 5000 tokens e trunca a
   spec (6733 → ~4791). Em spec longa, ele aponta como "inexistente" um FR que ficou no corte. Também
   marcou CRITICAL de `02_INFRA` para divergências já declaradas no PLANO do projeto (Prisma no lugar
   de Alembic, migration escrita à mão, chave em secret do Swarm).
   **Contorno:** em spec longa, tratar CRITICAL do Llama como não verificado. Conferir se o trecho
   citado caiu no corte e se a divergência já está declarada no PLANO.

4. **O fact-check devolve zero e o pipeline segue.** `fact-check.ps1` recebendo por stdin linhas no
   formato do analyze (`CRITICAL ref - defeito - correção`) devolve `findings_total: 0`. Não auditou
   nada. O fluxo continua como se tudo estivesse verificado.
   **Contorno:** conferir todo CRITICAL à mão contra o texto do canon (`01_REGRAS_INEGOCIAVEIS.md` /
   `02_INFRA_E_STACK_PERCUS.md`) e contra o PLANO do projeto.

**Ref:** LiliCalc, 2026-09-14 — specs `concorrentes-na-ficha` e `despesas-fixas-do-negocio`. Três
CRITICAL do Llama, todos infundados na conferência à mão.
Relacionados: [guarda-de-path-protegido-tokeniza-por-espaco-e-corta-o-alvo](guarda-de-path-protegido-tokeniza-por-espaco-e-corta-o-alvo.md)
(a mesma trava, outros comandos), [conselho-perna-vazia-teto-tokens](conselho-perna-vazia-teto-tokens.md),
[conselho-trunca-o-prompt-antes-de-enviar](conselho-trunca-o-prompt-antes-de-enviar.md),
[fact-check-infundado-e-nao-verificado](fact-check-infundado-e-nao-verificado.md).
