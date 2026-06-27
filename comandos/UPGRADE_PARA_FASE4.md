---
tipo: comando-pronto
quando-usar: aplicar Fase 4 num projeto em andamento — detecta automaticamente se é projeto legado (sem nada) ou já Fase 4
nao-toca-codigo: true
leitura: 3 min (execução: 3-15 min dependendo do estado detectado)
ultima-atualizacao: 2026-05-03
---

# Upgrade — Projeto em andamento → Fase 4

> ℹ️ **Rota específica por fase (→ Fase 4).** Ponto de entrada geral pra atualizar projeto pro canon
> atual = `comandos/REORGANIZAR_PROJETO.md` (umbrella). Use este se o gap é especificamente chegar à Fase 4.

> **Cole o prompt abaixo no chat do Claude Code do projeto que você quer atualizar.**
>
> O agente vai **detectar automaticamente** qual estado o projeto está e seguir o caminho certo:
> - **Já em Fase 4** → reporta e encerra (nada pra fazer)
> - **Fase 0 (legado sem nada)** → upgrade completo (review + DeepSeek + design + regras)

---

## Prompt para colar

```
Aplique o upgrade Fase 4 neste projeto seguindo `${env:PERCUS_CANON_DIR}\comandos\UPGRADE_PARA_FASE4.md`.

Comece pelo Passo 0 (diagnóstico de estado). NÃO execute Passos 1-3 ainda — só me mostre o resultado do diagnóstico e qual caminho (A/B/C) será seguido. Aguarde minha confirmação antes de prosseguir.

Não toque em código de negócio. Só ferramentas, configs, CLAUDE.md, AGENTS.md, GEMINI.md (se espelho-3) e .gitignore.
```

---

## Passo 0 — Diagnóstico de estado (sempre rodar primeiro)

Detectar qual fase o projeto está. Não modificar nada.

> ⚠️ **CRÍTICO — config dir do Claude Code não é sempre `~/.claude/`.** Em máquinas Percus o `CLAUDE_CONFIG_DIR` aponta pra `D:\Claud Automations\.claude-home\` (ou similar). Ler `~/.claude/settings.json` direto vai dar falso-negativo "plugin não instalado" mesmo com plugin ativo. **Sempre detectar via `$env:CLAUDE_CONFIG_DIR` primeiro**, com fallback pra `$env:USERPROFILE\.claude`.

```powershell
# === Detectar config dir REAL do Claude Code ===
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
$pluginsDir = Join-Path $claudeHome "plugins"
$settingsFile = Join-Path $claudeHome "settings.json"
$installedFile = Join-Path $claudeHome "installed_plugins.json"
Write-Host "Claude config dir: $claudeHome"

# Helper: plugin habilitado em settings.json (fonte da verdade) ou pasta presente (fallback)?
function Test-PluginEnabled([string]$pattern) {
    if (Test-Path $settingsFile) {
        $cfg = Get-Content $settingsFile -Raw | ConvertFrom-Json
        if ($cfg.enabledPlugins) {
            foreach ($key in $cfg.enabledPlugins.PSObject.Properties.Name) {
                if ($key -match $pattern -and $cfg.enabledPlugins.$key) { return $true }
            }
        }
    }
    # Fallback: pasta presente (plugin pode ter sido instalado mas ainda não recarregado)
    return [bool](Get-ChildItem $pluginsDir -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pattern })
}

# === FASE 4 — plugin percus-review já instalado? ===
$fase4_plugin = Test-PluginEnabled 'percus-review|@percus'
$fase4_agents_slim = (Test-Path AGENTS.md) -and `
    (Select-String -Path AGENTS.md -Pattern 'revisor cross-provider|/percus-review:review' -Quiet -ErrorAction SilentlyContinue)
$fase4_claude = (Test-Path CLAUDE.md) -and `
    (Select-String -Path CLAUDE.md -Pattern '/percus-review:review' -Quiet -ErrorAction SilentlyContinue)

