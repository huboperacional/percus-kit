# Task 6 — Registro de hooks no settings.json — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir um instalador idempotente (`scripts/registrar-hooks-settings.ps1`) que registra
os hooks de enforcement Percus (fonte da verdade: `hooks-manifest.json`) direto no `settings.json`,
com caminho absoluto pro `.cmd` do kit — sem depender da variavel `PERCUS_CANON_DIR` estar setada.

**Architecture:** um unico script PowerShell 5.1-compativel, no mesmo estilo de
`scripts/renomear-kit-local.ps1` (ASCII puro, valida JSON antes de gravar, faz backup datado,
`-DryRun` de primeira classe). Fonte da verdade e `plugin/percus-review/hooks/hooks-manifest.json`;
o script filtra por `-Escopo` (Guardas/Observadores/Todos), confere que cada `.cmd` existe em disco
ANTES de escrever qualquer coisa (fail-closed, licao do item 11 da medicao de 2026-07-31), faz merge
idempotente no `settings.json` existente (preserva hooks nao-relacionados, nao duplica em reexecucao),
e so entao grava com backup.

**Tech Stack:** PowerShell 5.1+, Pester (suite existente do repo).

**Contexto que este plano assume (nao redescobrir):**
- `docs/superpowers/plans/2026-07-31-enforcement-nao-silencioso.md` (Task 6 do plano 2) — decide o
  ramo (settings.json, caminho absoluto, ordem por risco) e documenta o cuidado do item 11.
- `docs/superpowers/medicoes/2026-07-31-semantica-hooks-harness.md` — os 12 itens medidos que
  sustentam as decisoes acima (especialmente item 2: enforcement duplo e real; item 6: nao emitir
  `async`; item 11: `command` malformado tranca a ferramenta inteira).
- `plugin/percus-review/hooks/hooks-manifest.json` — fonte unica da verdade dos 12 hooks
  registrados (8 guarda / 4 observador) + 1 orfao (`canon-version-check`, sempre excluido).
- `scripts/renomear-kit-local.ps1` — padrao ja testado de escrita segura em `settings.json`
  (`Update-SettingsJson`: valida JSON, faz backup datado, escreve UTF8 sem BOM).

**Escopo por risco (nao mudar sem reler a medicao):**
- `Guardas` (default) — so os 8 hooks `PreToolUse`. Seguro registrar JA, mesmo com o `hooks.json`
  do plugin ainda ativo: duplicar guarda so decide duas vezes o mesmo bloqueio (medido, item 2).
- `Observadores` — os 4 hooks `Stop`/`PreCompact`/`SessionStart`. So registrar DEPOIS de uma
  publicacao do plugin que esvazie as entradas correspondentes do `hooks.json` — observador
  duplicado e efeito colateral duplicado de verdade (ex.: `catalog_publish` faria POST duplicado).
- `Todos` — os 12. Para maquina onde o `hooks.json` do plugin ja esta vazio.

**Este plano NAO inclui:** publicar uma nova versao do plugin esvaziando `hooks.json` (isso e
trabalho separado, fora do escopo desta Task), nem aplicar o registro no `settings.json` REAL do
operador de forma automatica (Task 5, ao final, e manual e com portao de confirmacao explicito —
mutar o `settings.json` global do usuario e um sistema compartilhado por toda sessao Claude Code
na maquina, nao so por este projeto).

---

## File Structure

- Create: `scripts/registrar-hooks-settings.ps1` — script unico com as 3 responsabilidades
  (ler manifesto + filtrar por escopo + validar existencia; merge idempotente no settings; gravar
  com backup e suporte a `-DryRun`), seguindo o padrao de arquivo-unico ja usado por
  `scripts/renomear-kit-local.ps1`.
- Create: `plugin/percus-review/tests/registrar-hooks-settings.tests.ps1` — suite Pester, testando
  o script por invocacao completa (`& $script @params`), no mesmo estilo de
  `plugin/percus-review/tests/renomear-kit-local.tests.ps1` (nunca toca o `settings.json` real).

---

### Task 1: Esqueleto do script + leitura do manifesto por escopo

**Files:**
- Create: `scripts/registrar-hooks-settings.ps1`
- Test: `plugin/percus-review/tests/registrar-hooks-settings.tests.ps1`

