---
tipo: comando-pronto
quando-usar: aplicar TODAS as mudanças da Fase 4 (DeepSeek + Cross-Claude + design v0/shadcn) num projeto legado de uma vez
nao-toca-codigo: true
leitura: 5 min (execução: 10-15 min dependendo do que falta)
ultima-atualizacao: 2026-05-03
---

# Upgrade — Projeto legado para Fase 4

> ℹ️ **Rota específica (baseline Fase 4).** Para atualizar um projeto pro canon ATUAL de forma geral,
> o ponto de entrada é `comandos/REORGANIZAR_PROJETO.md` (umbrella) — ele roteia pra cá quando o
> projeto ainda não tem plugin/review/DeepSeek. Use este doc direto se você já sabe que o gap é só o baseline Fase 4.

> Cole este prompt no agente Claude Code do projeto legado. Ele aplica **todas** as mudanças da Fase 4 numa passada: plugin `@percus/review` como revisor cross-provider (DeepSeek + Cross-Claude), DeepSeek como implementador, design via v0.dev + shadcn, regras R10/R11/R13 mescladas em `CLAUDE.md`/`AGENTS.md`.
>
> **Substitui rodar separadamente:** `SETUP_REVIEW_ROUTING.md` + `SETUP_DEEPSEEK.md` + edição manual do `CLAUDE.md`/`AGENTS.md`.

---

## Objetivo

Trazer um projeto Percus para o estado canônico atual (Fase 4, 2026-05-03):

1. **Plugin `@percus/review`** instalado como revisor cross-provider (R11) — DeepSeek + Cross-Claude, gate de commit + marco
2. **DeepSeek** disponível como implementador delegado (R13) — playbook em `04_MODEL_ROUTING.md`
3. **Design** via v0.dev + shadcn MCP (R10 — Claude artifacts vetado)
4. **CLAUDE.md** + **AGENTS.md** atualizados com triggers R10/R11/R13
5. **`.gitignore`** com `.deepseek/`

---

## O que o agente vai fazer (na ordem, com gates)

### Passo 0 — Diagnóstico inicial

Detectar estado atual sem mexer em nada.

> ⚠️ **CRÍTICO:** Claude Code lê config de `$env:CLAUDE_CONFIG_DIR` quando setado, senão `~/.claude/`. Em máquinas Percus é `D:\Claud Automations\.claude-home\`. Hardcodar `$env:USERPROFILE\.claude` dá falso-negativo "plugin não instalado" mesmo com plugin ativo. **Detecte o path real primeiro:**

```powershell
# Detectar config dir REAL
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
$pluginsDir = Join-Path $claudeHome "plugins"
$userSettings = Join-Path $claudeHome "settings.json"
Write-Host "Claude config dir: $claudeHome"

# Helper: plugin habilitado em settings.json (fonte da verdade) ou pasta presente?
function Test-PluginEnabled([string]$pattern) {
    if (Test-Path $userSettings) {
        $cfg = Get-Content $userSettings -Raw | ConvertFrom-Json
        if ($cfg.enabledPlugins) {
            foreach ($k in $cfg.enabledPlugins.PSObject.Properties.Name) {
                if ($k -match $pattern -and $cfg.enabledPlugins.$k) { return $true }
            }
        }
    }
    return [bool](Get-ChildItem $pluginsDir -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pattern })
}

# Plugin percus-review já configurado?
Test-PluginEnabled 'percus-review|@percus'
Test-Path AGENTS.md

# Ambiente Claude Code — INFORMATIVO (não é bloqueio, ambos suportam plugins)
$claudeCli = Get-Command claude -ErrorAction SilentlyContinue
$vscodeExt = (code --list-extensions 2>$null | Select-String "anthropic.claude-code")
# Resultado: CLI standalone | Extensão VS Code | Ambos | Nenhum (raro)

# DeepSeek já configurado?
Select-String -Path .env -Pattern '^DEEPSEEK_API_KEY=' -Quiet

# CLAUDE.md menciona R13?
Select-String -Path CLAUDE.md -Pattern 'R13|MODEL_ROUTING|DeepSeek' -Quiet

# .gitignore tem .deepseek/?
Select-String -Path .gitignore -Pattern '^\.deepseek/' -Quiet

# Convenção espelho-3 (alguns projetos legados têm GEMINI.md como 3º espelho de CLAUDE.md/AGENTS.md)?
Test-Path GEMINI.md
```

Reportar matriz de status:

```
DIAGNÓSTICO — {Nome do Projeto}

