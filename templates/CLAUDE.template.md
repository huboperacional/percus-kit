# {Nome do Projeto} — CLAUDE.md

> Substitua {placeholders} ao copiar para um projeto novo.
> Apague esta linha de instrução depois.

## Versão do canon Percus adotada

**Versão:** ver `.percus-version` na raiz deste projeto.

Esse arquivo (uma linha com semver, ex: `6.3.0`) declara qual versão do canon Percus este projeto adotou no último upgrade. Agente Claude — pra saber quais regras valem (R1–R19 da v6.x; R14–R18 não existem em v4.x; auto-trigger review é v5.1.0+; conselho 3-membros é v6.1.0+; model router automático é v6.3.0+).

**Protocolo no primeiro turno de cada sessão** (não negociável):
1. Rodar `Get-Content .percus-version` (ou `cat .percus-version` em bash) — capturar versão do projeto.
2. Rodar `Get-Content "${env:PERCUS_CANON_DIR}\CANON_VERSION.md" -TotalCount 5` — capturar versão canônica atual.
3. Declarar em voz alta no primeiro turno: "Projeto na versão X.Y.Z, canônica atual A.B.C — alinhado/divergente."
4. Se divergente, sugerir ao usuário rodar `comandos/REORGANIZAR_PROJETO.md` (umbrella — atualiza o projeto pro canon atual) antes de qualquer trabalho não-trivial.

Sem essa declaração no primeiro turno, agente pode aplicar regras erradas (ex: tentar usar `/council:pre-mortem` num projeto v5.0.x onde nem existe).

## O que é este projeto

{2-3 linhas descrevendo propósito, público, problema que resolve}

## Stack

- **Frontend:** {Vite + React 19 + TS / Next.js 15 + RSC}
- **Backend:** FastAPI 0.115+ (Python 3.11+)
- **Banco:** PostgreSQL 17 — database `{slug_projeto}_v1`
- **Cache/OTP:** Redis 7.4 — namespace `{slug_projeto}:*`
- **Auth:** auth-service Percus centralizado (lib `percus-auth` valida JWT EdDSA local) **ou** sidecar FastAPI próprio com OTP+JWT HS256 (estado Transição até auth-service v1). Ver `02_INFRA_E_STACK_PERCUS.md` Seção 2 pros 3 estados de adoção.
- **Deploy:** Docker Swarm via Portainer no VPS `161.97.129.138`
- **Domínio:** `{subdominio}.huboperacional.com.br` (ou domínio próprio)

## Estrutura relevante

```
projeto/
├── services/
│   └── api/                    # FastAPI backend
│       ├── app/
│       │   ├── core/           # config, security, utils
│       │   ├── modules/        # auth/, {dominio}/
│       │   ├── models/         # SQLAlchemy
│       │   └── main.py
│       └── alembic/
├── web/                        # frontend (ou frontend/ se Next)
│   └── src/
│       ├── app/                # rotas
│       ├── components/
│       ├── hooks/
│       └── lib/
├── execution/                  # scripts Python determinísticos
├── docs/
│   ├── PLANO.md                # tracking [0]→[5-T] (fonte da verdade)
│   ├── mock-audit.md           # estado real de cada tela
│   └── superpowers/specs/      # specs de features grandes
├── HANDOFF.md
└── .env
```

## Como rodar localmente

```bash
# Backend
cd services/api
uv sync
uvicorn app.main:app --reload

# Frontend
cd web
npm install
npm run dev

# DB local (se aplicável)
docker compose up -d postgres redis
alembic upgrade head
```

## Critério de "pronto" para qualquer feature

Ciclo CRUD testado: **criar → F5 → editar → F5 → deletar → F5**, tudo persistindo no banco.
Build passando não conta. Tela abrindo não conta. Endpoint OK no Postman não conta.

Detalhes em `01_REGRAS_INEGOCIAVEIS.md` R1 (na pasta `_Novo_Projeto`).

## Tracking de features

Fonte da verdade: `docs/PLANO.md`. **Atualizar imediatamente após cada etapa.**

Tags: `[0]` planejado · `[1-S]` schema · `[2-E]` endpoint · `[3-H]` hook · `[4-C]` componente · `[5-T]` ✅ ciclo testado.

Marcações visuais (acumulam, ortogonais à tag):
- `🎨` draft de design aprovado (v0.dev/shadcn) · `🎨?` precisa draft antes de sair de `[0]`
- `🤖` implementação delegada ao DeepSeek (R13)
- `✓` revisor cross-provider aprovou no marco (R11) — adicionar quando review de marco passou

## Regra de mock

