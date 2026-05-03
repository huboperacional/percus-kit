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
| `superpowers:requesting-code-review` | Antes de commitar diff > 500 linhas | Cobertura redundante ao `/percus:review` |
| `superpowers:verification-before-completion` | Antes de marcar `[5-T]` | Evita falso positivo de "feito" |

## Tier 2 — Otimizações (não obrigatórias)

| Skill | Quando vale | Ganho |
|---|---|---|
| `superpowers:using-git-worktrees` | Refactor grande / experiment / projeto > 50 arquivos pra upgrade | Contexto físico isolado, descarte limpo |
| `superpowers:executing-plans` | Plano com 5+ marcos sequenciais | Cada marco = sessão separada com checkpoint |
| `superpowers:dispatching-parallel-agents` | Backend + frontend independentes | Paralelismo manual (vs subagent-driven que é por task) |
| `superpowers:writing-skills` | Padrão Percus repetido em 3+ projetos | Vira skill nova, instala uma vez |

## Skills internas Percus

| Skill | Disparar quando |
|---|---|
| `percus:feature-flow` | Toda feature ou bugfix não-trivial — orquestra R1→R13 |
| `percus:close-milestone` | Antes de marcar ✓ no PLANO (fechar marco) |

## Antipatterns

- ❌ Pular brainstorming "porque já sei o que fazer" — feature simples vira retrabalho
- ❌ Implementar plano com 3+ tasks serialmente sem subagent-driven — desperdiça contexto/tempo
- ❌ "Vou usar worktree depois" — depois é nunca

## Referências

- Plugin instalado em `~/.claude/plugins/superpowers-dev/`
- R9 do canon: `D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md`
