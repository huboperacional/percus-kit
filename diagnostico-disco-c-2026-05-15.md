---
tipo: diagnostico-operacional
data: 2026-05-15
autor: Claude Opus 4.7 + operador
projeto-ref: Refatoracao estrategica Percus, Eixo E
---

# Diagnostico disco C: — 2026-05-15

Maquina: `criativo66@WIN-...`
User profile: `C:\Users\Criativo66`

## Estado das drives

| Drive | Usado | Livre | Total | % Livre |
|---|---|---|---|---|
| **C:** | 448.84 GB | **16.32 GB** | 465.16 GB | **3.5%** ← critico |
| D: | 656.47 GB | 3069.54 GB | 3726.01 GB | 82.4% |
| E: | 277.17 GB | 654.32 GB | 931.5 GB | 70.2% |
| H: | 809.94 GB | 2916.06 GB | 3726.01 GB | 78.3% |
| I: | 809.94 GB | 2916.06 GB | 3726.01 GB | 78.3% |

## Distribuicao em C:\

- `C:\Users` — 296 GB (dominante)
- `C:\Program Files` — 54.58 GB
- `C:\Windows` — 46.63 GB
- `C:\Program Files (x86)` — 16.55 GB
- `C:\temp` — 0.86 GB

## Distribuicao em C:\Users\

- **Criativo66** — 244.16 GB (user ativo)
- Edicao — 51.67 GB (user secundario)

## Top 10 em C:\Users\Criativo66\

| Pasta | Tamanho | Categoria |
|---|---|---|
| **Videos** | **126.26 GB** | Gravacoes pessoais (OBS, FL Ao Vivo, partidas de poker) — nao-movivel automatico |
| **AppData** | **100.42 GB** | Caches e dados de apps — alvo principal |
| Documents | 8.10 GB | dados pessoais |
| Downloads | 3.62 GB | limpaveis |
| .vscode | 1.66 GB | extensions VS Code |
| dwhelper | 1.25 GB | DownloadHelper Firefox |
| Pictures | 1.05 GB | dados pessoais |
| Creative Cloud Files | 0.67 GB | dados Adobe |
| .claude | 0.5 GB | config CLI Claude — ja em D: parcialmente (.claude-home) |

### Videos (detalhe — total 126 GB, NAO sera movido automaticamente)

- `FL Ao Vivo 2020/` — 43.37 GB
- `OBS Old/` — 30.38 GB
- Arquivos diretos `.mkv` na raiz Videos:
  - `2026-03-17 10-31-02.mkv` — 23.89 GB
  - `2025-11-20 11-16-53.mkv` — 6.34 GB
  - `2026-04-25 09-23-27.mkv` — 2.98 GB
  - `2026-04-25 14-10-28.mkv` — 2.76 GB
  - `2026-03-16 16-12-52.mkv` — 1.9 GB

