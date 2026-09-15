# R11 sem ponto único de falha — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** o gate R11 deixa de depender de uma única chamada DeepSeek: cliente com timeout + 1 retry + exit 4 visível, comando suportado para registrar a review Cross-Claude, e hook que só libera por marcador com conteúdo de review.

**Architecture:** quatro peças com paridade `.ps1`/`.sh`: (1) hook `pre-commit-check` + hook git nativo classificam o marcador lido (review / placeholder / inválido); (2) cliente `deepseek-review` com `HttpClient`/`curl --max-time`, retry único e despejo mascarado do corpo; (3) novo `registrar-review` que grava `d-<hash>.jsonl` e `latest.jsonl` de forma atômica; (4) wrapper `percus-review-auto` que distingue exit 4 e entrega a linha pronta do registro no marcador `__PERCUS_NEEDS_CROSS_CLAUDE__`.

**Tech Stack:** Windows PowerShell 5.1 (runtime real) / pwsh 7 (suíte), Pester 5, Git Bash (bash, `/bin/sh`, gawk, curl, jq, sha256sum).

**Spec:** `docs/superpowers/specs/2026-09-14-r11-sem-ponto-unico-design.md` (ANALYZED, com as emendas do controlador em FR-011, FR-016 e §8). Executores leem a spec E este plano.

**Raiz de trabalho:** `D:\Claud Automations\percus-kit\.claude\worktrees\r11-fallback` (branch `worktree-r11-fallback`, base `c144aaf`). Todo caminho deste plano é relativo a essa raiz, porque a ferramenta PowerShell exige caminho relativo (ver regras de ambiente).

## Global Constraints

- **Regras de ambiente (leitura obrigatória antes de qualquer task):** `D:\Claud Automations\percus-kit\.claude\worktrees\plano-sync\.superpowers\sdd\2026-09-13-plano-sync-2a\scratch-plano-2\regras-de-ambiente.md`, substituindo a raiz `plano-sync` por `r11-fallback`. Resumo que vale sobre qualquer comando deste plano: PowerShell só pela ferramenta PowerShell (`& '.\script.ps1'`, `Invoke-Pester -Path '.\...'`); git simples, um comando por chamada da ferramenta Bash, sem `-C` e sem `&&`; `-m` com aspas simples; testes em PRIMEIRO PLANO (nunca background); suíte nunca em paralelo com outra; não dispare subagentes; não empurre, não faça merge.
- `.ps1` roda em Windows PowerShell 5.1: sem `??`, sem ternário, um filho por `Join-Path`, sem `-AdditionalChildPath`, sem `[IO.Path]::GetRelativePath`.
- Fonte `.ps1` em ASCII; caractere especial por code point (`[char]0x00ED`). Todo `.ps1` já existente tocado aqui TEM BOM (medido: `deepseek-review.ps1`, `percus-review-auto.ps1`, `pre-commit-check.ps1`, todos os `.tests.ps1` citados) — edite só com a ferramenta Edit e confira `head -c3 <arquivo> | od -An -tx1` = `ef bb bf` antes e depois. `.ps1` NOVO nasce UTF-8 **com BOM** (convenção de `plugin/percus-review/scripts/` e `tests/`, todos com BOM; `ps51-compat` exige BOM se houver byte > 0x7F).
- Chamada nativa (`git`) em `.ps1` novo: NÃO use `$ErrorActionPreference = 'Stop'` no escopo do script — no 5.1 ele transforma stderr nativo em exceção mesmo com `2>$null` (verbete `conhecimento/resolver/erroractionpreference-stop-e-herdado-e-transforma-stderr-nativo-em-excecao.md`). Teste `$LASTEXITCODE`.
- Interpolação: `"$nome:true"` é variável com escopo no PowerShell — escreva `"${nome}:true"`.
- `.sh`: ASCII e LF. Arquivo novo: nenhum byte > 0x7F nem `\r`. Arquivo existente: linhas ADICIONADAS em ASCII, índice em LF (`git ls-files --eol -- <arq>` mostra `i/lf`; `pre-commit-check.sh` já é `i/-text` na base por um `\r` literal num comentário da linha 102 — não normalize o arquivo). O checkout tem `core.autocrlf=true`, então `file` na árvore pode dizer CRLF para arquivo antigo; o critério é o índice. Saída de `jq.exe` no Windows traz `\r`: sempre `| tr -d '\r'`. Sob `set -e`/`pipefail`, pipeline dentro de `$(...)` que pode falhar leva `|| true`.
- Pester 5: um `BeforeAll`/`AfterAll` por bloco; funções usadas pelos `It` dentro do `BeforeAll`; dados de `-ForEach` montados em `BeforeDiscovery`; nada de três crases literais; nenhum texto `git`+`commit` literal em payload de hook (monte `'com' + 'mit'`).
- Testes HTTP: zero rede real. Servidor falso local (`tests/_servidor-http-falso.ps1`, Task 2) apontado por `-Endpoint`/`--endpoint`; chave falsa só no ambiente do processo de teste, restaurada no fim (ausência restaurada com `[NullString]::Value`).
- Regra do hash (idêntica em hook, cliente e registro): SHA-256 dos bytes escritos por `git -C <raiz> diff HEAD --output=<tmp>`, 12 primeiros hex minúsculos. Arquivo vazio ⇒ hash `e3b0c44298fc` ⇒ **sem hash** (emenda FR-011/FR-016): nunca grava nem procura `d-e3b0c44298fc.jsonl`.
- Sem bump de versão. `CANON_VERSION.md` só ganha entrada em "Pendente de versão" (Task 6).
- **R11 por commit (trilho G):** depois do `git add -- <arquivos>`, rode `& '.\plugin\percus-review\scripts\deepseek-review.ps1'` (a cópia do WORKTREE, não o wrapper — o wrapper usa o plugin instalado). Confira cada finding no código; conserte o que proceder e rode os testes de novo; declare no corpo do commit o que não proceder e por quê. Re-rode a review só se arquivos mudaram depois dela.
- **Commit (ferramenta Bash, uma chamada):**
  `PERCUS_GATE_OVERSIZE='sem bump nesta branch (versao no merge); INDICE.md do main lista verbetes de outra sessao' git commit -m '<assunto ASCII>' -m '<corpo: o que mudou + triagem R11>' -m 'Gate: PERCUS_GATE_OVERSIZE declarado -- sem bump nesta branch (versao atribuida no merge) e INDICE.md do main lista verbetes nao commitados por outra sessao.' -m 'Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>' -- <arquivos da task>`
  Confira com `git log -1 --format=%B`. Se o gate barrar por outro motivo, pare e reporte. Nunca `PERCUS_HOOKS_DISABLED`.
- **Testes por task:** os arquivos de teste da task + `ps51-compat.tests.ps1` + `hooks-leitura-utf8.tests.ps1` (+ `pester-blocos-unicos.tests.ps1` quando cria/edita teste). Suíte inteira só na Task 6.
- Não edite `conhecimento/resolver/INDICE.md` nem rode o gerador de índice.

---

## Pré-voo (controlador, antes da Task 1)

Pasta de trabalho não versionada (gitignored via `.deepseek/`): `.deepseek\r11-sem-ponto-unico\`.

- [ ] **P1: estado limpo.** `git rev-parse --short HEAD` = `c144aaf` (ou o commit que acrescenta spec+plano) e `git status --porcelain` só com spec/plano.

- [ ] **P2: baseline da suíte inteira** (sem outra suíte rodando — confira com `Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" | Where-Object { $_.CommandLine -match 'rodar-suite|Invoke-Pester' }` vazio). Ferramenta PowerShell, primeiro plano, timeout 600000:

```powershell
New-Item -ItemType Directory -Force -Path '.\.deepseek\r11-sem-ponto-unico' | Out-Null
$ini = Get-Date
& '.\scripts\rodar-suite.ps1' *>&1 | Tee-Object -FilePath '.\.deepseek\r11-sem-ponto-unico\baseline-suite.txt'
"PERCUS_CTX_WINDOW=[$env:PERCUS_CTX_WINDOW] inicio=$($ini.ToString('HH:mm:ss')) fim=$((Get-Date).ToString('HH:mm:ss'))" | Add-Content '.\.deepseek\r11-sem-ponto-unico\baseline-suite.txt'
```

Esperado: falhas só entre as 18 conhecidas por nome exato (6 da regra de ambiente + 12 `context-budget-guard hook`, lista em `D:\Claud Automations\percus-kit\.claude\worktrees\checkpoint-so-operador\.superpowers\sdd\2026-09-14-checkpoint-so-operador\baseline-suite.txt`), ou menos. Qualquer outra: pare. A lista medida aqui vira a lista aceita na Task 6.

- [ ] **P3: script de latência (SC-007).** Crie `.deepseek\r11-sem-ponto-unico\medir-latencia-hook.ps1` (não versionado):

```powershell
param([string[]]$Hooks, [int]$N = 20)
$ErrorActionPreference = 'Continue'
$dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-lat-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Push-Location $dir
try {
    & git init -q . 2>$null; & git config user.email t@t.t 2>$null; & git config user.name t 2>$null
    Set-Content -Path (Join-Path $dir 'a.ps1') -Value 'original' -Encoding utf8
    & git add a.ps1 2>$null; & git @('com' + 'mit', '-q', '-m', 'base', '--no-verify') 2>$null
    Set-Content -Path (Join-Path $dir 'a.ps1') -Value 'alterado com acentuacao' -Encoding utf8
    $tmp = [IO.Path]::GetTempFileName()
    & git diff HEAD --output=$tmp 2>$null | Out-Null
    $sha = [Security.Cryptography.SHA256]::Create()
    $h = ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($tmp))) -replace '-','').ToLower().Substring(0,12)
    Remove-Item $tmp -Force
} finally { Pop-Location }
$rev = Join-Path $dir '.deepseek'; $rev = Join-Path $rev 'reviews'
New-Item -ItemType Directory -Force -Path $rev | Out-Null
$enc = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $rev 'latest.jsonl'), '{"findings":"Sem findings criticos."}', $enc)
(Get-Item (Join-Path $rev 'latest.jsonl')).LastWriteTime = (Get-Date).AddMinutes(-60)
[IO.File]::WriteAllText((Join-Path $rev "d-$h.jsonl"), '{"findings":"Sem findings criticos."}', $enc)
$payload = @{ tool_name = 'Bash'; tool_input = @{ command = ('cd "' + $dir + '" && git com' + 'mit -m x') } } | ConvertTo-Json -Compress
$tempos = @{}
foreach ($k in $Hooks) { $tempos[$k] = New-Object System.Collections.Generic.List[double] }
foreach ($k in $Hooks) { $payload | & pwsh -NoProfile -File $k *>$null }   # aquecimento
for ($i = 0; $i -lt $N; $i++) {
    foreach ($k in $Hooks) {   # alternado: deriva da maquina pesa igual nos dois
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $payload | & pwsh -NoProfile -File $k *>$null
        $sw.Stop()
        if ($LASTEXITCODE -ne 0) { throw "hook $k saiu $LASTEXITCODE -- a medicao tem de ser do caminho que LIBERA" }
        $tempos[$k].Add($sw.Elapsed.TotalMilliseconds)
    }
}
foreach ($k in $Hooks) {
    $o = @($tempos[$k] | Sort-Object)
    $med = ($o[[int][Math]::Floor(($o.Count - 1) / 2)] + $o[[int][Math]::Ceiling(($o.Count - 1) / 2)]) / 2
    "{0} mediana={1:N1}ms" -f $k, $med
}
Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
```

- [ ] **P4: cópia do hook antigo + baseline de latência.** Ferramenta Bash (uma chamada):
  `MSYS_NO_PATHCONV=1 git show c144aaf:plugin/percus-review/hooks/pre-commit-check.ps1 > .deepseek/r11-sem-ponto-unico/pre-commit-check-antigo.ps1`
  Confira BOM (`head -c3 ... | od -An -tx1` = `ef bb bf`). Depois, ferramenta PowerShell:
  `& '.\.deepseek\r11-sem-ponto-unico\medir-latencia-hook.ps1' -Hooks @('.\.deepseek\r11-sem-ponto-unico\pre-commit-check-antigo.ps1') | Tee-Object '.\.deepseek\r11-sem-ponto-unico\latencia-baseline.txt'`
  Informativo: o critério SC-007 é medido na Task 6 com antigo e novo no MESMO run.

- [ ] **P5: DeepSeek alcançável** (para o R11 de cada commit). Ferramenta PowerShell:

```powershell
$k = $env:DEEPSEEK_API_KEY
if (-not $k -and (Test-Path '.\.env')) { $l = Get-Content '.\.env' -Encoding UTF8 | Where-Object { $_ -match '^\s*DEEPSEEK_API_KEY\s*=' } | Select-Object -First 1; if ($l) { $k = ($l -replace '^\s*DEEPSEEK_API_KEY\s*=\s*', '').Trim('"', "'", ' ') } }
if (-not $k) { 'SEM CHAVE' } else { (Invoke-RestMethod -Uri 'https://api.deepseek.com/models' -Headers @{ Authorization = "Bearer $k" } -TimeoutSec 30).data.id -join ', ' }
```

Esperado: lista de modelos. Se falhar, avise o operador antes de despachar (o R11 de cada task depende disso; com o provedor fora, a própria feature vira o contorno só depois da Task 4).

---

## Mapa de arquivos

| Arquivo | Task | Responsabilidade |
|---|---|---|
| `plugin/percus-review/hooks/pre-commit-check.ps1` (modificar) | 1 | classificar marcador, regra do hash vazio, `deferidos.log`, WARN no stderr |
| `plugin/percus-review/hooks/pre-commit-check.sh` (modificar) | 1 | mesma decisão, classificador awk |
| `plugin/percus-review/git-hooks/pre-commit.template.sh` (modificar) | 1 | mesma decisão em `/bin/sh` sem jq |
| `plugin/percus-review/tests/_resolver-bash.ps1` (criar) | 1 | localizar Git Bash, converter caminho, copiar sem CR |
| `plugin/percus-review/tests/pre-commit-marcador-classificacao.tests.ps1` (criar) | 1 | matriz SC-001 + hash vazio + deferidos + WARN |
| `plugin/percus-review/scripts/deepseek-review.ps1` (modificar) | 2 | timeout, retry, exits 1/3/4, corpo mascarado, hash vazio |
| `plugin/percus-review/tests/_servidor-http-falso.ps1` (criar) | 2 | servidor HTTP roteirizado em processo separado |
| `plugin/percus-review/tests/deepseek-review-retry.tests.ps1` (criar) | 2 | SC-003/004/005 no `.ps1` |
| `plugin/percus-review/scripts/deepseek-review.sh` (modificar) | 3 | paridade + `model`/`usage` no marcador |
| `plugin/percus-review/tests/deepseek-review-retry-sh.tests.ps1` (criar) | 3 | SC-003/004/005 no `.sh` + paridade do `ultimo-erro.txt` |
| `plugin/percus-review/scripts/registrar-review.ps1` / `.sh` (criar) | 4 | registro validado, atômico, com telemetria |
| `plugin/percus-review/tests/registrar-review.tests.ps1` (criar) | 4 | FR-009..014 + SC-006 |
| `scripts/percus-review-auto.ps1` / `.sh` (modificar) | 5 | motivo do exit 4, linha de registro nos 4 pontos, stderr do cliente visível |
| `plugin/percus-review/tests/percus-review-auto-registro.tests.ps1` (criar) | 5 | FR-007/008 |
| `01_REGRAS_INEGOCIAVEIS.md`, `conhecimento/resolver/deepseek-review-2xx-sem-choices-nao-grava-review.md`, `CANON_VERSION.md` (modificar) | 6 | FR-020 |

---

## Contratos compartilhados (valem para todas as tasks)

Strings exatas. Teste de uma task pode afirmar string definida aqui.

**Classificação do marcador (FR-015)** — resultado: `review`, `placeholder` ou `invalido` + motivo. Ordem de decisão (igual nas 3 camadas):
1. tamanho > 262144 bytes → `invalido`, motivo `acima do teto (256 KB)` (sem ler);
2. falha de leitura → `invalido`, `ilegivel`;
3. remove BOM UTF-8 inicial; texto só com espaço/`\t`/`\n`/`\r` → `invalido`, `vazio`;
4. não parseia como JSON → `invalido`, `nao e JSON`; raiz não é objeto → `invalido`, `raiz nao e objeto`;
5. chave `deferred` (nome exato) com booleano `true` E chave `reason` string com conteúdo não-branco → `placeholder` (com `decision` = string não-branca ou `desconhecida`);
6. sem chave `findings` → `invalido`, `sem findings nem placeholder`;
7. `findings` não-string (inclui `null`) → `invalido`, `findings nao e string`;
8. `findings` branco (só espaço, `\t`, `\n`, `\r`, inclusive escapados `\n` `\t` `\r` `\u0020` `\u0009` `\u000a` `\u000d`) → `invalido`, `findings vazio`;
9. senão → `review`.

**Mensagens do hook** (prefixo `[percus:hook pre-commit]` no PreToolUse, `[percus:hook pre-commit native]` no hook git):
- recusa por hash, citada em QUALQUER BLOCK posterior: linha `  recusado: d-<hash>.jsonl recusado: <motivo>` (placeholder no caminho do hash usa o motivo `placeholder nao libera por hash`);
- `latest` inválido: `<prefixo> BLOCK: marcador <nome> invalido: <motivo>`;
- placeholder que libera: `<prefixo> AVISO: commit SEM review real -- liberado por placeholder deferido (<nome>, decision=<decision>). Registre a review Cross-Claude com registrar-review.`;
- fail-graceful: `[percus:hook pre-commit] WARN: hook crashed, allowing commit. Error: <erro>` no **stderr**.

**`deferidos.log`** — `.deepseek/reviews/deferidos.log`, 1 linha JSON por liberação: `{"timestamp":"<UTC yyyy-MM-ddTHH:mm:ssZ>","camada":"pretooluse|git-hook","repo":"<raiz>","decision":"<valor>","reason":"<valor>"}`. Falha ao gravar é engolida.

**Cliente DeepSeek** (`[deepseek-review]`, tudo no stderr):
- antes da 1ª chamada: `[deepseek-review] timeout=<t>s backoff=<b>s`;
- env inválida: `[deepseek-review] WARN: <VAR>='<valor>' invalido -- usando padrao <n>.`;
- corpo sem `choices`: `[deepseek-review] resposta sem choices (HTTP <status>) -- primeiros 2000 caracteres do corpo:` e na linha seguinte o trecho;
- retry: `[deepseek-review] tentativa 1 falhou: <causa>. Nova tentativa em <b>s.`;
- exit 4: `[deepseek-review] PROVEDOR INDISPONIVEL apos retry: <causa>. Nenhum marcador gravado (exit 4).`;
- exit 1 (4xx≠429 e outros status): `[deepseek-review] ERRO: HTTP <status> -- nao recuperavel, sem nova tentativa. Nenhum marcador gravado (exit 1).`;
- causas: `erro de rede/timeout: timeout de <t>s`, `erro de rede/timeout: <mensagem>`, `HTTP <s>`, `HTTP <s> sem choices`, `HTTP <s> com corpo vazio`.
- Trecho = corpo com TODA ocorrência da chave trocada por `***`, DEPOIS cortado nos primeiros 2000 caracteres (mascarar antes de cortar impede meia chave na borda).
- `ultimo-erro.txt` (`.deepseek/reviews/`, UTF-8 sem BOM, LF, sobrescrito): `timestamp=<UTC>\nstatus=<s>\n---\n<trecho>` (sem `\n` final).
- "sem choices" = corpo que não começa (após espaço) com `{`, não parseia, ou cujo `choices` está ausente/não-array/vazio. Vale para qualquer status; o despejo acontece em toda resposta HTTP sem choices, inclusive 429/5xx/401.

**Registro** (`registrar-review`): ps1 `-Arquivo -Canal [-Modelo] [-Repo]`; sh `--arquivo --canal [--modelo] [--repo]`. Exits: 0 sucesso; 1 ambiente (jq/git/sha256sum ausente, `git diff HEAD` falhou, hash vazio); 2 entrada recusada; 3 falha de gravação (rollback feito). Sucesso imprime no stdout exatamente `hash=<h> latest=<caminho> d=<caminho>`. Mensagens `[registrar-review] ERRO: <motivo>`; motivos: `arquivo de findings ausente: '<arq>'`, `canal vazio`, `findings acima do teto (256 KB): <n> bytes`, `findings vazio ou so espaco`, `o arquivo e um placeholder (<campo>:true), nao uma review`, `o texto contem o marcador __PERCUS_NEEDS_CROSS_CLAUDE__ -- isso e o pedido de review, nao a review`, `repositório sem commit` (acento por code point), `git diff HEAD vazio -- nao ha o que registrar`, `hash vazio -- nada gravado`.
Marcador gravado: `{"timestamp","base":"","diff_lines":<n de bytes 0x0A do diff>,"model":<string|null>,"usage":null,"findings":<texto sem BOM>,"canal":<canal>}` + `\n`.

**Wrapper:** texto de exit 4 no `reason`: `provedor indisponível após retry (exit 4)`; outro exit: `DeepSeek falhou (exit <n>)`. Instrução de registro anexada a TODO marcador `__PERCUS_NEEDS_CROSS_CLAUDE__`:
- ps1: ` Depois que o subagente responder, grave os findings dele num arquivo e registre com registrar-review: & '<caminho absoluto>' -Arquivo '<arquivo-dos-findings>' -Canal cross-claude -Modelo '<modelo-do-subagente>'. Sem esse registro o commit so passa pelo placeholder de 5 min.`
- sh: igual, com `bash '<caminho absoluto>' --arquivo '<arquivo-dos-findings>' --canal cross-claude --modelo '<modelo-do-subagente>'`.

---

### Task 1: Hook classifica o marcador (PreToolUse `.ps1`/`.sh` + hook git nativo)

