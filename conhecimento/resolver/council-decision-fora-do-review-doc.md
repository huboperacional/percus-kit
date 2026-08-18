## Decisão `"council"` do review-router não está nos passos do comando `/review` — e só `deepseek-review.ps1` escreve o marcador de frescor que o hook checa {#council-decision-fora-do-review-doc}

`tags: percus-review, review-router, council, deepseek-review, reviews latest.jsonl, council-log, pre-commit hook, freshness, R11, versao do kit, drift de documentacao`

**Contexto:** Kommo-Disparo-WhatsApp, 2026-08-05 — primeiro commit de um projeto novo (37+ arquivos,
pasta sensível inteira). `/percus-review:review` roda `review-router.ps1 -Json` e devolve
`"decision":"council"`. Os passos do próprio comando `/review` só cobrem 3 ramos —
`"deepseek"`/`"cross-claude"`/`"dual"` — nenhuma instrução pra `"council"`.

**Causa raiz:** `"council"` é decisão nova (`review-router.ps1` docstring: "Fase 6 v6.1.0+", dispara
quando pasta sensível **e** (commit veio do DeepSeek **ou** >10 arquivos)). O texto do comando
`/review` ficou desatualizado em relação ao router instalado — mesmo drift que o health-check da
sessão já apontava ("versão instalada 6.34.0 diferente da do kit 6.34.1").

**O que fazer quando `decision == "council"`:** chamar `council-orchestrator.ps1` direto —
`-Mode review -Providers "deepseek,groq-llama,cross-claude"` (cross-claude via o fallback normal do
marker `__PERCUS_NEEDS_CROSS_CLAUDE__`) — passando o diff (ou um recorte priorizado dos arquivos mais
sensíveis, se o diff inteiro estourar `-MaxInputTokens`) como `-PromptFile`.

**Pegadinha separada, mais cara:** `council-orchestrator.ps1` loga em
`.deepseek/council-log/<timestamp>-<mode>.jsonl` — **NÃO** em `.deepseek/reviews/latest.jsonl`, que é
o arquivo que o hook `pre-commit-check` de fato lê pra decidir se o review está fresco (≤5min). Só
`deepseek-review.ps1` (o wrapper simples do ramo `"deepseek"`) escreve `reviews/latest.jsonl`. Rodar
só o conselho, por mais completo que seja, **não desbloqueia o commit** — o hook bloqueia com
`"nenhum /percus-review:review em .deepseek/reviews/"` mesmo com o council-log cheio. **Solução:**
depois do council (ou junto, se o tempo permitir), rodar `deepseek-review.ps1` sem argumentos
(lê `git diff --cached`+`git diff` sozinho, publica em `reviews/latest.jsonl`) — ele é rápido
(~15-60s) e serve como refresh do marcador de frescor mesmo quando o conselho já fez a análise funda.

**Ref:** Kommo-Disparo-WhatsApp, primeiro commit `a59bd60`, sessão 2026-08-05.
