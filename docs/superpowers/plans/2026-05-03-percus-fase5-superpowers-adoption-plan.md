# Percus Fase 5 — Superpowers Adoption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar Fase 5 do kit Percus — adicionar 2 skills internas (`feature-flow`, `close-milestone`) + 2 hooks bloqueantes (pre-commit, on-stop) ao plugin `@percus/review`, atualizar canon (R8, R9), criar guia `USANDO_SUPERPOWERS.md` e resolver bloqueador de instalação via `marketplace.json` wrapper.

**Architecture:** 3 camadas no plugin existente — Skills (memória ativa via auto-trigger por description), Hooks (gates mecânicos via PreToolUse/Stop events), Canon (fonte de verdade atualizada). Sem novos plugins; tudo dentro do `percus-review` que já está no kit.

**Tech Stack:** PowerShell 5.1+ (Windows handlers), Bash 4+ (Unix handlers), JSON (plugin manifest + marketplace), Markdown (skills + docs), Git (versionamento, branch `fase5-superpowers-adoption`).

**Spec aprovado:** `docs/superpowers/specs/2026-05-03-percus-fase5-superpowers-adoption-design.md`

**Pré-requisitos antes de começar:**
- Branch ativa: `fase5-superpowers-adoption`
- Repo: `github.com/huboperacional/percus-kit` (privado)
- Plugin Fase 4 existe em `plugin/percus-review/` + `marketplace.json` wrapper já criado em `plugin/.claude-plugin/` (v4.0.1)
- `DEEPSEEK_API_KEY` configurada em pelo menos 1 projeto Percus pra smoke real

**Princípios de isolamento entre tasks (importante):**
- **Smoke tests Tasks 7 e 8** rodam o script handler **diretamente via subprocess** (`powershell -File <hook>.ps1` ou `bash <hook>.sh`) passando JSON via stdin. **Não dependem do plugin manifest estar registrado.**
- **E2E tests Task 9** validam o ciclo completo via Claude Code (commit dispara hook automaticamente). **Dependem do manifest em plugin.json**.
- Sequência: implementar handlers (7, 8) → registrar no manifest (9) → E2E (9.3+).

---

## File Structure

### Files a CRIAR

| Path | Responsabilidade |
|---|---|
| `plugin/.claude-plugin/marketplace.json` | Wrapper que registra `percus-review` como plugin instalável via `/plugin marketplace add` |
| `plugin/percus-review/skills/feature-flow/SKILL.md` | Orquestra fluxo R1→R13 numa invocação (~4 KB) |
| `plugin/percus-review/skills/close-milestone/SKILL.md` | Gate de marco — invoca milestone-review e marca ✓ (~1.5 KB) |
| `plugin/percus-review/hooks/pre-commit-check.ps1` | Hook bloqueante: pre-commit sem review fresco (Windows) |
| `plugin/percus-review/hooks/pre-commit-check.sh` | Mesmo, Unix |
| `plugin/percus-review/hooks/on-stop-check.ps1` | Hook bloqueante: stop sem HANDOFF atualizado (Windows) |
| `plugin/percus-review/hooks/on-stop-check.sh` | Mesmo, Unix |
| `plugin/percus-review/tests/smoke-pre-commit.{ps1,sh}` | Smoke test pre-commit |
| `plugin/percus-review/tests/smoke-on-stop.{ps1,sh}` | Smoke test on-stop |
| `comandos/USANDO_SUPERPOWERS.md` | Guia rápido das skills relevantes (~1.2 KB) |

### Files a MODIFICAR

| Path | Mudança |
|---|---|
| `plugin/percus-review/plugin.json` | Adicionar campos `skills` e `hooks` |
| `01_REGRAS_INEGOCIAVEIS.md` | R8 ganha gate mecânico, R9 ganha 2 linhas, anti-padrões 17+18 |
| `comandos/SETUP_REVIEW_ROUTING.md` | Passo 2 com nova sintaxe `/plugin marketplace add` |
| `comandos/UPGRADE_PARA_FASE4.md` | Caminhos B e C com nova sintaxe |
| `templates/PLANO.template.md` | Marcação ✓ menciona `percus-review:close-milestone` skill |

### Princípio de decomposição

Cada task produz um artefato auto-contido (1 arquivo ou 1 grupo de arquivos relacionados) + smoke test que valida comportamento. Commits frequentes (1 por task em geral).

---

## Task 1: Smoke tests T0a/T0b — validar formato real dos hooks no Claude Code

**Files:**
- Create: `plugin/percus-review/tests/smoke-hook-format.ps1`
- Create: `plugin/percus-review/tests/smoke-hook-format.sh`

**Por que primeiro:** spec depende de assumir que `PreToolUse` matcher `Bash` recebe `tool_input.command` no stdin e `Stop` event recebe `transcript_path`. Se formato divergir, todos os hooks subsequentes precisam ajuste. Validar ANTES de implementar handlers reais.

- [ ] **Step 1: Criar handler minimal que só ECHO o stdin recebido**

Conteúdo de `plugin/percus-review/tests/smoke-hook-format.ps1`:
```powershell
#requires -Version 5.1
# Smoke test format — só lê stdin e escreve em arquivo de log pra inspeção.
# NÃO bloqueia (sempre exit 0).

$logDir = Join-Path $env:USERPROFILE ".percus-hook-format-test"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString().Substring(0,8)).json"

$stdin = [Console]::In.ReadToEnd()
$stdin | Out-File -FilePath $logFile -Encoding utf8 -NoNewline

Write-Host "[smoke-hook-format] stdin capturado em $logFile" -ForegroundColor Cyan
exit 0
```

