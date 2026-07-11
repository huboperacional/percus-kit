---
tipo: referencia-rapida
quando-usar: agente Claude (ou operador) precisa saber como invocar um item do plugin percus-review — skill ou slash command
leitura: 2 min
ultima-atualizacao: 2026-07-11
---

# Skills vs Slash Commands — referência rápida

> **Problema recorrente:** docs/HANDOFFs mandando "rode `/percus-review:checkpoint`" (ou
> `/percus-review:feature-flow`, `/percus-review:consult-knowledge`…). **Isso não existe.** `checkpoint`,
> `feature-flow`, `consult-knowledge`… são **skills**, não commands — **não têm slash**. Só o inventário de
> **commands** abaixo é invocável por `/`. Este doc fecha a confusão.

---

## A regra de ouro

| Tipo | Quem dispara | Como |
|---|---|---|
| **Slash command** | **User** digita `/` | `/percus-review:<nome>` no chat. O plugin executa o handler (wrapper PS/sh). O autocomplete mostra. |
| **Skill** | **Agente** (Claude) | O agente invoca via `Skill` tool quando a tarefa matcha a `description:` do `SKILL.md`. O **user aciona pedindo em linguagem natural** ("faça o checkpoint", "consulte o que já sabemos sobre X") — **nunca** por slash. |

⚠️ **Skill NÃO tem slash confiável.** Mesmo que algum autocomplete mostre `/<algo>:checkpoint`, o namespace
de skill é **instável**: numa instalação real ele apareceu como `6.28.0:checkpoint` (a **versão** como
namespace, não `percus-review:`). Ou seja: `/percus-review:checkpoint` falha, e `/<versão>:checkpoint` é
frágil e muda a cada bump. A forma **robusta e portável** de disparar uma skill é **linguagem natural** —
descreva a intenção e deixe o agente invocar.

**Heurística:** arquivo em `plugin/percus-review/commands/*.md` → **slash command**. Diretório em
`plugin/percus-review/skills/<nome>/SKILL.md` → **skill** (linguagem natural / auto-trigger).

---

## Inventário (plugin `percus-review` — versão corrente em `${env:PERCUS_CANON_DIR}/CANON_VERSION.md`)

### Slash commands — user digita `/percus-review:<nome>`

| Command | O que faz |
|---|---|
| `/percus-review:review` | Router auto (DeepSeek / Cross-Claude / dual conforme o diff). Gate R11 pré-commit. |
| `/percus-review:milestone-review` | Review de marco completo (sempre dual). Usa `--base <commit>`. |
| `/percus-review:deepseek-review` | Força DeepSeek-only. |
| `/percus-review:cross-claude-review` | Força Cross-Claude-only (subagent Sonnet). |
| `/percus-review:spec-analyze` | Conselho Modo 5 sobre um `spec.md` (gate `[S]`). |
| `/percus-review:install-git-hooks` | Instala git hook nativo (Layer 2 anti-bypass). |
| `/percus-review:version` | Mostra a versão do canon/plugin. |

**Conselho 3-membros — namespace próprio `council:` (⚠️ confirmar no autocomplete):** os 4 commands do
conselho declaram `name: council:<x>` no frontmatter (não `percus-review:`), então a forma **pretendida** é
`/council:consult`, `/council:pre-mortem`, `/council:brainstorm` e `/council:drift-detect` — que é o uso
majoritário no canon. **Porém** o namespace efetivo depende de como o harness resolve um `name:` com
dois-pontos dentro de um plugin; se o autocomplete não reconhecer `/council:*`, o fallback é
`/percus-review:council-*`. Digite `/council:` no chat e veja se lista, pra cravar qual funciona nesta versão.

### Skills — o agente invoca (user pede em linguagem natural, sem slash)