**Decisao operador:** mover/deletar `Videos\` resolve 126 GB de uma vez. Recomendacao:
- Move `Videos\` inteira pra `D:\Videos\` ou `H:\Videos\`.
- Comando: `robocopy "C:\Users\Criativo66\Videos" "D:\Videos" /MOVE /E /MT:8 /R:1 /W:1`.
- Symlink opcional: `New-Item -ItemType SymbolicLink -Path "C:\Users\Criativo66\Videos" -Target "D:\Videos"` (apos mover).

## AppData\Local (~100 GB, top 18)

| Pasta | GB | Categoria | Acao |
|---|---|---|---|
| Google | 19.33 | Chrome cache+sync | nao mover (afeta browser; pode limpar cache via UI) |
| CapCut | 9.79 | Cache video editor | manual via app |
| **npm-cache** | **5.42** | cache npm | **MOVER pra D:\caches\npm-cache** ✓ |
| Packages | 4.73 | Microsoft Store apps cache | nao mover (Windows-gerenciado) |
| Programs | 4.33 | apps per-user (Claude Code CLI, etc) | nao mover sem cuidado |
| Microsoft | 3.20 | Edge/Office caches | nao mover |
| Perplexity | 2.16 | cache Perplexity desktop | manual |
| WebEx | 1.53 | cache WebEx | manual |
| **Temp** | **1.40** | temp Windows | **LIMPAR** ✓ |
| **Python** | **1.34** | user site-packages | **MOVER (usar venv por projeto, ja e canon)** ✓ |
| **ms-playwright** | **0.97** | cache Playwright | **MOVER pra D:** ✓ |
| slack | 0.84 | cache | manual |
| Discord | 0.84 | cache | manual |
| Mozilla | 0.76 | cache Firefox | nao mover |
| RealtimeBoard | 0.67 | Miro cache | manual |
| puccinialin | 0.65 | desconhecido | investigar |
| SquirrelTemp | 0.64 | instaladores antigos | LIMPAR |
| Navegador C6 Bank | 0.52 | browser banco | nao mover |

## AppData\Roaming (~30 GB, top 18)

| Pasta | GB | Categoria | Acao |
|---|---|---|---|
| **Claude** | **11.30** | cache + transcripts Claude Code CLI | **MOVER pra D:\caches\Claude** ✓ |
| Adobe | 9.15 | preferencias + cache Creative Cloud | nao mover (Adobe gerenciado) |
| GGPCOM | 1.44 | poker | nao mover |
| Notion | 1.39 | cache desktop | nao mover (Notion gerenciado) |
| Zoom | 1.25 | cache + gravacoes | LIMPAR antigas |
| Code | 1.25 | VS Code per-user (extensions+state) | symlink opcional |
| Slack | 1.24 | cache | manual |
| NVIDIA | 0.94 | driver cache | nao mover |
| **Python** | **0.82** | Python config user | mover junto com Local\Python ✓ |
| dolphin_anty | 0.80 | anti-detect browser | nao mover (dependencias HW) |
| Opera Software | 0.77 | browser | nao mover |
| **npm** | **0.66** | node_modules global | **MOVER (npm config set prefix)** ✓ |
| RealtimeBoard | 0.66 | Miro | manual |
| discord | 0.47 | cache | manual |
| ClickUp | 0.33 | cache | manual |
| Mozilla | 0.30 | Firefox | nao mover |
| Poker | 0.26 | dados | nao mover |
| com.adobe.dunamis | 0.25 | Adobe service | nao mover |

## Plano de movimentacao automatizavel (Fase 2)

**Movimentar agora (sem reboot, sem UI):**

| Origem | Destino | Mecanismo | GB liberados |
|---|---|---|---|
| `%LOCALAPPDATA%\npm-cache` | `D:\caches\npm-cache` | `npm config set cache D:\caches\npm-cache --global` + delete origem | ~5.4 |
| `%APPDATA%\npm` (prefix global) | `D:\caches\npm-global` | `npm config set prefix D:\caches\npm-global` + delete origem | ~0.7 |
| `%APPDATA%\Claude` | `D:\caches\Claude-Code` | mover + symlink ou env var | ~11.3 |
| `%LOCALAPPDATA%\ms-playwright` | `D:\caches\ms-playwright` | env `PLAYWRIGHT_BROWSERS_PATH=D:\caches\ms-playwright` + reinstalar | ~1.0 |
| `%LOCALAPPDATA%\pip\Cache` (se existir) | `D:\caches\pip` | env `PIP_CACHE_DIR=D:\caches\pip` + delete origem | varia |
| `%LOCALAPPDATA%\Temp` | — | `cleanmgr` + delete arquivos > 30 dias | ~1.0 |

Total estimado liberado em Fase 2: **~19 GB**.

**Fase 3 (requer UI/reboot — operador):**

- Docker Desktop disk image: Settings → Resources → Disk image location → mover para `D:\Docker\`.
- WSL2 distros: `wsl --shutdown`, `wsl --export Ubuntu D:\WSL\Ubuntu.tar`, `wsl --unregister Ubuntu`, `wsl --import Ubuntu D:\WSL\Ubuntu D:\WSL\Ubuntu.tar`.
- Pagefile.sys: System Properties → Performance → Virtual Memory → mover pra D:.
- Hiberfil.sys: `powercfg /h off` se nao usa hibernacao.

**Fase 4 (limpeza final):**

- `cleanmgr` Disk Cleanup completo (Windows Update cache, etc).
- `dism /online /Cleanup-Image /StartComponentCleanup /ResetBase`.
- Remover instaladores antigos em `SquirrelTemp`.

## Recomendacao operacional pos-Fase 2

1. **Liberar 19 GB automatico** → C: vai de 16 GB pra ~35 GB livres.
2. **Operador decide sobre Videos** (126 GB) — mover pra D: libera C: pra ~160 GB livres.
3. **Fase 3 (Docker/WSL)** opcional — se voce usa Docker Desktop com WSL2 ativo, vale.

## Status execucao

- [x] **Fase 1 — Diagnostico** (este doc).
- [x] **Fase 2 — Movimentacoes automatizadas** — executada 2026-05-15.
- [ ] **Fase 3 — Docker + WSL + pagefile** (operador, requer UI/reboot).
- [ ] **Fase 4 — Limpeza final** (`cleanmgr`).
- [ ] **Decisao operador:** Videos\ — manter / mover / deletar?
- [ ] **Canon update:** criar `AMBIENTE_LOCAL_OPERADOR.md` (Eixo B).

## Resultado Fase 2 (2026-05-15)

**Espaco C: antes:** 16.32 GB livres (3.5%)
**Espaco C: depois:** 25.49 GB livres (5.5%)
**Liberado:** ~9 GB

### Executado

- [x] `npm config set cache D:\caches\npm-cache` — global config.
- [x] `npm-cache` movido C:\Users\Criativo66\AppData\Local\npm-cache → D:\caches\npm-cache (5.4 GB).
- [x] env var `PIP_CACHE_DIR=D:\caches\pip` (user scope, permanente).
- [x] pip cache movido C:\Users\...\pip\Cache → D:\caches\pip.
- [x] env var `PLAYWRIGHT_BROWSERS_PATH=D:\caches\ms-playwright` (user scope, permanente).
- [x] ms-playwright movido C:\Users\...\ms-playwright → D:\caches\ms-playwright (1 GB).
- [x] env var `HF_HOME=D:\caches\huggingface` (user scope, permanente — preparado pra uso futuro).
- [x] SquirrelTemp limpo (0.64 GB).
- [x] Temp > 14 dias scan (nada removido — arquivos todos recentes ou em uso).

### Pendencias proximas (requer operador)

**Pra liberar mais ~12-30 GB sem mexer em Videos:**

1. **Claude AppData (11.3 GB)** — `%APPDATA%\Claude\`.
   - Requer Claude Code/CLI **fechado**.
   - Comando (rodar com Claude Code parado):
     ```powershell
     # Mover
     robocopy "$env:APPDATA\Claude" "D:\caches\Claude" /E /MOVE /MT:8 /R:1 /W:1
     # Symlink junction (sem precisar admin)
     New-Item -ItemType Junction -Path "$env:APPDATA\Claude" -Target "D:\caches\Claude"
     ```
   - Risco: medio. Validar abrindo Claude Code apos.

2. **npm global prefix (0.7 GB)** — `%APPDATA%\npm\`.
   - Quebra CLIs globais ate `npm i -g <pacote>` reinstalar cada um.
   - Listar antes: `npm ls -g --depth=0 --json > npm-globals-backup.json`.
   - Depois: `npm config set prefix D:\caches\npm-global` + ajustar PATH (adicionar `D:\caches\npm-global`).
   - Reinstalar cada um.

3. **Adobe Roaming (9.15 GB)** — `%APPDATA%\Adobe\`.
   - Adobe gerenciado; mover sem suporte oficial pode quebrar Creative Cloud.
   - Alternativa: limpar `Adobe\Common\Media Cache` e `Media Cache Files` via Premiere/After Effects Preferences.

4. **Google Chrome cache (19.33 GB em `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache`)**:
   - Limpar via Chrome: Settings → Privacy → Clear browsing data → Cached images and files.
   - Ganho: ate ~15 GB.

5. **CapCut cache (9.79 GB)** — limpar via UI do app.

**Pra Fase 3 (requer reboot):**

- [x] **Docker Desktop disk image** → `D:\Docker\` — confirmado pelo operador 2026-05-15.
- [ ] **WSL2 distros** — `wsl --shutdown`, `wsl --export <distro>`, `wsl --unregister`, `wsl --import D:\WSL\<distro>`.
- [ ] **Pagefile.sys** — System Properties → Advanced → Performance → Virtual Memory → mover pra D:.
- [ ] **Hiberfil.sys** — `powercfg /h off` se nao usa hibernacao.

**Em andamento pelo operador:**

- [x] Videos (126 GB) — movendo pra outra drive (operador confirmou 2026-05-15).

**Decisao critica do operador:**

- `C:\Users\Criativo66\Videos\` tem **126 GB de gravacoes** (OBS, FL Ao Vivo, partidas de poker antigas).
- Mover/deletar libera 126 GB → C: ficaria com ~150 GB livres (excelente).
- Comando: `robocopy "C:\Users\Criativo66\Videos" "D:\Videos" /MOVE /E /MT:8 /R:1 /W:1`
- Verificar antes se algum video desses ainda e relevante.
