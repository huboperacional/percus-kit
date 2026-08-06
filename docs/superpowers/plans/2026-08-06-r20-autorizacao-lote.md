# R20 — autorização em lote para ações externas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao hook `external-action-guard.ps1` (R20) um segundo escape hatch — um arquivo em
disco com janela de 60 minutos — que atravessa a fronteira de processo que a variável de ambiente
`PERCUS_EXTERNAL_OVERRIDE` não atravessa, mais dois scripts pequenos e testados (criar autorização,
registrar uso) pra reduzir o risco de o agente errar a mão ao usar o mecanismo de verdade.

**Architecture:** um novo bloco `try/catch` local dentro de `external-action-guard.ps1`, com
fail-closed próprio (erro nesta checagem específica nunca libera, mesmo o resto do hook sendo
fail-open pra erro interno inesperado). Dois scripts PowerShell 5.1-compatíveis novos, no mesmo
estilo de arquivo-único de `scripts/renomear-kit-local.ps1` e `scripts/registrar-hooks-settings.ps1`.

**Tech Stack:** PowerShell 5.1+, Pester (suite existente do repo).

**Spec completa (ler antes de implementar, contém todo o raciocínio e as decisões do council-consult):**
`docs/superpowers/specs/2026-08-06-r20-autorizacao-lote-design.md`

**Contexto que este plano assume (não redescobrir):**
- Variável de ambiente não atravessa a fronteira de processo do hook `PreToolUse` — achado
  confirmado 2 vezes (2026-07-31 e 2026-08-06).
- Risco estrutural apontado pelo DeepSeek (agente cria E o hook confia no próprio arquivo, sem
  verificação externa de que a confirmação humana aconteceu) foi **aceito conscientemente pelo
  operador**, não é bug a corrigir neste plano.
- Fonte da janela de validade é `timestamp_unix` gravado dentro do JSON no momento da criação,
  **não** `LastWriteTime` do filesystem (mudança feita depois da revisão do Cross-Claude).
- Erro na checagem do arquivo de autorização (JSON corrompido, campo faltando, arquivo ilegível)
  tem que **bloquear**, nunca liberar — é uma correção de bug em relação à primeira versão do
  design, não uma feature nova.

---

## File Structure

- Modify: `plugin/percus-review/hooks/external-action-guard.ps1` — novo escape hatch de arquivo,
  ao lado do de env var já existente.
- Modify: `plugin/percus-review/tests/external-action-guard.tests.ps1` — testes do novo escape
  hatch (fresco libera, expirado bloqueia, corrompido bloqueia, escopo por-diretório, mensagem de
  log).
- Create: `scripts/autorizar-acao-externa.ps1` — cria `.percus/acao-externa-autorizada.json`
  (id, motivo, timestamp_unix). Chamado pelo agente DEPOIS de confirmação explícita do operador.
- Create: `plugin/percus-review/tests/autorizar-acao-externa.tests.ps1`.
- Create: `scripts/registrar-uso-autorizacao.ps1` — acrescenta uma linha em
  `.percus/autorizacoes-usadas.jsonl` toda vez que o agente usa a autorização em lote.
- Create: `plugin/percus-review/tests/registrar-uso-autorizacao.tests.ps1`.
- Modify: `01_REGRAS_INEGOCIAVEIS.md` — seção R20, documentar o mecanismo novo ao lado do já
  existente.

---

### Task 1: Escape hatch no hook — caso feliz (fresco libera, expirado bloqueia)

**Files:**
- Modify: `plugin/percus-review/hooks/external-action-guard.ps1`
- Modify: `plugin/percus-review/tests/external-action-guard.tests.ps1`

- [ ] **Step 1: Adicionar helpers de teste no `BeforeAll` já existente**

Abra `plugin/percus-review/tests/external-action-guard.tests.ps1`. Dentro do bloco `BeforeAll {
... }` já existente (que hoje só tem `$script:hookPath = ...`), acrescente estas duas funções
(sem remover a linha do `$script:hookPath`):

