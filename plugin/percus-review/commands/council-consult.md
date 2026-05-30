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

## Pre-requisitos (enforcement v6.7.0+)

ANTES de invocar council-consult com findings técnicos como contexto, verifique:

1. **Findings críticos passaram por fact-check?**
   Se contexto inclui findings com `[SEV: risco]` ou `[SEV: bug]`, eles devem ter sido
   processados por `fact-check.ps1` (F3 pipeline) ou conter metadata `fact_check: CONFIRMADO`.

   **Como verificar:**
   - Rodou `/percus-review:review` no diff completo? Output já passou pelo F3 desde v6.7.0+.
   - Está consolidando findings manualmente? Rode antes:
     ```bash
     cat findings.md | pwsh -File "${env:PERCUS_CANON_DIR}/plugin/percus-review/scripts/fact-check.ps1"
     ```

2. **Se você está escalando finding INFUNDADO ou unverified para o council:**
   - **STOP.** O council vai votar em premissa textual sem ver código.
   - Anti-padrão observado (incidente Plexco Tasks 2026-05-18): council 3/3 ratificou
     alegação falsa do DeepSeek porque viu só texto, não código. Resultado: 4 PR
     comments públicos errados foram postados, operador perdeu confiança.

3. **Council ≠ autorização pra ação externa pública** (R20):
   Consenso 3/3 do council é licença pra ação reversível interna apenas. PR comment,
   Slack, deploy, push: gate explícito do operador OBRIGATÓRIO antes de executar.
   Hook `external-action-guard.ps1` (PreToolUse) bloqueia `gh pr comment`, `slack-cli`,
   `git push` sem `PERCUS_EXTERNAL_OVERRIDE=1`.

## Warning automático

Se você (agente) usa esta skill com:
- Findings críticos no contexto
- Sem evidência de fact-check (`fact_check: CONFIRMADO` ausente)
- Sem confirmação do operador

**Pare e pergunte ao operador antes de prosseguir.** Mensagem sugerida:

> "Vou consultar o council sobre findings críticos. Os findings já passaram por
> fact-check (F3 pipeline)? Se não, recomendo rodar `fact-check.ps1` primeiro
> pra evitar council ratificar alegação não verificada (anti-padrão R20)."

Aguarda resposta explícita antes de chamar `council-orchestrator.ps1`.

## Fluxo (passo a passo do agente)

1. **Monte a pergunta + opcoes A/B/C.** Formato do conteudo:
   ```
   PERGUNTA: <pergunta clara, 1-2 linhas>
   CONTEXTO: <2-4 linhas relevantes>
   OPCAO A: <opcao>
   OPCAO B: <opcao>
   (OPCAO C: opcional)
   ```
   > ⚠️ **NUNCA salve num nome de arquivo FIXO** tipo `/tmp/council-q.txt` (bug 2026-05-30: no Windows `/tmp/...` resolve pra `d:\tmp\...` e o arquivo fica **stale entre runs** — o orchestrator le o prompt VELHO e o conselho "revisa a coisa errada de novo"). Use um arquivo temp **unico por invocacao** (passo 3).

2. **Decida providers** com base no risco/sensibilidade:
   - Decisao trivial (rename, refactor mecanico): `--providers "deepseek,groq-llama"` (2 providers, ~$0.002, latencia ~2s).
   - Decisao com impacto medio: `--providers "deepseek,groq-llama,cross-claude"` (3 providers, ~$0.005 + 1 subagent, latencia ~30s).

3. **Rode o orchestrator** — arquivo temp **unico** escrito e consumido na MESMA invocacao pwsh, com cleanup:
   ```powershell
   $Q = Join-Path $env:TEMP "council-q-$([guid]::NewGuid().ToString('N')).txt"
   @'
   <conteudo do passo 1 — PERGUNTA/CONTEXTO/OPCAO A/B/C>
   '@ | Set-Content -LiteralPath $Q -Encoding utf8
   pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.ps1" -PromptFile $Q -Mode consult -Providers "deepseek,groq-llama"
   Remove-Item -LiteralPath $Q -Force -ErrorAction SilentlyContinue
   ```
   Unix: `Q=$(mktemp); printf '%s' "$prompt" > "$Q"; bash "${CLAUDE_PLUGIN_ROOT}/scripts/council-orchestrator.sh" --prompt-file "$Q" --mode consult --providers "deepseek,groq-llama"; rm -f "$Q"`. (Alternativa ainda mais a prova de stale: passar o prompt por **stdin** — orchestrator le stdin se `-PromptFile`/`--prompt-file` for omitido.)

4. **Se output stderr tiver `__PERCUS_NEEDS_CROSS_CLAUDE__`:** dispatch subagent Sonnet via Agent tool (subagent_type=general-purpose) com o prompt mostrado no stderr. Salve a resposta num arquivo temp **unico** (`$CC = Join-Path $env:TEMP "council-cc-$([guid]::NewGuid().ToString('N')).txt"`; Unix `mktemp`) e re-invoque com `-CrossClaudeFile $CC`. **NUNCA reuse `/tmp/council-cc.txt`** (mesmo motivo de stale do passo 1).

5. **Leia o ultimo log** em `.deepseek/council-log/<ts>-consult.jsonl` e sintetize:
   - **3/3 concordam** → execute sem perguntar, registre no commit log que conselho foi consultado.
   - **2/3 concordam** → execute a posicao majoritaria + cite a divergencia minoritaria no commit.
   - **1/1/1 ou divergencia grave** → `AskUserQuestion` ao operador com **contexto consolidado** das 3 perspectivas.
   - **`tie_breaker_invoked: true` no log (Vetor D, v6.14.0):** a Llama foi chamada como desempate porque 2 providers OK divergiram em `premise_validity` e o groq-llama nao estava entre eles. Trate o resultado (`tie_breaker.content`) como **"2/3 informal — tie-breaker fraco"**, NUNCA como consenso forte. Em duvida, prefira `AskUserQuestion` ao operador.

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
- ❌ Escalar finding nao verificado pro council sem fact-check (F3) — council ratifica premissa textual; incidente Plexco Tasks 2026-05-18.
- ❌ Executar acao externa publica (PR comment, push, Slack) com base em consenso 3/3 sem gate do operador (R20).

## Referencias

- Spec: `_Novo_Projeto/06_CONSELHO_PERCUS.md` Modo 2.
- Registry: `providers/_registry.json`.
- Logs: `.deepseek/council-log/`.
