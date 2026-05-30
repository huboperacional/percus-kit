#requires -Version 5.1
# Hook pre-commit Percus crud-evidence-warn (R2 / v6.12.0). WARN-ONLY.
#
# Avisa (NUNCA bloqueia) quando o staged diff de PLANO.md/HANDOFF.md ADICIONA uma
# feature marcada [5-T] mas o `git commit` nao carrega o trailer
# `CRUD-verified: YYYY-MM-DD`. O trailer e a evidencia, no historico git, de que o
# ciclo CRUD com F5 (R1) foi rodado de fato -- em vez de [4-C] arredondado pra [5-T].
#
# Decisao do conselho (plano v6.11->v7.0): warn-only, SEM promocao automatica
# warn->block. Promover so sob pedido explicito do operador, apos soak.
#
# Skip: $env:PERCUS_SKIP_CRUD_WARN=1  (ou $env:PERCUS_HOOKS_DISABLED).
# Falha graceful: qualquer erro -> exit 0 (nunca trava o commit).
#
# NOTA: fonte 100% ASCII de proposito. PowerShell 5.1 le .ps1 sem BOM como cp1252;
# chars nao-ASCII em string literal (ex: em-dash) viram smart-quotes e quebram o
# parser. Os chars de matching (em-dash, emoji) vem de code point via [char].

. "$PSScriptRoot\_helpers.ps1"

function Get-CrudFeatureName {
    <#
      Extrai um nome legivel da linha de diff (sem o '+' inicial) que contem [5-T].
      Cobre bullets de PLANO e linhas de tabela de HANDOFF. Best-effort: serve pra
      apontar o humano pra feature, nao pra parsing rigoroso.
    #>
    param([string]$Line)

    # Chars nao-ASCII por code point (fonte ASCII-safe pra PS 5.1).
    $emDash = [char]0x2014   # em-dash
    $enDash = [char]0x2013   # en-dash

    $t = $Line.TrimStart('+').Trim()

    # Linha de tabela: pega a celula imediatamente antes da celula de status.
    if ($t.StartsWith('|')) {
        $cells = $t.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        for ($i = 0; $i -lt $cells.Count; $i++) {
            if ($cells[$i] -match '\[5-T\]') {
                if ($i -ge 1 -and $cells[$i - 1]) { return $cells[$i - 1] }
                break
            }
        }
    }

    # Bullet: remove marcador, tags `[..]`, marcacoes visuais; corta na descricao.
    $t = $t -replace '^[-*]\s+', ''
    $t = $t -replace '`?\[[0-9A-Za-z-]+\]`?', ''   # remove [5-T], [4-C], etc (com/sem crase)
    # Remove marcacoes visuais via String.Replace literal (surrogate-pair safe).
    $marks = @(
        [char]::ConvertFromUtf32(0x1F3A8),  # paleta (draft aprovado)
        [char]::ConvertFromUtf32(0x1F916),  # robo (delegado DeepSeek)
        [string][char]0x2713,               # check (reviewer aprovou)
        [string][char]0x2705,               # check verde (testado)
        '?', '!'
    )
    foreach ($m in $marks) { $t = $t.Replace($m, '') }
    # corta na separacao de descricao (em-dash / en-dash / duplo-hifen)
    $cutPattern = "\s+(?:$emDash|$enDash|--)\s+"
    $t = ($t -split $cutPattern, 2)[0]
    return $t.Trim()
}

$prevEnc = [Console]::OutputEncoding
try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $payload = $stdin | ConvertFrom-Json
    $command = $payload.tool_input.command
    if (-not $command) { exit 0 }

    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }
    if ($env:PERCUS_HOOKS_DISABLED -or $env:PERCUS_SKIP_CRUD_WARN) { exit 0 }

    $projectRoot = Resolve-PercusProjectRoot -Command $command
    if (-not (Test-Path (Join-Path $projectRoot ".git"))) { exit 0 }

    # Arquivos de tracking staged (PLANO.md / HANDOFF.md, em qualquer subpasta).
    $staged = Get-PercusStagedFiles -ProjectRoot $projectRoot
    if (-not $staged) { exit 0 }
    $trackingFiles = @($staged | Where-Object {
        $b = [System.IO.Path]::GetFileName($_)
        $b -eq 'PLANO.md' -or $b -eq 'HANDOFF.md'
    })
    if ($trackingFiles.Count -eq 0) { exit 0 }

    # Decodifica o diff do git em UTF-8 (sem isso, acentos/em-dash mojibakam; licao v6.8.1).
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $hits = @()
    foreach ($file in $trackingFiles) {
        $diff = & git -C $projectRoot diff --cached -- $file 2>$null
        if (-not $diff) { continue }
        $diffLines = $diff -split "`n"

        # Linhas [5-T] REMOVIDAS (normalizadas): se a mesma linha reaparece adicionada
        # (reformat/EOF-newline/reorder), nao e transicao nova -> nao avisa.
        $removed = New-Object System.Collections.Generic.HashSet[string]
        foreach ($line in $diffLines) {
            if ($line -match '^-' -and $line -notmatch '^---' -and $line -match '\[5-T\]') {
                [void]$removed.Add((($line.Substring(1)).Trim() -replace '\s+', ' '))
            }
        }

        foreach ($line in $diffLines) {
            if ($line -match '^\+' -and $line -notmatch '^\+\+\+' -and $line -match '\[5-T\]') {
                $norm = ($line.Substring(1)).Trim() -replace '\s+', ' '
                if ($removed.Contains($norm)) { continue }   # reformat: feature ja era [5-T]
                $name = Get-CrudFeatureName -Line $line
                if (-not $name) { $name = '(feature sem nome legivel)' }
                $hits += [pscustomobject]@{ File = $file; Name = $name }
            }
        }
    }

    if ($hits.Count -eq 0) { exit 0 }

    # Trailer presente no commit message? Entao a evidencia foi declarada -> silencioso.
    if ($command -match 'CRUD-verified:\s*\d{4}-\d{2}-\d{2}') { exit 0 }

    # -- WARN (exit 0) --------------------------------------------------------
    [Console]::Error.WriteLine("[percus:warn crud-evidence] feature(s) marcada(s) [5-T] sem trailer 'CRUD-verified: YYYY-MM-DD' neste commit:")
    foreach ($h in $hits) {
        [Console]::Error.WriteLine("  - `"$($h.Name)`" ($($h.File))")
    }
    [Console]::Error.WriteLine("Confirme o ciclo CRUD com F5 (R1: criar/editar/deletar + refresh) OU adicione o trailer 'CRUD-verified: <data>' no commit.")
    [Console]::Error.WriteLine("Silenciar: `$env:PERCUS_SKIP_CRUD_WARN=1 (warn-only; este aviso NAO bloqueia o commit).")

    # Log pro soak (mede adesao real: quantas vezes warn disparou).
    try {
        $logDir = Join-Path $projectRoot ".deepseek"
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $ts = Get-Date -Format 'o'
        $logFile = Join-Path $logDir "crud-warn.log"
        foreach ($h in $hits) {
            "$ts | crud-warn | $($h.File) | $($h.Name)" | Out-File -Append -FilePath $logFile -Encoding utf8
        }
    } catch { }

    exit 0
} catch {
    exit 0
} finally {
    [Console]::OutputEncoding = $prevEnc
}
