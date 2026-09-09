#requires -Version 5.1
# Hook pre-commit Percus types-check (R5).
# Roda mypy --strict em arquivos .py staged + tsc --noEmit em arquivos .ts/.tsx staged.
# Best-effort: se mypy ou tsc nao disponiveis no projeto, skip silencioso.
# Skip: $env:PERCUS_SKIP_TYPES_CHECK=1.

. "$PSScriptRoot\_helpers.ps1"

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $payload = $stdin | ConvertFrom-Json
    $command = $payload.tool_input.command

    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }
    if ($env:PERCUS_HOOKS_DISABLED -or $env:PERCUS_SKIP_TYPES_CHECK) { exit 0 }

    $projectRoot = Resolve-PercusProjectRoot -Command $command
    if (-not (Test-Path (Join-Path $projectRoot ".git"))) { exit 0 }
    # Canonicaliza (achado no code-review, R11): Find-PercusNearestConfigDir devolve path
    # RESOLVIDO (via Resolve-Path). O walk-up de busca do tsc compara contra $projectRoot
    # pra saber quando parar -- se $projectRoot ficar CRU (a string literal do `cd "..."`
    # do comando: barra normal, trailing slash, symlink nao resolvido), a comparacao nunca
    # bate e a busca sobe alem da raiz do projeto, arriscando pegar um tsc.cmd de fora do repo.
    $projectRoot = (Resolve-Path $projectRoot).Path.TrimEnd('\', '/')

    $pyFiles = Get-PercusStagedFiles -ProjectRoot $projectRoot -Extensions @('.py')
    $tsFiles = Get-PercusStagedFiles -ProjectRoot $projectRoot -Extensions @('.ts','.tsx')

    $errors = @()
    $semTsconfig = @()   # .ts/.tsx staged sem tsconfig.json achavel (nao vira erro, mas fala)
    $semVenv = @()       # .py staged sem .venv achavel

    # Agrupa arquivos staged pelo diretorio MAIS PROXIMO (subindo a arvore a partir de
    # cada arquivo, parando em ProjectRoot) que tem o marker -- resolve monorepo
    # (tsconfig.json/.venv numa subpasta como frontend/ ou backend/, nao na raiz) sem
    # o hook precisar saber o layout. Ver Find-PercusNearestConfigDir.
    function Group-ByNearestConfig {
        param([string[]]$Files, [string]$Marker)
        $groups = @{}
        $semMatch = @()
        foreach ($f in $Files) {
            $dir = Find-PercusNearestConfigDir -ProjectRoot $projectRoot -RelativeFile $f -Marker $Marker
            if ($null -eq $dir) { $semMatch += $f; continue }
            if (-not $groups.ContainsKey($dir)) { $groups[$dir] = @() }
            $groups[$dir] += $f
        }
        return @{ Groups = $groups; SemMatch = $semMatch }
    }

    # ── mypy --strict ────────────────────────────────────────────────────
    if ($pyFiles -and $pyFiles.Count -gt 0) {
        $pyGrouped = Group-ByNearestConfig -Files $pyFiles -Marker ".venv"
        $semVenv = $pyGrouped.SemMatch

        foreach ($venvDir in $pyGrouped.Groups.Keys) {
            if ($errors.Count -ge 10) { break }
            # .venv achado NO diretorio (o marker JA E o proprio .venv) — binario sempre co-localizado.
            $mypyCmd = $null
            $venvMypy = Join-Path $venvDir ".venv\Scripts\mypy.exe"
            if (Test-Path $venvMypy) { $mypyCmd = $venvMypy }
            elseif (Get-Command mypy -ErrorAction SilentlyContinue) { $mypyCmd = "mypy" }
            if (-not $mypyCmd) { continue }

            $pyExisting = @($pyGrouped.Groups[$venvDir] | Where-Object { Test-Path (Join-Path $projectRoot $_) })
            if ($pyExisting.Count -eq 0) { continue }

            # Linhas REALMENTE adicionadas/mudadas por arquivo (ver
            # Get-PercusChangedLines): a trava é sobre o DIFF, não sobre o arquivo
            # staged inteiro -- legado sem type-check não pode bloquear um commit
            # que nem tocou a linha do erro. Chave normalizada com '\' pra bater
            # com o separador que mypy usa no Windows.
            #
            # ⚠️ `Get-PercusChangedLines` lê `git diff --cached` (staged), mas o
            # mypy abaixo roda sobre o ARQUIVO NO DISCO (working tree). Se houver
            # mudança NÃO staged no mesmo arquivo além do que foi indexado, os
            # números de linha podem divergir e um erro novo staged pode cair
            # fora do filtro por engano (achado do R11/DeepSeek). Mitigação
            # aceita por agora: o fluxo normal desta sessão sempre stagea antes
            # de checar, então a divergência é rara — documentado, não
            # resolvido; resolver de verdade exigiria rodar o mypy contra o
            # conteúdo do ÍNDICE (`git show :arquivo` em diretório temporário
            # espelhando a árvore, pra imports relativos resolverem).
            #
            # ⚠️ Limitação aceita, não resolvida (achado do R11/DeepSeek): o
            # filtro por linha só vê o erro cujo `.py:linha:` cai numa linha
            # ADICIONADA/MODIFICADA. Um erro real causado pela mudança mas que
            # aparece numa linha NÃO tocada do MESMO arquivo (ex.: mudar a
            # assinatura de uma função derruba tipagem num call-site antigo,
            # sem tocá-lo) passa em silêncio. Resolver de verdade exigiria
            # comparar contra o mypy rodado no HEAD anterior (baseline) e
            # bloquear só o que é NOVO na comparação -- mais caro (2 rodadas de
            # mypy) e fora do escopo desta correção, que já fecha o buraco
            # maior (758 erros do repo inteiro reportados por um diff de 6
            # arquivos). Prefira o veredito de `pytest`/review humana pra essa
            # classe de regressão até este ponto ser endereçado.
            $changedByFile = @{}
            foreach ($f in $pyExisting) {
                $changedByFile[$f.Replace('/', '\')] = Get-PercusChangedLines -ProjectRoot $projectRoot -RelPath $f
            }

            Push-Location $projectRoot
            try {
                # --follow-imports=silent: sem isto o mypy segue import e reporta
                # QUALQUER módulo do grafo de dependência (achado real: 758 erros
                # espalhados pelo repo inteiro a partir de meia dúzia de arquivos
                # staged) -- o gate vira impossível de satisfazer e nem é o que a
                # mensagem "erros em arquivos staged" promete.
                $mypyOut = & $mypyCmd --strict --follow-imports=silent --no-error-summary --show-error-codes @pyExisting 2>&1
                if ($LASTEXITCODE -ne 0) {
                    foreach ($l in ($mypyOut | Where-Object { $_ -match ': error:' })) {
                        if ($errors.Count -ge 10) { break }
                        # `.+` GANANCIOSO, não `.+?` (achado do R11/DeepSeek): um
                        # path absoluto com drive (`C:\proj\file.py:42: error:`)
                        # com quantificador PREGUIÇOSO ainda funciona por
                        # backtracking na prática, mas depender disso é frágil —
                        # ganancioso captura até o ÚLTIMO `:num:`, que é sempre o
                        # separador real de linha, goste o path do formato que for.
                        if ($l -match '^(.+):(\d+): error:') {
                            # Normaliza pro MESMO separador da chave acima --
                            # achado do R11/DeepSeek: sem isto, um mypy que
                            # devolvesse path com '/' faria TODO erro cair fora
                            # do filtro em silêncio (gate verde por engano, o
                            # pior tipo de falha pra um guard-rail).
                            $ef = $matches[1].Replace('/', '\')
                            $eln = [int]$matches[2]
                            $set = $changedByFile[$ef]
                            if ($set -and $set.Contains($eln)) {
                                $errors += "mypy :: $l"
                            }
                        }
                    }
                }
            } finally { Pop-Location }
        }
    }

    # Sem .venv achavel a partir de algum .py staged (best-effort continua best-effort,
    # mas falado -- skip silencioso e o pior dos dois mundos, finge que protegeu). Dispara
    # mesmo quando OUTROS .py staged acharam .venv e foram checados normalmente.
    if ($semVenv.Count -gt 0) {
        [Console]::Error.WriteLine("[percus:warn types-check] AVISO: $($semVenv.Count) arquivo(s) .py staged, mas nenhum .venv encontrado a partir deles -- checagem mypy PULADA. Isto nao e um 'ok'.")
    }

    # ── tsc --noEmit ─────────────────────────────────────────────────────
    if (($tsFiles -and $tsFiles.Count -gt 0) -and ($errors.Count -lt 10)) {
        $tsGrouped = Group-ByNearestConfig -Files $tsFiles -Marker "tsconfig.json"
        $semTsconfig = $tsGrouped.SemMatch

        $stagedSet = @{}
        foreach ($f in $tsFiles) { $stagedSet[$f.Replace('\','/')] = $true }

        foreach ($tsconfigDir in $tsGrouped.Groups.Keys) {
            if ($errors.Count -ge 10) { break }
            # tsc pode NAO estar co-localizado com o tsconfig (report Plexco #2) -- sobe
            # a partir do dir do tsconfig ate ProjectRoot procurando node_modules/.bin/tsc.
            $tscCmd = $null
            $walkDir = $tsconfigDir
            while ($walkDir) {
                $candidate = Join-Path $walkDir "node_modules\.bin\tsc.cmd"
                if (Test-Path $candidate) { $tscCmd = $candidate; break }
                if ($walkDir -eq $projectRoot.TrimEnd('\','/')) { break }
                $walkDir = Split-Path $walkDir -Parent
            }
            if (-not $tscCmd -and (Get-Command tsc -ErrorAction SilentlyContinue)) { $tscCmd = "tsc" }
            if (-not $tscCmd) { continue }

            $tsconfigPath = Join-Path $tsconfigDir "tsconfig.json"
            Push-Location $projectRoot
            try {
                # -p explicito (nao depende do CWD ter o tsconfig): path do erro sai
                # relativo ao CWD de invocacao com '/' -- confirmado empiricamente contra
                # TypeScript real, bate com o formato de $tsFiles (git diff --name-only).
                $tscOut = & $tscCmd -p $tsconfigPath --noEmit --pretty false 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $take = 10 - $errors.Count
                    $errLines = @($tscOut | Where-Object { $_ -match 'error TS\d+:' } | Where-Object {
                        $line = $_
                        $matched = $false
                        foreach ($s in $stagedSet.Keys) {
                            if ($line -match [regex]::Escape($s)) { $matched = $true; break }
                        }
                        $matched
                    } | Select-Object -First $take)
                    foreach ($l in $errLines) { $errors += "tsc :: $l" }
                }
            } finally { Pop-Location }
        }
    }

    if ($semTsconfig.Count -gt 0) {
        [Console]::Error.WriteLine("[percus:warn types-check] AVISO: $($semTsconfig.Count) arquivo(s) .ts/.tsx staged, mas nenhum tsconfig.json encontrado a partir deles -- checagem tsc PULADA. Isto nao e um 'ok'.")
    }

    if ($errors.Count -eq 0) { exit 0 }

    Write-PercusBlock -HookName 'types-check' -Lines (@(
        "$($errors.Count) erro(s) de tipo em arquivos staged (R5 — tipos explicitos, mypy --strict / tsc --noEmit)."
    ) + $errors + @(
        "Corrija os tipos OU use:",
        "  `$env:PERCUS_SKIP_TYPES_CHECK=1 (declarar motivo em voz alta)."
    ))
    exit 2
} catch {
    Write-Host "[percus:hook types-check] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
