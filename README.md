# Percus Kit

> Conjunto canônico de regras, templates, comandos e tooling para projetos de software Percus (FastAPI + React + PostgreSQL + JWT cookie httpOnly).

**Estado atual:** Fase 7 — **versão canônica autoritativa em `CANON_VERSION.md`** (atualmente **v6.16.1**). Releases recentes: v6.16.1 (fix: council usava caminho fixo → prompt stale; agora temp único por invocação), v6.16.0 (integra Padrão Auth Percus v2 — 5 pilares — no canon com status de rollout), v6.15.0 (governança: R11 sem exceção pro kit + refresh de docs), v6.14.0 (otimização Groq no conselho: triagem de fact-check + tie-breaker), v6.12.0 (enforcement do tracking `[5-T]` via hooks `crud-evidence-warn` + `state-drift-check`), v6.11.0 (limpa cosmética + template `settings.json`), v6.10.0 (R22 alocação central de portas), v6.9.x (sync Painel), Sprint v6.8 (canonização do padrão auth), v6.7.x (hardening anti-hallucination). Fase 6 (conselho 3-membros) e Fase 4 (review cross-provider sem Codex/OpenAI) estáveis.

---

## O que é isto

Este repositório é a **fonte da verdade** das convenções Percus aplicadas em todos os projetos. Inclui:

- **Regras inegociáveis** (R1-R22) que valem em qualquer projeto Percus
- **Templates** prontos para `CLAUDE.md`, `AGENTS.md`, `HANDOFF.md`, `PLANO.md`, `mock-audit.md`
- **Comandos prontos** para colar no chat do Claude Code (setup, upgrade, healthcheck, design, refactor)
- **Plugin `@percus/review`** — conselho 3-membros (DeepSeek + Cross-Claude + Llama via Groq) para review/consult/pre-mortem/brainstorm + hooks de enforcement (substitui Codex CLI desde 2026-05-03)
- **Scripts** auxiliares (wrapper DeepSeek para implementação delegada R13, automações de review/conselho)

**Filosofia:** disciplina mecânica via regras + plugin + hooks. Não confiar em memória humana ou disciplina do agente.

---

## Por onde começar

### Sou um agente Claude Code abrindo um projeto Percus
1. Leia `00_LEIA_PRIMEIRO.md` (~3 min) — roteamento por situação
2. Siga a hierarquia de `01_REGRAS_INEGOCIAVEIS.md`
3. Aplique `checklists/CHECKLIST_INICIO_SESSAO.md` (5 passos obrigatórios)

### Quero atualizar um projeto em andamento
Cole no chat do Claude Code do projeto-alvo (use o `UPGRADE_PARA_FASE<N>` mais recente — hoje `UPGRADE_PARA_FASE7.md`; projetos muito antigos encadeiam a partir de `UPGRADE_PARA_FASE4.md`):
```
Aplique o upgrade do canon neste projeto seguindo `${env:PERCUS_CANON_DIR}\comandos\UPGRADE_PARA_FASE7.md`.

Comece pelo diagnóstico de estado. NÃO execute as mudanças ainda — só me mostre o resultado do diagnóstico e qual caminho será seguido. Aguarde minha confirmação antes de prosseguir.
```

### Quero iniciar projeto novo greenfield
Cole no chat do Claude Code do projeto-alvo:
```
Vou iniciar um projeto novo Percus. Leia ${env:PERCUS_CANON_DIR}\00_LEIA_PRIMEIRO.md e siga o roteamento "Projeto NOVO greenfield".
```

### Quero auditar a saúde de um projeto
Cole:
```
Faça healthcheck deste projeto, conforme `${env:PERCUS_CANON_DIR}\comandos\HEALTHCHECK_FASE2.md`.
```

---

## Estrutura de pastas

