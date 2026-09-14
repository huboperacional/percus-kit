# Checkpoint e sessão nova só pelo operador — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o `context-budget-guard` passa a só informar o tamanho do contexto. A skill `checkpoint` e o texto do canon passam a ter o operador como único gatilho de checkpoint e de sessão nova.

**Architecture:** o conserto tira o texto imperativo das duas implementações do hook (`.ps1` e `.sh`, em paridade) e fecha toda mensagem ao agente com a mesma frase: a decisão é do operador. Níveis, debounce e cálculo de janela não mudam. Os gatilhos automáticos saem da skill (`description`, "Quando rodar", passo 5) e dos seis docs do canon que repetiam a política antiga. Cada porta ganha um teste que falha antes do conserto, e a versão vai para 6.54.0.

**Tech Stack:** Windows PowerShell 5.1 (runtime do hook via `.cmd`), pwsh 7 + Pester 5 (testes), bash (porta `.sh`), git.

**Spec:** não há documento de spec. A fonte é a decisão do operador de 2026-09-14, copiada abaixo com o defeito medido. O executor lê só este plano.

### Defeito medido (2026-09-14)

Uma sessão CL_Liliflow (`claude-opus-5[1m]`, janela de 1M) estava com 244k tokens, 26% da janela. Ela fez checkpoint e mandou o operador abrir sessão nova sem ele pedir. Aviso literal recebido do hook:

> [percus:context-budget] contexto vivo ~244k tokens. Janela INDETERMINADA (passou de ~200k, o piso que eu supunha, e a sessao continua viva) -- entao ela e MAIOR que isso, mas eu nao sei quanto, e sem o denominador nao da pra dizer se voce esta perto do teto. Defina PERCUS_CTX_WINDOW pra eu voltar a medir percentual. Acao: rode percus-review:checkpoint e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto.

As causas foram conferidas no código em 9a23c82:
1. `plugin/percus-review/hooks/context-budget-guard.ps1:140-169`: o `model` do transcript não traz `[1m]`. O hook cai no piso de 200k e, acima dele, declara a janela INDETERMINADA. **Descobrir a janela não é escopo deste plano.**
2. `context-budget-guard.ps1:273-277` (gêmeo `.sh:133-137`) ordena checkpoint + RESET em todo aviso. A condição de dias (`.ps1:267-269`, `.sh:131`) ordena "Nao continue nela: abra sessao nova". O aviso opcional ao operador (`.ps1:292`, `.sh:140`) diz "Hora de checkpoint + sessao nova".
3. `plugin/percus-review/skills/checkpoint/SKILL.md` põe o hook como gatilho em três lugares: na `description` (linha 3), em "Quando rodar" (17-24) e na introdução (9-10). O passo 5 (92-104) torna o reset obrigatório quando o hook avisou.

### Decisão do operador (2026-09-14)

**Só o operador inicia checkpoint e manda abrir sessão nova.** O hook passa a SÓ INFORMAR o tamanho do contexto, sem ordem. A skill `checkpoint` perde o gatilho do hook e o reset obrigatório do passo 5. O agente nunca inicia checkpoint nem manda abrir sessão nova por conta própria; no máximo menciona o número ao operador uma vez. A mitigação `PERCUS_CTX_WINDOW=1000000` no settings do usuário já está aplicada, e o conserto não depende dela.

## Global Constraints

- **Worktree isolado:** raiz `D:\Claud Automations\percus-kit\.claude\worktrees\checkpoint-so-operador`. Todo caminho deste plano é relativo a ela, e a sessão executora roda com o cwd nessa raiz.
- **Ferramentas:** na ferramenta Bash o isolamento recusa o token `pwsh`/`powershell`. PowerShell vai pela ferramenta **PowerShell** (`Invoke-Pester -Path '.\plugin\...'`, `& '.\scripts\...'`). Git vai pela ferramenta **Bash**, com um comando simples por chamada, sem `-C` e sem `&&`.
- **PowerShell 5.1 é o runtime real dos hooks:** proibido `??`, ternário, `Join-Path` com mais de um filho, `-AdditionalChildPath` e `[IO.Path]::GetRelativePath`.
- **Codificação:** a fonte `.ps1` do hook fica em ASCII (hoje tem BOM e 0 linha não-ASCII), e arquivo com BOM se edita só com a ferramenta Edit. O `.sh` fica em ASCII e LF. Os `.tests.ps1` têm BOM, e o texto novo deles vai em ASCII (acento no regex vira `.`). `hooks-manifest.json` não tem BOM e usa LF. Os `.md` são UTF-8 sem BOM, com acento livre.
- **Pester 5:** um só `BeforeAll`/`AfterAll` por bloco (`pester-blocos-unicos.tests.ps1`). Nome de `It` sem `<` nem `>`.
- **O ambiente vaza pros testes (medido nesta máquina):** a sessão herda `PERCUS_CTX_WINDOW=1000000` de `D:\Claud Automations\.claude-home\settings.json`. O `context-budget-guard.tests.ps1` não fixa a janela, então os casos de 160k/185k ficam mudos e falham por causa do ambiente. A Task 1, Step 1 conserta isso no próprio arquivo. **Não limpe a variável na mão** antes de rodar a suíte: baseline e rodada final usam o mesmo ambiente, para que a comparação valha.
- **Paridade `.ps1`/`.sh`:** a mensagem ao agente e a mensagem ao operador saem idênticas nos dois runtimes, e os testes comparam a string inteira.
- **Frase literal que fecha toda mensagem ao agente** (ASCII, uma linha):
  `Isto e so informacao: decidir checkpoint ou sessao nova e do operador. Voce NAO inicia checkpoint nem manda abrir sessao nova por conta propria; no maximo mencione estes numeros ao operador uma vez.`
- **Mensagem literal ao operador** (só com `PERCUS_CTX_OPERADOR=1`):
  `[percus:hook context-budget-guard] contexto ~{k}k tokens ({pct}% da janela | janela indeterminada). Checkpoint e sessao nova ficam a seu criterio.`
- **Gate de versão:** `v2/gates/percus-gate.sh:552-563` exige que a versão do índice seja maior que a de `origin/main` (6.53.0) em todo commit que stage `plugin/`, `templates/`, `v2/`, `scripts/` ou `0[1-6]_*.md`. Por isso o bump para **6.54.0 vai no commit da Task 1**, não no fim.
- **Gate de conhecimento (medido em 9a23c82, 2026-09-14):** `sh v2/gates/percus-gate.sh` sai 1 com exatamente 5 `BLOQUEADO`, todos "verbete FORA do INDICE.md" e todos em `conhecimento/resolver/`: `implementador-sdd-nao-cumpre-review-duplo-de-pasta-sensivel`, `janela-de-estabilidade-de-alerta-se-escolhe-por-replay-do-log`, `mascara-de-segredo-por-regex-vira-caca-a-separador`, `reachout-timelock-do-whatsapp-desloga-device-companion` e `subagente-em-background-nao-acorda-com-notificacao`. **Regra:** antes de cada commit, rode o gate com os arquivos já staged. Use o escape `PERCUS_GATE_OVERSIZE="<motivo>"`, com a linha `Gate:` no corpo, **somente se todos os `BLOQUEADO` forem "FORA do INDICE.md" de arquivos que este branch não toca.** Qualquer outra violação se conserta. Nunca regere o índice, nunca use `PERCUS_HOOKS_DISABLED`. Amend só de mensagem é impossível, então acerte o corpo na primeira vez. O gate que roda no commit é o de `$PERCUS_CANON_V2_DIR` (checkout principal), com a mesma lógica, aplicado ao índice deste worktree.
- **R11 em todo commit que leva `.ps1`/`.sh`/`.json`:** `git add -- <arquivos>` → `& '.\plugin\percus-review\scripts\deepseek-review.ps1'` (lê cached + working tree) → confira cada finding contra o código. Finding que procede se conserta, depois roda os testes da tarefa, `git add` e R11 de novo. Finding que não procede vai no corpo do commit, com o porquê. Commit só de `.md` dispensa R11.
- **Commit:** por pathspec, só com os arquivos da tarefa (`git commit ... -- <arquivos>`), mensagem em ASCII com `-m` por parágrafo (não use `-F`), e por último `-m "Co-Authored-By: ..."` com a linha do lembrete de atribuição da sessão que commitar.
- **Testes por tarefa:** rode os arquivos de teste da tarefa. Some `ps51-compat.tests.ps1` e `hooks-leitura-utf8.tests.ps1` quando mexer em `.ps1` (os `.tests.ps1` contam), `hooks-manifest.tests.ps1` quando mexer em hook ou manifesto, e `pester-blocos-unicos.tests.ps1` quando mexer em arquivo de teste.
- **Suíte inteira** (`& '.\scripts\rodar-suite.ps1'`): uma vez no Pré-voo e uma vez na Task 4. Nunca em paralelo com outra suíte, porque um teste grava no `hooks-manifest.json` real. O controlador agenda.
- **Sem merge e sem push.** O plano termina em 4 commits locais. O merge na `main` ativa o hook em todas as sessões desta máquina (trampolim `PERCUS_CANON_DIR`), e essa decisão é do operador.

---

## Estrutura de arquivos

| Arquivo | Responsabilidade | Tarefa |
|---|---|---|
| `plugin/percus-review/hooks/context-budget-guard.ps1` | hook (runtime 5.1): mensagem só informativa | 1 |
| `plugin/percus-review/hooks/context-budget-guard.sh` | porta bash, mesma mensagem | 1 |
| `plugin/percus-review/hooks/hooks-manifest.json` | `_nota` do hook (descrevia 150k/180k e `PERCUS_CTX_HOURS`) | 1 |
| `plugin/percus-review/tests/context-budget-guard.tests.ps1` | isolamento do ambiente + casos "só informa" nos dois runtimes | 1 |
| `CANON_VERSION.md`, `plugin/percus-review/plugin.json`, `.claude-plugin/marketplace.json`, `.percus-version` | 6.54.0 (via `scripts/bump-canon.ps1`) + changelog | 1 (bump), 2-4 (changelog) |
| `plugin/percus-review/skills/checkpoint/SKILL.md` | gatilho só pelo operador; passo 5 condicional | 2 |
| `plugin/percus-review/tests/checkpoint-gatilho.tests.ps1` | portas da skill (Task 2) + varredura do canon (Task 3) | 2, 3 |
| `v2/loops/checkpoint.md`, `templates/CLAUDE.template.md`, `templates/RESUME_PROMPT.template.md`, `01_REGRAS_INEGOCIAVEIS.md`, `comandos/SKILLS_VS_COMMANDS.md`, `comandos/REORGANIZAR_PROJETO.md` | texto do canon alinhado | 3 |

