---
tipo: indice-mestre
prevalece-sobre: [todos os outros arquivos desta pasta em caso de conflito de roteamento]
quando-usar: SEMPRE ao abrir qualquer projeto Percus (novo ou existente)
leitura: 3 min
ultima-atualizacao: 2026-04-29
---

# 00 — LEIA PRIMEIRO

> **Você é o agente.** Este é o único arquivo que você precisa abrir para saber o que ler depois.
> Nenhum outro documento é "obrigatório de cor" — todos são consultáveis. Mas a hierarquia abaixo é absoluta.

---

## Roteamento por situação

| Situação | Leia, nesta ordem |
|---|---|
| **Projeto NOVO greenfield** | `01_REGRAS_INEGOCIAVEIS.md` → `02_INFRA_E_STACK_PERCUS.md` → `checklists/CHECKLIST_INICIO_SESSAO.md` |
| **Sessão NOVA em projeto existente** | `checklists/CHECKLIST_INICIO_SESSAO.md` (literalmente os 5 passos) → ler `HANDOFF.md` do projeto → ler `docs/PLANO.md` do projeto |
| **Reorganizar/auditar projeto existente** | `comandos/REORGANIZAR_PROJETO.md` |
| **Migrar auth de projeto legado** | `comandos/MIGRAR_AUTH.md` |
| **Criar tela / componente / fluxo visual novo** | `comandos/DESIGN_WORKFLOW.md` (v0.dev + shadcn MCP — substitui Claude artifacts) |
| **Revisão visual de telas existentes** | `comandos/REVISAO_VISUAL.md` |
| **Adicionar tracking de atribuição** | `03_TRACKING_ATTRIBUITION.md` |
| **Implementar feature nova** | `checklists/CHECKLIST_FEATURE_NOVA.md` |
| **Decidir qual modelo executa qual task (Claude / DeepSeek / Cross-Claude)** | `04_MODEL_ROUTING.md` |
| **Encerrar sessão** | `checklists/CHECKLIST_ENCERRAR_SESSAO.md` |
| **Configurar revisor cross-provider (1ª vez no projeto)** | `comandos/SETUP_REVIEW_ROUTING.md` (instala plugin `@percus/review`, cria `AGENTS.md`) |
| **Configurar DeepSeek como implementador (1ª vez no projeto)** | `comandos/SETUP_DEEPSEEK.md` (valida `.env`, smoke test) |
| **Atualizar projeto legado pra Fase 4 (review+DeepSeek+design, migra Codex→Percus)** | `comandos/UPGRADE_PROJETO_FASE2.md` (consolidador) |
| **Auditar se Fase 4 está sendo usada (não só configurada)** | `comandos/HEALTHCHECK_FASE2.md` (3 níveis: config + uso histórico + teste comportamental) |

---

## Hierarquia em caso de conflito

Quando dois documentos divergirem, prevalece nesta ordem (do mais forte ao mais fraco):

1. **`CLAUDE.md` do projeto atual** (regras locais sempre vencem regras globais)
2. **`01_REGRAS_INEGOCIAVEIS.md`** (regras universais Percus)
3. **`02_INFRA_E_STACK_PERCUS.md`** (decisões técnicas universais)
4. **Demais documentos** (apoio operacional)

**Em caso de divergência detectada, pare e informe o usuário** — não tente resolver sozinho.

---

## Mapa de arquivos

```
_arquivos para iniciar qualquer projeto no claude code/
├── 00_LEIA_PRIMEIRO.md                  ← você está aqui
├── 01_REGRAS_INEGOCIAVEIS.md            ← regras universais (~150 linhas)
├── 02_INFRA_E_STACK_PERCUS.md           ← stack + VPS + auth + DB (~400 linhas)
├── 03_TRACKING_ATTRIBUITION.md          ← capturar UTMs/click IDs em forms
├── 04_MODEL_ROUTING.md                  ← Claude=arquiteto, DeepSeek=implementador, DeepSeek+Cross-Claude=revisores
│
├── checklists/                          ← passos curtos e literais
│   ├── CHECKLIST_INICIO_SESSAO.md       ← 5 passos antes de qualquer ação
│   ├── CHECKLIST_FEATURE_NOVA.md        ← do brainstorm ao [5-T]
│   └── CHECKLIST_ENCERRAR_SESSAO.md     ← HANDOFF + mock-audit + commit
│
├── templates/                           ← scaffolding pronto
│   ├── CLAUDE.template.md               ← contexto para Claude
│   ├── AGENTS.template.md               ← contexto para revisor cross-provider (DeepSeek + Cross-Claude)
│   ├── HANDOFF.template.md
│   ├── PLANO.template.md
│   ├── mock-audit.template.md
│   └── .gitignore.example               ← base com .deepseek/, secrets, etc
│
├── comandos/                            ← prompts prontos para colar
│   ├── REORGANIZAR_PROJETO.md
│   ├── MIGRAR_AUTH.md
│   ├── REVISAO_VISUAL.md                ← agora aponta pra v0.dev + shadcn (Fase 2)
│   ├── DESIGN_WORKFLOW.md               ← cria tela/componente novo (v0.dev + shadcn MCP)
│   ├── SETUP_REVIEW_ROUTING.md          ← instala plugin @percus/review + cria AGENTS.md (Fase 4)
│   ├── SETUP_CODEX_REVIEWER.md          ← DEPRECATED — referência histórica
│   ├── SETUP_DEEPSEEK.md                ← valida .env, smoke test do wrapper DeepSeek
│   ├── UPGRADE_PROJETO_FASE2.md         ← consolida review+DeepSeek+design e migra Codex→Percus
│   └── HEALTHCHECK_FASE2.md             ← audita se Fase 4 está SENDO USADA, não só configurada
│
├── scripts/                             ← workers e utilitários
│   ├── deepseek-impl.ps1                ← worker DeepSeek (PowerShell, Windows)
│   └── deepseek-impl.sh                 ← worker DeepSeek (Bash, Linux/Mac/WSL)
│
└── hooks/
    └── settings.json.example            ← hooks do Claude Code que forçam adesão
```

Tudo num lugar só — não há código auxiliar fora desta pasta. Claude orquestra DeepSeek lendo o playbook em `04_MODEL_ROUTING.md` e invocando o wrapper diretamente; sem subagents registrados no harness.

---

## Princípio inegociável de uso

Sempre que o `CHECKLIST_INICIO_SESSAO.md` listar algo como "obrigatório", **execute literalmente** — não interprete, não pule, não "deixa pra depois". Se não conseguir executar (faltou arquivo, faltou credencial), **pare e informe o usuário**, não improvise.

A grande causa de erros recorrentes é o agente "interpretar" regras imperativas como sugestões. Aqui não são. Os checklists são scripts, não diretrizes.