Conteúdo de `plugin/percus-review/tests/smoke-hook-format.sh`:
```bash
#!/usr/bin/env bash
LOG_DIR="$HOME/.percus-hook-format-test"
mkdir -p "$LOG_DIR"
TS=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/${TS}-$(uuidgen 2>/dev/null | head -c 8 || echo "smoke").json"
cat > "$LOG_FILE"
echo "[smoke-hook-format] stdin capturado em $LOG_FILE" >&2
exit 0
```

- [ ] **Step 2: Registrar handler temporariamente em `~/.claude/settings.json` (pre + stop)**

Adicionar em `~/.claude/settings.json` (criar arquivo se não existir, mesclar com config existente):
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "powershell -File \"${env:PERCUS_CANON_DIR}/plugin/percus-review/tests/smoke-hook-format.ps1\"" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "powershell -File \"${env:PERCUS_CANON_DIR}/plugin/percus-review/tests/smoke-hook-format.ps1\"" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Disparar handlers em ambiente real**

No chat Claude Code:
1. Executar comando Bash trivial: `Bash` tool com `command: "echo test"` → captura T0a
2. Encerrar sessão (Stop) → captura T0b

- [ ] **Step 4: Inspecionar logs capturados**

```powershell
Get-ChildItem "$env:USERPROFILE\.percus-hook-format-test" | Sort-Object LastWriteTime -Descending | Select-Object -First 2 | ForEach-Object { Write-Host "=== $($_.Name) ==="; Get-Content $_.FullName }
```

Esperado: 2 arquivos JSON. Conferir:
- T0a (PreToolUse Bash) tem `tool_input.command` ou estrutura similar
- T0b (Stop) tem `transcript_path`

Anotar o formato real em `plugin/percus-review/tests/HOOK_FORMAT_REFERENCE.md` (file de referência criado a partir dos resultados — base pra implementar handlers reais).

- [ ] **Step 5: Limpar config temporário**

Remover bloco de hooks de `~/.claude/settings.json` (ou comentar). Limpar `~/.percus-hook-format-test/`.

- [ ] **Step 6: Commit**

```bash
git add plugin/percus-review/tests/smoke-hook-format.ps1 plugin/percus-review/tests/smoke-hook-format.sh plugin/percus-review/tests/HOOK_FORMAT_REFERENCE.md
git commit -m "test(hooks): smoke validate Claude Code hook stdin format (T0a/T0b)"
```

---

## Task 2: Criar `marketplace.json` wrapper + validar instalação local

**Files:**
- Create: `plugin/.claude-plugin/marketplace.json`

- [ ] **Step 1: Criar arquivo de marketplace wrapper**

```json
{
  "name": "percus-tools",
  "description": "Percus internal tooling — review cross-provider plugin",
  "owner": { "name": "Percus" },
  "plugins": [
    {
      "name": "percus-review",
      "description": "Review cross-provider Percus (DeepSeek + Cross-Claude)",
      "version": "1.0.0",
      "source": "./percus-review"
    }
  ]
}
```

- [ ] **Step 2: Verificar que plugin.json existente do percus-review está válido**

```bash
cat "${env:PERCUS_CANON_DIR}/plugin/percus-review/plugin.json"
```

Confirmar que tem `name: "percus-review"` e estrutura mínima.

- [ ] **Step 3: Smoke test instalação no chat Claude Code (terminal `claude`)**

```
/plugin marketplace add ${env:PERCUS_CANON_DIR}/plugin
```

Esperado: `Successfully added marketplace: percus-tools`

```
/plugin install percus-review
```

Esperado: `Plugin 'percus-review' installed`. Confirmação:
```
/plugin
```

Esperado: `percus-review` listado como instalado.

- [ ] **Step 4: Validar plugin acessível via slash commands**

```
/percus-review:review
```

Esperado: comando responde (mesmo que com erro "no diff" — confirma que está roteado).

- [ ] **Step 5: Documentar resultado em commit**

Se funcionou: prosseguir.
Se falhou: anotar erro exato no commit message + pivotar.

```bash
git add plugin/.claude-plugin/marketplace.json
git commit -m "feat(plugin): add marketplace.json wrapper to enable local install"
```

---

## Task 3: Atualizar SETUP_REVIEW_ROUTING + UPGRADE_PARA_FASE4 com nova sintaxe

**Files:**
- Modify: `comandos/SETUP_REVIEW_ROUTING.md`
- Modify: `comandos/UPGRADE_PARA_FASE4.md`

- [ ] **Step 1: Atualizar SETUP_REVIEW_ROUTING.md Passo 2**

Localizar bloco "Caminho A — CLI standalone" e substituir por:

```markdown
**Caminho A — CLI standalone (preferido)**

Abrir Claude Code no terminal:
\`\`\`powershell
claude
\`\`\`

No chat:
\`\`\`
/plugin marketplace add ${env:PERCUS_CANON_DIR}/plugin
/plugin install percus-review
\`\`\`

Esperado:
- 1ª linha: "Successfully added marketplace: percus-tools"
- 2ª linha: "Plugin 'percus-review' installed"
\`\`\`

- [ ] **Step 2: Atualizar UPGRADE_PARA_FASE4.md Caminho B (passo B.2) e Caminho C**

Substituir referências antigas a `/plugin install <path>` pelas duas linhas (`marketplace add` + `install`) em ambos caminhos B.2 e C (delegação ao UPGRADE_PROJETO_FASE2 deve refletir).

- [ ] **Step 3: Atualizar UPGRADE_PROJETO_FASE2.md Passo 1 (que UPGRADE_PARA_FASE4 delega)**

Mesma atualização de sintaxe.

- [ ] **Step 4: Smoke test conceitual (revisão visual)**

`grep -r "/plugin install" comandos/` — todas as ocorrências devem usar a nova sintaxe ou serem dentro de seções DEPRECATED.

- [ ] **Step 5: Commit**

```bash
git add comandos/SETUP_REVIEW_ROUTING.md comandos/UPGRADE_PARA_FASE4.md comandos/UPGRADE_PROJETO_FASE2.md
git commit -m "docs(commands): update plugin install syntax to use marketplace add + install"
```

---

## Task 4: Criar skill `feature-flow`

**Files:**
- Create: `plugin/percus-review/skills/feature-flow/SKILL.md`

- [ ] **Step 1: Criar SKILL.md**

Conteúdo:
```markdown
---
name: feature-flow
description: Use when starting any feature or bugfix in a Percus project. Orchestrates R1→R13 workflow (brainstorming → plan → subagent-driven execution → TDD → /percus-review:review → mark [5-T]). Replaces loading R1+R9+R11+R13 separately.
---

