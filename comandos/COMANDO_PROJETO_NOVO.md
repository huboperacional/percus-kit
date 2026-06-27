---
tipo: comando-pronto-para-colar
quando-usar: começar projeto Percus greenfield do zero
nao-toca-codigo: true
leitura: 1 min · execução típica: 30-45 min
ultima-atualizacao: 2026-06-25
fase-destino: 7+ (versão canônica atual em CANON_VERSION.md)
---

# Comando — Começar Projeto Novo Percus (greenfield)

> **Pré-requisitos antes de colar:**
> 1. Máquina já tem bootstrap Percus completo: `${env:PERCUS_CANON_DIR}` apontando pro canon, API keys do kit em User-scope env vars, plugin `percus-review` instalado. Se não: rode `${env:PERCUS_CANON_DIR}/comandos/SETUP_NOVA_MAQUINA.md` primeiro.
> 2. Pasta vazia do projeto criada (`mkdir <nome-projeto>; cd <nome-projeto>; git init`).
> 3. Repo do projeto-alvo aberto no Claude Code.

---

## Cole isto no chat do Claude Code do projeto-alvo

```
Vou iniciar um projeto novo Percus.

PROTOCOLO DE 1o TURNO (obrigatorio):
1. Le `.percus-version` da raiz se existir (provavelmente ausente — projeto novo).
2. Le `${env:PERCUS_CANON_DIR}/CANON_VERSION.md` primeiras 5 linhas pra versao canonica atual.
3. Declara: "Projeto novo (sem .percus-version ainda). Canonica atual: X.Y.Z. Vou seguir greenfield Fase 6."

Premissas (confirme antes de comecar):
- `${env:PERCUS_CANON_DIR}` aponta pro canon Percus clonado.
- API keys do kit no User-scope env vars (DeepSeek, Groq, Anthropic, Painel, Catalog). Confirmar com:
  @('PERCUS_CANON_DIR','DEEPSEEK_API_KEY','GROQ_API_KEY','ANTHROPIC_API_KEY','PAINEL_API_URL','CATALOG_INGEST_KEY') | ForEach-Object {
      $v = [Environment]::GetEnvironmentVariable($_, 'User')
      "$_ : $(if ($v) { 'OK' } else { 'MISSING' })"
  }
  Se alguma MISSING, instruir setup via `${env:PERCUS_CANON_DIR}/AMBIENTE_LOCAL_OPERADOR.md` e PARAR.
- Plugin percus-review instalado na versao canonica atual.

FLUXO GREENFIELD:

1. Le `${env:PERCUS_CANON_DIR}/00_LEIA_PRIMEIRO.md` e segue roteamento "Projeto NOVO greenfield":
   - Ler `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md` (R1-R19, kit Fase 6).
   - Ler `${env:PERCUS_CANON_DIR}/02_INFRA_E_STACK_PERCUS.md` (stack, VPS, auth, DB).
   - Rodar `${env:PERCUS_CANON_DIR}/checklists/CHECKLIST_INICIO_SESSAO.md` (5 passos).

2. Usar templates em `${env:PERCUS_CANON_DIR}/templates/` pra criar:
   - `CLAUDE.md` (de `CLAUDE.template.md`)
   - `AGENTS.md` slim (de `AGENTS.template.md`, ~4-5 KB cross-provider)
   - `HANDOFF.md` (de `HANDOFF.template.md`)
   - `docs/PLANO.md` (de `PLANO.template.md`)
   - `docs/mock-audit.md` (de `mock-audit.template.md`)
   - `.gitignore` (de `.gitignore.example`, com `.deepseek/` e `.codex/`)
   - `.percus-version` (de `.percus-version.template`, copia versao canonica atual)
   - `catalog-info.yaml` (de `catalog-info.yaml.template`)
   - `docs/legal/TERMS_PRIVACY.md` (ver passo 2.6 — gerado do LEGAL_MASTER.md)

2.6. Gerar `docs/legal/TERMS_PRIVACY.md` (documentação legal obrigatória do projeto):
   - Leia `${env:PERCUS_CANON_DIR}/docs/legal/LEGAL_MASTER.md`
   - Crie `docs/legal/TERMS_PRIVACY.md` para este projeto:
     1. Mantenha as 19 cláusulas dos Termos e a Política de Privacidade intactos (PT + EN)
     2. No Apêndice A: remova todos os outros projetos; deixe APENAS a linha deste produto
     3. No Apêndice B: remova sub-processadores que este projeto não utiliza
     4. Remova o Apêndice C inteiro (é específico do Micro Investors)
     5. Atualize o nome do produto na introdução e o campo "Last updated"
   - Não reescreva, não invente cláusulas, não resuma. Só filtre o que não pertence a este projeto.
   - Se o projeto ainda não consta no Apêndice A do LEGAL_MASTER.md, adicionar lá primeiro antes de gerar a versão filtrada.

2.5. Alocar PERCUS_PORT_BASE (R22 — registro central de portas locais):
   - Roda 1x: `python "${env:PERCUS_CANON_DIR}/plugin/percus-review/scripts/port_allocate.py" --slug <slug> --name "<Nome Bonito>"`
   - Stdout retorna `PERCUS_PORT_BASE=NNNN`; cache grava em `.percus-ports.json` (commitar).
   - Adicionar `PERCUS_PORT_BASE=NNNN` ao `.env.example` e `.env` do projeto.
   - Convencao de offsets (frontend +0, backend +1, etc): ver 02_INFRA secao 5.5 ou skill `percus-review:port-allocate`.
   - Se Painel offline: fallback deterministico entra automatico; reconciliar quando voltar.

2.7. Inicializar estrutura de skills, recipes e personas do projeto (padrão gmp-cli):
   - Ler `${env:PERCUS_CANON_DIR}/comandos/SETUP_PROJECT_SKILLS.md` pra entender a estrutura.
   - Rodar Passo 0 (diagnóstico): identificar domínios, workflows compostos e papéis de agente.
   - Criar `skills/`, `skills/recipes/`, `skills/personas/` com ao menos 1 de cada tipo.
   - Templates em: `${env:PERCUS_CANON_DIR}/templates/project-skill.template.md`, `project-recipe.template.md`, `project-persona.template.md`
   - Registrar no `CLAUDE.md` do projeto (seção "Skills locais").
   - Mínimo viável: 1 skill de domínio + 1 recipe (ex: recipe-nova-feature) + 1 persona (ex: persona-feature-implementor).
   - PULA somente se projeto é trivial (<2 semanas de trabalho) OU ainda não tem domínio técnico definido.

3. Apos templates criados, rodar `${env:PERCUS_CANON_DIR}/comandos/SCOPE_COUNCIL.md` (gate de scope dia 1):
   - 3 etapas: Claude principal solo -> conselho 3-membros pre-mortem paralelo -> sintese humana
   - ~25 min, ~$0.005
   - PULA somente se projeto trivial (<1 mes de trabalho dedicado, stack ja decidida por restricao externa).

4. Setup auth (R7 — auth-service Percus):
   - Auth-service em prod em `https://auth.huboperacional.com.br` (Fase 7 v6.8.0+).
   - Rodar o scaffold mecanico (1 comando, idempotente):
     pwsh "${env:PERCUS_CANON_DIR}/tools/scaffold-percus-project.ps1" -ProjectPath "$PWD" -AudienceFallback <slug-kebab-case>
     (ou `bash "${env:PERCUS_CANON_DIR}/tools/scaffold-percus-project.sh" --project-path . --audience-fallback <slug-kebab-case>` em Unix.)
   - Depois abrir `CHECKLIST_AUTH.md` (gerado pelo script) e completar os passos humanos: criar audience + branding na UI do auth-service, smoke E2E.
   - VETADO em projeto novo: GoTrue, Supabase Auth, NextAuth, magic-link proprio, senha sem 2FA, refresh JWT stateless. Ver R7 em 01_REGRAS_INEGOCIAVEIS.md.
   - Detalhes completos: secao "Setup auth (R7)" abaixo deste comando.

