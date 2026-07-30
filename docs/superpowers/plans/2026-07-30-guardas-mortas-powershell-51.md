# Guardas mortas no PowerShell 5.1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trazer de volta as três guardas `PreToolUse` que estão respondendo verde sem rodar, e deixar a classe impossível de se repetir em silêncio.

**Architecture:** Duas falhas encaixadas: 16 `.ps1` que o PowerShell 5.1 não parseia (encoding lido como ANSI) e 11 wrappers `.cmd` que traduzem "script morreu" em `exit 0`. O conserto é em camadas com **ordem obrigatória** — os arquivos primeiro, o wrapper depois — mais dois testes comportamentais que rodam o artefato de verdade sob o runtime real (`powershell.exe`, não `pwsh`).

**Tech Stack:** Windows PowerShell 5.1 (`powershell.exe`) + PowerShell 7 (`pwsh`) + Pester 5.7, batch (`.cmd`), git.

**Spec:** `D:\Claud Automations\percus-kit\docs\superpowers\specs\2026-07-30-guardas-mortas-powershell-51-design.md` (aprovado; conselho consultado 3x — consult, pre-mortem e review do texto escrito).

---

## Por que a ordem das tasks não é negociável

A Task 5 (wrapper barulhento) **depois** da Task 2 (arquivos consertados). Invertido, as três guardas quebradas passam de "aprovam tudo" para "bloqueiam todo `PreToolUse` Bash" — e a máquina para de commitar, inclusive o commit do próprio conserto. Estado que se auto-tranca.

## Estrutura de arquivos

| Arquivo | Responsabilidade | Ação |
|---|---|---|
| `plugin\percus-review\tests\ps51-compat.tests.ps1` | prova que todo `.ps1` do kit parseia sob o runtime real dos hooks | Criar (Task 1) |
| os 16 `.ps1` do Anexo A do spec | receber BOM, conteúdo byte-idêntico | Modificar (Task 2) |
| `plugin\percus-review\tests\hook-wrapper-fail-loud.tests.ps1` | prova que o wrapper não traduz "morreu" em "aprovou" | Criar (Task 4) |
| os 11 `.cmd` de `plugin\percus-review\hooks\` | trocar `-Command` por `-File`, preservando fim de linha | Modificar (Task 5) |

**Convenção de commit (R11, obrigatória):** antes de cada `git commit`, rodar o review numa chamada **separada** — `sh "D:/Claud Automations/percus-kit/scripts/percus-review-auto.sh"` — e tratar findings de bug/regressão. Trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`.

**Nota de ambiente:** se a sessão que executa este plano começou **antes** do rename de 2026-07-30, `PERCUS_CANON_V2_DIR` está com o valor velho e o gate de pre-commit barra todo commit com `PERCUS: gate V2 nao achado em ...\_Novo_Projeto\v2/gates/`. Contorno legítimo (o gate roda, não é `--no-verify`): prefixar cada commit com `PERCUS_CANON_V2_DIR="/d/Claud Automations/percus-kit/v2"`. Sessão nova não precisa disso.

---

### Task 1: Teste que prova o gatilho — e falha vermelho com os 16

**Files:**
- Create: `D:\Claud Automations\percus-kit\plugin\percus-review\tests\ps51-compat.tests.ps1`

- [ ] **Step 1: Escrever o teste**

Criar `plugin\percus-review\tests\ps51-compat.tests.ps1`:

```powershell
#requires -Version 5.1
# Prova que todo .ps1 do kit PARSEIA sob Windows PowerShell 5.1 -- que e o runtime real
# dos hooks: todo .cmd em hooks/ invoca powershell.exe, nunca pwsh 7. A suite roda em
# pwsh 7, que le UTF-8 por default, entao ela e cega pra esta classe por construcao.
# Foi assim que 16 arquivos, incluindo 3 guardas de PreToolUse, quebraram sem ninguem ver.

Describe "todo .ps1 do kit parseia sob Windows PowerShell 5.1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:ps51    = Get-Command powershell.exe -ErrorAction SilentlyContinue
    }

    It "nenhum .ps1 do kit tem erro de parse no 5.1" {
        if (-not $script:ps51) {
            Set-ItResult -Skipped -Because "powershell.exe (5.1) nao existe nesta maquina; sem ele os .cmd tambem nao rodam, entao o hook e irrelevante aqui"
            return
        }

        # Parse SEM executar. Rodar os .ps1 pra descobrir se parseiam dispararia hook de
        # verdade (git, rede, escrita em .deepseek/) como efeito colateral de um teste.
        $prog = @'
$raiz = $args[0]
Get-ChildItem $raiz -Recurse -Include *.ps1 -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\\.git\\' } |
  ForEach-Object {
    $erros = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$erros)
    if ($erros -and $erros.Count -gt 0) {
      "{0} ({1} erro(s)) -- 1o: {2}" -f $_.FullName.Replace($raiz + '\', ''), $erros.Count, $erros[0].Message
    }
  }
'@
        # O proprio programa auxiliar vai COM BOM: ele tambem seria lido como ANSI pelo 5.1.
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("ps51-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".ps1")
        [IO.File]::WriteAllText($tmp, $prog, (New-Object System.Text.UTF8Encoding($true)))
        try {
            $falhas = & $script:ps51.Source -NoProfile -ExecutionPolicy Bypass -File $tmp $script:kitRoot 2>&1
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }

        @($falhas) | Should -BeNullOrEmpty -Because "arquivo que nao parseia no 5.1 e hook que morre calado:`n$(($falhas | Out-String))"
    }
}
```

- [ ] **Step 2: Rodar e ver falhar, com a lista dos 16**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests\ps51-compat.tests.ps1" -Output Detailed
```

Esperado: **FAIL** listando 16 arquivos. Os três primeiros por gravidade operacional são `hooks\external-action-guard.ps1` (10 erros), `hooks\auth-import-pre-commit.ps1` (7) e `hooks\types-check-pre-commit.ps1` (7) — as guardas wired. Se aparecer número diferente de 16, **pare**: o Anexo A do spec foi medido em 2026-07-30 e divergência significa que outra coisa mudou.

- [ ] **Step 3: Review + commit (vermelho, de propósito)**

```bash
cd "/d/Claud Automations/percus-kit"
git add plugin/percus-review/tests/ps51-compat.tests.ps1
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/percus-kit" && PERCUS_CANON_V2_DIR="/d/Claud Automations/percus-kit/v2" git commit -F - <<'MSG'
teste: prova vermelha dos 16 .ps1 que o PowerShell 5.1 nao parseia

Commitado VERMELHO de proposito: a lista de 16 e a medicao do defeito, e o proximo
commit e o que a apaga. Sem ver este vermelho, o BOM seria um commit sem prova de
que resolveu alguma coisa.

O teste roda o powershell.exe de verdade porque e ele que executa os hooks -- todo
.cmd em hooks/ invoca powershell.exe, nunca pwsh 7. A suite roda em pwsh 7, que le
UTF-8 por default, e por isso nao via nada disso.

Parse sem execucao (Parser::ParseFile): executar os .ps1 pra descobrir se parseiam
dispararia hook de verdade como efeito colateral de teste.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 2: BOM nos 34 — os dois `It` da Task 1 ficam verdes

**Files:**
- Modify: os 34 `.ps1` do kit com byte > `0x7F` e sem BOM (os 16 do Anexo A que quebram o parse, mais 18 que passam no parse e só imprimem lixo — entre eles os hooks wired `pre-commit-check.ps1` e `on-stop-check.ps1`)

> **Escopo revisado em execução:** era 16. A revisão de qualidade da Task 1 mostrou que parse-only enxerga só metade da armadilha; ver o bloco de escopo no §2 do spec.

- [ ] **Step 1: Gravar o BOM por bytes**

**Nunca** por `Set-Content`/`Out-File`/editor: os arquivos estão com fim de linha **LF** e o repo tem `core.autocrlf=true` sem `.gitattributes`. Via texto, o fim de linha é reescrito (medido: `Set-Content -Encoding utf8BOM` no pwsh 7 já acrescenta um CRLF final, 4098 → 4103 bytes) e o diff vira arquivo inteiro.

```powershell
Os alvos **não são listados à mão**: são exatamente os que o `It` de invariante da Task 1 acusa —
todo `.ps1` do kit com byte > `0x7F` e sem BOM, fora de `.git\` e `node_modules\`. Descobrir pela
mesma regra que o teste usa elimina a chance de a lista e o teste divergirem.

```powershell
$kit = "D:\Claud Automations\percus-kit"
$alvos = Get-ChildItem $kit -Recurse -Include *.ps1 -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' } |
  Where-Object {
    $b = [IO.File]::ReadAllBytes($_.FullName)
    $temNaoAscii = $false
    foreach ($x in $b) { if ($x -gt 0x7F) { $temNaoAscii = $true; break } }
    $comBom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
    $temNaoAscii -and -not $comBom
  }
