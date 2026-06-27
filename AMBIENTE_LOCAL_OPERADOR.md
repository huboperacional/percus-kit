---
tipo: configuracao-maquina
prevalece-sobre: nenhum (orientação operacional)
prevalecido-por: [01_REGRAS_INEGOCIAVEIS]
quando-usar: ao configurar máquina nova OU recuperar de "C: cheio" OU adicionar nova API key sem precisar tocar em cada projeto
leitura: 4 min
ultima-atualizacao: 2026-05-17
fase-introducao: Fase 6 (Eixo E do plano de refatoração)
---

# Ambiente Local do Operador — convenção Percus

> **Por que existe:** projetos Percus moram em `D:\Claud Automations\`. Caches de ferramentas (npm, pip, HF, Playwright, Claude Code) **NÃO** devem encher `C:\Users\<user>\AppData\`. **API keys do kit Percus** (DeepSeek, Groq, Anthropic, Painel) ficam em env vars User-scope — assim qualquer projeto novo já enxerga sem precisar copiar pra `.env` local. Esta convenção define as env vars padrão.

---

## Princípio

Caches e dados volumosos de ferramentas dev moram em `D:\caches\<ferramenta>\`. Configuração persiste via **env vars de usuário** (Windows: `[Environment]::SetEnvironmentVariable('NOME', 'valor', 'User')`).

Vantagens:
- `C:` permanece para o sistema operacional + apps instalados.
- Mover entre máquinas é trivial (copia env vars + pasta).
- Limpeza/auditoria centralizada.

---

## Env vars obrigatórias (rodar uma vez)

```powershell
# Pip cache
[Environment]::SetEnvironmentVariable('PIP_CACHE_DIR', 'D:\caches\pip', 'User')

# Playwright (Chromium etc.)
[Environment]::SetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH', 'D:\caches\ms-playwright', 'User')

# HuggingFace
[Environment]::SetEnvironmentVariable('HF_HOME', 'D:\caches\huggingface', 'User')

# npm cache (via npm config, não env var)
npm config set cache 'D:\caches\npm-cache' --global

# Yarn cache (se usar yarn)
# yarn config set cache-folder 'D:\caches\yarn-cache'

# pnpm store (se usar pnpm)
# pnpm config set store-dir 'D:\caches\pnpm-store'
```

Após setar, **reabrir o terminal** pra env vars persistentes carregarem.

---

## Path do canon Percus — `PERCUS_CANON_DIR` (CRÍTICO — define UMA vez)

**Problema que resolve:** comandos do canon (UPGRADE_PARA_FASE6, SCOPE_COUNCIL, etc) e templates (CLAUDE.template, AGENTS.template) referenciam paths do canon via `${env:PERCUS_CANON_DIR}/...`. Sem essa env var apontando pra onde você clonou o repo `huboperacional/percus-kit`, qualquer comando colado em projeto-alvo quebra com "path não existe".

**Bootstrap por máquina nova** (faça uma vez, ver `comandos/SETUP_NOVA_MAQUINA.md` pra automação):

```powershell
# 1. Clonar o canon onde preferir (ex: D:\Claud Automations\_Novo_Projeto, C:\dev\percus-kit, $HOME\percus-kit)
git clone https://github.com/huboperacional/percus-kit.git "D:\Claud Automations\_Novo_Projeto"

# 2. Apontar a env var pro path escolhido
[Environment]::SetEnvironmentVariable('PERCUS_CANON_DIR', 'D:\Claud Automations\_Novo_Projeto', 'User')

