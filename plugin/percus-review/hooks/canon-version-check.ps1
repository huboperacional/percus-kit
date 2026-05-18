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

# Extrai versao atual do canon
$canonContent = Get-Content $canonVersionFile -Raw
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
$providersDir = Join-Path $baseDir ".." "providers"
$promptFiles = Get-ChildItem -Path $providersDir -Filter "system-prompt-*.md" -ErrorAction SilentlyContinue
if (-not $promptFiles) { exit 0 }

$divergent = @()
# Nota: canon_version nos system-prompt-*.md usa formato DATA (ex: 2026-05-17),
# enquanto CANON_VERSION.md usa SEMVER (ex: 6.5.2). Comparacao string vai SEMPRE
# divergir — isso e intencional: warn permanente lembra operador de revisar apos
# cada bump de versao. Para silenciar, bumpe canon_version no header YAML.
foreach ($f in $promptFiles) {
    $raw = Get-Content $f.FullName -Raw
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
