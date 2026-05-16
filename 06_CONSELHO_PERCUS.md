---
tipo: arquitetura-de-conselho
prevalece-sobre: comandos/SETUP_REVIEW_ROUTING (Fase 6 supersede)
prevalecido-por: [01_REGRAS_INEGOCIAVEIS, CLAUDE.md do projeto]
quando-usar: ao configurar review/consult/pre-mortem/brainstorm com perspectivas múltiplas
leitura: 7 min
ultima-atualizacao: 2026-05-15
fase-introducao: Fase 6
---

# 06 — Conselho Percus (DeepSeek + Cross-Claude + Llama)

> **O que é:** sistema de 3 modelos consultivos operando em 4 modos. Substitui o esquema Fase 5 (2 modelos, 1 modo).
>
> **Não é mágica:** o conselho não decide negócio nem stack. Ele revisa, opina, sintetiza, sinaliza divergência. Decisões finais são do operador.

---

## Composição

| Membro | Provider | Modelo | Custo (1M in/out) | Especialidade |
|---|---|---|---|---|
| **DeepSeek** | DeepSeek API | `deepseek-chat` | $0.27 / $1.10 | Review cross-provider, código geral |
| **Cross-Claude** | Anthropic (subagent Sonnet) | `claude-sonnet-4-6` | incluso na assinatura Claude Code | Análise de design, raciocínio profundo |
| **Llama** | Groq API | `llama-3.3-70b-versatile` | Free 30 req/min, depois $0.59 / $0.79 | Resposta rápida (~500 tok/s), consultor inline |

**Custo agregado estimado:** $5/mês com volume Percus atual (vs $200-400/mês de Codex pré-2026-05-03).

**Diversidade de provider:** DeepSeek Inc + Anthropic + Meta (via Groq) — 3 origens diferentes, reduz viés single-provider.

---

## 4 modos operacionais

### Modo 1 — Review cross-provider (pre-commit + marco)

**Quando:** antes de cada `git commit` que toca código (R11), e ao fechar cada marco.

**Quem aciona:** automático via wrapper `scripts/percus-review-auto.{ps1,sh}` (já instalado por R9 / R11).

**Como decide:**

| Cenário | Reviewer | Custo |
|---|---|---|
| Commit rotineiro | DeepSeek + Llama (paralelo) | ~$0.02 |
| Commit em pasta sensível (`auth/`, `payment*/`, `migrations/`, `credentials/`, `.env*`) | DeepSeek + Cross-Claude + Llama | ~$0.05 |
| Commit com trailer `Co-implemented-by: deepseek` | Cross-Claude + Llama (sem auto-revisão) | ~$0 + free tier |
| Marco | DeepSeek + Cross-Claude + Llama | ~$0.05 |

Comando manual: `/percus-review:review`.

### Modo 2 — Consult (pré-pergunta)

**Quando:** Claude está prestes a invocar `AskUserQuestion` em decisão de design / naming / pattern interno (não trivial).

**Quem aciona:** o próprio Claude na sessão, via skill `council:consult` (no plugin v6.0.0).

**Como funciona:**

1. Claude formula pergunta + opções A/B/C.
2. Skill manda pros 3 membros em paralelo.
3. Cada um responde: "minha escolha + por quê + qual risco da alternativa".
4. Síntese:
   - **3/3 concordam** → Claude executa sem perguntar, anota em commit log.
   - **2/3 concordam** → Claude executa, mas nota a divergência no commit.
   - **1/1/1** ou divergência grave → Claude faz `AskUserQuestion` ao operador com **contexto consolidado** das 3 perspectivas.

**Tipos de decisão elegíveis pra consult:**
- Refactor mecânico (extrair função, renomear var).
- Naming de coluna/tabela/endpoint.
- Escolha entre 2 padrões internos canônicos (pydantic-settings vs env direto, asyncio vs threads).
- Decomposição de plano grande.

**Vetado pra consult automático** (sempre operador):
- Decisão de stack (FastAPI/Next.js/Postgres/…).
- Decisão de produto (escopo, prazo, prioridade).
- Pasta sensível (auth/payment/migrations).

Comando manual: `/council:consult <pergunta>`.

### Modo 3 — Pre-mortem (plano)

**Quando:** antes de `ExitPlanMode` em planos > 500 linhas.

**Quem aciona:** hook `pre-plan-exit.{ps1,sh}` (instalado por plugin v6.0.0).

**Como funciona:**

1. Hook intercepta `ExitPlanMode`.
2. Manda plano pros 3 membros com prompt: "Se esse plano falhar em 30 dias, por quê? Liste 3 motivos concretos com probabilidade alta."
3. Síntese: agrupa motivos comuns, ordena por probabilidade.
4. Se ≥2 membros apontarem o mesmo risco crítico → hook bloqueia ExitPlanMode até operador revisar.
5. Escape: `PERCUS_PREMORTEM_OVERRIDE=1` (logado em `.deepseek/council-log/pre-mortem-override.jsonl`).

Comando manual: `/council:pre-mortem <path-to-plan>`.