```powershell
        # Invoca o hook com um cwd controlado -- o hook le (Get-Location).Path pra montar o
        # caminho do arquivo de autorizacao, entao os testes precisam simular "rodando de
        # dentro do projeto X" sem tocar o .percus/ real do repo.
        function Invoke-HookEmDir {
            param([string]$Dir, [string]$Stdin)
            Push-Location $Dir
            try {
                return ($Stdin | & pwsh -NoProfile -File $script:hookPath 2>&1)
            } finally {
                Pop-Location
            }
        }

        # Planta um arquivo de autorizacao fixture com idade controlada (em minutos atras de
        # agora), no formato timestamp_unix que o hook espera.
        function New-AutorizacaoFixture {
            param([string]$Dir, [double]$IdadeMinutos = 5, [string]$Motivo = "teste")
            $percusDir = Join-Path $Dir ".percus"
            New-Item -ItemType Directory -Path $percusDir -Force | Out-Null
            $quando = (Get-Date).AddMinutes(-$IdadeMinutos)
            $epoch = [DateTimeOffset]::new($quando).ToUnixTimeSeconds()
            $auth = [pscustomobject]@{
                id             = [guid]::NewGuid().ToString()
                motivo         = $Motivo
                autorizado_em  = $quando.ToString("o")
                timestamp_unix = $epoch
            }
            $caminho = Join-Path $percusDir "acao-externa-autorizada.json"
            ($auth | ConvertTo-Json) | Set-Content -LiteralPath $caminho -Encoding utf8
            return $caminho
        }
```

- [ ] **Step 2: Escrever os 2 testes do caso feliz**

Acrescente estes dois `It` dentro do `Describe "external-action-guard.ps1 hook" { ... }` já
existente:

```powershell
    It "permite acao externa com autorizacao em lote fresca (timestamp_unix recente)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 0 -Because "autorizacao em lote fresca deve liberar"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "NAO permite acao externa com autorizacao em lote expirada (timestamp_unix ha mais de 60min)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 61 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "autorizacao expirada nao pode liberar"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
```

- [ ] **Step 3: Rodar e confirmar que os 2 testes novos falham (hook ainda não tem o escape hatch)**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/external-action-guard.tests.ps1' -Output Detailed"`
Expected: os 2 testes novos FALHAM (exit code do hook é 2 em vez de 0 no primeiro teste; ou o
teste de expirado pode passar coincidentemente — o que importa é confirmar que o de "fresca libera"
falha, provando que o comportamento ainda não existe).

- [ ] **Step 4: Adicionar o escape hatch no hook**

Abra `plugin/percus-review/hooks/external-action-guard.ps1`. Localize este trecho (já existe):

```powershell
    # Escape hatch: operador autorizou explicitamente
    if ($env:PERCUS_EXTERNAL_OVERRIDE -eq "1") {
        [Console]::Error.WriteLine("[percus:hook external-action-guard] PERCUS_EXTERNAL_OVERRIDE setado — permitindo.")
        exit 0
    }

    # Verifica council recente (premise_validity)
    $cwd = (Get-Location).Path
    $councilDir = Join-Path $cwd ".deepseek/council-log"
```

Substitua por (move `$cwd` pra antes, porque o novo bloco também precisa dele; adiciona o novo
escape hatch entre o de env var e a checagem de council):

