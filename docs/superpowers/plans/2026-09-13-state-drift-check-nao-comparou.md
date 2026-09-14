# `state-drift-check` deixa de sair verde calado — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o hook `Stop` `state-drift-check` passa a (1) ler as tarefas de `docs/plano/*.md` em projeto fatiado e (2) avisar sem bloquear, por `systemMessage` e uma vez por sessão, quando não consegue comparar PLANO com HANDOFF — em vez de sair 0 calado em 25 de 29 projetos.

**Architecture:** o `.ps1` (runtime real: `powershell.exe` 5.1, chamado pelo trampolim `.cmd`) ganha três funções pequenas — fonte do plano, predicado "tem tarefa", aviso "não comparou" — e o bloco principal passa a desviar para o aviso quando o HANDOFF não rende linha de tag. O `.sh` (Python embutido) espelha as mesmas três decisões. A divergência continua bloqueando com exit 2, sem mudança.

**Tech Stack:** Windows PowerShell 5.1 (hook), pwsh 7 + Pester 5 (testes), bash + python3 (porta `.sh`), git.

**Spec:** `docs/superpowers/specs/2026-09-12-plano-hub-gerado-design.md` — RF21, RF22, RF22a, RF22b, RF22c, SC4 e o teste T23. É o **plano 1** do Pacote B; `plano-sync`, `crud-evidence-warn` e o texto do canon ficam para planos seguintes.

## Global Constraints

- **Runtime do hook é PowerShell 5.1:** o `.cmd` chama `powershell.exe`. Nada de `??`, ternário, `Join-Path` com mais de um filho, `-AdditionalChildPath`. O `ps51-compat.tests.ps1` afere parse, não runtime — por isso o teste 27 roda o hook no `powershell.exe` de verdade.
- **Fonte do `.ps1` do hook em ASCII puro** (ele não tem BOM); caractere não-ASCII só por code point (`[char]0x2014`), como o arquivo já faz.
- **Todo arquivo de dados lido pelo hook com `-Encoding UTF8`** (`hooks-leitura-utf8.tests.ps1`).
- **Paridade `.ps1`/`.sh`:** mesmas decisões e mesmo `systemMessage`; provada por teste que roda os dois contra o mesmo fixture.
- **Pester:** um só `BeforeAll`/`AfterAll` por bloco (`pester-blocos-unicos.tests.ps1`). Edite os arquivos de teste com a ferramenta Edit; se usar script, preserve o BOM que o arquivo tiver (`head -c3 arquivo | od -An -tx1` antes e depois).
- **Mensagem do aviso, literal** (uma linha, ASCII): `[percus:hook state-drift] NAO COMPAROU: <handoff> nao tem a secao "Status de Features" com linhas de tag (templates/HANDOFF.template.md) -- a divergencia de status PLANO x HANDOFF nao e verificada neste projeto. Nada foi bloqueado.` — `<handoff>` é o caminho relativo ao `cwd`, com `/` (`docs/HANDOFF.md` ou `HANDOFF.md`). *Diferença deliberada em relação ao texto de RF22:* o trecho "com linhas de tag" foi acrescentado para a mensagem ser verdadeira também no caso "a seção existe mas está vazia".
- **Marca por sessão:** `<cwd>/.deepseek/state-drift/<session_id>.flag`, com `session_id` sanitizado apagando tudo fora de `[A-Za-z0-9_\-]` (mesma regra do `context-budget-guard.ps1:59`). `session_id` vazio depois de sanitizar: avisa e não marca. Falha ao gravar a marca: avisa mesmo assim.
- **Marcador de projeto fatiado:** linha que casa `^<!-- plano-format: \d+ -->` em `docs/PLANO.md`.
- **Tag canônica:** exatamente `[0]`, `[1-S]`, `[2-E]`, `[3-H]`, `[4-C]`, `[5-T]`. "Linha de tarefa" = bullet `-`/`*` com tag canônica (opcionalmente entre crases), fora de bloco de código cercado.
- **Suíte do kit nunca em paralelo consigo mesma** (um teste grava no `hooks-manifest.json` real). Antes de rodar, confira que não há outra execução.
- **Commit:** caminho **literal** no `git -C` (nunca `"$VAR"`: o `pre-commit-check` lê o texto do comando e não expande variável — verbete `hook-le-o-cwd-nao-a-raiz-do-git`), `git add` e `git commit` por pathspec só dos arquivos da tarefa (checkout compartilhado entre sessões), R11 com `deepseek-review.ps1` antes de todo commit que leva `.ps1`/`.sh`.
- **R20:** o plano termina em commit local. Push (que publica o hook para a frota) só com autorização do operador.

---

## Estrutura de arquivos

| Arquivo | Responsabilidade | Tarefas |
|---|---|---|
| `plugin/percus-review/hooks/state-drift-check.ps1` | o hook (runtime 5.1) | 1, 2 |
| `plugin/percus-review/hooks/state-drift-check.sh` | porta Unix, mesma decisão | 3 |
| `plugin/percus-review/tests/state-drift-check.tests.ps1` | testes do `.ps1` e a paridade do `.sh` | 1, 2, 3 |
| `CANON_VERSION.md`, `plugin/percus-review/plugin.json`, `.claude-plugin/marketplace.json`, `.percus-version` | versão 6.54.0 (via `scripts/bump-canon.ps1`) | 4 |
| `docs/superpowers/plans/2026-09-12-enforcement-regras-sem-hook.md`, a spec | estado da execução | 4 |

`hooks.json` e `hooks-manifest.json` **não mudam**: o hook já está registrado no `Stop`, com a mesma assinatura e o mesmo escape.

**Rodar um arquivo de teste** (de qualquer diretório):

```powershell
Invoke-Pester -Path 'D:\Claud Automations\percus-kit\plugin\percus-review\tests\state-drift-check.tests.ps1' -Output Detailed
```

---

### Task 1: Fonte das tarefas em projeto fatiado (RF21)

**Files:**
- Modify: `plugin/percus-review/hooks/state-drift-check.ps1` (função `Read-PlanoFeatures`, linhas 51-63; bloco principal, linhas 103-116; função nova antes de `Read-PlanoFeatures`)
- Test: `plugin/percus-review/tests/state-drift-check.tests.ps1`

**Interfaces:**
- Consumes: nada de outras tarefas.
- Produces: `Get-DriftFontesPlano -Cwd <string>` → `string[]` (caminhos absolutos, vazio se não há fonte); `Read-PlanoFeatures -Paths <string[]>` → `hashtable` (mesmo formato de hoje). No teste: `New-DriftRepoFatiado -Hub <string> -Arquivos <hashtable> -Handoff <string>` → caminho do repo temporário.

- [ ] **Step 1: Escrever os testes que falham**

Dentro do `BeforeAll` do `Describe` (depois da função `Handoff`, antes do `}` que fecha o `BeforeAll`), acrescente:

```powershell
        function New-DriftRepoFatiado {
            # Projeto FATIADO (spec do Pacote B): docs/PLANO.md e o hub gerado, com o marcador de
            # formato; as frentes moram em docs/plano/<slug>.md. $Arquivos: nome relativo a
            # docs/plano/ -> conteudo (aceita subpasta, como "_notas/x.md").
            param([string]$Hub = "", [hashtable]$Arquivos = @{}, [string]$Handoff = $null)
            $repo = Join-Path ([IO.Path]::GetTempPath()) "drift-test-$(Get-Random)"
            $dirPlano = Join-Path $repo "docs/plano"
            New-Item -ItemType Directory -Force -Path $dirPlano | Out-Null
            $enc = New-Object System.Text.UTF8Encoding($false)
            $hubTexto = "<!-- GERADO por plano-sync.ps1 -Modo Sync. Nao edite a mao. -->`n<!-- plano-format: 1 -->`n`n" + $Hub
            [System.IO.File]::WriteAllText((Join-Path $repo "docs/PLANO.md"), $hubTexto, $enc)
            foreach ($nome in $Arquivos.Keys) {
                $destino = Join-Path $dirPlano $nome
                $pai = Split-Path -Parent $destino
                if (-not (Test-Path $pai)) { New-Item -ItemType Directory -Force -Path $pai | Out-Null }
                [System.IO.File]::WriteAllText($destino, $Arquivos[$nome], $enc)
            }
            if ($null -ne $Handoff) { [System.IO.File]::WriteAllText((Join-Path $repo "docs/HANDOFF.md"), $Handoff, $enc) }
            return $repo
        }