# === FASE 0 — projeto legado sem nada? ===
$tem_qualquer_regra = (Test-Path AGENTS.md) -or `
    ((Test-Path CLAUDE.md) -and (Select-String -Path CLAUDE.md -Pattern 'R11|R13|01_REGRAS_INEGOCIAVEIS' -Quiet -ErrorAction SilentlyContinue))

# === Outros componentes (independente da fase) ===
$deepseek_key = (Test-Path .env) -and (Select-String -Path .env -Pattern '^DEEPSEEK_API_KEY=' -Quiet)
$gitignore_deepseek = (Test-Path .gitignore) -and (Select-String -Path .gitignore -Pattern '^\.deepseek/' -Quiet)
$espelho3 = Test-Path GEMINI.md

# === Git hook nativo Percus (Layer 2 anti-bypass, v5.0.8+; v5.0.9+ detecta core.hooksPath) ===
# Resolver hooks dir real (core.hooksPath se setado, senao .git/hooks)
$hooksPath = (git config --local --get core.hooksPath 2>$null)
if (-not $hooksPath) { $hooksPath = (git config --global --get core.hooksPath 2>$null) }
if (-not $hooksPath) { $hooksPath = ".git/hooks" }
$hookFile = Join-Path $hooksPath "pre-commit"
# Detecta tanto v5.0.9 (markers BEGIN/END) quanto v5.0.8 legado (so 'percus-review pre-commit hook')
$git_hook_percus = (Test-Path $hookFile) -and `
    (Select-String -Path $hookFile -Pattern 'PERCUS-MERGED-HOOK BEGIN|percus-review pre-commit hook' -Quiet -ErrorAction SilentlyContinue)
# Sinalizar se eh hibrido (v5.0.9 com custom logic apos END marker)
$git_hook_hybrid = $false
if ($git_hook_percus -and (Select-String -Path $hookFile -Pattern 'PERCUS-MERGED-HOOK END' -Quiet -ErrorAction SilentlyContinue)) {
    # Le linhas apos END marker; se houver mais que 'exit 0' + comentarios, eh hibrido
    $lines = Get-Content $hookFile
    $endIdx = ($lines | Select-String -Pattern 'PERCUS-MERGED-HOOK END' | Select-Object -First 1).LineNumber
    if ($endIdx) {
        $tail = $lines[$endIdx..($lines.Count - 1)] -join "`n"
        if ($tail -notmatch '^\s*(#.*\n|\s*\n)*\s*exit 0\s*$') { $git_hook_hybrid = $true }
    }
}
```

### Decidir caminho

| Sinais detectados | Estado | Caminho |
|---|---|---|
| `$fase4_plugin` AND `$fase4_agents_slim` AND `$fase4_claude` | **Já em Fase 4** | **Caminho A** (reportar e encerrar) |
| Nenhum sinal de Fase 4 | **Fase 0 (legado)** | **Caminho C** (upgrade completo) |
| Sinais mistos / parcial | **Inconsistente** | Reportar matriz e perguntar usuário |

### Reportar matriz ao usuário

```
DIAGNÓSTICO — {Nome do Projeto}

Fase 4 (estado alvo):
  Plugin @percus/review instalado     | ✅/❌
  AGENTS.md slim (cross-provider)     | ✅/❌
  CLAUDE.md menciona /percus-review:review   | ✅/❌

Componentes Percus:
  DEEPSEEK_API_KEY no .env            | ✅/❌
  .gitignore com .deepseek/           | ✅/❌
  GEMINI.md (espelho-3)               | presente/ausente
  CLAUDE.md/AGENTS.md presentes       | ✅/❌
  Git hook nativo Percus ($hooksPath/pre-commit, v5.0.8+) | ✅ puro / ✅ híbrido / ❌
  core.hooksPath custom               | (path) / default (.git/hooks)

──────────────────────────────────────────
ESTADO DETECTADO: {A | B | C | INCONSISTENTE}
CAMINHO RECOMENDADO: {descrição curta}
TEMPO ESTIMADO: {3 / 8 / 15} min
──────────────────────────────────────────

Aguardando confirmação para prosseguir com Caminho {A/B/C}.
```

**PARAR aqui.** Aguardar usuário confirmar antes de executar qualquer mudança.

---

## Caminho A — Já em Fase 4/5 ✅

Quase nada a fazer. Único passo se faltar:

### A.1 — Instalar/atualizar git hook nativo (v5.0.8+; v5.0.9 detecta core.hooksPath e híbrido)

Lógica baseada no diagnóstico:

| Estado | Ação |
|---|---|
| `$git_hook_percus = $false` | Pedir usuário rodar `/percus-review:install-git-hooks` (cria do zero) |
| `$git_hook_percus = $true` E hook é v5.0.8 legado (sem markers BEGIN/END) | Pedir usuário rodar `/percus-review:install-git-hooks` (upgrade pra v5.0.9 format) |
| `$git_hook_percus = $true` E `$git_hook_hybrid = $true` | Pedir usuário rodar `/percus-review:install-git-hooks` se quiser update do bloco Percus (preserva custom). Opcional. |
| `$git_hook_percus = $true` E v5.0.9 puro já | Pular (idempotente, nada a fazer) |

Mensagem padrão pro usuário (adapte ao caso):

> Diagnóstico detectou {ausência | versão legada v5.0.8 | hook híbrido | ausência por core.hooksPath}. Rode no chat:
>
> `/percus-review:install-git-hooks`
>
> Slash commands precisam ser disparados pelo usuário, não pelo agente. O comando v5.0.9 detecta `core.hooksPath`, oferece 3 opções (hybrid merge / replace / abort) se houver hook custom, e é idempotente em re-runs.

### A.2 — Reportar

```
✅ PROJETO JÁ EM FASE 4/5 — {Nome}