5. Validacao final:
   - `cat .percus-version` mostra versao canonica.
   - `/percus-review:review` num diff de teste retorna 3 outputs.
   - `/council:consult "Pergunta teste"` retorna 3 providers.

Premissas operacionais:
- R5 ativo: confirma antes de qualquer commit, criacao de DB/role, primeiro deploy, ou operacao paga.
- Auto-trigger review (v5.1.0+): voce mesmo (agente) dispara `pwsh -File "${env:PERCUS_CANON_DIR}/scripts/percus-review-auto.ps1"` antes de cada commit que voce executa. NUNCA pede pro user colar /percus-review:review.
- Skills vs commands: leia `${env:PERCUS_CANON_DIR}/comandos/SKILLS_VS_COMMANDS.md` antes de mencionar `/algo:coisa`. Skills (feature-flow, tracking-audit, etc) sao auto-trigger via Skill tool — NAO existem como slash command. Invoque voce mesmo.

Nao toque em codigo de negocio neste turno. So setup de ferramentas, configs, regras, templates.
```

---

## Setup auth (R7 — auth-service Percus)

Auth-service em prod em `https://auth.huboperacional.com.br` (Fase 7 v6.8.0+).

### 4.1 Scaffold mecânico (1 comando)

```pwsh
pwsh "$env:PERCUS_CANON_DIR/tools/scaffold-percus-project.ps1" `
    -ProjectPath "$PWD" `
    -AudienceFallback <slug-kebab-case>
```