- [ ] **Step 1: Escrever o teste que monta um kit falso e um settings vazio, roda em `-DryRun`, e confere que o escopo Guardas filtra certo**

```powershell
#requires -Version 5.1
# O script mexe no settings.json do usuario. O teste NUNCA toca o real: monta um par
# (kit falso com manifesto+wrappers + settings falso) e afere o resultado, mesmo padrao
# de plugin/percus-review/tests/renomear-kit-local.tests.ps1.

Describe "registrar-hooks-settings.ps1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\registrar-hooks-settings.ps1"
        $script:temps   = New-Object System.Collections.ArrayList

        # Kit falso: so o suficiente pra exercitar o script (manifesto pequeno, 2 guarda + 1
        # observador), sem precisar dos 12 hooks reais. O Task 5 cruza com o manifesto de
        # verdade separadamente.
        function New-KitFalso {
            param([bool]$ComWrappers = $true)
            $raiz = Join-Path ([IO.Path]::GetTempPath()) ("regh-kit-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            $hooksDir = Join-Path $raiz "plugin\percus-review\hooks"
            New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null

            $manifesto = @{
                hooks = @(
                    @{ nome = "guarda-um";  evento = "PreToolUse"; matcher = "Bash|PowerShell"; forma = "guarda";     registrado = $true }
                    @{ nome = "guarda-dois";evento = "PreToolUse"; matcher = "Bash|PowerShell"; forma = "guarda";     registrado = $true }
                    @{ nome = "obs-um";     evento = "Stop";       matcher = $null;             forma = "observador";registrado = $true }
                    @{ nome = "orfao";      evento = "SessionStart"; matcher = $null;           forma = "observador";registrado = $false }
                )
            } | ConvertTo-Json -Depth 10
            [IO.File]::WriteAllText((Join-Path $hooksDir "hooks-manifest.json"), $manifesto, (New-Object System.Text.UTF8Encoding($false)))

            if ($ComWrappers) {
                foreach ($nome in @("guarda-um", "guarda-dois", "obs-um")) {
                    [IO.File]::WriteAllText((Join-Path $hooksDir "$nome.cmd"), "@echo off`r`nexit /b 0`r`n", (New-Object System.Text.UTF8Encoding($false)))
                }
            }
            [void]$script:temps.Add($raiz)
            return $raiz
        }

        function New-SettingsFalso {
            param([hashtable]$Conteudo = @{})
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("regh-set-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $caminho = Join-Path $dir "settings.json"
            [IO.File]::WriteAllText($caminho, ($Conteudo | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
            [void]$script:temps.Add($dir)
            return $caminho
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "DryRun com escopo Guardas: reporta 2 hooks (os 2 de forma guarda), nao os observadores nem o orfao" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}

        $saida = & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings -DryRun *>&1 | Out-String

        $saida | Should -Match "2 hook"
        $saida | Should -Match "guarda-um"
        $saida | Should -Match "guarda-dois"
        $saida | Should -Not -Match "obs-um"
        $saida | Should -Not -Match "orfao"
    }
}
```

- [ ] **Step 2: Rodar e confirmar que falha (script ainda nao existe)**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/registrar-hooks-settings.tests.ps1' -Output Detailed"`
Expected: FAIL — `scripts\registrar-hooks-settings.ps1` nao encontrado / comando falha.

- [ ] **Step 3: Escrever o esqueleto do script — param block, resolucao de KitRoot/SettingsPath, leitura do manifesto, filtro por escopo, saida em DryRun**