```powershell
    $cwd = (Get-Location).Path

    # Escape hatch: operador autorizou explicitamente
    if ($env:PERCUS_EXTERNAL_OVERRIDE -eq "1") {
        [Console]::Error.WriteLine("[percus:hook external-action-guard] PERCUS_EXTERNAL_OVERRIDE setado — permitindo.")
        exit 0
    }

    # Escape hatch: autorizacao em lote via arquivo (janela de 60min por timestamp_unix DENTRO do
    # JSON, nao LastWriteTime do filesystem -- metadado de filesystem pode mudar sem o conteudo
    # mudar; o timestamp gravado na criacao e mais confiavel). Arquivo atravessa a fronteira de
    # processo do hook; env var da sessao do Claude nao atravessa (achado 2026-07-31).
    #
    # IMPORTANTE: try/catch AQUI, LOCAL -- nao deixar erro desta checagem cair no catch generico
    # do fim do script. O catch generico do hook e fail-OPEN de proposito (erro interno do script
    # nao pode travar a maquina). Mas erro NESTA checagem especifica (arquivo ilegivel, JSON
    # corrompido, campo faltando) tem que continuar pro fluxo normal do R20 -- ou seja, tem que
    # poder BLOQUEAR. Fail-open aqui seria: permissao negada no arquivo = "ah, deu erro, libera
    # geral" -- o oposto do que devia acontecer.
    try {
        $authFile = Join-Path $cwd ".percus/acao-externa-autorizada.json"
        if (Test-Path $authFile) {
            $auth = Get-Content $authFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            # Comparacao em epoch puro, NUNCA converter pra hora local antes de subtrair --
            # achado do R11/DeepSeek no review deste plano: subtracao de DateTime local e
            # aritmetica de relogio de parede, nao tempo real decorrido. Numa transicao de
            # horario de verao isso podia fazer autorizacao EXPIRADA parecer fresca (perigoso).
            # Epoch (segundos desde 1970 UTC) e monotonico e imune a fuso/DST por definicao.
            $agoraUnix = [DateTimeOffset]::new((Get-Date)).ToUnixTimeSeconds()
            $idadeSeg = $agoraUnix - $auth.timestamp_unix
            if ($idadeSeg -ge 0 -and $idadeSeg -lt 3600) {
                [Console]::Error.WriteLine("[percus:hook external-action-guard] autorizacao em lote ativa (id: $($auth.id), motivo: $($auth.motivo), idade: $([math]::Round($idadeSeg/60,1))min) -- permitindo.")
                exit 0
            }
        }
    } catch {
        # Qualquer falha nesta checagem especifica (arquivo ilegivel, JSON invalido, campo
        # faltando, relogio no passado) NAO libera -- so significa "nao consegui confirmar
        # autorizacao", cai pro fluxo normal do R20 abaixo. Fail-closed desta checagem, mesmo
        # com o resto do hook sendo fail-open pra erro interno inesperado.
        [Console]::Error.WriteLine("[percus:hook external-action-guard] falha ao processar autorizacao em lote: $($_.Exception.Message)")
    }

    # Verifica council recente (premise_validity)
    $councilDir = Join-Path $cwd ".deepseek/council-log"
```

- [ ] **Step 5: Rodar e confirmar que TODOS os testes do arquivo passam**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/external-action-guard.tests.ps1' -Output Detailed"`
Expected: PASS — todos os testes (os pré-existentes + os 2 novos), 0 falhas.

- [ ] **Step 6: Commit**

```bash
git add plugin/percus-review/hooks/external-action-guard.ps1 plugin/percus-review/tests/external-action-guard.tests.ps1
git commit -m "feat(r20): escape hatch de autorizacao em lote via arquivo -- caso feliz"
```

---

### Task 2: Fail-closed em erro na checagem (a correção de bug do council-consult)

**Files:**
- Modify: `plugin/percus-review/tests/external-action-guard.tests.ps1`

- [ ] **Step 1: Escrever os 2 testes de fail-closed**