# 3. REABRIR todos os terminais (VS Code + PowerShell) — env vars persistentes só carregam em processos novos
```

**Verificar:**
```powershell
$canon = [Environment]::GetEnvironmentVariable('PERCUS_CANON_DIR', 'User')
"PERCUS_CANON_DIR: $canon"
"Existe: $(Test-Path $canon)"
"CANON_VERSION: $(Get-Content (Join-Path $canon 'CANON_VERSION.md') -TotalCount 5 -ErrorAction SilentlyContinue)"
```

**Manter sincronizado:** mensalmente (ou quando alguém anunciar release), `cd $env:PERCUS_CANON_DIR && git pull origin main` pra puxar mudanças do canon.

---

## API keys do kit Percus (User-scope — define UMA vez, vale pra todos projetos)

**Problema que resolve:** todo projeto novo Percus precisa de DeepSeek + Groq + Anthropic + Painel keys. Antes desta seção, cada projeto pedia `.env` local com as 4-5 keys, repetidamente. Solução: env vars User-scope. Wrappers (`deepseek.ps1`, `groq-llama.ps1`, `cross-claude.ps1`, etc) já fazem `if (-not $env:KEY) { load .env do cwd }` — se a key já estiver no env do user, eles enxergam sem precisar `.env` no projeto.

**Override por projeto continua funcionando:** se um projeto precisar de chave dedicada (ex: cliente próprio com sua conta Anthropic), basta criar `.env` na raiz com `ANTHROPIC_API_KEY=sk-...` — o `.env` do cwd vence o User-scope (ordem dos wrappers: env atual → load .env se ausente).

```powershell
# DeepSeek (R11 review + R13 implementador)
[Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', 'sk-...', 'User')

# Groq (Llama 3.3 70B, conselho 3-membros Fase 6+)
[Environment]::SetEnvironmentVariable('GROQ_API_KEY', 'gsk_...', 'User')

# Anthropic (wrapper Cross-Claude direto com cache_control — Fase 6 v6.3.0+)
[Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', 'sk-ant-...', 'User')

# Painel Ads4Pros (catalog-publish e on-stop hook)
[Environment]::SetEnvironmentVariable('PAINEL_API_URL', 'https://api.ads4pros.com', 'User')
[Environment]::SetEnvironmentVariable('CATALOG_INGEST_KEY', '...', 'User')
```

**Após setar, REABRIR todos os terminais** (VS Code + PowerShell) pra env vars persistentes recarregarem.

**Como obter cada key:**

| Key | Onde obter | Plano gratuito? |
|---|---|---|
| `DEEPSEEK_API_KEY` | https://platform.deepseek.com | Não — pay-as-you-go, ~$0.27/Mtoken in |
| `GROQ_API_KEY` | https://console.groq.com | **Sim** — free tier 30 req/min |
| `ANTHROPIC_API_KEY` | https://console.anthropic.com | Pay-as-you-go, $3-15/Mtoken in |
| `PAINEL_API_URL` | Fixo em `https://api.ads4pros.com` (interno Percus) | — |
| `CATALOG_INGEST_KEY` | Operador (você) — gerar/recuperar do Painel admin | — |

**Verificação rápida pós-setup:**
```powershell
@('DEEPSEEK_API_KEY','GROQ_API_KEY','ANTHROPIC_API_KEY','PAINEL_API_URL','CATALOG_INGEST_KEY') | ForEach-Object {
    $v = [Environment]::GetEnvironmentVariable($_, 'User')
    [PSCustomObject]@{ Key = $_; Set = [bool]$v; Preview = if ($v) { $v.Substring(0,[Math]::Min(8,$v.Length)) + '…' } else { '' } }
}
```

**Anti-pattern explícito:** NÃO commite `.env` com essas keys em nenhum repo. `.env` está no `.gitignore` global do kit. Se você precisa de override por projeto, use `.env` local (gitignored).

---

## Env vars opcionais (avançado)

```powershell
# npm global prefix (CUIDADO: quebra CLIs até reinstalar cada um com `npm i -g <pacote>`)
# npm config set prefix 'D:\caches\npm-global'
# E adicionar 'D:\caches\npm-global' no PATH do usuário.

# Claude Code transcripts/cache (se variável existir — verificar versão)
# [Environment]::SetEnvironmentVariable('CLAUDE_TRANSCRIPT_DIR', 'D:\caches\Claude-Code', 'User')

# Temp do Windows (NÃO recomendado mover — afeta tudo no SO)
# Limpar periodicamente: `cleanmgr` Windows Disk Cleanup.
```

---

## Estrutura recomendada em `D:\caches\`

```
D:\caches\
├── npm-cache\           # cache npm (download de pacotes)
├── npm-global\          # node_modules globais (CLIs)
├── pip\                 # cache pip
├── ms-playwright\       # binaries Playwright (Chromium, Firefox, WebKit)
├── huggingface\         # cache HF (models, datasets)
├── Claude-Code\         # opcional, se mover Claude AppData
├── pnpm-store\          # opcional, se usar pnpm
└── yarn-cache\          # opcional, se usar yarn
```

---

## Pendências habituais que precisam ação manual

Itens que NÃO podem ser movidos só por env var. Operador faz uma vez:

| Item | Como mover | Risco |
|---|---|---|
| **Docker Desktop disk image** | Settings → Resources → Disk image location → `D:\Docker\` | Baixo (Docker faz nativo, mantém containers/imagens) |
| **WSL2 distros** | `wsl --shutdown` → `wsl --export <distro> D:\WSL\<distro>.tar` → `wsl --unregister <distro>` → `wsl --import <distro> D:\WSL\<distro> D:\WSL\<distro>.tar` | Médio (precisa reboot + reimport) |
| **Pagefile.sys** | System Properties → Advanced → Performance → Virtual Memory → mover pra D: | Médio (reboot) |
| **Hiberfil.sys** | `powercfg /h off` (se não usa hibernação) | Baixo |
| **Claude AppData (`%APPDATA%\Claude`)** | Com Claude Code fechado: `robocopy "%APPDATA%\Claude" "D:\caches\Claude" /E /MOVE` + `New-Item -ItemType Junction -Path "%APPDATA%\Claude" -Target "D:\caches\Claude"` | Médio (precisa Claude Code parado durante o move) |

---

## Verificação rápida (rodar periodicamente)

```powershell
# Espaço em todas as drives
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | Select-Object Name, @{N='UsedGB';E={[math]::Round($_.Used/1GB,2)}}, @{N='FreeGB';E={[math]::Round($_.Free/1GB,2)}}

# Confirmar env vars caches
[Environment]::GetEnvironmentVariable('PIP_CACHE_DIR', 'User')
[Environment]::GetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH', 'User')
[Environment]::GetEnvironmentVariable('HF_HOME', 'User')
npm config get cache

# Confirmar env vars do kit Percus (canon path + API keys)
@('PERCUS_CANON_DIR','DEEPSEEK_API_KEY','GROQ_API_KEY','ANTHROPIC_API_KEY','PAINEL_API_URL','CATALOG_INGEST_KEY') | ForEach-Object {
    $v = [Environment]::GetEnvironmentVariable($_, 'User')
    "$_ : $(if ($v) { 'OK' } else { 'MISSING' })"
}

# Confirmar pasta D:\caches existe e tem conteúdo
Get-ChildItem D:\caches -Force | Select-Object Name, @{N='SizeGB';E={[math]::Round((Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum/1GB,2)}}
```

---

## Checklist de início de sessão (passo "0")

Adicionar em `checklists/CHECKLIST_INICIO_SESSAO.md`:

```
[0] Confirmar caches em D: (uma vez por máquina):
    - npm config get cache → deve retornar D:\caches\npm-cache
    - PIP_CACHE_DIR → deve ser D:\caches\pip
    - C:\ deve ter ≥ 30 GB livres
```

Se algum item falhar, rodar setup desta doc antes de qualquer trabalho.

---

## Histórico

- **2026-05-15**: introdução desta doc após diagnóstico de C: cheio (16 GB livres em 465 GB total). Eixo E do plano "Refatoração estratégica Percus".
- **2026-05-17 (v6.4.0)**: seção "API keys do kit Percus (User-scope)" adicionada. Resolve "todo projeto novo pede as mesmas 5 keys".
- **2026-05-17 (v6.5.0)**: seção "Path do canon Percus — `PERCUS_CANON_DIR`" adicionada. Resolve "todo comando do canon referencia `D:\Claud Automations\_Novo_Projeto` que só existe na máquina do operador principal". Canon agora é portável — opera de qualquer path, basta apontar a env var. Comandos do canon migraram pra `${env:PERCUS_CANON_DIR}/...` em vez de path hardcoded.