# Percus Feature Flow

Quando começar feature nova OU bugfix em projeto Percus, siga este fluxo.

## Quando NÃO usar
- Bug fix de 1 linha, rename trivial, typo → só faz e roda `/percus-review:review`
- Sessão de consulta (ler código, explicar) → não aplicável

## Fluxo (passos numerados)

### 1. Brainstorming se não-trivial (R9)
Invoque `superpowers:brainstorming` antes de codar quando feature tem qualquer ambiguidade.

### 2. Plano se 3+ arquivos (R9)
Invoque `superpowers:writing-plans`. Output: `docs/plans/<topic>.md` com tasks numeradas.

### 3. G-DELEGA pra cada task (R13)

| Característica da task | Para onde |
|---|---|
| Mecânica + plano explícito + ≤3 arquivos OU padrão repetido + fora de pasta sensível | DeepSeek (wrapper + trailer `Co-implemented-by: deepseek-v4`) |
| Decisão arquitetural / debug / pasta sensível (auth/payment/migrations) | Claude direto |
| 3+ tasks independentes | `superpowers:subagent-driven-development` OBRIGATÓRIO |

### 4. TDD pra endpoint novo (R9)
Invoque `superpowers:test-driven-development`. Vitest/pytest antes do código.

### 5. Pipeline R2: [0]→[1-S]→[2-E]→[3-H]→[4-C]→[5-T]
Avança SÓ com verificação. Não arredondar.

### 6. Review pre-commit (R11) — IMPORTANTE
**INVOQUE `/percus-review:review` ATIVAMENTE antes de commitar.** Não espere o hook bloquear — o hook é safety net, não fluxo.

Por quê: se commitar sem review, hook pre-commit bloqueia E você perde 5-10s de retrabalho. Rodar review proativamente é mais rápido E garante que findings são tratados antes do commit.

### 7. Marco
Invoque `percus-review:close-milestone` ao fechar fase/feature/épico (skill irmã).

### 8. Marcações visuais (R2)
- 🤖 = delegado pro DeepSeek (commit deve ter trailer `Co-implemented-by: deepseek-v4`)
- ✓ = milestone-review aprovado
- 🎨 = draft de design aprovado (R10)

## Gates inline (não esquece)

- **R1:** [5-T] só após ciclo CRUD completo (Criar→F5→Editar→F5→Deletar→F5)
- **R3:** mock = banner MODO DEMO + toast "salvo localmente"
- **R7:** auth Percus, nunca Supabase/NextAuth/localStorage pra JWT
- **R10:** tela nova = v0.dev/shadcn, nunca Claude artifacts em produção
- **R13:** trailer `Co-implemented-by: deepseek-v4` no commit se aplicar saída do wrapper

## Referência completa
`${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md`

## Skills upstream que invoco
Ver `${env:PERCUS_CANON_DIR}/comandos/USANDO_SUPERPOWERS.md` (tabela Tier 1).
```

- [ ] **Step 2: Validar tamanho do arquivo**

```bash
wc -c "${env:PERCUS_CANON_DIR}/plugin/percus-review/skills/feature-flow/SKILL.md"
```

Esperado: 3000-4500 bytes. Se > 5000, comprimir.

- [ ] **Step 3: Commit**

```bash
git add plugin/percus-review/skills/feature-flow/SKILL.md
git commit -m "feat(skills): add feature-flow skill orchestrating R1->R13 workflow"
```

---

## Task 5: Criar skill `close-milestone`

**Files:**
- Create: `plugin/percus-review/skills/close-milestone/SKILL.md`

- [ ] **Step 1: Criar SKILL.md**

Conteúdo:
```markdown
---
name: close-milestone
description: Use when closing a milestone in Percus project — end of numbered phase, feature group in epic, or "ready for next step" transition. Runs /percus-review:milestone-review and marks ✓ in PLANO/HANDOFF.
---

# Percus Close Milestone

Quando declarar marco fechado (fim de Fase X numerada, fim de feature em épico, ou "pronto, próxima etapa"), use este fluxo antes de marcar ✓.

## Fluxo

### 1. Identificar commit-inicio-marco

- **Default:** último commit do PLANO.md que tem ✓ (= marco anterior). Use `git log --all -p -S "✓" -- docs/PLANO.md | head -20` pra encontrar.
- **Se não houver marco anterior:** usar branch base (main/master). Confirmar com usuário se inseguro.
- **Inseguro?** Perguntar usuário em voz alta antes de prosseguir.

### 2. Rodar milestone-review (R11 ampliada)