"alvos: $($alvos.Count)"   # esperado: 34
foreach ($alvo in $alvos) {
  $f = $alvo.FullName
  $rel = $f.Replace("$kit\", "")
  $b = [IO.File]::ReadAllBytes($f)
  if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) {
    "JA TEM BOM (pulado): $rel"; continue
  }
  [IO.File]::WriteAllBytes($f, (@(0xEF,0xBB,0xBF) + $b))
  # prova por arquivo: o conteudo depois do BOM tem que ser byte-identico ao original
  $d = [IO.File]::ReadAllBytes($f)
  $ok = [Convert]::ToBase64String($d[3..($d.Length-1)]) -eq [Convert]::ToBase64String($b)
  "{0,-6} {1}" -f $(if ($ok) { "OK" } else { "ERRO" }), $rel
}
```

Esperado: `alvos: 34`, 34 linhas `OK`, nenhuma `ERRO`, nenhuma `JA TEM BOM`.

- [ ] **Step 2: Provar que o diff é de uma linha por arquivo**

```bash
cd "/d/Claud Automations/percus-kit" && git diff --stat
```

Esperado: `34 files changed, 34 insertions(+)` — sem deleções. Qualquer deleção significa fim de linha reescrito: **desfaça com `git checkout -- <arquivo>` e refaça por bytes.**

- [ ] **Step 3: Rodar o teste da Task 1 e ver os DOIS `It` passarem**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests\ps51-compat.tests.ps1" -Output Detailed
```

Esperado: **2 PASS** — o de parse (era 16 falhas) e o de invariante (era 34).

- [ ] **Step 4: Rodar a suíte inteira (o BOM toca 11 arquivos de teste)**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests" | Select-String "Tests Passed"
```

Esperado: `Failed: 0`. O total cresce com o teste novo — não afira número exato.

- [ ] **Step 5: Review + commit**

```bash
cd "/d/Claud Automations/percus-kit"
git add -A
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/percus-kit" && PERCUS_CANON_V2_DIR="/d/Claud Automations/percus-kit/v2" git commit -F - <<'MSG'
kit: BOM nos 16 .ps1 -- 3 guardas de PreToolUse voltam a rodar

Windows PowerShell 5.1 le .ps1 sem BOM como ANSI. Um em dash dentro de string vira
aspa curva em ANSI, e o PowerShell aceita aspa curva como delimitador -- a string
fecha antes da hora e o arquivo inteiro desanda. Com BOM ele le UTF-8 e parseia.

Gravado por bytes, nao por Set-Content: os arquivos estao com LF e o repo tem
core.autocrlf=true sem .gitattributes, entao via texto o fim de linha seria
reescrito e o diff viraria arquivo inteiro. Provado: conteudo apos o BOM
byte-identico ao original em cada arquivo, e git diff --stat com 16 insercoes e
zero delecoes.

ATENCAO -- as guardas voltam a guardar: external-action-guard barra gh pr comment
e git push sem PERCUS_EXTERNAL_OVERRIDE=1; types-check-pre-commit barra erro de
tipo; auth-import-pre-commit barra import de auth fora do padrao. Commit que
passava pode comecar a falhar. Nao e regressao, e a funcao voltando depois de um
periodo em que nao rodou. Escape geral: PERCUS_HOOKS_DISABLED=1.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 3: Medir o que as guardas revividas passam a barrar

Sem alteração de arquivo. Existe porque o pre-mortem do conselho apontou "conserto revertido porque quebrou os commits" como o motivo de falha **mais provável** do plano — e o antídoto é saber o que mudou antes de alguém descobrir do jeito ruim.

