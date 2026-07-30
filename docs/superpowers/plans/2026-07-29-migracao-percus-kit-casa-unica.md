# Casa única `percus-kit` — Implementation Plan (fase 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deixar o kit Percus com **uma casa só** (`D:\Claud Automations\percus-kit`), com o canon `v2/` fundido e correto, a camada velha arquivada e a pasta avulsa `_Novo_Projeto_V2` apagada.

**Architecture:** O kit é um repo git único (`huboperacional/percus-kit`) puxado por `git pull` em 10 máquinas. O rename é **local por máquina** (nome de diretório não vem por git), então ele é feito por um script idempotente versionado no próprio kit. Cada mudança de comportamento é provada por teste Pester rodando o artefato de verdade — nunca por inspeção de código.

**Tech Stack:** PowerShell 7 (`pwsh`) + Pester 5.7, bash (Git for Windows), git.

**Spec:** `docs/superpowers/specs/2026-07-29-migracao-percus-kit-casa-unica-design.md` (aprovado; pre-mortem do conselho incorporado na §5.2).

**Fora deste plano:** a migração dos 11 hooks pro `settings.json` (§4.4 do spec) vira **plano 2**, escrito depois que este rodar — os caminhos dos hooks mudam com o rename, e plano com path errado é plano quebrado.

---

## ESTADO DA EXECUÇÃO (atualizado 2026-07-29, antes do `/clear`)

Branch: **`migracao-percus-kit-fase1`** (o kit está em `main`; nada foi mergeado).

| Task | Estado | Commits / evidência |
|---|---|---|
| 1 — gate de conhecimento | ✅ **fechada**, aprovada nos 2 estágios de review | `5486e2d`, `9ac75d7`, `951ab30` · 10 testes · gate enxerga 105/105 verbetes (antes: 33) |
| 2 — `.percus-review.json` no loop | ✅ fechada (revisada inline) | `bc9f19e` · loop em 35/60 linhas, fence par |
| 3 — `.percus/` no `.gitignore` | ✅ fechada (revisada inline) | `b637bfe` · provado com `git status` vazio |
| 4 — `renomear-kit-local.ps1` | ⚠️ **implementada, review REPROVOU 2ª vez** | `b8c96ee`, `14cfb9b` · 9 testes · ver "pendência" abaixo |
| 7 — roteamento (era arquivamento) | 🔨 **em curso** — escopo reduzido por decisão do operador | ver §3.1 do spec; patch do move em `scratchpad/task7-arquivamento.patch` |
| 5 — rename da pasta | ⏸️ pendente | muda `PERCUS_CANON_DIR` e a allowlist da sessão; exige aval do operador na hora |
| 6 — gate anti-path-legado | ⏸️ pendente | só passa **depois** do rename |
| 8 — versão 6.32.0 | ⏸️ pendente | 4 arquivos + changelog |
| 9 — apagar `_Novo_Projeto_V2` | ⏸️ pendente | último, depois de tudo verde |

**Ordem ajustada em execução:** 1 → 2 → 3 → 4 → 7 → **5 (rename)** → 6 → 8 → 9. Motivo: renomear a
pasta no meio do voo quebra os caminhos que a sessão e os subagents usam, e a allowlist de diretórios
do harness aponta pro nome antigo.

### PENDÊNCIA BLOQUEANTE da Task 4 (fazer antes de seguir pro 5)

A re-revisão reprovou: o fix fechou **uma** das três portas para o mesmo estado quebrado. `Copy-Item`
(backup) e `[IO.File]::WriteAllText` (escrita final) rodam **depois** do `Rename-Item` e não têm
proteção — provado por execução (ACL negando o `.bak`; `settings.json` somente-leitura). Nos dois
casos a pasta fica renomeada, o settings aponta pro caminho morto, e a mensagem é a exceção crua do
.NET, sem instrução de recuperação.

**Correção decidida (não é remendo de mensagem):** `try/catch` envolvendo **tudo** que acontece após o
rename e, no `catch`, **rollback** — renomear a pasta de volta, deixando a máquina no estado original;
se o rollback também falhar, dizer exatamente em que estado ficou e qual `-KitAtual` usar pra retomar.
Mais dois testes: falha na escrita final (arquivo somente-leitura) e falha no backup, ambos aferindo
que a pasta voltou ao nome antigo.

### Nota operacional

O limite de sessão da API foi atingido em 2026-07-29 ~21:5x (reseta 22:10, Cuiabá) e derrubou um
subagent no meio da Task 7. Enquanto não resetar, executar **inline**; subagent falha.

---

## Estrutura de arquivos

| Arquivo | Responsabilidade | Ação |
|---|---|---|
| `v2/gates/percus-gate.sh` | gate mecânico dos tetos + higiene de conhecimento | Modificar (Task 1) |
| `plugin/percus-review/tests/gate-conhecimento.tests.ps1` | prova comportamental do gate: o que ele vê e o que ele barra | Criar (Task 1) |
| `v2/loops/review.md` | loop de review | Modificar (Task 2) |
| `.gitignore` | lixo local fora do git | Modificar (Task 3) |
| `scripts/renomear-kit-local.ps1` | rename local idempotente + conserto do `settings.json` | Criar (Task 4) |
| `plugin/percus-review/tests/renomear-kit-local.tests.ps1` | prova do script em diretório falso | Criar (Task 4) |
| `plugin/percus-review/tests/no-legacy-kit-path.tests.ps1` | barra referência ao path legado em arquivo vivo | Criar (Task 6) |
| `.archive/camada-v1/` | camada velha aposentada | Criar (Task 7) |
| `README.md` | ponteiro pra onde as coisas foram | Modificar (Task 7) |
| `CANON_VERSION.md`, `plugin.json`, `.percus-version`, `.claude-plugin/marketplace.json` | versão + changelog | Modificar (Task 8) |