```powershell
#requires -Version 5.1
<#
.SYNOPSIS
  Registra os hooks de enforcement Percus (guardas e/ou observadores) no settings.json,
  usando caminho absoluto para os wrappers do kit. Idempotente.
.DESCRIPTION
  ASCII PURO, sem excecao -- mesma disciplina do renomear-kit-local.ps1 (script irmao que
  mexe no mesmo settings.json): em dash dentro de string corrompe em PowerShell 5.1 sem BOM.

  Fonte da verdade dos hooks e hooks-manifest.json, dentro do proprio kit (plugin/percus-review/hooks/).

  Escopo por risco (Task 6 do plano 2 -- enforcement-nao-silencioso):
    Guardas       -- so os hooks PreToolUse. Seguro registrar junto com o hooks.json do
                     plugin, porque duplicar guarda so decide duas vezes o mesmo bloqueio.
    Observadores  -- os hooks Stop/PreCompact/SessionStart. So registrar depois de uma
                     publicacao do plugin que esvazie as entradas correspondentes do
                     hooks.json -- observador duplicado e efeito colateral duplicado de
                     verdade (ex.: POST duplicado), nao decisao redundante.
    Todos         -- todos os hooks registrados no manifesto. Para maquina onde o hooks.json
                     do plugin ja esta vazio.

  Valida a existencia de cada wrapper .cmd em disco ANTES de escrever qualquer coisa --
  registro parcial e pior que nenhum registro, porque mente sobre o que esta protegido.
#>
[CmdletBinding()]
param(
    [ValidateSet('Guardas','Observadores','Todos')]
    [string]$Escopo = 'Guardas',
    [string]$SettingsPath,
    [string]$KitRoot,
    [switch]$DryRun
)
$ErrorActionPreference = "Stop"

# Default calculado no corpo, nao no bloco param: mesma razao do renomear-kit-local.ps1 --
# expressao condicional em default de parametro e fragil entre PS 5.1 e 7.
if (-not $KitRoot) {
    $KitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $SettingsPath) {
    $claudeHome   = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
    $SettingsPath = Join-Path $claudeHome "settings.json"
}

$hooksDir     = Join-Path $KitRoot "plugin\percus-review\hooks"
$manifestPath = Join-Path $hooksDir "hooks-manifest.json"

if (-not (Test-Path $manifestPath)) { throw "manifesto nao encontrado: $manifestPath" }

$manifesto = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$vivos = @($manifesto.hooks | Where-Object { $_.registrado })

$formaAlvo = switch ($Escopo) {
    'Guardas'      { 'guarda' }
    'Observadores' { 'observador' }
    'Todos'        { $null }
}
if ($formaAlvo) {
    $vivos = @($vivos | Where-Object { $_.forma -ceq $formaAlvo })
}

# Fail-closed: confere TODOS antes de escrever qualquer coisa. Registro parcial mente sobre
# o que esta protegido -- licao do item 11 da medicao (command malformado tranca a maquina).
$faltando = New-Object System.Collections.Generic.List[string]
$hooks    = New-Object System.Collections.Generic.List[object]
foreach ($h in $vivos) {
    $cmdPath = Join-Path $hooksDir ($h.nome + ".cmd")
    if (-not (Test-Path $cmdPath)) {
        [void]$faltando.Add("$($h.nome): esperado em $cmdPath")
        continue
    }
    $absoluto = (Resolve-Path $cmdPath).Path
    $matcher  = if ($h.matcher) { "$($h.matcher)" } else { "" }
    [void]$hooks.Add([pscustomobject]@{
        Nome    = $h.nome
        Evento  = $h.evento
        Matcher = $matcher
        Command = $absoluto
        Forma   = $h.forma
    })
}

if ($faltando.Count -gt 0) {
    throw ("registro abortado: $($faltando.Count) hook(s) do manifesto sem wrapper .cmd em disco -- NADA foi gravado:`n" + ($faltando -join "`n"))
}

Write-Host "[registrar-hooks] $($hooks.Count) hook(s) no escopo '$Escopo', todos com wrapper confirmado em disco"
foreach ($h in $hooks) { Write-Host "[registrar-hooks]   - $($h.Nome) ($($h.Evento))" }

if ($DryRun) {
    Write-Host "[registrar-hooks] DRY RUN -- parando aqui (merge e escrita entram na Task 3)"
}
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/registrar-hooks-settings.tests.ps1' -Output Detailed"`
Expected: PASS — 1 teste, 0 falhas.

- [ ] **Step 5: Commit**

```bash
git add scripts/registrar-hooks-settings.ps1 plugin/percus-review/tests/registrar-hooks-settings.tests.ps1
git commit -m "feat(hooks): esqueleto do instalador settings.json + filtro por escopo"
```

---

### Task 2: Fail-closed quando falta wrapper em disco

**Files:**
- Modify: `plugin/percus-review/tests/registrar-hooks-settings.tests.ps1`