(ou `bash tools/scaffold-percus-project.sh --project-path . --audience-fallback <slug-kebab-case>` em Unix.)

Idempotente. Copia `templates/login-ui/` → `src/components/auth/`, gera `.env.local`, instala `percus-auth >= 0.4.0`, cria `CHECKLIST_AUTH.md`.

### 4.2 Checklist humano (depois do scaffold)

Abrir `CHECKLIST_AUTH.md` no projeto (gerado pelo script) e completar:

- [ ] **Audience** — criar em `https://auth.huboperacional.com.br/admin/audiences/new` (slug **kebab-case** — R7), preencher `origins` com prod + staging + preview deploys
- [ ] **Branding** — `PUT /admin/audiences/{slug}/branding` (exige step-up TOTP):
  - `product_name`, `logo_url`, `palette: { primary, accent }`, `copy.helper_text` (opcional), `support_contact_url`
- [ ] **Smoke E2E** — `/login` renderiza com product_name correto + fluxo OTP → validate → `/me` funciona
- [ ] Cookie httpOnly + Secure + SameSite=Lax visível em DevTools

### 4.3 Refs

- Spec auth completa: [_Novo_Projeto/PADRAO_AUTH_SERVICE.md](../PADRAO_AUTH_SERVICE.md)
- R7 canon: [_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md#R7](../01_REGRAS_INEGOCIAVEIS.md)
- R15 (phone normalization JWT/DB): [_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md#R15](../01_REGRAS_INEGOCIAVEIS.md)
- Templates: [_Novo_Projeto/templates/login-ui/README.md](../templates/login-ui/README.md)

---

## Quando algo der errado

| Sintoma | Provável causa | Resolver |
|---|---|---|
| "path não existe" em comando do canon | `PERCUS_CANON_DIR` não setado ou aponta pra path inválido | Rodar `${env:PERCUS_CANON_DIR}/comandos/SETUP_NOVA_MAQUINA.md` na máquina |
| "MISSING" em alguma API key | Setup User-scope não rodado | Ver `${env:PERCUS_CANON_DIR}/AMBIENTE_LOCAL_OPERADOR.md` seção "API keys do kit Percus" |
| Plugin v6.x antigo | Cache do plugin não foi atualizado | UI "Manage plugins" do VS Code → Update `percus-tools` → Reinstall `percus-review` → Reload Window |
| Agente pede `/percus-review:feature-flow` | Skill confundida com slash command | Cole resposta de `comandos/SKILLS_VS_COMMANDS.md` |

---

## Referências relacionadas

- Roteamento completo: `${env:PERCUS_CANON_DIR}/00_LEIA_PRIMEIRO.md`
- Upgrade de projeto existente (não greenfield): `${env:PERCUS_CANON_DIR}/comandos/REORGANIZAR_PROJETO.md`
- Bootstrap de máquina nova: `${env:PERCUS_CANON_DIR}/comandos/SETUP_NOVA_MAQUINA.md`
- Versão atual do canon: `${env:PERCUS_CANON_DIR}/CANON_VERSION.md`