`hooks.json` não muda: registro, assinatura e escape seguem os mesmos. `v2/loops/checkpoint.md` mantém a contagem de linhas, porque o gate tem teto de 60 por loop e de 600 no núcleo.

## Mapa: decisão do operador → tarefa

| Decisão | Tarefa |
|---|---|
| Hook só informa, em todos os níveis e na condição de dias | 1 |
| Aviso ao operador informa e deixa a decisão com ele | 1 |
| Agente nunca inicia checkpoint nem manda abrir sessão nova; no máximo menciona o número uma vez | 1 (frase do hook), 2 (skill), 3 (template, R5, loop) |
| Skill perde o gatilho do hook e o reset obrigatório do passo 5 | 2 |
| Canon para de dar checkpoint ao agente | 3 |
| Não depender de `PERCUS_CTX_WINDOW` | 1 (caso de 244k sem env; ambiente zerado no teste) |
| 6.54.0 + changelog | 1 (bump), 4 (fechamento) |

---

## Pré-voo (controlador, antes da Task 1)

- [ ] **P1: Conferir o ponto de partida** (Bash, um comando por chamada)

```bash
git status --short
```
Esperado: vazio.
```bash
git log --oneline -1
```
Esperado: `9a23c82 conhecimento: script do Playwright MCP sem setTimeout; ...`
```bash
git show origin/main:CANON_VERSION.md
```
Esperado: o cabeçalho diz `6.53.0`. Se disser 6.54.0 ou mais, **pare e reporte**: outra janela publicou uma versão, e o bump da Task 1 colidiria.

- [ ] **P2: Conferir o gate** (Bash)

```bash
sh v2/gates/percus-gate.sh
```
Esperado: exit 1 e só os 5 "verbete FORA do INDICE.md" listados nas Global Constraints. Se aparecer outra violação, pare e reporte antes de tocar em qualquer arquivo.

- [ ] **P3: Suíte de baseline** (PowerShell; nada mais rodando)

```powershell
$env:PERCUS_CTX_WINDOW; & '.\scripts\rodar-suite.ps1'
```
Registre o valor da variável, os totais Passed/Failed/Skipped e o nome de cada falha. Espere falhas em `context-budget-guard.tests.ps1` causadas pelo `PERCUS_CTX_WINDOW=1000000` herdado. Elas são o vermelho da Task 1, Step 1.

---

### Task 1: Hook só informa (`.ps1` + `.sh`) e bump 6.54.0

**Files:**
- Modify: `plugin/percus-review/tests/context-budget-guard.tests.ps1` (BeforeAll do Describe, linhas 20-85; teste de dias, linhas 287-295; Context novo antes da linha 570)
- Modify: `plugin/percus-review/hooks/context-budget-guard.ps1` (linhas 12-13, 42-44, 267-277, 292)
- Modify: `plugin/percus-review/hooks/context-budget-guard.sh` (linhas 5, 131-140)
- Modify: `plugin/percus-review/hooks/hooks-manifest.json` (`_nota` do `context-budget-guard`, linha 206)
- Modify (via script): `CANON_VERSION.md`, `plugin/percus-review/plugin.json`, `.claude-plugin/marketplace.json`, `.percus-version`

**Interfaces:**
- Consumes: nada.
- Produces: a frase final e a mensagem ao operador (Global Constraints), que as Tasks 2 e 3 citam em prosa. No teste: `Assert-SoInforma -Msg <string> -Caso <string>`, e `Assert-SoInformaNosDois -Transcript <string> -Caso <string>`, que devolve `[pscustomobject]@{ Ps; Sh; SemBash }`. No canon: versão 6.54.0 committed, que o gate exige nos commits das Tasks 2 e 3.

- [ ] **Step 1: Isolar o teste do ambiente do runner**

Leia o arquivo. No `BeforeAll` do `Describe` (linha 20), logo depois de `$script:hook = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.ps1"`, insira:

```powershell

        # O runner herda o ambiente da sessao que o chamou. Com PERCUS_CTX_WINDOW=1000000 no
        # settings do usuario (mitigacao de 2026-09-14), 160k fica mudo e metade deste arquivo
        # passa a medir o ambiente em vez do hook -- mesma classe do verbete
        # teste-de-hook-no-windows-mede-o-ambiente-do-runner-e-nao-o-do-harness. Zera aqui e
        # restaura no AfterAll; os testes que precisam de um valor setam e removem o seu.
        $script:ctxEnvNomes = @('PERCUS_CTX_WINDOW', 'PERCUS_CTX_WARN', 'PERCUS_CTX_HARD', 'PERCUS_CTX_RESUME_DAYS', 'PERCUS_CTX_OPERADOR', 'PERCUS_CTX_HOURS', 'PERCUS_SKIP_CONTEXT_BUDGET')
        $script:ctxEnvSalvo = @{}
        foreach ($nome in $script:ctxEnvNomes) {
            $script:ctxEnvSalvo[$nome] = [Environment]::GetEnvironmentVariable($nome)
            Remove-Item "Env:$nome" -ErrorAction SilentlyContinue
        }
```

Depois do fechamento desse `BeforeAll`, insira o único `AfterAll` do Describe (Edit):

old:
```powershell
            return [pscustomobject]@{ Code = $code; Out = $texto; Json = $json; Ms = $sw.ElapsedMilliseconds; Cwd = $Cwd }
        }
    }

    It "existe" {
```
new:
```powershell
            return [pscustomobject]@{ Code = $code; Out = $texto; Json = $json; Ms = $sw.ElapsedMilliseconds; Cwd = $Cwd }
        }
    }

    AfterAll {
        foreach ($nome in $script:ctxEnvNomes) {
            $valor = $script:ctxEnvSalvo[$nome]
            if ($null -eq $valor) { Remove-Item "Env:$nome" -ErrorAction SilentlyContinue }
            else { Set-Item "Env:$nome" $valor }
        }
    }

    It "existe" {
```

Rode (PowerShell, com o env herdado da sessão):
```powershell
$env:PERCUS_CTX_WINDOW; Invoke-Pester -Path '.\plugin\percus-review\tests\context-budget-guard.tests.ps1' -Output Detailed
```
Esperado: a variável imprime `1000000` e o arquivo sai com **0 Failed**. As falhas do P3 neste arquivo somem. Se a variável não estiver setada nesta sessão, rode antes `$env:PERCUS_CTX_WINDOW='1000000';` na mesma linha, para provar o isolamento.

- [ ] **Step 2: Escrever os testes que falham**

(a) No teste de idade do transcript (linhas 287-295), a asserção `'sess[aã]o nova'` exigia a ordem. Substitua o `It` inteiro:

old:
```powershell
        It "100k tokens mas transcript iniciado ha 3 dias (resume velho) -> avisa citando os dias" {
            $t = New-Transcript -Tokens 100000 -HorasAtras 72
            $r = Invoke-Guard -Transcript $t
            $r.Json | Should -Not -BeNullOrEmpty
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '3 dias'
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'sess[aã]o nova'
        }
```
new:
```powershell
        It "100k tokens mas transcript iniciado ha 3 dias (resume velho) -> informa citando os dias" {
            $t = New-Transcript -Tokens 100000 -HorasAtras 72
            $r = Invoke-Guard -Transcript $t
            $r.Json | Should -Not -BeNullOrEmpty
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '3 dias'
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'retomada/velha'
            # ate a 6.53.0 esta assercao era 'sessao nova' -- exigia a ordem que o operador tirou
            $r.Json.hookSpecificOutput.additionalContext | Should -Not -Match 'Nao continue nela'
        }
```

(b) Insira o Context novo **imediatamente antes** da linha `    Context "limiares sao configuraveis por env (o hook mede o que o operador mandar)" {`:

```powershell
    # Decisao do operador em 2026-09-14: "so o operador inicia checkpoint e manda abrir sessao nova".
    #
    # Ate a 6.53.0 TODA mensagem terminava em "Acao: rode percus-review:checkpoint e encerre em
    # RESET" -- inclusive com a janela INDETERMINADA, quando o proprio hook acabara de admitir que
    # nao sabia se a sessao estava perto do teto. Medido: sessao claude-opus-5[1m] (janela 1M) com
    # 244k tokens, 26% da janela, recebeu esse aviso, fez checkpoint e mandou o operador abrir
    # sessao nova sem ele pedir. O model do transcript nao traz [1m]; o hook caiu no piso de 200k.
    # Estes testes varrem TODOS os caminhos que falam -- aviso, duro, duro com HARD explicito,
    # indeterminada, idade do transcript -- nos dois runtimes, porque a ordem estava nos dois.
    Context "so informa: checkpoint e sessao nova sao do operador (2026-09-14)" {
        BeforeAll {
            $script:ordens = @(
                'Acao:',
                'rode percus-review:checkpoint',
                'encerre em RESET',
                'abra sessao nova',
                'Nao continue nela',
                'so o reset salva contexto'
            )
            $script:regraOperador = 'Isto e so informacao: decidir checkpoint ou sessao nova e do operador. Voce NAO inicia checkpoint nem manda abrir sessao nova por conta propria; no maximo mencione estes numeros ao operador uma vez.'

            $script:bashSo = (Get-Command bash -ErrorAction SilentlyContinue).Source
            if (-not $script:bashSo) {
                $script:bashSo = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
                                 Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            }
            $script:shSo = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.sh"

            # Roda o .sh e devolve o JSON (ou $null se ele ficou mudo).
            function Invoke-GuardShSo {
                param([string]$Transcript, [string]$SessionId = "so-sh-$(Get-Random)")
                $cwd = Split-Path $Transcript -Parent
                $payload = @{ session_id = $SessionId; transcript_path = $Transcript; cwd = $cwd; hook_event_name = "PostToolUse" } | ConvertTo-Json -Compress
                Push-Location $cwd
                try { $txt = (($payload | & $script:bashSo $script:shSo 2>$null) -join "").Trim() } finally { Pop-Location }
                if (-not $txt) { return $null }
                return ($txt | ConvertFrom-Json)
            }

            # Nenhuma ordem, e a regra do operador presente. Mensagem vazia NAO passa (anti-vacuidade).
            function Assert-SoInforma {
                param([string]$Msg, [string]$Caso)
                $Msg | Should -Not -BeNullOrEmpty -Because "o hook tinha que ter falado no caso '$Caso'"
                $Msg | Should -Match '~\d+k tokens' -Because "o numero e a informacao que fica ($Caso)"
                foreach ($o in $script:ordens) {
                    $Msg | Should -Not -Match ([regex]::Escape($o)) -Because "caso '$Caso' ainda ordena: $Msg"
                }
                $Msg.Contains($script:regraOperador) | Should -BeTrue -Because "caso '$Caso' tem que dizer que a decisao e do operador: $Msg"
            }

            # Os DOIS runtimes no mesmo transcript: sem ordem, com a regra, e mensagem identica.
            function Assert-SoInformaNosDois {
                param([string]$Transcript, [string]$Caso)
                $r = Invoke-Guard -Transcript $Transcript
                $msgPs = $r.Json.hookSpecificOutput.additionalContext
                Assert-SoInforma -Msg $msgPs -Caso "$Caso (.ps1)"
                $msgSh = $null
                if ($script:bashSo) {
                    $sh = Invoke-GuardShSo -Transcript $Transcript
                    if ($sh) { $msgSh = $sh.hookSpecificOutput.additionalContext }
                    Assert-SoInforma -Msg $msgSh -Caso "$Caso (.sh)"
                    $msgSh | Should -Be $msgPs -Because "paridade no caso '$Caso'`nps: $msgPs`nsh: $msgSh"
                }
                return [pscustomobject]@{ Ps = $msgPs; Sh = $msgSh; SemBash = (-not $script:bashSo) }
            }
        }

        It "aviso sobre o piso (160k): informa o numero e nao ordena checkpoint" {
            $t = New-Transcript -Tokens 160000 -Model 'claude-opus-4-7'
            $x = Assert-SoInformaNosDois -Transcript $t -Caso 'aviso 160k'
            $x.Ps | Should -Match '160k'
            if ($x.SemBash) { Set-ItResult -Skipped -Because "sem bash: so o .ps1 foi aferido" }
        }

        It "LIMITE DURO sobre o piso (185k): o nivel continua, a ordem nao" {
            $t = New-Transcript -Tokens 185000 -Model 'claude-opus-4-7'
            $x = Assert-SoInformaNosDois -Transcript $t -Caso 'duro 185k'
            $x.Ps | Should -Match 'LIMITE DURO' -Because "o nivel e informacao sobre o teto; so a ordem saiu"
            if ($x.SemBash) { Set-ItResult -Skipped -Because "sem bash: so o .ps1 foi aferido" }
        }

        It "o caso medido: 244k num modelo sem marcador (janela INDETERMINADA) nao ordena RESET" {
            $t = New-Transcript -Tokens 244000 -Model 'claude-opus-5'
            $x = Assert-SoInformaNosDois -Transcript $t -Caso 'indeterminada 244k'
            $x.Ps | Should -Match 'INDETERMINADA'
            $x.Ps | Should -Match '244k'
            if ($x.SemBash) { Set-ItResult -Skipped -Because "sem bash: so o .ps1 foi aferido" }
        }

        It "PERCUS_CTX_HARD explicito com janela indeterminada (210k): duro, sem ordem" {
            $t = New-Transcript -Tokens 210000 -Model 'claude-opus-4-7'
            $env:PERCUS_CTX_HARD = "180000"
            try { $x = Assert-SoInformaNosDois -Transcript $t -Caso 'HARD explicito 210k' } finally { Remove-Item Env:PERCUS_CTX_HARD -ErrorAction SilentlyContinue }
            $x.Ps | Should -Match 'LIMITE DURO'
            if ($x.SemBash) { Set-ItResult -Skipped -Because "sem bash: so o .ps1 foi aferido" }
        }

        It "transcript de 3 dias (100k): informa a idade e nao manda abrir sessao nova" {
            $t = New-Transcript -Tokens 100000 -HorasAtras 72
            $x = Assert-SoInformaNosDois -Transcript $t -Caso 'transcript velho'
            $x.Ps | Should -Match '3 dias'
            if ($x.SemBash) { Set-ItResult -Skipped -Because "sem bash: so o .ps1 foi aferido" }
        }

        It "PERCUS_CTX_OPERADOR=1: o aviso ao operador informa e deixa a decisao com ele, igual nos dois runtimes" {
            $t = New-Transcript -Tokens 160000 -Model 'claude-opus-4-7'
            $env:PERCUS_CTX_OPERADOR = "1"
            try {
                $r = Invoke-Guard -Transcript $t
                $sh = $null
                if ($script:bashSo) { $sh = Invoke-GuardShSo -Transcript $t }
            } finally { Remove-Item Env:PERCUS_CTX_OPERADOR -ErrorAction SilentlyContinue }
            $op = $r.Json.systemMessage
            $op | Should -Match '160k' -Because "anti-vacuidade"
            $op | Should -Not -Match 'Hora de checkpoint' -Because "o operador decide; o hook nao empurra"
            $op | Should -Not -Match 'veja o aviso ao agente' -Because "o aviso ao agente nao tem mais acao pra ver"
            $op | Should -Match 'a seu criterio'
            if (-not $script:bashSo) { Set-ItResult -Skipped -Because "sem bash: so o .ps1 foi aferido"; return }
            $sh.systemMessage | Should -Be $op
        }
    }

```

- [ ] **Step 3: Rodar e ver falhar**

```powershell
Invoke-Pester -Path '.\plugin\percus-review\tests\context-budget-guard.tests.ps1' -Output Detailed
```
Esperado: **7 Failed**. São os 6 `It` do Context "so informa" (falham em `Acao:` ou em `Hora de checkpoint`) e o teste de 3 dias (falha em `Nao continue nela`). Todo o resto passa.

- [ ] **Step 4: Consertar o `.ps1`** (ferramenta Edit; o arquivo tem BOM)

Edit 1, cabeçalho (linhas 12-13):

old:
```text
# NAO bloqueia. Bloqueio em contexto vivo vira escape rotineiro, e escape rotineiro mata o
# sinal -- foi o que o teto do CONTEXT.md provou. O que ele faz e nao deixar o agente NAO SABER.
```
new:
```text
# NAO bloqueia e NAO ordena. Bloqueio em contexto vivo vira escape rotineiro, e escape rotineiro
# mata o sinal -- foi o que o teto do CONTEXT.md provou. Ordem tambem nao (6.54.0): ate a 6.53.0
# toda mensagem terminava em "rode checkpoint e encerre em RESET", e o agente obedecia mesmo com a
# janela INDETERMINADA (244k de uma janela de 1M, 2026-09-14). O que ele faz e nao deixar o agente
# NAO SABER. Decidir checkpoint e sessao nova e do operador, que ve o painel de contexto.
```

Edit 2 (linha 44):

old:
```text
# ele ve o contexto no painel do VSCode e dispara o checkpoint na mao (decisao dele, 2026-09-12).
```
new:
```text
# ele ve o contexto no painel do VSCode e dispara o checkpoint na mao (decisao dele, 2026-09-12).
# Nas duas mensagens o hook so INFORMA: checkpoint e sessao nova sao decisao dele (2026-09-14).
```

Edit 3, dias + linha de ação (linhas 267-277):

old:
```powershell
    if ($condDias) {
        $partes.Add("Este transcript foi iniciado ha $dias dias -- e uma sessao retomada/velha. Nao continue nela: abra sessao nova e cole o bloco de retomada do HANDOFF.")
    }
    # A linha de acao tambem nao pode reafirmar o denominador que a 1a frase acabou de negar: dizer
    # "eu nao sei a janela" e depois "resume em janela ~200k falha" e a certeza falsa de volta pela
    # porta dos fundos (finding R11, 5a rodada).
    if ($janelaIncerta) {
        $partes.Add("Acao: rode percus-review:checkpoint e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto.")
    } else {
        $partes.Add("Acao: rode percus-review:checkpoint e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto. Acima de ~${kWarn}k um resume futuro em janela ~${kJanela}k falha.")
    }
```
new:
```powershell
    if ($condDias) {
        $partes.Add("Este transcript foi iniciado ha $dias dias -- e uma sessao retomada/velha.")
    }
    # SO INFORMA (decisao do operador, 2026-09-14). Ate a 6.53.0 aqui havia "Acao: rode
    # percus-review:checkpoint e encerre em RESET" em TODO aviso, e a idade do transcript mandava
    # "Nao continue nela: abra sessao nova". Com a janela INDETERMINADA o hook dizia que nao sabia se
    # a sessao estava perto do teto e ordenava reset na frase seguinte. Medido: claude-opus-5[1m] a
    # 244k (26% de 1M) fez checkpoint e mandou o operador abrir sessao nova sem ele pedir. A mesma
    # frase fecha todos os caminhos (aviso, duro, indeterminada, dias) porque o agente repete o que
    # le (licao da 6.52.0). Paridade com o .sh: mude os dois juntos.
    $partes.Add("Isto e so informacao: decidir checkpoint ou sessao nova e do operador. Voce NAO inicia checkpoint nem manda abrir sessao nova por conta propria; no maximo mencione estes numeros ao operador uma vez.")
```

Edit 4, aviso ao operador (linha 292):

