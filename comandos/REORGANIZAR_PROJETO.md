---
tipo: comando-pronto
quando-usar: projeto  existente mas ainda não tem CLAUDE.md / HANDOFF.md / docs/PLANO.md no padrão atual
nao-toca-codigo: true
leitura: 5 min
ultima-atualizacao: 2026-04-25
---

# Reorganizar Projeto — Atualização de Arquivos de Acompanhamento

> Cole este prompt no projeto atual. O agente vai ler o projeto como ele está hoje
> e criar/atualizar os arquivos de acompanhamento sem tocar em nenhum código.
>
> **Templates de referência:** `D:\Claud Automations\_Novo_Projeto\templates\` (CLAUDE / HANDOFF / PLANO / mock-audit).

---

## O que você vai fazer

Você vai ler o projeto atual e criar ou atualizar apenas estes arquivos:

1. `CLAUDE.md` — contexto do projeto para o agente
2. `HANDOFF.md` — estado atual + status de cada feature
3. `docs/PLANO.md` — lista de features com status `[0]→[5-T]`
4. `docs/mock-audit.md` — quais telas usam dados reais vs mock

**Não toque em código de negócio. Não mova arquivos. Não reescreva nada que já funciona.**

---

## Passo 1 — Leia o projeto como ele está

Antes de criar qualquer arquivo:

- Leia a estrutura de diretórios completa
- Leia os arquivos de rotas do backend (identifique endpoints existentes)
- Leia os hooks/services do frontend (identifique o que chama API vs o que usa mock)
- Leia os componentes principais (identifique o que renderiza dado real vs hardcoded)
- Cheque o banco: quais tabelas/models existem?

---

## Passo 2 — Classifique cada feature com seu status real

Para cada tela ou funcionalidade encontrada, atribua um status:

| Tag | O que significa | Condição obrigatória |
|-----|-----------------|----------------------|
| `[0]` | Planejado, não iniciado | — |
| `[1-S]` | Schema/tabela existe no banco | Migration ou model confirmado |
| `[2-E]` | Endpoint existe | Rota encontrada no backend |
| `[3-H]` | Hook chama o endpoint | Frontend conectado ao backend |
| `[4-C]` | Componente usa dado real | Sem mock-data, sem array hardcoded |
| `[5-T]` | Ciclo CRUD testado | Só se você testou nesta sessão |

> Se não testou o ciclo criar → F5 → editar → F5 → deletar → F5 nesta sessão, não marque `[5-T]`. Deixe em `[4-C]` no máximo.

---

## Passo 3 — Crie `docs/PLANO.md`

```markdown
# Plano — {Nome do Projeto}
_Atualizado em: {data}_

## Frente: {Nome da área}

- [5-T] {Feature com ciclo CRUD confirmado}
- [4-C] {Feature com componente real, ciclo não testado}
- [3-H] {Feature com hook conectado, componente incompleto}
- [2-E] {Feature com endpoint, sem hook}
- [1-S] {Feature com schema, sem endpoint}
- [0]   {Feature planejada, não iniciada}
```

---

## Passo 4 — Crie `docs/mock-audit.md`

Use grep para encontrar mocks antes de preencher:

```bash
# Mocks no frontend
grep -r "mock-data\|mockData\|MOCK_\|fakeData" src --include="*.ts" --include="*.tsx" -l

# Toasts que mentem
grep -r "toast.success\|toast(" src --include="*.ts" --include="*.tsx" -n | grep -i "salvo\|saved\|sucesso"
```

```markdown
# Mock Audit — {projeto}
_Atualizado em: {data}_

| Tela / Feature | Status | O que falta para conectar ao backend | Esforço |
|----------------|--------|--------------------------------------|---------|
| {Tela}         | ✅ real | —                                    | —       |
| {Tela}         | ⚠️ mock | Endpoint POST + hook                 | {X}h    |
| {Tela}         | ❌ só UI | Schema + endpoint + hook             | {X}h    |
```

---

## Passo 5 — Crie ou atualize `CLAUDE.md`, `AGENTS.md` (e `GEMINI.md` se espelho-3)

**Antes de mexer:** rode `Test-Path GEMINI.md`. Se retornar true, o projeto mantém convenção de espelhar regras nos 3 arquivos (CLAUDE.md / AGENTS.md / GEMINI.md). Aplique todas as mudanças nos 3 — não quebre invariante interna do projeto, mesmo que o usuário não use Gemini ativamente.

Se já existe `CLAUDE.md`, `AGENTS.md` (ou `GEMINI.md` no caso espelho-3), **mescle** os triggers da Fase 2 (não sobrescreva):

- **R10** — design via v0.dev + shadcn MCP (Claude artifacts vetado pra produção). Apontar pra `comandos/DESIGN_WORKFLOW.md`
- **R11** — review cross-provider obrigatório em **dois** momentos: antes de commit (`/percus:review`) E ao concluir cada marco (`/percus:milestone-review --base <commit>`). Apontar pra `comandos/SETUP_REVIEW_ROUTING.md` se não estiver configurado
- **R13** — routing de modelos: Claude=arquiteto, DeepSeek=implementador, DeepSeek+Cross-Claude=revisores. Apontar pra `04_MODEL_ROUTING.md`

Use `templates/CLAUDE.template.md` e `templates/AGENTS.template.md` como referência do estado canônico. Se conflito de seção, mantenha o conteúdo específico do projeto + adicione o trecho da Fase 2 abaixo.

Se não existe nenhum dos dois, crie do zero seguindo o template:

```markdown
# {Nome do Projeto} — CLAUDE.md