\`\`\`
/percus-review:milestone-review --base <commit-inicio-marco>
\`\`\`

Roda DeepSeek + Cross-Claude duplo. Custo ~$0.05.

### 3. Tratar findings

- **Bug/regressão** → corrigir ANTES de fechar marco
- **Risco/violação Percus** → corrigir OU declarar em voz alta por que ignora
- **Preferência** → ignorar OK, declarar em voz alta

### 4. Marcar ✓ no PLANO + HANDOFF

Para cada feature afetada pelo marco, adicionar ✓ antes da tag de status:

```
- [5-T] Login OTP   →   - [5-T] ✓ Login OTP
```

Aplicar em `docs/PLANO.md` E `HANDOFF.md` (espelhos da R2).

### 5. Nota no HANDOFF.md

```markdown
## Marco {nome} fechado em {data}, milestone-review aprovado
- Features afetadas: {lista}
- Findings críticos tratados: {lista ou "nenhum"}
- Próximo marco: {descrição}
```

## Anti-padrões

- ❌ Marcar ✓ sem rodar milestone-review (R11 ampliada violada)
- ❌ Pular findings críticos
- ❌ Marcar ✓ retroativo em features já em [5-T] sem auditoria do escopo

## Referência
`${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md` R11 (Review cross-provider)
```

- [ ] **Step 2: Validar tamanho**

```bash
wc -c "${env:PERCUS_CANON_DIR}/plugin/percus-review/skills/close-milestone/SKILL.md"
```

Esperado: 1200-1800 bytes.

- [ ] **Step 3: Commit**

```bash
git add plugin/percus-review/skills/close-milestone/SKILL.md
git commit -m "feat(skills): add close-milestone skill for R11 milestone gate"
```

---

## Task 6: Atualizar `plugin.json` com seção `skills`

**Files:**
- Modify: `plugin/percus-review/plugin.json`

- [ ] **Step 1: Ler estado atual**

```bash
cat "${env:PERCUS_CANON_DIR}/plugin/percus-review/plugin.json"
```

- [ ] **Step 2: Adicionar campo `skills` (formato depende de Claude Code v2.x — confirmar via doc oficial ou via plugin existente como `superpowers-dev`)**

Inspecionar `~/.claude/plugins/superpowers-dev/plugin.json` como referência:
```bash
cat "$HOME/.claude/plugins/superpowers-dev/plugin.json" 2>&1 | head -50
```

Aplicar mesmo formato. Tipicamente:
```json
{
  "name": "percus-review",
  "version": "1.0.0",
  "description": "Review cross-provider Percus (DeepSeek + Cross-Claude)",
  "author": "Percus",
  "commands": "./commands",
  "scripts": "./scripts",
  "skills": "./skills"
}
```

- [ ] **Step 3: Reinstalar plugin pra registrar skills**

```
/plugin uninstall percus-review
/plugin install percus-review
```

- [ ] **Step 4: Validar skills disponíveis**

```
/plugin
```

Esperado: percus-review listado com 4 commands + 2 skills (feature-flow, close-milestone).

- [ ] **Step 5: Smoke test auto-trigger das skills**

Em sessão nova de teste, dizer: "implementa endpoint de produtos no projeto X"

Esperado: agente menciona ou invoca `feature-flow` skill (visível no transcript).

Se não auto-triggerar, anotar e seguir — calibragem D7.

- [ ] **Step 6: Commit**

```bash
git add plugin/percus-review/plugin.json
git commit -m "feat(plugin): register skills (feature-flow, close-milestone) in manifest"
```

---

## Task 7: Hook pre-commit — handlers PS+SH + smoke test

**Files:**
- Create: `plugin/percus-review/hooks/pre-commit-check.ps1`
- Create: `plugin/percus-review/hooks/pre-commit-check.sh`
- Create: `plugin/percus-review/tests/smoke-pre-commit.ps1`

- [ ] **Step 1: Escrever smoke test ANTES do hook (TDD-like)**

Conteúdo de `plugin/percus-review/tests/smoke-pre-commit.ps1`:
```powershell
#requires -Version 5.1
# Smoke test pre-commit hook

$ErrorActionPreference = "Stop"
$hookScript = Join-Path $PSScriptRoot "..\hooks\pre-commit-check.ps1"

function Test-Case {
    param([string]$Name, [string]$Stdin, [int]$ExpectedExit)
    $tmp = New-TemporaryFile
    $Stdin | Out-File -FilePath $tmp -Encoding utf8 -NoNewline
    Get-Content $tmp | & powershell -File $hookScript 2>&1 | Out-Null
    $actual = $LASTEXITCODE
    Remove-Item $tmp
    if ($actual -eq $ExpectedExit) {
        Write-Host "[PASS] $Name (exit $actual)" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name expected $ExpectedExit got $actual" -ForegroundColor Red
        return 1
    }
    return 0
}

# Caso 1: command sem 'git commit' → libera (exit 0)
$json1 = '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
$failed = 0
$failed += Test-Case "non-commit command" $json1 0

# Caso 2: command 'git commit' sem review recente → bloqueia (exit 2)
# (assume cwd não tem .deepseek/reviews/ recente)
$json2 = '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
$failed += Test-Case "git commit without recent review" $json2 2

# Caso 3: 'git commit --amend --no-edit' → libera (rebase exception)
$json3 = '{"tool_name":"Bash","tool_input":{"command":"git commit --amend --no-edit"}}'
$failed += Test-Case "amend no-edit (rebase)" $json3 0

if ($failed -eq 0) {
    Write-Host "`nAll smoke tests PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$failed tests FAILED" -ForegroundColor Red
    exit 1
}
```

- [ ] **Step 2: Rodar smoke test (deve FALHAR — hook não existe ainda)**

```powershell
powershell -File "${env:PERCUS_CANON_DIR}/plugin/percus-review/tests/smoke-pre-commit.ps1"
```

Esperado: erro "hook não encontrado" ou todos os testes falhando. Confirma que estamos no estado esperado pré-implementação.

- [ ] **Step 3: Implementar `pre-commit-check.ps1`**

Conteúdo (baseado no spec Seção 4.2):
```powershell
#requires -Version 5.1
# Hook pre-commit Percus — bloqueia commit sem /percus-review:review recente.
# Falha graceful: qualquer erro → exit 0.

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $command = $input.tool_input.command

    # Não-commit → libera
    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }

    # Amend sem edit (rebase) → libera
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }

    # Verificar se PERCUS_HOOKS_DISABLED tá ativo (escape)
    if ($env:PERCUS_HOOKS_DISABLED) { exit 0 }

    # Procurar review recente
    $cwd = (Get-Location).Path
    $reviewDir = Join-Path $cwd ".deepseek/reviews"
    if (-not (Test-Path $reviewDir)) {
        # Nenhum review jamais → bloqueia
        Write-Host "[percus:hook pre-commit] BLOCK: nenhum /percus-review:review encontrado em .deepseek/reviews/" -ForegroundColor Red
        Write-Host "Rode /percus-review:review antes de commitar (R11)." -ForegroundColor Yellow
        exit 2
    }

    $latest = Get-ChildItem $reviewDir -Filter "*.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Host "[percus:hook pre-commit] BLOCK: pasta .deepseek/reviews/ vazia" -ForegroundColor Red
        exit 2
    }

    $age = (Get-Date) - $latest.LastWriteTime
    if ($age.TotalMinutes -gt 5) {
        Write-Host "[percus:hook pre-commit] BLOCK: ultimo /percus-review:review tem $([math]::Round($age.TotalMinutes,1)) min (max 5)." -ForegroundColor Red
        Write-Host "Rode /percus-review:review de novo antes de commitar (R11)." -ForegroundColor Yellow
        exit 2
    }

    # Review fresco → libera
    exit 0
} catch {
    # Falha do hook não bloqueia workflow
    Write-Host "[percus:hook pre-commit] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
```

- [ ] **Step 4: Rodar smoke test (deve PASSAR agora)**

```powershell
powershell -File "${env:PERCUS_CANON_DIR}/plugin/percus-review/tests/smoke-pre-commit.ps1"
```

Esperado: 3 PASS.

- [ ] **Step 5: Implementar `pre-commit-check.sh` (espelho)**

Conteúdo:
```bash
#!/usr/bin/env bash
# Hook pre-commit Percus — graceful failure (exit 0 on any error)

set +e

STDIN=$(cat)
if [ -z "$STDIN" ]; then exit 0; fi

COMMAND=$(echo "$STDIN" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Non-commit
if ! echo "$COMMAND" | grep -qE '\bgit[[:space:]]+commit\b'; then exit 0; fi

# Amend no-edit (rebase)
if echo "$COMMAND" | grep -qE '\bgit[[:space:]]+commit[[:space:]]+--amend[[:space:]]+--no-edit\b'; then exit 0; fi

# Escape
if [ -n "${PERCUS_HOOKS_DISABLED:-}" ]; then exit 0; fi

REVIEW_DIR=".deepseek/reviews"
if [ ! -d "$REVIEW_DIR" ]; then
  echo "[percus:hook pre-commit] BLOCK: nenhum /percus-review:review em $REVIEW_DIR" >&2
  echo "Rode /percus-review:review antes de commitar (R11)." >&2
  exit 2
fi

LATEST=$(ls -t "$REVIEW_DIR"/*.jsonl 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
  echo "[percus:hook pre-commit] BLOCK: $REVIEW_DIR vazia" >&2
  exit 2
fi

# Age in seconds (300 = 5 min)
NOW=$(date +%s)
MTIME=$(stat -c %Y "$LATEST" 2>/dev/null || stat -f %m "$LATEST" 2>/dev/null)
AGE=$((NOW - MTIME))

if [ $AGE -gt 300 ]; then
  AGE_MIN=$(( AGE / 60 ))
  echo "[percus:hook pre-commit] BLOCK: ultimo review tem $AGE_MIN min (max 5)" >&2
  echo "Rode /percus-review:review de novo." >&2
  exit 2
fi

exit 0
```

`chmod +x plugin/percus-review/hooks/pre-commit-check.sh`.

- [ ] **Step 6: Commit**

```bash
git add plugin/percus-review/hooks/pre-commit-check.ps1 plugin/percus-review/hooks/pre-commit-check.sh plugin/percus-review/tests/smoke-pre-commit.ps1
git commit -m "feat(hooks): add pre-commit-check hook with smoke test

- Blocks commit if no /percus-review:review in last 5 min (R11 enforcement)
- Allows non-commit Bash, amend --no-edit, and PERCUS_HOOKS_DISABLED escape
- Graceful failure: any error returns exit 0 (never blocks via hook crash)"
```

---

## Task 8: Hook on-stop — handlers PS+SH + smoke test

**Files:**
- Create: `plugin/percus-review/hooks/on-stop-check.ps1`
- Create: `plugin/percus-review/hooks/on-stop-check.sh`
- Create: `plugin/percus-review/tests/smoke-on-stop.ps1`

- [ ] **Step 1: Escrever smoke test ANTES do hook (TDD)**

Conteúdo de `plugin/percus-review/tests/smoke-on-stop.ps1`:
```powershell
#requires -Version 5.1
$ErrorActionPreference = "Stop"
$hookScript = Join-Path $PSScriptRoot "..\hooks\on-stop-check.ps1"

# Cria 3 transcripts fake em pasta temp
$tmpDir = Join-Path $env:TEMP "percus-smoke-on-stop"
if (Test-Path $tmpDir) { Remove-Item -Recurse -Force $tmpDir }
New-Item -ItemType Directory -Path $tmpDir | Out-Null

# Caso 1: transcript sem edições (só Read tool calls)
$t1 = Join-Path $tmpDir "case1.jsonl"
@'
{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"foo.md"}}
{"type":"tool_use","tool_name":"Grep","tool_input":{"pattern":"x"}}
'@ | Out-File -FilePath $t1 -Encoding utf8

# Caso 2: edição em .tsx mas SEM edição em HANDOFF.md
$t2 = Join-Path $tmpDir "case2.jsonl"
@'
{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"src/Login.tsx"}}
{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"docs/PLANO.md"}}
'@ | Out-File -FilePath $t2 -Encoding utf8

# Caso 3: edição em .tsx + edição em HANDOFF.md
$t3 = Join-Path $tmpDir "case3.jsonl"
@'
{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"src/Login.tsx"}}
{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"HANDOFF.md"}}
'@ | Out-File -FilePath $t3 -Encoding utf8

function Test-Case {
    param([string]$Name, [string]$TranscriptPath, [int]$ExpectedExit)
    $stdin = (@{ transcript_path = $TranscriptPath } | ConvertTo-Json -Compress)
    $stdin | & powershell -File $hookScript 2>&1 | Out-Null
    $actual = $LASTEXITCODE
    if ($actual -eq $ExpectedExit) { Write-Host "[PASS] $Name (exit $actual)" -ForegroundColor Green; return 0 }
    else { Write-Host "[FAIL] $Name expected $ExpectedExit got $actual" -ForegroundColor Red; return 1 }
}

$failed = 0
$failed += Test-Case "case 1: no code edits" $t1 0
$failed += Test-Case "case 2: code edit without HANDOFF" $t2 2
$failed += Test-Case "case 3: code edit with HANDOFF" $t3 0

Remove-Item -Recurse -Force $tmpDir
if ($failed -eq 0) { Write-Host "`nAll PASSED" -ForegroundColor Green; exit 0 }
else { Write-Host "`n$failed FAILED" -ForegroundColor Red; exit 1 }
```

- [ ] **Step 2: Rodar smoke (deve FALHAR — hook não existe)**

```powershell
powershell -File "${env:PERCUS_CANON_DIR}/plugin/percus-review/tests/smoke-on-stop.ps1"
```

Esperado: erro "hook não encontrado" ou todos casos falhando.

- [ ] **Step 3: Implementar `on-stop-check.ps1` completo**

Conteúdo:
```powershell
#requires -Version 5.1
# Hook on-stop Percus — bloqueia stop se sessão tocou código sem atualizar HANDOFF.md (R8)
# Falha graceful: qualquer erro → exit 0

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $transcriptPath = $input.transcript_path
    if (-not $transcriptPath -or -not (Test-Path $transcriptPath)) { exit 0 }

    # Skip flag (escape pro user)
    if ($env:PERCUS_SKIP_HANDOFF) {
        $logDir = Join-Path (Get-Location) ".deepseek"
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        "$(Get-Date -Format 'o') | skip flag used | transcript=$transcriptPath" | Out-File -Append -FilePath (Join-Path $logDir "handoff-skipped.log") -Encoding utf8
        exit 0
    }

    # Extensões código vs não-código
    $codeExts = @('.py','.ts','.tsx','.js','.jsx','.sql','.go','.rs','.java','.css','.html','.vue','.svelte')
    $nonCodeExts = @('.md','.yml','.yaml','.json','.txt','.toml','.ini','.cfg','.gitignore','.env')

    $codeEdits = 0
    $handoffEdited = $false

    Get-Content $transcriptPath | ForEach-Object {
        if ($_ -match '"tool_name"\s*:\s*"(Edit|Write|NotebookEdit)"') {
            if ($_ -match '"file_path"\s*:\s*"([^"]+)"') {
                $file = $matches[1]
                $ext = [System.IO.Path]::GetExtension($file).ToLower()
                $base = [System.IO.Path]::GetFileName($file)
                if ($base -eq 'HANDOFF.md') { $handoffEdited = $true }
                elseif ($codeExts -contains $ext) { $codeEdits++ }
            }
        }
    }

    if ($codeEdits -eq 0) { exit 0 }
    if ($handoffEdited) { exit 0 }

    # Bloqueia
    Write-Host "[percus:hook on-stop] BLOCK: sessao tocou $codeEdits arquivo(s) de codigo mas HANDOFF.md nao foi atualizado (R8)." -ForegroundColor Red
    Write-Host "Atualize HANDOFF.md antes de encerrar OU defina PERCUS_SKIP_HANDOFF=1 com motivo declarado." -ForegroundColor Yellow
    exit 2
} catch {
    exit 0
}
```

- [ ] **Step 4: Rodar smoke (deve PASSAR)**

```powershell
powershell -File "${env:PERCUS_CANON_DIR}/plugin/percus-review/tests/smoke-on-stop.ps1"
```

Esperado: 3 PASS.

- [ ] **Step 5: Implementar `on-stop-check.sh` (espelho)**

Conteúdo:
```bash
#!/usr/bin/env bash
set +e

STDIN=$(cat)
[ -z "$STDIN" ] && exit 0

TRANSCRIPT=$(echo "$STDIN" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# Skip flag
if [ -n "${PERCUS_SKIP_HANDOFF:-}" ]; then
  mkdir -p .deepseek
  echo "$(date -Iseconds) | skip flag used | transcript=$TRANSCRIPT" >> .deepseek/handoff-skipped.log
  exit 0
fi

CODE_EXT_REGEX='\.(py|ts|tsx|js|jsx|sql|go|rs|java|css|html|vue|svelte)$'

CODE_EDITS=0
HANDOFF_EDITED=0

while IFS= read -r line; do
  if echo "$line" | grep -qE '"tool_name"[[:space:]]*:[[:space:]]*"(Edit|Write|NotebookEdit)"'; then
    FILE=$(echo "$line" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    [ -z "$FILE" ] && continue
    BASE=$(basename "$FILE")
    if [ "$BASE" = "HANDOFF.md" ]; then HANDOFF_EDITED=1
    elif echo "$FILE" | grep -qiE "$CODE_EXT_REGEX"; then CODE_EDITS=$((CODE_EDITS+1))
    fi
  fi
done < "$TRANSCRIPT"

[ $CODE_EDITS -eq 0 ] && exit 0
[ $HANDOFF_EDITED -eq 1 ] && exit 0

echo "[percus:hook on-stop] BLOCK: sessao tocou $CODE_EDITS arquivo(s) de codigo mas HANDOFF.md nao foi atualizado (R8)." >&2
echo "Atualize HANDOFF.md antes de encerrar OU defina PERCUS_SKIP_HANDOFF=1." >&2
exit 2
```

`chmod +x plugin/percus-review/hooks/on-stop-check.sh`.

- [ ] **Step 6: Commit**

```bash
git add plugin/percus-review/hooks/on-stop-check.ps1 plugin/percus-review/hooks/on-stop-check.sh plugin/percus-review/tests/smoke-on-stop.ps1
git commit -m "feat(hooks): add on-stop-check hook with smoke test

- Blocks Stop if session edited code but HANDOFF.md not updated (R8)
- Anti-false-positive: parses transcript, classifies edits by extension
- Skip flag PERCUS_SKIP_HANDOFF logs to .deepseek/handoff-skipped.log
- Graceful failure: exit 0 on any error"
```

---

## Task 9: Atualizar `plugin.json` com seção `hooks`

**Files:**
- Modify: `plugin/percus-review/plugin.json`

- [ ] **Step 1: Adicionar campo `hooks`**

```json
{
  "name": "percus-review",
  "version": "1.0.0",
  ...
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit-check.ps1"
      }
    ],
    "Stop": [
      {
        "command": "${CLAUDE_PLUGIN_ROOT}/hooks/on-stop-check.ps1"
      }
    ]
  }
}
```

**NOTA:** formato exato do campo `hooks` em plugin manifest é validado em Task 1 (T0a/T0b). Se diferente, ajustar.

- [ ] **Step 2: Reinstalar plugin**

```
/plugin uninstall percus-review
/plugin install percus-review
```

- [ ] **Step 3: Smoke test end-to-end pre-commit (cobre T2 do spec)**

1. Em projeto Fase 4 de teste, fazer Edit em `.py`
2. `git add` + `git commit -m "test"` via Bash tool
3. Esperado: hook bloqueia com mensagem orientativa
4. Rodar `/percus-review:review`
5. Repetir commit → libera

- [ ] **Step 3b: Smoke E2E pre-commit DOCS-ONLY (cobre T3 do spec)**

1. Edit só em `.md` (sem código)
2. `git add` + `git commit`
3. Esperado: hook libera com warning "commit só de docs, R11 dispensa"

- [ ] **Step 4: Smoke test end-to-end on-stop (cobre T5 do spec)**

Sessão de teste:
1. Edit em arquivo `.tsx`
2. Stop sem atualizar HANDOFF
3. Esperado: bloqueio
4. Editar HANDOFF + Stop de novo → libera

- [ ] **Step 4b: Smoke E2E on-stop SESSÃO DE CONSULTA (cobre T4 do spec)**

1. Sessão só com Read/Grep (zero edição)
2. Stop
3. Esperado: libera silenciosamente (zero atrito, T4)

- [ ] **Step 4c: Smoke E2E close-milestone skill (cobre T7 do spec)**

1. Em sessão de teste, dizer "fechamos a Fase 1"
2. Esperado: agente invoca skill `percus-review:close-milestone`, roda `/percus-review:milestone-review`, marca ✓ no PLANO

- [ ] **Step 5: Commit**

```bash
git add plugin/percus-review/plugin.json
git commit -m "feat(plugin): register hooks (pre-commit, on-stop) in manifest"
```

---

## Task 10: Atualizar canon (R8 + R9 + anti-padrões)

**Files:**
- Modify: `01_REGRAS_INEGOCIAVEIS.md`

- [ ] **Step 1: Atualizar R8** — adicionar parágrafo "Gate mecânico" após gate atual (ver spec Seção 4.3)

- [ ] **Step 2: Atualizar R9** — adicionar 2 linhas na tabela (`feature-flow`, `subagent-driven-development`) e bullet "Cobertura mecânica"

- [ ] **Step 3: Adicionar anti-padrões 17 e 18** na lista final

- [ ] **Step 4: Validar consistência**

`grep -n "feature-flow\|close-milestone\|subagent-driven" 01_REGRAS_INEGOCIAVEIS.md` — deve aparecer em R9 + anti-padrões.

- [ ] **Step 5: Commit**

```bash
git add 01_REGRAS_INEGOCIAVEIS.md
git commit -m "docs(canon): update R8/R9 with Fase 5 mechanic gates and skills"
```

---

## Task 11: Criar `comandos/USANDO_SUPERPOWERS.md`

**Files:**
- Create: `comandos/USANDO_SUPERPOWERS.md`

- [ ] **Step 1: Criar arquivo** com conteúdo completo da Seção 7 do brainstorming (tabela Tier 1 / Tier 2 / Skills internas Percus / Antipattern / Referências)

- [ ] **Step 2: Validar tamanho ~1.2 KB**

```bash
wc -c "${env:PERCUS_CANON_DIR}/comandos/USANDO_SUPERPOWERS.md"
```

- [ ] **Step 3: Linkar de R9 do canon**

Adicionar em R9: "Guia rápido de skills: `comandos/USANDO_SUPERPOWERS.md`."

- [ ] **Step 4: Commit**

```bash
git add comandos/USANDO_SUPERPOWERS.md 01_REGRAS_INEGOCIAVEIS.md
git commit -m "docs(commands): add USANDO_SUPERPOWERS guide and link from R9"
```

---

## Task 12: Atualizar `templates/PLANO.template.md` (referência a close-milestone)

**Files:**
- Modify: `templates/PLANO.template.md`

- [ ] **Step 1: Atualizar linha do `✓`** mencionando que fluxo é via `percus-review:close-milestone` skill

- [ ] **Step 2: Commit**

```bash
git add templates/PLANO.template.md
git commit -m "docs(templates): reference close-milestone skill for ✓ workflow"
```

---

## Task 13: Push branch fase5 + propagação

**Files:** nenhum novo, só git operations

- [ ] **Step 1: Push branch fase5 atualizada**

```bash
TOKEN=$(grep '^GIT_TOKEN_CLASSIC=' "D:/Claud Automations/Melhoria do prompt inicial/.env" | cut -d'=' -f2- | tr -d '"\r')
git push "https://huboperacional:${TOKEN}@github.com/huboperacional/percus-kit.git" fase5-superpowers-adoption
```

- [ ] **Step 2: Reinstalar plugin nos projetos Fase 4 já existentes**

Em cada projeto (Padrão Comportamento Humano, Plexco Tasks, etc):
```
/plugin uninstall percus-review
/plugin marketplace add ${env:PERCUS_CANON_DIR}/plugin   # se ainda não tem
/plugin install percus-review
```

Validar `/plugin` lista skills + hooks.

- [ ] **Step 3: Iniciar janela de calibração D3-D7 (uso real)**

Documentar em `HANDOFF.md` da metalibrary local: "Calibração Fase 5 começa em {data}. Reportar findings dia a dia."

---

## Task 14: D7 retrospectiva e merge

**Files:** nenhum novo

- [ ] **Step 1: Coletar dados (com comandos concretos)**

Adoção de `feature-flow` (target: ≥4 das próximas 5 features novas):
```bash
# Conta menções/invocações em transcripts da semana
grep -rE "feature-flow|percus-review:feature-flow" "$HOME/.claude/projects" --include="*.jsonl" | wc -l
```

Uso do skip flag `PERCUS_SKIP_HANDOFF`:
```bash
# Em cada projeto Percus ativo
find . -name "handoff-skipped.log" -path "*/.deepseek/*" -exec wc -l {} \;
```

Custo DeepSeek na semana: dashboard https://platform.deepseek.com/usage (target < $2/sem).

Commits que vieram do wrapper DeepSeek (R13):
```bash
git log --since="7 days ago" --grep="Co-implemented-by: deepseek" --oneline | wc -l
```

Mínimo viável de calibração (do spec):
- ≥5 features novas iniciadas + ≥10 commits totais entre D3 e D7
- Se uso menor: prolongar janela pra D14 antes de promover

- [ ] **Step 2: Avaliar critérios de pivô**
  - Pivô leve (>2 falsos positivos on-stop) → ajustar lista de extensões
  - Pivô médio (auto-trigger < 4/5) → reescrever description
  - Rollback (5+ reclamações/dia OU custo > $10/sem) → desativar via env var

- [ ] **Step 3: Aplicar tunings necessários** + commit

- [ ] **Step 4: Merge fase5 → main**

```bash
cd "${env:PERCUS_CANON_DIR}"
git checkout main
git merge --no-ff fase5-superpowers-adoption -m "feat: Fase 5 — Superpowers adoption (skills + hooks + canon)"
git tag v5.0.0
TOKEN=$(grep '^GIT_TOKEN_CLASSIC=' "D:/Claud Automations/Melhoria do prompt inicial/.env" | cut -d'=' -f2- | tr -d '"\r')
git push "https://huboperacional:${TOKEN}@github.com/huboperacional/percus-kit.git" main --tags
```

- [ ] **Step 5: Atualizar memória persistente**

Editar `project_fase4_review_routing.md` → marcar superseded e criar `project_fase5_superpowers_adoption.md` com snapshot final + metricas reais.

- [ ] **Step 6: Reportar conclusão Fase 5**

---

## Resumo das tasks

| # | Task | Tempo estimado |
|---|---|---|
| 1 | Smoke test formato real dos hooks | 30 min |
| 2 | Marketplace.json wrapper + validar instalação | 20 min |
| 3 | Atualizar SETUP/UPGRADE com nova sintaxe | 20 min |
| 4 | Skill feature-flow | 30 min |
| 5 | Skill close-milestone | 20 min |
| 6 | plugin.json + skills | 15 min |
| 7 | Hook pre-commit + smoke | 45 min |
| 8 | Hook on-stop + smoke | 60 min |
| 9 | plugin.json + hooks + smoke E2E | 30 min |
| 10 | Canon R8/R9 + anti-padrões | 20 min |
| 11 | USANDO_SUPERPOWERS guide | 15 min |
| 12 | PLANO.template ref close-milestone | 5 min |
| 13 | Push + propagação nos projetos | 30 min |
| 14 | D7 retrospectiva + merge + tag v5.0.0 | 60 min |

**Total estimado:** ~6-7h de trabalho (D1+D2 implementação + D3-D7 calibração passiva).

---

## Princípios de execução

- **DRY:** scripts PS e SH são espelhos — mantenha lógica idêntica, só sintaxe muda
- **YAGNI:** não adicione features de Open Questions / parking lot do spec; deixe pra Fase 6
- **TDD:** cada hook tem smoke test escrito ANTES da implementação (Tasks 7, 8 seguem isso)
- **Frequent commits:** 1 commit por task (no máximo 2 se task ficar grande)
- **Graceful failure:** hooks NUNCA bloqueiam por erro próprio — exit 0 + log
- **Calibragem honesta:** se Task 1 (smoke T0a/T0b) revelar formato diferente, AJUSTE Tasks 7-9 antes de continuar — não force assumption