**Convenção de commit (R11, obrigatória em todos os Tasks):** antes de cada `git commit`, rodar o review numa chamada **separada** — `sh "<kit>/scripts/percus-review-auto.sh"` — e tratar findings de bug/regressão. Trailer canônico: `Co-Authored-By: Claude <noreply@anthropic.com>`.

---

### Task 1: Gate de conhecimento — fundir as duas variantes e provar o que ele enxerga

**Por que primeiro:** o gate que roda hoje nos projetos está **cego em 72 dos 105 verbetes** de `COMO_RESOLVER.md` (medido em 2026-07-29). Ele sai `exit 0` não porque o canon está limpo, mas porque não olha. Isso é pior que o falso positivo da cópia morta.

**Files:**
- Create: `D:\Claud Automations\_Novo_Projeto\plugin\percus-review\tests\gate-conhecimento.tests.ps1`
- Modify: `D:\Claud Automations\_Novo_Projeto\v2\gates\percus-gate.sh` (blocos "2. Verbete de conhecimento orfao" e "3. Verbete sem linha tags:", linhas ~78-104)

- [ ] **Step 1: Escrever o teste que falha**

Criar `plugin\percus-review\tests\gate-conhecimento.tests.ps1`:

```powershell
#requires -Version 5.1
# Prova COMPORTAMENTAL do gate de conhecimento: roda o script de verdade num repo
# temporario e afere o que ele barra. Nao inspeciona o codigo do gate — inspecao de
# codigo foi o que deixou passar o gate cego de 2026-07-29 (via 33 de 105 verbetes).

Describe "percus-gate.sh — higiene de conhecimento" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:gate    = Join-Path $script:kitRoot "v2\gates\percus-gate.sh"
        $script:temps   = New-Object System.Collections.ArrayList

        function Get-BashExe {
            $c = Get-Command bash -ErrorAction SilentlyContinue
            if ($c) { return $c.Source }
            foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe")) {
                if (Test-Path $p) { return $p }
            }
            return $null
        }

        # Cria repo temporario com um conhecimento/x.md montado a partir das linhas dadas.
        function New-KnowledgeRepo {
            param([string[]]$Linhas)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-gate-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path (Join-Path $dir "conhecimento") -Force | Out-Null
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\x.md"), $Linhas, (New-Object System.Text.UTF8Encoding($false)))
            [void]$script:temps.Add($dir)
            return $dir
        }

        function Invoke-Gate {
            param([string]$Repo)
            $bash = Get-BashExe
            Push-Location $Repo
            try { & $bash $script:gate 2>&1 | Out-Null; return $LASTEXITCODE } finally { Pop-Location }
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "enxerga verbete DEPOIS de fence dentro de blockquote (a causa dos 72 invisiveis)" {
        # O padrao antigo casava '> ```' como fence de verdade; o toggle dessincronizava
        # e tudo dali pra frente sumia da vista. Com fence ESTRITO (coluna 0), '> ```'
        # e so texto e o verbete seguinte continua sendo aferido.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '- [Sem tags](#sem-tags)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a, b`', '', '**Sintoma:** ok.', '',
            '> Modelo pra copiar:', '> ```', '> ## Exemplo {#exemplo}', '> ```', '',
            '## Sem tags {#sem-tags}', '', '**Sintoma:** invisivel pra busca.'
        )
        Invoke-Gate -Repo $repo | Should -Be 1 -Because "o verbete sem tags vem depois e precisa ser visto"
    }

    It "BARRA arquivo com bloco de codigo aberto e nunca fechado" {
        # Fence nao fechado cega o gate dali pra frente. Em vez de passar calado, acusa.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '```', 'bloco aberto e nunca fechado'
        )
        Invoke-Gate -Repo $repo | Should -Be 1 -Because "cegueira silenciosa e pior que falso positivo"
    }

    It "NAO acusa titulo de exemplo dentro de bloco de codigo" {
        # ^## sozinho enxergaria este exemplo como verbete real e acusaria ancora orfa.
        # Por isso o fence ESTRITO continua no gate — so ele, e so na coluna 0.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            'Exemplo de como escrever um verbete:', '',
            '```markdown', '## Titulo de exemplo {#exemplo-em-bloco}', '`tags: x`', '```'
        )
        Invoke-Gate -Repo $repo | Should -Be 0 -Because "exemplo em bloco de codigo nao e verbete"
    }

    It "aceita tags: SEM crase (18 de ~105 verbetes escrevem assim e sao encontraveis)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', 'tags: a, b', '', '**Sintoma:** ok.'
        )
        Invoke-Gate -Repo $repo | Should -Be 0
    }

    It "NAO acusa o bloco-modelo em blockquote (falso positivo de 2026-07-27)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '> Modelo pra copiar:', '> ## <sintoma curto> {#ancora-kebab}', '> `tags:` ...'
        )
        Invoke-Gate -Repo $repo | Should -Be 0
    }

    It "barra ancora que nao esta no indice" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '## Orfa {#orfa}', '', '`tags: c`', '', '**Sintoma:** fora do indice.'
        )
        Invoke-Gate -Repo $repo | Should -Be 1
    }

    It "roda limpo no canon de verdade (exit 0) — e enxergando os 105 verbetes" {
        $reais = @(Select-String -Path (Join-Path $script:kitRoot "conhecimento\COMO_RESOLVER.md") -Pattern '^## .*\{#').Count
        $reais | Should -BeGreaterThan 100 -Because "sanity: o arquivo tem ~105 verbetes"
        Invoke-Gate -Repo $script:kitRoot | Should -Be 0
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

```powershell
cd "D:\Claud Automations\_Novo_Projeto\plugin\percus-review"
Invoke-Pester -Path "tests\gate-conhecimento.tests.ps1" -Output Detailed
```

Esperado: **FAIL** no 1º teste (`Expected 1, but got 0`) — o gate atual não vê o verbete depois do bloco. Os testes 2 e 4 podem falhar também.

- [ ] **Step 3: Corrigir o gate**

Em `v2\gates\percus-gate.sh`, bloco 2, trocar a linha do `awk` de detecção de âncora por filtro de **linha de título**, sem rastreio de fence:

```bash
  # Verbete real = linha de TITULO (^## ) fora de bloco de codigo.
  # Fence ESTRITO (^``` na coluna 0): o padrao antigo casava tambem fence indentado e
  # dentro de blockquote, o toggle dessincronizava e o gate ficava CEGO do ponto em
  # diante — medido 2026-07-29: via 33 de 105 verbetes e saia exit 0 por nao olhar.
  # ^## ja exclui blockquote por construcao (linha comeca com '>').
  orfaos=$(awk '/^```/{f=!f; next} f{next} /^## .*\{#/{print}' "$f" 2>/dev/null \
           | grep -oE '\{#[a-z0-9-]+\}' | tr -d '{}#' | sort -u \
           | while read -r a; do grep -qF "(#$a)" "$f" || echo "$a"; done)