- [ ] **Step 1: Escrever o teste (manifesto cita um hook sem `.cmd` correspondente)**

```powershell
    It "aborta SEM escrever nada quando o manifesto cita um hook sem wrapper .cmd em disco" {
        $kit = New-KitFalso -ComWrappers $false
        $settings = New-SettingsFalso -Conteudo @{}
        $antes = Get-Content $settings -Raw

        { & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings -DryRun } |
            Should -Throw -ExpectedMessage "*sem wrapper*"

        (Get-Content $settings -Raw) | Should -Be $antes -Because "registro parcial mente sobre o que esta protegido -- nada pode ser gravado"
    }
```

- [ ] **Step 2: Rodar e confirmar que passa (o `throw` da Task 1 ja cobre isso)**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/registrar-hooks-settings.tests.ps1' -Output Detailed"`
Expected: PASS — 2 testes, 0 falhas. Se falhar, e sinal de que o `throw` da Task 1 nao esta
disparando antes de qualquer escrita; nenhuma mudanca de implementacao esperada aqui, so a prova.

- [ ] **Step 3: Commit**

```bash
git add plugin/percus-review/tests/registrar-hooks-settings.tests.ps1
git commit -m "test(hooks): prova que wrapper faltando aborta sem escrever nada"
```

---

### Task 3: Merge idempotente + escrita real com backup

**Files:**
- Modify: `scripts/registrar-hooks-settings.ps1`
- Modify: `plugin/percus-review/tests/registrar-hooks-settings.tests.ps1`

- [ ] **Step 1: Escrever os testes de merge (settings vazio recebe tudo; hook alheio e preservado; reexecucao nao duplica; backup datado aparece)**

```powershell
    It "registra no settings.json vazio e preserva hook alheio ja existente" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{
            hooks = @{ SessionStart = @(@{ matcher = ""; hooks = @(@{ type = "command"; command = "echo alheio" }) }) }
        }

        & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings | Out-Null

        $j = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $blocosPreToolUse = @($j.hooks.PreToolUse)
        $comandos = @($blocosPreToolUse | ForEach-Object { @($_.hooks) } | ForEach-Object { $_.command })
        ($comandos -join "|") | Should -Match "guarda-um\.cmd"
        ($comandos -join "|") | Should -Match "guarda-dois\.cmd"

        # o hook alheio de SessionStart sobrevive intacto
        $sessionStart = @($j.hooks.SessionStart)
        ($sessionStart | ForEach-Object { @($_.hooks) } | ForEach-Object { $_.command }) | Should -Contain "echo alheio"
    }

    It "reexecucao e idempotente: mesmo numero de blocos PreToolUse na segunda rodada" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}

        & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings | Out-Null
        $j1 = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $n1 = @($j1.hooks.PreToolUse).Count

        & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings | Out-Null
        $j2 = Get-Content $settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $n2 = @($j2.hooks.PreToolUse).Count

        $n2 | Should -Be $n1 -Because "rodar duas vezes nao pode duplicar bloco -- enforcement duplo e real (item 2 da medicao)"
    }

    It "faz backup datado do settings.json antes de sobrescrever" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}

        & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings | Out-Null

        @(Get-ChildItem (Split-Path $settings -Parent) -Filter "settings.json.bak-*").Count |
            Should -Be 1 -Because "primeira escrita sobrescreve um settings.json que ja existia (o fixture cria vazio antes)"
    }
```

- [ ] **Step 2: Rodar e confirmar que falha (merge e escrita real ainda nao existem -- so DryRun existe)**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/registrar-hooks-settings.tests.ps1' -Output Detailed"`
Expected: FAIL nos 3 testes novos (o script hoje para no DryRun / nao grava nada fora dele).

- [ ] **Step 3: Implementar o merge idempotente e a escrita real com backup, substituindo o bloco final do script (a partir do `if ($DryRun) { ... }` da Task 1)**

```powershell
if (-not $Settings) { } # placeholder removido -- ver corpo real abaixo
```

Substituir o trecho final do script (a partir de `if ($DryRun) {` da Task 1) por:

```powershell
$settingsAtual = if (Test-Path $SettingsPath) {
    try { Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw "settings.json JA esta invalido antes de qualquer mudanca ($SettingsPath). Conserte o JSON primeiro. NADA foi registrado." }
} else {
    [pscustomobject]@{}
}

if (-not $settingsAtual.PSObject.Properties['hooks']) {
    $settingsAtual | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}

$adicionados = New-Object System.Collections.Generic.List[string]
$jaPresentes = New-Object System.Collections.Generic.List[string]

foreach ($h in $hooks) {
    if (-not $settingsAtual.hooks.PSObject.Properties[$h.Evento]) {
        $settingsAtual.hooks | Add-Member -NotePropertyName $h.Evento -NotePropertyValue @()
    }
    $blocos = @($settingsAtual.hooks.($h.Evento))

    $normAlvo = ($h.Command -replace '/', '\').ToLowerInvariant()
    $jaTem = $false
    foreach ($b in $blocos) {
        foreach ($hk in @($b.hooks)) {
            $normExistente = ("$($hk.command)".Trim('"') -replace '/', '\').ToLowerInvariant()
            if ($normExistente -eq $normAlvo) { $jaTem = $true; break }
        }
        if ($jaTem) { break }
    }

    if ($jaTem) {
        [void]$jaPresentes.Add($h.Nome)
        continue
    }

    $novoBloco = [pscustomobject]@{
        matcher = $h.Matcher
        hooks   = @([pscustomobject]@{ type = "command"; command = $h.Command })
    }
    $settingsAtual.hooks.($h.Evento) = @($blocos) + $novoBloco
    [void]$adicionados.Add($h.Nome)
}

if ($adicionados.Count -eq 0) {
    Write-Host "[registrar-hooks] nada novo -- todos os $($hooks.Count) hook(s) do escopo ja estavam registrados em $SettingsPath"
} else {
    Write-Host "[registrar-hooks] novo(s): $($adicionados -join ', ')"
}
if ($jaPresentes.Count -gt 0) {
    Write-Host "[registrar-hooks] ja presentes (pulados): $($jaPresentes -join ', ')"
}

$texto = $settingsAtual | ConvertTo-Json -Depth 20
try { $null = $texto | ConvertFrom-Json }
catch { throw "resultado seria JSON invalido -- NADA foi gravado em '$SettingsPath'" }

if ($DryRun) {
    Write-Host "[registrar-hooks] DRY RUN -- nada foi gravado. Conteudo proposto:"
    Write-Host $texto
    return
}

$backup = $null
if (Test-Path $SettingsPath) {
    $stamp  = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    $backup = "$SettingsPath.bak-$stamp"
    Copy-Item -LiteralPath $SettingsPath -Destination $backup
} else {
    $pai = Split-Path $SettingsPath -Parent
    if ($pai -and -not (Test-Path $pai)) { New-Item -ItemType Directory -Path $pai -Force | Out-Null }
}
[IO.File]::WriteAllText($SettingsPath, $texto, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[registrar-hooks] gravado em $SettingsPath$(if ($backup) { " (backup: $backup)" })"
```

(Remover a linha-placeholder `if (-not $Settings) { }` -- ela existe so pra marcar onde o bloco
da Task 1 termina; o texto real e o bloco acima, colado no lugar do antigo `if ($DryRun) { ... }`.)

- [ ] **Step 4: Rodar e confirmar que TODOS os testes passam (5 no total ate aqui)**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/registrar-hooks-settings.tests.ps1' -Output Detailed"`
Expected: PASS — 5 testes, 0 falhas.

- [ ] **Step 5: Commit**

```bash
git add scripts/registrar-hooks-settings.ps1 plugin/percus-review/tests/registrar-hooks-settings.tests.ps1
git commit -m "feat(hooks): merge idempotente + escrita real com backup datado"
```

---

### Task 4: JSON pre-existente invalido aborta sem mexer em nada

**Files:**
- Modify: `plugin/percus-review/tests/registrar-hooks-settings.tests.ps1`

- [ ] **Step 1: Escrever o teste**