**Files:**
- Create: `plugin/percus-review/tests/_resolver-bash.ps1`
- Create: `plugin/percus-review/tests/pre-commit-marcador-classificacao.tests.ps1`
- Modify: `plugin/percus-review/hooks/pre-commit-check.ps1:56,87-95,135-206` (funções novas, caminho do hash, caminho do latest, catch)
- Modify: `plugin/percus-review/hooks/pre-commit-check.sh:8,93-155`
- Modify: `plugin/percus-review/git-hooks/pre-commit.template.sh:10,20-90`
- Test (inalterados, SC-002): `plugin/percus-review/tests/pre-commit-hash-validity.tests.ps1`, `pre-commit-path-resolution.tests.ps1`, `review-politica-risco.tests.ps1`, `hardening-2026-05-19.tests.ps1`

**Interfaces:**
- Consumes: nada.
- Produces: `tests/_resolver-bash.ps1` com `Get-BashGit` → `[string]` (caminho do bash.exe ou `$null`); `ConvertTo-CaminhoBash([string]$Caminho)` → `[string]` (`\` → `/`); `Copy-SemCR([string]$Origem, [string]$Destino)`; `Set-EnvTemporario([hashtable]$Env)` → `[hashtable]` de valores antigos (valor `$null` remove a variável); `Restore-EnvTemporario([hashtable]$Antigos)`. No hook: `Get-ClasseMarcador -Caminho` → `@{ Classe; Motivo; Decision; Reason }`. Nos `.sh`: bloco `# >>> percus-classifica-marcador` … `# <<< percus-classifica-marcador` idêntico, com `percus_classifica_marcador <arquivo>` (linha 1 classe; linha 2 motivo ou decision; linha 3 reason) e `percus_json_escapa <texto>`.

- [ ] **Step 1: Crie `tests/_resolver-bash.ps1`** (UTF-8 com BOM; dot-source, não é suíte):

```powershell
#requires -Version 5.1
# Utilitarios de teste para exercitar .sh a partir do Pester. Nao e *.tests.ps1: quem precisa faz
# dot-source no BeforeAll.
# Git\bin\bash.exe PRIMEIRO: o lancador poe %HOME%\bin (onde mora o jq desta maquina) no PATH
# (medido 2026-09-13, _dispatch-paridade.ps1). O `bash` do PATH pode ser o do WSL.

function Get-BashGit {
    $c = Join-Path $env:ProgramFiles 'Git'
    $c = Join-Path $c 'bin'
    $c = Join-Path $c 'bash.exe'
    if (Test-Path -LiteralPath $c) { return $c }
    $g = Get-Command bash -ErrorAction SilentlyContinue
    if ($g) { return $g.Source }
    return $null
}

function ConvertTo-CaminhoBash {
    param([string]$Caminho)
    return $Caminho.Replace([char]92, [char]47)
}

function Copy-SemCR {
    # Simula a instalacao do hook nativo (verbete sh-do-plugin-no-cache-chega-com-crlf...): tr -d '\r'.
    param([string]$Origem, [string]$Destino)
    $b = [IO.File]::ReadAllBytes($Origem)
    $l = New-Object System.Collections.Generic.List[byte]
    foreach ($x in $b) { if ($x -ne 13) { $l.Add($x) } }
    [IO.File]::WriteAllBytes($Destino, $l.ToArray())
}

function Set-EnvTemporario {
    param([hashtable]$Env)
    $antigos = @{}
    foreach ($k in $Env.Keys) {
        $antigos[$k] = [Environment]::GetEnvironmentVariable($k)
        if ($null -eq $Env[$k]) { [Environment]::SetEnvironmentVariable($k, [NullString]::Value) }
        else { [Environment]::SetEnvironmentVariable($k, [string]$Env[$k]) }
    }
    return $antigos
}

function Restore-EnvTemporario {
    # SetEnvironmentVariable(k, $null) no pwsh cria a variavel VAZIA; so [NullString]::Value remove.
    param([hashtable]$Antigos)
    foreach ($k in $Antigos.Keys) {
        if ($null -eq $Antigos[$k]) { [Environment]::SetEnvironmentVariable($k, [NullString]::Value) }
        else { [Environment]::SetEnvironmentVariable($k, [string]$Antigos[$k]) }
    }
}
```

- [ ] **Step 2: Escreva o teste que falha** — `tests/pre-commit-marcador-classificacao.tests.ps1` (UTF-8 com BOM):

```powershell
#requires -Version 5.1
# FR-015..019 / SC-001: o hook passa a LER o marcador e so libera por conteudo de review.
# Antes (2026-09-14) placeholder, arquivo vazio ou lixo em d-<hash>.jsonl liberavam igual a review
# real -- o hook so olhava existencia e mtime. Tres camadas, mesma matriz, mesmo resultado.

BeforeDiscovery {
    $casos = @(
        @{ Caso = 'review';         LiberaHash = $true;  LiberaLatest = $true;  Motivo = '' }
        @{ Caso = 'placeholder';    LiberaHash = $false; LiberaLatest = $true;  Motivo = 'placeholder nao libera por hash' }
        @{ Caso = 'findings-vazio'; LiberaHash = $false; LiberaLatest = $false; Motivo = 'findings vazio' }
        @{ Caso = 'so-espaco';      LiberaHash = $false; LiberaLatest = $false; Motivo = 'findings vazio' }
        @{ Caso = 'nao-string';     LiberaHash = $false; LiberaLatest = $false; Motivo = 'findings nao e string' }
        @{ Caso = 'raiz-array';     LiberaHash = $false; LiberaLatest = $false; Motivo = 'raiz nao e objeto' }
        @{ Caso = 'vazio';          LiberaHash = $false; LiberaLatest = $false; Motivo = 'vazio' }
        @{ Caso = 'nao-json';       LiberaHash = $false; LiberaLatest = $false; Motivo = 'nao e JSON' }
        @{ Caso = 'acima-teto';     LiberaHash = $false; LiberaLatest = $false; Motivo = 'acima do teto (256 KB)' }
        @{ Caso = 'bom';            LiberaHash = $true;  LiberaLatest = $true;  Motivo = '' }
    )
    $script:matriz = @()
    foreach ($cam in @('ps1', 'sh', 'git')) {
        foreach ($c in $casos) {
            foreach ($onde in @('hash', 'latest')) {
                $lib = $c.LiberaLatest; if ($onde -eq 'hash') { $lib = $c.LiberaHash }
                $mot = $c.Motivo; if ($onde -eq 'latest' -and $c.Caso -eq 'placeholder') { $mot = '' }
                $script:matriz += @{ Camada = $cam; Caso = $c.Caso; Onde = $onde; Libera = $lib; Motivo = $mot }
            }
        }
    }
}

Describe "hook pre-commit -- classificacao do marcador nas 3 camadas" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        $plugin = Split-Path $PSScriptRoot -Parent
        $script:hookPs1  = Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.ps1'
        $script:hookSh   = Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.sh'
        $script:template = Join-Path (Join-Path $plugin 'git-hooks') 'pre-commit.template.sh'
        $script:bash = Get-BashGit
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-cls-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        # Hook git instalado = template sem CR (procedimento do verbete de CRLF).
        $script:templateLF = Join-Path $script:tmpBase 'pre-commit'
        Copy-SemCR -Origem $script:template -Destino $script:templateLF
        $script:bloqueio = @{ ps1 = 2; sh = 2; git = 1 }
        $script:u8 = New-Object System.Text.UTF8Encoding($false)

        function Get-DiffHash {
            param([string]$RepoDir)
            $tmp = [IO.Path]::GetTempFileName()
            try {
                Push-Location $RepoDir
                try { & git diff HEAD --output=$tmp 2>$null | Out-Null } finally { Pop-Location }
                $sha = [System.Security.Cryptography.SHA256]::Create()
                return ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($tmp))) -replace '-','').ToLower().Substring(0,12)
            } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }

        function Get-BytesCaso {
            param([string]$Caso)
            switch ($Caso) {
                'review'         { return $script:u8.GetBytes('{"findings":"Sem findings criticos."}') }
                'placeholder'    { return $script:u8.GetBytes('{"deferred":true,"reason":"DeepSeek falhou (exit 4)","decision":"dual","placeholder":true}') }
                'findings-vazio' { return $script:u8.GetBytes('{"findings":""}') }
                'so-espaco'      { return $script:u8.GetBytes('{"findings":"   \n\t  "}') }
                'nao-string'     { return $script:u8.GetBytes('{"findings":42}') }
                'raiz-array'     { return $script:u8.GetBytes('[{"findings":"Sem findings criticos."}]') }
                'vazio'          { return [byte[]]@() }
                'nao-json'       { return $script:u8.GetBytes('Sem findings criticos.') }
                'acima-teto'     { return $script:u8.GetBytes('{"findings":"' + ('a' * 262200) + '"}') }
                'bom'            { return [byte[]](@(0xEF, 0xBB, 0xBF) + $script:u8.GetBytes('{"findings":"Sem findings criticos."}')) }
            }
        }

        # Repo com a.ps1 alterado E staged: o hook git so age com algo staged, e .ps1 fura a
        # dispensa por extensao da politica de risco.
        function New-RepoMarcador {
            param([string]$Caso, [ValidateSet('hash','latest','nenhum')][string]$Onde, [switch]$SemCommit)
            $dir = Join-Path $script:tmpBase ("r-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Push-Location $dir
            try {
                & git init -q . 2>$null; & git config user.email t@t.t 2>$null; & git config user.name t 2>$null
                if (-not $SemCommit) {
                    [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "original`n", $script:u8)
                    & git add a.ps1 2>$null
                    & git @(('com' + 'mit'), '-q', '-m', 'base', '--no-verify') 2>$null
                }
                [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "alterado com acentuacao`n", $script:u8)
                & git add a.ps1 2>$null
            } finally { Pop-Location }
            $rev = Join-Path (Join-Path $dir '.deepseek') 'reviews'
            New-Item -ItemType Directory -Force -Path $rev | Out-Null
            $latest = Join-Path $rev 'latest.jsonl'
            if ($Onde -eq 'latest') {
                [IO.File]::WriteAllBytes($latest, (Get-BytesCaso $Caso))
            } else {
                [IO.File]::WriteAllBytes($latest, (Get-BytesCaso 'review'))
                (Get-Item $latest).LastWriteTime = (Get-Date).AddMinutes(-60)
            }
            if ($Onde -eq 'hash') {
                [IO.File]::WriteAllBytes((Join-Path $rev ("d-" + (Get-DiffHash $dir) + ".jsonl")), (Get-BytesCaso $Caso))
            }
            return $dir
        }

        function Invoke-Camada {
            param([string]$Camada, [string]$Repo, [string]$Alternativo = '')
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $cmd = 'cd "' + (ConvertTo-CaminhoBash $Repo) + '" && git com' + 'mit -m x'
            $payload = @{ tool_name = 'Bash'; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            $code = -1
            if ($Camada -eq 'ps1') {
                $payload | & pwsh -NoProfile -File $script:hookPs1 2>$err | Out-Null; $code = $LASTEXITCODE
            } elseif ($Camada -eq 'sh') {
                $alvo = $script:hookSh; if ($Alternativo) { $alvo = $Alternativo }
                $payload | & $script:bash (ConvertTo-CaminhoBash $alvo) 2>$err | Out-Null; $code = $LASTEXITCODE
            } else {
                $alvo = $script:templateLF; if ($Alternativo) { $alvo = $Alternativo }
                Push-Location $Repo
                try { & $script:bash -c ("sh '" + (ConvertTo-CaminhoBash $alvo) + "'") 2>$err | Out-Null; $code = $LASTEXITCODE } finally { Pop-Location }
            }
            $texto = ''
            if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            return [pscustomobject]@{ Code = $code; Err = $texto }
        }
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "pre-condicao: Git Bash com jq, sha256sum e awk" {
        # Sem jq o pre-commit-check.sh libera tudo e as linhas sh passariam por vacuidade.
        $script:bash | Should -Not -BeNullOrEmpty
        $saida = & $script:bash -c 'command -v jq; command -v sha256sum; command -v awk' 2>&1 | Out-String
        $saida | Should -Match 'jq'
        $saida | Should -Match 'sha256sum'
        $saida | Should -Match 'awk'
    }

    It "<Camada> | <Onde> | <Caso>" -ForEach $script:matriz {
        $repo = New-RepoMarcador -Caso $Caso -Onde $Onde
        $r = Invoke-Camada -Camada $Camada -Repo $repo
        if ($Libera) {
            $r.Code | Should -Be 0 -Because "deveria liberar. stderr: $($r.Err)"
        } else {
            $r.Code | Should -Be $script:bloqueio[$Camada] -Because "deveria bloquear. stderr: $($r.Err)"
            if ($Motivo) { $r.Err | Should -Match ([regex]::Escape($Motivo)) }
            if ($Onde -eq 'hash') { $r.Err | Should -Match 'd-[0-9a-f]{12}\.jsonl recusado' }
        }
        if ($Onde -eq 'latest' -and $Caso -eq 'placeholder') {
            $r.Err | Should -Match 'SEM review real'
            $log = Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'deferidos.log'
            $linhas = @([IO.File]::ReadAllLines($log, $script:u8) | Where-Object { $_.Trim() })
            $linhas.Count | Should -Be 1
            $j = $linhas[0] | ConvertFrom-Json
            $esperada = 'pretooluse'; if ($Camada -eq 'git') { $esperada = 'git-hook' }
            $j.camada    | Should -Be $esperada
            $j.decision  | Should -Be 'dual'
            $j.reason    | Should -Be 'DeepSeek falhou (exit 4)'
            $j.repo      | Should -Not -BeNullOrEmpty
            "$($j.timestamp)" | Should -Not -BeNullOrEmpty
        }
    }

    It "<Camada>: hash do diff vazio (repo sem commit) nao usa d-e3b0c44298fc.jsonl" -ForEach @(
        @{ Camada = 'ps1' }, @{ Camada = 'sh' }, @{ Camada = 'git' }
    ) {
        # Um d-e3b0c44298fc.jsonl real existe hoje em outro worktree: liberaria por 24 h qualquer
        # diff de repo sem commit (emenda FR-016).
        $repo = New-RepoMarcador -Caso 'review' -Onde 'nenhum' -SemCommit
        $rev = Join-Path (Join-Path $repo '.deepseek') 'reviews'
        [IO.File]::WriteAllText((Join-Path $rev 'd-e3b0c44298fc.jsonl'), '{"findings":"Sem findings criticos."}', $script:u8)
        $r = Invoke-Camada -Camada $Camada -Repo $repo
        $r.Code | Should -Be $script:bloqueio[$Camada] -Because "latest.jsonl tem 60 min; so o d-e3b0 liberaria. stderr: $($r.Err)"
    }

    It "<Camada>: latest.jsonl invalido e velho bloqueia pelo TEMPO, sem classificar" -ForEach @(
        @{ Camada = 'ps1' }, @{ Camada = 'sh' }, @{ Camada = 'git' }
    ) {
        $repo = New-RepoMarcador -Caso 'nao-json' -Onde 'latest'
        $latest = Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'latest.jsonl'
        (Get-Item $latest).LastWriteTime = (Get-Date).AddMinutes(-10)
        $r = Invoke-Camada -Camada $Camada -Repo $repo
        $r.Code | Should -Be $script:bloqueio[$Camada]
        $r.Err  | Should -Match 'max 5'
        $r.Err  | Should -Not -Match 'nao e JSON'
    }

    It "<Camada>: deferidos.log que nao grava nao muda a decisao" -ForEach @(
        @{ Camada = 'ps1' }, @{ Camada = 'sh' }, @{ Camada = 'git' }
    ) {
        $repo = New-RepoMarcador -Caso 'placeholder' -Onde 'latest'
        New-Item -ItemType Directory -Force -Path (Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'deferidos.log') | Out-Null
        (Invoke-Camada -Camada $Camada -Repo $repo).Code | Should -Be 0
    }

    It "ps1: erro interno sai 0 com WARN no STDERR" {
        $err = Join-Path $script:tmpBase 'warn.txt'
        '{isto nao e json' | & pwsh -NoProfile -File $script:hookPs1 2>$err | Out-Null
        $LASTEXITCODE | Should -Be 0
        ([IO.File]::ReadAllText($err)) | Should -Match '^\[percus:hook pre-commit\] WARN:'
    }

    It "o bloco awk e identico nos dois .sh" {
        $blocos = foreach ($arq in @($script:hookSh, $script:template)) {
            $t = [IO.File]::ReadAllText($arq).Replace("`r", '')
            $i = $t.IndexOf('# >>> percus-classifica-marcador')
            $f = $t.IndexOf('# <<< percus-classifica-marcador')
            $i | Should -BeGreaterThan -1 -Because "$arq sem o bloco"
            $f | Should -BeGreaterThan $i
            $t.Substring($i, $f - $i)
        }
        $blocos[0] | Should -BeExactly $blocos[1]
    }

    It "<Camada>: copia CRLF (como no cache do plugin) ainda classifica review" -ForEach @(
        @{ Camada = 'sh' }, @{ Camada = 'git' }
    ) {
        $orig = $script:hookSh; if ($Camada -eq 'git') { $orig = $script:template }
        $crlf = Join-Path $script:tmpBase ("crlf-" + $Camada + ".sh")
        $t = [IO.File]::ReadAllText($orig).Replace("`r`n", "`n").Replace("`n", "`r`n")
        [IO.File]::WriteAllText($crlf, $t, $script:u8)
        $repo = New-RepoMarcador -Caso 'review' -Onde 'latest'
        $r = Invoke-Camada -Camada $Camada -Repo $repo -Alternativo $crlf
        $r.Code | Should -Be 0 -Because "stderr: $($r.Err)"
    }
}
```

- [ ] **Step 3: Rode e confirme a falha.** Ferramenta PowerShell, primeiro plano:
  `Invoke-Pester -Path '.\plugin\percus-review\tests\pre-commit-marcador-classificacao.tests.ps1' -Output Detailed`
  Esperado FAIL: `hash|<não-review>` (hoje liberam), `latest|<inválido>` (hoje liberam), `deferidos.log` inexistente, `d-e3b0` (hoje libera), WARN (hoje vai ao stdout), bloco awk ausente. Se a pré-condição falhar, pare e reporte (não pule).

- [ ] **Step 4: Classificador no `pre-commit-check.ps1`.** Com Edit, insira depois de `Get-CommitTargetDir` (antes do `try {` da linha 56):

```powershell
# === CLASSIFICACAO DO MARCADOR (2026-09-14, FR-015) ===
# Ate aqui o hook liberava pela EXISTENCIA do arquivo: placeholder, arquivo vazio ou lixo em
# d-<hash>.jsonl passavam igual a review real. Ordem e textos sao contrato com o bloco awk
# percus-classifica-marcador dos .sh -- mude os tres juntos.
# ARMADILHA pwsh 7: ConvertFrom-Json ENUMERA array na raiz, entao '[{"findings":"x"}]' viraria o
# objeto de dentro e liberaria. Por isso a raiz tambem e decidida pelo primeiro caractere.
# Nome de chave com -ceq: acesso a propriedade no PowerShell ignora caixa; o awk nao.
# Limite conhecido fora da matriz: pwsh 7 converte string com cara de data ISO em DateTime.
function Get-PropriedadeExata {
    param($Obj, [string]$Nome)
    foreach ($p in $Obj.PSObject.Properties) { if ($p.Name -ceq $Nome) { return $p } }
    return $null
}

function Get-ClasseMarcador {
    param([string]$Caminho)
    $r = @{ Classe = 'invalido'; Motivo = ''; Decision = 'desconhecida'; Reason = '' }
    $ws = [char[]]@(32, 9, 10, 13)
    try {
        if ((Get-Item -LiteralPath $Caminho).Length -gt 262144) { $r.Motivo = 'acima do teto (256 KB)'; return $r }
        $bytes = [IO.File]::ReadAllBytes($Caminho)
    } catch { $r.Motivo = 'ilegivel'; return $r }
    $ini = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $ini = 3 }
    $texto = (New-Object System.Text.UTF8Encoding($false)).GetString($bytes, $ini, $bytes.Length - $ini)
    $limpo = $texto.Trim($ws)
    if ($limpo.Length -eq 0) { $r.Motivo = 'vazio'; return $r }
    $obj = $null
    try { $obj = ConvertFrom-Json -InputObject $texto -ErrorAction Stop } catch { $r.Motivo = 'nao e JSON'; return $r }
    if (-not $limpo.StartsWith('{') -or $obj -isnot [System.Management.Automation.PSCustomObject]) { $r.Motivo = 'raiz nao e objeto'; return $r }
    $pDef = Get-PropriedadeExata $obj 'deferred'
    $pRea = Get-PropriedadeExata $obj 'reason'
    if ($pDef -and ($pDef.Value -is [bool]) -and $pDef.Value -and $pRea -and ($pRea.Value -is [string]) -and $pRea.Value.Trim($ws).Length -gt 0) {
        $r.Classe = 'placeholder'; $r.Reason = $pRea.Value
        $pDec = Get-PropriedadeExata $obj 'decision'
        if ($pDec -and ($pDec.Value -is [string]) -and $pDec.Value.Trim($ws).Length -gt 0) { $r.Decision = $pDec.Value }
        return $r
    }
    $pFin = Get-PropriedadeExata $obj 'findings'
    if (-not $pFin) { $r.Motivo = 'sem findings nem placeholder'; return $r }
    if ($pFin.Value -isnot [string]) { $r.Motivo = 'findings nao e string'; return $r }
    if ($pFin.Value.Trim($ws).Length -eq 0) { $r.Motivo = 'findings vazio'; return $r }
    $r.Classe = 'review'
    return $r
}

function Add-LinhaDeferido {
    param([string]$ReviewDir, [string]$Camada, [string]$Repo, [string]$Decision, [string]$Reason)
    $linha = [ordered]@{
        timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        camada    = $Camada
        repo      = $Repo
        decision  = $Decision
        reason    = $Reason
    } | ConvertTo-Json -Compress
    [IO.File]::AppendAllText((Join-Path $ReviewDir 'deferidos.log'), $linha + "`n", (New-Object System.Text.UTF8Encoding($false)))
}
```

  Não use `Get-Content` aqui (`hooks-leitura-utf8` exigiria `-Encoding UTF8`).

- [ ] **Step 5: Caminhos de decisão no `pre-commit-check.ps1`.** Logo depois de `Write-BlockContext` (linha 95) adicione:

```powershell
    $recusado = $null
    function Write-Recusado {
        if ($recusado) { [Console]::Error.WriteLine("  recusado: $recusado") }
    }