old:
```powershell
        $msgOperador = "[percus:hook context-budget-guard] contexto ~${k}k tokens ($pctTxt). Hora de checkpoint + sessao nova (veja o aviso ao agente)."
```
new:
```powershell
        # informa e deixa a decisao com ele: "Hora de checkpoint" empurrava a mesma ordem que saiu do aviso ao agente (2026-09-14)
        $msgOperador = "[percus:hook context-budget-guard] contexto ~${k}k tokens ($pctTxt). Checkpoint e sessao nova ficam a seu criterio."
```

- [ ] **Step 5: Consertar o `.sh`** (ferramenta Edit; ASCII, LF)

Edit 1 (linha 5):

old:
```text
# e avisa (additionalContext + systemMessage) acima dos limiares, uma vez por nivel por sessao.
```
new:
```text
# e informa (additionalContext; systemMessage so com PERCUS_CTX_OPERADOR) acima dos limiares, uma vez
# por nivel por sessao. SO INFORMA (6.54.0): checkpoint e sessao nova sao decisao do operador.
```

Edit 2 (linhas 131-140):

old:
```bash
if [ "$COND_D" -eq 1 ]; then MSG="$MSG Este transcript foi iniciado ha $DIAS dias -- e uma sessao retomada/velha. Nao continue nela: abra sessao nova e cole o bloco de retomada do HANDOFF."
fi
if [ "$JANELA_INCERTA" -eq 1 ]; then
  MSG="$MSG Acao: rode percus-review:checkpoint e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto."
else
  MSG="$MSG Acao: rode percus-review:checkpoint e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto. Acima de ~${KW}k um resume futuro em janela ~${KJ}k falha."
fi
# o operador so e avisado se pedir: ele ve o contexto no painel do VSCode (decisao dele 2026-09-12)
OP=""
[ "$(limiar "${PERCUS_CTX_OPERADOR:-}" 0)" -gt 0 ] && OP="[percus:hook context-budget-guard] contexto ~${K}k tokens (${PCT_TXT}). Hora de checkpoint + sessao nova (veja o aviso ao agente)."
```
new:
```bash
if [ "$COND_D" -eq 1 ]; then MSG="$MSG Este transcript foi iniciado ha $DIAS dias -- e uma sessao retomada/velha."
fi
# SO INFORMA (paridade .ps1; decisao do operador 2026-09-14): nenhuma ordem de checkpoint ou RESET
MSG="$MSG Isto e so informacao: decidir checkpoint ou sessao nova e do operador. Voce NAO inicia checkpoint nem manda abrir sessao nova por conta propria; no maximo mencione estes numeros ao operador uma vez."
# o operador so e informado se pedir: ele ve o contexto no painel do VSCode e decide (2026-09-12 e 2026-09-14)
OP=""
[ "$(limiar "${PERCUS_CTX_OPERADOR:-}" 0)" -gt 0 ] && OP="[percus:hook context-budget-guard] contexto ~${K}k tokens (${PCT_TXT}). Checkpoint e sessao nova ficam a seu criterio."
```

- [ ] **Step 6: Corrigir a `_nota` do manifesto** (ferramenta Edit; a nota descrevia limiares fixos e `PERCUS_CTX_HOURS`, que saiu na 6.52.0)

old (trecho da linha 206):
```text
a cada tool call e avisa agente (additionalContext) e operador (systemMessage) acima de PERCUS_CTX_WARN=150k / PERCUS_CTX_HARD=180k, ou apos PERCUS_CTX_HOURS=8h / PERCUS_CTX_RESUME_DAYS=2d de sessao.
```
new:
```text
a cada tool call e INFORMA o agente (additionalContext; o operador so com PERCUS_CTX_OPERADOR=1, via systemMessage) acima de 75%/90% da janela (PERCUS_CTX_WINDOW, ou PERCUS_CTX_WARN/PERCUS_CTX_HARD explicitos) ou com transcript de PERCUS_CTX_RESUME_DAYS=2d. Nao ordena checkpoint nem sessao nova: essa decisao e do operador (6.54.0).
```

- [ ] **Step 7: Rodar e ver passar**

```powershell
Invoke-Pester -Path '.\plugin\percus-review\tests\context-budget-guard.tests.ps1', '.\plugin\percus-review\tests\ps51-compat.tests.ps1', '.\plugin\percus-review\tests\hooks-leitura-utf8.tests.ps1', '.\plugin\percus-review\tests\hooks-manifest.tests.ps1', '.\plugin\percus-review\tests\pester-blocos-unicos.tests.ps1' -Output Detailed
```
Esperado: 0 Failed, e 0 Skipped nos 6 novos, já que o bash do Git existe nesta máquina. Anote os totais do `context-budget-guard.tests.ps1`.

Confira a codificação e a sintaxe (Bash, um comando por chamada):
```bash
bash -n plugin/percus-review/hooks/context-budget-guard.sh
```
```bash
head -c3 plugin/percus-review/hooks/context-budget-guard.ps1 | od -An -tx1
```
Esperado: ` ef bb bf`.
```bash
tail -c +4 plugin/percus-review/hooks/context-budget-guard.ps1 | LC_ALL=C grep -c $'[\x80-\xff]'
```
Esperado: `0`.
```bash
LC_ALL=C grep -c $'[\x80-\xff\r]' plugin/percus-review/hooks/context-budget-guard.sh
```
Esperado: `0`.
```bash
head -c3 plugin/percus-review/tests/context-budget-guard.tests.ps1 | od -An -tx1
```
Esperado: ` ef bb bf`.

- [ ] **Step 8: Bump 6.54.0 e changelog**

```powershell
& '.\scripts\bump-canon.ps1' -Versao 6.54.0 -Data 2026-09-14
```
Esperado: `Canon 6.53.0 -> 6.54.0`.

Em `CANON_VERSION.md`, troque a linha `- (descreva a mudanca desta versao)` da seção `## Changelog v6.54.0 — 2026-09-14` por:

```markdown
**Checkpoint e sessão nova passam a ser só do operador.** O `context-budget-guard` deixa de dar ordem e
só informa o tamanho do contexto.

**O defeito (medido em 2026-09-14):** uma sessão `claude-opus-5[1m]` (janela de 1M) estava com 244k
tokens, 26% da janela. Ela fez checkpoint e mandou o operador abrir sessão nova sem ele pedir. O
`model` gravado no transcript não traz `[1m]`, então o hook caiu no piso de 200k, passou dele e
declarou a janela INDETERMINADA. Mesmo admitindo que não sabia se a sessão estava perto do teto, a
mensagem terminava em "Acao: rode percus-review:checkpoint e encerre em RESET". A condição de
transcript velho ordenava "Nao continue nela: abra sessao nova". E a skill `checkpoint` tinha o aviso
do hook como gatilho, com reset obrigatório depois dele.

**Decisão do operador:** só o operador inicia checkpoint e manda abrir sessão nova. O agente nunca faz
isso por conta própria e, no máximo, menciona o número ao operador uma vez. É a mesma direção de
2026-09-12, quando o aviso ao operador virou opcional porque ele vê o contexto no painel do VSCode.

**Hook (`.ps1` e `.sh`, em paridade):**
- Sai a linha "Acao: rode percus-review:checkpoint e encerre em RESET" nas duas variantes, e com ela
  "Acima de ~Xk um resume futuro em janela ~Yk falha".
- A idade do transcript só informa ("iniciado ha N dias -- e uma sessao retomada/velha") e não manda
  mais abrir sessão nova.
- Toda mensagem ao agente termina na mesma frase: "Isto e so informacao: decidir checkpoint ou sessao
  nova e do operador. Voce NAO inicia checkpoint nem manda abrir sessao nova por conta propria; no
  maximo mencione estes numeros ao operador uma vez."
- O aviso opcional ao operador (`PERCUS_CTX_OPERADOR=1`) troca "Hora de checkpoint + sessao nova" por
  "Checkpoint e sessao nova ficam a seu criterio".
- **Ficam:** os níveis (75% e 90% da janela), o debounce de um aviso por nível, o texto do LIMITE DURO
  e a ressalva do piso adivinhado. Eles dizem quando o hook fala e o que se sabe sobre o teto: são
  informação, não ordem. Os invariantes das rodadas de R11 da janela descoberta continuam cobertos
  pelos testes que já existiam.
- A `_nota` do `hooks-manifest.json` ainda descrevia 150k/180k fixos e `PERCUS_CTX_HOURS=8h`, que
  saiu na 6.52.0. Foi corrigida junto.
- `context-budget-guard.tests.ps1` zera os `PERCUS_CTX_*` herdados e os restaura no fim. Com a
  mitigação `PERCUS_CTX_WINDOW=1000000` no settings do usuário, os casos de 160k/185k ficavam mudos,
  e o arquivo passava a medir o ambiente do runner em vez do hook.

**Não resolve a janela.** O input dos hooks não traz o tamanho da janela; só o statusline recebe
`context_window.context_window_size`. Sem `PERCUS_CTX_WINDOW`, uma sessão 1M continua indeterminada
acima de 200k. A diferença é que isso agora só produz um número, e não uma ordem.
```

```powershell
Invoke-Pester -Path '.\plugin\percus-review\tests\version-alignment.tests.ps1' -Output Detailed
```
Esperado: 0 Failed.

- [ ] **Step 9: Stage, gate, R11**

```bash
git add -- plugin/percus-review/hooks/context-budget-guard.ps1 plugin/percus-review/hooks/context-budget-guard.sh plugin/percus-review/hooks/hooks-manifest.json plugin/percus-review/tests/context-budget-guard.tests.ps1 CANON_VERSION.md plugin/percus-review/plugin.json .claude-plugin/marketplace.json .percus-version
```
```bash
sh v2/gates/percus-gate.sh
```
Esperado: só os 5 "FORA do INDICE.md" das Global Constraints. **Nenhuma** violação de versão: o índice tem 6.54.0 e `origin/main` tem 6.53.0.

```powershell
& '.\plugin\percus-review\scripts\deepseek-review.ps1'
```
Trate cada finding como descrito nas Global Constraints. Se consertar algo, volte ao Step 7 e depois repita este step.

- [ ] **Step 10: Commit** (Bash; uma chamada; substitua os `{...}` pelos valores medidos nos Steps 3, 7 e 9)