```powershell
    It "BLOQUEIA (fail-closed) quando o arquivo de autorizacao tem JSON corrompido" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $percusDir = Join-Path $dir ".percus"
        New-Item -ItemType Directory -Path $percusDir -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $percusDir "acao-externa-autorizada.json"), "{ isto nao e json", (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $saida = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "JSON corrompido nao pode liberar -- fail-closed desta checagem especifica"
        ($saida -join " ") | Should -Match "falha ao processar autorizacao em lote" -Because "erro tecnico tem que ser distinguivel de 'nunca autorizado' no log (achado R11/DeepSeek)"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "BLOQUEIA quando o arquivo de autorizacao existe mas NAO tem timestamp_unix" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $percusDir = Join-Path $dir ".percus"
        New-Item -ItemType Directory -Path $percusDir -Force | Out-Null
        '{"id":"x","motivo":"sem timestamp"}' | Set-Content -LiteralPath (Join-Path $percusDir "acao-externa-autorizada.json") -Encoding utf8
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "sem timestamp_unix nao da pra calcular idade -- bloqueia, nao libera"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
```

**Nota:** não é necessário um teste separado de "arquivo com permissão de leitura negada" — ele
exercitaria exatamente o mesmo bloco `catch` que os dois testes acima já cobrem (`Get-Content
-ErrorAction Stop` lança em ambos os casos, permissão negada ou JSON corrompido; o `catch` trata
os dois do mesmo jeito). Manipulação de ACL no Windows dentro de um teste Pester é frágil e cara
de fazer/desfazer com segurança — o ganho de confiança adicional não compensa a fragilidade.

- [ ] **Step 2: Rodar e confirmar que passa (o `catch` da Task 1 já deveria cobrir isso, se
implementado certo — se algum desses 2 testes falhar aqui, é sinal de que o `try/catch` da Task 1
está fail-open em vez de fail-closed, e precisa ser corrigido antes de prosseguir)**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/external-action-guard.tests.ps1' -Output Detailed"`
Expected: PASS — todos os testes, 0 falhas.

- [ ] **Step 3: Commit**

```bash
git add plugin/percus-review/tests/external-action-guard.tests.ps1
git commit -m "test(r20): prova que erro na checagem de autorizacao bloqueia, nunca libera"
```

---

### Task 3: Escopo por-diretório, independência do env var, mensagem de log

**Files:**
- Modify: `plugin/percus-review/tests/external-action-guard.tests.ps1`

- [ ] **Step 1: Escrever os 3 testes**

```powershell
    It "autorizacao criada num diretorio NAO libera acao rodada em outro diretorio (escopo por-projeto)" {
        $dirAutorizado = Join-Path ([IO.Path]::GetTempPath()) ("eag-auth-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $dirOutro      = Join-Path ([IO.Path]::GetTempPath()) ("eag-outro-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dirOutro -Force | Out-Null
        New-AutorizacaoFixture -Dir $dirAutorizado -IdadeMinutos 5 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dirOutro -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "autorizacao de outro diretorio nao pode vazar"
        Remove-Item -Recurse -Force $dirAutorizado,$dirOutro -ErrorAction SilentlyContinue
    }

    It "cobre acao externa alem de git push -- slack-cli tambem e liberado pela autorizacao em lote" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"slack-cli send --channel geral msg"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 0 -Because "escopo cobre TODAS as acoes externas do R20, nao so push"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "mensagem de stderr ao usar autorizacao em lote inclui id e motivo" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $caminho = New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 -Motivo "fim do dia, autorizado"
        $auth = Get-Content $caminho -Raw | ConvertFrom-Json
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $saida = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        ($saida -join " ") | Should -Match ([regex]::Escape($auth.id))
        ($saida -join " ") | Should -Match "fim do dia, autorizado"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
```

- [ ] **Step 2: Rodar e confirmar que passa**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/external-action-guard.tests.ps1' -Output Detailed"`
Expected: PASS — todos os testes, 0 falhas.

- [ ] **Step 3: Rodar a suite inteira pra confirmar que nada quebrou**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path plugin/percus-review/tests -PassThru | Select-Object Result,TotalCount,PassedCount,FailedCount"`
Expected: contagem de passados maior que a baseline anterior + os 7 novos deste hook (2 do Task 1
+ 2 do Task 2 + 3 deste), 0 falhas novas (a única falha esperada é a pré-existente e documentada
`no-legacy-kit-path.tests.ps1`, não relacionada).