## O que é este projeto
{2-3 linhas descrevendo o propósito}

## Stack
- Frontend: {framework}
- Backend: {framework}
- Banco: {banco}
- Serviços externos: {lista}

## Estrutura relevante
{Onde ficam rotas, componentes, hooks, models}

## Como rodar localmente
{Comandos}

## Critério de "pronto" para qualquer feature
Ciclo CRUD testado: criar → F5 → editar → F5 → deletar → F5, tudo persistindo no banco.
Build passando não conta. Tela abrindo não conta.

## Tracking de features
Ver `docs/PLANO.md` — atualizar imediatamente após cada etapa concluída.
Tags: [0] → [1-S] → [2-E] → [3-H] → [4-C] → [5-T]

## Regra de mock
Tela com dado mock = banner MODO DEMO visível + toast diz "salvo localmente", nunca "salvo".

## Routing de modelos (R13)
Tasks de implementação mecânica devem ser delegadas ao DeepSeek via `scripts/deepseek-impl.{ps1,sh}` — playbook em `_Novo_Projeto/04_MODEL_ROUTING.md` seção "Como delegar". Saída sempre revisada por Claude e por Codex (R11) antes de commit.

## Design (R10)
Tela/componente novo: usar v0.dev (telas) ou shadcn MCP (componentes isolados). Detalhes em `_Novo_Projeto/comandos/DESIGN_WORKFLOW.md`. Claude artifacts vetado pra produção.

## Review cross-provider (R11)
Obrigatório em **dois** momentos: antes de cada commit (`/percus:review`) + ao concluir cada marco (`/percus:milestone-review --base <commit>`). Setup em `_Novo_Projeto/comandos/SETUP_REVIEW_ROUTING.md`.
```

---

## Passo 6 — Crie ou atualize `HANDOFF.md`

```markdown
# Handoff — {Nome do Projeto}
_Atualizado em: {data}_

## Estado atual
- **Funcionando end-to-end:** [features com [5-T]]
- **UI pronta mas sem ciclo testado:** [features com [4-C]]
- **Backend parcial:** [features com [2-E] ou [3-H]]
- **Não iniciadas:** [features com [0] ou [1-S]]
- **Próximo passo imediato:** [o que fazer primeiro ao retomar]

## Status de Features

> Fonte da verdade: docs/PLANO.md — se divergir daqui, o plano prevalece.
> Tags: `[0]` planejado · `[1-S]` schema · `[2-E]` endpoint · `[3-H]` hook · `[4-C]` componente · `[5-T]` ✅ testado

| Frente | Feature | Status | Próxima etapa |
|--------|---------|--------|---------------|
| {Frente} | {Feature} | `[5-T]` ✅ | — |
| {Frente} | {Feature} | `[4-C]` | Testar ciclo CRUD |
| {Frente} | {Feature} | `[2-E]` | Criar hook + componente |

## Infraestrutura
- **DB:** `{nome_do_banco}`
- **Backend rodando em:** `{url ou porta}`
- **Frontend rodando em:** `{url ou porta}`

## Problemas conhecidos
- [Problema] → [Workaround em uso]
```

---

## Passo 7 — Adote o workflow de Superpowers nas próximas features

Adicione ao `CLAUDE.md` (na seção de workflow) o fluxo padrão para features novas:

```markdown
## Workflow obrigatório para features novas

1. `superpowers:brainstorming` — 5-10min antes de qualquer código
2. `superpowers:writing-plans` — se a feature for multi-step
3. `superpowers:dispatching-parallel-agents` — backend + frontend em paralelo quando independentes
4. `superpowers:test-driven-development` — vitest antes do endpoint
5. `superpowers:requesting-code-review` — em background antes do commit
6. `superpowers:verification-before-completion` — antes de marcar `[5-T]`

Debug: `superpowers:systematic-debugging` para qualquer bug ou teste quebrado.
Exploração de código desconhecido: agente `Explore`.
```

### Playwright MCP (se o projeto tem frontend)

Se ainda não estiver configurado:
```bash
claude mcp add playwright npx '@playwright/mcp@latest'
```

Documentar no `CLAUDE.md` que o Playwright MCP deve ser usado para:
- Automatizar o ciclo CRUD do critério `[5-T]`
- Smoke tests pós-deploy
- Verificação visual de componentes novos

---

## Passo 8 — Reporte o que foi feito

Ao terminar, liste:

```
ARQUIVOS ATUALIZADOS — {Nome do Projeto}

✅ CLAUDE.md        — criado / atualizado
✅ HANDOFF.md       — criado / atualizado
✅ docs/PLANO.md    — criado com X features classificadas
✅ docs/mock-audit.md — X telas reais, X mocks, X só UI

Resumo de status:
  [5-T] X features
  [4-C] X features
  [3-H] X features
  [2-E] X features
  [1-S] X features
  [0]   X features

Próxima ação recomendada:
  → {Feature mais próxima de [5-T] — o que falta para completá-la}
```