```
_Novo_Projeto/                       ← raiz do canon (canon + plugin = "percus-kit", versionados juntos)
│
├── 00_LEIA_PRIMEIRO.md              ← roteamento e índice mestre
├── 01_REGRAS_INEGOCIAVEIS.md        ← regras universais R1-R22
├── 02_INFRA_E_STACK_PERCUS.md       ← stack + VPS + auth + DB
├── 03_TRACKING_ATTRIBUITION.md      ← UTMs/click IDs em forms (R3)
├── 04_MODEL_ROUTING.md              ← Claude=arquiteto, DeepSeek=implementador, conselho revisor
├── 05_FEATURE_TRACKING.md           ← catalog-info.yaml + ADRs cross-projeto (R20)
├── 06_CONSELHO_PERCUS.md            ← conselho 3-membros (DeepSeek+Cross-Claude+Llama) · 4 modos
├── PADRAO_AUTH_SERVICE.md           ← padrão auth-service canônico (consolidado na Sprint v6.8)
├── AMBIENTE_LOCAL_OPERADOR.md       ← env vars padrão do operador (caches em D:\caches\)
├── CANON_VERSION.md                 ← versão autoritativa + changelog completo
├── .percus-version                  ← versão pura (consumida por hooks/scaffold)
│
├── checklists/                      ← passos curtos imperativos
│   └── inicio · encerrar · feature_nova · auth_novo_projeto · audience_nova
│
├── comandos/                        ← prompts prontos para colar (~19)
│   ├── UPGRADE_PARA_FASE{4,6,7}.md  ← upgrade encadeado de projetos em andamento
│   ├── SETUP_*.md                   ← review-routing · deepseek · catalog · claude-settings · nova-maquina
│   ├── DESIGN_WORKFLOW.md / REVISAO_VISUAL.md   ← UI (R10)
│   ├── MIGRAR_AUTH.md / REORGANIZAR_PROJETO.md
│   └── SETUP_CODEX_REVIEWER.md      ← DEPRECATED desde 2026-05-03
│
├── templates/                       ← scaffolding canônico
│   ├── CLAUDE / AGENTS / HANDOFF / PLANO / mock-audit / adr-0000 (.template.md)
│   ├── settings.template.json       ← .claude/settings.json canônico (v6.11.0)
│   ├── catalog-info.yaml.template · CHECKLIST_AUTH · MIGRATION_KIT_AUTH · .gitignore.example
│   └── login-ui/                    ← template React de tela de login (alinhado com @percus/auth)
│
├── scripts/                         ← automações (raiz do canon)
│   ├── deepseek-impl.{ps1,sh}       ← wrapper DeepSeek implementador (R13)
│   ├── percus-review-auto.{ps1,sh} · percus-milestone-review-auto.{ps1,sh}
│   └── analyze_council_spend.py · council-ab-validate.ps1
│
├── tools/                           ← scaffold-percus-project.{ps1,sh}
├── infra/                           ← approved-evolution-instances.yaml (allowlist instâncias WhatsApp)
│
├── plugin/percus-review/            ← plugin Claude Code @percus/review
│   ├── plugin.json
│   ├── commands/                    ← /review · /council-{consult,pre-mortem,brainstorm} · /drift-detect · /install-git-hooks · /version
│   ├── skills/                      ← feature-flow · security-audit · tracking-audit · cookie-audit · port-allocate · pages-scan · catalog-publish · delegate-impl · close-milestone
│   ├── scripts/                     ← review-router · council-orchestrator · council-tiebreaker · fact-check(-triage) · dedup-findings · *_audit.py
│   ├── hooks/                       ← ~12 hooks (.ps1/.sh/.cmd): pre-commit-check · crud-evidence-warn · state-drift-check · canon-version-check · external-action-guard · mock/auth/migration/types-pre-commit · pre-plan-exit · on-stop-check
│   ├── providers/                   ← deepseek · cross-claude · groq-llama (.ps1/.sh) + system-prompts
│   └── tests/                       ← suites Pester (123/123 verde em v6.14.0)
│
├── docs/
│   ├── superpowers/{specs,plans}/   ← design specs + planos versionados
│   ├── handoffs/                    ← handoffs de release (Painel · consumidores)
│   └── contracts/                   ← error-codes · redirect-reasons · migration V1→V2
│
├── hooks/
│   └── settings.json.example        ← exemplo legado (preferir templates/settings.template.json)
│
└── .claude-plugin/marketplace.json  ← manifesto do marketplace do plugin
```