```powershell
    It "settings.json JA invalido antes de qualquer mudanca: aborta e nao mexe no arquivo" {
        $kit = New-KitFalso
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("regh-set-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $settings = Join-Path $dir "settings.json"
        [IO.File]::WriteAllText($settings, "{ isto nao e json valido", (New-Object System.Text.UTF8Encoding($false)))
        [void]$script:temps.Add($dir)
        $antes = Get-Content $settings -Raw

        { & $script:script -Escopo Guardas -KitRoot $kit -SettingsPath $settings } |
            Should -Throw -ExpectedMessage "*JA esta invalido*"

        (Get-Content $settings -Raw) | Should -Be $antes
        @(Get-ChildItem $dir -Filter "settings.json.bak-*").Count | Should -Be 0 -Because "nada deveria ter sido tentado, nem backup"
    }
```

- [ ] **Step 2: Rodar e confirmar que passa (o `try/catch` da Task 3 ja cobre isso)**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/registrar-hooks-settings.tests.ps1' -Output Detailed"`
Expected: PASS — 6 testes, 0 falhas.

- [ ] **Step 3: Commit**

```bash
git add plugin/percus-review/tests/registrar-hooks-settings.tests.ps1
git commit -m "test(hooks): prova que settings.json invalido preexistente aborta sem tocar no arquivo"
```

---

### Task 5: Escopo Observadores/Todos + regressao contra o manifesto REAL do kit

**Files:**
- Modify: `plugin/percus-review/tests/registrar-hooks-settings.tests.ps1`

- [ ] **Step 1: Escrever os testes (escopo Observadores/Todos no kit falso + contagem 8/4/12 no kit REAL)**

```powershell
    It "escopo Observadores filtra so o hook de forma observador" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}
        $saida = & $script:script -Escopo Observadores -KitRoot $kit -SettingsPath $settings -DryRun *>&1 | Out-String
        $saida | Should -Match "1 hook"
        $saida | Should -Match "obs-um"
        $saida | Should -Not -Match "guarda-um"
    }

    It "escopo Todos inclui guarda e observador, nunca o orfao" {
        $kit = New-KitFalso
        $settings = New-SettingsFalso -Conteudo @{}
        $saida = & $script:script -Escopo Todos -KitRoot $kit -SettingsPath $settings -DryRun *>&1 | Out-String
        $saida | Should -Match "3 hook"
        $saida | Should -Not -Match "orfao"
    }

    It "contra o manifesto REAL do kit: Guardas=8, Observadores=4, Todos=12 -- todos com wrapper em disco" {
        # Regressao de verdade: usa o hooks-manifest.json e os .cmd reais do proprio repo,
        # nao o kit falso. Prova que o script bate com o que hooks-manifest.tests.ps1 ja
        # afirma sobre o mundo real (8 guarda / 4 observador / 12 total).
        $settings = New-SettingsFalso -Conteudo @{}

        $saidaGuardas = & $script:script -Escopo Guardas -KitRoot $script:kitRoot -SettingsPath $settings -DryRun *>&1 | Out-String
        $saidaGuardas | Should -Match "8 hook"

        $saidaObs = & $script:script -Escopo Observadores -KitRoot $script:kitRoot -SettingsPath $settings -DryRun *>&1 | Out-String
        $saidaObs | Should -Match "4 hook"

        $saidaTodos = & $script:script -Escopo Todos -KitRoot $script:kitRoot -SettingsPath $settings -DryRun *>&1 | Out-String
        $saidaTodos | Should -Match "12 hook"
    }
```

- [ ] **Step 2: Rodar e confirmar que passa**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/registrar-hooks-settings.tests.ps1' -Output Detailed"`
Expected: PASS — 9 testes, 0 falhas. Se o teste "contra o manifesto REAL" falhar com contagem
diferente de 8/4/12, ISTO NAO E BUG DO SCRIPT — e o manifesto real tendo mudado desde que este
plano foi escrito; conferir `hooks-manifest.tests.ps1` (que afirma a mesma contagem) antes de
mexer em qualquer coisa.

- [ ] **Step 3: Rodar a suite inteira pra confirmar que nada quebrou**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path plugin/percus-review/tests | Select-String 'Tests Passed'"`
Expected: contagem de testes passando maior que a anterior (baseline + 9 novos), 0 falhas.

- [ ] **Step 4: Commit**

```bash
git add plugin/percus-review/tests/registrar-hooks-settings.tests.ps1
git commit -m "test(hooks): escopo Observadores/Todos + regressao contra hooks-manifest.json real"
```