Componente                       | Status              | Ação
---------------------------------|---------------------|---------------------------
Plugin @percus/review            | ❌ ausente           | Passo 1
DEEPSEEK_API_KEY                 | ✅ presente          | —
AGENTS.md (slim, Fase 4)         | ❌ ausente/antigo    | Recriar (Passo 4)
GEMINI.md (se existir)           | ✅ presente          | Recriar slim (Passo 4 — espelho-3)
CLAUDE.md menciona R11 nova      | ❌ ausente           | Mesclar (Passo 4)
.gitignore .deepseek/            | ❌ ausente           | Passo 5

Tempo estimado: ~10 min (+1 min se espelho-3 ativo)
```

> **Importante sobre "Ambiente Claude Code":** essa linha é **informativa, não bloqueio**. Tanto CLI standalone (`claude` no PATH) quanto Extensão VS Code (`anthropic.claude-code` instalada) suportam plugins normalmente — só muda o **canal de instalação** do plugin (slash command vs UI Manage Plugins). Use ℹ️ (não ❓ nem ❌) e não trate como "fallback" ou "ambiente restrito". Se ambos estiverem presentes, prefira Caminho A (slash) por ser mais rápido.

**Nota sobre GEMINI.md:** alguns projetos Percus legados mantêm convenção de espelhar CLAUDE.md em 3 arquivos (CLAUDE.md / AGENTS.md / GEMINI.md), pra que diferentes agentes (Claude / revisor cross-provider / Gemini CLI) leiam as mesmas regras. Não é convenção do kit Percus — é decisão por-projeto. Se o `Test-Path GEMINI.md` retornar true, **assuma espelho-3 ativo** e aplique mescla nos 3 arquivos no Passo 4 (mantém invariante interna do projeto, mesmo que o usuário não use Gemini ativamente). Se retornar false, segue espelho-2 (CLAUDE.md + AGENTS.md) normal.

**Pedir confirmação ao usuário antes de prosseguir.**

---

### Passo 1 — Plugin @percus/review (R11) — se ausente

Aplicar fluxo de `comandos/SETUP_REVIEW_ROUTING.md` em modo "skip o que já existe":

- Verificar `DEEPSEEK_API_KEY` no `.env` do projeto (PARAR se ausente — instruir obtenção em https://platform.deepseek.com)
- Instalar plugin `@percus/review` a nível de usuário (1× por máquina) via:
  ```
  /plugin marketplace add huboperacional/percus-kit
  /plugin install percus-review
  ```
  Alternativo (kit local): `/plugin marketplace add ${env:PERCUS_CANON_DIR}` + `/plugin install percus-review`
- Validar com `/percus-review:review` em smoke trivial (Passo 6)

**Bifurcação CLI standalone vs Extensão VS Code (informativo):**

Tanto CLI standalone quanto Extensão VS Code suportam plugins. Detectar:

```powershell
$cli = Get-Command claude -ErrorAction SilentlyContinue
$ext = (code --list-extensions 2>$null | Select-String "anthropic.claude-code")
```

| Cenário detectado | Caminho de instalação |
|---|---|
| CLI standalone presente | **Caminho A** — abrir `claude` no PowerShell e rodar `/plugin marketplace add huboperacional/percus-kit` + `/plugin install percus-review` (ou path local `${env:PERCUS_CANON_DIR}` se offline) |
| Só Extensão VS Code | **Caminho B** — UI: `/plu` → "Manage plugins" → aba Plugins → "Install from local" → cola path do plugin |
| Ambos | Caminho A (mais rápido) ou B (UI) |
| Nenhum (raro) | `npm i -g @anthropic-ai/claude-code` → reabrir → seguir Caminho A |

> **`/plugin` não funciona no chat da extensão VS Code.** Plugin manager de slash só está no terminal `claude`. Extensão tem UI Manage Plugins.

### Passo 2 — DeepSeek como implementador (R13) — se ausente

Aplicar fluxo do `comandos/SETUP_DEEPSEEK.md`:

- Verificar `DEEPSEEK_API_KEY` no `.env` (PARAR se ausente)
- Verificar wrapper presente em `${env:PERCUS_CANON_DIR}/scripts/`
- Adicionar `.deepseek/` ao `.gitignore` (próximo passo já cobre)
- Smoke test em dry-run com `_smoke-deepseek.md` mínimo (somar dois inteiros)
- Validar que retornou bloco `===WRITE===` com tokens < 1500
- Apagar `_smoke-deepseek.md` (não aplicar)

---

### Passo 3 — Design workflow (R10) — atualizar referências

Não há instalação — só garantir que o agente do projeto **sabe** que:
- Componente isolado → `shadcn MCP` (skill `vercel:shadcn` se disponível, senão `npx shadcn@latest add <comp>`)
- Tela/fluxo novo → `v0.dev` (browser, créditos Vercel próprios)
- Iteração rápida → editar local + `npm run dev`
- Diagrama → Excalidraw / Mermaid

Isso vai entrar no `CLAUDE.md` no Passo 4. Não tem setup técnico aqui.

---

### Passo 4 — Mesclar triggers R10/R11/R13 no `CLAUDE.md` + `AGENTS.md` (+ `GEMINI.md` se espelho-3 ativo)

**NÃO sobrescrever** os arquivos. **Mesclar** — adicionar seções faltando, preservar conteúdo existente.

**Detecção de espelho-3 (do Passo 0):** se `Test-Path GEMINI.md` retornou true, o projeto mantém convenção de espelhar regras nos 3 arquivos. Aplique a mesma mescla em todos os 3, na seguinte ordem:

1. Mesclar primeiro em `CLAUDE.md` (autoridade primária do projeto)
2. Aplicar a mesma mescla em `AGENTS.md` (espelho pro revisor cross-provider)
3. **Se espelho-3 ativo:** aplicar a mesma mescla em `GEMINI.md` (espelho pra Gemini CLI)

> Espelho-3 não é convenção Percus — é convenção interna do projeto detectada pela presença do `GEMINI.md`. Honrar essa invariante mesmo que o usuário não use Gemini ativamente; quebra silenciosa de convenção interna gera drift difícil de detectar depois.

**Para `CLAUDE.md`:**

Adicionar (se ausente) na seção "Workflow obrigatório" ou como seção própria:

```markdown
## R10 — Design (v0.dev + shadcn MCP)
Tela ou componente novo: NÃO usar Claude artifacts (vetado pra produção pela R10).
- Componente isolado → shadcn MCP (`npx shadcn@latest add <comp>`)
- Tela/fluxo → v0.dev
- Diagrama → Excalidraw / Mermaid

