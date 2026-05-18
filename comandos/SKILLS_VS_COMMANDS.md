---
tipo: referencia-rapida
quando-usar: agente Claude precisa decidir como invocar um item do plugin (skill ou command)
leitura: 2 min
ultima-atualizacao: 2026-05-17
---

# Skills vs Slash Commands — referência rápida

> **Problema recorrente:** agentes pedindo pro user colar `/percus-review:feature-flow`, `/percus-review:tracking-audit`, etc. Isso **não existe**. São skills, não commands. Este doc fecha a confusão.

---

## A regra de ouro

| Tipo | Quem invoca | Como |
|---|---|---|
| **Slash command** | **User** | Digita `/nome` no chat. Plugin executa o handler do command (geralmente um wrapper PS/sh). |
| **Skill** | **Agente** (Claude) | Invoca via `Skill` tool **automaticamente** quando a tarefa do user matcha a `description:` do SKILL.md. User nunca digita. |

**Heurística rápida:** se está em `plugin/percus-review/commands/*.md` → é slash command. Se está em `plugin/percus-review/skills/<nome>/SKILL.md` → é skill (auto-trigger pelo agente).

---

## Inventário do plugin `percus-review` (versão atual em `${env:PERCUS_CANON_DIR}/CANON_VERSION.md`)

### Slash commands (user digita `/`)

| Slash command | O que faz |
|---|---|
| `/percus-review:review` | Roda router auto (DeepSeek/Cross-Claude/dual conforme diff). Layer 1 anti-bypass. |
| `/percus-review:deepseek-review` | Force DeepSeek-only. |
| `/percus-review:cross-claude-review` | Force Cross-Claude-only (Sonnet subagent). |
| `/percus-review:milestone-review` | Review de marco completo. Sempre dual. |
| `/percus-review:install-git-hooks` | Instala git hook nativo (Layer 2 anti-bypass). |
| `/council:consult` | Conselho 3-membros pra decisão reversível (`Mode consult`). |
| `/council:pre-mortem` | Conselho 3-membros pra plano antes de `ExitPlanMode` (`Mode pre-mortem`). |
| `/council:brainstorm` | Conselho 3-membros pra brainstorming aberto. |
| `/council:drift-detect` | Detecta drift do plano. |
| `/catalog-publish` | Publica `catalog-info.yaml` no Painel. |

### Skills (agente invoca via Skill tool)

| Skill | Quando o agente deve invocar (resumo) |
|---|---|
| `feature-flow` | User pediu pra iniciar feature/bugfix novo. Orquestra R1→R13 workflow. |
| `close-milestone` | User declarou marco/fase concluída ("Fase X feita", "fechar Eixo Y"). |
| `delegate-impl` | Task mecânica + plano explícito + ≤3 arquivos → delegar pra DeepSeek (R13). |
| `tracking-audit` | Auditoria de tracking attribution (R2 cookies/ref). |
| `security-audit` | Auditoria das regras R14-R19 (auth, observability, rate limit). |
| `cookie-audit` | Subset de tracking — só cookies + SameSite + Secure (R7). |
| `pages-scan` | Sync de rotas do projeto com Painel `/admin/pages/ingest`. |
| `catalog-publish` | Publica catalog-info.yaml (também existe como command duplicado). |

---

## Como o agente decide invocar uma skill

1. Agente lê a description da skill no SKILL.md (frontmatter).
2. Compara com a intenção do user.
3. Se matcha (mesmo que 30% de chance), agente **invoca via Skill tool** sem pedir confirmação.
4. Skill executa.

**Não há slash command pra disparar skill.** Tentar `/feature-flow` ou `/percus-review:feature-flow` no chat **não funciona** — o autocomplete não mostra, e mesmo se digitado, retorna "command not found".

---

## Os 3 erros mais comuns de agentes

### ❌ Erro 1: Agente pede pro user disparar skill como slash command

**Exemplo genérico:** "Aguardando você disparar `/percus-review:feature-flow` pra iniciar Sprint X."

**Correto:** o próprio agente invoca `feature-flow` via Skill tool quando vê intenção de "iniciar sprint/feature". User só descreveu a tarefa — agente decide.

### ❌ Erro 2: Agente confunde wrapper de implementador com revisor

**Exemplo genérico:** "Posso chamar `deepseek-impl.ps1` direto com system prompt customizado pra revisão de scope."

**Correto:** `deepseek-impl.ps1` é o **implementador R13**, não revisor. Pra revisão use `deepseek-review.ps1`. Melhor ainda: pra revisar markdown de scope/plano, use `council-orchestrator.ps1 -Mode pre-mortem` (3 providers em paralelo).

### ❌ Erro 3: Agente pede pro user rodar auto-trigger manualmente

**Exemplo genérico:** "Pode rodar `/percus-review:review` rapidinho? Hook tá stale."

**Correto:** desde Fase 5 v5.1.0+, **o próprio agente** dispara `pwsh -File "${env:PERCUS_CANON_DIR}\scripts\percus-review-auto.ps1"` antes de cada `git commit` que ele executa. Detalhes em `CLAUDE.template.md` seção "Workflow de commit do agente (auto-trigger v5.1.0+)".

---

## Checklist mental antes de mencionar `/algo:coisa`

Antes do agente escrever "rode `/X:Y`" no chat pro user:

1. **`/X:Y` existe como command?** Olha em `plugin/percus-review/commands/` e `.claude-plugin/marketplace.json`. Se não, é skill ou inexistente.
2. **Se é skill, eu (agente) consigo invocar via Skill tool?** Sim — sempre. User não precisa colar nada.
3. **Se é auto-trigger (review):** eu (agente) consigo rodar o wrapper via Bash tool? Sim. Não passa responsabilidade pro user.

Se a resposta de qualquer um for "sim, eu posso fazer", **faça**. Não jogue pro user.

---

## Referências

- Plugin: `${env:PERCUS_CANON_DIR}/plugin/percus-review/`
- Marketplace canônico: `.claude-plugin/marketplace.json` (lista commands) + skills auto-discovered de `skills/<nome>/SKILL.md`
- Wrapper auto-trigger: `scripts/percus-review-auto.ps1` (cwd do projeto-alvo)
- Conselho 3-membros: `scripts/council-orchestrator.ps1` (`-Mode consult|pre-mortem|review`)
