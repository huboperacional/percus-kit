---
tipo: guia-rapido
quando-usar: consulta de skills superpowers a serem usadas em projetos Percus
leitura: 2 min
ultima-atualizacao: 2026-05-03
---

# Usando Superpowers em Percus

> Skills do plugin `superpowers` carregam contexto e orquestram fluxos. Usar bem corta tokens, tempo e drift. Plugin já está instalado a nível de usuário.

## Tier 1 — Obrigatórias (R9)

| Skill | Disparar quando | Ganho |
|---|---|---|
| `superpowers:brainstorming` | Feature não-trivial, antes de qualquer código | Evita retrabalho de premissa errada |
| `superpowers:writing-plans` | Multi-step com 3+ arquivos a tocar | Plano salvo + revisado, executável depois |
| `superpowers:subagent-driven-development` | Plano com 3+ tasks independentes | -60% contexto principal, paralelismo |
| `superpowers:test-driven-development` | Endpoint novo / função pura nova | Testes antes do código (R1) |
| `superpowers:systematic-debugging` | Bug ou teste quebrado | Causa raiz, não workaround |
| `superpowers:requesting-code-review` | Antes de commitar diff > 500 linhas | Cobertura redundante ao `/percus-review:review` |
| `superpowers:verification-before-completion` | Antes de marcar `[5-T]` | Evita falso positivo de "feito" |

## Tier 2 — Otimizações (não obrigatórias)

| Skill | Quando vale | Ganho |
|---|---|---|
| `superpowers:using-git-worktrees` | Refactor grande / experiment / projeto > 50 arquivos pra upgrade | Contexto físico isolado, descarte limpo |
| `superpowers:executing-plans` | Plano com 5+ marcos sequenciais | Cada marco = sessão separada com checkpoint |
| `superpowers:dispatching-parallel-agents` | Backend + frontend independentes | Paralelismo manual (vs subagent-driven que é por task) |
| `superpowers:writing-skills` | Padrão Percus repetido em 3+ projetos | Vira skill nova, instala uma vez |

## Skills internas Percus

### Fase 4/5 (existentes)

| Skill | Disparar quando |
|---|---|
| `percus-review:feature-flow` | Toda feature ou bugfix não-trivial — orquestra R1→R19 |
| `percus-review:close-milestone` | Antes de marcar ✓ no PLANO (fechar marco) |

### Fase 6+ (NOVAS — após bump pra plugin v6.0.0)

| Skill | Disparar quando | O que entrega |
|---|---|---|
| `percus-review:catalog-publish` | Auto no on-stop quando `catalog-info.yaml` muda | Push pro Painel de Gestão (`/admin/catalog/ingest`) |
| `percus-review:pages-scan` | Auto no pre-commit/on-stop | Extrai rotas FastAPI/Next.js/HTML estático e pusha pro Painel |
| `percus-review:tracking-audit` | PRs que tocam form/lead/conversion | Valida 15 campos canônicos (R2) |
| `percus-review:cookie-audit` | PRs em pasta auth | Valida flags httpOnly/Secure/SameSite (R7) |
| `percus-review:delegate-impl` | Boilerplate > 50 linhas | Aciona DeepSeek + auto-adiciona trailer `Co-implemented-by` (R9/R13) |
| `percus-review:security-audit` | Auditoria opt-in de pasta auth | Checklist guiado por R14/R15/R16/R17/R18/R19 |
| **Conselho expandido (3-membros)** | | |
| `council:consult` | Pré-`AskUserQuestion` em decisão design/naming/pattern | 3 perspectivas + síntese (reduz fricção) |
| `council:pre-mortem` | Plano > 500 linhas, antes de ExitPlanMode | Risco crítico × probabilidade (bloqueia se 2+ apontam mesmo risco) |
| `council:brainstorm` | Sessão `superpowers:brainstorming` (opt-in) | Conselho opina junto a cada `AskUserQuestion` do Claude |
| `council:drift-detect` | Investigar divergência cross-projeto de feature | Lê catalog-info.yaml + ADRs + commits, lista divergências |

Detalhes completos: `D:\Claud Automations\_Novo_Projeto\06_CONSELHO_PERCUS.md`.

## Antipatterns

- ❌ Pular brainstorming "porque já sei o que fazer" — feature simples vira retrabalho
- ❌ Implementar plano com 3+ tasks serialmente sem subagent-driven — desperdiça contexto/tempo
- ❌ "Vou usar worktree depois" — depois é nunca

## Referências

- Plugin instalado em `~/.claude/plugins/superpowers-dev/`
- R9 do canon: `D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md`