**Files:** nenhum.

- [ ] **Step 1: Exercitar as três guardas com payload representativo**

O hook recebe o JSON do `PreToolUse` por stdin; o campo que importa é `tool_input.command`.

```powershell
$h = "D:\Claud Automations\percus-kit\plugin\percus-review\hooks"
$casos = @(
  @{ Hook = "external-action-guard";  Cmd = "git push origin main" }
  @{ Hook = "external-action-guard";  Cmd = "gh pr comment 12 --body oi" }
  @{ Hook = "external-action-guard";  Cmd = "git status" }
  @{ Hook = "auth-import-pre-commit"; Cmd = "git commit -m teste" }
  @{ Hook = "types-check-pre-commit"; Cmd = "git commit -m teste" }
)
foreach ($c in $casos) {
  $json = '{"tool_name":"Bash","tool_input":{"command":"' + $c.Cmd + '"}}'
  $saida = ($json | & cmd.exe /c "`"$h\$($c.Hook).cmd`"" 2>&1) | Out-String
  "{0,-24} {1,-32} exit={2}" -f $c.Hook, $c.Cmd, $LASTEXITCODE
  if ($saida.Trim()) { "    " + ($saida.Trim() -replace "`r?`n", "`n    ") }
}
```

- [ ] **Step 2: Ler o resultado com a expectativa certa**

Nenhum `exit` é "errado" por si só — este passo **mede**, não afere. O que interessa:

- `exit=0` em tudo é resultado plausível: `external-action-guard` é fail-open por desenho (o próprio cabeçalho diz *"qualquer erro -> exit 0 (nao bloqueia injustamente)"*) e só barra quando há ação externa **e** council/findings em estado ruim.
- Qualquer `exit` não-zero: anote o hook, o comando e a mensagem. É exatamente o que vai surpreender alguém amanhã.
- **Erro de parse em qualquer um deles significa que a Task 2 não fechou** — volte pra ela.

- [ ] **Step 3: Registrar o achado**

Se algum hook barrar, leve a linha (hook + comando + mensagem + escape) para o corpo do commit da Task 5 e para o aviso ao time. Se nenhum barrar, registre isso também — é a informação de que a revivência é silenciosa e não vai gerar atrito.

Sem commit nesta task.

---

### Task 4: Teste do amplificador — vermelho contra os `.cmd` de hoje

**Files:**
- Create: `D:\Claud Automations\percus-kit\plugin\percus-review\tests\hook-wrapper-fail-loud.tests.ps1`

- [ ] **Step 1: Escrever o teste**

Criar `plugin\percus-review\tests\hook-wrapper-fail-loud.tests.ps1`:

```powershell
#requires -Version 5.1
# O .cmd e a fronteira entre o harness e a guarda: o harness so le zero/nao-zero. Se o
# wrapper traduz "o script nem rodou" em zero, guarda quebrada responde "aprovado" -- foi
# o que aconteceu em 2026-07-30 com 3 guardas de PreToolUse.
#
# O .ps1 e sintetico de proposito, e o .cmd e o REAL: o artefato sob teste e o wrapper.
# O par copiado roda sozinho porque o .cmd resolve o script por %~dp0.