```bash
PERCUS_GATE_OVERSIZE="conhecimento/resolver/INDICE.md desatualizado desde 9a23c82 (outra sessao), fora do escopo" git commit -m "fix(hooks): context-budget-guard so informa; checkpoint e sessao nova sao do operador (6.54.0)" -m "Decisao do operador (2026-09-14): so o operador inicia checkpoint e manda abrir sessao nova. O hook passa a so informar o tamanho do contexto." -m "Defeito medido: sessao claude-opus-5[1m] com 244k (26% de 1M) recebeu 'Janela INDETERMINADA ... Acao: rode percus-review:checkpoint e encerre em RESET', fez checkpoint e mandou abrir sessao nova sem pedido. O model do transcript nao traz [1m]; o hook caiu no piso de 200k." -m "SAI (.ps1 e .sh): a linha Acao nas duas variantes; 'Nao continue nela: abra sessao nova' na idade do transcript; 'Hora de checkpoint + sessao nova' no aviso opcional ao operador. ENTRA: a mesma frase final em toda mensagem ao agente, dizendo que a decisao e do operador. FICAM: niveis 75/90%, debounce, LIMITE DURO e ressalva do piso (informacao, nao ordem). hooks-manifest.json: _nota descrevia 150k/180k fixos e PERCUS_CTX_HOURS (removido na 6.52.0)." -m "TESTES: 6 novos + 1 reescrito (3 dias exigia 'sessao nova'), os 7 vermelhos antes do conserto. O arquivo passou a zerar os PERCUS_CTX_* herdados: com PERCUS_CTX_WINDOW=1000000 no settings do usuario ele media o ambiente do runner. context-budget-guard {passed}/{failed}/{skipped}; ps51-compat, hooks-leitura-utf8, hooks-manifest, pester-blocos-unicos e version-alignment verdes; bash -n ok; BOM e ASCII conferidos." -m "R11 (DeepSeek): {resultado; cada finding que nao procedeu, com o porque}" -m "Gate: PERCUS_GATE_OVERSIZE declarado -- conhecimento/resolver/INDICE.md desatualizado desde 9a23c82 (5 verbetes fora do indice, outra sessao)." -m "Co-Authored-By: {linha do lembrete de atribuicao desta sessao}" -- plugin/percus-review/hooks/context-budget-guard.ps1 plugin/percus-review/hooks/context-budget-guard.sh plugin/percus-review/hooks/hooks-manifest.json plugin/percus-review/tests/context-budget-guard.tests.ps1 CANON_VERSION.md plugin/percus-review/plugin.json .claude-plugin/marketplace.json .percus-version
```
Se no Step 9 o gate não acusou nenhuma violação, tire o prefixo `PERCUS_GATE_OVERSIZE=...` e o `-m "Gate: ..."`.

---

### Task 2: Skill `checkpoint` só pelo operador

**Files:**
- Modify: `plugin/percus-review/tests/checkpoint-gatilho.tests.ps1` (BeforeAll, linhas 17-24; `It` novos antes do `}` final do Describe)
- Modify: `plugin/percus-review/skills/checkpoint/SKILL.md` (linhas 3, 8-15, 17-24, 26-28, 92-104, 114, 127-131)
- Modify: `CANON_VERSION.md` (changelog 6.54.0)

**Interfaces:**
- Consumes: 6.54.0 committed (Task 1). A frase do hook "Isto e so informacao..." aparece aqui só como contexto de prosa, sem dependência de código.
- Produces: no teste, `Get-Secao -Prefixo <string>` → `string` (seção markdown do título até o próximo título de nível igual ou maior; `""` se não achar). No SKILL.md, o título `### 5. Sessão nova — só se o operador pediu` e a seção `## O que o agente NÃO faz` com "Não inicia checkpoint por conta própria".

- [ ] **Step 1: Escrever os testes que falham**

Leia o arquivo. No `BeforeAll`, troque:

old:
```powershell
        $script:description = if ($m.Success) { $m.Groups['d'].Value } else { "" }
    }
```
new:
```powershell
        $script:description = if ($m.Success) { $m.Groups['d'].Value } else { "" }

        # Secao do markdown: do titulo (prefixo ASCII) ate o proximo titulo de nivel igual ou maior.
        function Get-Secao {
            param([string]$Prefixo)
            $i = $script:texto.IndexOf($Prefixo, [StringComparison]::Ordinal)
            if ($i -lt 0) { return "" }
            $nivel = ([regex]::Match($Prefixo, '^#+')).Value.Length
            $resto = $script:texto.Substring($i + $Prefixo.Length)
            $mm = [regex]::Match($resto, '(?m)^#{1,' + $nivel + '} ')
            if ($mm.Success) { return $Prefixo + $resto.Substring(0, $mm.Index) }
            return $Prefixo + $resto
        }
    }
```

Depois do último `It` ("diz o que fazer quando a tarefa NAO pode ser terminada"), antes do `}` que fecha o Describe, insira:

```powershell

    # Decisao do operador em 2026-09-14: so o operador inicia checkpoint e manda abrir sessao nova.
    # Medido no mesmo dia: sessao com 244k tokens (26% de uma janela de 1M) recebeu do hook "rode
    # percus-review:checkpoint e encerre em RESET", fez checkpoint e mandou o operador abrir sessao
    # nova sem ele pedir. A skill obedecia por tres portas: o hook como gatilho na description, os
    # gatilhos automaticos em "Quando rodar" e o reset obrigatorio do passo 5.

    It "a description so tem o operador como gatilho (sem milestone, sem hook, sem contexto crescendo)" {
        $script:description | Should -Not -Match '(?i)milestone|context-budget|contexto cresceu|contexto ficando grande' `
            -Because "description e o que dispara a skill; gatilho que nao seja o operador vira checkpoint por conta propria"
    }

    It "a description diz que o agente nunca inicia checkpoint nem manda abrir sessao nova" {
        $script:description | Should -Match '(?i)nunca inicia checkpoint por conta pr.pria'
        $script:description | Should -Match '(?i)abrir sess.o nova sem o operador pedir'
    }

    It "Quando rodar lista so pedidos do operador" {
        $s = Get-Secao '## Quando rodar'
        $s.Length | Should -BeGreaterThan 100 -Because "anti-vacuidade: a secao tem que existir"
        $s | Should -Not -Match '(?i)milestone|context-budget|contexto ficando grande|PreCompact|hook'
        $s | Should -Match '(?i)checkpoint'
        $s | Should -Match '(?i)fechar ou limpar a sess.o'
    }

    It "O que o agente NAO faz inclui iniciar checkpoint e mandar abrir sessao nova" {
        $s = Get-Secao '## O que o agente'
        $s.Length | Should -BeGreaterThan 100 -Because "anti-vacuidade"
        $s | Should -Match '(?i)n.o inicia checkpoint por conta pr.pria'
        $s | Should -Match '(?i)n.o manda abrir sess.o nova'
    }

    It "o passo 5 so fala de sessao nova quando o operador pediu" {
        $s = Get-Secao '### 5.'
        $s.Length | Should -BeGreaterThan 100 -Because "anti-vacuidade"
        $s | Should -Not -Match '(?i)obrigat|n.o retome o trabalho' -Because "reset obrigatorio foi a porta que mandou abrir sessao nova sem pedido"
        $s | Should -Match '(?i)operador pediu'
    }

    It "nenhum resto da politica antiga: reset obrigatorio, horas na saida, checkpoint proativo" {
        $script:texto | Should -Not -Match 'RESET OBRIGAT'
        $script:texto | Should -Not -Match '\{H\}h' -Because "hora de parede saiu da politica na 6.52.0 e sobrou na saida esperada"
        $script:texto | Should -Not -Match '(?i)fa.a no milestone, proativo'
        $script:texto | Should -Not -Match '(?i)checkpoint sem reset em sess.o avisada'
        $script:texto | Should -Not -Match '(?i)\(agente\) roda isto'
    }
```

- [ ] **Step 2: Rodar e ver falhar**

```powershell
Invoke-Pester -Path '.\plugin\percus-review\tests\checkpoint-gatilho.tests.ps1' -Output Detailed
```
Esperado: **6 Failed** (os 6 novos). Os 7 antigos passam.

- [ ] **Step 3: Reescrever as portas da skill** (ferramenta Edit em `plugin/percus-review/skills/checkpoint/SKILL.md`)

Edit 1, `description` (linha 3). Troque só o começo da linha:

old:
```text
description: Use SEMPRE que o operador disser a palavra checkpoint, em qualquer forma (faz um checkpoint, checkpoint e clear, hora do checkpoint, bora checkpointar) — esse é o gatilho principal. Também ao fim de cada milestone, quando o hook context-budget-guard avisar que o contexto cresceu, ou antes de um /clear ou /compact. Ordem obrigatória
```
new:
```text
description: Use SÓ quando o operador pedir — quando ele disser a palavra checkpoint, em qualquer forma (faz um checkpoint, checkpoint e clear, hora do checkpoint, bora checkpointar), ou pedir explicitamente pra fechar ou limpar a sessão. O agente NUNCA inicia checkpoint por conta própria nem manda abrir sessão nova sem o operador pedir (decisão do operador, 2026-09-14). Ordem obrigatória
```
(YAML de linha única: não introduza `: ` nem ` #` na description.)

Edit 2, introdução:

old:
```text
retomada seja limpa. **Você (agente) roda isto ao fim de cada milestone** — não espere o contexto
estourar. O hook `PreCompact` existe só como rede de segurança se você esquecer.
```
new:
```text
retomada seja limpa. **Só o operador inicia isto** — dizendo checkpoint, ou pedindo pra fechar ou
limpar a sessão. O hook `PreCompact` existe só como rede de segurança.
```

Edit 3:

old:
```text
> acabou em "Prompt is too long". Por isso o passo 5 existe e não é opcional.
```
new:
```text
> acabou em "Prompt is too long".
>
> **E resetar é decisão do operador, não do agente.** Medido em 2026-09-14: uma sessão com 244k
> tokens (26% de uma janela de 1M) fez checkpoint e mandou o operador abrir sessão nova sem ele
> pedir. O hook `context-budget-guard` não sabia a janela e mandava "rode checkpoint e encerre em
> RESET". O operador vê o contexto no painel do VSCode, e é ele quem decide.
```