| Skill | User aciona dizendo… (o agente invoca via Skill tool) |
|---|---|
| `checkpoint` | "faça o checkpoint", "vamos fechar este milestone", ou auto ao fim de marco / antes de `/clear`/`/compact`. Sincroniza PLANO+HANDOFF+mock-audit, commita com review (R11), emite prompt de retomada. |
| `close-milestone` | "Fase X feita", "fechar Eixo Y". |
| `feature-flow` | "iniciar feature/bugfix novo". Orquestra o workflow R1→R13. |
| `consult-knowledge` | "o que já sabemos sobre X?", ou antes de debugar (R23). |
| `delegate-impl` | task mecânica + plano explícito + ≤3 arquivos → delega pra DeepSeek (R13). |
| `auth-consumer` | "auditar como este projeto consome o auth-service" (bridge lê `#rt=`). |
| `tracking-audit` | auditoria de tracking attribution (R2 — cookies/ref). |
| `security-audit` | auditoria das regras R14-R19 (auth, observability, rate limit). |
| `cookie-audit` | subset de tracking — só cookies + SameSite + Secure (R7). |
| `pages-scan` | sync das rotas do projeto com o Painel (`/admin/pages/ingest`). |
| `port-allocate` | aloca a porta do projeto no range canônico. |
| `catalog-publish` | publica `catalog-info.yaml` no Painel. |

> **Regra:** só os itens da 1ª tabela têm slash. Qualquer `/percus-review:<skill>` da 2ª tabela
> (ex.: `/percus-review:checkpoint`) **não existe** — é skill, aciona-se por linguagem natural.

---

## Como o agente decide invocar uma skill

1. O agente lê a `description:` da skill (frontmatter do `SKILL.md`).
2. Compara com a intenção do user (mesmo que descrita em linguagem natural).
3. Se matcha (mesmo ~30% de chance), o agente **invoca via `Skill` tool** — sem pedir pro user colar slash.
4. A skill executa.

**Não há slash command pra disparar skill.** Tentar `/percus-review:feature-flow` ou
`/percus-review:checkpoint` no chat **não funciona** (não é command; e o namespace de skill nem é
`percus-review`). O caminho é: user descreve a intenção → agente invoca.

---

## Os 3 erros mais comuns de agentes

### ❌ Erro 1: mandar o user disparar uma skill como slash command

**Exemplo genérico:** "Aguardando você rodar `/percus-review:checkpoint`." ou "rode `/percus-review:feature-flow`."

**Correto:** o próprio agente invoca `checkpoint`/`feature-flow` via `Skill` tool quando vê a intenção
(fim de milestone; iniciar feature). O user só descreve — o agente decide e executa.

### ❌ Erro 2: confundir wrapper de implementador com revisor

**Exemplo genérico:** "Posso chamar `deepseek-impl.ps1` direto pra revisão de scope?"

**Correto:** `deepseek-impl.ps1` é o **implementador R13**, não revisor. Pra revisão use `deepseek-review.ps1`.
Pra revisar markdown de scope/plano, use o conselho (`council-orchestrator.ps1 -Mode pre-mortem`).

### ❌ Erro 3: pedir pro user rodar o auto-trigger de review manualmente

**Exemplo genérico:** "Pode rodar `/percus-review:review` rapidinho? Hook tá stale."

**Correto:** desde Fase 5 (v5.1.0+), **o próprio agente** dispara
`pwsh -File "${env:PERCUS_CANON_DIR}/scripts/percus-review-auto.ps1"` antes de cada `git commit` que ele
executa. Detalhes em `CLAUDE.template.md`, seção "Workflow de commit do agente (auto-trigger)".

---

## Checklist mental antes de escrever "rode `/X:Y`" no chat

1. **`/X:Y` existe como command?** Olha em `plugin/percus-review/commands/` (e `.claude-plugin/marketplace.json`).
   Se não está lá, é **skill** (ou inexistente) — não peça slash.
2. **Se é skill, eu (agente) consigo invocar via `Skill` tool?** Sim — sempre. O user não cola nada.
3. **Se é o review auto:** eu (agente) consigo rodar o wrapper via Bash tool? Sim. Não passo pro user.

Se qualquer resposta for "sim, eu posso fazer", **faça**. Não jogue pro user.

---

## Referências

- Plugin (source): `${env:PERCUS_CANON_DIR}/plugin/percus-review/` (`commands/` = slash · `skills/<nome>/SKILL.md` = skill).
- Marketplace canônico: `.claude-plugin/marketplace.json` (declara os commands; skills são auto-discovered de `skills/`).
- Wrapper auto-trigger de review: `scripts/percus-review-auto.ps1` (roda no cwd do projeto-alvo).
- Conselho 3-membros: `scripts/council-orchestrator.ps1` (`-Mode consult|pre-mortem|review`).
- Troubleshoot desta classe: `conhecimento/COMO_RESOLVER.md#skill-nao-e-slash`.