```

  Substitua o bloco `try { ... } catch { }` do hash (linhas 152-173) por:

```powershell
    try {
        $hashHex = $null
        $tmpDiff = [System.IO.Path]::GetTempFileName()
        try {
            git -C $repoRoot diff HEAD --output=$tmpDiff 2>$null | Out-Null
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $fs  = [IO.File]::OpenRead($tmpDiff)
            try { $hashHex = ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-','').ToLower().Substring(0,12) }
            finally { $fs.Dispose() }
        } finally { Remove-Item $tmpDiff -Force -ErrorAction SilentlyContinue }
        # Hash do conteudo VAZIO (e3b0c44298fc) = sem hash: repo sem commit ou sem mudanca. Um
        # d-e3b0c44298fc.jsonl liberaria por 24 h qualquer diff de repo sem commit (emenda FR-016).
        if ($hashHex -and $hashHex -ne 'e3b0c44298fc') {
            $porHash = Join-Path $reviewDir "d-$hashHex.jsonl"
            if (Test-Path -LiteralPath $porHash) {
                $idade = (Get-Date) - (Get-Item -LiteralPath $porHash).LastWriteTime
                # >24 h: ignorado SEM ler (FR-016).
                if ($idade.TotalHours -le 24) {
                    $cHash = Get-ClasseMarcador -Caminho $porHash
                    if ($cHash.Classe -eq 'review') { exit 0 }
                    $motivoHash = $cHash.Motivo
                    if ($cHash.Classe -eq 'placeholder') { $motivoHash = 'placeholder nao libera por hash' }
                    $recusado = "d-$hashHex.jsonl recusado: $motivoHash"
                }
            }
        }
    } catch { }
```

  Acrescente `Write-Recusado` depois de `Write-BlockContext -searched $reviewDir` nos dois BLOCKs do `latest` (vazia; mais de 5 min). Troque `# Review fresco -> libera` + `exit 0` (linhas 200-201) por:

```powershell
    # <=5 min: agora o conteudo decide (FR-017).
    $cLatest = Get-ClasseMarcador -Caminho $latest.FullName
    if ($cLatest.Classe -eq 'review') { exit 0 }
    if ($cLatest.Classe -eq 'placeholder') {
        [Console]::Error.WriteLine("[percus:hook pre-commit] AVISO: commit SEM review real -- liberado por placeholder deferido ($($latest.Name), decision=$($cLatest.Decision)). Registre a review Cross-Claude com registrar-review.")
        try { Add-LinhaDeferido -ReviewDir $reviewDir -Camada 'pretooluse' -Repo $repoRoot -Decision $cLatest.Decision -Reason $cLatest.Reason } catch { }
        exit 0
    }
    [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: marcador $($latest.Name) invalido: $($cLatest.Motivo)")
    Write-BlockContext -searched $reviewDir
    Write-Recusado
    [Console]::Error.WriteLine("Rode /percus-review:review de novo antes de commitar (R11).")
    exit 2
```

  No `catch` final: `[Console]::Error.WriteLine("[percus:hook pre-commit] WARN: hook crashed, allowing commit. Error: $_")` no lugar do `Write-Host`.
  Nota de escopo: tudo roda no escopo de script (o `try` não cria escopo), então `Write-Recusado` enxerga `$recusado` por escopo dinâmico. Não mova a atribuição para dentro de função; o teste `hash|*` exige a linha `recusado`.

- [ ] **Step 6: Bloco awk nos dois `.sh`.** Texto EXATO, em coluna 0; no `pre-commit-check.sh` logo após `set +e` (linha 8), no template logo após `set -u` (linha 20, dentro do BEGIN):

```sh
# >>> percus-classifica-marcador (copia IDENTICA em hooks/pre-commit-check.sh e git-hooks/pre-commit.template.sh)
# Classifica .deepseek/reviews/*.jsonl sem jq: o hook git nativo nao pode depender dele (FR-018).
# Saida: linha 1 = review|placeholder|invalido; linha 2 = motivo (invalido) ou decision
# (placeholder); linha 3 = reason (placeholder, conteudo JSON-escapado cru). Ordem e textos sao
# contrato com Get-ClasseMarcador em pre-commit-check.ps1 -- mude os tres juntos.
# Programa em heredoc dentro de FUNCAO (heredoc dentro de $(...) parseia mal em bash antigo) e
# passado por tr -d CR (o cache do plugin chega com CRLF).
percus_awk_classifica() {
cat <<'PERCUS_AWK_FIM'
function ws(   c) { while (p <= n) { c = substr(s, p, 1); if (c == " " || c == "\t" || c == "\n" || c == "\r") p++; else break } }
function pstr(   c, st, blank, h) {
  if (substr(s, p, 1) != "\"") return 0
  p++; st = p; blank = 1
  while (p <= n) {
    c = substr(s, p, 1)
    if (c == "\"") { SRAW = substr(s, st, p - st); SBLANK = blank; p++; return 1 }
    if (c == "\\") {
      c = substr(s, p + 1, 1)
      if (c == "n" || c == "t" || c == "r") { p += 2; continue }
      if (c == "\"" || c == "\\" || c == "/" || c == "b" || c == "f") { blank = 0; p += 2; continue }
      if (c == "u") {
        h = tolower(substr(s, p + 2, 4))
        if (h !~ /^[0-9a-f][0-9a-f][0-9a-f][0-9a-f]$/) return 0
        if (h != "0020" && h != "0009" && h != "000a" && h != "000d") blank = 0
        p += 6; continue
      }
      return 0
    }
    if (c != " " && c != "\t" && c != "\n" && c != "\r") blank = 0
    p++
  }
  return 0
}
function pnum(   st, c, tok) {
  st = p
  while (p <= n) { c = substr(s, p, 1); if (index("+-.eE0123456789", c) > 0) p++; else break }
  tok = substr(s, st, p - st)
  if (tok !~ /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$/) return 0
  VTYPE = "number"; return 1
}
function parr(depth,   c) {
  p++; ws()
  if (substr(s, p, 1) == "]") { p++; VTYPE = "array"; return 1 }
  while (1) {
    if (!pval(depth + 1)) return 0
    ws(); c = substr(s, p, 1)
    if (c == ",") { p++; continue }
    if (c == "]") { p++; VTYPE = "array"; return 1 }
    return 0
  }
}
function pobj(depth,   c, k) {
  p++; ws()
  if (substr(s, p, 1) == "}") { p++; VTYPE = "object"; return 1 }
  while (1) {
    ws(); if (!pstr()) return 0
    k = SRAW
    ws(); if (substr(s, p, 1) != ":") return 0
    p++
    if (!pval(depth + 1)) return 0
    if (depth == 0) {
      if (k == "findings") { FT = VTYPE; if (VTYPE == "string") FB = SBLANK }
      if (k == "deferred") { DT = VTYPE }
      if (k == "reason") { RT = VTYPE; if (VTYPE == "string") { RB = SBLANK; RR = SRAW } }
      if (k == "decision") { ET = VTYPE; if (VTYPE == "string") { EB = SBLANK; ER = SRAW } }
    }
    ws(); c = substr(s, p, 1)
    if (c == ",") { p++; continue }
    if (c == "}") { p++; VTYPE = "object"; return 1 }
    return 0
  }
}
function pval(depth,   c) {
  ws(); c = substr(s, p, 1)
  if (c == "{") return pobj(depth)
  if (c == "[") return parr(depth)
  if (c == "\"") { if (!pstr()) return 0; VTYPE = "string"; return 1 }
  if (substr(s, p, 4) == "true") { p += 4; VTYPE = "true"; return 1 }
  if (substr(s, p, 5) == "false") { p += 5; VTYPE = "false"; return 1 }
  if (substr(s, p, 4) == "null") { p += 4; VTYPE = "null"; return 1 }
  if (c == "-" || (c >= "0" && c <= "9")) return pnum()
  return 0
}
{ s = s $0 "\n" }
END {
  if (substr(s, 1, 3) == "\357\273\277") s = substr(s, 4)
  n = length(s); p = 1; ws()
  if (p > n) { print "invalido"; print "vazio"; exit }
  if (!pval(0)) { print "invalido"; print "nao e JSON"; exit }
  ws()
  if (p <= n) { print "invalido"; print "nao e JSON"; exit }
  if (VTYPE != "object") { print "invalido"; print "raiz nao e objeto"; exit }
  if (DT == "true" && RT == "string" && RB == 0) {
    gsub(/[\001-\037]/, " ", RR); gsub(/[\001-\037]/, " ", ER)
    print "placeholder"
    if (ET == "string" && EB == 0) print ER; else print "desconhecida"
    print RR
    exit
  }
  if (FT == "") { print "invalido"; print "sem findings nem placeholder"; exit }
  if (FT != "string") { print "invalido"; print "findings nao e string"; exit }
  if (FB == 1) { print "invalido"; print "findings vazio"; exit }
  print "review"
}
PERCUS_AWK_FIM
}
percus_classifica_marcador() {
    _pcm_tam=$(wc -c < "$1" 2>/dev/null | tr -d ' \r')
    if [ -z "$_pcm_tam" ]; then printf 'invalido\nilegivel\n'; return 0; fi
    if [ "$_pcm_tam" -gt 262144 ]; then printf 'invalido\nacima do teto (256 KB)\n'; return 0; fi
    LC_ALL=C awk "$(percus_awk_classifica | tr -d '\r')" "$1"
}
percus_json_escapa() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}
# <<< percus-classifica-marcador
```

  Armadilhas: `LC_ALL=C` (bytes; BOM por octal); locais das funções awk declarados como parâmetros extras (recursão global clobber); nenhuma aspa simples no programa awk; terminador em coluna 0 (não `<<-`); nada de `length(array)`, `gensub` ou outra extensão gawk.

- [ ] **Step 7: `pre-commit-check.sh` usa o bloco.** Troque o bloco do hash (linhas 108-129) por:

```sh
RECUSADO=""
if command -v sha256sum >/dev/null 2>&1; then
  TMP_DIFF="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-diff-$$")"
  git -C "$REPO_ROOT" diff HEAD --output="$TMP_DIFF" 2>/dev/null || true
  DIFF_HASH=$(sha256sum "$TMP_DIFF" 2>/dev/null | cut -c1-12)
  rm -f "$TMP_DIFF"
  POR_HASH="$REVIEW_DIR/d-$DIFF_HASH.jsonl"
  # e3b0c44298fc = hash do conteudo vazio = sem hash (emenda FR-016).
  if [ -n "$DIFF_HASH" ] && [ "$DIFF_HASH" != "e3b0c44298fc" ] && [ -f "$POR_HASH" ]; then
    H_NOW=$(date +%s)
    H_MTIME=$(stat -c %Y "$POR_HASH" 2>/dev/null || stat -f %m "$POR_HASH" 2>/dev/null)
    if [ -n "$H_MTIME" ] && [ $((H_NOW - H_MTIME)) -le 86400 ]; then
      _CLS=$(percus_classifica_marcador "$POR_HASH")
      _CLASSE=$(printf '%s\n' "$_CLS" | sed -n 1p)
      if [ "$_CLASSE" = "review" ]; then exit 0; fi
      if [ "$_CLASSE" = "placeholder" ]; then _MOT="placeholder nao libera por hash"; else _MOT=$(printf '%s\n' "$_CLS" | sed -n 2p); fi
      RECUSADO="d-$DIFF_HASH.jsonl recusado: $_MOT"
    fi
  fi
fi
recusado_context() {
  [ -n "$RECUSADO" ] && echo "  recusado: $RECUSADO" >&2
  return 0
}
```

  Acrescente `recusado_context` após `block_context "$REVIEW_DIR"` nos BLOCKs de `latest` (vazia e `AGE -gt 300`). Troque o `exit 0` final (linha 155) por:

```sh
_CLS=$(percus_classifica_marcador "$LATEST")
_CLASSE=$(printf '%s\n' "$_CLS" | sed -n 1p)
if [ "$_CLASSE" = "review" ]; then exit 0; fi
if [ "$_CLASSE" = "placeholder" ]; then
  _DEC=$(printf '%s\n' "$_CLS" | sed -n 2p)
  _REA=$(printf '%s\n' "$_CLS" | sed -n 3p)
  echo "[percus:hook pre-commit] AVISO: commit SEM review real -- liberado por placeholder deferido ($(basename "$LATEST"), decision=$_DEC). Registre a review Cross-Claude com registrar-review." >&2
  { printf '{"timestamp":"%s","camada":"pretooluse","repo":"%s","decision":"%s","reason":"%s"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(percus_json_escapa "$REPO_ROOT")" "$_DEC" "$_REA" >> "$REVIEW_DIR/deferidos.log"; } 2>/dev/null || true
  exit 0
fi
echo "[percus:hook pre-commit] BLOCK: marcador $(basename "$LATEST") invalido: $(printf '%s\n' "$_CLS" | sed -n 2p)" >&2
block_context "$REVIEW_DIR"
recusado_context
echo "Rode /percus-review:review de novo (R11)." >&2
exit 2
```

- [ ] **Step 8: Template do hook git.** Dentro de `if ! git diff --cached --quiet`, troque o bloco do hash (linhas 43-55) pela mesma lógica do Step 7 (sem `-C`, pois roda na raiz; `RECUSADO`, regra `e3b0c44298fc`, `exit 0` só para `review`). Nos BLOCKs `pasta ... vazia` e `tem $AGE_MIN min (max 5)` acrescente `[ -n "$RECUSADO" ] && >&2 echo "  recusado: $RECUSADO"` antes do `exit 1`. Depois do `if [ -z "$MTIME" ] ... fi` (antes do `fi` do `if ! git diff --cached`), insira:

```sh
        _CLS=$(percus_classifica_marcador "$LATEST")
        _CLASSE=$(printf '%s\n' "$_CLS" | sed -n 1p)
        if [ "$_CLASSE" = "placeholder" ]; then
            _DEC=$(printf '%s\n' "$_CLS" | sed -n 2p)
            _REA=$(printf '%s\n' "$_CLS" | sed -n 3p)
            >&2 echo "[percus:hook pre-commit native] AVISO: commit SEM review real -- liberado por placeholder deferido ($(basename "$LATEST"), decision=$_DEC). Registre a review Cross-Claude com registrar-review."
            _TOP=$(git rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
            { printf '{"timestamp":"%s","camada":"git-hook","repo":"%s","decision":"%s","reason":"%s"}\n' \
                "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(percus_json_escapa "$_TOP")" "$_DEC" "$_REA" >> "$REVIEW_DIR/deferidos.log"; } 2>/dev/null || true
        elif [ "$_CLASSE" != "review" ]; then
            >&2 echo "[percus:hook pre-commit native] BLOCK: marcador $(basename "$LATEST") invalido: $(printf '%s\n' "$_CLS" | sed -n 2p)"
            [ -n "$RECUSADO" ] && >&2 echo "  recusado: $RECUSADO"
            >&2 echo "Rode /percus-review:review de novo antes de commitar (R11)."
            exit 1
        fi
```

  Atualize o comentário da linha 10: `Espelha logica de hooks/pre-commit-check.ps1 (hash 24 h, TTL 5 min, classificacao do marcador, escape PERCUS_HOOKS_DISABLED).` Mantenha intactas as linhas `=== PERCUS-MERGED-HOOK BEGIN/END ===`.

- [ ] **Step 9: Rode a task** (ferramenta PowerShell, primeiro plano, um arquivo por vez):
  - `Invoke-Pester -Path '.\plugin\percus-review\tests\pre-commit-marcador-classificacao.tests.ps1' -Output Detailed` → PASS (74 testes).
  - `pre-commit-hash-validity.tests.ps1` → 5 PASS; `git diff --stat -- plugin/percus-review/tests/pre-commit-hash-validity.tests.ps1` vazio (SC-002).
  - `pre-commit-path-resolution.tests.ps1`, `review-politica-risco.tests.ps1`, `hardening-2026-05-19.tests.ps1`, `ps51-compat.tests.ps1`, `hooks-leitura-utf8.tests.ps1`, `pester-blocos-unicos.tests.ps1` → PASS.

- [ ] **Step 10: Formato.** BOM (`head -c3 <arq> | od -An -tx1` = `ef bb bf`) em `pre-commit-check.ps1`, `_resolver-bash.ps1` e no `.tests.ps1` novo. Ferramenta Bash: `git add -- plugin/percus-review/hooks/pre-commit-check.ps1 plugin/percus-review/hooks/pre-commit-check.sh plugin/percus-review/git-hooks/pre-commit.template.sh plugin/percus-review/tests/_resolver-bash.ps1 plugin/percus-review/tests/pre-commit-marcador-classificacao.tests.ps1`; depois `git ls-files --eol -- plugin/percus-review/hooks/pre-commit-check.sh plugin/percus-review/git-hooks/pre-commit.template.sh` (esperado `i/-text` e `i/lf`). Linhas adicionadas em ASCII — ferramenta PowerShell:

```powershell
$d = git diff --cached -U0 -- 'plugin/percus-review/hooks/pre-commit-check.sh' 'plugin/percus-review/git-hooks/pre-commit.template.sh'
@($d | Where-Object { $_ -match '^\+' -and $_ -match '[^\x09\x20-\x7E]' })
```
  Esperado: vazio.

- [ ] **Step 11: R11 + commit.** `& '.\plugin\percus-review\scripts\deepseek-review.ps1'`, triagem, commit (forma do Global Constraints) com assunto `feat(hook): marcador R11 so libera por conteudo de review; hash vazio nao conta` e os 5 arquivos do Step 10.

---

### Task 2: Cliente DeepSeek `.ps1` — timeout, 1 retry, exits 1/3/4, corpo mascarado

**Files:**
- Create: `plugin/percus-review/tests/_servidor-http-falso.ps1`
- Create: `plugin/percus-review/tests/deepseek-review-retry.tests.ps1`
- Modify: `plugin/percus-review/scripts/deepseek-review.ps1:18-29` (params), `:95-98` (resolução de config), `:200-211` (chamada), `:317` (hash vazio)
- Test (inalterado, deve seguir verde): `plugin/percus-review/tests/provider-limites.tests.ps1` (âncoras `Get-StatusResposta` antes de `Move-Item -Path $logTmp`, `Status -ne "ok"`, `exit 3`, `-ne "stop"`), `faixa-regras-derivada.tests.ps1`

**Interfaces:**
- Consumes: `tests/_resolver-bash.ps1` → `Set-EnvTemporario`, `Restore-EnvTemporario` (Task 1).
- Produces: `tests/_servidor-http-falso.ps1` com `New-RespostaFalsa([int]$Status = 200, [string]$Corpo = '', [switch]$Pendurar)` → `[hashtable]`; `Start-ServidorFalso([object[]]$Roteiro)` → `[pscustomobject]@{ Porta; Url; Processo; Dir }` (`Url` = `http://127.0.0.1:<porta>/v1/chat/completions`; o roteiro é consumido em ordem, o último item se repete); `Get-ContagemServidorFalso($Servidor)` → `[int]` (conexões aceitas); `Stop-ServidorFalso($Servidor)`. Script: `deepseek-review.ps1 [-TimeoutSec <int>=180] [-BackoffSec <int>=5]` além dos existentes; env `PERCUS_DEEPSEEK_TIMEOUT_S`, `PERCUS_DEEPSEEK_BACKOFF_S`; exits 0/1/2/3/4 do contrato.

- [ ] **Step 1: Servidor falso** — `tests/_servidor-http-falso.ps1` (UTF-8 com BOM). Processo SEPARADO (o cliente é outro processo; um listener no processo do Pester ficaria parado enquanto o `& pwsh` do teste bloqueia). TcpListener em `127.0.0.1:0` (HttpListener exige urlacl fora de `localhost`). A porta sai por arquivo:

```powershell
#requires -Version 5.1
# Servidor HTTP roteirizado para testar retry/timeout sem rede real. Nao e *.tests.ps1: dot-source.
# Cada conexao aceita consome o proximo item do roteiro (o ultimo se repete) e incrementa
# contador.txt -- e assim que os testes afirmam "exatamente 1 requisicao" ou "2 tentativas".
# Item com pendurar=true aceita o TCP, le o pedido e NUNCA responde (o caso que travava 4 min).

function New-RespostaFalsa {
    param([int]$Status = 200, [string]$Corpo = '', [switch]$Pendurar)
    return @{ status = $Status; corpo = $Corpo; pendurar = [bool]$Pendurar }
}

function Start-ServidorFalso {
    param([object[]]$Roteiro)
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-srv-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $u8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $dir 'roteiro.json'), (ConvertTo-Json -InputObject @($Roteiro) -Depth 5), $u8)
    $servidor = @'
param([string]$Dir)
$u8 = New-Object System.Text.UTF8Encoding($false)
$roteiro = @([IO.File]::ReadAllText((Join-Path $Dir 'roteiro.json'), $u8) | ConvertFrom-Json)
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$porta = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
[IO.File]::WriteAllText((Join-Path $Dir 'porta.tmp'), "$porta", $u8)
Move-Item -LiteralPath (Join-Path $Dir 'porta.tmp') -Destination (Join-Path $Dir 'porta.txt') -Force
$pendurados = New-Object System.Collections.ArrayList
$n = 0
while ($true) {
    $cli = $listener.AcceptTcpClient()
    $idx = [Math]::Min($n, $roteiro.Count - 1)
    $item = $roteiro[$idx]
    $n++
    [IO.File]::WriteAllText((Join-Path $Dir 'contador.tmp'), "$n", $u8)
    Move-Item -LiteralPath (Join-Path $Dir 'contador.tmp') -Destination (Join-Path $Dir 'contador.txt') -Force
    try {
        $s = $cli.GetStream()
        $s.ReadTimeout = 5000
        $buf = New-Object byte[] 65536
        $ms = New-Object System.IO.MemoryStream
        $tam = -1; $fimCab = -1
        while ($true) {
            $lidos = $s.Read($buf, 0, $buf.Length)
            if ($lidos -le 0) { break }
            $ms.Write($buf, 0, $lidos)
            $txt = [Text.Encoding]::ASCII.GetString($ms.ToArray())
            if ($fimCab -lt 0) { $fimCab = $txt.IndexOf("`r`n`r`n") }
            if ($fimCab -ge 0) {
                if ($tam -lt 0) {
                    $m = [regex]::Match($txt.Substring(0, $fimCab), '(?im)^Content-Length:\s*(\d+)')
                    if ($m.Success) { $tam = [int]$m.Groups[1].Value } else { $tam = 0 }
                }
                if ($ms.Length - ($fimCab + 4) -ge $tam) { break }
            }
        }
        if ($item.pendurar) { [void]$pendurados.Add($cli); continue }
        $corpo = $u8.GetBytes([string]$item.corpo)
        $cab = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $($item.status) Falso`r`nContent-Type: application/json`r`nContent-Length: $($corpo.Length)`r`nConnection: close`r`n`r`n")
        $s.Write($cab, 0, $cab.Length)
        if ($corpo.Length -gt 0) { $s.Write($corpo, 0, $corpo.Length) }
        $s.Flush()
        $cli.Close()
    } catch {
        try { $cli.Close() } catch { }
    }
}
'@
    $script = Join-Path $dir 'servidor.ps1'
    [IO.File]::WriteAllText($script, $servidor, (New-Object System.Text.UTF8Encoding($true)))
    $exe = (Get-Process -Id $PID).Path
    # Aspas manuais: Start-Process junta ArgumentList com espaco sem citar.
    $proc = Start-Process -FilePath $exe -ArgumentList @('-NoProfile', '-File', ('"' + $script + '"'), '-Dir', ('"' + $dir + '"')) -PassThru -WindowStyle Hidden
    $arqPorta = Join-Path $dir 'porta.txt'
    $limite = (Get-Date).AddSeconds(20)
    while (-not (Test-Path -LiteralPath $arqPorta) -and (Get-Date) -lt $limite) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path -LiteralPath $arqPorta)) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        throw "servidor falso nao subiu em 20 s ($dir)"
    }
    $porta = [int]([IO.File]::ReadAllText($arqPorta).Trim())
    return [pscustomobject]@{ Porta = $porta; Url = "http://127.0.0.1:$porta/v1/chat/completions"; Processo = $proc; Dir = $dir }
}

function Get-ContagemServidorFalso {
    param($Servidor)
    $arq = Join-Path $Servidor.Dir 'contador.txt'
    if (-not (Test-Path -LiteralPath $arq)) { return 0 }
    return [int]([IO.File]::ReadAllText($arq).Trim())
}

function Stop-ServidorFalso {
    param($Servidor)
    if (-not $Servidor) { return }
    Stop-Process -Id $Servidor.Processo.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 200
    Remove-Item -Recurse -Force $Servidor.Dir -ErrorAction SilentlyContinue
}
```

- [ ] **Step 2: Teste que falha** — `tests/deepseek-review-retry.tests.ps1` (UTF-8 com BOM):

```powershell
#requires -Version 5.1
# FR-001..006 / SC-003..005 no deepseek-review.ps1. Medido 2026-09-14: sem timeout nem retry, 3
# falhas + 1 travamento de 4 min numa tarde; 2xx sem choices morria em "Cannot index into a null
# array" e descartava o corpo. Aqui o script roda INTEIRO contra um servidor falso local.

Describe "deepseek-review.ps1 -- timeout, retry e provedor indisponivel" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        . (Join-Path $PSScriptRoot '_servidor-http-falso.ps1')
        $script:cliente = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts') 'deepseek-review.ps1'
        $script:chave = 'sk-teste-FALSA-0123456789abcdef'
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-dsr-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $script:ok = '{"choices":[{"message":{"content":"Sem findings criticos."},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1}}'
        $script:semChoices5k = '{"eco":"' + $script:chave + '","pad":"' + ('x' * 5000) + '"}'

        function New-RepoCliente {
            param([switch]$SemCommit)
            $dir = Join-Path $script:tmpBase ("r-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Push-Location $dir
            try {
                & git init -q . 2>$null; & git config user.email t@t.t 2>$null; & git config user.name t 2>$null
                [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "original`n", $script:u8)
                & git add a.ps1 2>$null
                if (-not $SemCommit) { & git @(('com' + 'mit'), '-q', '-m', 'base', '--no-verify') 2>$null }
                [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "alterado`n", $script:u8)
                if ($SemCommit) { & git add a.ps1 2>$null }
            } finally { Pop-Location }
            return $dir
        }

        function Invoke-Cliente {
            param([string]$Repo, [string]$Url, [string[]]$ArgsExtra = @(), [hashtable]$Env = @{})
            $envTotal = @{ DEEPSEEK_API_KEY = $script:chave; PERCUS_DEEPSEEK_TIMEOUT_S = $null; PERCUS_DEEPSEEK_BACKOFF_S = $null }
            foreach ($k in $Env.Keys) { $envTotal[$k] = $Env[$k] }
            $antigos = Set-EnvTemporario $envTotal
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $sw = [Diagnostics.Stopwatch]::StartNew()
            Push-Location $Repo
            try {
                $out = & pwsh -NoProfile -File $script:cliente -Endpoint $Url @ArgsExtra 2>$err
                $code = $LASTEXITCODE
            } finally { Pop-Location; $sw.Stop(); Restore-EnvTemporario $antigos }
            $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            $rev = Join-Path (Join-Path $Repo '.deepseek') 'reviews'
            $marcadores = @()
            if (Test-Path $rev) { $marcadores = @(Get-ChildItem $rev -Filter '*.jsonl' | ForEach-Object { $_.Name }) }
            return [pscustomobject]@{ Code = $code; Err = $texto; Out = ($out -join "`n"); Segundos = $sw.Elapsed.TotalSeconds; Marcadores = $marcadores; Rev = $rev }
        }

        function Invoke-ComRoteiro {
            param([object[]]$Roteiro, [string[]]$ArgsExtra = @('-TimeoutSec', '2', '-BackoffSec', '1'), [hashtable]$Env = @{}, [switch]$SemCommit)
            $srv = Start-ServidorFalso -Roteiro $Roteiro
            try {
                $repo = New-RepoCliente -SemCommit:$SemCommit
                $r = Invoke-Cliente -Repo $repo -Url $srv.Url -ArgsExtra $ArgsExtra -Env $Env
                $r | Add-Member -NotePropertyName Requisicoes -NotePropertyValue (Get-ContagemServidorFalso $srv)
                return $r
            } finally { Stop-ServidorFalso $srv }
        }
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "200 com choices: 1 requisicao, exit 0, latest.jsonl e d-<hash>.jsonl gravados" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok))
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        $r.Marcadores | Should -Contain 'latest.jsonl'
        @($r.Marcadores | Where-Object { $_ -match '^d-[0-9a-f]{12}\.jsonl$' }).Count | Should -Be 1
    }

    It "1a falha por <Nome>, 2a responde: exit 0, 2 requisicoes, aviso de retry, tempo extra <= backoff+timeout+1s" -ForEach @(
        @{ Nome = 'HTTP 429';        Primeira = @{ status = 429; corpo = '{"error":{"message":"rate"}}'; pendurar = $false }; Causa = 'HTTP 429' }
        @{ Nome = 'HTTP 503';        Primeira = @{ status = 503; corpo = '{"error":{"message":"boom"}}'; pendurar = $false }; Causa = 'HTTP 503' }
        @{ Nome = '200 sem choices'; Primeira = @{ status = 200; corpo = '{"id":"x"}'; pendurar = $false }; Causa = 'HTTP 200 sem choices' }
        @{ Nome = '200 corpo vazio'; Primeira = @{ status = 200; corpo = ''; pendurar = $false }; Causa = 'HTTP 200 com corpo vazio' }
        @{ Nome = 'timeout';         Primeira = @{ status = 200; corpo = ''; pendurar = $true }; Causa = 'timeout de 2s' }
    ) {
        $base = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok))
        $r = Invoke-ComRoteiro -Roteiro @($Primeira, (New-RespostaFalsa -Corpo $script:ok))
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 2
        $r.Err | Should -Match ([regex]::Escape("tentativa 1 falhou: ") + '.*' + [regex]::Escape($Causa))
        $r.Err | Should -Match 'Nova tentativa em 1s\.'
        $r.Marcadores | Should -Contain 'latest.jsonl'
        ($r.Segundos - $base.Segundos) | Should -BeLessOrEqual (1 + 2 + 1) -Because "SC-004"
    }

    It "5xx nas 2 tentativas: exit 4, 2 requisicoes, nenhum marcador" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Status 500 -Corpo '{"error":"x"}'))
        $r.Code | Should -Be 4 -Because $r.Err
        $r.Requisicoes | Should -Be 2
        $r.Err | Should -Match 'PROVEDOR INDISPONIVEL apos retry: HTTP 500'
        @($r.Marcadores).Count | Should -Be 0
    }

    It "SC-003: 2xx sem choices (5 KB com a chave) nas 2 tentativas -> 2000 caracteres mascarados, exit 4" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:semChoices5k))
        $trecho = $script:semChoices5k.Replace($script:chave, '***').Substring(0, 2000)
        $r.Code | Should -Be 4 -Because $r.Err
        $r.Requisicoes | Should -Be 2
        $r.Err.Contains($trecho) | Should -BeTrue -Because "stderr tem de mostrar exatamente os primeiros 2000 caracteres"
        $r.Err.Contains($trecho + 'x') | Should -BeFalse -Because "nem um caractere a mais"
        $r.Err.Contains($script:chave) | Should -BeFalse
        $ue = [IO.File]::ReadAllText((Join-Path $r.Rev 'ultimo-erro.txt'), $script:u8)
        $ue | Should -Match '^timestamp=\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\nstatus=200\n---\n'
        $ue.Substring($ue.IndexOf("---`n") + 4) | Should -BeExactly $trecho
        @($r.Marcadores).Count | Should -Be 0
    }

    It "HTTP <Status>: exatamente 1 requisicao, exit 1, nenhum marcador" -ForEach @(@{ Status = 401 }, @{ Status = 404 }) {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Status $Status -Corpo ('{"error":"chave ' + $script:chave + '"}')))
        $r.Code | Should -Be 1 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        $r.Err | Should -Match "HTTP $Status -- nao recuperavel"
        $r.Err.Contains($script:chave) | Should -BeFalse
        @($r.Marcadores).Count | Should -Be 0
    }

    It "5xx e depois 401: para no 401 com exit 1" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Status 502 -Corpo '{}'), (New-RespostaFalsa -Status 401 -Corpo '{}'))
        $r.Code | Should -Be 1 -Because $r.Err
        $r.Requisicoes | Should -Be 2
    }

    It "SC-005: servidor que nunca responde, timeout 2 s, backoff 1 s -> exit 4 em ate 6 s alem de uma chamada normal" {
        $base = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok))
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Pendurar))
        $r.Code | Should -Be 4 -Because $r.Err
        $r.Requisicoes | Should -Be 2
        ($r.Segundos - $base.Segundos) | Should -BeLessOrEqual 6
        @($r.Marcadores).Count | Should -Be 0
    }

    It "choices com content vazio ou finish_reason=<Fim>: exit 3 SEM retry" -ForEach @(
        @{ Fim = 'stop';   Corpo = '{"choices":[{"message":{"content":""},"finish_reason":"stop"}]}' }
        @{ Fim = 'length'; Corpo = '{"choices":[{"message":{"content":"meia frase"},"finish_reason":"length"}]}' }
    ) {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $Corpo))
        $r.Code | Should -Be 3 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        @($r.Marcadores).Count | Should -Be 0
    }

    It "precedencia <Nome>" -ForEach @(
        @{ Nome = 'padrao';           ArgsCaso = @();                                   Env = @{};                                                              Esperado = 'timeout=180s backoff=5s' }
        @{ Nome = 'env';              ArgsCaso = @();                                   Env = @{ PERCUS_DEEPSEEK_TIMEOUT_S = '7'; PERCUS_DEEPSEEK_BACKOFF_S = '3' }; Esperado = 'timeout=7s backoff=3s' }
        @{ Nome = 'parametro > env';  ArgsCaso = @('-TimeoutSec', '2', '-BackoffSec', '1'); Env = @{ PERCUS_DEEPSEEK_TIMEOUT_S = '7'; PERCUS_DEEPSEEK_BACKOFF_S = '3' }; Esperado = 'timeout=2s backoff=1s' }
        @{ Nome = 'env invalida';     ArgsCaso = @();                                   Env = @{ PERCUS_DEEPSEEK_TIMEOUT_S = 'abc' };                            Esperado = 'timeout=180s backoff=5s' }
    ) {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -ArgsExtra $ArgsCaso -Env $Env
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Err | Should -Match ([regex]::Escape("[deepseek-review] $Esperado"))
        if ($Nome -eq 'env invalida') { $r.Err | Should -Match "WARN: PERCUS_DEEPSEEK_TIMEOUT_S='abc' invalido" }
    }

    It "-TimeoutSec 0: exit 2 sem chamar a API" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -ArgsExtra @('-TimeoutSec', '0')
        $r.Code | Should -Be 2
        $r.Requisicoes | Should -Be 0
    }

    It "emenda FR-011: repo sem commit (diff HEAD vazio) grava latest.jsonl mas NUNCA d-e3b0c44298fc.jsonl" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -SemCommit
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Marcadores | Should -Contain 'latest.jsonl'
        @($r.Marcadores | Where-Object { $_ -like 'd-*' }).Count | Should -Be 0
    }
}
```

- [ ] **Step 3: Rode e confirme a falha.** `Invoke-Pester -Path '.\plugin\percus-review\tests\deepseek-review-retry.tests.ps1' -Output Detailed`. Esperado: o 1º It passa (se falhar, o servidor falso está errado — conserte o harness antes de seguir); os demais falham (sem retry, exit 1 em vez de 4, `-TimeoutSec` inexistente → erro de binding, `d-e3b0c44298fc.jsonl` gravado).

- [ ] **Step 4: Parâmetros e resolução de config.** No `param(...)` acrescente depois de `$Endpoint`:

```powershell
    # 2026-09-14 (FR-001/002): precedencia parametro > env > padrao. Sem valor padrao no param de
    # proposito: $PSBoundParameters diz se o chamador passou.
    [int]$TimeoutSec,
    [int]$BackoffSec