Edit 4, "Quando rodar":

old:
```text
- **O operador disse "checkpoint"** — em qualquer forma ("faz um checkpoint", "checkpoint e clear",
  "hora do checkpoint"). Este é o gatilho principal e não precisa de mais nada: a palavra basta.
- **Fim de um milestone / fase** do plano (momento natural de checkpoint).
- **Contexto ficando grande** (resposta lenta, muita coisa acumulada) — antes de pedir `/clear`.
- Antes de um `/compact` manual.
- Quando o hook `PreCompact` avisar que a compactação vai acontecer (rode antes dela).
```
new:
```text
Só quando o operador pede. São dois gatilhos e não há outro:

- **O operador disse "checkpoint"** — em qualquer forma ("faz um checkpoint", "checkpoint e clear",
  "hora do checkpoint"). A palavra basta.
- **O operador pediu pra fechar ou limpar a sessão** — "fecha a sessão", "vou dar clear", "prepara
  pra sessão nova", "antes do compact".
```

Edit 5, "O que o agente NÃO faz":

old:
```text
## O que o agente NÃO faz

**O `/clear` é do operador.**
```
new:
```text
## O que o agente NÃO faz

**Não inicia checkpoint por conta própria.** Nem ao fim de milestone, nem porque o hook
`context-budget-guard` informou o tamanho do contexto, nem porque a sessão parece grande. O hook só
informa. Se o operador ainda não sabe o número, mencione-o **uma vez** e siga o trabalho.

**Não manda abrir sessão nova** sem o operador pedir, nem depois de um checkpoint que ele pediu só
como "checkpoint".

**O `/clear` é do operador.**
```

Edit 6, passo 5 (bloco inteiro):

old:
```text
### 5. Reset — encerrar a sessão
Se o hook `context-budget-guard` avisou nesta sessão (contexto acima do limiar de aviso — 75% da
janela do modelo —, ou transcript retomado com dias de idade), **o checkpoint não termina no commit:
termina no reset.** Hora de parede **não** é motivo: o contexto enche por trabalho, não por relógio —
sessão parada 10h tem o mesmo contexto de quando parou. Não cite "Xh de sessão" como argumento. Diga
ao operador, literalmente:

> "Checkpoint feito e commitado. Esta sessão está com ~{N}k tokens de contexto — continuar nela custa
> mais a cada passo e um resume futuro falha. Abra uma **sessão nova** (botão de nova conversa no VSCode,
> ou `/clear` no terminal) e cole o bloco acima."

Não retome o trabalho na sessão atual depois disso. Sem aviso do hook, o reset é opcional — mas ao fim
de milestone continua sendo a hora natural de fazê-lo.
```
new:
```text
### 5. Sessão nova — só se o operador pediu
Se o pedido do operador incluiu fechar ou limpar a sessão ("checkpoint e clear", "fecha a sessão",
"vou abrir outra"), termine dizendo, literalmente:

> "Checkpoint feito e commitado. Pode abrir a **sessão nova** (botão de nova conversa no VSCode, ou
> `/clear` no terminal) e colar o bloco acima."

Se ele pediu só "checkpoint", a skill termina no bloco de retomada e o trabalho continua nesta sessão
quando ele quiser. Não sugira sessão nova por conta própria. O aviso do `context-budget-guard` não é
motivo, porque ele só informa o tamanho. Horas de sessão também não são: o contexto enche por
trabalho, não por relógio.
```

Edit 7, saída esperada (linha 114):

old:
```text
Contexto: ~{N}k tokens / {H}h — {RESET OBRIGATÓRIO: abra sessão nova | reset opcional}
```
new:
```text
Contexto: ~{N}k tokens (informativo) — {sessão nova: pedida pelo operador | não pedida, segue nesta sessão}
```

Edit 8, anti-padrões:

old:
```text
- ❌ Esperar o contexto estourar pra fazer checkpoint — faça no milestone, proativo.
- ❌ **Checkpoint sem reset em sessão avisada pelo hook** — o arquivo salva, o contexto continua
  morrendo (sessão de 610k tokens, Empresa-Milionaria, 2026-09-10).
- ❌ Retomar (`--resume` / "retomar") um transcript de dias ou de centenas de k — abra sessão nova e
  cole o bloco; o hook avisa na primeira tool se você fizer isso mesmo assim.
```
new:
```text
- ❌ **Iniciar checkpoint por conta própria**, seja ao fim de milestone, por aviso do hook ou porque o
  contexto cresceu. Checkpoint é do operador (2026-09-14).
- ❌ **Mandar o operador abrir sessão nova sem ele pedir.** Em 2026-09-14 uma sessão a 26% de uma
  janela de 1M fez isso, obedecendo a um hook que não sabia a janela.
- ❌ Tratar a idade do transcript como ordem. O hook informa quando a sessão foi retomada de dias
  atrás; se o operador não sabe, diga uma vez, e a decisão é dele.
```

- [ ] **Step 4: Rodar e ver passar**

```powershell
Invoke-Pester -Path '.\plugin\percus-review\tests\checkpoint-gatilho.tests.ps1', '.\plugin\percus-review\tests\ps51-compat.tests.ps1', '.\plugin\percus-review\tests\hooks-leitura-utf8.tests.ps1', '.\plugin\percus-review\tests\pester-blocos-unicos.tests.ps1' -Output Detailed
```
Esperado: 0 Failed (13 no `checkpoint-gatilho`).
```bash
head -c3 plugin/percus-review/tests/checkpoint-gatilho.tests.ps1 | od -An -tx1
```
Esperado: ` ef bb bf`.

- [ ] **Step 5: Changelog** (Edit em `CANON_VERSION.md`)

old:
```text
acima de 200k. A diferença é que isso agora só produz um número, e não uma ordem.
```
new:
```text
acima de 200k. A diferença é que isso agora só produz um número, e não uma ordem.

**Skill `checkpoint`:** a `description` passa a ter só o operador como gatilho: a palavra checkpoint,
em qualquer forma, ou o pedido explícito de fechar ou limpar a sessão. Saem, como gatilhos do agente,
o fim de milestone, o aviso do hook, o contexto ficando grande e o aviso do PreCompact. O passo 5 só
fala em sessão nova se o operador pediu ("checkpoint e clear") e não diz mais "Não retome o trabalho
na sessão atual". A saída esperada perdeu "RESET OBRIGATÓRIO" e o `/{H}h`, que sobrou da 6.52.0. Os
anti-padrões que mandavam fazer checkpoint proativo e resetar depois do aviso foram invertidos.
```

- [ ] **Step 6: Stage, gate, R11**

```bash
git add -- plugin/percus-review/skills/checkpoint/SKILL.md plugin/percus-review/tests/checkpoint-gatilho.tests.ps1 CANON_VERSION.md
```
```bash
sh v2/gates/percus-gate.sh
```
Esperado: só os 5 "FORA do INDICE.md".
```powershell
& '.\plugin\percus-review\scripts\deepseek-review.ps1'
```

- [ ] **Step 7: Commit** (Bash; valores medidos nos Steps 2, 4 e 6)

```bash
PERCUS_GATE_OVERSIZE="conhecimento/resolver/INDICE.md desatualizado desde 9a23c82 (outra sessao), fora do escopo" git commit -m "fix(skills): checkpoint so dispara por pedido do operador (6.54.0)" -m "Decisao do operador (2026-09-14): so o operador inicia checkpoint e manda abrir sessao nova. A skill obedecia ao hook por tres portas: o hook como gatilho na description, gatilhos automaticos em Quando rodar (milestone, contexto grande, PreCompact) e o reset obrigatorio do passo 5." -m "Gatilhos agora: a palavra checkpoint em qualquer forma, ou pedido explicito de fechar/limpar a sessao. Passo 5 so fala de sessao nova se o operador pediu. Saida esperada sem RESET OBRIGATORIO e sem {H}h (sobra da 6.52.0). Anti-padroes invertidos." -m "TESTES: 6 novos, os 6 vermelhos antes do conserto; checkpoint-gatilho {passed}/{failed}/{skipped}; ps51-compat, hooks-leitura-utf8, pester-blocos-unicos verdes." -m "R11 (DeepSeek): {resultado; findings que nao procederam, com o porque}" -m "Gate: PERCUS_GATE_OVERSIZE declarado -- conhecimento/resolver/INDICE.md desatualizado desde 9a23c82 (5 verbetes fora do indice, outra sessao)." -m "Co-Authored-By: {linha do lembrete de atribuicao desta sessao}" -- plugin/percus-review/skills/checkpoint/SKILL.md plugin/percus-review/tests/checkpoint-gatilho.tests.ps1 CANON_VERSION.md
```

---

### Task 3: Texto do canon alinhado + varredura

**Files:**
- Modify: `plugin/percus-review/tests/checkpoint-gatilho.tests.ps1` (Describe novo no fim do arquivo)
- Modify: `v2/loops/checkpoint.md:3,28`
- Modify: `templates/CLAUDE.template.md:33,152` (+1 bullet)
- Modify: `templates/RESUME_PROMPT.template.md:3`
- Modify: `01_REGRAS_INEGOCIAVEIS.md:185,890-891`
- Modify: `comandos/SKILLS_VS_COMMANDS.md:60,97-98`
- Modify: `comandos/REORGANIZAR_PROJETO.md:61`
- Modify: `CANON_VERSION.md` (changelog)

Três arquivos entram além do escopo inicial, porque também davam checkpoint ao agente. `RESUME_PROMPT.template.md:3` diz "gerado ao fim de um milestone". `SKILLS_VS_COMMANDS.md:97-98` diz "o próprio agente invoca `checkpoint`... (fim de milestone)". E o item 4 da R23 (`01_REGRAS:890-891`) contava com o checkpoint automático como rede de captura.

**Interfaces:**
- Consumes: 6.54.0 committed (Task 1). A skill da Task 2 é citada por nome nos docs.
- Produces: no teste, o Describe `canon nao da checkpoint ao agente`, com `$script:proibidos` (tabela `Arquivo`/`Regex`/`Era`) e `Get-TextoCanon -Relativo <string>` → `string`.

