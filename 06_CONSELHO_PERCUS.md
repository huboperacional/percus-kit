---
tipo: arquitetura-de-conselho
prevalece-sobre: comandos/SETUP_REVIEW_ROUTING (Fase 6 supersede)
prevalecido-por: [01_REGRAS_INEGOCIAVEIS, CLAUDE.md do projeto]
quando-usar: ao configurar review/consult/pre-mortem/brainstorm com perspectivas múltiplas
leitura: 7 min
ultima-atualizacao: 2026-06-25
fase-introducao: Fase 6
---

# 06 — Conselho Percus (DeepSeek + Cross-Claude + Llama)

> **O que é:** sistema de 3 modelos consultivos operando em 5 modos. Substitui o esquema Fase 5 (2 modelos, 1 modo).
>
> **Não é mágica:** o conselho não decide negócio nem stack. Ele revisa, opina, sintetiza, sinaliza divergência. Decisões finais são do operador.

---

## Composição

| Membro | Provider | Modelo | Custo (1M in/out) | Especialidade |
|---|---|---|---|---|
| **DeepSeek** | DeepSeek API | `deepseek-chat` | $0.27 / $1.10 | Review cross-provider, código geral |
| **Cross-Claude** | Anthropic (subagent Sonnet) | `claude-sonnet-4-6` | incluso na assinatura Claude Code | Análise de design, raciocínio profundo |
| **Llama** | Groq API | `llama-3.3-70b-versatile` | Free 30 req/min, depois $0.59 / $0.79 | Resposta rápida (~500 tok/s), consultor inline |

**Custo agregado estimado:** $5/mês com volume Percus atual (vs $200-400/mês do esquema single-provider anterior).

**Diversidade de provider:** DeepSeek Inc + Anthropic + Meta (via Groq) — 3 origens diferentes, reduz viés single-provider.

---

## 5 modos operacionais

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

**Quando:** **SEMPRE que um plano fica pronto** (antes de `ExitPlanMode` / antes de começar a implementar),
independente do tamanho. O operador quer conselho em todo plano.

**Quem aciona:** o **próprio agente** roda `council-pre-mortem` sozinho ao finalizar o plano — sem pedir
permissão, sem depender de threshold. O hook `pre-plan-exit.{ps1,sh}` (>500 linhas) continua como **backstop**
(pega o caso do agente esquecer), mas o comportamento primário é o agente disparar **sempre**.

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

### Otimizações Groq (v6.14.0)

Duas otimizações isoladas exploram latência (~3×) e custo (~10×) do Groq-Llama na pipeline, sem mexer em criatividade (brainstorm segue Sonnet) nem em precisão de código (DeepSeek). Ambas opt-in / gated — **zero mudança visível por default**.

**Vetor B — Triagem de fact-check (Llama upstream do Sonnet).**
- `scripts/fact-check-triage.ps1`/`.sh`: classifica cada finding `[SEV: risco|bug]` como **PLAUSIVEL** (coerente, não precisa do Sonnet) ou **SUSPEITA** (duvidoso / exige ler código → escalar). Em dúvida → SUSPEITA.
- Integrado em `fact-check.ps1` via `$env:PERCUS_FACTCHECK_TRIAGE`:
  - ausente → **OFF** (default; Sonnet em tudo, comportamento histórico).
  - `1`/`shadow` → **dual-run**: roda Llama **e** Sonnet, loga concordância em `.deepseek/metrics/factcheck-triage.jsonl` (calibração ~30 dias). Output inalterado.
  - `gate` → Llama PLAUSIVEL **pula** o Sonnet (economia esperada 70-80% no item mais caro). Ativar só após a calibração mostrar ≥90% de concordância.
- **Sem promoção automática** shadow→gate — operador ativa `gate` manualmente após revisar as métricas.

**Vetor D — Tie-breaker Llama no conselho.**
- Quando exatamente 2 providers respondem com sucesso, o **groq-llama NÃO está entre eles** (ex: Cross-Claude falhou 400), E os 2 divergem em `premise_validity`, o orchestrator chama a Llama como 3º voto.
- Reportado como **"convergência 2/3 informal — tie-breaker fraco"** (`tie_breaker_invoked: true` no JSON), **não** como consenso. Operador decide.
- Custo desprezível (~$0.0001/call), latência ~1.6s. Conservador: sem sinal estruturado de divergência (premise_validity), não dispara.

