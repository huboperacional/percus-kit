#requires -Version 5.1
# Hook Stop event Percus state-drift-check (R2 / R8 / v6.12.0).
#
# BLOQUEIA (exit 2) o encerramento da sessao quando uma feature tem tag de status
# DIVERGENTE entre docs/PLANO.md (fonte da verdade) e HANDOFF.md. Status
# desatualizado e mentira documentada (R8) -- pega o drift antes de fechar.
#
# CONSERVADOR por design (fail-open): so bloqueia quando casa o MESMO nome de
# feature (normalizado) nos dois arquivos com tags diferentes. Se nao consegue
# parsear/casar, NAO bloqueia. Qualquer erro -> exit 0.
#
# Skip: $env:PERCUS_SKIP_DRIFT_CHECK=1 (ou $env:PERCUS_HOOKS_DISABLED).

function Get-DriftCleanName {
    # Limpa o nome de uma feature pra exibicao/comparacao: remove tag, marcacoes
    # visuais, corta na descricao. Preserva caixa (a key normalizada e lowercased
    # pelo chamador). Chars nao-ASCII vem de code point (PS 5.1 source-safe).
    param([string]$Text)
    $emDash = [char]0x2014; $enDash = [char]0x2013
    $t = $Text.Trim()
    $t = $t -replace '`?\[[0-9A-Za-z-]+\]`?', ''   # remove tags [5-T] etc
    $marks = @(
        [char]::ConvertFromUtf32(0x1F3A8),  # paleta (draft aprovado)
        [char]::ConvertFromUtf32(0x1F916),  # robo (delegado DeepSeek)
        [string][char]0x2713,               # check (reviewer aprovou)
        [string][char]0x2705,               # check verde (testado)
        '?', '!'
    )
    foreach ($m in $marks) { $t = $t.Replace($m, '') }
    $t = ($t -split "\s+(?:$emDash|$enDash|--)\s+", 2)[0]
    return ($t.Trim() -replace '\s+', ' ')
}

function Get-DriftTag {
    param([string]$Text)
    if ($Text -match '\[([0-9A-Za-z-]+)\]') { return $matches[1] }
    return $null
}

function Add-DriftFeature {
    param([hashtable]$Map, [string]$Clean, [string]$Tag)
    if (-not $Clean -or -not $Tag) { return }
    $key = $Clean.ToLowerInvariant()
    if ($key -eq 'feature') { return }   # header da tabela
    if (-not $Map.ContainsKey($key)) {
        $Map[$key] = [pscustomobject]@{ Display = $Clean; Tags = (New-Object System.Collections.Generic.List[string]) }
    }
    if (-not $Map[$key].Tags.Contains($Tag)) { $Map[$key].Tags.Add($Tag) }
}

function Read-PlanoFeatures {
    # Bullets "- `[tag]` Nome -- desc" sob qualquer "## Frente:". Tabelas (Legenda)
    # comecam com '|' e sao ignoradas naturalmente.
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path $Path)) { return $map }
    foreach ($line in (Get-Content $Path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($line -match '^\s*[-*]\s+`?\[([0-9A-Za-z-]+)\]`?\s*(.*)$') {
            Add-DriftFeature -Map $map -Clean (Get-DriftCleanName $matches[2]) -Tag $matches[1]
        }
    }
    return $map
}

function Read-HandoffFeatures {
    # Tabela da secao "## Status de Features": | Frente | Feature | Status | ... |
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path $Path)) { return $map }
    $inSection = $false
    foreach ($line in (Get-Content $Path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($line -match '^\s*#{1,6}\s') {
            $inSection = ($line -match '(?i)status\s+de\s+features')
            continue
        }
        if (-not $inSection) { continue }
        $t = $line.Trim()
        if (-not $t.StartsWith('|')) { continue }
        if ($t -match '^\|[\s:\-\|]+$') { continue }   # separador |---|---|
        $cells = $t.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        if ($cells.Count -lt 2) { continue }
        $statusIdx = -1
        for ($i = 0; $i -lt $cells.Count; $i++) {
            if ($cells[$i] -match '\[[0-9A-Za-z-]+\]') { $statusIdx = $i; break }
        }
        if ($statusIdx -lt 1) { continue }   # precisa de uma celula de feature antes do status
        $tag = Get-DriftTag $cells[$statusIdx]
        Add-DriftFeature -Map $map -Clean (Get-DriftCleanName $cells[$statusIdx - 1]) -Tag $tag
    }
    return $map
}

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    if ($env:PERCUS_HOOKS_DISABLED -or $env:PERCUS_SKIP_DRIFT_CHECK) { exit 0 }

    $payload = $stdin | ConvertFrom-Json
    $cwd = $payload.cwd
    if (-not $cwd -or -not (Test-Path $cwd)) { $cwd = (Get-Location).Path }

    $planoPath = @(
        (Join-Path $cwd "docs/PLANO.md"),
        (Join-Path $cwd "PLANO.md")
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    $handoffPath = @(
        (Join-Path $cwd "docs/HANDOFF.md"),
        (Join-Path $cwd "HANDOFF.md")
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $planoPath -or -not $handoffPath) { exit 0 }   # nada pra comparar

    $plano   = Read-PlanoFeatures   $planoPath
    $handoff = Read-HandoffFeatures $handoffPath

    $drifts = @()
    foreach ($key in $plano.Keys) {
        if (-not $handoff.ContainsKey($key)) { continue }
        $pTags = $plano[$key].Tags
        $hTags = $handoff[$key].Tags
        if ($pTags.Count -ne 1 -or $hTags.Count -ne 1) { continue }  # ambiguo -> conservador
        if ($pTags[0] -ne $hTags[0]) {
            $drifts += [pscustomobject]@{
                Name    = $plano[$key].Display
                Plano   = $pTags[0]
                Handoff = $hTags[0]
            }
        }
    }

    if ($drifts.Count -eq 0) { exit 0 }

    [Console]::Error.WriteLine("[percus:hook state-drift] BLOCK: PLANO.md e HANDOFF.md divergem no status de $($drifts.Count) feature(s):")
    foreach ($d in $drifts) {
        [Console]::Error.WriteLine("  - `"$($d.Name)`": [$($d.Plano)] no PLANO vs [$($d.Handoff)] no HANDOFF")
    }
    [Console]::Error.WriteLine("Sincronize os dois (fonte da verdade = PLANO.md) antes de encerrar a sessao (R2/R8).")
    [Console]::Error.WriteLine("Pular: `$env:PERCUS_SKIP_DRIFT_CHECK=1 (declarar motivo em voz alta).")
    exit 2
} catch {
    exit 0
}