Tela com dado mock = banner `MODO DEMO` visível + toast diz `"salvo localmente"`, nunca apenas `"salvo"`.

Auditoria em `docs/mock-audit.md`, atualizada toda sessão com frontend.

## Workflow obrigatório para features novas

Ver `checklists/CHECKLIST_FEATURE_NOVA.md` (na pasta `_Novo_Projeto`).

Resumo: brainstorming → plano → TDD → execução vertical [0]→[5-T] → `/percus-review:review` → commit.

## Review cross-provider (R11)

Review é obrigatório em **dois momentos:**
1. Antes de cada commit que muda código — `/percus-review:review` (router auto)
2. Ao concluir cada marco de plano — `/percus-review:milestone-review --base <commit-inicio-marco>` (DeepSeek + Cross-Claude duplo)

**Matriz de roteamento automática (`/percus-review:review`):**

| Cenário | Reviewer |
|---|---|
| Pre-commit rotineiro | DeepSeek (`deepseek-chat`) |
| Pre-commit em pasta sensível (`auth/`, `payment*/`, `migrations/`, `.env*`) | DeepSeek + Cross-Claude duplo |
| Pre-commit de saída DeepSeek (commit com trailer `Co-implemented-by: deepseek-v4`) | Cross-Claude apenas (Sonnet subagent) |
| Marco | DeepSeek + Cross-Claude duplo |

Override manual: `/percus-review:deepseek-review`, `/percus-review:cross-claude-review`.

**Tratamento de findings:**
1. Bug ou regressão → corrigir antes de commitar
2. Violação de regra Percus → corrigir OU declarar em voz alta por que ignora
3. Preferência de estilo → ignorar é OK, declarar em voz alta

Sem review rodado nos últimos 5 minutos antes do commit = não pode commitar.
Sem milestone-review do escopo do marco = marco não está concluído.

**Após review aprovar o marco:** adicionar marcação `✓` nas features afetadas em `docs/PLANO.md` e `HANDOFF.md`.

### Workflow de commit do agente (auto-trigger v5.1.0+)

Agente Claude Code AUTO-DISPARA review antes de qualquer `git commit` que ele mesmo for executar via Bash tool. Não pede pro usuário colar slash command.

**Sequência ao commitar:**

1. **ANTES de `git commit`** que toca código, rodar via Bash tool:
   ```
   pwsh -NoProfile -ExecutionPolicy Bypass -File "${env:PERCUS_CANON_DIR}\scripts\percus-review-auto.ps1"
   ```
   (ou `.sh` em Unix; passe `-Base <ref>` se for review de escopo)

2. **Ler findings DeepSeek** retornados pelo wrapper. Tratar críticos (corrigir antes do commit).

3. **Se aparecer marker `__PERCUS_NEEDS_CROSS_CLAUDE__`** no stderr do wrapper:
   - Significa que a decisão do router foi `cross-claude` ou `dual` (pasta sensível, marco, ou commit veio de DeepSeek).
   - Dispatch Sonnet subagent IMEDIATAMENTE via Agent tool (`subagent_type: "general-purpose"`) com prompt R11 cross-claude-review (revisar `git diff` vs AGENTS.md).
   - Salvar output do subagent em `.deepseek/reviews/<timestamp>-cross-claude.jsonl` para satisfazer o hook (`.deepseek/reviews/` é gitignored).

4. **Apresentar consolidado** (DeepSeek findings + Cross-Claude findings se aplicável) ao usuário. Declarar em voz alta findings ignorados e o porquê.

5. **`git commit`** — hooks Layer 1 (PreToolUse) e Layer 2 (git nativo) aprovam por TTL do review fresco.

**Ao fechar marco:** mesmo padrão, mas com wrapper de marco:
```
pwsh -File "${env:PERCUS_CANON_DIR}\scripts\percus-milestone-review-auto.ps1" -Base <commit-inicio-marco>
```
Marco é SEMPRE dual — wrapper sempre emite marker `__PERCUS_NEEDS_CROSS_CLAUDE__`, agente sempre dispatcha Sonnet adicional.

**Caso especial — usuário commitando manualmente no terminal:** Layer 2 (git hook nativo) bloqueia se não houver review fresco. Usuário roda `/percus-review:review` no chat manualmente nesse caso. Auto-trigger é só do agente, não do humano.

**Skills vs slash commands do plugin** (leitura obrigatória antes de mencionar `/algo:coisa` pro user): `${env:PERCUS_CANON_DIR}\comandos\SKILLS_VS_COMMANDS.md`. Resumo: slash commands são digitados pelo user. Skills são auto-trigger pelo agente via `Skill` tool — **não existem** como slash command. Se você (agente) está prestes a pedir pro user "rodar `/percus-review:feature-flow`", `/percus-review:tracking-audit`, ou qualquer outro nome listado em `plugin/percus-review/skills/`, **PARE** — invoque você mesmo via `Skill` tool.