**Descartados (consenso 2/2 do conselho):** Vetor A (brainstorm via Llama — Sonnet é melhor pra criatividade) e Vetor C (geração de código via Llama — DeepSeek é mais preciso na sintaxe).

Diferença pra Modo 2: Modo 2 reduz perguntas (consenso → não pergunta); Modo 4 enriquece perguntas (sempre pergunta, mas com 3 perspectivas anexadas).

### Modo 5 — Spec Analyze (validação de spec, pré-`[0]`)

**Quando:** **SEMPRE que uma `spec.md` fica pronta** (template `templates/spec.template.md`), antes dela
virar `[0]` no `PLANO.md`. O operador quer conselho em **toda** spec — não só nas "não-triviais". Preenche o
gap entre "escopo do projeto" (SCOPE_COUNCIL, dia 1) e "review do código" (Modo 1, pré-commit).

**Quem aciona:** o **próprio agente** roda `spec-analyze` sozinho ao finalizar a spec — sem pedir permissão.
(Gate `[S]` do `feature-flow`; comando manual equivalente: `/percus-review:spec-analyze <spec.md>`.)

**Como funciona:** o conselho roda em **modo analyze** — não opina sobre mérito, faz **detecção
estruturada** (estilo `/analyze` do spec-kit): FR testável? SC mensurável? ambiguidade? terminologia
consistente? edge case sem FR? **violação de constituição R1-R23/02_INFRA (CRITICAL)?** vazamento
WHAT→HOW? Saída = findings com severidade + `VEREDITO: PRONTA | AJUSTAR | BLOQUEADA`.

- **Custo proporcional:** 2 providers default (`deepseek,groq-llama`, ~$0.002); 3 (+cross-claude) só em
  domínio sensível (auth/pagamento/identidade/migrations) ou `--deep`.
- **Guardrail (R20):** findings CRITICAL passam pelo fact-check F3 antes de bloquear — o conselho não
  ratifica alegação não-verificada (anti-padrão Plexco Tasks 2026-05-18).
- **BLOQUEADA** → corrige a spec e re-roda; **PRONTA** → cola na §8 da spec e marca `[0]`.

Diferença pro Modo 1: Modo 1 revisa **diff de código** (pré-commit); Modo 5 revisa **spec** (pré-`[0]`,
antes de existir código).

---

## Mapeamento spec-kit ↔ Percus (adoção seletiva)

O método **Spec-Driven Development** do [spec-kit](https://github.com/github/spec-kit) tem 7 fases. O
canon adota **seletivamente** o front-end (specify/clarify/analyze) e mantém o back-end próprio
(`[0]→[5-T]`), que é mais granular que o `implement` deles:

| spec-kit | Percus (equivalente) | Status |
|---|---|---|
| `/constitution` | `01_REGRAS_INEGOCIAVEIS` + `02_INFRA_E_STACK_PERCUS` | Já temos (mais forte) |
| `/specify` | `templates/spec.template.md` (gate `[S]`) | **Novo (v6.19.0)** |
| `/clarify` | `/clarify` ≤5 perguntas via AskUserQuestion no `feature-flow` | **Novo (v6.19.0)** |
| `/analyze` | Conselho Modo 5 (`/percus-review:spec-analyze`) | **Novo (v6.19.0)** |
| `/plan` | `docs/PLANO.md` (o COMO; stack vive aqui, não na spec) | Já temos |
| `/tasks` | Quebra em features/frentes no PLANO | Já temos |
| `/implement` | Pipeline `[0]→[1-S]→[2-E]→[3-H]→[4-C]→[5-T]` | Já temos (mais granular) |
| `/analyze` (pós-impl) | Review Modo 1 (R11) + `state-drift-check` | Já temos |

**Não adotamos:** a estrutura `.specify/` nem os 7 comandos como CLI. Só o que preenche gap real.

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

- Plugin: `${env:PERCUS_CANON_DIR}\plugin\percus-review\` (fonte canônica; runtime usa o cache instalado, resolvido dinamicamente)
- Registry: `providers/_registry.json`
- Comandos: `commands/council-consult.md`, `commands/council-pre-mortem.md`, `commands/drift-detect.md`
- Hooks: `hooks/pre-plan-exit.{ps1,sh}`
- Log: `.deepseek/council-log/<data>.jsonl`