Workflow detalhado: `${env:PERCUS_CANON_DIR}/comandos/DESIGN_WORKFLOW.md`

## R11 — Review cross-provider (commit + marco)
`/percus-review:review` é obrigatório em DOIS momentos:
1. Antes de cada commit que muda código (router decide DeepSeek / Cross-Claude / duplo)
2. Ao concluir cada marco de plano: `/percus-review:milestone-review --base <commit-inicio-marco>` (DeepSeek + Cross-Claude duplo)

Sem review nos últimos 5min antes do commit OU sem milestone-review no escopo do marco = não pode prosseguir.

## R13 — Routing de modelos (Claude arquiteta, DeepSeek implementa, multi-revisor revisa)
Implementação mecânica delegada ao DeepSeek via wrapper (R13). Saída é rascunho até passar por Claude (R1–R12) + revisor cross-provider (R11) + ciclo CRUD (R1).

Commits aplicados via wrapper DeepSeek devem terminar com trailer Git:
\`\`\`
Co-implemented-by: deepseek-v4
\`\`\`
O router de R11 detecta esse trailer e roteia revisão pra Cross-Claude (anti auto-revisão).

Quando delegar (TODOS): plano explícito + arquivos nomeados + sem decisão arquitetural + fora de pasta sensível + ≤3 arquivos ou padrão repetido.

Playbook: `${env:PERCUS_CANON_DIR}/04_MODEL_ROUTING.md` seção "Como delegar".
```

**Para `AGENTS.md`** (revisor cross-provider precisa saber pra revisar com critério):

Recriar a partir do template slim em `${env:PERCUS_CANON_DIR}/templates/AGENTS.template.md` (~4.4 KB). Substitui versão antiga/maior. Preservar seções "O que é este projeto" e "Stack" se já preenchidas no AGENTS.md anterior — mesclar.

---

### Passo 5 — `.gitignore` com `.deepseek/`

Garantir que `.deepseek/` está no `.gitignore` do projeto. Se faltar `.gitignore` inteiro, criar baseado em `${env:PERCUS_CANON_DIR}/templates/.gitignore.example`.