---

### Task 6 (MANUAL, fora de TDD) — Aplicar de verdade no settings.json global do operador

**NAO automatizar este passo dentro de uma sessao autonoma.** `settings.json` do usuario e lido por
TODA sessao Claude Code na maquina, nao so por projetos Percus — um erro aqui tem raio de alcance
maior que este kit (e o proprio item 11 da medicao mostrou auto-lockout real). Isto e uma checklist
pro operador (ou pra uma sessao que tenha pedido e recebido confirmacao explicita ANTES de cada
passo que grava).

- [ ] **Passo 1 — Dry run, so pra ver o que mudaria:**

```powershell
pwsh -NoProfile -File "scripts\registrar-hooks-settings.ps1" -Escopo Guardas -DryRun
```

Ler a saida com atencao: confirmar que sao 8 hooks, todos os 8 nomes esperados
(`pre-plan-exit`, `pre-commit-check`, `mock-scan-pre-commit`, `auth-import-pre-commit`,
`migration-check-pre-commit`, `types-check-pre-commit`, `external-action-guard`,
`crud-evidence-warn`), e que o `settings.json` alvo (mostrado no rodape) e mesmo o
`$env:USERPROFILE\.claude\settings.json` esperado.

- [ ] **Passo 2 — Confirmacao explicita do operador antes de gravar de verdade.** Sem `-DryRun`.

```powershell
pwsh -NoProfile -File "scripts\registrar-hooks-settings.ps1" -Escopo Guardas
```

- [ ] **Passo 3 — Verificar que o backup foi criado e que o settings.json continua JSON valido:**

```powershell
Get-ChildItem "$env:USERPROFILE\.claude\settings.json.bak-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw | ConvertFrom-Json | Out-Null
```

- [ ] **Passo 4 — Canario real: abrir uma sessao nova em qualquer projeto Percus e confirmar que uma
acao que uma guarda bloquearia (ex.: `git push --dry-run`) continua bloqueada — agora com DOIS
registros ativos (plugin + settings.json), o que e esperado e seguro nesta fase (Guardas).**

- [ ] **NAO rodar `-Escopo Observadores` nem `-Escopo Todos` ainda.** Isso fica pra depois que uma
publicacao do plugin esvaziar as 4 entradas de observador do `hooks.json` (`on-stop-check`,
`state-drift-check`, `pre-compact-checkpoint`, `enforcement-health`) — ver "Escopo por risco" no
topo deste plano. Registrar isso como pendencia explicita (memoria ou `HANDOFF.md`) quando a Task
6 chegar ate aqui.

---

## Self-Review

**Cobertura do spec (Task 6 do plano 2):**
- "registro vai para o settings.json, caminho absoluto, instalador idempotente" — Tasks 1-3.
- "nao depende de variavel" — `Resolve-Path` grava caminho absoluto resolvido, nunca `${VAR}`.
- "ordem por risco: guardas, publicacao, observadores" — `-Escopo` default `Guardas` + nota
  explicita na Task 6 barrando `Observadores`/`Todos` ate a publicacao acontecer.
- "valida o JSON e a existencia de cada command em disco antes de salvar" — Task 1 (existencia,
  fail-closed antes de qualquer escrita) + Task 3/4 (JSON valido, tanto o resultado quanto o
  arquivo pre-existente).
- "backup datado" — Task 3.
- Nao emitir `async` (item 6 da medicao) — o objeto `hooks` montado nunca inclui esse campo.

**Placeholder scan:** a unica linha marcada como placeholder (`if (-not $Settings) { }` na Task 3)
e proposital e documentada — existe so pra ancorar o "substituir a partir daqui" no texto do plano,
nao entra no arquivo final.

**Consistencia de tipos:** `Get-HooksParaRegistrar`/`Add-HooksAoSettings`/`Backup-EGravarSettings`
descritas no design inicial foram achatadas em um script unico (sem chamadas de funcao entre elas)
porque o padrao ja estabelecido no repo (`renomear-kit-local.ps1` + seu teste) testa por invocacao
completa do script, nao por unidade de funcao interna — seguir o padrao existente em vez de
introduzir uma convencao de `scripts/lib/` nova so pra este script.
