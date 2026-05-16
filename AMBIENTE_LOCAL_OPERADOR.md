---
tipo: configuracao-maquina
prevalece-sobre: nenhum (orientação operacional)
prevalecido-por: [01_REGRAS_INEGOCIAVEIS]
quando-usar: ao configurar máquina nova OU recuperar de "C: cheio"
leitura: 3 min
ultima-atualizacao: 2026-05-15
fase-introducao: Fase 6 (Eixo E do plano de refatoração)
---

# Ambiente Local do Operador — convenção Percus

> **Por que existe:** projetos Percus moram em `D:\Claud Automations\`. Caches de ferramentas (npm, pip, HF, Playwright, Claude Code) **NÃO** devem encher `C:\Users\<user>\AppData\`. Esta convenção define as env vars padrão.

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

# Confirmar env vars
[Environment]::GetEnvironmentVariable('PIP_CACHE_DIR', 'User')
[Environment]::GetEnvironmentVariable('PLAYWRIGHT_BROWSERS_PATH', 'User')
[Environment]::GetEnvironmentVariable('HF_HOME', 'User')
npm config get cache

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

## Referências

- Diagnóstico inicial: `diagnostico-disco-c-2026-05-15.md`
- Plano: `D:\Claud Automations\.claude-home\plans\criei-a-pasta-d-claud-warm-patterson.md` (Eixo E)
