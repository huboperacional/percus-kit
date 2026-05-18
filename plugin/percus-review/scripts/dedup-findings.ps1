#requires -Version 5.1
<#
.SYNOPSIS
  F5 — Dedup findings ecoados em PRs stackados.

.DESCRIPTION
  Recebe N findings raw (markdown) de multiplos reviews via pasta (-FindingsDir).
  Calcula hash MD5(file_path + primeiros_100_chars_descricao) por finding.
  Agrupa por hash e apresenta "1 finding unico, presente em N PRs" em vez de
  N confirmacoes aparentemente independentes.

  Output JSON estruturado:
  {
    total_raw, total_unique, duplicates_collapsed,
    groups: [{ hash, severity, file_path, description, occurrences, sources }],
    consolidated_md
  }

.PARAMETER FindingsDir
  Pasta com .md de findings (1 arquivo por PR — nome do arquivo = source name).

.EXAMPLE
  pwsh -File dedup-findings.ps1 -FindingsDir D:\reviews\pr-stack
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FindingsDir
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# === Empty / missing dir ===
if (-not (Test-Path $FindingsDir)) {
    @{ total_raw = 0; total_unique = 0; duplicates_collapsed = 0; groups = @(); consolidated_md = "" } | ConvertTo-Json -Depth 5
    exit 0
}

$mdFiles = Get-ChildItem -Path $FindingsDir -Filter "*.md" -File
if ($mdFiles.Count -eq 0) {
    @{ total_raw = 0; total_unique = 0; duplicates_collapsed = 0; groups = @(); consolidated_md = "" } | ConvertTo-Json -Depth 5
    exit 0
}

# === MD5 helper ===
function Get-Md5String {
    param([string]$Value)
    $md5    = [System.Security.Cryptography.MD5]::Create()
    $bytes  = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $hBytes = $md5.ComputeHash($bytes)
    $md5.Dispose()
    return -join ($hBytes | ForEach-Object { $_.ToString("x2") })
}

# === Parse findings de cada arquivo ===
# Pattern: bloco comecando em [SEV: risco|bug|preferencia|preferência] ate proximo [SEV: ou fim
$blockPattern = '(?ms)(\[SEV:\s*(risco|bug|prefer[eê]nci[ao])\][^\[]*?)(?=\[SEV:|$)'

$allFindings = [System.Collections.Generic.List[hashtable]]::new()

foreach ($file in $mdFiles) {
    $sourceName = $file.BaseName
    $content    = Get-Content $file.FullName -Raw

    $rxMatches = [regex]::Matches($content, $blockPattern)
    foreach ($m in $rxMatches) {
        $block = $m.Groups[1].Value.Trim()
        $sev   = $m.Groups[2].Value.Trim()

        if (-not $block) { continue }

        # Extrair file_path: qualquer token com extensao (py, ts, js, go, rb, java, sh, ps1 etc)
        $filePath = ""
        $fpMatch  = [regex]::Match($block, '(?:^|\s|`|")([A-Za-z0-9_./-]+\.[A-Za-z]{1,5}(?::\d+(?:-\d+)?)?)')
        if ($fpMatch.Success) {
            $filePath = $fpMatch.Groups[1].Value.Trim().Trim('`"')
        }

        # Hash: file_path + primeiros 100 chars da descricao (sem a tag [SEV:...])
        $descRaw    = [regex]::Replace($block, '^\[SEV:[^\]]+\]\s*', '').Trim()
        $descSlice  = $descRaw.Substring(0, [Math]::Min(100, $descRaw.Length))
        $hashInput  = "$filePath|$descSlice"
        $hash       = Get-Md5String -Value $hashInput

        $allFindings.Add(@{
            hash      = $hash
            severity  = $sev
            file_path = $filePath
            description = $block
            source    = $sourceName
        })
    }
}

# === Agrupar por hash ===
$grouped = $allFindings | Group-Object { $_.hash }

$groups = [System.Collections.Generic.List[hashtable]]::new()
foreach ($g in $grouped) {
    $first   = $g.Group[0]
    $sources = @($g.Group | ForEach-Object { $_.source } | Select-Object -Unique | Sort-Object)
    $groups.Add(@{
        hash        = $first.hash
        severity    = $first.severity
        file_path   = $first.file_path
        description = $first.description
        occurrences = $g.Count
        sources     = $sources
    })
}

# Ordenar grupos: mais ocorrencias primeiro, depois por severity
$sortedGroups = @($groups | Sort-Object { -$_.occurrences }, { $_.severity })

# === consolidated_md ===
$mdLines = [System.Collections.Generic.List[string]]::new()
$mdLines.Add("## Findings consolidados (deduplicados v6.7.0+)`n")

foreach ($g in $sortedGroups) {
    $header = "### [SEV: $($g.severity)] $($g.file_path)"
    $mdLines.Add($header)

    if ($g.occurrences -gt 1) {
        $sourcesJoined = $g.sources -join ", "
        $mdLines.Add("`n> **Mesmo finding presente em $($g.occurrences) PRs:** $sourcesJoined`n")
    }

    $mdLines.Add("$($g.description)`n")
    $mdLines.Add("---`n")
}

$consolidatedMd = $mdLines -join "`n"

# === Output final ===
@{
    total_raw            = $allFindings.Count
    total_unique         = $sortedGroups.Count
    duplicates_collapsed = $allFindings.Count - $sortedGroups.Count
    groups               = $sortedGroups
    consolidated_md      = $consolidatedMd
} | ConvertTo-Json -Depth 10 -Compress
