---
tipo: comando-pronto
quando-usar: 1ª vez configurando review cross-provider Percus (DeepSeek + Cross-Claude) num projeto — substitui SETUP_CODEX_REVIEWER
nao-toca-codigo: true
leitura: 4 min (execução: ~5 min se faltar tudo, ~1 min se só falta o plugin)
ultima-atualizacao: 2026-05-03
---

# Setup — Review Cross-Provider Routing (Fase 4)

> Cole este prompt no agente Claude Code do projeto onde quer ativar review cross-provider.
> O agente vai detectar o que falta, instalar o plugin `@percus/review`, criar `AGENTS.md` slim e validar com smoke test.
> Não toca código de negócio. Só configura ferramentas.

---

## Objetivo

Habilitar **review cross-provider** (DeepSeek API + Cross-Claude subagent) antes de cada commit e em cada marco. Substitui Codex CLI (descontinuado em 2026-05-03 por custo).

**Estimativa de custo após setup:** $2-5/mês total em uso normal (vs $200-400/mês com Codex).

**Cobertura cross-provider mantida:** DeepSeek Inc + Anthropic = 2 organizações independentes auditando o mesmo diff.

---

## O que o agente vai fazer (na ordem, com gates)

### Passo 1 — Diagnóstico

> ⚠️ **CRÍTICO:** plugins do Claude Code ficam em `$env:CLAUDE_CONFIG_DIR` (custom) ou `~/.claude/` (default). Em máquinas Percus o custom é `D:\Claud Automations\.claude-home\`. Detecte o path real antes de checar — `~/.claude/` vai dar falso-negativo.

```powershell
# Detectar config dir REAL do Claude Code
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
$settingsFile = Join-Path $claudeHome "settings.json"

# DeepSeek API key carregada?
Select-String -Path .env -Pattern '^DEEPSEEK_API_KEY=' -Quiet

# Plugin percus-review habilitado em settings.json (fonte da verdade)?
if (Test-Path $settingsFile) {
    $cfg = Get-Content $settingsFile -Raw | ConvertFrom-Json
    $cfg.enabledPlugins.PSObject.Properties.Name | Where-Object { $_ -match 'percus-review|@percus' }
}
# Fallback: pasta do plugin presente em disco?
Get-ChildItem (Join-Path $claudeHome "plugins") -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'percus-review|@percus' }

# AGENTS.md presente na raiz do projeto?
Test-Path AGENTS.md

# .gitignore tem .deepseek/?
Select-String -Path .gitignore -Pattern '^\.deepseek/' -Quiet

# Resíduo Codex (precisa ser limpo se Fase 2 anterior foi aplicada)?
Test-Path .codex
Select-String -Path CLAUDE.md, AGENTS.md -Pattern '/codex:review|codex CLI|gpt-5' -Quiet
```

Reportar matriz e pedir confirmação.

---

### Passo 2 — Instalar plugin `@percus/review` (se ausente)

Plugin local do kit em `D:/Claud Automations/_Novo_Projeto/plugin/percus-review/`. Instalação a nível de usuário (1× por máquina, vale pra todos os projetos).

**Caminho A — CLI standalone (preferido)**

```powershell
# Abrir Claude Code CLI
claude
```

No chat:
```
/plugin marketplace add huboperacional/percus-kit
/plugin install percus-review
```

**Caminho alternativo (sem internet, kit local):**
```
/plugin marketplace add D:/Claud Automations/_Novo_Projeto
/plugin install percus-review
```

**Caminho B — UI Extensão VS Code**

`/plu` → Manage plugins → aba Plugins → "Install from local" → cola o path acima.

Após instalar: `/codex:status`-equivalente não existe ainda, validar com `/percus-review:review` no smoke do Passo 5.

---

### Passo 3 — Validar `DEEPSEEK_API_KEY`

Se ausente do `.env` do projeto: PARAR. Instruir usuário a obter chave em https://platform.deepseek.com e adicionar:
```
DEEPSEEK_API_KEY=sk-xxx...
```

Não criar placeholder. Aguardar confirmação.

---

### Passo 4 — Criar/atualizar `AGENTS.md` na raiz do projeto

Usar template slim em `D:/Claud Automations/_Novo_Projeto/templates/AGENTS.template.md` (~4.4 KB).

Substitui qualquer `AGENTS.md` Codex-era no projeto (que era ~7.3 KB). Se já existe AGENTS.md, mesclar — preservar seções "O que é este projeto" e "Stack" se já preenchidas.

**Se projeto tem `GEMINI.md` (espelho-3):** aplicar mesma reescrita lá.

---

### Passo 5 — Atualizar `.gitignore`

Adicionar (se ausente):
```gitignore
.deepseek/
```

`.deepseek/runs/` (logs DeepSeek-impl, R13) e `.deepseek/reviews/` (logs DeepSeek-review, R11) ficam ambos em `.deepseek/` — uma linha cobre os dois.

---

### Passo 6 — Smoke test

```powershell
# Garantir que existe diff
"smoke" | Out-File _smoke.md -Encoding utf8
git add _smoke.md
```

No chat Claude Code:
```
/percus-review:review
```

Esperado:
1. Router decide `deepseek` (caminho default — `_smoke.md` não toca pasta sensível)
2. DeepSeek retorna findings em < 5s (provavelmente "Sem findings críticos.")
3. Custo no dashboard DeepSeek: ~$0.001-0.01

Se falhar:
- API key inválida → conferir `.env`
- Plugin não responde → `/plugin reload` ou reabrir VS Code
- DeepSeek API down → router faz fallback automático pra Cross-Claude (Sonnet subagent)

**Limpar:** `rm _smoke.md && git restore --staged _smoke.md`

---

### Passo 6.5 — Instalar git hook nativo (Layer 2 anti-bypass, v5.0.8+)

PreToolUse:Bash do plugin tem brecha em comandos compostos (`rm -rf .deepseek/reviews && git commit` burla porque PreToolUse avalia estado antes do bash rodar). `.git/hooks/pre-commit` nativo do git fecha essa brecha — dispara no momento real do commit, e cobre commits do terminal direto fora do Claude Code.

Pedir ao usuário rodar no chat:

```
/percus-review:install-git-hooks
```

(Slash command precisa ser disparado pelo usuário, não pelo agente.)

Comando é idempotente: instala se ausente, atualiza se já era versão Percus, aborta se detectar hook custom não-Percus.

Smoke do bypass (opcional, autoriza usuário antes — custo ~$0.01):
1. `/percus-review:review` → gera review fresco
2. `rm -rf .deepseek/reviews && git commit -m "tentativa de bypass"`
3. ESPERADO: hook nativo BLOCK com stderr `[percus:hook pre-commit native] BLOCK: nenhum review...`

---

### Passo 7 — Migração de projeto Fase 2 anterior (se aplicável)

Se diagnóstico do Passo 1 detectou resíduo Codex:

```powershell
# Remover .codex/ (config local Codex, não rastreada por git)
Remove-Item -Recurse -Force .codex -ErrorAction SilentlyContinue

