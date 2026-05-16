# Percus Kit

> Conjunto canônico de regras, templates, comandos e tooling para projetos de software Percus (FastAPI + React + PostgreSQL + JWT cookie httpOnly).

**Estado atual:** Fase 6 em construção (feature tracking cross-projeto + conselho 3-membros + ambiente local sanitizado) · Fase 5 ativa (skills + hooks superpowers) · Fase 4 estável (review cross-provider sem Codex/OpenAI).

---

## O que é isto

Este repositório é a **fonte da verdade** das convenções Percus aplicadas em todos os projetos. Inclui:

- **Regras inegociáveis** (R1-R13) que valem em qualquer projeto Percus
- **Templates** prontos para `CLAUDE.md`, `AGENTS.md`, `HANDOFF.md`, `PLANO.md`, `mock-audit.md`
- **Comandos prontos** para colar no chat do Claude Code (setup, upgrade, healthcheck, design, refactor)
- **Plugin `@percus/review`** — review cross-provider via DeepSeek + Cross-Claude (substitui Codex CLI desde 2026-05-03)
- **Scripts** auxiliares (DeepSeek wrapper para implementação delegada R13)

**Filosofia:** disciplina mecânica via regras + plugin + hooks. Não confiar em memória humana ou disciplina do agente.

---

## Por onde começar

### Sou um agente Claude Code abrindo um projeto Percus
1. Leia `00_LEIA_PRIMEIRO.md` (~3 min) — roteamento por situação
2. Siga a hierarquia de `01_REGRAS_INEGOCIAVEIS.md`
3. Aplique `checklists/CHECKLIST_INICIO_SESSAO.md` (5 passos obrigatórios)

### Quero atualizar um projeto em andamento para Fase 4
Cole no chat do Claude Code do projeto-alvo:
```
Aplique o upgrade Fase 4 neste projeto seguindo `D:\Claud Automations\_Novo_Projeto\comandos\UPGRADE_PARA_FASE4.md`.

Comece pelo Passo 0 (diagnóstico de estado). NÃO execute Passos 1-3 ainda — só me mostre o resultado do diagnóstico e qual caminho (A/B/C) será seguido. Aguarde minha confirmação antes de prosseguir.
```

### Quero iniciar projeto novo greenfield
Cole no chat do Claude Code do projeto-alvo:
```
Vou iniciar um projeto novo Percus. Leia D:\Claud Automations\_Novo_Projeto\00_LEIA_PRIMEIRO.md e siga o roteamento "Projeto NOVO greenfield".
```

### Quero auditar saúde da Fase 4 num projeto
Cole:
```
Faça healthcheck Fase 4 deste projeto, conforme `D:\Claud Automations\_Novo_Projeto\comandos\HEALTHCHECK_FASE2.md`.
```

---

## Estrutura de pastas

```
_Novo_Projeto/
├── 00_LEIA_PRIMEIRO.md              ← roteamento e índice mestre
├── 01_REGRAS_INEGOCIAVEIS.md        ← regras universais R1-R13
├── 02_INFRA_E_STACK_PERCUS.md       ← stack + VPS + auth + DB
├── 03_TRACKING_ATTRIBUITION.md      ← UTMs/click IDs em forms
├── 04_MODEL_ROUTING.md              ← Claude=arquiteto, DeepSeek=implementador, multi-revisor
│
├── checklists/                      ← passos curtos imperativos
│   ├── CHECKLIST_INICIO_SESSAO.md
│   ├── CHECKLIST_FEATURE_NOVA.md
│   └── CHECKLIST_ENCERRAR_SESSAO.md
│
├── comandos/                        ← prompts prontos para colar
│   ├── UPGRADE_PARA_FASE4.md        ← entrada principal para projetos em andamento
│   ├── SETUP_REVIEW_ROUTING.md      ← instala plugin @percus/review (Fase 4)
│   ├── SETUP_DEEPSEEK.md            ← configura DeepSeek implementador
│   ├── DESIGN_WORKFLOW.md           ← v0.dev + shadcn MCP (R10)
│   ├── REVISAO_VISUAL.md            ← auditoria visual de telas
│   ├── REORGANIZAR_PROJETO.md       ← arrumar projeto desorganizado
│   ├── MIGRAR_AUTH.md               ← legado → padrão Percus
│   ├── UPGRADE_PROJETO_FASE2.md     ← upgrade detalhado (delegado por UPGRADE_PARA_FASE4)
│   ├── HEALTHCHECK_FASE2.md         ← auditoria de uso real (3 níveis)
│   ├── USANDO_SUPERPOWERS.md        ← guia rápido de skills (Fase 5, em construção)
│   └── SETUP_CODEX_REVIEWER.md      ← DEPRECATED desde 2026-05-03
│
├── templates/                       ← scaffolding canônico
│   ├── CLAUDE.template.md
│   ├── AGENTS.template.md
│   ├── HANDOFF.template.md
│   ├── PLANO.template.md
│   ├── mock-audit.template.md
│   └── .gitignore.example
│
├── scripts/                         ← workers e utilitários
│   ├── deepseek-impl.ps1            ← wrapper DeepSeek implementador (Windows)
│   └── deepseek-impl.sh             ← wrapper DeepSeek implementador (Linux/Mac/WSL)
│
├── plugin/                          ← plugins Claude Code
│   └── percus-review/               ← @percus/review (Fase 4): commands + scripts + (Fase 5: skills + hooks)
│
├── docs/
│   └── superpowers/specs/           ← design specs versionadas
│
└── hooks/
    └── settings.json.example        ← hooks Claude Code (em revisão na Fase 5)
```

