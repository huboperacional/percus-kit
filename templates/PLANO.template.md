# Plano — {Nome do Projeto}

_Atualizado em: {YYYY-MM-DD}_
_Fonte da verdade do tracking. Atualize imediatamente após cada etapa concluída._

<!-- Opcional: se rodou SCOPE_COUNCIL.md no greenfield, adicionar bloco abaixo (apague se não rodou) -->
<!--
## Scope-Council aplicado em {YYYY-MM-DD}

Outputs em `docs/scope-council/`:
- `scope-draft.md` — análise solo Claude principal
- `scope-deepseek-review.md` — review cross-provider DeepSeek
- `scope-challenger.md` — adversário Sonnet subagent

Decisões adotadas vs draft inicial:
- {feature/decisão atendida da crítica X}
- {feature/decisão atendida da crítica Y}

Decisões mantidas (críticas ignoradas):
- {feature/decisão Z mantida apesar de crítica — motivo}
-->

---

## Legenda

**Tags de status (R2 do `01_REGRAS_INEGOCIAVEIS.md`):**

| Tag | Significado | Condição obrigatória |
|-----|-------------|----------------------|
| `[0]` | Planejada | — |
| `[1-S]` | Schema | Migration rodou, tabela existe (verificado com `\dt`) |
| `[2-E]` | Endpoint | Rota responde 2xx em curl/log |
| `[3-H]` | Hook | Frontend chama endpoint sem erro |
| `[4-C]` | Componente | Tela renderiza dado real do banco |
| `[5-T]` | ✅ Testado | Ciclo CRUD com F5: criar → F5 → editar → F5 → deletar → F5 |

**Marcações visuais (ortogonais à tag, podem acumular — vão ANTES da tag):**
- `🎨` = draft de design aprovado (v0.dev export, shadcn add aplicado, ou wireframe Excalidraw/Mermaid)
- `🎨?` = feature visual sem draft (BLOQUEADA em `[0]` até virar `🎨` — ver `comandos/DESIGN_WORKFLOW.md`)
- `🤖` = implementação delegada ao DeepSeek (R13) — adicione ao delegar via wrapper
- `✓` = Reviewer aprovou no marco (não no commit) — adicione invocando skill `percus-review:close-milestone` que roda `/percus-review:milestone-review --base <commit>` e marca aqui
- (sem ícone) = feature backend-only sem delegação nem marco fechado

**Regra de profundidade:** não inicie feature nova enquanto outra da mesma frente estiver entre `[1-S]` e `[3-H]`.

---

## Frente: {Nome da Frente 1}

- `[5-T]` ✓ ✅ {Feature completa, marco aprovado pelo revisor cross-provider} — {data}
- `[4-C]` 🎨 🤖 {Feature componente pronto, implementada via DeepSeek, falta CRUD}
- `[3-H]` 🎨 {Feature backend conectado} — próxima: terminar componente
- `[2-E]` 🤖 {Feature backend-only com endpoint, scaffolding via DeepSeek} — próxima: hook
- `[1-S]` {Feature schema pronto} — próxima: endpoint
- `[0]` 🎨? {Feature visual sem draft} — BLOQUEADA: gerar via v0.dev (tela) ou shadcn (componente). Ver `comandos/DESIGN_WORKFLOW.md`
- `[0]` {Feature backend-only não iniciada}

## Frente: {Nome da Frente 2}

- `[0]` {...}
- `[0]` {...}

## Frente: Revisão Visual (v0.dev + shadcn) — opcional

> Adicionar com `comandos/REVISAO_VISUAL.md` se aplicável.

- `[0]` 🎨!! {Tela urgente — visual defasado/inconsistente}
- `[0]` 🎨? {Tela a revisar quando tiver tempo}
- `[-]` {Tela que está OK — não entra no plano de revisão}

---

## Histórico (changelog do plano em si)

- **{YYYY-MM-DD}** — Criação. Frentes iniciais: {lista}.
- **{YYYY-MM-DD}** — Adicionada Frente {X} após brainstorming sobre {Y}.
- **{YYYY-MM-DD}** — Feature {Z} reclassificada de `[3-H]` para `[2-E]` após descobrir bug no endpoint.