# Remover linha .codex/ do .gitignore (opcional — não dá problema deixar)
# Não obrigatório
```

Atualizar `CLAUDE.md` do projeto: substituir qualquer seção "Code review cross-provider (R11)" antiga (que mencionava `/codex:review`) pela nova:

```markdown
## Code review cross-provider (R11)

`/percus-review:review` é obrigatório em DOIS momentos:
1. Antes de cada commit que muda código
2. Ao concluir cada marco de plano

Em commit pré-commit: router auto decide DeepSeek / Cross-Claude / duplo (matriz em `D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md` R11).
Em marco: `/percus-review:milestone-review --base <commit-inicio-marco>` (DeepSeek + Cross-Claude duplo).

Sem review nos últimos 5min antes do commit → não pode commitar.
Plugin Codex (`codex@openai-codex`) descontinuado em 2026-05-03 por custo.
```

Aplicar mesma substituição em `AGENTS.md` e `GEMINI.md` (se espelho-3 ativo).

---

### Passo 8 — Reportar ao usuário

```
SETUP REVIEW ROUTING CONCLUÍDO — {Nome do Projeto}

✅ Plugin @percus/review instalado (versão X.Y.Z)
✅ DEEPSEEK_API_KEY validada (.env do projeto)
✅ AGENTS.md slim criado/atualizado (~4.4 KB)
✅ .gitignore com .deepseek/
✅ Smoke /percus-review:review respondeu OK
✅ Git hook nativo (.git/hooks/pre-commit, v5.0.8+) instalado
✅ Resíduo Codex limpo (se aplicável)

Próximo commit obrigatoriamente passa por /percus-review:review.
Próximo marco obrigatoriamente passa por /percus-review:milestone-review --base <commit>.

Custo estimado mensal: $2-5 total (vs $200-400 com Codex anterior).
```

---

## Anti-padrões durante o setup

- ❌ Pular Passo 3 (DEEPSEEK_API_KEY) e tentar smoke — vai falhar com 401
- ❌ Não migrar `.codex/` em projeto Fase 2 anterior — fica config morto no repo
- ❌ Esquecer `.deepseek/` no `.gitignore` — vaza logs de review pro repo
- ❌ Manter referências a `/codex:review` no `CLAUDE.md` após migração — gera ruído de "comando não encontrado"

---

## Pegadinhas conhecidas

| Sintoma | Causa | Solução |
|---|---|---|
| `/percus-review:review` retorna "command not found" | Plugin não instalado ou Claude Code não reiniciado | Reload do VS Code após `/plugin install` |
| DeepSeek retorna 401 | API key inválida ou expirada | Conferir `DEEPSEEK_API_KEY` no `.env`, regenerar em platform.deepseek.com |
| PowerShell 5.1 erro UTF-8 no wrapper | Bug conhecido | Wrapper já tem fix `[System.Text.Encoding]::UTF8.GetBytes` aplicado |
| Router decide errado em commit misto (sensível + trivial) | Conservador por design | Qualquer arquivo em pasta sensível → escala pra duplo. Comportamento esperado |

---

## Pré-requisitos resumidos

- [ ] `DEEPSEEK_API_KEY` no `.env` do projeto
- [ ] Plugin `@percus/review` instalado a nível de usuário (1× por máquina)
- [ ] `AGENTS.md` na raiz do projeto (template slim)
- [ ] `.deepseek/` no `.gitignore`
- [ ] Smoke `/percus-review:review` respondeu
- [ ] Git hook nativo instalado: `/percus-review:install-git-hooks` (1× por projeto)
- [ ] (Se Fase 2 anterior) `.codex/` removido + referências `/codex:review` substituídas

---

## Referências

- Plugin: `D:/Claud Automations/_Novo_Projeto/plugin/percus-review/`
- Template AGENTS.md slim: `D:/Claud Automations/_Novo_Projeto/templates/AGENTS.template.md`
- R11 detalhada: `D:/Claud Automations/_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md`
- Matriz de routing: `D:/Claud Automations/_Novo_Projeto/04_MODEL_ROUTING.md` seção "Roteamento de revisores"
- DeepSeek API: https://platform.deepseek.com