- [ ] **Step 4: Commit**

```bash
git add plugin/percus-review/tests/external-action-guard.tests.ps1
git commit -m "test(r20): escopo por-diretorio, cobertura alem de git push, mensagem de log"
```

---

### Task 4: `scripts/autorizar-acao-externa.ps1` — cria o arquivo de autorização

**Files:**
- Create: `scripts/autorizar-acao-externa.ps1`
- Create: `plugin/percus-review/tests/autorizar-acao-externa.tests.ps1`

- [ ] **Step 1: Escrever o teste**

```powershell
#requires -Version 5.1
# Script chamado pelo AGENTE depois de confirmacao explicita do operador na conversa -- ver
# docs/superpowers/specs/2026-08-06-r20-autorizacao-lote-design.md. O teste NUNCA toca o
# .percus/ real do repo: monta pasta temp e afere o resultado.

Describe "autorizar-acao-externa.ps1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\autorizar-acao-externa.ps1"
        $script:temps   = New-Object System.Collections.ArrayList
    }
    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "cria .percus/acao-externa-autorizada.json com id, motivo e timestamp_unix recente" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("autoriza-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)

        & $script:script -Motivo "fim do dia, pode publicar" -ProjetoRoot $dir | Out-Null

        $caminho = Join-Path $dir ".percus\acao-externa-autorizada.json"
        Test-Path $caminho | Should -Be $true
        $auth = Get-Content $caminho -Raw | ConvertFrom-Json
        { [guid]::Parse($auth.id) } | Should -Not -Throw
        $auth.motivo | Should -Be "fim do dia, pode publicar"
        $agoraEpoch = [DateTimeOffset]::new((Get-Date)).ToUnixTimeSeconds()
        [math]::Abs($agoraEpoch - $auth.timestamp_unix) | Should -BeLessThan 10
    }

    It "cria a pasta .percus se ela ainda nao existir" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("autoriza-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)
        Test-Path (Join-Path $dir ".percus") | Should -Be $false

        & $script:script -Motivo "teste" -ProjetoRoot $dir | Out-Null

        Test-Path (Join-Path $dir ".percus") | Should -Be $true
    }

    It "sobrescreve autorizacao existente (reautorizar renova a janela e troca o id)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("autoriza-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)

        & $script:script -Motivo "primeira" -ProjetoRoot $dir | Out-Null
        $primeiroId = (Get-Content (Join-Path $dir ".percus\acao-externa-autorizada.json") -Raw | ConvertFrom-Json).id

        & $script:script -Motivo "segunda" -ProjetoRoot $dir | Out-Null
        $auth = Get-Content (Join-Path $dir ".percus\acao-externa-autorizada.json") -Raw | ConvertFrom-Json

        $auth.motivo | Should -Be "segunda"
        $auth.id | Should -Not -Be $primeiroId
    }

    It "-Motivo e obrigatorio" {
        { & $script:script -ProjetoRoot "C:\qualquer" -ErrorAction Stop } | Should -Throw
    }
}
```

- [ ] **Step 2: Rodar e confirmar que falha (script ainda não existe)**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/autorizar-acao-externa.tests.ps1' -Output Detailed"`
Expected: FAIL — script não encontrado.

- [ ] **Step 3: Criar o script**

