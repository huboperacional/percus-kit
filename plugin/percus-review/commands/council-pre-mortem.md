---
name: council:pre-mortem
description: Pre-mortem do plano atual via conselho 3-membros. Cada membro responde "se este plano falhar em 30 dias, por que?" Hook pre-plan-exit dispara automaticamente em planos >500 linhas, mas tambem manual.
---

# /council:pre-mortem

Use **antes de ExitPlanMode** em planos com escopo nao-trivial. Conselho aponta riscos invisiveis pro autor.

## Fluxo

1. **Salve o plano** em `/tmp/council-plan.txt` (markdown completo do plano que voce ia chamar `ExitPlanMode` com).

2. **Rode orchestrator em modo pre-mortem com os 3 providers:**
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.ps1" `
       -PromptFile "/tmp/council-plan.txt" `
       -Mode pre-mortem `
       -Providers "deepseek,groq-llama,cross-claude"
   ```

3. **Se stderr `__PERCUS_NEEDS_CROSS_CLAUDE__`:** dispatch subagent Sonnet com prompt mostrado. Salve em `/tmp/council-cc.txt`. Re-invoque com `-CrossClaudeFile "/tmp/council-cc.txt"`.

4. **Leia ultimo log** em `.deepseek/council-log/<ts>-pre-mortem.jsonl`. Cada provider deve ter retornado **3 motivos concretos de falha em ordem de probabilidade**.

5. **Agrupe motivos por similaridade** (manual ou inline). Se >=2 providers apontam mesmo risco -> **risco critico**, mostre destacado.

6. **Reporte ao operador antes do ExitPlanMode:**
   ```
   [council:pre-mortem]
   Plano: <titulo, X linhas>
   
   Riscos consenso (>=2 providers):
   - <risco 1>: DeepSeek + Llama + (CC?). Mitigacao sugerida: ...
   - <risco 2>: ...
   
   Riscos isolados (1 provider):
   - DeepSeek: ...
   - Llama: ...
   - Cross-Claude: ...
   
   Quer ajustar o plano antes de Exit? (sim/nao)
   ```

7. Se operador disser nao OU autorizar `PERCUS_PREMORTEM_OVERRIDE=1`, prossiga com `ExitPlanMode`. Caso contrario, edite plano e re-rode pre-mortem.

## Auto-trigger via hook pre-plan-exit

Hook `pre-plan-exit` (instalado por plugin v6.1.0+) intercepta `ExitPlanMode` quando plano > 500 linhas e dispara este flow automaticamente. Escape: `$env:PERCUS_PREMORTEM_OVERRIDE=1` (logado em `.deepseek/council-log/pre-mortem-override.jsonl`).

## Custo

3 providers + 1 subagent Sonnet = ~$0.005 + assinatura. Latencia ~30s incluindo subagent.

## Anti-padroes

- ❌ Pular pre-mortem em plano grande "porque ja pensei direito" — vies de confirmacao.
- ❌ Override sem motivo declarado em voz alta — log fica orfao.
- ❌ Aceitar so 1 risco critico se >=2 apontaram — corrija plano.

## Referencias

- Spec: `_Novo_Projeto/06_CONSELHO_PERCUS.md` Modo 3.
- Hook: `hooks/pre-plan-exit.{ps1,sh}`.