Describe "wrapper .cmd nao engole falha do .ps1" {
    BeforeAll {
        $script:kitRoot  = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:hooksDir = Join-Path $script:kitRoot "plugin\percus-review\hooks"
        $script:temps    = New-Object System.Collections.ArrayList

        # Copia o .cmd real e planta um .ps1 sintetico com o mesmo nome ao lado dele.
        function New-ParDeTeste {
            param([string]$Nome, [string]$ConteudoPs1, [bool]$ComBom)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("wrap-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Copy-Item (Join-Path $script:hooksDir "$Nome.cmd") (Join-Path $dir "$Nome.cmd")
            [IO.File]::WriteAllText((Join-Path $dir "$Nome.ps1"), $ConteudoPs1, (New-Object System.Text.UTF8Encoding($ComBom)))
            [void]$script:temps.Add($dir)
            return (Join-Path $dir "$Nome.cmd")
        }

        function Invoke-Wrapper {
            param([string]$Cmd)
            $null = ('{"tool_name":"Bash","tool_input":{"command":"git status"}}' | & cmd.exe /c "`"$Cmd`"" 2>&1)
            return $LASTEXITCODE
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "com .ps1 que nao PARSEIA, o wrapper sai NAO-ZERO" {
        # Gatilho real deste defeito: em dash DENTRO de string, arquivo SEM BOM. Sem BOM o
        # 5.1 le ANSI, o ultimo byte do em dash vira aspa curva e fecha a string cedo.
        # Nao uso chave desbalanceada nem lixo aleatorio: precisa ser falha de PARSE.
        # Falha de EXECUCAO o wrapper antigo ja propagava certo, entao o teste passaria
        # pelo motivo errado e nao provaria nada sobre o amplificador.
        #
        # O corpo sadio faz 'exit 0' de proposito: se um dia a corrupcao parar de corromper,
        # o script roda, sai 0, e o teste FALHA. A direcao da falha e segura -- nunca vira
        # falso verde.
        $conteudo = "Write-Host 'este script NAO deveria ter rodado'`nWrite-Host `"x " + [char]0x2014 + " y`"`nexit 0"
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 $conteudo -ComBom $false

        Invoke-Wrapper -Cmd $cmd | Should -Not -Be 0 -Because "guarda que nao roda nao pode responder 'aprovado' pro harness"
    }

    It "com .ps1 sadio que bloqueia, o wrapper propaga o codigo (exit 2)" {
        # A outra metade da prova: consertar o engolimento nao pode custar a semantica.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "Write-Host 'bloqueando'`nexit 2" -ComBom $true
        Invoke-Wrapper -Cmd $cmd | Should -Be 2
    }

    It "com .ps1 ausente, o wrapper sai NAO-ZERO" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("wrap-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Copy-Item (Join-Path $script:hooksDir "external-action-guard.cmd") (Join-Path $dir "external-action-guard.cmd")
        [void]$script:temps.Add($dir)
        # de proposito: nenhum .ps1 ao lado
        Invoke-Wrapper -Cmd (Join-Path $dir "external-action-guard.cmd") | Should -Not -Be 0
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests\hook-wrapper-fail-loud.tests.ps1" -Output Detailed
```

Esperado: **2 FAIL, 1 PASS**. Falham "não parseia" e "ausente" (ambos devolvem `0` hoje); passa o "propaga exit 2", porque o `-Command` já acerta esse caso — e é justamente o que a Task 5 não pode quebrar.

- [ ] **Step 3: Review + commit (vermelho, de propósito)**

```bash
cd "/d/Claud Automations/percus-kit"
git add plugin/percus-review/tests/hook-wrapper-fail-loud.tests.ps1
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/percus-kit" && PERCUS_CANON_V2_DIR="/d/Claud Automations/percus-kit/v2" git commit -F - <<'MSG'
teste: prova vermelha do wrapper que traduz "guarda morreu" em "aprovado"

2 vermelhos e 1 verde, e o verde importa tanto quanto: o -Command ja propaga
corretamente o exit de script sadio, entao ele e a semantica que o conserto nao
pode custar.

O .ps1 dos casos e sintetico e o .cmd e o real -- o artefato sob teste e o wrapper,
nao a guarda. O caso de parse quebrado usa o gatilho real (em dash dentro de string,
arquivo sem BOM) em vez de lixo aleatorio: corrupcao qualquer daria falha de
EXECUCAO, que o wrapper atual ja propaga certo, e o teste passaria pelo motivo
errado. O corpo sadio faz exit 0 pra que, se a corrupcao um dia parar de corromper,
o teste falhe em vez de virar falso verde.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 5: `-File` nos 11 `.cmd` — o teste da Task 4 fica verde

**Files:**
- Modify: os 11 `.cmd` de `D:\Claud Automations\percus-kit\plugin\percus-review\hooks\`

**Pré-requisito rígido:** a Task 2 tem que estar commitada e o teste da Task 1 verde. Wrapper barulhento com guarda quebrada bloqueia todo `PreToolUse` Bash, incluindo o commit deste plano.

- [ ] **Step 1: Trocar só a linha, preservando o resto dos bytes**

4 dos 11 `.cmd` estão com CRLF e 7 com LF (medido). Reescrever o arquivo inteiro normalizaria fim de linha em 7 deles; o comando abaixo troca apenas a linha do `powershell.exe`. O `MatchEvaluator` existe porque `$` na string de substituição é metacaractere de regex — o mesmo defeito que o review pegou em `renomear-kit-local.ps1`.

```powershell
$h = "D:\Claud Automations\percus-kit\plugin\percus-review\hooks"
$padrao = 'powershell\.exe -NoProfile -ExecutionPolicy Bypass -Command "& \\"%~dp0(?<n>[\w\-]+)\.ps1\\"; exit \$LASTEXITCODE"'
foreach ($c in (Get-ChildItem $h -Filter *.cmd | Sort-Object Name)) {
  $raw = [IO.File]::ReadAllText($c.FullName)
  $novo = [regex]::Replace($raw, $padrao, {
    param($m) 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0' + $m.Groups['n'].Value + '.ps1"'
  })
  if ($novo -eq $raw) { "NAO CASOU: $($c.Name)"; continue }
  [IO.File]::WriteAllText($c.FullName, $novo, (New-Object Text.UTF8Encoding($false)))
  "ok: $($c.Name)"
}
```

Esperado: 11 linhas `ok:`, nenhuma `NAO CASOU`. (Dry-run já feito em 2026-07-30: 11/11 casaram e o fim de linha ficou preservado nos dois estilos.)

- [ ] **Step 2: Provar que só a linha mudou**

```bash
cd "/d/Claud Automations/percus-kit" && git diff --stat plugin/percus-review/hooks/
```

Esperado: `11 files changed, 11 insertions(+), 11 deletions(-)`. Número maior significa fim de linha reescrito — desfaça com `git checkout -- plugin/percus-review/hooks/` e refaça.

- [ ] **Step 3: Rodar o teste da Task 4 e ver passar**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests\hook-wrapper-fail-loud.tests.ps1" -Output Detailed
```

Esperado: **3 PASS**.

- [ ] **Step 4: Provar que os 11 hooks reais continuam rodando**

```powershell
$h = "D:\Claud Automations\percus-kit\plugin\percus-review\hooks"
foreach ($c in (Get-ChildItem $h -Filter *.cmd | Sort-Object Name)) {
  $saida = ('{"tool_name":"Bash","tool_input":{"command":"git status"}}' | & cmd.exe /c "`"$($c.FullName)`"" 2>&1) | Out-String
  $parse = if ($saida -match 'ParserError') { "ERRO DE PARSE" } else { "ok" }
  "{0,-28} exit={1,-4} {2}" -f $c.BaseName, $LASTEXITCODE, $parse
}
```

Esperado: 11 linhas `ok`, nenhum `ERRO DE PARSE`. `exit` não-zero aqui é resultado legítimo (guarda barrando `git status`? improvável, mas se acontecer é comportamento real, não falha do wrapper) — o que **não** pode aparecer é `ERRO DE PARSE`.

- [ ] **Step 5: Suíte inteira**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests" | Select-String "Tests Passed"
```

Esperado: `Failed: 0`.

- [ ] **Step 6: Review + commit**

```bash
cd "/d/Claud Automations/percus-kit"
git add plugin/percus-review/hooks/
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/percus-kit" && PERCUS_CANON_V2_DIR="/d/Claud Automations/percus-kit/v2" git commit -F - <<'MSG'
hooks: -File nos 11 wrappers -- guarda que morre agora grita

Com -Command "& script; exit $LASTEXITCODE", script que nao parseia nunca roda,
$LASTEXITCODE fica nulo e o wrapper sai 0 -- o harness le "guarda aprovou". Com
-File, o mesmo caso sai 1, e script ausente sai nao-zero. Bancada tambem confirmou
o que NAO pode mudar: guarda sadia com exit 2 continua devolvendo 2, stdin continua
chegando, e stdout, PSScriptRoot, CWD, PSCommandPath e args ficam identicos -- este
ultimo importava porque 5 hooks usam (Get-Location) como raiz do projeto.

Descartado manter -Command com sentinela (exit 97 quando LASTEXITCODE for nulo): o
harness so le zero/nao-zero, entao o codigo "diagnostico" seria lido como bloqueio.
A opcao mais informativa era a que travava a maquina.

Trocada so a linha do powershell.exe, preservando os bytes do resto: 4 dos 11 .cmd
estao com CRLF e 7 com LF, e reescrever inteiro normalizaria 7 deles.

Verificado rodando: 3 testes do wrapper verdes, os 11 .cmd reais executados sem erro
de parse, suite completa verde.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

---

### Task 6: Verificação final e ponteiros

**Files:** nenhum (só leitura), exceto o Step 3.

- [ ] **Step 1: Provar as duas camadas de uma vez, do zero**

```powershell
cd "D:\Claud Automations\percus-kit\plugin\percus-review"
Invoke-Pester -Path "tests\ps51-compat.tests.ps1","tests\hook-wrapper-fail-loud.tests.ps1" -Output Detailed
```

Esperado: **4 PASS, 0 FAIL** (1 do parse + 3 do wrapper).

- [ ] **Step 2: Conferir que o repo está limpo e o diff é o esperado**

```bash
cd "/d/Claud Automations/percus-kit" && git status --short && git log --oneline -5
```

Esperado: `git status` sem nada de `plugin/percus-review/hooks/` nem dos 16 `.ps1`. (O arquivo `conhecimento/COMO_RESOLVER.md` pode aparecer modificado — é trabalho de outra sessão, não toque.)

- [ ] **Step 3: Anotar no plano da migração que a versão 6.32.0 precisa citar isto**

O bump de versão e o changelog são da **Task 8 do plano `2026-07-29-migracao-percus-kit-casa-unica.md`**, que ainda está pendente. Este plano não mexe em `CANON_VERSION.md`, `plugin.json`, `.percus-version` nem `marketplace.json` — dois planos disputando os mesmos 4 arquivos é conflito garantido.

Acrescentar ao final da seção "ESTADO DA EXECUÇÃO" daquele plano:

```markdown
**Entrou depois (2026-07-30), precisa constar no changelog da 6.32.0:** três guardas `PreToolUse`
estavam respondendo verde sem rodar (16 `.ps1` que o PowerShell 5.1 não parseava + wrapper `.cmd`
que traduzia "script morreu" em `exit 0`). Consertado no plano
`docs/superpowers/plans/2026-07-30-guardas-mortas-powershell-51.md`.
```

```bash
cd "/d/Claud Automations/percus-kit"
git add docs/superpowers/plans/2026-07-29-migracao-percus-kit-casa-unica.md
sh scripts/percus-review-auto.sh
```

```bash
cd "/d/Claud Automations/percus-kit" && PERCUS_CANON_V2_DIR="/d/Claud Automations/percus-kit/v2" git commit -F - <<'MSG'
plano: a 6.32.0 tem que citar as guardas mortas no changelog

O bump de versao e da Task 8 do plano da migracao, que ainda esta pendente. Este
ponteiro existe pra que o changelog nao nasca contando so metade do que mudou na
versao -- e pra que os dois planos nao disputem os mesmos 4 arquivos.

Co-Authored-By: Claude <noreply@anthropic.com>
MSG
```

- [ ] **Step 4: Avisar o time**

O que precisa chegar às outras máquinas, em uma frase: *"as guardas `external-action-guard`, `auth-import-pre-commit` e `types-check-pre-commit` estavam mortas respondendo verde desde antes de 2026-07-30 e voltaram a funcionar — commit que passava pode começar a barrar; escape por guarda é `PERCUS_EXTERNAL_OVERRIDE=1`, escape geral é `PERCUS_HOOKS_DISABLED=1`"*, mais o que a Task 3 tiver medido.

---

## Fora deste plano

| Item | Onde vive |
|---|---|
| 4ª família de ponteiro `.git/percus-v2-dir` (12 repos apontando pro caminho morto) | decisão do operador foi tratar depois; sem plano ainda |
| Mensagem do gate dizer "o canon parece ter sido movido de X para Y" | sugestão do time Plexco Tasks; vai junto com o item acima |
| Verbete R23 em `conhecimento/COMO_RESOLVER.md` sobre erro de parse que aponta pro lugar errado | não decidido pelo operador |
| Migrar os 11 hooks pro `settings.json` | "plano 2" previsto no design da casa única |
| Bump de versão e changelog | Task 8 do plano da migração |