Setup primeira vez: `${env:PERCUS_CANON_DIR}\comandos\SETUP_REVIEW_ROUTING.md`.
Regras que o revisor usa: `AGENTS.md` (irmão deste arquivo, na raiz do projeto).

## Routing de modelos (R13)

Implementação mecânica delegada ao DeepSeek V4 via wrapper `${env:PERCUS_CANON_DIR}\scripts\deepseek-impl.{ps1,sh}`. Saída é tratada como rascunho — sempre revisada por Claude (R1–R12) e revisor cross-provider (R11) antes de virar commit.

**Marker obrigatório:** ao aplicar saída DeepSeek (`-Apply`), commit message deve terminar com:
```
Co-implemented-by: deepseek-v4
```
O router de R11 detecta esse trailer e roteia revisão pra Cross-Claude (não DeepSeek auto-revisão).

**Quando delegar (TODOS os critérios):**
- Plano explícito em markdown, com arquivos-alvo nomeados
- Sem decisão arquitetural pendente
- Não toca pasta sensível (`auth/`, `payment*/`, `migrations/`, `credentials/`, `.env*`)
- Cabe em ≤3 arquivos OU é padrão repetido em N arquivos

**Quando NÃO delegar:** brainstorm, decisão arquitetural, debug não-trivial, pasta sensível, tarefas visuais (segue R10/`DESIGN_WORKFLOW.md`).

**Após delegação aplicada:** marcar a feature no PLANO/HANDOFF com `🤖`. Playbook completo em `${env:PERCUS_CANON_DIR}\04_MODEL_ROUTING.md` seção "Como delegar".

## Design (R10)

Tela ou componente novo: NÃO usar Claude artifacts (vetado pra produção pela R10).
- Componente isolado → shadcn MCP (`npx shadcn@latest add <comp>`)
- Tela/fluxo novo → v0.dev (browser, créditos Vercel)
- Diagrama → Excalidraw / Mermaid em markdown

Workflow detalhado: `${env:PERCUS_CANON_DIR}\comandos\DESIGN_WORKFLOW.md`.

## Workflow obrigatório ao iniciar sessão

Ver `checklists/CHECKLIST_INICIO_SESSAO.md`. Os 5 passos não são opcionais.

## Workflow obrigatório ao encerrar sessão

Ver `checklists/CHECKLIST_ENCERRAR_SESSAO.md`. HANDOFF + PLANO + mock-audit atualizados antes de qualquer commit.

## Decisões arquiteturais deste projeto

- {Decisão 1: ex. multi-tenant via column `tenant_id` em todas as tabelas}
- {Decisão 2: ex. forward de eventos pro PMT após signup, ver `03_TRACKING_ATTRIBUITION.md`}
- {...}

## Coding conventions

- Funções e variáveis: `camelCase` (TS) / `snake_case` (Python)
- Classes: `PascalCase`
- Constantes: `UPPER_SNAKE_CASE`
- Arquivos Python: `snake_case.py`
- Comentários no código em **inglês**, documentação de projeto em **português**

## Referências externas

- **Regras universais Percus:** `${env:PERCUS_CANON_DIR}\01_REGRAS_INEGOCIAVEIS.md`
- **Stack e infra Percus:** `${env:PERCUS_CANON_DIR}\02_INFRA_E_STACK_PERCUS.md`
- **Tracking de atribuição:** `${env:PERCUS_CANON_DIR}\03_TRACKING_ATTRIBUITION.md` (se projeto tem forms)
- **Auth canônico:** `D:\Claud Automations\Claude Financas NEW\familia-api\app\modules\auth\` (read-only)
- **Setup Review Routing (cross-provider):** `${env:PERCUS_CANON_DIR}\comandos\SETUP_REVIEW_ROUTING.md`
- **Setup DeepSeek (R13):** `${env:PERCUS_CANON_DIR}\comandos\SETUP_DEEPSEEK.md`
- **Routing de modelos:** `${env:PERCUS_CANON_DIR}\04_MODEL_ROUTING.md`
- **Design workflow (R10):** `${env:PERCUS_CANON_DIR}\comandos\DESIGN_WORKFLOW.md`
- **Atualizar projeto pro canon atual (umbrella):** `${env:PERCUS_CANON_DIR}\comandos\REORGANIZAR_PROJETO.md`
- **AGENTS.md (irmão deste arquivo):** regras espelhadas para o revisor cross-provider — manter sincronizado com este CLAUDE.md