---

## Histórico de fases

| Fase | Data | Estado | Marco |
|---|---|---|---|
| Fase 1 | 2026-04 | DEPRECATED | Codex como revisor |
| Fase 2 | 2026-05-02 | Histórico | DeepSeek implementador + Codex revisor |
| Fase 3 | 2026-05-02 | Histórico | Harmonização do kit + tooling |
| Fase 4 | 2026-05-03 | ESTÁVEL (main) | Plugin `@percus/review` (DeepSeek + Cross-Claude), Codex eliminado |
| Fase 5 | 2026-05-03 | Absorvida em main | Skills + hooks de adoção de superpowers — hoje integrados no plugin (`skills/` + `hooks/`) via Fase 6/7 |
| Fase 6 | 2026-05-15 | Histórico | Feature tracking cross-projeto + conselho 3-membros (DeepSeek + Cross-Claude + Llama via Groq) + ambiente local sanitizado |
| **Fase 7** | **2026-05-18 →** | **ATIVA — v6.14.0** (ver `CANON_VERSION.md`) | **v6.14.0 Groq (triagem fact-check + tie-breaker) · v6.12.0 enforcement `[5-T]` (hooks) · v6.11.0 limpa + `settings.json` · v6.10.0 R22 portas · v6.9.x Painel · Sprint v6.8 canonização auth · v6.7.x hardening anti-hallucination** |

**Docs Fase 6 (Sprint 1 do Eixo B concluído):**
- `05_FEATURE_TRACKING.md` — convenção catalog-info.yaml + ADRs cross-projeto.
- `06_CONSELHO_PERCUS.md` — arquitetura do conselho 3-membros + 4 modos.
- `AMBIENTE_LOCAL_OPERADOR.md` — env vars padrão pra caches em `D:\caches\`.
- `comandos/SETUP_CATALOG.md` — adotar feature catalog num projeto existente.
- `comandos/UPGRADE_PARA_FASE6.md` — upgrade Fase 4/5 → Fase 6.

---

## Plugin `@percus/review`

Conselho 3-membros obrigatório (R11) — 3 providers distintos reduzem viés single-provider:
- **DeepSeek API** (`deepseek-chat`) — review cross-provider, código geral; pre-commit padrão
- **Cross-Claude** (subagent Sonnet) — análise de design/raciocínio; quando a saída veio do próprio DeepSeek
- **Llama via Groq** (`llama-3.3-70b-versatile`) — consultor rápido inline + triagem de fact-check (v6.14.0)

Opera em **4 modos**: review (pre-commit/marco), consult, pre-mortem, brainstorm. Pasta sensível ou marco escala pra duplo/triplo. Arquitetura completa em `06_CONSELHO_PERCUS.md`.

**Custo agregado estimado:** ~$5/mês em uso normal (vs $200-400/mês com Codex anterior).

Setup: ver `comandos/SETUP_REVIEW_ROUTING.md`.

---

## Convenções deste repositório

- **Idioma:** documentação em português, código/scripts em inglês
- **Branches:** `main` = última fase estável; `fase<N>-<topic>` = trabalho em andamento; merge em main no fim de cada fase com tag `vN.0.0`
- **Specs:** versionadas em `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- **R11 no kit:** mudanças no kit seguem R11 como qualquer projeto (mesmo gate de review cross-provider) — **sem exceção** (a isenção, dead-letter, foi removida pós-v6.14.0). Disciplina adicional, aditiva ao review: plano explícito + revisão do usuário + checagem de refs mortas. Detalhes em `01_REGRAS_INEGOCIAVEIS.md` R11.

---

## Licença

Privado. Uso interno Percus.