```

  (vírgula após a linha de `$Endpoint`). Nos dados de `-ForEach` do teste a chave chama `ArgsCaso`, não `Args`: `$args` é variável automática do PowerShell. Depois do bloco `if (-not $env:DEEPSEEK_API_KEY) { throw ... }` (linha 97), insira:

```powershell
# === TIMEOUT E BACKOFF (2026-09-14) ===
# Ate aqui a chamada nao tinha timeout: medido um travamento de 4 min que segurou uma onda de
# commits ~65 min. Parametro invalido e erro do chamador (exit 2); env invalida vira padrao com aviso.
function Get-InteiroDeEnv {
    param([string]$Nome, [int]$Padrao, [int]$Minimo)
    $valor = [Environment]::GetEnvironmentVariable($Nome)
    if ([string]::IsNullOrWhiteSpace($valor)) { return $Padrao }
    $n = 0
    if ([int]::TryParse($valor.Trim(), [ref]$n) -and $n -ge $Minimo) { return $n }
    [Console]::Error.WriteLine("[deepseek-review] WARN: $Nome='$valor' invalido -- usando padrao $Padrao.")
    return $Padrao
}
if ($PSBoundParameters.ContainsKey('TimeoutSec')) {
    if ($TimeoutSec -lt 1) { [Console]::Error.WriteLine("[deepseek-review] ERRO: -TimeoutSec precisa ser >= 1."); exit 2 }
    $timeoutEfetivo = $TimeoutSec
} else { $timeoutEfetivo = Get-InteiroDeEnv -Nome 'PERCUS_DEEPSEEK_TIMEOUT_S' -Padrao 180 -Minimo 1 }
if ($PSBoundParameters.ContainsKey('BackoffSec')) {
    if ($BackoffSec -lt 0) { [Console]::Error.WriteLine("[deepseek-review] ERRO: -BackoffSec precisa ser >= 0."); exit 2 }
    $backoffEfetivo = $BackoffSec
} else { $backoffEfetivo = Get-InteiroDeEnv -Nome 'PERCUS_DEEPSEEK_BACKOFF_S' -Padrao 5 -Minimo 0 }
```

- [ ] **Step 5: Chamada com retry.** Substitua as linhas 200-211 (`$headers = @{...}` até o `catch { ... exit 1 }`) por:

```powershell
# === CHAMADA COM TIMEOUT E EXATAMENTE 1 RETRY (2026-09-14, FR-001..005) ===
# HttpClient e nao Invoke-RestMethod: no 5.1 o IRM lanca em 4xx/5xx e o corpo se perde, e em 2xx sem
# choices a linha seguinte morria em "Cannot index into a null array" descartando o corpo (verbete
# deepseek-review-2xx-sem-choices-nao-grava-review). HttpClient devolve status e corpo nos dois
# runtimes, e o Timeout cobre conexao + leitura do corpo (ResponseContentRead e o padrao).
Add-Type -AssemblyName System.Net.Http
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

function Get-TrechoMascarado {
    # Mascara ANTES de cortar: cortar primeiro deixaria meia chave na borda dos 2000.
    param([string]$Corpo, [string]$Chave)
    $m = "$Corpo"
    if ($Chave) { $m = $m.Replace($Chave, '***') }
    if ($m.Length -gt 2000) { $m = $m.Substring(0, 2000) }
    return $m
}