- [ ] **Step 1: Escrever os testes que falham**

No fim de `plugin/percus-review/tests/checkpoint-gatilho.tests.ps1`, depois do `}` que fecha o primeiro Describe, acrescente:

```powershell

# Decisao do operador em 2026-09-14: so o operador inicia checkpoint e manda abrir sessao nova.
# A skill era so uma das portas. O canon repetia a politica antiga em seis lugares -- o loop, o
# template do CLAUDE.md que vai pra todo projeto, o template do prompt de retomada, a R5, a R23 e
# dois docs de comandos -- e o agente le esses textos no boot. Esta varredura prende as frases
# exatas que davam checkpoint ao agente, para nenhuma voltar.
Describe "canon nao da checkpoint ao agente" {

    BeforeAll {
        $script:raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
        $script:proibidos = @(
            @{ Arquivo = 'v2\loops\checkpoint.md';              Regex = '(?i)encerre em reset quando o hook';        Era = 'passo 6 mandava resetar quando o hook mandasse' }
            @{ Arquivo = 'v2\loops\checkpoint.md';              Regex = '(?i)sess.o passa de 8h';                    Era = 'gatilho de 8h, removido na 6.52.0' }
            @{ Arquivo = 'v2\loops\checkpoint.md';              Regex = '(?i)\*\*Quando:\*\* fim de milestone';     Era = 'milestone como gatilho do agente' }
            @{ Arquivo = 'templates\CLAUDE.template.md';        Regex = '(?i)build/checkpoint sozinho';              Era = 'checkpoint na lista rode sozinho' }
            @{ Arquivo = 'templates\CLAUDE.template.md';        Regex = '(?i)Sess.o terminando / contexto cheio';    Era = 'contexto cheio como gatilho do loop' }
            @{ Arquivo = 'templates\RESUME_PROMPT.template.md'; Regex = '(?i)checkpoint` ao fim de um milestone';    Era = 'milestone como gatilho' }
            @{ Arquivo = '01_REGRAS_INEGOCIAVEIS.md';           Regex = '(?i)build / checkpoint \(passos internos';  Era = 'checkpoint entre os auto-triggers da R5' }
            @{ Arquivo = '01_REGRAS_INEGOCIAVEIS.md';           Regex = '(?i)a captura n.o depende de mem.ria';      Era = 'R23 contava com checkpoint automatico' }
            @{ Arquivo = 'comandos\SKILLS_VS_COMMANDS.md';      Regex = '(?i)auto ao fim de marco';                  Era = 'checkpoint automatico no fim de marco' }
            @{ Arquivo = 'comandos\SKILLS_VS_COMMANDS.md';      Regex = '(?i)invoca `checkpoint`/`feature-flow`';    Era = 'agente invocando checkpoint por conta propria' }
            @{ Arquivo = 'comandos\REORGANIZAR_PROJETO.md';     Regex = '(?i)ao fim de milestone \(PreCompact';      Era = 'checkpoint ao fim de milestone' }
        )

        function Get-TextoCanon {
            param([string]$Relativo)
            $p = Join-Path $script:raiz $Relativo
            if (-not (Test-Path -LiteralPath $p)) { return "" }
            return [IO.File]::ReadAllText($p)
        }
    }

    It "nenhum doc do canon repete a politica antiga de checkpoint" {
        $achados = New-Object System.Collections.Generic.List[string]
        foreach ($p in $script:proibidos) {
            $txt = Get-TextoCanon $p.Arquivo
            $txt.Length | Should -BeGreaterThan 200 -Because "anti-vacuidade: $($p.Arquivo) tem que existir e ter conteudo"
            if ($txt -match $p.Regex) { $achados.Add("$($p.Arquivo): $($p.Era)") }
        }
        ($achados -join "`n") | Should -BeNullOrEmpty -Because "a politica antiga voltou"
    }

    It "o loop, o template do CLAUDE.md e a R5 dizem que so o operador inicia checkpoint" {
        foreach ($a in @('v2\loops\checkpoint.md', 'templates\CLAUDE.template.md', '01_REGRAS_INEGOCIAVEIS.md')) {
            Get-TextoCanon $a | Should -Match '(?i)s. o operador inicia checkpoint' -Because "$a tem que dizer de quem e a decisao"
        }
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

```powershell
Invoke-Pester -Path '.\plugin\percus-review\tests\checkpoint-gatilho.tests.ps1' -Output Detailed
```
Esperado: **2 Failed** (os 2 novos; o primeiro lista as 11 frases). Os 13 da Task 2 passam.

- [ ] **Step 3: Alinhar os docs** (ferramenta Edit; leia cada arquivo antes)

`v2/loops/checkpoint.md`. Edit 1, linha 3:

old:
```text
**Quando:** fim de milestone, contexto ficando grande, ou antes de `/clear`.
```
new:
```text
**Quando:** só quando o operador pede: a palavra checkpoint, ou o pedido explícito de fechar ou limpar a sessão. Só o operador inicia checkpoint e manda abrir sessão nova; o agente não faz isso por conta própria (decisão do operador, 2026-09-14).
```

Edit 2, linha 28 (linha única, e a contagem de linhas não muda):

old:
```text
**6. Encerre em reset quando o hook mandar.** O `context-budget-guard` avisa quando o contexto vivo passa de ~150k, ou a sessão passa de 8h, ou o transcript retomado tem dias. Aí o checkpoint termina em **sessão nova**, não no commit: o bloco de retomada (≤15 linhas, ponteiro + próximo passo — os arquivos continuam sendo a fonte) é o que a sessão nova cola.
```
new:
```text
**6. Sessão nova só se o operador pediu.** O `context-budget-guard` só informa o tamanho do contexto e a idade do transcript; ele não manda fazer checkpoint nem resetar. Se o operador pediu checkpoint e clear, o checkpoint termina entregando o bloco de retomada (≤15 linhas, ponteiro + próximo passo — os arquivos continuam sendo a fonte) pra ele colar na sessão nova. Sem esse pedido, termina no commit.
```

`templates/CLAUDE.template.md`. Edit 3, linha 33:

old:
```text
| Sessão terminando / contexto cheio | `v2/loops/checkpoint.md` |
```
new:
```text
| Operador pediu checkpoint, ou pediu pra fechar a sessão | `v2/loops/checkpoint.md` |
```

Edit 4, linha 152:

old:
```text
- **Rode review/conselho/testes/lint/build/checkpoint sozinho.**
```
new:
```text
- **Rode review/conselho/testes/lint/build sozinho.**
```

Edit 5, bullet novo antes de "Maximize paralelo":

old:
```text
- **Maximize paralelo (default):**
```
new:
```text
- **Checkpoint e sessão nova são do operador.** Só o operador inicia checkpoint e manda abrir sessão nova. Fim de milestone e aviso do `context-budget-guard` não são gatilho seu: o hook só informa o tamanho do contexto. Se o operador não sabe o número, mencione uma vez e siga.
- **Maximize paralelo (default):**
```

`templates/RESUME_PROMPT.template.md`. Edit 6, linha 3:

old:
```text
> Gerado pela skill `checkpoint` ao fim de um milestone (ou antes de `/clear`/`/compact`). Cole o **bloco
```
new:
```text
> Gerado pela skill `checkpoint` quando o operador pede checkpoint (só ele inicia). Cole o **bloco
```

`01_REGRAS_INEGOCIAVEIS.md`. Edit 7, linha 185:

old:
```text
- Rodar review / conselho / testes / lint / build / checkpoint (passos internos; auto-trigger, ver R11).
```
new:
```text
- Rodar review / conselho / testes / lint / build (passos internos; auto-trigger, ver R11). **Checkpoint fica fora desta lista:** só o operador inicia checkpoint e manda abrir sessão nova (decisão de 2026-09-14; skill `checkpoint`).
```

Edit 8, R23, linhas 890-891:

old:
```text
4. `CHECKLIST_ENCERRAR_SESSAO.md` tem o passo "problema novo resolvido virou verbete?"; a skill
   `checkpoint` reforça (a captura não depende de memória — fica num gate que já roda).
```
new:
```text
4. `CHECKLIST_ENCERRAR_SESSAO.md` tem o passo "problema novo resolvido virou verbete?"; a skill
   `checkpoint` reforça quando o operador a pede. Ela deixou de ser gatilho automático em
   2026-09-14, então não é rede: a captura continua sendo obrigação da sessão que resolveu.
```

`comandos/SKILLS_VS_COMMANDS.md`. Edit 9, linha 60:

old:
```text
| `checkpoint` | "faça o checkpoint", "vamos fechar este milestone", ou auto ao fim de marco / antes de `/clear`/`/compact`. Sincroniza PLANO+HANDOFF+mock-audit, commita com review (R11), emite prompt de retomada. |
```
new:
```text
| `checkpoint` | "faça o checkpoint", "checkpoint e clear", "fecha a sessão". **Só o operador aciona**: o agente não dispara sozinho, nem ao fim de marco nem por aviso de hook. Sincroniza PLANO+HANDOFF+mock-audit, commita com review (R11), emite prompt de retomada. |
```

Edit 10, linhas 97-98:

old:
```text
**Correto:** o próprio agente invoca `checkpoint`/`feature-flow` via `Skill` tool quando vê a intenção
(fim de milestone; iniciar feature). O user só descreve — o agente decide e executa.
```
new:
```text
**Correto:** o próprio agente invoca `feature-flow` via `Skill` tool quando vê a intenção (iniciar
feature). O user só descreve — o agente decide e executa. **Exceção: `checkpoint`.** Só o operador
inicia checkpoint (dizendo a palavra, ou pedindo pra fechar a sessão); o agente invoca a skill quando
ele pede, nunca por conta própria.
```

`comandos/REORGANIZAR_PROJETO.md`. Edit 11, linha 61:

old:
```text
- Checkpoint: rodar a skill `checkpoint` (linguagem natural, não slash) ao fim de milestone (PreCompact é backstop).
```
new:
```text
- Checkpoint: só quando o operador pede (a palavra checkpoint, em linguagem natural, não slash); o agente não inicia nem manda abrir sessão nova. PreCompact é backstop.
```

- [ ] **Step 4: Rodar e ver passar**

```powershell
Invoke-Pester -Path '.\plugin\percus-review\tests\checkpoint-gatilho.tests.ps1', '.\plugin\percus-review\tests\ps51-compat.tests.ps1', '.\plugin\percus-review\tests\hooks-leitura-utf8.tests.ps1', '.\plugin\percus-review\tests\pester-blocos-unicos.tests.ps1' -Output Detailed
```
Esperado: 0 Failed (15 no `checkpoint-gatilho`).
```bash
wc -l v2/loops/checkpoint.md
```
Esperado: `35`, a mesma contagem de antes (teto do gate: 60).

- [ ] **Step 5: Changelog** (Edit em `CANON_VERSION.md`)

old:
```text
anti-padrões que mandavam fazer checkpoint proativo e resetar depois do aviso foram invertidos.
```
new:
```text
anti-padrões que mandavam fazer checkpoint proativo e resetar depois do aviso foram invertidos.

**Texto do canon alinhado.** Seis lugares repetiam a política antiga:
- `v2/loops/checkpoint.md`: o passo 6 mandava encerrar em reset quando o hook mandasse e ainda citava
  o gatilho de 8h.
- `templates/CLAUDE.template.md`: checkpoint estava na lista "rode sozinho" e, na tabela, como
  "contexto cheio".
- `templates/RESUME_PROMPT.template.md`: dizia que o prompt é gerado "ao fim de um milestone".
- `01_REGRAS_INEGOCIAVEIS.md`: a R5 listava checkpoint entre os auto-triggers, e o item 4 da R23 o
  tratava como rede de captura.
- `comandos/SKILLS_VS_COMMANDS.md`: tinha "auto ao fim de marco" e "o agente invoca checkpoint".
- `comandos/REORGANIZAR_PROJETO.md`: mandava rodar checkpoint "ao fim de milestone".

Um teste novo varre esses arquivos pelas frases exatas para nenhuma voltar.
```

- [ ] **Step 6: Stage, gate, R11**

```bash
git add -- plugin/percus-review/tests/checkpoint-gatilho.tests.ps1 v2/loops/checkpoint.md templates/CLAUDE.template.md templates/RESUME_PROMPT.template.md 01_REGRAS_INEGOCIAVEIS.md comandos/SKILLS_VS_COMMANDS.md comandos/REORGANIZAR_PROJETO.md CANON_VERSION.md
```
```bash
sh v2/gates/percus-gate.sh
```
Esperado: só os 5 "FORA do INDICE.md". Não pode haver violação de teto de loop nem de núcleo.
```powershell
& '.\plugin\percus-review\scripts\deepseek-review.ps1'
```

- [ ] **Step 7: Commit** (Bash)

```bash
PERCUS_GATE_OVERSIZE="conhecimento/resolver/INDICE.md desatualizado desde 9a23c82 (outra sessao), fora do escopo" git commit -m "docs(canon): checkpoint sai dos gatilhos do agente em loop, template, R5, R23 e comandos (6.54.0)" -m "Decisao do operador (2026-09-14): so o operador inicia checkpoint e manda abrir sessao nova. Seis textos lidos no boot repetiam a politica antiga: v2/loops/checkpoint.md (reset quando o hook mandar; gatilho de 8h), CLAUDE.template (checkpoint na lista rode sozinho; contexto cheio), RESUME_PROMPT.template (fim de milestone), R5 e R23 em 01_REGRAS, SKILLS_VS_COMMANDS (auto ao fim de marco; agente invoca checkpoint) e REORGANIZAR_PROJETO (fim de milestone)." -m "TESTES: 2 novos (varredura de 11 frases exatas + presenca da regra no loop, template e R5), os 2 vermelhos antes do conserto; checkpoint-gatilho {passed}/{failed}/{skipped}; ps51-compat, hooks-leitura-utf8, pester-blocos-unicos verdes. Loop com 35 linhas (teto 60)." -m "R11 (DeepSeek): {resultado; findings que nao procederam, com o porque}" -m "Gate: PERCUS_GATE_OVERSIZE declarado -- conhecimento/resolver/INDICE.md desatualizado desde 9a23c82 (5 verbetes fora do indice, outra sessao)." -m "Co-Authored-By: {linha do lembrete de atribuicao desta sessao}" -- plugin/percus-review/tests/checkpoint-gatilho.tests.ps1 v2/loops/checkpoint.md templates/CLAUDE.template.md templates/RESUME_PROMPT.template.md 01_REGRAS_INEGOCIAVEIS.md comandos/SKILLS_VS_COMMANDS.md comandos/REORGANIZAR_PROJETO.md CANON_VERSION.md
```

---

### Task 4: Verificação final e changelog fechado

**Files:**
- Modify: `CANON_VERSION.md` (parágrafos "Testes" e "Dívidas")

**Interfaces:**
- Consumes: os 3 commits das Tasks 1-3.
- Produces: o 4º commit local, com o branch pronto para o operador decidir o merge.

- [ ] **Step 1: Suíte inteira** (PowerShell; nada mais rodando; o mesmo ambiente do P3)

```powershell
$env:PERCUS_CTX_WINDOW; & '.\scripts\rodar-suite.ps1'
```
Esperado: os totais do P3 **+14 testes** (6 + 6 + 2). Nenhuma falha nova. As falhas de `context-budget-guard.tests.ps1` que o P3 atribuiu ao ambiente somem, e toda falha restante já existia no P3, com o mesmo nome. Falha nova se investiga antes de seguir (`superpowers:systematic-debugging`). Não se atribui ao "ambiente" sem reproduzir a falha num worktree em `9a23c82`.

- [ ] **Step 2: Varredura de restos** (ferramenta Grep, na raiz do worktree)

Pattern: `(?i)encerre em RESET|Hora de checkpoint|RESET OBRIGAT|auto ao fim de marco|build/checkpoint sozinho|rode percus-review:checkpoint|Nao continue nela`, com `output_mode: files_with_matches`.
Esperado: só `plugin/percus-review/tests/context-budget-guard.tests.ps1`, `plugin/percus-review/tests/checkpoint-gatilho.tests.ps1` (as listas de frases proibidas) e `CANON_VERSION.md` (changelog), além de arquivos em `conhecimento/` e `docs/`, que estão fora do escopo. Qualquer outro arquivo é porta esquecida: pare e reporte.

- [ ] **Step 3: Fechar o changelog** (Edit em `CANON_VERSION.md`; números medidos no Step 1)

old:
```text
Um teste novo varre esses arquivos pelas frases exatas para nenhuma voltar.
```
new:
```text
Um teste novo varre esses arquivos pelas frases exatas para nenhuma voltar.

**Testes:** 14 novos (6 no hook, nos dois runtimes; 6 nas portas da skill; 2 na varredura do canon) e
1 reescrito. O teste de 3 dias exigia "sessao nova", ou seja, a própria ordem. Todos ficaram
vermelhos antes do conserto. Suíte {passed}/{failed}/{skipped}, contra {passed_p3}/{failed_p3}/{skipped_p3}
no baseline, com o mesmo `PERCUS_CTX_WINDOW={valor}` herdado. Cada commit que leva código passou pelo R11.

**Dívidas registradas (fora do escopo):**
- Descobrir a janela pelo statusline, o único ponto que recebe `context_window.context_window_size`.
  Sem isso, o hook segue indeterminado acima de 200k em sessão 1M sem `PERCUS_CTX_WINDOW`.
- A mensagem do `pre-compact-checkpoint` (`.ps1:33`, `.sh:25`) ainda manda rodar `/checkpoint` como
  slash, e esse slash não existe no ambiente do operador.
- A base `conhecimento/` não foi revista à luz desta decisão (ex.:
  `checkpoint-persiste-arquivos-nao-reseta-contexto`), nem `skills/consult-knowledge/SKILL.md:90`,
  que chama a skill `checkpoint` de gate de captura. O `INDICE.md` gerado colide com mudança não
  commitada de outra sessão no checkout principal.
- O gate barra por `conhecimento/resolver/INDICE.md` desatualizado desde 9a23c82 (5 verbetes fora do
  índice). Os 4 commits desta versão declararam `PERCUS_GATE_OVERSIZE`, com a linha `Gate:` no corpo.
```

- [ ] **Step 4: Stage, gate, commit** (só `.md`, então R11 é dispensado)

```bash
git add -- CANON_VERSION.md
```
```bash
sh v2/gates/percus-gate.sh
```
Esperado: só os 5 "FORA do INDICE.md".
```bash
PERCUS_GATE_OVERSIZE="conhecimento/resolver/INDICE.md desatualizado desde 9a23c82 (outra sessao), fora do escopo" git commit -m "docs(canon): changelog 6.54.0 fechado com suite e dividas" -m "Suite {passed}/{failed}/{skipped} (baseline {passed_p3}/{failed_p3}/{skipped_p3}, mesmo PERCUS_CTX_WINDOW herdado). Dividas: janela via statusline; /checkpoint no pre-compact-checkpoint; conhecimento/ e consult-knowledge nao revistos; INDICE.md desatualizado desde 9a23c82. Commit so de .md: R11 dispensado." -m "Gate: PERCUS_GATE_OVERSIZE declarado -- conhecimento/resolver/INDICE.md desatualizado desde 9a23c82 (5 verbetes fora do indice, outra sessao)." -m "Co-Authored-By: {linha do lembrete de atribuicao desta sessao}" -- CANON_VERSION.md
```

- [ ] **Step 5: Conferir e parar**

```bash
git log --oneline 9a23c82..HEAD
```
Esperado: 4 commits.
```bash
git status --short
```
Esperado: vazio.

**Pare aqui.** Reporte ao controlador: os 4 hashes, a suíte antes e depois, os findings de R11 que não procederam e as dívidas. Merge na `main` e push são decisão do operador. O merge ativa o hook em todas as sessões desta máquina pelo trampolim `PERCUS_CANON_DIR`.
