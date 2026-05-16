---
name: council:consult
description: Consulta os 3 membros do conselho Percus (DeepSeek + Llama + opcionalmente Cross-Claude) em paralelo sobre uma decisao de design/naming/pattern. Devolve sintese.
---

# /council:consult

Use para decisao **reversivel + baixo blast radius** onde 3 perspectivas ajudam:
- Refactor mecanico (extrair funcao, renomear var).
- Naming de coluna/tabela/endpoint.
- Escolha entre 2 padroes internos canonicos.
- Decomposicao de plano grande.

**VETADO** (sempre pergunte ao operador via `AskUserQuestion`):
- Decisao de stack (FastAPI/Next.js/Postgres/...).
- Decisao de produto (escopo, prazo, prioridade).
- Pasta sensivel (auth/payment/migrations) — esses passam pelo modo "review_sensitive" automatico.

## Fluxo (passo a passo do agente)

1. **Salve a pergunta + opcoes A/B/C** em `/tmp/council-q.txt`. Formato:
   ```
   PERGUNTA: <pergunta clara, 1-2 linhas>
   CONTEXTO: <2-4 linhas relevantes>
   OPCAO A: <opcao>
   OPCAO B: <opcao>
   (OPCAO C: opcional)
   ```

2. **Decida providers** com base no risco/sensibilidade:
   - Decisao trivial (rename, refactor mecanico): `--providers "deepseek,groq-llama"` (2 providers, ~$0.002, latencia ~2s).
   - Decisao com impacto medio: `--providers "deepseek,groq-llama,cross-claude"` (3 providers, ~$0.005 + 1 subagent, latencia ~30s).

3. **Rode o orchestrator:**
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.ps1" `
       -PromptFile "/tmp/council-q.txt" `
       -Mode consult `
       -Providers "deepseek,groq-llama"
   ```

4. **Se output stderr tiver `__PERCUS_NEEDS_CROSS_CLAUDE__`:** dispatch subagent Sonnet via Agent tool (subagent_type=general-purpose) com o prompt mostrado no stderr. Salve resposta em `/tmp/council-cc.txt`. Re-invoque orchestrator com `-CrossClaudeFile "/tmp/council-cc.txt"`.

5. **Leia o ultimo log** em `.deepseek/council-log/<ts>-consult.jsonl` e sintetize:
   - **3/3 concordam** → execute sem perguntar, registre no commit log que conselho foi consultado.
   - **2/3 concordam** → execute a posicao majoritaria + cite a divergencia minoritaria no commit.
   - **1/1/1 ou divergencia grave** → `AskUserQuestion` ao operador com **contexto consolidado** das 3 perspectivas.

## Output esperado pro operador

Apos sintese, mostre na conversa:

```
[council:consult]
  DeepSeek: <posicao em 1 linha> (latencia Xms)
  Llama:    <posicao em 1 linha> (latencia Xms)
  Cross-Claude: <posicao em 1 linha> (se rodou)
  ---
  Veredito: <CONSENSO N/N | MAJORIA N/M+divergencia | SEM CONSENSO -> pergunta operador>
  Acao tomada: <executei X | perguntei operador>
```

## Skip / escape

- `$env:PERCUS_SKIP_COUNCIL=1` — agente ignora skill, perguntar ao operador como antes (Fase 5).
- Sempre que duvida persistir, prefira perguntar ao operador via `AskUserQuestion` em vez de forcar consenso.

## Custo / latencia

| Set | Custo | Latencia |
|---|---|---|
| deepseek + groq-llama | ~$0.002 | ~2s |
| + cross-claude (subagent Sonnet) | ~$0.005 + assinatura Claude Code | ~30s |

## Anti-padroes

- ❌ Usar consult pra decisao irreversivel (deploy, drop table, push force) — pergunte sempre.
- ❌ Aceitar consenso 3/3 cego em pasta sensivel — opere consult-review primeiro.
- ❌ Pular consult pra "ir mais rapido" — quando elegivel, defaulta consult (custo/latencia minimos).

## Referencias

- Spec: `_Novo_Projeto/06_CONSELHO_PERCUS.md` Modo 2.
- Registry: `providers/_registry.json`.
- Logs: `.deepseek/council-log/`.