---

## Histórico de fases

| Fase | Data | Estado | Marco |
|---|---|---|---|
| Fase 1 | 2026-04 | DEPRECATED | Codex como revisor |
| Fase 2 | 2026-05-02 | Histórico | DeepSeek implementador + Codex revisor |
| Fase 3 | 2026-05-02 | Histórico | Harmonização do kit + tooling |
| Fase 4 | 2026-05-03 | ESTÁVEL (main) | Plugin `@percus/review` (DeepSeek + Cross-Claude), Codex eliminado |
| Fase 5 | 2026-05-03 | Estável (branch `fase5-superpowers-adoption`) | Skills + hooks para forçar adoção de superpowers |
| **Fase 6** | **2026-05-15** | **EM CONSTRUÇÃO** | **Feature tracking cross-projeto + conselho 3-membros (DeepSeek + Cross-Claude + Llama via Groq) + ambiente local sanitizado** |

**Docs Fase 6 (Sprint 1 do Eixo B concluído):**
- `_AUDIT_2026-05-15.md` — auditoria R1-R19 com decisão por regra (hook/skill/doc).
- `05_FEATURE_TRACKING.md` — convenção catalog-info.yaml + ADRs cross-projeto.
- `06_CONSELHO_PERCUS.md` — arquitetura do conselho 3-membros + 4 modos.
- `AMBIENTE_LOCAL_OPERADOR.md` — env vars padrão pra caches em `D:\caches\`.
- `comandos/SETUP_CATALOG.md` — adotar feature catalog num projeto existente.
- `comandos/UPGRADE_PARA_FASE6.md` — upgrade Fase 4/5 → Fase 6.

---

## Plugin `@percus/review`

Review cross-provider obrigatório (R11) via:
- **DeepSeek API** (cross-provider real, não-Anthropic) — pre-commit padrão
- **Cross-Claude subagent** (Sonnet) — quando saída veio do próprio DeepSeek
- **Duplo** (DeepSeek + Cross-Claude) — pre-commit em pasta sensível e marco

**Custo agregado esperado:** $2-5/mês total em uso normal (vs $200-400/mês com Codex anterior).

Setup: ver `comandos/SETUP_REVIEW_ROUTING.md`.

---

## Convenções deste repositório

- **Idioma:** documentação em português, código/scripts em inglês
- **Branches:** `main` = última fase estável; `fase<N>-<topic>` = trabalho em andamento; merge em main no fim de cada fase com tag `vN.0.0`
- **Specs:** versionadas em `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- **Exceção R11:** mudanças no kit não exigem `/percus-review:review` formal (kit é convenção, não código de produção). Auditoria por revisão humana + cross-Claude é suficiente. Detalhes em `01_REGRAS_INEGOCIAVEIS.md` R11 seção "Exceção estrutural".

---

## Licença

Privado. Uso interno Percus.