function Write-UltimoErro {
    param([int]$Status, [string]$Trecho)
    try {
        $dir = Join-Path (Get-Location) '.deepseek\reviews'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $txt = "timestamp=" + [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ') + "`n" + "status=$Status`n---`n" + $Trecho
        [IO.File]::WriteAllText((Join-Path $dir 'ultimo-erro.txt'), $txt, (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        [Console]::Error.WriteLine("[deepseek-review] WARN: nao consegui gravar ultimo-erro.txt: $($_.Exception.Message)")
    }
}

function Invoke-TentativaDeepSeek {
    param([string]$Uri, [byte[]]$Corpo, [string]$Chave, [int]$Timeout)
    $cliente = New-Object System.Net.Http.HttpClient
    $cliente.Timeout = [TimeSpan]::FromSeconds($Timeout)
    try {
        $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $Uri)
        [void]$req.Headers.TryAddWithoutValidation('Authorization', "Bearer $Chave")
        # Virgula: passa o byte[] como UM argumento, nao como N argumentos.
        $conteudo = New-Object System.Net.Http.ByteArrayContent -ArgumentList (,$Corpo)
        [void]$conteudo.Headers.TryAddWithoutValidation('Content-Type', 'application/json; charset=utf-8')
        $req.Content = $conteudo
        $resp = $cliente.SendAsync($req).GetAwaiter().GetResult()
        $bytes = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        return @{ Rede = $false; Status = [int]$resp.StatusCode; Corpo = [Text.Encoding]::UTF8.GetString($bytes); Erro = '' }
    } catch {
        $e = $_.Exception
        while ($e.InnerException) { $e = $e.InnerException }
        $msg = $e.Message
        if ($e -is [System.Threading.Tasks.TaskCanceledException] -or $e -is [System.TimeoutException]) { $msg = "timeout de ${Timeout}s" }
        return @{ Rede = $true; Status = 0; Corpo = ''; Erro = $msg }
    } finally { $cliente.Dispose() }
}

function Get-VereditoTentativa {
    # @{ Veredito = 'ok'|'retry'|'fatal'; Causa; Resposta }
    param($T, [string]$Chave)
    if ($T.Rede) { return @{ Veredito = 'retry'; Causa = "erro de rede/timeout: $($T.Erro)"; Resposta = $null } }
    $s = $T.Status
    $obj = $null
    $temChoices = $false
    $corpoLimpo = "$($T.Corpo)".Trim()
    # Raiz pelo 1o caractere: pwsh 7 enumera array na raiz do ConvertFrom-Json.
    if ($corpoLimpo.StartsWith('{')) {
        try { $obj = ConvertFrom-Json -InputObject $T.Corpo -ErrorAction Stop } catch { $obj = $null }
        if ($obj -is [System.Management.Automation.PSCustomObject] -and $null -ne $obj.choices -and @($obj.choices).Count -gt 0) { $temChoices = $true }
    }
    if (-not $temChoices) {
        $trecho = Get-TrechoMascarado -Corpo $T.Corpo -Chave $Chave
        [Console]::Error.WriteLine("[deepseek-review] resposta sem choices (HTTP $s) -- primeiros 2000 caracteres do corpo:")
        [Console]::Error.WriteLine($trecho)
        Write-UltimoErro -Status $s -Trecho $trecho
    }
    if ($s -ge 200 -and $s -le 299) {
        if ($temChoices) { return @{ Veredito = 'ok'; Causa = ''; Resposta = $obj } }
        if ($corpoLimpo.Length -eq 0) { return @{ Veredito = 'retry'; Causa = "HTTP $s com corpo vazio"; Resposta = $null } }
        return @{ Veredito = 'retry'; Causa = "HTTP $s sem choices"; Resposta = $null }
    }
    if ($s -eq 429 -or ($s -ge 500 -and $s -le 599)) { return @{ Veredito = 'retry'; Causa = "HTTP $s"; Resposta = $null } }
    return @{ Veredito = 'fatal'; Causa = "HTTP $s"; Resposta = $null }
}

[Console]::Error.WriteLine("[deepseek-review] timeout=${timeoutEfetivo}s backoff=${backoffEfetivo}s")
$chaveApi = $env:DEEPSEEK_API_KEY
$av = Get-VereditoTentativa -T (Invoke-TentativaDeepSeek -Uri $Endpoint -Corpo $bodyBytes -Chave $chaveApi -Timeout $timeoutEfetivo) -Chave $chaveApi
if ($av.Veredito -eq 'retry') {
    [Console]::Error.WriteLine("[deepseek-review] tentativa 1 falhou: $($av.Causa.Replace($chaveApi, '***')). Nova tentativa em ${backoffEfetivo}s.")
    Start-Sleep -Seconds $backoffEfetivo
    $av = Get-VereditoTentativa -T (Invoke-TentativaDeepSeek -Uri $Endpoint -Corpo $bodyBytes -Chave $chaveApi -Timeout $timeoutEfetivo) -Chave $chaveApi
    if ($av.Veredito -eq 'retry') {
        [Console]::Error.WriteLine("[deepseek-review] PROVEDOR INDISPONIVEL apos retry: $($av.Causa.Replace($chaveApi, '***')). Nenhum marcador gravado (exit 4).")
        exit 4
    }
}
if ($av.Veredito -eq 'fatal') {
    [Console]::Error.WriteLine("[deepseek-review] ERRO: $($av.Causa) -- nao recuperavel, sem nova tentativa. Nenhum marcador gravado (exit 1).")
    exit 1
}
$response = $av.Resposta
$findings = $response.choices[0].message.content
```

  Armadilhas: não cite o nome da função classificadora compartilhada (`Get-StatusResposta`) em nenhum comentário ANTES do uso real — `provider-limites.tests.ps1` usa o primeiro `IndexOf` dela; o 5xx NÃO entra no 3 (3 é só "com choices mas inutilizável"); `exit` dentro de função não é usado (as saídas ficam no corpo do script).

- [ ] **Step 6: Hash vazio.** Linha 317: `if ($hashHex) {` → `if ($hashHex -and $hashHex -ne 'e3b0c44298fc') {`, e acrescente ao comentário acima: `# e3b0c44298fc = hash do arquivo VAZIO (repo sem commit, git diff HEAD falhou): sem hash, nunca d-e3b0c44298fc.jsonl (emenda FR-011).`

- [ ] **Step 7: Rode.** `deepseek-review-retry.tests.ps1` → PASS (20 testes); `provider-limites.tests.ps1`, `faixa-regras-derivada.tests.ps1`, `ps51-compat.tests.ps1`, `hooks-leitura-utf8.tests.ps1`, `pester-blocos-unicos.tests.ps1` → PASS. BOM do `deepseek-review.ps1` e dos 2 arquivos novos = `ef bb bf`.

- [ ] **Step 8: R11 + commit.** `git add -- plugin/percus-review/scripts/deepseek-review.ps1 plugin/percus-review/tests/_servidor-http-falso.ps1 plugin/percus-review/tests/deepseek-review-retry.tests.ps1`; `& '.\plugin\percus-review\scripts\deepseek-review.ps1'` (já com retry: se ela mesma sair 4, é o provedor fora — reporte ao controlador, não contorne); commit com assunto `feat(review): deepseek-review.ps1 com timeout, 1 retry, exit 4 e corpo mascarado`.

---

### Task 3: Cliente DeepSeek `.sh` — paridade (status HTTP, retry, exit 4, `model`/`usage` no marcador)

**Files:**
- Create: `plugin/percus-review/tests/deepseek-review-retry-sh.tests.ps1`
- Modify: `plugin/percus-review/scripts/deepseek-review.sh:34-46` (args), `:65-71` (deps/config), `:171-229` (trap, chamada, gates), `:239-245` (marcador), `:270` (hash vazio)
- Test (inalterado): `plugin/percus-review/tests/provider-limites.tests.ps1` (âncoras `.sh`: `mv -f "$LOG_TMP"` com `-z "$FINDINGS"`, `finish_reason`, `"$FINISH" == "length"` e `!= "stop"` antes dele), `faixa-regras-derivada.tests.ps1` (`--help` sai 0 e imprime `deepseek-review`: não desloque as linhas 2-9 do cabeçalho)

**Interfaces:**
- Consumes: `_servidor-http-falso.ps1` (`New-RespostaFalsa`, `Start-ServidorFalso`, `Get-ContagemServidorFalso`, `Stop-ServidorFalso`, Task 2); `_resolver-bash.ps1` (`Get-BashGit`, `ConvertTo-CaminhoBash`, `Set-EnvTemporario`, `Restore-EnvTemporario`, Task 1).
- Produces: `deepseek-review.sh [--base <ref>] [--endpoint <url>] [--timeout <s>] [--backoff <s>]` (forma `--x=v` também), mesmos exits, mensagens e `ultimo-erro.txt` do contrato; marcador com `model` e `usage`.

- [ ] **Step 1: Teste que falha** — `tests/deepseek-review-retry-sh.tests.ps1` (UTF-8 com BOM). Monte-o a partir de `tests/deepseek-review-retry.tests.ps1` (Task 2) com estas transformações EXATAS, e nada além delas:

  1. Cabeçalho: `# Paridade do deepseek-review.sh com o .ps1 (FR-001..006, SC-003..005). O .sh chamava curl sem capturar status e sem --max-time, e o marcador nao gravava model/usage (defasado desde 2026-08-15).` Describe: `"deepseek-review.sh -- timeout, retry e provedor indisponivel"`.
  2. No `BeforeAll`, troque a linha `$script:cliente = ...` por:
     ```powershell
     $scripts = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts'
     $script:clienteSh  = ConvertTo-CaminhoBash (Join-Path $scripts 'deepseek-review.sh')
     $script:clientePs1 = Join-Path $scripts 'deepseek-review.ps1'
     $script:bash = Get-BashGit
     ```
     e em `$script:ok` troque `"usage":{"prompt_tokens":1,"completion_tokens":1}` por `"usage":{"prompt_tokens":11,"completion_tokens":7}`. `tmpBase` com prefixo `percus-dss-`.
  3. Substitua `Invoke-Cliente` e `Invoke-ComRoteiro` por:
     ```powershell
     function Invoke-Cliente {
         param([string]$Repo, [string]$Url, [string[]]$ArgsExtra = @(), [hashtable]$Env = @{})
         $envTotal = @{ DEEPSEEK_API_KEY = $script:chave; PERCUS_DEEPSEEK_TIMEOUT_S = $null; PERCUS_DEEPSEEK_BACKOFF_S = $null; DEEPSEEK_ENDPOINT = $null }
         foreach ($k in $Env.Keys) { $envTotal[$k] = $Env[$k] }
         $antigos = Set-EnvTemporario $envTotal
         $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
         # Env pelo AMBIENTE do processo, nao como prefixo do -c (o bash re-parsearia as aspas).
         $cmd = "cd '" + (ConvertTo-CaminhoBash $Repo) + "' && bash '" + $script:clienteSh + "' --endpoint '" + $Url + "' " + ($ArgsExtra -join ' ')
         $sw = [Diagnostics.Stopwatch]::StartNew()
         try {
             $out = & $script:bash -c $cmd 2>$err
             $code = $LASTEXITCODE
         } finally { $sw.Stop(); Restore-EnvTemporario $antigos }
         $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
         $rev = Join-Path (Join-Path $Repo '.deepseek') 'reviews'
         $marcadores = @()
         if (Test-Path $rev) { $marcadores = @(Get-ChildItem $rev -Filter '*.jsonl' | ForEach-Object { $_.Name }) }
         return [pscustomobject]@{ Code = $code; Err = $texto; Out = ($out -join "`n"); Segundos = $sw.Elapsed.TotalSeconds; Marcadores = $marcadores; Rev = $rev }
     }

     function Invoke-ComRoteiro {
         param([object[]]$Roteiro, [string[]]$ArgsExtra = @('--timeout', '2', '--backoff', '1'), [hashtable]$Env = @{}, [switch]$SemCommit)
         $srv = Start-ServidorFalso -Roteiro $Roteiro
         try {
             $repo = New-RepoCliente -SemCommit:$SemCommit
             $r = Invoke-Cliente -Repo $repo -Url $srv.Url -ArgsExtra $ArgsExtra -Env $Env
             $r | Add-Member -NotePropertyName Requisicoes -NotePropertyValue (Get-ContagemServidorFalso $srv)
             return $r
         } finally { Stop-ServidorFalso $srv }
     }
     ```
     (mesmos nomes de propósito: os `It` copiados não mudam de chamada).
  4. No It de precedência: `ArgsCaso = @('-TimeoutSec', '2', '-BackoffSec', '1')` → `@('--timeout', '2', '--backoff', '1')`; nome `'parametro > env'` → `'flag > env'`. No It de argumento inválido: título `"--timeout 0: exit 2 sem chamar a API"`, `-ArgsExtra @('--timeout', '0')`.
  5. Títulos com `SC-003`/`SC-005`/`emenda FR-011`: acrescente ` no .sh`.
  6. No It "200 com choices", depois das asserções existentes, acrescente (FR-006):
     ```powershell
     $j = [IO.File]::ReadAllText((Join-Path $r.Rev 'latest.jsonl'), $script:u8) | ConvertFrom-Json
     $j.model | Should -Be 'deepseek-v4-flash'
     $j.usage.completion_tokens | Should -Be 7
     $j.findings | Should -Match 'Sem findings criticos'
     ```
  7. Acrescente dois It novos no fim do Describe:
     ```powershell
     It "pre-condicao: Git Bash com curl e jq" {
         $script:bash | Should -Not -BeNullOrEmpty
         $saida = & $script:bash -c 'command -v curl; command -v jq' 2>&1 | Out-String
         $saida | Should -Match 'curl'
         $saida | Should -Match 'jq'
     }

     It "corpo com acentos: o trecho de 2000 caracteres do .sh e o mesmo do .ps1" {
         # Corte por CARACTERE (spec), nao por byte: exige locale UTF-8 no substring do bash.
         $acentos = 'a' + [char]0x00E7 + [char]0x00E3 + 'o '
         $corpo = '{"pad":"' + ($acentos * 900) + '"}'
         $srv = Start-ServidorFalso -Roteiro @((New-RespostaFalsa -Corpo $corpo))
         try {
             $repoSh = New-RepoCliente
             $null = Invoke-Cliente -Repo $repoSh -Url $srv.Url -ArgsExtra @('--timeout', '2', '--backoff', '1')
             $repoPs = New-RepoCliente
             $antigos = Set-EnvTemporario @{ DEEPSEEK_API_KEY = $script:chave }
             Push-Location $repoPs
             try { & pwsh -NoProfile -File $script:clientePs1 -Endpoint $srv.Url -TimeoutSec 2 -BackoffSec 1 2>$null | Out-Null } finally { Pop-Location; Restore-EnvTemporario $antigos }
         } finally { Stop-ServidorFalso $srv }
         $esperado = $corpo.Substring(0, 2000)
         foreach ($repo in @($repoPs, $repoSh)) {
             $t = [IO.File]::ReadAllText((Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'ultimo-erro.txt'), $script:u8)
             $t.Substring($t.IndexOf("---`n") + 4) | Should -BeExactly $esperado -Because $repo
         }
     }
     ```

- [ ] **Step 2: Rode e confirme a falha.** `Invoke-Pester -Path '.\plugin\percus-review\tests\deepseek-review-retry-sh.tests.ps1' -Output Detailed`. Esperado: pré-condição PASS; o resto FAIL (`--endpoint` ignorado → chamada ao host real negada ou sem contagem; sem `model`; exits errados). Se a pré-condição falhar, pare.

- [ ] **Step 3: Argumentos e config.** No `case` de argumentos acrescente `--endpoint`/`--endpoint=*` (atribui `ENDPOINT`), `--timeout`/`--timeout=*` (atribui `TIMEOUT_ARG`), `--backoff`/`--backoff=*` (atribui `BACKOFF_ARG`), inicializando `TIMEOUT_ARG=""` e `BACKOFF_ARG=""` junto de `BASE=""`. Depois do bloco DEPS (linha 71):

```bash
# === TIMEOUT E BACKOFF (2026-09-14, FR-001/002): flag > env > padrao ===
e_inteiro() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; return 0; }
config_de_env() {  # $1 nome da var, $2 padrao, $3 minimo
    local v="${!1:-}"
    if [[ -z "$v" ]]; then printf '%s' "$2"; return 0; fi
    if e_inteiro "$v" && [[ "$v" -ge "$3" ]]; then printf '%s' "$v"; return 0; fi
    echo "[deepseek-review] WARN: $1='$v' invalido -- usando padrao $2." >&2
    printf '%s' "$2"
}
if [[ -n "$TIMEOUT_ARG" ]]; then
    if ! e_inteiro "$TIMEOUT_ARG" || [[ "$TIMEOUT_ARG" -lt 1 ]]; then echo "[deepseek-review] ERRO: --timeout precisa ser inteiro >= 1." >&2; exit 2; fi
    TIMEOUT_S="$TIMEOUT_ARG"
else
    TIMEOUT_S="$(config_de_env PERCUS_DEEPSEEK_TIMEOUT_S 180 1)"
fi
if [[ -n "$BACKOFF_ARG" ]]; then
    if ! e_inteiro "$BACKOFF_ARG"; then echo "[deepseek-review] ERRO: --backoff precisa ser inteiro >= 0." >&2; exit 2; fi
    BACKOFF_S="$BACKOFF_ARG"
else
    BACKOFF_S="$(config_de_env PERCUS_DEEPSEEK_BACKOFF_S 5 0)"
fi
```

  Nota: `--timeout 0` precisa sair antes da chamada — `TIMEOUT_ARG="0"` não é vazio, então o `-n` pega. (O WARN dentro de `$(...)` vai para o stderr do processo, não para a variável.)

- [ ] **Step 4: Chamada com retry.** Troque `trap 'rm -f "$USER_MSG_FILE"' EXIT` (linha 172) por `RESP_FILE="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-resp-$$.json")"`, `CURL_ERR="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-curlerr-$$.txt")"` e `trap 'rm -f "$USER_MSG_FILE" "$RESP_FILE" "$CURL_ERR"' EXIT`. Substitua o bloco `=== CALL API ===` (linhas 191-209) por:

```bash
# === CALL API: TIMEOUT E EXATAMENTE 1 RETRY (2026-09-14, FR-001..005) ===
# Body via stdin (--data-binary @-), NAO via argv: git-bash reencoda argv e quebra UTF-8.
# -o arquivo + -w status: sem isso 4xx/5xx e 2xx sem choices eram indistinguiveis.
mask_trecho() {  # stdin: corpo bruto -> stdout: primeiros 2000 CARACTERES, chave trocada por ***
    local raw masked
    raw="$(cat; printf x)"; raw="${raw%x}"
    masked="${raw//"$DEEPSEEK_API_KEY"/***}"
    # Mascara ANTES de cortar. Locale UTF-8 so no subshell: o corte e por caractere, nao por byte.
    ( LC_ALL=C.UTF-8; printf '%s' "${masked:0:2000}" )
}

tentativa() {  # define TENT_VEREDITO (ok|retry|fatal) e TENT_CAUSA
    local rc=0 status tem trecho
    : > "$RESP_FILE"
    status="$(printf '%s' "$BODY" | curl -sS -o "$RESP_FILE" -w '%{http_code}' --max-time "$TIMEOUT_S" \
        -X POST "$ENDPOINT" \
        -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary @- 2>"$CURL_ERR")" || rc=$?
    status="$(printf '%s' "$status" | tr -d '\r')"
    if [[ $rc -ne 0 ]]; then
        TENT_VEREDITO=retry
        if [[ $rc -eq 28 ]]; then TENT_CAUSA="erro de rede/timeout: timeout de ${TIMEOUT_S}s"
        else TENT_CAUSA="erro de rede/timeout: curl exit $rc $(tr -d '\r\n' < "$CURL_ERR")"; fi
        return 0
    fi
    tem="$(jq -r 'if type == "object" and (.choices | type) == "array" and (.choices | length) > 0 then "sim" else "nao" end' < "$RESP_FILE" 2>/dev/null | tr -d '\r' || true)"
    [[ "$tem" == "sim" ]] || tem="nao"
    if [[ "$tem" == "nao" ]]; then
        trecho="$(mask_trecho < "$RESP_FILE"; printf x)"; trecho="${trecho%x}"
        echo "[deepseek-review] resposta sem choices (HTTP $status) -- primeiros 2000 caracteres do corpo:" >&2
        printf '%s\n' "$trecho" >&2
        { mkdir -p ".deepseek/reviews" && printf 'timestamp=%s\nstatus=%s\n---\n%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$trecho" > ".deepseek/reviews/ultimo-erro.txt"; } 2>/dev/null \
            || echo "[deepseek-review] WARN: nao consegui gravar ultimo-erro.txt" >&2
    fi
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
        if [[ "$tem" == "sim" ]]; then TENT_VEREDITO=ok; TENT_CAUSA=""; return 0; fi
        TENT_VEREDITO=retry
        if [[ -z "$(tr -d ' \t\r\n' < "$RESP_FILE")" ]]; then TENT_CAUSA="HTTP $status com corpo vazio"
        else TENT_CAUSA="HTTP $status sem choices"; fi
        return 0
    fi
    if [[ "$status" == "429" || "$status" =~ ^5[0-9][0-9]$ ]]; then TENT_VEREDITO=retry; TENT_CAUSA="HTTP $status"; return 0; fi
    TENT_VEREDITO=fatal; TENT_CAUSA="HTTP $status"
    return 0
}

echo "[deepseek-review] timeout=${TIMEOUT_S}s backoff=${BACKOFF_S}s" >&2
tentativa
if [[ "$TENT_VEREDITO" == "retry" ]]; then
    echo "[deepseek-review] tentativa 1 falhou: ${TENT_CAUSA}. Nova tentativa em ${BACKOFF_S}s." >&2
    sleep "$BACKOFF_S"
    tentativa
    if [[ "$TENT_VEREDITO" == "retry" ]]; then
        echo "[deepseek-review] PROVEDOR INDISPONIVEL apos retry: ${TENT_CAUSA}. Nenhum marcador gravado (exit 4)." >&2
        exit 4
    fi
fi
if [[ "$TENT_VEREDITO" == "fatal" ]]; then
    echo "[deepseek-review] ERRO: ${TENT_CAUSA} -- nao recuperavel, sem nova tentativa. Nenhum marcador gravado (exit 1)." >&2
    exit 1
fi
RESPONSE="$(cat "$RESP_FILE")"

FINDINGS="$(printf '%s' "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null | tr -d '\r' || true)"
if [[ -z "$FINDINGS" ]]; then
    # Com choices e content vazio: resposta inutilizavel, nao outage (FR-005 exit 3, sem retry).
    echo "[deepseek-review] REVIEW NAO CONCLUIDA -- content vazio." >&2
    echo "[deepseek-review] O marcador NAO foi escrito: o commit segue bloqueado (R11)." >&2
    exit 3
fi
```

  E na linha do `FINISH` acrescente `| tr -d '\r' || true` antes do `)"`. Armadilhas: `set -euo pipefail` segue ativo — toda atribuição com pipeline que pode falhar leva `|| rc=$?` ou `|| true`; `${raw//"$KEY"/***}` com o padrão entre aspas é literal (chave com `*`/`?` não vira glob); o `printf x` preserva `\n` finais. `LC_ALL=C.UTF-8` existe no MSYS; se o teste de acentos falhar por locale ausente, reporte (não troque por corte por byte).

- [ ] **Step 5: Marcador com `model` e `usage`.** Troque o `jq -n ... > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"` (linhas 239-245) por:

```bash
printf '%s' "$RESPONSE" | jq -c \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg base "$BASE" \
    --argjson diff_lines "$DIFF_LINES" \
    --arg model "$MODEL" \
    --arg findings "$FINDINGS" \
    '{ timestamp: $timestamp, base: $base, diff_lines: $diff_lines, model: $model, usage: (.usage // null), findings: $findings }' \
    | tr -d '\r' > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"
```

  Remova o parágrafo "NOTA: o marcador acima nao grava model/usage..." (linhas 283-285), agora falso.

- [ ] **Step 6: Hash vazio.** Linha 270: `if [ -n "$DIFF_HASH" ]; then` → `if [ -n "$DIFF_HASH" ] && [ "$DIFF_HASH" != "e3b0c44298fc" ]; then`, com o comentário `# e3b0c44298fc = hash do arquivo vazio: sem hash, nunca d-e3b0c44298fc.jsonl (emenda FR-011).`

- [ ] **Step 7: Rode.** `deepseek-review-retry-sh.tests.ps1` → PASS (22 testes); `deepseek-review-retry.tests.ps1`, `provider-limites.tests.ps1`, `faixa-regras-derivada.tests.ps1`, `ps51-compat.tests.ps1`, `hooks-leitura-utf8.tests.ps1`, `pester-blocos-unicos.tests.ps1` → PASS.

- [ ] **Step 8: Formato.** Ferramenta Bash: `git add -- plugin/percus-review/scripts/deepseek-review.sh plugin/percus-review/tests/deepseek-review-retry-sh.tests.ps1`; `git ls-files --eol -- plugin/percus-review/scripts/deepseek-review.sh` → `i/lf`. Linhas adicionadas ASCII (ferramenta PowerShell):

```powershell
$d = git diff --cached -U0 -- 'plugin/percus-review/scripts/deepseek-review.sh'
@($d | Where-Object { $_ -match '^\+' -and $_ -match '[^\x09\x20-\x7E]' })
```
  Esperado vazio. BOM do teste novo.

- [ ] **Step 9: R11 + commit.** `& '.\plugin\percus-review\scripts\deepseek-review.ps1'`, triagem, commit com assunto `feat(review): deepseek-review.sh com status HTTP, timeout, 1 retry, exit 4 e model/usage no marcador`.

---

### Task 4: `registrar-review` (`.ps1` + `.sh`) — registro suportado da review Cross-Claude

**Files:**
- Create: `plugin/percus-review/scripts/registrar-review.ps1`
- Create: `plugin/percus-review/scripts/registrar-review.sh`
- Create: `plugin/percus-review/tests/registrar-review.tests.ps1`

**Interfaces:**
- Consumes: `_resolver-bash.ps1` (`Get-BashGit`, `ConvertTo-CaminhoBash`, `Set-EnvTemporario`, `Restore-EnvTemporario`, Task 1); hook `pre-commit-check.ps1`/`.sh` com classificação (Task 1) para o SC-006.
- Produces: `registrar-review.ps1 -Arquivo <arq> -Canal <canal> [-Modelo <id>] [-Repo <dir>]` e `registrar-review.sh --arquivo <arq> --canal <canal> [--modelo <id>] [--repo <dir>]`; exits 0/1/2/3; stdout `hash=<h> latest=<caminho> d=<caminho>`; arquivos em `<raiz>/.deepseek/reviews/` e telemetria em `<raiz>/.deepseek/spend/<YYYY-MM>.jsonl` (contrato). A Task 5 cita os dois caminhos no marcador.