```powershell
#requires -Version 5.1
<#
.SYNOPSIS
  Cria o arquivo de autorizacao em lote pra acoes externas bloqueadas pelo R20.
.DESCRIPTION
  Chamado pelo AGENTE depois de confirmacao explicita do operador na conversa -- nunca antes.
  Ver docs/superpowers/specs/2026-08-06-r20-autorizacao-lote-design.md pro raciocinio completo,
  inclusive o risco aceito conscientemente (o agente cria o proprio arquivo que o hook confia).

  ASCII puro nos comentarios, mesma disciplina dos scripts irmaos deste kit
  (renomear-kit-local.ps1, registrar-hooks-settings.ps1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Motivo,
    [string]$ProjetoRoot
)
$ErrorActionPreference = "Stop"

if (-not $ProjetoRoot) { $ProjetoRoot = (Get-Location).Path }

$dir = Join-Path $ProjetoRoot ".percus"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$agora = Get-Date
$epoch = [DateTimeOffset]::new($agora).ToUnixTimeSeconds()
$auth = [pscustomobject]@{
    id             = [guid]::NewGuid().ToString()
    motivo         = $Motivo
    autorizado_em  = $agora.ToString("o")
    timestamp_unix = $epoch
}

$caminho = Join-Path $dir "acao-externa-autorizada.json"
$texto = $auth | ConvertTo-Json
[IO.File]::WriteAllText($caminho, $texto, (New-Object System.Text.UTF8Encoding($false)))

$expiraEm = $agora.AddMinutes(60).ToString("HH:mm")
Write-Host "[autorizar-acao-externa] autorizacao criada: id=$($auth.id) motivo='$Motivo' valida ate $expiraEm"
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/autorizar-acao-externa.tests.ps1' -Output Detailed"`
Expected: PASS — 4 testes, 0 falhas.

- [ ] **Step 5: Commit**

```bash
git add scripts/autorizar-acao-externa.ps1 plugin/percus-review/tests/autorizar-acao-externa.tests.ps1
git commit -m "feat(r20): script autorizar-acao-externa.ps1 -- cria o arquivo de autorizacao em lote"
```

---

### Task 5: `scripts/registrar-uso-autorizacao.ps1` — log de auditoria

**Files:**
- Create: `scripts/registrar-uso-autorizacao.ps1`
- Create: `plugin/percus-review/tests/registrar-uso-autorizacao.tests.ps1`

- [ ] **Step 1: Escrever o teste**

```powershell
#requires -Version 5.1
Describe "registrar-uso-autorizacao.ps1" {
    BeforeAll {
        $script:kitRoot     = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:scriptUsar  = Join-Path $script:kitRoot "scripts\registrar-uso-autorizacao.ps1"
        $script:scriptCriar = Join-Path $script:kitRoot "scripts\autorizar-acao-externa.ps1"
        $script:temps       = New-Object System.Collections.ArrayList
    }
    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "acrescenta uma linha em .percus/autorizacoes-usadas.jsonl com id, motivo, comando e quando" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("uso-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)
        & $script:scriptCriar -Motivo "fim do dia" -ProjetoRoot $dir | Out-Null
        $auth = Get-Content (Join-Path $dir ".percus\acao-externa-autorizada.json") -Raw | ConvertFrom-Json

        & $script:scriptUsar -Comando "git push origin main" -ProjetoRoot $dir | Out-Null

        $logPath = Join-Path $dir ".percus\autorizacoes-usadas.jsonl"
        Test-Path $logPath | Should -Be $true
        $linha = Get-Content $logPath -Raw | ConvertFrom-Json
        $linha.id | Should -Be $auth.id
        $linha.motivo | Should -Be "fim do dia"
        $linha.comando | Should -Be "git push origin main"
        $linha.quando | Should -Not -BeNullOrEmpty
    }

    It "acumula multiplas linhas (append, nao sobrescreve)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("uso-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)
        & $script:scriptCriar -Motivo "fim do dia" -ProjetoRoot $dir | Out-Null

        & $script:scriptUsar -Comando "git push origin main" -ProjetoRoot $dir | Out-Null
        & $script:scriptUsar -Comando "gh pr comment 1 --body oi" -ProjetoRoot $dir | Out-Null

        $linhas = @(Get-Content (Join-Path $dir ".percus\autorizacoes-usadas.jsonl"))
        $linhas.Count | Should -Be 2
    }

    It "lanca erro claro se nao ha autorizacao ativa" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("uso-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)

        { & $script:scriptUsar -Comando "git push origin main" -ProjetoRoot $dir -ErrorAction Stop } |
            Should -Throw -ExpectedMessage "*nenhuma autorizacao*"
    }
}
```

