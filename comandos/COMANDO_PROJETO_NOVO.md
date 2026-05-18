---
tipo: comando-pronto-para-colar
quando-usar: começar projeto Percus greenfield do zero
nao-toca-codigo: true
leitura: 1 min · execução típica: 30-45 min
ultima-atualizacao: 2026-05-18
fase-destino: 7 (v6.7.0+ — versão atual em CANON_VERSION.md)
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

3. Apos templates criados, rodar `${env:PERCUS_CANON_DIR}/comandos/SCOPE_COUNCIL.md` (gate de scope dia 1):
   - 3 etapas: Claude principal solo -> conselho 3-membros pre-mortem paralelo -> sintese humana
   - ~25 min, ~$0.005
   - PULA somente se projeto trivial (<1 mes de trabalho dedicado, stack ja decidida por restricao externa).

4. Setup auth (R7 — auth-service Percus):
   - Auth-service em prod em `https://auth.huboperacional.com.br` desde 2026-05-06.
   - Lib cliente self-hosted: pip install https://auth.huboperacional.com.br/dist/percus_auth-<ver>-py3-none-any.whl OU npm install https://auth.huboperacional.com.br/dist/percus-auth-<ver>.tgz
   - VETADO em projeto novo: GoTrue, Supabase Auth, NextAuth, magic-link proprio, senha sem 2FA, refresh JWT stateless. Ver R7 em 01_REGRAS_INEGOCIAVEIS.md.

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
- Upgrade de projeto existente (não greenfield): `${env:PERCUS_CANON_DIR}/comandos/UPGRADE_PARA_FASE6.md`
- Bootstrap de máquina nova: `${env:PERCUS_CANON_DIR}/comandos/SETUP_NOVA_MAQUINA.md`
- Versão atual do canon: `${env:PERCUS_CANON_DIR}/CANON_VERSION.md`