- [ ] **Step 1: Teste que falha** — `tests/registrar-review.tests.ps1` (UTF-8 com BOM):

```powershell
#requires -Version 5.1
# FR-009..014 / SC-006. Em 2026-09-14 o controlador calculou o hash a mao e escreveu d-<hash>.jsonl
# sozinho para registrar a review de um subagente: nao havia jeito suportado. Aqui o comando roda
# de verdade nos dois runtimes, e o fluxo termina no hook liberando pelo hash.

BeforeDiscovery {
    $script:runtimes = @(@{ Rt = 'ps1' }, @{ Rt = 'sh' })
}

Describe "registrar-review -- registro da review Cross-Claude" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        $plugin = Split-Path $PSScriptRoot -Parent
        $script:regPs1 = Join-Path (Join-Path $plugin 'scripts') 'registrar-review.ps1'
        $script:regSh  = ConvertTo-CaminhoBash (Join-Path (Join-Path $plugin 'scripts') 'registrar-review.sh')
        $script:hookPs1 = Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.ps1'
        $script:hookSh  = ConvertTo-CaminhoBash (Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.sh')
        $script:bash = Get-BashGit
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-reg-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $script:acento = 'acentua' + [char]0x00E7 + [char]0x00E3 + 'o'

        function New-RepoReg {
            param([switch]$SemCommit, [switch]$SemDiff)
            $dir = Join-Path $script:tmpBase ("r-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path (Join-Path $dir 'sub') | Out-Null
            Push-Location $dir
            try {
                & git init -q . 2>$null; & git config user.email t@t.t 2>$null; & git config user.name t 2>$null
                [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "original`n", $script:u8)
                & git add a.ps1 2>$null
                if (-not $SemCommit) { & git @(('com' + 'mit'), '-q', '-m', 'base', '--no-verify') 2>$null }
                if (-not $SemDiff) { [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), ("alterado com " + $script:acento + "`nsegunda linha`n"), $script:u8) }
            } finally { Pop-Location }
            return $dir
        }

        function Get-DiffHash {
            param([string]$RepoDir)
            $tmp = [IO.Path]::GetTempFileName()
            try {
                Push-Location $RepoDir
                try { & git diff HEAD --output=$tmp 2>$null | Out-Null } finally { Pop-Location }
                $b = [IO.File]::ReadAllBytes($tmp)
                $sha = [System.Security.Cryptography.SHA256]::Create()
                return [pscustomobject]@{
                    Hash   = ([BitConverter]::ToString($sha.ComputeHash($b)) -replace '-','').ToLower().Substring(0,12)
                    Linhas = @($b | Where-Object { $_ -eq 10 }).Count
                }
            } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }

        function New-Findings {
            param([string]$Texto = "Sem findings criticos.`n", [byte[]]$Bytes)
            $f = Join-Path $script:tmpBase ("f-" + [Guid]::NewGuid().ToString('N') + '.txt')
            if ($PSBoundParameters.ContainsKey('Bytes')) { [IO.File]::WriteAllBytes($f, $Bytes) }
            else { [IO.File]::WriteAllText($f, $Texto, $script:u8) }
            return $f
        }

        function Invoke-Registro {
            param([string]$Rt, [string]$Repo, [string]$Arquivo, [string]$Canal = 'cross-claude', [string]$Modelo = '', [string]$Cwd = '', [string]$BashExe = '', [hashtable]$Env = @{})
            if (-not $Cwd) { $Cwd = $Repo }
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $antigos = Set-EnvTemporario $Env
            Push-Location $Cwd
            try {
                if ($Rt -eq 'ps1') {
                    $a = @('-NoProfile', '-File', $script:regPs1, '-Arquivo', $Arquivo, '-Canal', $Canal)
                    if ($Modelo) { $a += @('-Modelo', $Modelo) }
                    $out = & pwsh @a 2>$err
                } else {
                    $b = $script:bash; if ($BashExe) { $b = $BashExe }
                    $cmd = "cd '" + (ConvertTo-CaminhoBash $Cwd) + "' && bash '" + $script:regSh + "' --arquivo '" + (ConvertTo-CaminhoBash $Arquivo) + "' --canal '" + $Canal + "'"
                    if ($Modelo) { $cmd += " --modelo '" + $Modelo + "'" }
                    $out = & $b -c $cmd 2>$err
                }
                $code = $LASTEXITCODE
            } finally { Pop-Location; Restore-EnvTemporario $antigos }
            $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            $rev = Join-Path (Join-Path $Repo '.deepseek') 'reviews'
            $arqs = @()
            if (Test-Path $rev) { $arqs = @(Get-ChildItem $rev -File | ForEach-Object { $_.Name }) }
            return [pscustomobject]@{ Code = $code; Err = $texto; Out = (@($out) -join "`n").Trim(); Rev = $rev; Arquivos = $arqs }
        }
    }

    AfterAll {
        Get-ChildItem $script:tmpBase -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { try { $_.Attributes = 'Normal' } catch { } }
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    Context "recusas: exit 2, nada gravado" {
        It "<Rt>: <Caso>" -ForEach @(
            foreach ($rt in @('ps1', 'sh')) {
                @{ Rt = $rt; Caso = 'arquivo ausente';         Motivo = 'arquivo de findings ausente' }
                @{ Rt = $rt; Caso = 'vazio';                   Motivo = 'findings vazio ou so espaco' }
                @{ Rt = $rt; Caso = 'so espaco';               Motivo = 'findings vazio ou so espaco' }
                @{ Rt = $rt; Caso = 'objeto deferred';         Motivo = 'placeholder' }
                @{ Rt = $rt; Caso = 'objeto placeholder';      Motivo = 'placeholder' }
                @{ Rt = $rt; Caso = 'texto com marcador';      Motivo = '__PERCUS_NEEDS_CROSS_CLAUDE__' }
                @{ Rt = $rt; Caso = 'canal vazio';             Motivo = 'canal vazio' }
                @{ Rt = $rt; Caso = 'repo sem commit';         Motivo = 'rio sem commit' }
                @{ Rt = $rt; Caso = 'diff vazio';              Motivo = 'git diff HEAD vazio' }
                @{ Rt = $rt; Caso = 'acima de 256 KB';         Motivo = 'acima do teto (256 KB)' }
            }
        ) {
            $repo = New-RepoReg -SemCommit:($Caso -eq 'repo sem commit') -SemDiff:($Caso -eq 'diff vazio')
            $canal = 'cross-claude'
            switch ($Caso) {
                'arquivo ausente'    { $f = Join-Path $script:tmpBase 'nao-existe.txt' }
                'vazio'              { $f = New-Findings -Bytes ([byte[]]@()) }
                'so espaco'          { $f = New-Findings -Texto "  `n`t `r`n" }
                'objeto deferred'    { $f = New-Findings -Texto '{"deferred":true,"reason":"x","decision":"dual"}' }
                'objeto placeholder' { $f = New-Findings -Texto '{"placeholder":true,"note":"x"}' }
                'texto com marcador' { $f = New-Findings -Texto "__PERCUS_NEEDS_CROSS_CLAUDE__: rota solo`n" }
                'canal vazio'        { $f = New-Findings; $canal = ' ' }
                'acima de 256 KB'    { $f = New-Findings -Texto ('a' * 262145) }
                default              { $f = New-Findings }
            }
            $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo $f -Canal $canal
            $r.Code | Should -Be 2 -Because $r.Err
            $r.Err  | Should -Match ([regex]::Escape($Motivo))
            @($r.Arquivos).Count | Should -Be 0 -Because "nada gravado: $($r.Arquivos -join ', ')"
        }
    }

    It "<Rt>: texto livre que so MENCIONA deferred e aceito" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $f = New-Findings -Texto ("[SEV: risco] o placeholder grava `"deferred`": true e isso e ok`n")
        (Invoke-Registro -Rt $Rt -Repo $repo -Arquivo $f).Code | Should -Be 0
    }

    It "<Rt>: sucesso grava d-<hash> e latest com o contrato, telemetria e a linha de saida" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $esperado = Get-DiffHash $repo
        $texto = "[SEV: bug] Arquivo: a.ps1:1 -- " + $script:acento + "`n"
        $f = New-Findings -Texto $texto
        $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo $f -Modelo 'claude-sonnet-5'
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Out | Should -Match ('^hash=' + $esperado.Hash + ' latest=\S.*latest\.jsonl d=\S.*d-' + $esperado.Hash + '\.jsonl$')
        foreach ($nome in @('latest.jsonl', "d-$($esperado.Hash).jsonl")) {
            $j = [IO.File]::ReadAllText((Join-Path $r.Rev $nome), $script:u8) | ConvertFrom-Json
            $j.canal      | Should -Be 'cross-claude'
            $j.base       | Should -Be ''
            $j.model      | Should -Be 'claude-sonnet-5'
            $j.usage      | Should -BeNullOrEmpty
            $j.findings   | Should -BeExactly $texto
            $j.diff_lines | Should -Be $esperado.Linhas
            "$($j.timestamp)" | Should -Not -BeNullOrEmpty
        }
        $spend = Get-ChildItem (Join-Path (Join-Path $repo '.deepseek') 'spend') -Filter '*.jsonl'
        @($spend).Count | Should -Be 1
        $s = [IO.File]::ReadAllLines($spend[0].FullName, $script:u8)[0] | ConvertFrom-Json
        $s.tool | Should -Be 'registrar-review'
        $s.provider | Should -Be 'cross-claude'
        $s.model | Should -Be 'claude-sonnet-5'
        $s.diff_lines | Should -Be $esperado.Linhas
        @($r.Arquivos | Where-Object { $_ -like '*.tmp' }).Count | Should -Be 0
    }

    It "<Rt>: sem -Modelo grava model null; findings com BOM sai sem BOM" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $f = New-Findings -Bytes ([byte[]](@(0xEF, 0xBB, 0xBF) + $script:u8.GetBytes("ok`n")))
        $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo $f
        $r.Code | Should -Be 0 -Because $r.Err
        $j = [IO.File]::ReadAllText((Join-Path $r.Rev 'latest.jsonl'), $script:u8) | ConvertFrom-Json
        $j.model | Should -BeNullOrEmpty
        $j.findings | Should -BeExactly "ok`n"
    }

    It "<Rt>: chamado de subdiretorio grava na raiz com o hash da raiz" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo (New-Findings) -Cwd (Join-Path $repo 'sub')
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Arquivos | Should -Contain ("d-" + (Get-DiffHash $repo).Hash + ".jsonl")
        Test-Path (Join-Path (Join-Path $repo 'sub') '.deepseek') | Should -BeFalse
    }

    It "<Rt>: falha ao gravar latest.jsonl -> exit 3 e o d-<hash> desta chamada e removido" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $rev = Join-Path (Join-Path $repo '.deepseek') 'reviews'
        New-Item -ItemType Directory -Force -Path (Join-Path $rev 'latest.jsonl') | Out-Null
        $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo (New-Findings)
        $r.Code | Should -Be 3 -Because $r.Err
        @(Get-ChildItem $rev -File -Filter 'd-*').Count | Should -Be 0
        @(Get-ChildItem $rev -File -Filter '*.tmp').Count | Should -Be 0
    }

    It "<Rt>: telemetria que falha nao muda o exit" -ForEach $script:runtimes {
        $repo = New-RepoReg
        [IO.File]::WriteAllText((Join-Path (Join-Path $repo '.deepseek') 'spend'), 'arquivo no lugar do diretorio', $script:u8)
        (Invoke-Registro -Rt $Rt -Repo $repo -Arquivo (New-Findings)).Code | Should -Be 0
    }

    It "sh sem jq: exit 1 com mensagem explicita e nenhum JSON gravado (FR-014)" {
        $semJq = Join-Path (Join-Path (Join-Path $env:ProgramFiles 'Git') 'usr') 'bin'
        $bashSemJq = Join-Path $semJq 'bash.exe'
        $vazio = Join-Path $script:tmpBase 'home-vazio'
        New-Item -ItemType Directory -Force -Path $vazio | Out-Null
        $repo = New-RepoReg
        # A pre-condicao e aferida no MESMO ambiente do cenario abaixo.
        $antigos = Set-EnvTemporario @{ PATH = $semJq; HOME = $vazio }
        try { $pre = & $bashSemJq -c 'command -v jq || echo SEM-JQ' 2>&1 | Out-String } finally { Restore-EnvTemporario $antigos }
        $pre | Should -Match 'SEM-JQ' -Because "sem isso o teste mede o caminho normal"
        $r = Invoke-Registro -Rt 'sh' -Repo $repo -Arquivo (New-Findings) -BashExe $bashSemJq -Env @{ PATH = $semJq; HOME = $vazio }
        $r.Code | Should -Be 1 -Because $r.Err
        $r.Err | Should -Match 'jq'
        @($r.Arquivos).Count | Should -Be 0
    }

    It "concorrencia: dois registros simultaneos nunca deixam marcador parcial ou intercalado" {
        $repo = New-RepoReg
        $fa = New-Findings -Texto ("A" * 50000)
        $fb = New-Findings -Texto ("B" * 50000)
        for ($i = 0; $i -lt 3; $i++) {
            $pa = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile', '-File', ('"' + $script:regPs1 + '"'), '-Arquivo', ('"' + $fa + '"'), '-Canal', 'cross-claude', '-Repo', ('"' + $repo + '"')) -PassThru -WindowStyle Hidden
            $pb = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile', '-File', ('"' + $script:regPs1 + '"'), '-Arquivo', ('"' + $fb + '"'), '-Canal', 'cross-claude', '-Repo', ('"' + $repo + '"')) -PassThru -WindowStyle Hidden
            $pa.WaitForExit(); $pb.WaitForExit()
            @($pa.ExitCode, $pb.ExitCode) | ForEach-Object { $_ | Should -BeIn @(0, 3) }
            $rev = Join-Path (Join-Path $repo '.deepseek') 'reviews'
            foreach ($m in @(Get-ChildItem $rev -File -Filter '*.jsonl')) {
                $j = [IO.File]::ReadAllText($m.FullName, $script:u8) | ConvertFrom-Json
                $j.findings | Should -BeIn @(("A" * 50000), ("B" * 50000))
            }
            @(Get-ChildItem $rev -File -Filter '*.tmp').Count | Should -Be 0
        }
    }

    It "SC-006: hash identico entre .ps1 e .sh num diff com acentos" {
        $repo = New-RepoReg
        $f = New-Findings
        $a = Invoke-Registro -Rt 'ps1' -Repo $repo -Arquivo $f
        $b = Invoke-Registro -Rt 'sh' -Repo $repo -Arquivo $f
        $a.Code | Should -Be 0 -Because $a.Err
        $b.Code | Should -Be 0 -Because $b.Err
        ($a.Out -replace '^hash=([0-9a-f]{12}) .*$', '$1') | Should -BeExactly ($b.Out -replace '^hash=([0-9a-f]{12}) .*$', '$1')
        ($a.Out -replace '^hash=([0-9a-f]{12}) .*$', '$1') | Should -BeExactly (Get-DiffHash $repo).Hash
    }

    It "SC-006: registro Cross-Claude + latest.jsonl com 60 min -> o hook <Camada> libera pelo hash" -ForEach @(@{ Camada = 'ps1' }, @{ Camada = 'sh' }) {
        $repo = New-RepoReg
        Push-Location $repo
        try { & git add a.ps1 2>$null } finally { Pop-Location }
        $r = Invoke-Registro -Rt 'ps1' -Repo $repo -Arquivo (New-Findings -Texto "[SEV: risco] revisado pelo subagente`n")
        $r.Code | Should -Be 0 -Because $r.Err
        (Get-Item (Join-Path $r.Rev 'latest.jsonl')).LastWriteTime = (Get-Date).AddMinutes(-60)
        $payload = @{ tool_name = 'Bash'; tool_input = @{ command = ('cd "' + (ConvertTo-CaminhoBash $repo) + '" && git com' + 'mit -m x') } } | ConvertTo-Json -Compress
        if ($Camada -eq 'ps1') { $payload | & pwsh -NoProfile -File $script:hookPs1 *>$null }
        else { $payload | & $script:bash $script:hookSh *>$null }
        $LASTEXITCODE | Should -Be 0 -Because "a review registrada cobre exatamente este diff; o relogio e irrelevante"
    }
}
```

- [ ] **Step 2: Rode e confirme a falha.** `Invoke-Pester -Path '.\plugin\percus-review\tests\registrar-review.tests.ps1' -Output Detailed` → FAIL em tudo (scripts inexistentes). Os It de recusa falham por exit ≠ 2, não por erro de fixture — confira as mensagens.

- [ ] **Step 3: `scripts/registrar-review.ps1`** (UTF-8 com BOM, ASCII):

```powershell
#requires -Version 5.1
<#
.SYNOPSIS
  Registra no marcador R11 uma review feita fora do cliente DeepSeek (ex.: subagente Cross-Claude).

.DESCRIPTION
  Existe porque, com a DeepSeek fora, o wrapper pedia o subagente mas nao havia jeito suportado de
  gravar o resultado: em 2026-09-14 o hash foi calculado a mao e o d-<hash>.jsonl escrito na unha.
  Hash IGUAL ao do hook (SHA-256 do arquivo de `git diff HEAD --output=`, 12 hex). Grava primeiro
  d-<hash>.jsonl e depois latest.jsonl, cada um por arquivo temporario unico + troca, e desfaz o
  que gravou se a segunda gravacao falhar.

  Exit: 0 ok | 1 ambiente/hash vazio | 2 entrada recusada | 3 falha de gravacao (desfeita).

.EXAMPLE
  & registrar-review.ps1 -Arquivo findings.txt -Canal cross-claude -Modelo claude-sonnet-5
#>
[CmdletBinding()]
param(
    [string]$Arquivo = "",
    [string]$Canal = "",
    [string]$Modelo = "",
    [string]$Repo = ""
)
# SEM $ErrorActionPreference='Stop': no 5.1 ele transforma stderr do git em excecao mesmo com 2>$null.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$u8 = New-Object System.Text.UTF8Encoding($false)
$ws = [char[]]@(32, 9, 10, 13)

function Stop-Registro {
    param([int]$Codigo, [string]$Motivo)
    [Console]::Error.WriteLine("[registrar-review] ERRO: $Motivo")
    exit $Codigo
}

function Write-Atomico {
    # Temporario unico por processo + troca: nunca ha conteudo parcial nem intercalado no destino.
    param([string]$Destino, [string]$Conteudo)
    if (Test-Path -LiteralPath $Destino -PathType Container) { throw "destino e um diretorio: $Destino" }
    $tmp = "$Destino.$PID." + [Guid]::NewGuid().ToString('N').Substring(0, 8) + ".tmp"
    try {
        [IO.File]::WriteAllText($tmp, $Conteudo, $u8)
        if (Test-Path -LiteralPath $Destino -PathType Leaf) {
            [IO.File]::Replace($tmp, $Destino, [NullString]::Value)
        } else {
            try { [IO.File]::Move($tmp, $Destino) }
            catch [System.IO.IOException] { [IO.File]::Replace($tmp, $Destino, [NullString]::Value) }
        }
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

# --- entrada ---
if ([string]::IsNullOrWhiteSpace($Arquivo) -or -not (Test-Path -LiteralPath $Arquivo -PathType Leaf)) { Stop-Registro 2 "arquivo de findings ausente: '$Arquivo'" }
if ([string]::IsNullOrWhiteSpace($Canal)) { Stop-Registro 2 "canal vazio (use -Canal cross-claude)" }
$caminhoArq = (Resolve-Path -LiteralPath $Arquivo).Path
$tam = (Get-Item -LiteralPath $caminhoArq).Length
if ($tam -gt 262144) { Stop-Registro 2 "findings acima do teto (256 KB): $tam bytes" }
$bytes = [IO.File]::ReadAllBytes($caminhoArq)
$ini = 0
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $ini = 3 }
$texto = $u8.GetString($bytes, $ini, $bytes.Length - $ini)
$limpo = $texto.Trim($ws)
if ($limpo.Length -eq 0) { Stop-Registro 2 "findings vazio ou so espaco" }
# So o arquivo que e INTEIRO um objeto placeholder e recusado; texto livre citando "deferred" passa.
if ($limpo.StartsWith('{')) {
    $obj = $null
    try { $obj = ConvertFrom-Json -InputObject $texto -ErrorAction Stop } catch { $obj = $null }
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $obj.PSObject.Properties) {
            if (($p.Name -ceq 'deferred' -or $p.Name -ceq 'placeholder') -and ($p.Value -is [bool]) -and $p.Value) {
                Stop-Registro 2 "o arquivo e um placeholder ($($p.Name):true), nao uma review"
            }
        }
    }
}
if ($texto.Contains('__PERCUS_NEEDS_CROSS_CLAUDE__')) { Stop-Registro 2 "o texto contem o marcador __PERCUS_NEEDS_CROSS_CLAUDE__ -- isso e o pedido de review, nao a review" }

# --- repo ---
$baseDir = $Repo
if (-not $baseDir) { $baseDir = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $baseDir -PathType Container)) { Stop-Registro 2 "diretorio do repo nao existe: '$baseDir'" }
$top = & git -C $baseDir rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $top) { Stop-Registro 2 "'$baseDir' nao e um repositorio git" }
$top = ([string]$top).Trim()
$null = & git -C $top rev-parse --verify --quiet 'HEAD^{commit}' 2>$null
if ($LASTEXITCODE -ne 0) { Stop-Registro 2 ('reposit' + [char]0x00F3 + 'rio sem commit') }