```

E, depois do `Context "Conservador / graceful / escapes"` (antes do `}` final do `Describe`), acrescente:

```powershell
    Context "Projeto fatiado: tarefas em docs/plano/ (RF21)" {
        It "13. frente em docs/plano/ diverge do HANDOFF -> exit 2 nomeando a feature" {
            $repo = New-DriftRepoFatiado -Arquivos @{ "auth.md" = "## Frente: Auth`n`n- ``[5-T]`` Login OTP — testado`n" } `
                                         -Handoff (Handoff "| Auth | Login OTP | ``[3-H]`` | hook |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 2
                $r.Out | Should -Match "Login OTP"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "14. o hub gerado NAO e fonte: bullet divergente nele nao bloqueia" {
            # Discriminante: se o hook lesse o hub, "Cadastro" [5-T] x [3-H] bloquearia.
            $repo = New-DriftRepoFatiado -Hub "- ``[5-T]`` Cadastro — so no hub`n" `
                                         -Arquivos @{ "auth.md" = "## Frente: Auth`n`n- ``[3-H]`` Login OTP — hook ok`n" } `
                                         -Handoff (Handoff "| Auth | Login OTP | ``[3-H]`` | — |`n| Auth | Cadastro | ``[3-H]`` | — |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 0 -Because "em projeto fatiado a fonte e docs/plano/, nao o hub"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "15. _contexto.md e _notas/ nao sao frente: tarefa divergente neles nao bloqueia" {
            $repo = New-DriftRepoFatiado -Arquivos @{
                "auth.md"          = "## Frente: Auth`n`n- ``[5-T]`` Login OTP — testado`n"
                "_contexto.md"     = "- ``[2-E]`` Webhook — anotado a mao`n"
                "_notas/antiga.md" = "- ``[0]`` Relatorios — nota velha`n"
            } -Handoff (Handoff "| Auth | Login OTP | ``[5-T]`` | — |`n| Int | Webhook | ``[5-T]`` | — |`n| Rel | Relatorios | ``[4-C]`` | — |")
            try {
                $r = Invoke-Drift -Repo $repo
                $r.Code | Should -Be 0 -Because "arquivo que comeca com _ e subpasta nao entram como frente"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }
    }
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `Invoke-Pester -Path 'D:\Claud Automations\percus-kit\plugin\percus-review\tests\state-drift-check.tests.ps1' -Output Detailed`
Expected: **13 FALHA** (exit 0 em vez de 2: o hook lê o hub, que não tem bullet) e **14 FALHA** (exit 2 em vez de 0: o hook lê o bullet do hub). **15 já passa** antes do conserto — é guarda contra implementação que leia `_contexto.md` ou subpasta, não RED. Os testes 1-12 continuam verdes.

- [ ] **Step 3: Implementar**

Em `state-drift-check.ps1`, **substitua a função `Read-PlanoFeatures` inteira** (linhas 51-63) por estas duas funções:

```powershell
function Get-DriftFontesPlano {
    # RF21 (spec 2026-09-12-plano-hub-gerado-design): em projeto FATIADO -- docs/PLANO.md com o
    # marcador <!-- plano-format: N --> -- as tarefas moram em docs/plano/*.md, e o hub gerado nao
    # tem linha de tarefa. Ler so o hub faria este hook silenciar para sempre. Arquivo que comeca
    # com "_" (_contexto.md) e subpasta (_notas/) nao sao frente. Sem marcador: o PLANO monolitico.
    param([string]$Cwd)
    $hub = Join-Path $Cwd "docs/PLANO.md"
    if ((Test-Path -LiteralPath $hub) -and (Select-String -LiteralPath $hub -Pattern '^<!-- plano-format: \d+ -->' -Encoding UTF8 -Quiet)) {
        $dir = Join-Path $Cwd "docs/plano"
        if (-not (Test-Path -LiteralPath $dir)) { return @() }
        return @(Get-ChildItem -LiteralPath $dir -File |
            Where-Object { $_.Extension -eq '.md' -and -not $_.Name.StartsWith('_') } |
            Sort-Object Name | ForEach-Object { $_.FullName })
    }
    $monolito = @((Join-Path $Cwd "docs/PLANO.md"), (Join-Path $Cwd "PLANO.md")) |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ($monolito) { return @($monolito) }
    return @()
}

function Read-PlanoFeatures {
    # Bullets "- `[tag]` Nome -- desc" em qualquer lugar das fontes. Tabelas (Legenda)
    # comecam com '|' e sao ignoradas naturalmente.
    param([string[]]$Paths)
    $map = @{}
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            if ($line -match '^\s*[-*]\s+`?\[([0-9A-Za-z-]+)\]`?\s*(.*)$') {
                Add-DriftFeature -Map $map -Clean (Get-DriftCleanName $matches[2]) -Tag $matches[1]
            }
        }
    }
    return $map
}
```

E **substitua as linhas 103-116** (de `$planoPath = @(` até `$handoff = Read-HandoffFeatures $handoffPath`) por:

```powershell
    $planoPaths = @(Get-DriftFontesPlano -Cwd $cwd)

    $handoffPath = @(
        (Join-Path $cwd "docs/HANDOFF.md"),
        (Join-Path $cwd "HANDOFF.md")
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($planoPaths.Count -eq 0 -or -not $handoffPath) { exit 0 }   # nada pra comparar

    $plano   = Read-PlanoFeatures   -Paths $planoPaths
    $handoff = Read-HandoffFeatures $handoffPath
```

- [ ] **Step 4: Rodar e ver passar**

Run: `Invoke-Pester -Path 'D:\Claud Automations\percus-kit\plugin\percus-review\tests\state-drift-check.tests.ps1' -Output Detailed`
Expected: 16 testes, **0 falhas**.

- [ ] **Step 5: Rodar as guardas de runtime e encoding**

Run:
```powershell
Invoke-Pester -Path 'D:\Claud Automations\percus-kit\plugin\percus-review\tests\ps51-compat.tests.ps1','D:\Claud Automations\percus-kit\plugin\percus-review\tests\hooks-leitura-utf8.tests.ps1' -Output Detailed
```
Expected: 0 falhas. E confira que o hook continua ASCII: `grep -nP '[^\x00-\x7F]' "/d/Claud Automations/percus-kit/plugin/percus-review/hooks/state-drift-check.ps1"` → nenhuma linha.

- [ ] **Step 6: R11 e commit**

```powershell
Push-Location 'D:\Claud Automations\percus-kit'
pwsh -NoProfile -ExecutionPolicy Bypass -File plugin/percus-review/scripts/deepseek-review.ps1
Pop-Location
```
Leia os findings. O review vê o working tree inteiro, e finding sobre arquivo de outra sessão é comum e às vezes falso: confira cada um no código antes de agir. Conserte o que proceder (e rode o Step 4 de novo) ou declare no corpo do commit por que não procede. Depois:

```bash
git -C "D:/Claud Automations/percus-kit" add -- plugin/percus-review/hooks/state-drift-check.ps1 plugin/percus-review/tests/state-drift-check.tests.ps1
git -C "D:/Claud Automations/percus-kit" commit -m "feat(hooks): state-drift-check le docs/plano/ em projeto fatiado (RF21)" -m "Com o marcador plano-format no docs/PLANO.md, as tarefas vem de docs/plano/*.md (exceto _*); o hub gerado nao tem linha de tarefa e lido sozinho faria o hook silenciar. Testes 13-15; 15 e guarda, nao RED." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- plugin/percus-review/hooks/state-drift-check.ps1 plugin/percus-review/tests/state-drift-check.tests.ps1
```

---

### Task 2: "Não comparou" → `systemMessage`, uma vez por sessão (RF22, RF22a, RF22b)

**Files:**
- Modify: `plugin/percus-review/hooks/state-drift-check.ps1` (cabeçalho, linhas 1-12; duas funções novas depois de `Read-HandoffFeatures`; bloco principal logo depois do trecho que a Task 1 escreveu)
- Test: `plugin/percus-review/tests/state-drift-check.tests.ps1`

**Interfaces:**
- Consumes: `Get-DriftFontesPlano`, `Read-PlanoFeatures -Paths` (Task 1); `New-DriftRepo`, `Plano`, `Handoff`, `$script:Legenda` (já existem no teste).
- Produces: `Test-DriftTemTarefa -Paths <string[]>` → `bool`; `Write-DriftNaoComparou -Cwd <string> -HandoffPath <string> -SessionId <string>` → escreve uma linha JSON no stdout (ou nada, se a sessão já foi avisada). No teste: `Invoke-DriftSeparado -Repo <string> -SessionId <string> -Runtime <string>` → `{ Code, Stdout, Stderr }`; `$script:HandoffSemSecao`.

- [ ] **Step 1: Escrever os testes que falham**

No `BeforeAll` do `Describe`, logo depois de `New-DriftRepoFatiado`, acrescente:

```powershell
        function Invoke-DriftSeparado {
            # Como Invoke-Drift, mas com stdout e stderr SEPARADOS: o aviso "nao comparou" sai no
            # stdout (JSON), o bloqueio sai no stderr. Com 2>&1 nao daria pra saber qual canal falou.
            param([string]$Repo, [string]$SessionId = "", [string]$Runtime = "pwsh")
            $obj = [ordered]@{ cwd = $Repo; transcript_path = "" }
            if ($SessionId) { $obj.session_id = $SessionId }
            $stdin = $obj | ConvertTo-Json -Compress
            $errFile = [IO.Path]::GetTempFileName()
            try {
                $out = $stdin | & $Runtime -NoProfile -ExecutionPolicy Bypass -File $script:hook 2>$errFile
                $code = $LASTEXITCODE
                $err = [IO.File]::ReadAllText($errFile)
            } finally { Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue }
            return [pscustomobject]@{ Code = $code; Stdout = ((@($out) -join "`n").Trim()); Stderr = $err.Trim() }
        }

        $script:HandoffSemSecao = "# Handoff`n`n## Proximo passo`n`nContinuar o login.`n"
```

Depois do `Context "Projeto fatiado..."` da Task 1, acrescente:

```powershell
    Context "Nao comparou -> systemMessage uma vez por sessao (RF22)" {
        It "17. HANDOFF sem a secao + PLANO com tarefa -> exit 0 e systemMessage no stdout" {
            $repo = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            try {
                $r = Invoke-DriftSeparado -Repo $repo -SessionId "s17"
                $r.Code | Should -Be 0
                $r.Stderr | Should -BeNullOrEmpty
                $msg = ($r.Stdout | ConvertFrom-Json).systemMessage
                $msg | Should -Match '^\[percus:hook state-drift\] NAO COMPAROU: docs/HANDOFF\.md nao tem a secao "Status de Features" com linhas de tag'
                $msg | Should -Match 'Nada foi bloqueado\.$'
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "18. mesma sessao, segunda parada -> silencio; a marca fica em .deepseek/state-drift/" {
            $repo = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            try {
                $r1 = Invoke-DriftSeparado -Repo $repo -SessionId "s18"
                $r2 = Invoke-DriftSeparado -Repo $repo -SessionId "s18"
                $r1.Stdout | Should -Not -BeNullOrEmpty
                $r2.Code | Should -Be 0
                $r2.Stdout | Should -BeNullOrEmpty -Because "o Stop dispara a cada fim de turno; repetir e ruido"
                Test-Path (Join-Path $repo ".deepseek/state-drift/s18.flag") | Should -Be $true
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "19. sessoes diferentes -> avisa nas duas" {
            $repo = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            try {
                (Invoke-DriftSeparado -Repo $repo -SessionId "s19a").Stdout | Should -Not -BeNullOrEmpty
                (Invoke-DriftSeparado -Repo $repo -SessionId "s19b").Stdout | Should -Not -BeNullOrEmpty
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "20. payload sem session_id -> avisa sempre e nao cria marca" {
            $repo = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            try {
                (Invoke-DriftSeparado -Repo $repo).Stdout | Should -Not -BeNullOrEmpty
                (Invoke-DriftSeparado -Repo $repo).Stdout | Should -Not -BeNullOrEmpty
                Test-Path (Join-Path $repo ".deepseek/state-drift") | Should -Be $false
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "21. secao existe mas sem nenhuma linha com tag -> avisa" {
            $vazia = "# Handoff`n`n## Status de Features`n`n| Frente | Feature | Status |`n|---|---|---|`n"
            $repo = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $vazia
            try {
                (Invoke-DriftSeparado -Repo $repo -SessionId "s21").Stdout | Should -Match 'NAO COMPAROU'
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "22. PLANO sem linha de tarefa canonica -> silencio e nenhuma marca" {
            # [risco] e [5-T parcial] nao sao tag canonica; o [5-T] esta dentro de bloco de codigo.
            $cerca = [string]::new([char]96, 3)   # tres crases montadas em runtime
            $semTarefa = $script:Legenda + "## Frente: Auth`n`n- [risco] Login pode cair sem aviso`n- [5-T parcial] Cadastro`n`n" +
                         $cerca + "markdown`n- [5-T] Exemplo dentro de bloco de codigo`n" + $cerca + "`n"
            $repo = New-DriftRepo -Plano $semTarefa -Handoff $script:HandoffSemSecao
            try {
                $r = Invoke-DriftSeparado -Repo $repo -SessionId "s22"
                $r.Code | Should -Be 0
                $r.Stdout | Should -BeNullOrEmpty
                Test-Path (Join-Path $repo ".deepseek/state-drift") | Should -Be $false
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "23. session_id com caracteres de caminho -> sanitizado, marca dentro de .deepseek/state-drift/" {
            $repo = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            try {
                (Invoke-DriftSeparado -Repo $repo -SessionId "../../s23").Stdout | Should -Not -BeNullOrEmpty
                Test-Path (Join-Path $repo ".deepseek/state-drift/s23.flag") | Should -Be $true
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "24. marca impossivel de gravar (.deepseek/state-drift e ARQUIVO) -> avisa mesmo assim" {
            $repo = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            try {
                New-Item -ItemType Directory -Force -Path (Join-Path $repo ".deepseek") | Out-Null
                Set-Content -Path (Join-Path $repo ".deepseek/state-drift") -Value "ocupado"
                $r = Invoke-DriftSeparado -Repo $repo -SessionId "s24"
                $r.Code | Should -Be 0
                $r.Stdout | Should -Match 'NAO COMPAROU' -Because "falha ao marcar nao pode calar o aviso"
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "25. divergencia continua exit 2 e nao escreve nada no stdout" {
            $repo = New-DriftRepo -Plano (Plano "- ``[5-T]`` Login OTP — testado") `
                                  -Handoff (Handoff "| Auth | Login OTP | ``[3-H]`` | hook |")
            try {
                $r = Invoke-DriftSeparado -Repo $repo -SessionId "s25"
                $r.Code | Should -Be 2
                $r.Stdout | Should -BeNullOrEmpty
                $r.Stderr | Should -Match 'BLOCK'
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "26. concordancia com a secao -> exit 0 e stdout vazio" {
            $repo = New-DriftRepo -Plano (Plano "- ``[5-T]`` Login OTP — testado") `
                                  -Handoff (Handoff "| Auth | Login OTP | ``[5-T]`` | — |")
            try {
                $r = Invoke-DriftSeparado -Repo $repo -SessionId "s26"
                $r.Code | Should -Be 0
                $r.Stdout | Should -BeNullOrEmpty
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }

        It "27. runtime real (powershell.exe 5.1) -> mesmo systemMessage do pwsh" {
            if (-not (Get-Command powershell.exe -ErrorAction SilentlyContinue)) { Set-ItResult -Skipped -Because "sem powershell.exe nesta maquina"; return }
            $repo = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            try {
                $r7 = Invoke-DriftSeparado -Repo $repo -SessionId "s27a"
                $r5 = Invoke-DriftSeparado -Repo $repo -SessionId "s27b" -Runtime "powershell.exe"
                $r5.Code | Should -Be 0
                $r7.Stdout | Should -Not -BeNullOrEmpty
                ($r5.Stdout | ConvertFrom-Json).systemMessage | Should -Be (($r7.Stdout | ConvertFrom-Json).systemMessage)
            } finally { Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue }
        }
    }
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `Invoke-Pester -Path 'D:\Claud Automations\percus-kit\plugin\percus-review\tests\state-drift-check.tests.ps1' -Output Detailed`
Expected: **falham 17, 18, 19, 20, 21, 23, 24 e 27** (stdout vazio: o hook sai 0 calado). **Passam 22, 25 e 26** já antes do conserto: são guardas contra aviso em excesso e contra mudança no bloqueio, não RED.

- [ ] **Step 3: Implementar**

Em `state-drift-check.ps1`, **substitua o cabeçalho** (linhas 1-12, do `#requires` até a linha `# Skip: ...`) por:

```powershell
#requires -Version 5.1
# Hook Stop event Percus state-drift-check (R2 / R8 / v6.12.0; RF21-RF22 do Pacote B em 6.54.0).
#
# Tres saidas:
#   - BLOQUEIA (exit 2) quando uma feature tem tag DIVERGENTE entre o plano (fonte da verdade) e o
#     HANDOFF.md. Conservador: so com o MESMO nome normalizado e uma tag de cada lado.
#   - AVISA SEM BLOQUEAR (exit 0 + {"systemMessage"} no stdout) quando o plano tem tarefa e o
#     HANDOFF nao tem a secao "Status de Features" com linha de tag -- nao ha o que comparar.
#     Antes saia 0 calado: verde em 25 de 29 projetos, gate so no papel. O Stop so entrega texto
#     ao modelo sem bloquear por systemMessage (doc oficial, secao Stop); stdout/stderr puros de
#     exit 0 vao so pro debug log. Uma vez por session_id, porque o Stop dispara a cada turno.
#   - Resto (sem plano, sem HANDOFF, plano sem tarefa, erro) -> exit 0 calado.
#
# Plano: em projeto fatiado (docs/PLANO.md com <!-- plano-format: N -->), docs/plano/*.md exceto _*;
# senao docs/PLANO.md ou PLANO.md. Spec: docs/superpowers/specs/2026-09-12-plano-hub-gerado-design.md.
#
# Skip: $env:PERCUS_SKIP_DRIFT_CHECK=1 (ou $env:PERCUS_HOOKS_DISABLED).
```

**Acrescente, logo depois da função `Read-HandoffFeatures`** (antes da linha `try {` do bloco principal):

```powershell
function Test-DriftTemTarefa {
    # "Linha de tarefa" na definicao da spec: bullet com tag CANONICA, fora de bloco de codigo
    # cercado. Mais estreito que Read-PlanoFeatures (que aceita qualquer [palavra]) de proposito:
    # a pergunta aqui e "este plano tem tarefa?", e [risco] nao e tarefa.
    param([string[]]$Paths)
    foreach ($path in $Paths) {
        $cerca = $false
        foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            if ($line -match '^\s*`{3}') { $cerca = -not $cerca; continue }   # `{3} = cerca de codigo
            if ($cerca) { continue }
            if ($line -match '^\s*[-*]\s+`?\[(0|1-S|2-E|3-H|4-C|5-T)\]`?') { return $true }
        }
    }
    return $false
}

function Write-DriftNaoComparou {
    # RF22b: uma vez por session_id. Marca ANTES de falar, e falha ao marcar nao cala o aviso.
    param([string]$Cwd, [string]$HandoffPath, [string]$SessionId)
    $sid = "$SessionId" -replace '[^A-Za-z0-9_\-]', ''   # mesma regra do context-budget-guard: apaga, nao troca
    if ($sid) {
        $dir  = Join-Path $Cwd ".deepseek/state-drift"
        $flag = Join-Path $dir "$sid.flag"
        if (Test-Path -LiteralPath $flag) { return }
        try {
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null }
            [IO.File]::WriteAllText($flag, (Get-Date -Format 'o'))
        } catch { }
    }
    $rel = $HandoffPath.Substring($Cwd.Length).TrimStart('\', '/').Replace('\', '/')
    $msg = "[percus:hook state-drift] NAO COMPAROU: $rel nao tem a secao ""Status de Features"" com linhas de tag (templates/HANDOFF.template.md) -- a divergencia de status PLANO x HANDOFF nao e verificada neste projeto. Nada foi bloqueado."
    Write-Output (@{ systemMessage = $msg } | ConvertTo-Json -Compress)
}
```

No bloco principal, **logo depois** da linha `$handoff = Read-HandoffFeatures $handoffPath` (escrita na Task 1), acrescente:

```powershell

    if ($handoff.Count -eq 0) {
        # HANDOFF sem a tabela "Status de Features", ou com ela vazia: nao ha o que comparar.
        if (Test-DriftTemTarefa -Paths $planoPaths) {
            Write-DriftNaoComparou -Cwd $cwd -HandoffPath $handoffPath -SessionId "$($payload.session_id)"
        }
        exit 0
    }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `Invoke-Pester -Path 'D:\Claud Automations\percus-kit\plugin\percus-review\tests\state-drift-check.tests.ps1' -Output Detailed`
Expected: 27 testes, **0 falhas** (o 27 só pula numa máquina sem `powershell.exe`).

- [ ] **Step 5: Guardas de runtime e encoding**

Run:
```powershell
Invoke-Pester -Path 'D:\Claud Automations\percus-kit\plugin\percus-review\tests\ps51-compat.tests.ps1','D:\Claud Automations\percus-kit\plugin\percus-review\tests\hooks-leitura-utf8.tests.ps1' -Output Detailed
```
Expected: 0 falhas. `grep -nP '[^\x00-\x7F]' "/d/Claud Automations/percus-kit/plugin/percus-review/hooks/state-drift-check.ps1"` → nenhuma linha.

- [ ] **Step 6: R11 e commit**

```powershell
Push-Location 'D:\Claud Automations\percus-kit'
pwsh -NoProfile -ExecutionPolicy Bypass -File plugin/percus-review/scripts/deepseek-review.ps1
Pop-Location
```
Trate os findings como no Step 6 da Task 1. Depois:

```bash
git -C "D:/Claud Automations/percus-kit" add -- plugin/percus-review/hooks/state-drift-check.ps1 plugin/percus-review/tests/state-drift-check.tests.ps1
git -C "D:/Claud Automations/percus-kit" commit -m "feat(hooks): state-drift-check avisa por systemMessage quando nao consegue comparar (RF22)" -m "PLANO com tarefa canonica e HANDOFF sem 'Status de Features' com linha de tag: exit 0 + systemMessage, uma vez por session_id (.deepseek/state-drift/<id>.flag). Antes: verde calado em 25 de 29 projetos. Divergencia continua exit 2. Testes 17-27; 22, 25 e 26 sao guardas." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- plugin/percus-review/hooks/state-drift-check.ps1 plugin/percus-review/tests/state-drift-check.tests.ps1
```

---

### Task 3: Paridade `.sh`

**Files:**
- Modify (reescrita inteira): `plugin/percus-review/hooks/state-drift-check.sh`
- Test: `plugin/percus-review/tests/state-drift-check.tests.ps1`

**Interfaces:**
- Consumes: `New-DriftRepo`, `New-DriftRepoFatiado`, `Invoke-DriftSeparado`, `Plano`, `Handoff`, `$script:HandoffSemSecao`, `$script:Legenda` (Tasks 1-2 e já existentes).
- Produces: `Invoke-DriftSh -Repo <string> -SessionId <string>` → `{ Code, Stdout, Stderr }` (dentro do `BeforeAll` do Context de paridade).

- [ ] **Step 1: Escrever os testes que falham**

Depois do `Context "Nao comparou..."` da Task 2, acrescente:

```powershell
    Context "paridade .sh -- os dois runtimes contra o mesmo fixture" {
        BeforeAll {
            # Fallback pro bash do Git: sem ele, a paridade vira Skipped quando a suite roda de um
            # pwsh sem bash no PATH (divida registrada no plano de enforcement).
            $script:bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
            if (-not $script:bash) {
                $g = Join-Path $env:ProgramFiles "Git\bin\bash.exe"
                if (Test-Path $g) { $script:bash = $g }
            }
            $script:shPronto = $false
            if ($script:bash) {
                & $script:bash -lc "command -v python3 >/dev/null 2>&1" 2>$null
                $script:shPronto = ($LASTEXITCODE -eq 0)
            }

            # Dentro do BeforeAll de proposito: no Pester 5, funcao definida no corpo do Context
            # (fora do BeforeAll) nao existe para os It.
            function Invoke-DriftSh {
                param([string]$Repo, [string]$SessionId = "")
                $sh = (Join-Path (Join-Path $PSScriptRoot "..") "hooks/state-drift-check.sh").Replace([char]92, [char]47)
                $obj = [ordered]@{ cwd = $Repo; transcript_path = "" }
                if ($SessionId) { $obj.session_id = $SessionId }
                $payload = [IO.Path]::GetTempFileName()
                $errFile = [IO.Path]::GetTempFileName()
                try {
                    [IO.File]::WriteAllText($payload, ($obj | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))
                    $out = & $script:bash -lc "bash '$sh' < '$($payload.Replace([char]92, [char]47))'" 2>$errFile
                    $code = $LASTEXITCODE
                    $err = [IO.File]::ReadAllText($errFile)
                } finally {
                    Remove-Item -LiteralPath $payload, $errFile -Force -ErrorAction SilentlyContinue
                }
                return [pscustomobject]@{ Code = $code; Stdout = ((@($out) -join "`n").Trim()); Stderr = ($err -replace "`r", "").Trim() }
            }
        }

        It "S1. nao comparou: .sh e .ps1 emitem o mesmo systemMessage" {
            if (-not $script:shPronto) { Set-ItResult -Skipped -Because "sem bash com python3 nesta maquina"; return }
            $a = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            $b = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            try {
                $ps = Invoke-DriftSeparado -Repo $a -SessionId "p1"
                $sh = Invoke-DriftSh -Repo $b -SessionId "p1"
                $ps.Stdout | Should -Not -BeNullOrEmpty
                $sh.Code | Should -Be $ps.Code
                ($sh.Stdout | ConvertFrom-Json).systemMessage | Should -Be (($ps.Stdout | ConvertFrom-Json).systemMessage)
            } finally { Remove-Item -Recurse -Force $a, $b -ErrorAction SilentlyContinue }
        }

        It "S2. segunda parada da mesma sessao: silencio nos dois, e o .sh tambem marca" {
            if (-not $script:shPronto) { Set-ItResult -Skipped -Because "sem bash com python3 nesta maquina"; return }
            $b = New-DriftRepo -Plano (Plano "- ``[4-C]`` Login OTP — falta CRUD") -Handoff $script:HandoffSemSecao
            try {
                (Invoke-DriftSh -Repo $b -SessionId "p2").Stdout | Should -Not -BeNullOrEmpty
                $sh2 = Invoke-DriftSh -Repo $b -SessionId "p2"
                $sh2.Code | Should -Be 0
                $sh2.Stdout | Should -BeNullOrEmpty
                Test-Path (Join-Path $b ".deepseek/state-drift/p2.flag") | Should -Be $true
            } finally { Remove-Item -Recurse -Force $b -ErrorAction SilentlyContinue }
        }

        It "S3. projeto fatiado com divergencia: exit 2 e BLOCK nos dois" {
            if (-not $script:shPronto) { Set-ItResult -Skipped -Because "sem bash com python3 nesta maquina"; return }
            $arq = @{ "auth.md" = "## Frente: Auth`n`n- ``[5-T]`` Login OTP — testado`n" }
            $h = Handoff "| Auth | Login OTP | ``[3-H]`` | hook |"
            $a = New-DriftRepoFatiado -Arquivos $arq -Handoff $h
            $b = New-DriftRepoFatiado -Arquivos $arq -Handoff $h
            try {
                $ps = Invoke-DriftSeparado -Repo $a -SessionId "p3"
                $sh = Invoke-DriftSh -Repo $b -SessionId "p3"
                $ps.Code | Should -Be 2
                $sh.Code | Should -Be 2
                $sh.Stderr | Should -Match '"Login OTP": \[5-T\] no PLANO vs \[3-H\] no HANDOFF'
            } finally { Remove-Item -Recurse -Force $a, $b -ErrorAction SilentlyContinue }
        }

        It "S4. plano sem tarefa canonica: silencio nos dois" {
            if (-not $script:shPronto) { Set-ItResult -Skipped -Because "sem bash com python3 nesta maquina"; return }
            $semTarefa = $script:Legenda + "## Frente: Auth`n`n- [risco] Login pode cair`n"
            $b = New-DriftRepo -Plano $semTarefa -Handoff $script:HandoffSemSecao
            try {
                $sh = Invoke-DriftSh -Repo $b -SessionId "p4"
                $sh.Code | Should -Be 0
                $sh.Stdout | Should -BeNullOrEmpty
            } finally { Remove-Item -Recurse -Force $b -ErrorAction SilentlyContinue }
        }

        It "S5. fatiado: _contexto.md e _notas/ ignorados nos dois" {
            if (-not $script:shPronto) { Set-ItResult -Skipped -Because "sem bash com python3 nesta maquina"; return }
            $arq = @{
                "auth.md"          = "## Frente: Auth`n`n- ``[5-T]`` Login OTP — testado`n"
                "_contexto.md"     = "- ``[2-E]`` Webhook — anotado a mao`n"
                "_notas/antiga.md" = "- ``[0]`` Relatorios — nota velha`n"
            }
            $h = Handoff "| Auth | Login OTP | ``[5-T]`` | — |`n| Int | Webhook | ``[5-T]`` | — |`n| Rel | Relatorios | ``[4-C]`` | — |"
            $b = New-DriftRepoFatiado -Arquivos $arq -Handoff $h
            try {
                (Invoke-DriftSh -Repo $b -SessionId "p5").Code | Should -Be 0
            } finally { Remove-Item -Recurse -Force $b -ErrorAction SilentlyContinue }
        }
    }
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `Invoke-Pester -Path 'D:\Claud Automations\percus-kit\plugin\percus-review\tests\state-drift-check.tests.ps1' -Output Detailed`
Expected: **falham S1, S2 e S3.** O `.sh` de hoje não avisa e lê o hub. Há mais uma causa de falha, anterior a essas: no Windows o `python3` do `$(...)` devolve o `cwd` com `\r` no fim, o `[[ -d ]]` falha e o `.sh` roda no diretório errado — a mesma armadilha do `\r` que a 6.53.0 achou no `jq` (verbete `crlf-mata-regex-git-bash`). **S4 e S5 passam** antes do conserto (guardas). Se todos pularem, a máquina não tem bash com python3: pare e resolva o ambiente antes de seguir, porque paridade não provada não é paridade.

- [ ] **Step 3: Reescrever o `.sh`**

Substitua o conteúdo inteiro de `plugin/percus-review/hooks/state-drift-check.sh` por (grave com LF):

```bash
#!/usr/bin/env bash
# Hook Stop event Percus state-drift-check (R2 / R8 / v6.12.0; RF21-RF22 do Pacote B em 6.54.0) - Unix.
# Espelha o state-drift-check.ps1 (primario). A paridade e provada em
# tests/state-drift-check.tests.ps1, Context "paridade .sh".
#   - divergencia de tag PLANO x HANDOFF (mesmo nome)          -> exit 2, stderr
#   - plano com tarefa canonica e HANDOFF sem "Status de
#     Features" com linha de tag                               -> exit 0 + {"systemMessage"} no stdout,
#                                                                 uma vez por session_id
#   - resto                                                    -> exit 0 calado
# Projeto fatiado (docs/PLANO.md com <!-- plano-format: N -->): docs/plano/*.md, exceto _*.
# Skip: PERCUS_SKIP_DRIFT_CHECK=1. Falha graceful: erro -> exit 0.
set +e

STDIN=$(cat || true)
[[ -z "$STDIN" ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" || -n "$PERCUS_SKIP_DRIFT_CHECK" ]] && exit 0

# tr -d '\r': no Windows o python3 escreve "\r\n", e o $(...) so remove o "\n". Com o "\r" sobrando,
# o [[ -d ]] falhava e o hook rodava calado no diretorio errado.
cwd=$(printf '%s' "$STDIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd','') or '')" 2>/dev/null | tr -d '\r')
[[ -z "$cwd" || ! -d "$cwd" ]] && cwd="$(pwd)"
sid=$(printf '%s' "$STDIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','') or '')" 2>/dev/null | tr -d '\r')

python3 - "$cwd" "$sid" <<'PYEOF'
import sys, os, re, json
from datetime import datetime

cwd = sys.argv[1]
sid = re.sub(r'[^A-Za-z0-9_\-]', '', sys.argv[2] if len(sys.argv) > 2 else '')

CANON = re.compile(r'^\s*[-*]\s+`?\[(0|1-S|2-E|3-H|4-C|5-T)\]`?')
MARCADOR = re.compile(r'^<!-- plano-format: \d+ -->')
MSG = ('[percus:hook state-drift] NAO COMPAROU: %s nao tem a secao "Status de Features" com linhas de tag '
       '(templates/HANDOFF.template.md) -- a divergencia de status PLANO x HANDOFF nao e verificada neste '
       'projeto. Nada foi bloqueado.')


def find(*cands):
    for c in cands:
        p = os.path.join(cwd, c)
        if os.path.isfile(p):
            return p
    return None


def read_lines(p):
    try:
        return open(p, encoding='utf-8', errors='replace').read().splitlines()
    except Exception:
        return []


def fontes_do_plano():
    hub = os.path.join(cwd, 'docs', 'PLANO.md')
    if os.path.isfile(hub) and any(MARCADOR.match(l) for l in read_lines(hub)):
        d = os.path.join(cwd, 'docs', 'plano')
        if not os.path.isdir(d):
            return []
        nomes = [n for n in os.listdir(d)
                 if n.lower().endswith('.md') and not n.startswith('_') and os.path.isfile(os.path.join(d, n))]
        return [os.path.join(d, n) for n in sorted(nomes, key=str.lower)]
    p = find('docs/PLANO.md', 'PLANO.md')
    return [p] if p else []


def clean(text):
    t = text.strip()
    t = re.sub(r'`?\[[0-9A-Za-z-]+\]`?', '', t)
    for m in ['\U0001F3A8', '\U0001F916', '\u2713', '\u2705', '?', '!']:
        t = t.replace(m, '')
    t = re.split(r'\s+(?:\u2014|\u2013|--)\s+', t, 1)[0]
    return re.sub(r'\s+', ' ', t.strip())


def tagof(text):
    m = re.search(r'\[([0-9A-Za-z-]+)\]', text)
    return m.group(1) if m else None


def add(d, c, tg):
    if not c or not tg:
        return
    k = c.lower()
    if k == 'feature':
        return
    e = d.setdefault(k, {'disp': c, 'tags': []})
    if tg not in e['tags']:
        e['tags'].append(tg)


def tem_tarefa(paths):
    for p in paths:
        cerca = False
        for ln in read_lines(p):
            if re.match(r'^\s*`{3}', ln):
                cerca = not cerca
                continue
            if cerca:
                continue
            if CANON.match(ln):
                return True
    return False


def avisar_nao_comparou(handoff):
    if sid:
        flag = os.path.join(cwd, '.deepseek', 'state-drift', sid + '.flag')
        if os.path.exists(flag):
            return
        try:
            os.makedirs(os.path.dirname(flag), exist_ok=True)
            with open(flag, 'w') as fh:
                fh.write(datetime.now().isoformat())
        except Exception:
            pass
    rel = os.path.relpath(handoff, cwd).replace('\\', '/')
    sys.stdout.write(json.dumps({'systemMessage': MSG % rel}) + '\n')


def main():
    fontes = fontes_do_plano()
    handoff = find('docs/HANDOFF.md', 'HANDOFF.md')
    if not fontes or not handoff:
        return 0

    plano_map = {}
    for p in fontes:
        for ln in read_lines(p):
            m = re.match(r'^\s*[-*]\s+`?\[([0-9A-Za-z-]+)\]`?\s*(.*)$', ln)
            if m:
                add(plano_map, clean(m.group(2)), m.group(1))

    handoff_map = {}
    insec = False
    for ln in read_lines(handoff):
        if re.match(r'^\s*#{1,6}\s', ln):
            insec = bool(re.search(r'(?i)status\s+de\s+features', ln))
            continue
        if not insec:
            continue
        t = ln.strip()
        if not t.startswith('|'):
            continue
        if re.match(r'^\|[\s:\-\|]+$', t):
            continue
        cells = [c.strip() for c in t.strip('|').split('|')]
        if len(cells) < 2:
            continue
        si = -1
        for i, c in enumerate(cells):
            if re.search(r'\[[0-9A-Za-z-]+\]', c):
                si = i
                break
        if si < 1:
            continue
        add(handoff_map, clean(cells[si - 1]), tagof(cells[si]))

    if not handoff_map:
        if tem_tarefa(fontes):
            avisar_nao_comparou(handoff)
        return 0

    drifts = []
    for k, e in plano_map.items():
        if k not in handoff_map:
            continue
        pt = e['tags']
        ht = handoff_map[k]['tags']
        if len(pt) != 1 or len(ht) != 1:
            continue
        if pt[0] != ht[0]:
            drifts.append((e['disp'], pt[0], ht[0]))

    if not drifts:
        return 0

    sys.stderr.write("[percus:hook state-drift] BLOCK: PLANO.md e HANDOFF.md divergem no status de %d feature(s):\n" % len(drifts))
    for name, pt, ht in drifts:
        sys.stderr.write('  - "%s": [%s] no PLANO vs [%s] no HANDOFF\n' % (name, pt, ht))
    sys.stderr.write("Sincronize os dois (fonte da verdade = PLANO.md) antes de encerrar a sessao (R2/R8).\n")
    sys.stderr.write("Pular: PERCUS_SKIP_DRIFT_CHECK=1 (declarar motivo em voz alta).\n")
    return 2


try:
    codigo = main()
except Exception:
    codigo = 0
sys.exit(codigo)
PYEOF
exit $?
```

Os caracteres especiais do `clean()` saíram de literais para escapes Python (`\u2713`, `\u2014`...): mesmo comportamento, arquivo em ASCII. Confira que o arquivo ficou com LF: `file "/d/Claud Automations/percus-kit/plugin/percus-review/hooks/state-drift-check.sh"` não deve dizer `CRLF`.

- [ ] **Step 4: Rodar e ver passar**

Run: `Invoke-Pester -Path 'D:\Claud Automations\percus-kit\plugin\percus-review\tests\state-drift-check.tests.ps1' -Output Detailed`
Expected: 32 testes, **0 falhas e 0 skipped** nesta máquina (tem Git Bash e python3).

- [ ] **Step 5: R11 e commit**

```powershell
Push-Location 'D:\Claud Automations\percus-kit'
pwsh -NoProfile -ExecutionPolicy Bypass -File plugin/percus-review/scripts/deepseek-review.ps1
Pop-Location
```
Trate os findings como no Step 6 da Task 1. Depois:

```bash
git -C "D:/Claud Automations/percus-kit" add -- plugin/percus-review/hooks/state-drift-check.sh plugin/percus-review/tests/state-drift-check.tests.ps1
git -C "D:/Claud Automations/percus-kit" commit -m "feat(hooks): paridade .sh do state-drift-check (RF21-RF22)" -m "O .sh toma as mesmas tres decisoes do .ps1, provado por teste que roda os dois contra o mesmo fixture (S1-S5). De carona: o cwd lido por \$(python3 ...) chegava com \\r no Windows, o [[ -d ]] falhava e o hook rodava calado no diretorio errado; tr -d '\\r'." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- plugin/percus-review/hooks/state-drift-check.sh plugin/percus-review/tests/state-drift-check.tests.ps1
```

---

### Task 4: Versão 6.54.0, suíte inteira e estado da execução

**Files:**
- Modify (via script): `CANON_VERSION.md`, `plugin/percus-review/plugin.json`, `.claude-plugin/marketplace.json`, `.percus-version`
- Modify: `CANON_VERSION.md` (texto do changelog), `docs/superpowers/plans/2026-09-12-enforcement-regras-sem-hook.md`, `docs/superpowers/specs/2026-09-12-plano-hub-gerado-design.md`

**Interfaces:**
- Consumes: as Tasks 1-3 commitadas.
- Produces: kit em 6.54.0, commit local pronto para publicação (R20).

- [ ] **Step 1: Confirmar que ninguém bumpou antes**

Run: `cat "/d/Claud Automations/percus-kit/.percus-version"`
Expected: `6.53.0`. Se for outro valor, outra janela bumpou: **pare**, use a versão seguinte à que estiver lá e registre isso no corpo do commit.

- [ ] **Step 2: Bump**

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'D:\Claud Automations\percus-kit\scripts\bump-canon.ps1' -Versao 6.54.0
```
Expected: o script atualiza os 7 pontos e cria, em `CANON_VERSION.md`, a seção `## Changelog v6.54.0 — <data>` com a linha `- (descreva a mudanca desta versao)`.

- [ ] **Step 3: Escrever o changelog**

Em `CANON_VERSION.md`, substitua a linha `- (descreva a mudanca desta versao)` por:

```markdown
**`state-drift-check` deixa de sair verde calado quando não consegue comparar.** Primeira entrega do
Pacote B (`docs/superpowers/specs/2026-09-12-plano-hub-gerado-design.md`, RF21–RF22c).

- **Não comparou → aviso sem bloqueio.** Quando o plano tem ao menos uma linha de tarefa com tag
  canônica e o HANDOFF não tem a seção `Status de Features` com linha de tag, o hook sai 0 com
  `{"systemMessage": ...}` no stdout — o único canal que o evento `Stop` oferece para dar texto ao
  modelo sem bloquear (doc oficial, seção Stop). Sai uma vez por `session_id`, marcado em
  `.deepseek/state-drift/<session_id>.flag`, porque o `Stop` dispara a cada fim de turno. Medido em
  2026-09-13: 4 dos 29 projetos com PLANO e HANDOFF têm a seção; nos outros 25 o hook rodava, não
  achava nada e saía verde.
- **Projeto fatiado.** Com o marcador `<!-- plano-format: N -->` no `docs/PLANO.md`, as tarefas vêm de
  `docs/plano/*.md`, exceto `_*`. O hub gerado não tem linha de tarefa, e lido sozinho faria o hook
  silenciar.
- **Divergência continua bloqueando** (exit 2), sem mudança.
- **Paridade `.sh`** provada por teste que roda os dois lados contra o mesmo fixture. De carona, o `.sh`
  lia o `cwd` com `\r` no Windows e rodava calado no diretório errado.

Registro não muda: `hooks.json` intocado.
```

A linha com os números da suíte entra no Step 5.

- [ ] **Step 4: Atualizar o estado da execução**

Em `docs/superpowers/plans/2026-09-12-enforcement-regras-sem-hook.md`, na seção `### ✅ Feito`, acrescente ao fim da lista:

```markdown
- **6.54.0** **`state-drift-check` avisa quando não consegue comparar** (plano
  `plans/2026-09-13-state-drift-check-nao-comparou.md`, RF21–RF22c do Pacote B). Exit 0 com
  `systemMessage`, uma vez por sessão, em vez do verde calado em 25 de 29 projetos; em projeto
  fatiado, lê `docs/plano/`. Paridade `.sh` provada por teste. **Não publicado:** espera R20.
```

E, no item 3 da FILA, substitua as três linhas que vão de "**Próximo passo literal:** executar o plano 1," até "que independe do resto; depois, o plano 2 (`plano-sync`)." por (mantendo o recuo de 3 espaços do item):

```markdown
**Próximo passo literal:** o conserto do `state-drift-check` (RF21–RF22c) saiu na 6.54.0, sem publicar; o
próximo é o plano 2 (`plano-sync`).
```

Na spec, no passo 0 do `## Rollout`, acrescente ao fim do parágrafo: ` **Entregue na 6.54.0** (plano \`2026-09-13-state-drift-check-nao-comparou.md\`).`

- [ ] **Step 5: Suíte inteira, nos dois ambientes, uma de cada vez**

Confira que não há outra execução:
```powershell
Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" | Where-Object { $_.CommandLine -match 'rodar-suite|Invoke-Pester' } | Select-Object ProcessId, CommandLine
```
Expected: nenhuma linha. Se houver, espere terminar.

Pelo PowerShell:
```powershell
Push-Location 'D:\Claud Automations\percus-kit'
pwsh -NoProfile -File scripts/rodar-suite.ps1
Pop-Location
```
Expected: 0 falhas. Anote passou/total e quantos skipped.

Depois, só depois de a primeira terminar, pelo Git Bash:
```bash
"/c/Program Files/Git/bin/bash.exe" -lc 'cd "/d/Claud Automations/percus-kit" && pwsh -NoProfile -File scripts/rodar-suite.ps1'
```
Expected: 0 falhas. Anote passou/total.

Acrescente ao fim da seção do changelog, em `CANON_VERSION.md`, a linha com os números medidos:
`Suíte inteira: <passou>/<total> pelo Git Bash; <passou>/<total>, <skipped> skipped, pelo PowerShell.`

Se algo falhar fora dos arquivos deste plano, confira antes de consertar se a falha já existia em HEAD (worktree limpo em HEAD, mesma suíte): a árvore é compartilhada com outras sessões.

- [ ] **Step 6: R11 e commit**

```powershell
Push-Location 'D:\Claud Automations\percus-kit'
pwsh -NoProfile -ExecutionPolicy Bypass -File plugin/percus-review/scripts/deepseek-review.ps1
Pop-Location
```

```bash
git -C "D:/Claud Automations/percus-kit" add -- CANON_VERSION.md plugin/percus-review/plugin.json .claude-plugin/marketplace.json .percus-version docs/superpowers/plans/2026-09-12-enforcement-regras-sem-hook.md docs/superpowers/specs/2026-09-12-plano-hub-gerado-design.md
git -C "D:/Claud Automations/percus-kit" commit -m "chore(release): 6.54.0 -- state-drift-check avisa quando nao consegue comparar" -m "Bump pelos 7 pontos (scripts/bump-canon.ps1), changelog com os numeros da suite nos dois ambientes, estado da execucao no plano de enforcement e na spec. Registro nao muda: hooks.json intocado. Nao publicado: push espera R20." -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>" -- CANON_VERSION.md plugin/percus-review/plugin.json .claude-plugin/marketplace.json .percus-version docs/superpowers/plans/2026-09-12-enforcement-regras-sem-hook.md docs/superpowers/specs/2026-09-12-plano-hub-gerado-design.md
```

- [ ] **Step 7: Parar antes do push**

O hook só chega aos projetos por push → auto-update. Informe ao operador: commits locais das Tasks 1-4, números da suíte, e que o push precisa de autorização R20. **Não empurre.**