- [ ] **Step 2: Rodar e confirmar que falha (script ainda não existe)**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/registrar-uso-autorizacao.tests.ps1' -Output Detailed"`
Expected: FAIL — script não encontrado.

- [ ] **Step 3: Criar o script**

```powershell
#requires -Version 5.1
<#
.SYNOPSIS
  Registra o uso da autorizacao em lote no log de auditoria (.percus/autorizacoes-usadas.jsonl).
.DESCRIPTION
  Chamado pelo AGENTE toda vez que executa uma acao externa usando a autorizacao em lote
  (nao quando usa PERCUS_EXTERNAL_OVERRIDE ou aprovacao pontual do operador pra uma acao so).
  Le id e motivo do arquivo de autorizacao ja existente -- nao precisa que o chamador repita.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Comando,
    [string]$ProjetoRoot
)
$ErrorActionPreference = "Stop"

if (-not $ProjetoRoot) { $ProjetoRoot = (Get-Location).Path }

$authFile = Join-Path $ProjetoRoot ".percus/acao-externa-autorizada.json"
if (-not (Test-Path $authFile)) {
    throw "nenhuma autorizacao em lote ativa em '$authFile' -- nada pra registrar"
}
$auth = Get-Content $authFile -Raw | ConvertFrom-Json

$linha = [pscustomobject]@{
    id      = $auth.id
    motivo  = $auth.motivo
    comando = $Comando
    quando  = (Get-Date).ToString("o")
} | ConvertTo-Json -Compress

$logPath = Join-Path $ProjetoRoot ".percus/autorizacoes-usadas.jsonl"
Add-Content -LiteralPath $logPath -Value $linha -Encoding UTF8

Write-Host "[registrar-uso-autorizacao] registrado: id=$($auth.id) comando='$Comando'"
```

- [ ] **Step 4: Rodar e confirmar que passa**

Run: `pwsh -NoProfile -Command "Invoke-Pester -Path 'plugin/percus-review/tests/registrar-uso-autorizacao.tests.ps1' -Output Detailed"`
Expected: PASS — 3 testes, 0 falhas.

- [ ] **Step 5: Commit**

```bash
git add scripts/registrar-uso-autorizacao.ps1 plugin/percus-review/tests/registrar-uso-autorizacao.tests.ps1
git commit -m "feat(r20): script registrar-uso-autorizacao.ps1 -- log de auditoria da autorizacao em lote"
```

---

### Task 6: Documentar os dois mecanismos em `01_REGRAS_INEGOCIAVEIS.md`

**Files:**
- Modify: `01_REGRAS_INEGOCIAVEIS.md`

- [ ] **Step 1: Localizar e substituir a seção "Gate verificável" do R20**

Texto atual (dentro de `## R20. Decisões de conselho não autorizam ação externa pública`):

```markdown
### Gate verificável

- Antes de qualquer ação externa pública pelo agente:
  - Log explícito de `operator_approved: true` na conversa, OU
  - Variável de ambiente `PERCUS_EXTERNAL_OVERRIDE=1` com motivo declarado em commit/log
- **Logs de council consult NÃO contam como autorização** (são opinião, não gate)
- Hook `plugin/percus-review/hooks/external-action-guard.ps1` (v6.7.0+) faz
  enforcement runtime via PreToolUse bloqueando `gh pr comment`, `gh issue close`,
  `slack-cli`, `git push` sem aprovação explícita
```

Substituir por:

