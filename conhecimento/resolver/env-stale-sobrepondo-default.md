## Config que só o browser vê: env stale sobrepondo o default do código {#env-stale-sobrepondo-default}

tags: env override, CORS_ALLOWED_ORIGINS, config apodrece, default no codigo, swarm, tasks recriadas,
falha silenciosa no servidor, TypeError Failed to fetch, smoke pos-deploy, OPTIONS por origin,
cross-product

**Origem:** P0 de 2026-07-30 — 11h com login quebrado em 6 produtos.

Um `CORS_ALLOWED_ORIGINS` explícito no env do Swarm sobrepunha o default do código (que era gerado,
versionado e completo) e recusava 7 origins. **A falha é silenciosa do lado do servidor:** serviço
`healthy`, log limpo, nada erra — quem quebra é o browser do usuário (`TypeError: Failed to fetch`,
porque o preflight volta 400 sem `access-control-allow-origin`).

- **Padrão:** env override de lista **apodrece**. Prefira o default no código (gerado de um manifesto
  versionado) e trate o env como escape hatch temporário.
- **Sintoma de que o env está mandando:** o valor efetivo do processo ≠ o literal do código. Leia o
  processo vivo, não o repo.
- **Gatilho comum:** a mudança de env só entra em vigor quando as **tasks são recriadas** — pode
  ficar meses armada e detonar num restart qualquer.
- **Cuidado cross-product:** o script de outro produto pode estar escrevendo no seu serviço. Procure
  o consumidor declarado (`grep -rl 'SEU_ENV' /opt /root --include='*.yml' --include='*.yaml'`).
- **Defesa:** smoke pós-deploy de `OPTIONS` por origin, esperando **200 + `ACAO`**. Transforma falha
  invisível em falha barulhenta.

**Relacionado:** [#preflight-cors-falha-silenciosa] — mesmo P0, visto do outro lado: lá está **como
diagnosticar** o preflight recusado; aqui, **por que o env chegou nesse estado**.
