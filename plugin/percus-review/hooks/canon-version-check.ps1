#requires -Version 5.1
<#
.SYNOPSIS
  Pre-commit warn: avisa se canon_version dos system-prompt-*.md diverge do CANON_VERSION.md atual.

.DESCRIPTION
  Nao bloqueia commit (exit 0 sempre). Apenas warn em stderr pra operador revisar.
  Roda como pre-commit hook do git ou standalone.
#>
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$canonDir = $env:PERCUS_CANON_DIR
if (-not $canonDir) {
    [Console]::Error.WriteLine("[percus:hook canon-version] PERCUS_CANON_DIR nao setado - skip check")
    exit 0
}

$canonVersionFile = Join-Path $canonDir "CANON_VERSION.md"
if (-not (Test-Path $canonVersionFile)) {
    [Console]::Error.WriteLine("[percus:hook canon-version] CANON_VERSION.md nao encontrado em $canonDir - skip")
    exit 0
}

# Extrai versao atual do canon.
#
# -Encoding UTF8 NAO e decorativo. No PowerShell 5.1 -- que e o runtime real deste hook -- o
# default de Get-Content e ANSI (Windows-1252); no pwsh 7 e UTF-8. CANON_VERSION.md e UTF-8 SEM
# BOM (markdown nao usa BOM, e esta certo assim), entao sob 5.1 "versao canonica" chegava como
# "versAo canOnica" e o regex acentuado abaixo NAO CASAVA. O hook saia com "skip" e exit 0:
# guarda morta respondendo verde, medido em 2026-08-16.
#
# Note que a classe e diferente da do ps51-compat: la o problema e o .ps1 FONTE sem BOM nao
# PARSEAR; aqui o fonte parseia perfeitamente e o DADO lido e que chega corrompido. Botar BOM
# no .md nao e o conserto -- quem le e que tem de declarar o encoding.
$canonContent = Get-Content -Encoding UTF8 $canonVersionFile -Raw
$currentVersion = $null
if ($canonContent -match 'Vers[aã]o can[oô]nica em.*?`([\d\.]+)`') {
    $currentVersion = $matches[1]
}
if (-not $currentVersion) {
    [Console]::Error.WriteLine("[percus:hook canon-version] nao foi possivel extrair versao atual de CANON_VERSION.md - skip")
    exit 0
}

# Itera system-prompt-*.md
$baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path }
# UM child path por Join-Path: -AdditionalChildPath e do PS 6+. Este arquivo e um HOOK, e hook
# roda sob powershell.exe 5.1 -- com tres argumentos a linha lanca e o hook vira guarda morta.
$providersDir = Join-Path (Split-Path $baseDir -Parent) "providers"
$promptFiles = Get-ChildItem -Path $providersDir -Filter "system-prompt-*.md" -ErrorAction SilentlyContinue
if (-not $promptFiles) { exit 0 }

$divergent = @()
# Nota: canon_version nos system-prompt-*.md usa formato DATA (ex: 2026-05-17),
# enquanto CANON_VERSION.md usa SEMVER (ex: 6.5.2). Comparacao string vai SEMPRE
# divergir — isso e intencional: warn permanente lembra operador de revisar apos
# cada bump de versao. Para silenciar, bumpe canon_version no header YAML.
foreach ($f in $promptFiles) {
    $raw = Get-Content -Encoding UTF8 $f.FullName -Raw
    if ($raw -match '(?ms)^---\r?\n(.*?)\r?\n---') {
        $header = $matches[1]
        if ($header -match 'canon_version:\s*(\S+)') {
            $promptCanonVer = $matches[1]
            if ($promptCanonVer -ne $currentVersion) {
                $divergent += @{ File = $f.Name; PromptVer = $promptCanonVer; CanonVer = $currentVersion }
            }
        }
    }
}

if ($divergent.Count -gt 0) {
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("[percus:hook canon-version] AVISO: SystemPrompts podem estar desatualizados")
    foreach ($d in $divergent) {
        [Console]::Error.WriteLine("  - $($d.File): canon_version=$($d.PromptVer), canon atual=$($d.CanonVer)")
    }
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  Revise se ha novas regras (R-X) que precisam refletir no SystemPrompt enriquecido.")
    [Console]::Error.WriteLine("  Para silenciar: bumpe canon_version no header YAML apos revisar.")
    [Console]::Error.WriteLine("")
}

exit 0