# --- hash (identico ao hook) ---
$tmpDiff = [IO.Path]::GetTempFileName()
$hash = $null
$diffLinhas = 0
try {
    & git -C $top diff HEAD --output=$tmpDiff 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-Registro 1 "git diff HEAD falhou (exit $LASTEXITCODE) -- hash vazio, nada gravado" }
    $diffBytes = [IO.File]::ReadAllBytes($tmpDiff)
    if ($diffBytes.Length -eq 0) { Stop-Registro 2 "git diff HEAD vazio -- nao ha o que registrar" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = ([BitConverter]::ToString($sha.ComputeHash($diffBytes)) -replace '-', '').ToLower().Substring(0, 12)
    # Latin-1 decodifica 1 byte = 1 char: conta 0x0A sem laco por byte (lento no 5.1 em diff grande).
    $diffLinhas = [Text.Encoding]::GetEncoding(28591).GetString($diffBytes).Split([char]10).Count - 1
} finally { Remove-Item -LiteralPath $tmpDiff -Force -ErrorAction SilentlyContinue }
if (-not $hash -or $hash -eq 'e3b0c44298fc') { Stop-Registro 1 "hash vazio -- nada gravado" }

# --- gravacao: d-<hash> primeiro, latest depois, desfaz em falha ---
$reviewDir = Join-Path $top '.deepseek'
$reviewDir = Join-Path $reviewDir 'reviews'
$dPath = Join-Path $reviewDir "d-$hash.jsonl"
$latestPath = Join-Path $reviewDir 'latest.jsonl'
$modeloJson = $null
if ($Modelo) { $modeloJson = $Modelo }
$agora = [DateTime]::UtcNow
$json = [ordered]@{
    timestamp  = $agora.ToString('yyyy-MM-ddTHH:mm:ssZ')
    base       = ''
    diff_lines = $diffLinhas
    model      = $modeloJson
    usage      = $null
    findings   = $texto
    canal      = $Canal
} | ConvertTo-Json -Compress -Depth 3
$gravados = New-Object System.Collections.Generic.List[string]
try {
    New-Item -ItemType Directory -Force -Path $reviewDir | Out-Null
    Write-Atomico -Destino $dPath -Conteudo ($json + "`n"); $gravados.Add($dPath)
    Write-Atomico -Destino $latestPath -Conteudo ($json + "`n"); $gravados.Add($latestPath)
} catch {
    foreach ($g in $gravados) { Remove-Item -LiteralPath $g -Force -ErrorAction SilentlyContinue }
    Stop-Registro 3 "falha ao gravar marcador ($($_.Exception.Message)) -- o que esta chamada gravou foi removido"
}

# --- telemetria: falha nao muda o exit ---
try {
    $spendDir = Join-Path $top '.deepseek'
    $spendDir = Join-Path $spendDir 'spend'
    New-Item -ItemType Directory -Force -Path $spendDir -ErrorAction Stop | Out-Null
    $linha = [ordered]@{
        timestamp  = $agora.ToString('yyyy-MM-ddTHH:mm:ssZ')
        tool       = 'registrar-review'
        provider   = $Canal
        model      = $modeloJson
        usage      = $null
        diff_lines = $diffLinhas
    } | ConvertTo-Json -Compress
    [IO.File]::AppendAllText((Join-Path $spendDir ($agora.ToString('yyyy-MM') + '.jsonl')), $linha + "`n", $u8)
} catch { }

[Console]::Out.WriteLine("hash=$hash latest=$latestPath d=$dPath")
exit 0
```

  Armadilhas: `exit` dentro de `try` com `finally` roda o `finally` (o temporário do diff some); `[IO.File]::Replace(..., $null)` no pwsh 7 com `$null` vira `""` e lança — use `[NullString]::Value`; `Split-Path`/`Join-Path` um filho por vez.

- [ ] **Step 4: `scripts/registrar-review.sh`** (ASCII puro, LF):

```bash
#!/usr/bin/env bash
# registrar-review.sh -- registra no marcador R11 uma review feita fora do cliente DeepSeek
# (ex.: subagente Cross-Claude). Hash igual ao do hook; grava d-<hash>.jsonl e depois latest.jsonl
# por temporario unico + mv, e desfaz o que gravou se a segunda gravacao falhar.
#
# Uso: bash registrar-review.sh --arquivo <findings> --canal cross-claude [--modelo <id>] [--repo <dir>]
# Exit: 0 ok | 1 ambiente (jq/git/sha256sum) ou hash vazio | 2 entrada recusada | 3 falha de gravacao.
# Requer jq (FR-014): sem ele sai 1 -- nunca monta JSON na mao.

set -uo pipefail

falha() { echo "[registrar-review] ERRO: $2" >&2; exit "$1"; }

ARQUIVO=""; CANAL=""; MODELO=""; REPO=""
while [ $# -gt 0 ]; do
    case "$1" in
        --arquivo) ARQUIVO="${2:-}"; shift 2 ;;
        --arquivo=*) ARQUIVO="${1#*=}"; shift ;;
        --canal) CANAL="${2:-}"; shift 2 ;;
        --canal=*) CANAL="${1#*=}"; shift ;;
        --modelo) MODELO="${2:-}"; shift 2 ;;
        --modelo=*) MODELO="${1#*=}"; shift ;;
        --repo) REPO="${2:-}"; shift 2 ;;
        --repo=*) REPO="${1#*=}"; shift ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        *) falha 2 "argumento desconhecido: $1" ;;
    esac
done

command -v jq >/dev/null 2>&1 || falha 1 "dependencia 'jq' nao encontrada -- instale jq; nenhum JSON foi gravado"
for c in git sha256sum; do
    command -v "$c" >/dev/null 2>&1 || falha 1 "dependencia '$c' nao encontrada"
done

{ [ -n "$ARQUIVO" ] && [ -f "$ARQUIVO" ]; } || falha 2 "arquivo de findings ausente: '$ARQUIVO'"
[ -n "$(printf '%s' "$CANAL" | tr -d ' \t\r\n')" ] || falha 2 "canal vazio (use --canal cross-claude)"
TAM=$(wc -c < "$ARQUIVO" | tr -d ' \r')
[ "$TAM" -le 262144 ] || falha 2 "findings acima do teto (256 KB): $TAM bytes"

TMPD="$(mktemp -d 2>/dev/null || { d="${TMPDIR:-/tmp}/percus-reg-$$"; mkdir -p "$d" && echo "$d"; })"
trap 'rm -rf "$TMPD"' EXIT
FIND="$TMPD/findings.txt"
if [ "$(head -c3 "$ARQUIVO" | od -An -tx1 | tr -d ' \r\n')" = "efbbbf" ]; then
    tail -c +4 "$ARQUIVO" > "$FIND"
else
    cat "$ARQUIVO" > "$FIND"
fi
[ -n "$(tr -d ' \t\r\n' < "$FIND")" ] || falha 2 "findings vazio ou so espaco"
# So o arquivo que e INTEIRO um objeto placeholder e recusado; texto livre citando deferred passa.
if jq -e 'type == "object" and (.deferred == true or .placeholder == true)' < "$FIND" >/dev/null 2>&1; then
    CAMPO="$(jq -r 'if .deferred == true then "deferred" else "placeholder" end' < "$FIND" 2>/dev/null | tr -d '\r')"
    falha 2 "o arquivo e um placeholder (${CAMPO}:true), nao uma review"
fi
if grep -q '__PERCUS_NEEDS_CROSS_CLAUDE__' "$FIND"; then
    falha 2 "o texto contem o marcador __PERCUS_NEEDS_CROSS_CLAUDE__ -- isso e o pedido de review, nao a review"
fi

BASE_DIR="${REPO:-$PWD}"
[ -d "$BASE_DIR" ] || falha 2 "diretorio do repo nao existe: '$BASE_DIR'"
TOP="$(git -C "$BASE_DIR" rev-parse --show-toplevel 2>/dev/null | tr -d '\r')"
[ -n "$TOP" ] || falha 2 "'$BASE_DIR' nao e um repositorio git"
git -C "$TOP" rev-parse --verify --quiet 'HEAD^{commit}' >/dev/null 2>&1 || falha 2 "$(printf 'reposit\303\263rio sem commit')"

DIFF_TMP="$TMPD/diff.txt"
git -C "$TOP" diff HEAD --output="$DIFF_TMP" 2>/dev/null || falha 1 "git diff HEAD falhou -- hash vazio, nada gravado"
[ -s "$DIFF_TMP" ] || falha 2 "git diff HEAD vazio -- nao ha o que registrar"
HASH="$(sha256sum "$DIFF_TMP" | cut -c1-12)"
{ [ -n "$HASH" ] && [ "$HASH" != "e3b0c44298fc" ]; } || falha 1 "hash vazio -- nada gravado"
DIFF_LINES="$(wc -l < "$DIFF_TMP" | tr -d ' \r')"

REV_DIR="$TOP/.deepseek/reviews"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DOC="$TMPD/doc.json"
jq -nc --arg timestamp "$TS" --argjson diff_lines "$DIFF_LINES" --arg model "$MODELO" \
    --rawfile findings "$FIND" --arg canal "$CANAL" \
    '{timestamp: $timestamp, base: "", diff_lines: $diff_lines, model: (if $model == "" then null else $model end), usage: null, findings: $findings, canal: $canal}' \
    2>/dev/null | tr -d '\r' > "$DOC"
[ -s "$DOC" ] || falha 1 "jq nao montou o marcador -- nada gravado"

grava_atomico() {  # $1 origem pronta, $2 destino
    [ -d "$2" ] && return 1
    _t="$2.$$.$RANDOM.tmp"
    cp "$1" "$_t" 2>/dev/null || { rm -f "$_t"; return 1; }
    mv -f "$_t" "$2" 2>/dev/null || { rm -f "$_t"; return 1; }
    return 0
}
mkdir -p "$REV_DIR" 2>/dev/null || falha 3 "nao consegui criar $REV_DIR -- nada gravado"
D_PATH="$REV_DIR/d-$HASH.jsonl"
L_PATH="$REV_DIR/latest.jsonl"
grava_atomico "$DOC" "$D_PATH" || falha 3 "falha ao gravar $D_PATH -- nada gravado"
if ! grava_atomico "$DOC" "$L_PATH"; then
    rm -f "$D_PATH"
    falha 3 "falha ao gravar $L_PATH -- o d-$HASH.jsonl desta chamada foi removido"
fi

{
    mkdir -p "$TOP/.deepseek/spend" &&
    jq -nc --arg timestamp "$TS" --arg provider "$CANAL" --arg model "$MODELO" --argjson diff_lines "$DIFF_LINES" \
        '{timestamp: $timestamp, tool: "registrar-review", provider: $provider, model: (if $model == "" then null else $model end), usage: null, diff_lines: $diff_lines}' \
        | tr -d '\r' >> "$TOP/.deepseek/spend/$(date -u +%Y-%m).jsonl"
} 2>/dev/null || true

printf 'hash=%s latest=%s d=%s\n' "$HASH" "$L_PATH" "$D_PATH"
exit 0
```

  Armadilhas: sem `set -e` (cada falha é tratada com mensagem); `--rawfile` e não `--arg` para os findings (argv estoura ~32 KB no git-bash, mesma lição do `deepseek-review.sh`); a checagem `[ -d "$2" ]` vem antes do `mv` porque `mv` para um diretório existente move PARA DENTRO dele e "funciona".

- [ ] **Step 5: Rode.** `registrar-review.tests.ps1` → PASS (37 testes); `ps51-compat.tests.ps1`, `hooks-leitura-utf8.tests.ps1`, `pester-blocos-unicos.tests.ps1` → PASS. Se o It de concorrência falhar por exit fora de {0,3} ou JSON inválido, é defeito real de atomicidade — não afrouxe o teste.

- [ ] **Step 6: Formato.** BOM em `registrar-review.ps1` e no teste. `registrar-review.sh` sem CR e sem byte > 0x7F (ferramenta PowerShell):

```powershell
$b = [IO.File]::ReadAllBytes('.\plugin\percus-review\scripts\registrar-review.sh')
@($b | Where-Object { $_ -eq 13 -or $_ -gt 127 }).Count
```
  Esperado `0`. Depois do `git add -- plugin/percus-review/scripts/registrar-review.ps1 plugin/percus-review/scripts/registrar-review.sh plugin/percus-review/tests/registrar-review.tests.ps1`, `git ls-files --eol -- plugin/percus-review/scripts/registrar-review.sh` → `i/lf`.

- [ ] **Step 7: R11 + commit.** `& '.\plugin\percus-review\scripts\deepseek-review.ps1'`, triagem, commit com assunto `feat(review): registrar-review grava a review Cross-Claude no marcador R11 (ps1 e sh)`.

---

### Task 5: Wrapper `percus-review-auto` (`.ps1` + `.sh`) — motivo do exit 4 e linha de registro no marcador

**Files:**
- Create: `plugin/percus-review/tests/percus-review-auto-registro.tests.ps1`
- Modify: `scripts/percus-review-auto.ps1:85-92` (caminho do registro), `:146-171` (helper de motivo), `:199-331` (4 rotas)
- Modify: `scripts/percus-review-auto.sh:86-93`, `:135-165`, `:230-331`
- Test (inalterado): `plugin/percus-review/tests/fact-check-resumo-honesto.tests.ps1` (recorta `function Invoke-FactCheck {` até `}` na coluna 0 — não mexa nessa função nem ponha `}` em coluna 0 dentro dela)

**Interfaces:**
- Consumes: `registrar-review.ps1`/`.sh` (Task 4) — só o caminho; exit 4 do cliente (Tasks 2/3); `_resolver-bash.ps1` (Task 1).
- Produces: marcadores `__PERCUS_NEEDS_CROSS_CLAUDE__` com a instrução de registro do contrato; `reason` do placeholder com `provedor indisponível após retry (exit 4)` ou `DeepSeek falhou (exit <n>)`; stderr do cliente repassado ao stderr do wrapper.

- [ ] **Step 1: Teste que falha** — `tests/percus-review-auto-registro.tests.ps1` (UTF-8 com BOM). Plugin falso num `CLAUDE_CONFIG_DIR` temporário (router e cliente falsos), wrapper REAL do kit:

```powershell
#requires -Version 5.1
# FR-007/008: com a DeepSeek fora, o wrapper pedia o subagente mas nao dizia como registrar a review
# dele. Aqui o wrapper real roda contra um plugin falso: router devolve a rota pedida, cliente sai
# com o exit pedido, e o teste le o placeholder e cada linha de marcador.

BeforeDiscovery {
    $script:casosPs1 = @(
        @{ Decisao = 'deepseek';     DsExit = 4; Placeholder = $true;  Motivo = 'retry' }
        @{ Decisao = 'deepseek';     DsExit = 1; Placeholder = $true;  Motivo = 'exit1' }
        @{ Decisao = 'dual';         DsExit = 4; Placeholder = $true;  Motivo = 'retry' }
        @{ Decisao = 'dual';         DsExit = 0; Placeholder = $false; Motivo = '' }
        @{ Decisao = 'council';      DsExit = 4; Placeholder = $true;  Motivo = 'retry' }
        @{ Decisao = 'cross-claude'; DsExit = 0; Placeholder = $true;  Motivo = '' }
    )
}