```

No bloco 3, trocar o fence permissivo pelo estrito, tirar o skip de blockquote (redundante com
`^## `) e tornar a crase opcional:

```bash
  sem_tags=$(awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^## .*\{#/ { if (p != "") print p; p=$0; c=0; next }
    p != "" { c++; if ($0 ~ /^`?tags:/) p=""; else if (c >= 4) { print p; p="" } }
    END { if (p != "") print p }
  ' "$f" | grep -oE '\{#[a-z0-9-]+\}' | tr -d '{}#')
```

Ainda no Step 3, acrescentar um bloco **novo** logo após o bloco 3, para que cegueira nunca mais seja
silenciosa:

```bash
# ---------- 3b. Bloco de codigo aberto e nunca fechado ----------
# Fence sem par cega os blocos 2 e 3 dali pra frente. Acusar e obrigatorio: gate que
# para de olhar no meio do arquivo e pior que gate com falso positivo (2026-07-29).
for f in conhecimento/*.md referencia/conhecimento/*.md; do
  [ -f "$f" ] || continue
  aberto=$(awk '/^```/{fence=!fence; if (fence) linha=NR} END{print (fence ? linha : 0)}' "$f")
  if [ "$aberto" -gt 0 ]; then
    violacao "$f -- bloco de codigo aberto na linha $aberto e nunca fechado (o gate fica cego dali pra frente)"
  fi
done
```

- [ ] **Step 4: Rodar e ver passar**

```powershell
Invoke-Pester -Path "tests\gate-conhecimento.tests.ps1" -Output Detailed
```

Esperado: **7/7 PASS**.

- [ ] **Step 5: Rodar a suíte inteira (não pode regredir)**

```powershell
Invoke-Pester -Path "tests" -Output Normal | Select-String "Tests Passed"
```

Esperado: `Failed: 0` e `Tests Passed` >= 172 (166 de hoje + 6 novos). Nao afira numero exato: outro teste entrando depois travaria o roteiro a toa.

- [ ] **Step 6: Review + commit**

```bash
cd "/d/Claud Automations/_Novo_Projeto"
git add v2/gates/percus-gate.sh plugin/percus-review/tests/gate-conhecimento.tests.ps1
sh scripts/percus-review-auto.sh
```

Depois, em chamada separada:

```bash
cd "/d/Claud Automations/_Novo_Projeto" && git commit -F - <<'MSG'
gate: estava cego em 72 dos 105 verbetes (rastreio de fence dessincronizava)

O gate saia exit 0 no canon nao porque estava limpo, mas porque nao olhava: um ```
solto no texto invertia o toggle de fence e apagava o resto do arquivo da vista.
Deteccao passa a ser por linha de titulo (^## ), que ja exclui blockquote e nao
depende de fence. Crase em tags: vira opcional (18 verbetes escrevem sem, e sao
encontraveis).

Verificado rodando: teste comportamental novo roda o gate de verdade em repo
temporario -- barra verbete sem tags DEPOIS de bloco de codigo, aceita tags sem
crase, nao acusa o bloco-modelo em blockquote, barra ancora fora do indice, e o
canon real sai exit 0 com os 105 verbetes visiveis.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 2: Trazer a seção `.percus-review.json` pro loop de review vivo

**Files:**
- Modify: `D:\Claud Automations\_Novo_Projeto\v2\loops\review.md` (após a linha 17, seção "Roteamento")

- [ ] **Step 1: Aplicar a edição**

Depois da linha `O router decide sozinho: DeepSeek por padrão · Cross-Claude quando o código veio do DeepSeek (evita auto-revisão) ou toca pasta sensível · ambos no fechamento de marco.`, inserir:

```markdown

**Pasta sensível é declarada, não adivinhada.** O baseline do router é taxonomia de produto web (`auth/`, `payment*/`, `migrations/`). Se o que escreve em produção neste projeto tem outro nome, declare em `.percus-review.json` na raiz — senão ele é revisado como código trivial:

```json
{ "sensitivePatterns": ["(^|[/\\\\])execution[/\\\\].*\\.py$"] }
```

Descrever isso só em prosa no `CLAUDE.md` não configura nada: o router lê o JSON, não o markdown.
```

- [ ] **Step 2: Verificar o teto do loop (60 linhas)**

```powershell
(Get-Content "D:\Claud Automations\_Novo_Projeto\v2\loops\review.md").Count
```

Esperado: número **≤ 60**. Se passar de 60, mover conteúdo pra `referencia/` em vez de comprimir (CONSTITUICAO §8).

- [ ] **Step 3: Rodar o gate (ele afere o teto)**

```powershell
cd "D:\Claud Automations\_Novo_Projeto"
$bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
if (-not $bash) { $bash = "$env:ProgramFiles\Git\bin\bash.exe" }
& $bash "v2/gates/percus-gate.sh"; $LASTEXITCODE
```

Esperado: `0`.

- [ ] **Step 4: Review + commit**

```bash
cd "/d/Claud Automations/_Novo_Projeto"
git add v2/loops/review.md
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/_Novo_Projeto" && git commit -F - <<'MSG'
v2: loop de review ensina a declarar pasta sensivel em .percus-review.json

Delta que existia so na pasta avulsa (_Novo_Projeto_V2). Prosa no CLAUDE.md nao
configura o router -- ele le o JSON.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 3: `.percus/` no `.gitignore` do kit

O gate escreve `.percus/gate-escapes.log` quando alguém usa `PERCUS_GATE_OVERSIZE`. O `.gitignore` do kit ignora `.deepseek/` mas **não** `.percus/`.

**Files:**
- Modify: `D:\Claud Automations\_Novo_Projeto\.gitignore` (após a linha `.deepseek/`)

- [ ] **Step 1: Aplicar a edição**

```
# Log de escape do gate (local por maquina — o loop drift audita rodando o script)
.percus/
```

- [ ] **Step 2: Verificar que o git passou a ignorar**

```bash
cd "/d/Claud Automations/_Novo_Projeto"
mkdir -p .percus && echo "teste" > .percus/gate-escapes.log
git status --short .percus/
```

Esperado: **saída vazia** (ignorado). Depois: `rm -rf .percus`

- [ ] **Step 3: Review + commit**

```bash
cd "/d/Claud Automations/_Novo_Projeto"
git add .gitignore
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/_Novo_Projeto" && git commit -F - <<'MSG'
gitignore: .percus/ (log de escape do gate) nao vai pro git

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 4: Script de rename local, com teste em diretório falso

O rename **não se propaga por `git pull`** — nome de diretório de trabalho é local. Este script é o que impede o kit de ter nome diferente em cada máquina.

**Files:**
- Create: `D:\Claud Automations\_Novo_Projeto\scripts\renomear-kit-local.ps1`
- Create: `D:\Claud Automations\_Novo_Projeto\plugin\percus-review\tests\renomear-kit-local.tests.ps1`

- [ ] **Step 1: Escrever o teste que falha**

Criar `plugin\percus-review\tests\renomear-kit-local.tests.ps1`:

```powershell
#requires -Version 5.1
# O script de rename mexe no settings.json do usuario. O teste NUNCA toca o real:
# monta um par (pasta falsa + settings falso) e afere o resultado.

Describe "renomear-kit-local.ps1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\renomear-kit-local.ps1"
        $script:temps   = New-Object System.Collections.ArrayList

        function New-Cenario {
            $base = Join-Path ([IO.Path]::GetTempPath()) ("percus-ren-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path (Join-Path $base "_Novo_Projeto") -Force | Out-Null
            $settings = @{
                env = @{ PERCUS_CANON_DIR = (Join-Path $base "_Novo_Projeto") }
                permissions = @{ allow = @(
                    ('Bash(pwsh -File "' + (Join-Path $base "_Novo_Projeto") + '/scripts/percus-review-auto.ps1")')
                ) }
            } | ConvertTo-Json -Depth 10
            $sp = Join-Path $base "settings.json"
            [IO.File]::WriteAllText($sp, $settings, (New-Object System.Text.UTF8Encoding($false)))
            [void]$script:temps.Add($base)
            return [pscustomobject]@{ Base = $base; Settings = $sp; Antigo = (Join-Path $base "_Novo_Projeto"); Novo = (Join-Path $base "percus-kit") }
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "renomeia a pasta e reescreve PERCUS_CANON_DIR" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        Test-Path $c.Novo | Should -Be $true
        Test-Path $c.Antigo | Should -Be $false
        (Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json).env.PERCUS_CANON_DIR | Should -Be $c.Novo
    }

    It "reescreve tambem as entradas de permissao que hardcodam o path" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        $j = Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json
        ($j.permissions.allow -join " ") | Should -Not -Match '_Novo_Projeto'
        ($j.permissions.allow -join " ") | Should -Match 'percus-kit'
    }

    It "deixa o settings.json VALIDO (JSON quebrado derruba todos os hooks calado)" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        { Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json } | Should -Not -Throw
    }

    It "faz backup datado do settings antes de mexer" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        @(Get-ChildItem (Split-Path $c.Settings) -Filter "settings.json.bak-*").Count | Should -BeGreaterThan 0
    }

    It "NAO troca o nome no MEIO de um token maior" {
        $c = New-Cenario
        $j = Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $j.permissions.allow += 'Bash(echo backup_Novo_Projeto_old)'
        [IO.File]::WriteAllText($c.Settings, ($j | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        (Get-Content $c.Settings -Raw -Encoding UTF8) | Should -Match 'backup_Novo_Projeto_old' -Because "so path e alvo; substring dentro de token nao"
    }

    It "NAO corrompe mencao a _Novo_Projeto_V2 (o nome antigo e prefixo dela)" {
        $c = New-Cenario
        $j = Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $j.permissions.allow += ('Read(' + (Join-Path $c.Base "_Novo_Projeto_V2") + '/**)')
        [IO.File]::WriteAllText($c.Settings, ($j | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        $depois = Get-Content $c.Settings -Raw -Encoding UTF8
        $depois | Should -Match '_Novo_Projeto_V2' -Because "a pasta avulsa nao e alvo deste rename"
        $depois | Should -Not -Match 'percus-kit_V2' -Because "prefixo trocado no meio da palavra corrompe o path"
    }

    It "e idempotente: rodar de novo com a pasta ja renomeada nao quebra nem duplica" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        { & $script:script -KitAtual $c.Novo -NomeNovo "percus-kit" -SettingsPath $c.Settings } | Should -Not -Throw
        (Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json).env.PERCUS_CANON_DIR | Should -Be $c.Novo
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

```powershell
cd "D:\Claud Automations\_Novo_Projeto\plugin\percus-review"
Invoke-Pester -Path "tests\renomear-kit-local.tests.ps1" -Output Detailed
```

Esperado: **FAIL** — `The term '...renomear-kit-local.ps1' is not recognized` (script não existe).

- [ ] **Step 3: Escrever o script**

Criar `scripts\renomear-kit-local.ps1`:

```powershell
#requires -Version 5.1
<#
.SYNOPSIS
  Renomeia a pasta local do kit Percus e conserta o settings.json do usuario.
.DESCRIPTION
  O nome do diretorio de trabalho NAO vem por git pull — e local de cada maquina.
  Rode uma vez por maquina apos o rename entrar no canon. Idempotente.
#>
[CmdletBinding()]
param(
    [string]$KitAtual = $env:PERCUS_CANON_DIR,
    [string]$NomeNovo = "percus-kit",
    [string]$SettingsPath
)
$ErrorActionPreference = "Stop"

# Default calculado no corpo, nao no bloco param: expressao condicional em default de
# parametro e fragil entre PS 5.1 e 7, e este script roda nos dois.
if (-not $SettingsPath) {
    $claudeHome   = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
    $SettingsPath = Join-Path $claudeHome "settings.json"
}

if (-not $KitAtual) { throw "Informe -KitAtual ou defina PERCUS_CANON_DIR." }
$KitAtual = $KitAtual.TrimEnd('\','/')
$destino  = Join-Path (Split-Path $KitAtual -Parent) $NomeNovo

# 1. Rename (idempotente: se ja esta no nome novo, segue pro settings)
if ((Split-Path $KitAtual -Leaf) -ne $NomeNovo) {
    if (-not (Test-Path $KitAtual)) { throw "Pasta nao encontrada: $KitAtual" }
    if (Test-Path $destino) { throw "Destino ja existe: $destino (resolva a mao)" }
    Rename-Item -LiteralPath $KitAtual -NewName $NomeNovo
    Write-Host "[renomear-kit] pasta: $KitAtual -> $destino"
} else {
    $destino = $KitAtual
    Write-Host "[renomear-kit] pasta ja esta como '$NomeNovo' — so o settings"
}

# 2. Settings: backup datado ANTES de qualquer escrita
if (-not (Test-Path $SettingsPath)) { Write-Host "[renomear-kit] settings nao encontrado: $SettingsPath"; return }
$stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $SettingsPath "$SettingsPath.bak-$stamp"

# 3. Troca o nome da pasta em todas as formas de path (barra, contrabarra, escapada).
#    As duas guardas sao obrigatorias e cobrem casos diferentes:
#    - a da direita impede casar o PREFIXO: '_Novo_Projeto' e prefixo de
#      '_Novo_Projeto_V2', que viraria 'percus-kit_V2';
#    - as duas juntas impedem troca no MEIO de token maior (ex.: 'backup_Novo_Projeto_old'),
#      que corromperia a chave em silencio.
#    Nao uso \b porque '_' conta como caractere de palavra e a semantica fica ambigua.
$antigoLeaf = Split-Path $KitAtual -Leaf
# -Encoding UTF8 explicito: no PS 5.1 o default de leitura e ANSI, entao um settings
# UTF-8 sem BOM com acento no path (C:\Users\Joao vs Joäo) seria lido errado e gravado
# de volta corrompido. O script roda em 5.1 e em 7.
$raw = Get-Content $SettingsPath -Raw -Encoding UTF8
$padrao = '(?<![A-Za-z0-9_])' + [regex]::Escape($antigoLeaf) + '(?![A-Za-z0-9_])'
$raw = [regex]::Replace($raw, $padrao, $NomeNovo)

# 4. Valida ANTES de salvar — JSON quebrado desativa todos os hooks em silencio
try { $null = $raw | ConvertFrom-Json } catch { throw "Resultado nao e JSON valido; nada foi salvo. Backup em $SettingsPath.bak-$stamp" }
[IO.File]::WriteAllText($SettingsPath, $raw, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[renomear-kit] settings atualizado (backup: $SettingsPath.bak-$stamp)"
Write-Host "[renomear-kit] PRONTO. Reabra o Claude Code para o PERCUS_CANON_DIR novo valer."
```

- [ ] **Step 4: Rodar e ver passar**

```powershell
Invoke-Pester -Path "tests\renomear-kit-local.tests.ps1" -Output Detailed
```

Esperado: **5/5 PASS**.

- [ ] **Step 5: Review + commit**

```bash
cd "/d/Claud Automations/_Novo_Projeto"
git add scripts/renomear-kit-local.ps1 plugin/percus-review/tests/renomear-kit-local.tests.ps1
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/_Novo_Projeto" && git commit -F - <<'MSG'
scripts: renomear-kit-local.ps1 -- o rename nao vem por git pull

Nome de diretorio de trabalho e local de cada maquina. Sem este script, o kit
teria nome diferente em cada uma e todo path absoluto documentado passaria a
mentir. Idempotente, faz backup datado e VALIDA o JSON antes de salvar --
settings.json quebrado desativa todos os hooks em silencio.

Verificado rodando: 5 testes em par (pasta falsa + settings falso), incluindo
idempotencia e validade do JSON. O settings real nunca e tocado pelo teste.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 5: Executar o rename nesta máquina

> **A partir daqui o kit é `D:\Claud Automations\percus-kit`.** Todos os caminhos abaixo já usam o nome novo.

- [ ] **Step 1: Fechar o que segura a pasta**

Encerre qualquer terminal/editor com o diretório atual dentro de `D:\Claud Automations\_Novo_Projeto`. O `Rename-Item` falha se houver handle aberto.

- [ ] **Step 2: Rodar o script**

```powershell
cd "D:\Claud Automations"
& "D:\Claud Automations\_Novo_Projeto\scripts\renomear-kit-local.ps1" -KitAtual "D:\Claud Automations\_Novo_Projeto" -NomeNovo "percus-kit"
```

Esperado: duas linhas — `pasta: ... -> D:\Claud Automations\percus-kit` e `settings atualizado (backup: ...)`.

- [ ] **Step 3: Verificar**

```powershell
Test-Path "D:\Claud Automations\percus-kit\CANON_VERSION.md"
Test-Path "D:\Claud Automations\_Novo_Projeto"
# Resolve o settings pela MESMA logica do script, em vez de cravar o path: nesta maquina
# CLAUDE_CONFIG_DIR e "D:\Claud Automations\.claude-home", mas o plano nao deve depender disso.
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
(Get-Content (Join-Path $claudeHome "settings.json") -Raw | ConvertFrom-Json).env.PERCUS_CANON_DIR
```

Esperado: `True`, `False`, `D:\Claud Automations\percus-kit` (ou a forma com barra que estava lá).

- [ ] **Step 4: Provar que o wrapper roda do path novo**

```bash
cd "/d/Claud Automations/percus-kit" && sh scripts/percus-review-auto.sh 2>&1 | head -3
```

Esperado: linha `[percus-review-auto] plugin pasta=… plugin.json=…` seguida de `decisao: …`. Se der "plugin nao encontrado", o `CLAUDE_CONFIG_DIR` não foi afetado — investigar antes de seguir.

- [ ] **Step 5: Commit (nada mudou no repo, só o nome local — mas o git precisa estar limpo)**

```bash
cd "/d/Claud Automations/percus-kit" && git status --short
```

Esperado: **vazio**. O rename não gera diff (o nome da pasta não é versionado).

---

### Task 6: Teste que barra referência ao path legado + varredura guiada por ele

**Files:**
- Create: `D:\Claud Automations\percus-kit\plugin\percus-review\tests\no-legacy-kit-path.tests.ps1`
- Modify: os arquivos **vivos** que o teste apontar

- [ ] **Step 1: Escrever o teste que falha**

Criar `plugin\percus-review\tests\no-legacy-kit-path.tests.ps1`:

```powershell
#requires -Version 5.1
# Varredura como GATE, nao como ato de memoria: o pre-mortem do conselho apontou que
# uma referencia escapa e quebra em silencio, so aparecendo quando trava em producao.
# Historico fica de fora por desenho: reescrever plano/spec/handoff de maio falsifica
# o registro do que aconteceu.

Describe "nenhum arquivo VIVO referencia o path legado do kit" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:permitido = @(
            '\.archive\\',
            '\\docs\\superpowers\\plans\\',
            '\\docs\\superpowers\\specs\\',
            '\\docs\\handoffs\\',
            '\\docs\\contracts\\',
            '\\CANON_VERSION\.md$',
            'no-legacy-kit-path\.tests\.ps1$'
        )
    }

    It "grep por '_Novo_Projeto' nao acha nada fora da allowlist" {
        $hits = Get-ChildItem $script:kitRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\\.git\\' } |
            Where-Object { $f = $_.FullName; -not ($script:permitido | Where-Object { $f -match $_ }) } |
            Where-Object { Select-String -Path $_.FullName -Pattern '_Novo_Projeto' -Quiet -ErrorAction SilentlyContinue } |
            ForEach-Object { $_.FullName.Replace($script:kitRoot, '') }

        $hits | Should -BeNullOrEmpty -Because "arquivo vivo apontando pro nome antigo quebra em silencio: $($hits -join ', ')"
    }
}
```

- [ ] **Step 2: Rodar e ver falhar, com a lista**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests\no-legacy-kit-path.tests.ps1" -Output Detailed
```

Esperado: **FAIL** listando os arquivos vivos. Pela medição de 2026-07-29 devem aparecer: `templates\CLAUDE.template.md`, `templates\project-persona.template.md`, `templates\project-recipe.template.md`, `templates\project-skill.template.md`, `templates\login-ui\README.md`, `plugin\percus-review\plugin.json`, `plugin\percus-review\commands\{version,drift-detect,council-consult,council-brainstorm,council-pre-mortem}.md`, `plugin\percus-review\skills\{auth-consumer,cookie-audit,delegate-impl,security-audit}\SKILL.md`, `plugin\percus-review\scripts\tracking_audit.py`, `plugin\percus-review\hooks\{auth-import-pre-commit,on-stop-check}.sh`, `plugin\percus-review\tests\hardening-2026-05-18.tests.ps1`, `v2\MIGRACAO.md`, `v2\referencia\README.md`, `v2\gates\instalar-gates.sh`, `README.md`, `AMBIENTE_LOCAL_OPERADOR.md`, `01_REGRAS_INEGOCIAVEIS.md`, `04_MODEL_ROUTING.md`, `PADRAO_AUTH_SERVICE.md`, `conhecimento\COMO_RESOLVER.md`, `comandos\*.md`.

- [ ] **Step 3: Corrigir arquivo por arquivo**

Substituir `_Novo_Projeto` por `percus-kit` em cada arquivo da lista. Atenção especial:

- `plugin\percus-review\tests\hardening-2026-05-18.tests.ps1`: tem o path **hardcoded** como fallback —
  `$env:PERCUS_CANON_DIR = "D:\Claud Automations\_Novo_Projeto"` vira `"D:\Claud Automations\percus-kit"`.
- `v2\gates\instalar-gates.sh`: verificar se o path aparece em mensagem ao usuário ou em lógica.
- `comandos\*.md`: **estes vão ser arquivados no Task 7**. Corrija mesmo assim (o arquivamento preserva o conteúdo e o teste roda antes).

- [ ] **Step 4: Rodar e ver passar**

```powershell
Invoke-Pester -Path "tests\no-legacy-kit-path.tests.ps1" -Output Detailed
Invoke-Pester -Path "tests" -Output Normal | Select-String "Tests Passed"
```

Esperado: teste novo **PASS**; suíte com `Failed: 0` (o total cresce conforme testes entram — não afira número exato).

- [ ] **Step 5: Review + commit**

```bash
cd "/d/Claud Automations/percus-kit"
git add -A
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/percus-kit" && git commit -F - <<'MSG'
kit: _Novo_Projeto -> percus-kit nas referencias vivas, com gate que impede recaida

O nome da pasta dizia "projeto novo generico"; ela e o kit (huboperacional/percus-kit),
veiculo de entrega das 10 maquinas. Historico (plans/specs/handoffs/contracts/.archive)
fica intocado de proposito: reescrever registro do passado falsifica o registro.

no-legacy-kit-path.tests.ps1 transforma a varredura em gate -- referencia escapando
passa a ser vermelho na suite, nao descoberta quando travar em producao.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 7 (REESCRITA em execução): Corrigir o roteamento — sem mover nada

**Por que mudou:** o arquivamento foi executado, medido e **revertido**. A camada "velha" é apontada
**89 vezes** pela camada viva, incluindo o próprio `v2/referencia/README.md`. Detalhe e evidência na
§3.1 do spec. Aposentar de verdade é migrar conteúdo, e isso virou fase própria.

**Files:**
- Modify: `README.md` — bloco "Por onde um agente entra": `v2/` é a porta; numerados são referência
  **pendente de migração**, com o número medido e o motivo da reversão.
- Modify: `00_LEIA_PRIMEIRO.md` — seção "Antes da tabela: comece pelo `v2/`", com a ordem
  CONSTITUICAO → loop da situação → referência → só então a tabela antiga.

**Não fazer:** `git mv` de `01..06`, `comandos/`, `checklists/`. O patch do arquivamento está em
`scratchpad/task7-arquivamento.patch` para a fase de migração de conteúdo.

**Verificação:** gate `exit 0`; suíte `Failed: 0`; e `grep` provando que nenhum ponteiro vivo passou a
apontar pra `.archive/camada-v1/` (o move foi desfeito).

---

### Task 7 — versão ORIGINAL (não executar; mantida como registro do que foi tentado)

**Files:**
- Create: `D:\Claud Automations\percus-kit\.archive\camada-v1\` (destino)
- Modify: `D:\Claud Automations\percus-kit\README.md` (ponteiro)

- [ ] **Step 1: Mover com histórico preservado**

```bash
cd "/d/Claud Automations/percus-kit"
mkdir -p .archive/camada-v1
git mv 01_REGRAS_INEGOCIAVEIS.md 02_INFRA_E_STACK_PERCUS.md 03_TRACKING_ATTRIBUITION.md \
       04_MODEL_ROUTING.md 05_FEATURE_TRACKING.md 06_CONSELHO_PERCUS.md .archive/camada-v1/
git mv comandos checklists .archive/camada-v1/
git status --short | head -20
```

Esperado: linhas `R  01_REGRAS_INEGOCIAVEIS.md -> .archive/camada-v1/01_REGRAS_INEGOCIAVEIS.md` etc.

- [ ] **Step 2: Ponteiro no README**

Adicionar em `README.md`, logo após o título:

```markdown
> **Camada aposentada.** Os documentos `01..06_*.md`, `comandos/` e `checklists/` foram para
> `.archive/camada-v1/` em 2026-07-29. O canon vivo é `v2/`: `v2/CONSTITUICAO.md` (invariantes) +
> `v2/loops/` (procedimento) + `v2/referencia/` (detalhe de stack). Conhecimento continua em
> `conhecimento/`. Nada em `.archive/` é lido por agente — está lá para consulta histórica.
```

- [ ] **Step 3: Verificar que ninguém vivo aponta pro que foi arquivado**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests" -Output Normal | Select-String "Tests Passed"
```

Esperado: `Failed: 0`. **Um arquivo é conhecido por depender da camada velha** (medido em 2026-07-29):
`plugin\percus-review\tests\hardening-2026-05-18.tests.ps1` monta
`$script:canonPath = Join-Path $env:PERCUS_CANON_DIR "01_REGRAS_INEGOCIAVEIS.md"` — passa a apontar para
`.archive\camada-v1\01_REGRAS_INEGOCIAVEIS.md`. Também há `hooks\settings.json.example` citando
`comandos/`; atualizar o exemplo para o caminho arquivado ou para o `v2/loop` equivalente.

Além disso:

```bash
cd "/d/Claud Automations/percus-kit"
grep -rln "01_REGRAS_INEGOCIAVEIS\|comandos/" --include="*.md" --include="*.ps1" --include="*.sh" . \
  | grep -v "^./.archive" | grep -v "^./docs" | head
```

Esperado: as referências que sobrarem devem ser corrigidas para `.archive/camada-v1/…` ou reescritas para apontar pro `v2/` equivalente.

- [ ] **Step 4: Review + commit**

```bash
cd "/d/Claud Automations/percus-kit"
git add -A
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/percus-kit" && git commit -F - <<'MSG'
kit: camada velha (01..06, comandos/, checklists/) vai pra .archive/camada-v1/

O canon vivo e o v2/: CONSTITUICAO (invariantes) + loops/ (procedimento) +
referencia/ (stack). Manter as duas camadas lado a lado era o que fazia agente
carregar 942 linhas de regra pra consultar uma. git mv preserva o historico.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 8: Versão, changelog e alinhamento

**Files:**
- Modify: `CANON_VERSION.md`, `plugin/percus-review/plugin.json`, `.percus-version`, `.claude-plugin/marketplace.json`

- [ ] **Step 1: Bump nos 4 arquivos para `6.32.0`**

Nos quatro, trocar `6.31.1` por `6.32.0` (em `CANON_VERSION.md` é a linha `**Versão canônica em ...**`).

- [ ] **Step 2: Entrada de changelog**

Em `CANON_VERSION.md`, acima de `## Changelog v6.31.1 — 2026-07-27`:

```markdown
## Changelog v6.32.0 — 2026-07-29

**Casa única: `_Novo_Projeto` → `percus-kit`, camada velha arquivada, gate que estava cego.**

- **Gate de conhecimento via 33 de 105 verbetes.** O rastreio de fence dessincronizava com um
  ``` solto no texto e o gate ficava cego do ponto em diante — saía `exit 0` por não olhar.
  Detecção passa a ser por linha de título (`^## `); crase em `tags:` vira opcional.
- **Rename da pasta:** o nome dizia "projeto novo genérico"; ela é o kit. `scripts/renomear-kit-local.ps1`
  faz o rename **por máquina** (nome de diretório não vem por `git pull`), com backup e validação do JSON.
- **Camada velha** (`01..06`, `comandos/`, `checklists/`) em `.archive/camada-v1/`. Canon vivo = `v2/`.
- **`_Novo_Projeto_V2` apagada** — devia ter virado arquivo em 2026-07-20 (v6.30.0) e não virou;
  as duas cópias divergiram e o fix do gate ficou preso na cópia morta.
- Gate novo contra recaída: `no-legacy-kit-path.tests.ps1`.
```

- [ ] **Step 3: Rodar o teste de alinhamento**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests\version-alignment.tests.ps1" -Output Detailed
```

Esperado: **5/5 PASS** (inclui "tem entrada de changelog da versão atual").

- [ ] **Step 4: Review + commit**

```bash
cd "/d/Claud Automations/percus-kit"
git add CANON_VERSION.md plugin/percus-review/plugin.json .percus-version .claude-plugin/marketplace.json
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/percus-kit" && git commit -F - <<'MSG'
v6.32.0: casa unica percus-kit + camada velha arquivada + gate que estava cego

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 9: Apagar a pasta avulsa

Só agora — até aqui ela foi o backup natural dos 3 deltas.

- [ ] **Step 1: Confirmar que os deltas estão no kit**

```powershell
$kit = "D:\Claud Automations\percus-kit"
Select-String -Path "$kit\v2\gates\percus-gate.sh" -Pattern "\^## " -Quiet
Select-String -Path "$kit\v2\loops\review.md" -Pattern "percus-review\.json" -Quiet
Select-String -Path "$kit\.gitignore" -Pattern "\.percus/" -Quiet
```

Esperado: `True`, `True`, `True`. Se algum for `False`, **pare** — o delta não chegou.

- [ ] **Step 2: Confirmar que ninguém aponta pra pasta avulsa**

```bash
grep -rl "_Novo_Projeto_V2" "/d/Claud Automations/percus-kit" "/d/Claud Automations/.claude-home/settings.json" 2>/dev/null \
  | grep -v "/.git/" | grep -v "/docs/" | grep -v "CANON_VERSION.md"
```

Esperado: **saída vazia**.

- [ ] **Step 3: Apagar**

```powershell
Remove-Item -Recurse -Force "D:\Claud Automations\_Novo_Projeto_V2"
Test-Path "D:\Claud Automations\_Novo_Projeto_V2"
```

Esperado: `False`.

- [ ] **Step 4: Suíte completa como fechamento**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests" -Output Normal | Select-String "Tests Passed"
```

Esperado: `Failed: 0`.

- [ ] **Step 5: Gate no canon**

```powershell
cd "D:\Claud Automations\percus-kit"
$bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
if (-not $bash) { $bash = "$env:ProgramFiles\Git\bin\bash.exe" }
& $bash "v2/gates/percus-gate.sh"; $LASTEXITCODE
```

Esperado: `0`.

---

## Critério de pronto do plano (todos observados, nenhum assumido)

- [ ] `Invoke-Pester -Path "tests"` → `Failed: 0` (≥173 testes; não aferir número exato)
- [ ] Gate roda no canon com `exit 0` **e** os 4 testes negativos do Task 1 continuam barrando
- [ ] `D:\Claud Automations\percus-kit` existe; `_Novo_Projeto` e `_Novo_Projeto_V2` não existem
- [ ] `PERCUS_CANON_DIR` aponta pro path novo e o wrapper roda de lá
- [ ] `no-legacy-kit-path.tests.ps1` verde (nenhum arquivo vivo com o nome antigo)
- [ ] Os 4 arquivos de versão em `6.32.0`, com entrada de changelog

## Próximo plano (não é este)

Migração dos 11 hooks pro `settings.json` (§4.4 do spec), com a sequência de 6 etapas por hook que o
pre-mortem exigiu. Será escrito depois deste plano rodar, com os caminhos já em `percus-kit`.