### Modo 4 — Brainstorming companion

**Quando:** dentro de sessão `superpowers:brainstorming`, opcional (operador autoriza no início).

**Quem aciona:** skill `council:brainstorm` chamada por hook que se enxerta em `brainstorming`.

**Como funciona:**

1. Após cada `AskUserQuestion` formulada pelo Claude na sessão brainstorming, o conselho **opcionalmente** roda em paralelo.
2. Cada membro responde como se fosse um consultor independente revisando a opção que o Claude trouxe.
3. Síntese aparece como **contexto adicional** antes do operador responder.
4. Operador ainda responde — o conselho não substitui o operador.

Diferença pra Modo 2: Modo 2 reduz perguntas (consenso → não pergunta); Modo 4 enriquece perguntas (sempre pergunta, mas com 3 perspectivas anexadas).

---

## Tabela de automação (níveis de decisão)

Resposta concreta à dúvida operacional "o que o conselho passa a decidir SEM pedir confirmação":

| Tipo de decisão | Pré-Fase 6 | Fase 6 (com conselho) | Limite/escape |
|---|---|---|---|
| Refactor mecânico (renomear var, extrair função, ajustar import) | Claude pergunta | **Conselho decide** se 3/3 concordam. Operador vê no commit log. | Skip se arquivo > 200 linhas afetadas → operador vê. |
| Naming de coluna/tabela/endpoint | Claude pergunta | **Conselho propõe top-1 + 2 alternativas**, Claude usa top-1 + nota; operador altera se quiser. | Pasta sensível → operador confirma. |
| Escolha de pattern interno | Claude pergunta | **Conselho decide se canon R1-R19 responde**. Ambíguo → operador. | Sempre escapável via `/council:explain`. |
| Decomposição de plano grande | Claude pergunta + apresenta opções | **Conselho propõe**, operador só confirma. Vetar subplano → pergunta. | Revisável antes de ExitPlanMode. |
| Decisão de stack | Operador decide | **Operador decide** (conselho só opina como contexto). | Sem mudança. |
| Decisão de produto | Operador decide | **Operador decide** (conselho não opina). | Sem mudança. |
| Aplicar feature global em projeto legado | Operador decide caso-a-caso | **Conselho gera PR-draft**, operador revisa antes de merge. | PR sempre review humano. |
| Bloquear plano em pre-mortem | Não existia | **Hook bloqueia ExitPlanMode** se ≥2 providers apontam mesmo risco crítico. | `PERCUS_PREMORTEM_OVERRIDE=1`. |
| Bloquear commit com mock detectado | Não existia | **Hook mock-scan bloqueia** (R3 Fase 6). | `MOCK-OK:` no commit message. |

**Regra geral:**
1. Decisões **reversíveis + baixo blast radius** → conselho age, operador notificado.
2. Decisões **irreversíveis ou alto blast radius** → conselho opina, operador decide.
3. **Tudo logado** em `.deepseek/council-log/<data>.jsonl` (auditável).

---

## Setup primeira vez

### Pré-requisitos

- `DEEPSEEK_API_KEY` no `.env` do projeto (já é padrão Fase 4+).
- `GROQ_API_KEY` no `.env` do projeto (novo na Fase 6 — obter free em https://console.groq.com).
- Plugin `percus-review` v6.0.0 instalado globalmente.

### Comandos

```powershell
# Verificar
Test-Path .env
Select-String -Path .env -Pattern '^(DEEPSEEK_API_KEY|GROQ_API_KEY)='

# Se faltar GROQ_API_KEY:
Add-Content -Path .env -Value "GROQ_API_KEY=gsk_<sua-chave>"
```

### Smoke test

```bash
/council:consult "Renomear coluna users.name para users.full_name. Faz sentido?"
```

Esperado: 3 outputs (DeepSeek + Cross-Claude + Llama) com síntese final. Custo total < $0.01.

---

## Anti-padrões

- ❌ Tratar conselho como decisor final → ele opina, operador decide em casos não-mecânicos.
- ❌ Pular o conselho pra "ir mais rápido" → defaulta a consultar quando elegível (custo/latência baixos).
- ❌ Confiar 100% em consenso 3/3 → conselho pode estar todo errado se prompt for ruim; revisão humana ainda é gate em pasta sensível.
- ❌ Hardcode de provider no código → sempre usar registry `providers/_registry.json` do plugin.

---

## Referências

- Plugin: `D:\Claud Automations\.claude-home\plugins\cache\percus-tools\percus-review\6.0.0\`
- Registry: `providers/_registry.json`
- Comandos: `commands/council-consult.md`, `commands/council-pre-mortem.md`, `commands/drift-detect.md`
- Hooks: `hooks/pre-plan-exit.{ps1,sh}`
- Log: `.deepseek/council-log/<data>.jsonl`
- Audit Fase 5 → Fase 6: `_AUDIT_2026-05-15.md`
- Plano: `D:\Claud Automations\.claude-home\plans\criei-a-pasta-d-claud-warm-patterson.md` (Eixo C)
