---
tipo: runbook de setup
audiência: operador (Rodrigo) configurando projeto Percus novo ou padronizando projeto existente
quando-usar: ao criar projeto novo, ao migrar projeto legado pra padrão Percus, ao detectar drift no `.claude/settings.json` de algum projeto
leitura: 3 min
---

# SETUP — `.claude/settings.json` canônico Percus

> **Por quê:** padronizar permissões, hooks de sessão (GATE INICIO / GATE VISUAL / ENCERRAMENTO) e MCPs entre todos os projetos Percus, eliminando drift entre configs.

## Quando aplicar

- **Projeto novo:** scaffolda automaticamente via `tools/scaffold-percus-project.ps1` (incluído desde v6.11.0).
- **Projeto existente:** copia `templates/settings.template.json` pra `<projeto>/.claude/settings.json` (sobrescreve se já existir; faz backup antes se houver customização local).

## Passo a passo (manual, ~1 min)

### 1. Criar diretório

```powershell
# Na raiz do projeto consumidor:
New-Item -ItemType Directory -Force .claude | Out-Null
```

### 2. Copiar template

```powershell
Copy-Item "${env:PERCUS_CANON_DIR}\templates\settings.template.json" .claude\settings.json -Force
```

Ou — em projetos onde já existe `.claude/settings.json` customizado:

```powershell
Copy-Item .claude\settings.json .claude\settings.json.bak
Copy-Item "${env:PERCUS_CANON_DIR}\templates\settings.template.json" .claude\settings.json -Force
# Conferir o .bak depois pra trazer customizações específicas se houver.
```

### 3. Smoke

Abra uma sessão nova de Claude Code no projeto. Verifique:

- Hook `[GATE INICIO]` dispara no início da sessão.
- Hook `[ENCERRAMENTO]` dispara ao fechar.
- `Bash(*)`, `PowerShell(*)`, `Write/Edit/Read` rodam sem prompt.
- MCPs do projeto carregam automaticamente.

## O que está no template (anotado)

### `permissions.defaultMode: "bypassPermissions"`
Trust mode total. Justificativa: ambiente Percus = **operador único** (Rodrigo). Zero atrito; cliques manuais viram ruído. Se algum dia o estúdio crescer, esse default precisa ser reavaliado (provavelmente vira `acceptEdits` ou `default`).

### `permissions.additionalDirectories`
- `d:\\tmp` — scratch space para council prompts, drafts, smoke tests.
- `d:\\Claud Automations` — todos os projetos Percus moram aqui; permite ler cross-projeto pra referência (mas não escrever — ver [[cross-repo-write-protocol]] em memory).
- `${env:USERPROFILE}\\Downloads` — auto-resolve em qualquer máquina via env var Windows.

### `permissions.allow`
Whitelist explícita pra futura migração de `bypassPermissions` → `acceptEdits` sem perder o "sim a tudo" atual. Cobre Bash, PowerShell, edição/escrita/leitura de arquivos, web search/fetch, MCPs.

### `enableAllProjectMcpServers: true`
Auto-trust de MCPs declarados em `.mcp.json` do projeto. Conveniente; aceitável pra ambiente solo.

### `env.NODE_ENV: "development"`
Padrão pra qualquer ferramenta Node (Vite, Next, tests) ler corretamente. Override por `.env` do projeto se precisar.

### Hooks

**`SessionStart` — GATE INICIO** (sempre dispara):
- Lembra de ler `HANDOFF.md` + `docs/PLANO.md` + `docs/mock-audit.md` se for projeto de produto.
- Inclui "Se eh canon/lib/tooling, ignore." pra silenciar em sessões de canon onde esses arquivos não existem.

**`UserPromptSubmit` — GATE VISUAL** (dispara só com regex específica):
- Regex: `(gerar (mockup|wireframe|design)|criar tela nova|redesenhar.*(p[áa]gina|tela)|v0\.dev|claude\.ai/design|hero section|reestilizar.*UI|landing page (nova|do zero)|mockup do figma)`
- Dispara só quando o operador pede explicitamente algo visual NOVO. Palavras genéricas como "layout", "estilo", "paleta" não disparam mais (eram fonte de falso-positivo recorrente).
- Lembra de gerar mockup no Claude Design antes de codar.

**`Stop` — ENCERRAMENTO** (sempre dispara):
- Lembra de atualizar `HANDOFF.md` + `docs/PLANO.md` + `docs/mock-audit.md` antes de fechar.
- Inclui "Se canon/lib, ignorar." pelo mesmo motivo do GATE INICIO.

## Customização permitida

O template é **base** — você pode adicionar:

- Mais `additionalDirectories` específicos do projeto.
- Hooks adicionais (ex: `PreToolUse` matcher pra bash específico).
- `env` vars específicas (ex: `DATABASE_URL`, `API_KEY` — só em `.env`, **nunca** em `settings.json` versionado).

O template **não deve ser editado** em:
- `permissions.allow` — alterações aqui mudam segurança; discutir antes de adotar permanente.
- Hooks `SessionStart` e `Stop` — alterações aqui afetam disciplina de leitura/atualização de HANDOFF/PLANO. Tornam regra inconsistente entre projetos.
- Regex do `UserPromptSubmit` — refinada em v6.11.0 após observar falsos-positivos.

## Drift detection

Pra checar se um projeto está alinhado com o template:

```powershell
diff (Get-Content .claude\settings.json) (Get-Content "${env:PERCUS_CANON_DIR}\templates\settings.template.json")
```

Se houver diff legítimo (customização do projeto), documente em `<projeto>/docs/CLAUDE_SETTINGS_DIFF.md` justificando.

## Anti-padrões

- ❌ Editar `permissions.defaultMode` pra `default` num projeto sem coordenar com o canon — quebra expectativa de "sim a tudo" automática.
- ❌ Adicionar `deny` específico via settings.json — gerencie permissions sensíveis via hooks PreToolUse (ex: `external-action-guard.ps1` do plugin `percus-review`).
- ❌ Hardcoded de path absoluto da máquina principal (`d:\Claud Automations\...`) em outros projetos sem reescrever via env var. Use `${env:PERCUS_CANON_DIR}` ou `${env:USERPROFILE}`.

## Referências
- Template: `templates/settings.template.json`
- Memory cross-repo: [[cross-repo-write-protocol]] (NUNCA escreve em projeto fora do CWD)
- Plugin percus-review hooks (camada Layer 2, complementam SessionStart/Stop): `plugin/percus-review/hooks/pre-commit-check.{ps1,sh}`, `on-stop-check.{ps1,sh}`