---

### Passo 6 — Smoke test combinado

Validar fluxo end-to-end:

1. Criar `_smoke.md` na raiz com texto bobo
2. `git add _smoke.md`
3. Rodar `/percus-review:review` no chat
4. Esperado: router decide `deepseek` (default), DeepSeek retorna findings em < 5s (provavelmente "Sem findings críticos."). Custo dashboard DeepSeek: ~$0.001-0.01
5. Apagar `_smoke.md` e `git restore --staged _smoke.md`

Se falha:
- API key inválida → conferir `DEEPSEEK_API_KEY` no `.env`
- Plugin não responde → `/plugin reload` ou reabrir Claude Code
- DeepSeek API down → router faz fallback automático pra Cross-Claude (Sonnet subagent)

---

### Passo 7 — Atualizar `HANDOFF.md`

Adicionar nota:

```markdown
## Upgrade Fase 4 aplicado em {data}

Projeto agora usa:
- Plugin @percus/review como revisor cross-provider (R11 — commit + marco; DeepSeek + Cross-Claude duplo)
- DeepSeek como implementador delegado (R13 — playbook em 04_MODEL_ROUTING.md)
- v0.dev + shadcn MCP como caminho de design (R10 — Claude artifacts vetado)

Próximas tasks: avaliar elegibilidade DeepSeek antes de implementar (gate G-DELEGA do CHECKLIST_FEATURE_NOVA).
```

---

### Passo 8 — Reportar

```
UPGRADE FASE 4 CONCLUÍDO — {Nome do Projeto}

Aplicado:
✅ Plugin @percus/review instalado
✅ AGENTS.md slim recriado (~4.4 KB)
✅ DEEPSEEK_API_KEY validada
✅ CLAUDE.md com R10/R11/R13 mesclados (R11: cross-provider)
✅ GEMINI.md com R10/R11/R13 mesclados (se espelho-3; senão N/A)
✅ .gitignore com .deepseek/
✅ /percus-review:review smoke test passou
✅ HANDOFF.md atualizado

Custos do upgrade: ~$0.01 (smoke DeepSeek)
Tempo total: X minutos
Custo mensal estimado pós-upgrade: $2-5

Próximos passos:
1. Ao iniciar próxima feature: aplicar G-DELEGA (CHECKLIST_FEATURE_NOVA) pra decidir se vai pro DeepSeek
2. Antes de cada commit: `/percus-review:review` (router decide)
3. Ao concluir cada marco: `/percus-review:milestone-review --base <commit-inicio-marco>` (DeepSeek + Cross-Claude duplo)
4. Tela/componente novo: ler comandos/DESIGN_WORKFLOW.md (NÃO Claude artifacts)
```

---

## Anti-padrões durante o upgrade

- ❌ Pular Passo 0 (diagnóstico) e tentar instalar tudo cego — vai duplicar trabalho ou quebrar o que já funciona
- ❌ Sobrescrever `CLAUDE.md` ou `AGENTS.md` em vez de mesclar — perde contexto específico do projeto
- ❌ Esquecer `.deepseek/` no `.gitignore` antes do smoke test — vaza `_smoke.md` se commitar antes
- ❌ Aplicar `--apply` no smoke test em vez de `--dry-run` — polui o repo
- ❌ Aplicar saída DeepSeek sem trailer `Co-implemented-by: deepseek-v4` no commit — router não detecta auto-revisão

---

## Quando NÃO usar este comando

- Projeto novo greenfield → use `00_LEIA_PRIMEIRO.md` + `CHECKLIST_INICIO_SESSAO.md`. O kit já parte da Fase 4 atual.
- Projeto que só precisa do reviewer (não usa DeepSeek delegado) → use `SETUP_REVIEW_ROUTING.md` direto
- Projeto que só precisa de DeepSeek implementador (reviewer já configurado) → use `SETUP_DEEPSEEK.md` direto

---

## Referências

- `comandos/SETUP_REVIEW_ROUTING.md` — plugin @percus/review isolado
- `comandos/SETUP_DEEPSEEK.md` — DeepSeek implementador isolado
- `comandos/DESIGN_WORKFLOW.md` — fluxo de design v0/shadcn
- `04_MODEL_ROUTING.md` — playbook completo + matriz de routing de revisores
- `01_REGRAS_INEGOCIAVEIS.md` — R10, R11, R13
- `templates/.gitignore.example` — base do `.gitignore`