Plugin percus-review instalado, AGENTS.md slim, CLAUDE.md atualizado.
{Se git hook nativo foi instalado neste turno: "Git hook nativo (.git/hooks/pre-commit) instalado em v5.0.8."}
{Se já estava instalado: "Git hook nativo (.git/hooks/pre-commit) já presente."}

Para validar saúde de uso (não só configuração), rode:
`comandos/HEALTHCHECK_FASE2.md`
```

---

## Caminho C — Upgrade completo (Fase 0 legado → Fase 4)

Projeto não tem nada do kit Percus. Aplicar tudo de uma vez.

Delegar pro fluxo completo de [`UPGRADE_PROJETO_FASE2.md`](UPGRADE_PROJETO_FASE2.md) (apesar do nome legado, o conteúdo já é Fase 4):

1. **Passo 1** — Plugin `@percus/review` (R11)
2. **Passo 2** — DeepSeek implementador (R13)
4. **Passo 3** — Design workflow (R10) — só atualizar referências
5. **Passo 4** — Mesclar R10/R11/R13 em `CLAUDE.md` + `AGENTS.md` (+ `GEMINI.md` se espelho-3)
6. **Passo 5** — `.gitignore` com `.deepseek/`
7. **Passo 6** — Smoke test combinado (`/percus-review:review` + DeepSeek dry-run)
8. **Passo 6.5** — Instalar git hook nativo: pedir ao usuário rodar `/percus-review:install-git-hooks` (Layer 2 anti-bypass, v5.0.8+)
9. **Passo 7** — HANDOFF
10. **Passo 8** — Reportar

Tempo estimado: ~10-15 min.

Reportar ao final:
```
✅ UPGRADE COMPLETO FASE 4 APLICADO — {Nome}
(detalhes do Passo 8 do UPGRADE_PROJETO_FASE2.md)
```

---

## Anti-padrões

- ❌ Pular Passo 0 (diagnóstico) e tentar adivinhar o estado — vai duplicar trabalho ou quebrar config existente
- ❌ Não ler `GEMINI.md` (espelho-3) — quebra invariante interna do projeto silenciosamente
- ❌ Tocar em código de negócio — esse upgrade é só ferramentas/configs/regras

---

## Quando NÃO usar este comando

- **Projeto novo greenfield** → use `00_LEIA_PRIMEIRO.md` + `CHECKLIST_INICIO_SESSAO.md`. O kit já parte de Fase 4.
- **Quero auditar uso (não config)** → use [`HEALTHCHECK_FASE2.md`](HEALTHCHECK_FASE2.md).
- **Só preciso de uma peça** (review-routing isolado, ou só DeepSeek) → granulares: `SETUP_REVIEW_ROUTING.md`, `SETUP_DEEPSEEK.md`.

---

## Referências

- Setup isolado revisor: [`SETUP_REVIEW_ROUTING.md`](SETUP_REVIEW_ROUTING.md)
- Setup isolado DeepSeek: [`SETUP_DEEPSEEK.md`](SETUP_DEEPSEEK.md)
- Upgrade detalhado completo: [`UPGRADE_PROJETO_FASE2.md`](UPGRADE_PROJETO_FASE2.md) (mesmo conteúdo Fase 4 apesar do nome)
- Healthcheck: [`HEALTHCHECK_FASE2.md`](HEALTHCHECK_FASE2.md)
- Plugin: `${env:PERCUS_CANON_DIR}/plugin/percus-review/`
- Regras: `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md` R11, R13
- Routing de modelos: `${env:PERCUS_CANON_DIR}/04_MODEL_ROUTING.md`