Describe "percus-review-auto -- exit 4 e instrucao de registro" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        $kit = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
        $kit = Split-Path $kit -Parent
        $script:wrapPs1 = Join-Path (Join-Path $kit 'scripts') 'percus-review-auto.ps1'
        $script:wrapSh  = ConvertTo-CaminhoBash (Join-Path (Join-Path $kit 'scripts') 'percus-review-auto.sh')
        $script:registrarKitPs1 = Join-Path (Join-Path (Join-Path (Join-Path $kit 'plugin') 'percus-review') 'scripts') 'registrar-review.ps1'
        $script:bash = Get-BashGit
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:u8bom = New-Object System.Text.UTF8Encoding($true)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-auto-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $script:textoRetry = 'provedor indispon' + [char]0x00ED + 'vel ap' + [char]0x00F3 + 's retry'

        function New-PluginFalso {
            param([switch]$SemRegistrar)
            $cfg = Join-Path $script:tmpBase ("cfg-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            $ver = $cfg
            foreach ($p in @('plugins', 'cache', 'percus-tools', 'percus-review', '9.9.9', 'scripts')) { $ver = Join-Path $ver $p }
            New-Item -ItemType Directory -Force -Path $ver | Out-Null
            [IO.File]::WriteAllText((Join-Path (Split-Path $ver -Parent) 'plugin.json'), '{"version":"9.9.9"}', $script:u8)
            [IO.File]::WriteAllText((Join-Path $ver 'review-router.ps1'), "param([switch]`$Json, [string]`$Base)`nWrite-Output `$env:FAKE_ROUTER_JSON`n", $script:u8bom)
            [IO.File]::WriteAllText((Join-Path $ver 'deepseek-review.ps1'), "param([string]`$Base)`n[Console]::Error.WriteLine('[deepseek-review] tentativa 1 falhou: HTTP 503. Nova tentativa em 1s.')`nWrite-Output 'Sem findings criticos.'`nexit ([int]`$env:FAKE_DS_EXIT)`n", $script:u8bom)
            [IO.File]::WriteAllText((Join-Path $ver 'review-router.sh'), "#!/usr/bin/env bash`nprintf '%s\n' `"`$FAKE_ROUTER_JSON`"`n", $script:u8)
            [IO.File]::WriteAllText((Join-Path $ver 'deepseek-review.sh'), "#!/usr/bin/env bash`necho '[deepseek-review] tentativa 1 falhou: HTTP 503. Nova tentativa em 1s.' >&2`necho 'Sem findings criticos.'`nexit `"`${FAKE_DS_EXIT:-0}`"`n", $script:u8)
            if (-not $SemRegistrar) {
                [IO.File]::WriteAllText((Join-Path $ver 'registrar-review.ps1'), "# falso`n", $script:u8bom)
                [IO.File]::WriteAllText((Join-Path $ver 'registrar-review.sh'), "#!/usr/bin/env bash`n", $script:u8)
            }
            return [pscustomobject]@{ Cfg = $cfg; Scripts = $ver }
        }

        function Invoke-Wrapper {
            param([ValidateSet('ps1','sh')][string]$Rt, $Plugin, [string]$Decisao, [int]$DsExit)
            $cwd = Join-Path $script:tmpBase ("w-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $cwd | Out-Null
            $router = '{"decision":"' + $Decisao + '","sensitive":true,"from_deepseek":false,"files_count":1,"warnings":[]}'
            $cfg = $Plugin.Cfg
            if ($Rt -eq 'sh') { $cfg = ConvertTo-CaminhoBash $cfg }
            $antigos = Set-EnvTemporario @{ CLAUDE_CONFIG_DIR = $cfg; FAKE_ROUTER_JSON = $router; FAKE_DS_EXIT = "$DsExit" }
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            Push-Location $cwd
            try {
                if ($Rt -eq 'ps1') { $null = & pwsh -NoProfile -File $script:wrapPs1 -NoFactCheck 2>$err }
                else { $null = & $script:bash -c ("cd '" + (ConvertTo-CaminhoBash $cwd) + "' && bash '" + $script:wrapSh + "' --no-fact-check") 2>$err }
                $code = $LASTEXITCODE
            } finally { Pop-Location; Restore-EnvTemporario $antigos }
            $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            $latest = Join-Path (Join-Path (Join-Path $cwd '.deepseek') 'reviews') 'latest.jsonl'
            $ph = $null
            if (Test-Path $latest) { $ph = [IO.File]::ReadAllText($latest, $script:u8).TrimStart([char]0xFEFF) | ConvertFrom-Json }
            $marcas = @($texto -split "`r?`n" | Where-Object { $_ -like '__PERCUS_NEEDS_CROSS_CLAUDE__*' })
            return [pscustomobject]@{ Code = $code; Err = $texto; Placeholder = $ph; Marcas = $marcas }
        }
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "<Rt> | decision=<Decisao> | deepseek exit <DsExit>" -ForEach @(
        foreach ($c in $script:casosPs1) { foreach ($rt in @('ps1', 'sh')) { $x = $c.Clone(); $x.Rt = $rt; $x } }
    ) {
        $pl = New-PluginFalso
        $r = Invoke-Wrapper -Rt $Rt -Plugin $pl -Decisao $Decisao -DsExit $DsExit
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Marcas.Count | Should -BeGreaterThan 0 -Because "toda rota desta tabela pede o subagente. stderr: $($r.Err)"
        $ext = $Rt
        $caminho = Join-Path $pl.Scripts ("registrar-review." + $ext)
        if ($Rt -eq 'sh') { $caminho = ConvertTo-CaminhoBash $caminho }
        $flag = '-Canal cross-claude'; if ($Rt -eq 'sh') { $flag = '--canal cross-claude' }
        foreach ($m in $r.Marcas) {
            $m | Should -Match 'registrar-review'
            $m.Contains($caminho) | Should -BeTrue -Because "caminho absoluto '$caminho' ausente em: $m"
            $m.Contains($flag) | Should -BeTrue
        }
        if ($Placeholder) {
            $r.Placeholder | Should -Not -BeNullOrEmpty
            $r.Placeholder.deferred | Should -BeTrue
            if ($Motivo -eq 'retry') { $r.Placeholder.reason | Should -Match ([regex]::Escape($script:textoRetry)) }
            if ($Motivo -eq 'exit1') { $r.Placeholder.reason | Should -Match '\(exit 1\)' }
        } else {
            $r.Placeholder | Should -BeNullOrEmpty
        }
        if ($Decisao -ne 'cross-claude') {
            $r.Err | Should -Match 'tentativa 1 falhou' -Because "o aviso de retry do cliente tem de chegar a quem roda o wrapper"
        }
    }

    It "<Rt>: plugin instalado sem registrar-review -> marcador aponta a copia do kit" -ForEach @(@{ Rt = 'ps1' }, @{ Rt = 'sh' }) {
        $pl = New-PluginFalso -SemRegistrar
        $r = Invoke-Wrapper -Rt $Rt -Plugin $pl -Decisao 'cross-claude' -DsExit 0
        $esperado = $script:registrarKitPs1
        if ($Rt -eq 'sh') { $esperado = ConvertTo-CaminhoBash ([IO.Path]::ChangeExtension($script:registrarKitPs1, '.sh')) }
        $r.Marcas.Count | Should -BeGreaterThan 0
        foreach ($m in $r.Marcas) { $m.Contains($esperado) | Should -BeTrue -Because "esperado '$esperado' em: $m" }
    }
}
```

  Nota: no Git Bash `pwd` devolve `/c/...`; o `.sh` normaliza com `pwd -W` (Step 4) para o caminho do kit sair na mesma forma `C:/...` que o teste espera.

- [ ] **Step 2: Rode e confirme a falha.** `Invoke-Pester -Path '.\plugin\percus-review\tests\percus-review-auto-registro.tests.ps1' -Output Detailed` → FAIL (marcador sem `registrar-review`, `reason` sem o texto do exit 4, stderr do cliente engolido).

- [ ] **Step 3: `percus-review-auto.ps1`.** (a) Depois de `$factCheckScript` (linha 87):

```powershell
# Comando de registro da review Cross-Claude (FR-008, 2026-09-14). Prefere a copia do plugin
# instalado; cache ainda sem o comando (plugin de versao anterior) -> copia do kit, que e onde este
# wrapper mora. Sem isto o agente despachava o subagente e nao tinha como gravar o resultado.
$registrarScript = Join-Path $current.FullName "scripts\registrar-review.ps1"
if (-not (Test-Path -LiteralPath $registrarScript)) {
    $registrarKit = Join-Path (Split-Path $PSScriptRoot -Parent) "plugin\percus-review\scripts\registrar-review.ps1"
    if (Test-Path -LiteralPath $registrarKit) { $registrarScript = $registrarKit }
}
$instrucaoRegistro = " Depois que o subagente responder, grave os findings dele num arquivo e registre com registrar-review: & '$registrarScript' -Arquivo '<arquivo-dos-findings>' -Canal cross-claude -Modelo '<modelo-do-subagente>'. Sem esse registro o commit so passa pelo placeholder de 5 min."

function Get-CausaFalhaDeepSeek {
    param([int]$Codigo)
    if ($Codigo -eq 4) { return ('provedor indispon' + [char]0x00ED + 'vel ap' + [char]0x00F3 + 's retry (exit 4)') }
    return "DeepSeek falhou (exit $Codigo)"
}
```

  (b) Nas 3 chamadas do cliente (rotas `deepseek`, `dual`, `council`), troque o filtro que DESCARTA o stderr por um que o REPASSA, e guarde o exit na hora:

```powershell
        $reviewOutput = & $PsExe -NoProfile -ExecutionPolicy Bypass -File $deepseekScript @deepseekArgs 2>&1 |
            ForEach-Object {
                # stderr do cliente (aviso de retry, 2000 caracteres do corpo, exit 4) vai para o
                # stderr do wrapper; antes era descartado e o agente so via "falhou".
                if ($_ -is [System.Management.Automation.ErrorRecord]) { [Console]::Error.WriteLine("$_") } else { $_ }
            } |
            Out-String
        $dsExit = $LASTEXITCODE
        if ($dsExit -ne 0) {
```

  (c) Nos `Write-DeferredReviewPlaceholder` das falhas, troque `DeepSeek falhou (exit $LASTEXITCODE) -- provável outage/API key inválida.` por `$(Get-CausaFalhaDeepSeek $dsExit) -- provável outage/API key inválida.` (mantendo o resto do texto de cada rota), e no `ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE)` use `$dsExit`. (d) Acrescente `$instrucaoRegistro` ao final das 5 strings `__PERCUS_NEEDS_CROSS_CLAUDE__` (deepseek-falha, dual-falha, dual-ok, cross-claude, council): `[Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: ... R11 cross-claude-review." + $instrucaoRegistro)`. (e) Atualize o `.NOTES` do cabeçalho: marcador traz o comando `registrar-review`.

- [ ] **Step 4: `percus-review-auto.sh`.** (a) Depois de `FACT_CHECK=` (linha 88):

```sh
# Comando de registro da review Cross-Claude (FR-008, 2026-09-14): copia do plugin instalado, ou a do
# kit (onde este wrapper mora) se o cache ainda nao tem o comando.
REGISTRAR="$CURRENT/scripts/registrar-review.sh"
if [ ! -f "$REGISTRAR" ]; then
    _KIT_DIR=$(cd "$(dirname "$0")/.." 2>/dev/null && { pwd -W 2>/dev/null || pwd; })
    if [ -f "$_KIT_DIR/plugin/percus-review/scripts/registrar-review.sh" ]; then
        REGISTRAR="$_KIT_DIR/plugin/percus-review/scripts/registrar-review.sh"
    fi
fi
INSTRUCAO_REGISTRO=" Depois que o subagente responder, grave os findings dele num arquivo e registre com registrar-review: bash '$REGISTRAR' --arquivo '<arquivo-dos-findings>' --canal cross-claude --modelo '<modelo-do-subagente>'. Sem esse registro o commit so passa pelo placeholder de 5 min."

causa_falha_deepseek() {
    if [ "$1" = "4" ]; then
        printf 'provedor indispon\303\255vel ap\303\263s retry (exit 4)'
    else
        printf 'DeepSeek falhou (exit %s)' "$1"
    fi
}
```

  (`pwd -W` devolve `C:/...` no Git Bash, igual à forma do `CLAUDE_CONFIG_DIR` que o teste passa; fora do Git Bash cai no `pwd`.) (b) Nas rotas `deepseek`, `dual`, `council` troque `REVIEW_OUTPUT=$(bash "$DEEPSEEK" $DEEPSEEK_ARGS 2>/dev/null)` + `if [ $? -ne 0 ]` por `REVIEW_OUTPUT=$(bash "$DEEPSEEK" $DEEPSEEK_ARGS)` / `DS_RC=$?` / `if [ "$DS_RC" -ne 0 ]` (o stderr do cliente passa direto). (c) Nas mensagens de falha e nos `reason`: `DeepSeek falhou -- provavel outage/API key invalida.` → `$(causa_falha_deepseek "$DS_RC") -- provavel outage/API key invalida.`; `deepseek-review.sh falhou --` → `deepseek-review.sh falhou (exit $DS_RC) --`. (d) Acrescente `$INSTRUCAO_REGISTRO` ao fim das 5 linhas `__PERCUS_NEEDS_CROSS_CLAUDE__` (as strings estão entre aspas duplas: `>&2 echo "__PERCUS_NEEDS_CROSS_CLAUDE__: ...R11).$INSTRUCAO_REGISTRO"`).

- [ ] **Step 5: Rode.** `percus-review-auto-registro.tests.ps1` → PASS (14 testes); `fact-check-resumo-honesto.tests.ps1`, `faixa-regras-derivada.tests.ps1`, `ps51-compat.tests.ps1`, `hooks-leitura-utf8.tests.ps1`, `pester-blocos-unicos.tests.ps1` → PASS. BOM de `percus-review-auto.ps1` preservado.

- [ ] **Step 6: Formato.** `git add -- scripts/percus-review-auto.ps1 scripts/percus-review-auto.sh plugin/percus-review/tests/percus-review-auto-registro.tests.ps1`; `git ls-files --eol -- scripts/percus-review-auto.sh` → `i/lf`; linhas adicionadas do `.sh` em ASCII (mesmo comando PowerShell das tasks anteriores, apontando `scripts/percus-review-auto.sh`).

- [ ] **Step 7: R11 + commit.** `& '.\plugin\percus-review\scripts\deepseek-review.ps1'`, triagem, commit com assunto `feat(review): wrapper distingue exit 4 e entrega o comando registrar-review no marcador Cross-Claude`.

---

### Task 6: Documentação, SC-007, suíte inteira e conferência final

**Files:**
- Modify: `01_REGRAS_INEGOCIAVEIS.md:468`
- Modify: `conhecimento/resolver/deepseek-review-2xx-sem-choices-nao-grava-review.md` (só o corpo)
- Modify: `CANON_VERSION.md` (nova seção antes de `## Changelog v6.53.0 — 2026-09-13`)

**Interfaces:**
- Consumes: tudo das Tasks 1-5; `.deepseek\r11-sem-ponto-unico\medir-latencia-hook.ps1` e `pre-commit-check-antigo.ps1` (pré-voo).
- Produces: nada consumido por código.

- [ ] **Step 1: R11 "Exceções declaráveis".** Troque a linha 468 (`- DeepSeek API down → router faz fallback automático pra Cross-Claude (declarar em voz alta)`) por:

```markdown
- DeepSeek API down → o cliente `deepseek-review` faz **1 retry automático** (timeout 180 s, backoff 5 s; `PERCUS_DEEPSEEK_TIMEOUT_S`/`PERCUS_DEEPSEEK_BACKOFF_S`). Se o provedor seguir indisponível (exit 4), o wrapper grava placeholder e emite `__PERCUS_NEEDS_CROSS_CLAUDE__` com o comando pronto: a review do subagente Sonnet é registrada com `registrar-review` (`-Canal cross-claude` / `--canal cross-claude`) e libera o commit pelo hash do diff. O placeholder sozinho libera **só por 5 min**, com aviso e uma linha em `.deepseek/reviews/deferidos.log` (declarar em voz alta)
```

- [ ] **Step 2: Verbete resolvido.** No arquivo do verbete, NÃO toque título nem linha de `tags`. Logo abaixo da linha de tags insira:

```markdown
**Status: RESOLVIDO em 2026-09-14** pela feature `r11-sem-ponto-unico` (spec
`docs/superpowers/specs/2026-09-14-r11-sem-ponto-unico-design.md`): o cliente passou a ter timeout e
1 retry, mostra no stderr os primeiros 2 000 caracteres do corpo (chave mascarada), grava
`.deepseek/reviews/ultimo-erro.txt` e sai **exit 4** sem marcador; a review Cross-Claude é gravada
com `registrar-review`. O texto abaixo descreve o comportamento ANTERIOR, mantido como histórico.
```

  Troque o bullet "Com autorização do operador, faça a review com um subagente Cross-Claude ... senão não casa." por `- Com autorização do operador, faça a review com um subagente Cross-Claude e registre com \`registrar-review\` (a linha pronta vem no marcador \`__PERCUS_NEEDS_CROSS_CLAUDE__\`); não calcule hash à mão.`, e o último bullet ("Melhoria do kit pendente...") por `- ~~Melhoria do kit pendente: logar o corpo da resposta quando \`choices\` vier nulo.~~ Feita (ver Status).` Não rode o gerador de índice.

- [ ] **Step 3: `CANON_VERSION.md`.** Não existe hoje seção "Pendente de versão" (conferido na base `c144aaf` e no checkout principal). Insira, imediatamente antes de `## Changelog v6.53.0 — 2026-09-13`:

```markdown
## Pendente de versão

> Entradas desta seção ainda não têm número: a versão é atribuída no merge para a `main` (sem bump
> em branch). Quem fizer o merge move a entrada para um `## Changelog vX.Y.Z` e bumpa.

### R11 sem ponto único de falha (branch `worktree-r11-fallback`, spec `docs/superpowers/specs/2026-09-14-r11-sem-ponto-unico-design.md`)

- **Cliente `deepseek-review.{ps1,sh}`:** timeout por chamada (padrão 180 s) e exatamente 1 retry
  (backoff 5 s) em timeout/rede, 429, 5xx e 2xx sem `choices`; 4xx ≠ 429 sai exit 1 sem retry;
  **exit 4** = provedor indisponível após retry. Corpo sem `choices` vai ao stderr (2 000 caracteres,
  chave mascarada) e a `.deepseek/reviews/ultimo-erro.txt`. O `.sh` passa a gravar `model`/`usage`.
- **Novo `registrar-review.{ps1,sh}`:** grava a review do subagente Cross-Claude em
  `d-<hash>.jsonl` + `latest.jsonl` (hash igual ao do hook, gravação atômica com rollback, telemetria).
- **Wrapper `percus-review-auto.{ps1,sh}`:** `reason` distingue exit 4; os 4 pontos do marcador
  `__PERCUS_NEEDS_CROSS_CLAUDE__` trazem a linha pronta do `registrar-review`; stderr do cliente visível.
- **Hook `pre-commit-check.{ps1,sh}` + `git-hooks/pre-commit.template.sh`:** o marcador passa a ser
  LIDO — só review com `findings` não vazio libera; placeholder libera por `latest.jsonl` ≤5 min com
  aviso e linha em `.deepseek/reviews/deferidos.log`; hash do diff vazio (`e3b0c44298fc`) não conta.
  **Projetos com o hook git instalado precisam reinstalar** (`/percus-review:install-git-hooks`, com
  `tr -d '\r'`) para ganhar a classificação.
- **Publicação:** mudança em `plugin/percus-review/hooks/` e `scripts/` do plugin exige publicação
  (ver topo deste arquivo); o wrapper do kit aponta para a cópia do kit do `registrar-review` enquanto
  o cache não a tiver.
```

- [ ] **Step 4: SC-007 no mesmo run.** Ferramenta PowerShell, primeiro plano:
  `& '.\.deepseek\r11-sem-ponto-unico\medir-latencia-hook.ps1' -Hooks @('.\.deepseek\r11-sem-ponto-unico\pre-commit-check-antigo.ps1', '.\plugin\percus-review\hooks\pre-commit-check.ps1') | Tee-Object '.\.deepseek\r11-sem-ponto-unico\latencia-final.txt'`
  Critério: mediana(novo) − mediana(antigo) ≤ 20 ms. Se passar de 20 ms, rode mais uma vez; persistindo, pare e reporte os números (não otimize às cegas).

- [ ] **Step 5: Suíte inteira.** Confira que nenhuma outra suíte roda (comando do pré-voo P2) e rode em primeiro plano, timeout 600000:
  `& '.\scripts\rodar-suite.ps1' *>&1 | Tee-Object -FilePath '.\.deepseek\r11-sem-ponto-unico\suite-final.txt'`
  Critério: toda falha está, por nome exato, na lista medida no pré-voo P2 (as conhecidas). Qualquer falha nova: pare e reporte com a mensagem. O total de testes cresce em ~175 (5 arquivos novos).

- [ ] **Step 6: Formato final.** Ferramenta Bash: `git ls-files --eol -- plugin/percus-review/scripts/deepseek-review.sh plugin/percus-review/scripts/registrar-review.sh scripts/percus-review-auto.sh plugin/percus-review/hooks/pre-commit-check.sh plugin/percus-review/git-hooks/pre-commit.template.sh` → `i/lf` em todos, exceto `pre-commit-check.sh` = `i/-text` (igual à base). Ferramenta PowerShell, linhas adicionadas desde a base em ASCII:

```powershell
$d = git diff c144aaf -U0 -- 'plugin/percus-review/scripts/deepseek-review.sh' 'plugin/percus-review/scripts/registrar-review.sh' 'scripts/percus-review-auto.sh' 'plugin/percus-review/hooks/pre-commit-check.sh' 'plugin/percus-review/git-hooks/pre-commit.template.sh'
@($d | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' -and $_ -match '[^\x09\x20-\x7E]' })
```
  Esperado vazio.

- [ ] **Step 7: Conferência do mapa de cobertura.** Percorra a tabela "Mapa de cobertura da spec" abaixo e, para cada linha, aponte o teste que passou na suíte final (nome do `It`). Linha sem teste verde = pare e reporte.

- [ ] **Step 8: Commit.** Só `.md`: o `pre-commit-check` dispensa review (política de risco); rode o R11 mesmo assim se o controlador pedir. `git add -- 01_REGRAS_INEGOCIAVEIS.md conhecimento/resolver/deepseek-review-2xx-sem-choices-nao-grava-review.md CANON_VERSION.md` e commit com assunto `docs(r11): retry + registrar-review na excecao do R11; verbete 2xx sem choices resolvido; pendente de versao`.

---

## Mapa de cobertura da spec

| Item | Task | Teste / verificação |
|---|---|---|
| US1 | 2, 3 | "1a falha por <Nome>, 2a responde" (ps1 e sh) |
| US2 | 4, 5 | "SC-006: registro Cross-Claude ... hook <Camada> libera pelo hash"; wrapper "decision=<Decisao> ... exit 4" |
| US3 | 2, 3 | "SC-003 ..." (ps1 e sh) |
| US4 | 1 | matriz `hash|<não-review>` e `latest|<inválido>` (motivo + `recusado`) |
| US5 | 1 | matriz `latest|placeholder` (aviso + `deferidos.log`) |
| FR-001 | 2, 3 | "precedencia <Nome>"; SC-005 |
| FR-002 | 2, 3 | "1a falha por <Nome>" (timeout, 429, 5xx, 2xx sem choices, corpo vazio) |
| FR-003 | 2, 3 | "HTTP <Status>: exatamente 1 requisicao"; "5xx e depois 401" |
| FR-004 | 2, 3 | "SC-003"; "HTTP <Status>" (chave mascarada); "corpo com acentos" |
| FR-005 | 2, 3 | exits 0/1/2/3/4 nos It de retry, 5xx, 401/404, content vazio/length, `-TimeoutSec 0` |
| FR-006 | 2, 3 | "200 com choices" (ps1: marcadores; sh: `model`/`usage`) |
| FR-007 | 5 | "decision=<Decisao> | deepseek exit 4/1" (`reason`) |
| FR-008 | 5 | mesmos It (cada marcador: nome, caminho absoluto, `-Canal`/`--canal`) + "sem registrar-review -> copia do kit" |
| FR-009 | 4 | "sucesso grava ... -Modelo"; "subdiretorio" |
| FR-010 | 4 | Context "recusas" (10 casos × 2) + "texto livre que so MENCIONA deferred" |
| FR-011 (+emenda) | 4, 2, 3 | "SC-006: hash identico"; "emenda FR-011" (cliente ps1 e sh); registro recusa diff vazio |
| FR-012 | 4 | "sucesso grava ..."; "falha ao gravar latest.jsonl -> exit 3"; "concorrencia" |
| FR-013 | 4 | "sucesso grava ..." (spend); "telemetria que falha nao muda o exit" |
| FR-014 | 4 | "sh sem jq: exit 1" |
| FR-015 | 1 | matriz (10 casos × 2 caminhos × 3 camadas); `acima-teto`; `bom` |
| FR-016 (+emenda) | 1 | matriz `hash|*`; "hash do diff vazio ... d-e3b0c44298fc"; `pre-commit-hash-validity` It 5 (>24 h) |
| FR-017 | 1 | matriz `latest|*`; "latest.jsonl invalido e velho bloqueia pelo TEMPO" |
| FR-018 | 1 | linhas `git` da matriz; "bloco awk e identico"; "copia CRLF" |
| FR-019 | 1 | "ps1: erro interno sai 0 com WARN no STDERR"; "deferidos.log que nao grava" |
| FR-020 | 6 | Steps 1-3 (conferência visual + commit) |
| SC-001 | 1 | matriz completa |
| SC-002 | 1, 6 | `pre-commit-hash-validity.tests.ps1` sem diff e verde |
| SC-003 | 2, 3 | "SC-003 ..." |
| SC-004 | 2, 3 | "1a falha por <Nome> ... tempo extra"; "HTTP <Status>" (401/404) |
| SC-005 | 2, 3 | "SC-005 ..." |
| SC-006 | 4 | "SC-006: hash identico"; "SC-006: registro ... libera pelo hash" |
| SC-007 | pré-voo, 6 | P3/P4 + Task 6 Step 4 |
| SC-008 | 6 | Steps 5-6 |

---

## Decisões de planejamento sobre pontos abertos da spec

- **Emendas do controlador** (hash vazio = sem hash) aplicadas em FR-011, FR-016 e §8. O §5 (último edge case, "sem `d-e3b0c44298fc.jsonl` que libere, decide por `latest.jsonl`") ficou sem emenda: o resultado observável é o mesmo, mas o texto sugere que tal arquivo poderia liberar — vale corrigir no merge.
- **Placeholder com `findings` junto:** a spec define review e placeholder sem ordem; o plano decide **placeholder primeiro** (lado seguro: nunca libera por hash).
- **"Trim" de whitespace** fixado em espaço, `\t`, `\n`, `\r` (literais ou escapados) para as 3 camadas darem o mesmo resultado; `ilegivel` é motivo extra para falha de leitura.
- **Trecho de 2 000 caracteres:** mascarar a chave ANTES de cortar (a spec não fixa a ordem; cortar antes pode vazar meia chave).
- **SC-005 "≤ 6 s":** medido como incremento sobre uma chamada normal no mesmo teste (a partida do pwsh/bash sozinha consome 0,5-1,5 s e tornaria o absoluto instável).
- **FR-008 caminho absoluto:** o wrapper do kit roda antes da publicação do plugin; o plano faz o marcador apontar para a cópia do kit quando o cache ainda não tem `registrar-review`.
- **Visibilidade do US1/US3 via wrapper:** o wrapper descartava o stderr do cliente; o plano o repassa (sem isso o aviso de retry e o corpo só aparecem rodando o cliente direto).
- **"Pendente de versão"** não existe em `CANON_VERSION.md` (base e checkout principal); a Task 6 cria a seção.
- **SC-008 "checagem ASCII/LF dos `.sh`":** não há teste na suíte que a faça, e três `.sh` tocados já têm bytes não-ASCII na base; o plano verifica índice LF e ASCII só das linhas adicionadas (Task 6 Step 6), sem criar guarda nova.

## Self-review (feito ao escrever)

- Cobertura: todo FR/SC/US tem linha no mapa acima com teste nomeado.
- Nomes cruzados conferidos: `Get-BashGit`, `ConvertTo-CaminhoBash`, `Copy-SemCR`, `Set-EnvTemporario`/`Restore-EnvTemporario` (Task 1 → 2, 3, 4, 5); `New-RespostaFalsa`/`Start-ServidorFalso`/`Get-ContagemServidorFalso`/`Stop-ServidorFalso` (Task 2 → 3); `-Arquivo -Canal -Modelo -Repo` / `--arquivo --canal --modelo --repo` (Task 4 → 5); strings de mensagem e motivos do bloco "Contratos".
- Armadilhas com código completo: PS 5.1/pwsh 7 (`ConvertFrom-Json` enumerando array, `$null` vs `[NullString]::Value`, `"${nome}:"`, EAP Stop com git), awk POSIX sem jq, heredoc em função, `set -e` com pipeline, `mv` para diretório, `HttpClient` com timeout, servidor falso em processo separado, gravação atômica com rollback.