```markdown
### Gate verificável

- Antes de qualquer ação externa pública pelo agente, um dos dois:
  - Variável de ambiente `PERCUS_EXTERNAL_OVERRIDE=1`, setada FORA da sessão do Claude (ela não
    atravessa a fronteira de processo do hook `PreToolUse` — setar dentro da sessão não funciona).
  - Arquivo `.percus/acao-externa-autorizada.json` (janela de 60min, criado pelo agente via
    `scripts/autorizar-acao-externa.ps1` DEPOIS de confirmação explícita do operador na conversa
    — nunca antes). Risco estrutural aceito conscientemente: o agente cria o arquivo que o hook
    confia, sem verificação externa de que a confirmação aconteceu de verdade. Ver
    `docs/superpowers/specs/2026-08-06-r20-autorizacao-lote-design.md` pro raciocínio completo.
    Todo uso registrado em `.percus/autorizacoes-usadas.jsonl` via
    `scripts/registrar-uso-autorizacao.ps1`.
- **Logs de council consult NÃO contam como autorização** (são opinião, não gate)
- Hook `plugin/percus-review/hooks/external-action-guard.ps1` (v6.7.0+, arquivo v6.35.0+) faz
  enforcement runtime via PreToolUse bloqueando `gh pr comment`, `gh issue close`,
  `slack-cli`, `git push` sem aprovação explícita
```

- [ ] **Step 2: Conferir que o arquivo continua Markdown válido (sem checar sintaxe especial, só ler de volta)**

Run: `pwsh -NoProfile -Command "Get-Content '01_REGRAS_INEGOCIAVEIS.md' -TotalCount 5"`
Expected: as primeiras linhas do arquivo aparecem normalmente (arquivo não foi corrompido).

- [ ] **Step 3: Commit**

```bash
git add 01_REGRAS_INEGOCIAVEIS.md
git commit -m "docs(r20): documenta os dois mecanismos de autorizacao (env var + arquivo)"
```

---

## Fora do escopo deste plano (não implementar como parte dele)

- **Corrigir a memória `git-push-sempre-bloqueado-r20.md`** (fora do repo git, em
  `.claude-home/projects/.../memory/`) — por decisão explícita da spec, só depois que o mecanismo
  estiver **comprovado funcionando ponta a ponta numa sessão real**, não só nos testes. Isso é
  trabalho da sessão orquestradora depois que este plano terminar, não de um subagent.
- **Script de revogação antecipada** — é só `Remove-Item -LiteralPath ".percus/acao-externa-autorizada.json" -ErrorAction SilentlyContinue`, simples e arriscado demais de errar pra precisar de script próprio; comportamento do agente, não código.

## Self-Review

**Cobertura da spec:** risco aceito (registrado, sem código); motivação/arquitetura (Tasks 1-3);
escopo todas-as-ações (Task 3, teste com `slack-cli`) e por-projeto (Task 3, teste de vazamento
entre diretórios); formato do arquivo com `id`+`timestamp_unix` (Task 4); mudança no hook com
fail-closed local (Tasks 1-2); comportamento do agente itens 1-3 e 5-6 (não são código, já
decididos na spec); item 4 (auditoria) → Task 5; testes da spec → Tasks 1-3 (hook) e 4-5
(scripts); documentação → Task 6; achados extras do council (worktree, concorrência no log, git
clean) → já resolvidos/aceitos na própria spec, nada a implementar.

**Placeholder scan:** nenhum "TBD"/"TODO" nos blocos de código; todo `Run:` tem comando exato e
`Expected:` concreto.

**Consistência de tipos:** `-Motivo`/`-ProjetoRoot` em `autorizar-acao-externa.ps1` usados
identicamente no teste da Task 4 e chamados pela Task 5; `id`/`motivo`/`timestamp_unix` no JSON
batem entre o que a Task 4 escreve e o que o hook (Tasks 1-3) e a Task 5 leem — mesmos nomes de
campo em todo lugar.
