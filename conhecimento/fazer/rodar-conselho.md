## Consultar o conselho (consult / pre-mortem / analyze) {#rodar-conselho}

`tags: council, conselho, consult, pre-mortem, analyze, orchestrator, temp file, stale`

**Quando:** decisão reversível de baixo risco (`consult`), validar plano antes de ExitPlanMode
(`pre-mortem`), ou validar spec de feature antes do `[0]` (`analyze`).

**Passos:**
1. Escreva o prompt num **arquivo temp único** (nunca nome fixo — ver [conselho-prompt-stale](../resolver/conselho-prompt-stale.md)).
2. Rode o orchestrator com o `-Mode` certo e os providers (2 default; +cross-claude se sensível).
3. Se `__PERCUS_NEEDS_CROSS_CLAUDE__`: dispatch subagent, salve em temp único, re-invoque com `-CrossClaudeFile`.
4. Leia o log em `.deepseek/council-log/<ts>-<mode>.jsonl` e sintetize.

**Comando:**
```powershell
$Q = Join-Path $env:TEMP "council-$([guid]::NewGuid().ToString('N')).txt"
Set-Content -LiteralPath $Q -Value $prompt -Encoding utf8
pwsh -File "${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.ps1" -PromptFile $Q -Mode <consult|pre-mortem|analyze> -Providers "deepseek,groq-llama"
Remove-Item -LiteralPath $Q -Force
```

**Armadilhas:** nome de arquivo fixo → prompt stale; escalar finding não-verificado pro conselho sem
fact-check (R20). Ver `06_CONSELHO_PERCUS.md` (5 modos).
