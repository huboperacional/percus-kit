#requires -Version 5.1
<#
.SYNOPSIS
  Diz se a medicao de semantica de hooks do harness ainda vale, ou se o chao se moveu.

.DESCRIPTION
  A Task 1 do plano 2 mediu comportamento NAO-DOCUMENTADO do harness (expansao de env var
  em command, coexistencia plugin x settings.json, matcher, stdin, SessionStart). Cada
  resposta vale contra UMA versao do harness e UMA versao do plugin instalado.

  Com autoUpdate ligado, a versao viva muda sozinha. Uma regra de decisao congelada contra
  um harness que ja nao esta instalado decide pelo motivo errado -- foi esse o risco que o
  pre-mortem levantou. Este script existe pra que "a medicao envelheceu" seja BARULHENTO.

  Nao usa ASCII estendido de proposito: .ps1 sem BOM e lido como ANSI pelo PowerShell 5.1
  (ver docs/superpowers/plans/2026-07-30-guardas-mortas-powershell-51.md).

.PARAMETER EstadoPath
  Caminho do snapshot .estado.json. Default: o da Task 1.

.EXAMPLE
  pwsh -File "D:\Claud Automations\percus-kit\scripts\revalidar-medicao.ps1"

.NOTES
  Exit codes: 0 = medicao ainda vale. 1 = divergiu, releia antes de confiar. 2 = erro de uso.
#>
[CmdletBinding()]
param(
    [string]$EstadoPath
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$PREFIXO = "[revalidar-medicao]"

function Escrever($msg)  { Write-Host "$PREFIXO $msg" }
function Gritar($msg)    { [Console]::Error.WriteLine("$PREFIXO $msg") }

# --- Resolve o snapshot -------------------------------------------------------
if (-not $EstadoPath) {
    $raiz = Split-Path -Parent $PSScriptRoot
    $EstadoPath = Join-Path $raiz "docs\superpowers\medicoes\2026-07-31-semantica-hooks-harness.estado.json"
}
if (-not (Test-Path -LiteralPath $EstadoPath)) {
    Gritar "snapshot nao encontrado: $EstadoPath"
    Gritar "Sem snapshot nao da pra dizer se a medicao envelheceu -- isso e um erro, nao um aviso."
    exit 2
}

try {
    $esperado = Get-Content -LiteralPath $EstadoPath -Raw | ConvertFrom-Json
} catch {
    Gritar "snapshot ilegivel ($EstadoPath): $($_.Exception.Message)"
    exit 2
}

# --- Observa o ambiente de hoje ----------------------------------------------
# Arquivo ilegivel conta como NAO-VERIFICADO, nunca como igual: a licao da Task 6 da fase 1.

$cfgDir = $env:CLAUDE_CONFIG_DIR
if (-not $cfgDir) { $cfgDir = Join-Path $env:USERPROFILE ".claude" }
if (-not (Test-Path -LiteralPath $cfgDir)) { $cfgDir = "D:\Claud Automations\.claude-home" }

$instaladosPath = Join-Path $cfgDir "plugins\installed_plugins.json"
if (-not (Test-Path -LiteralPath $instaladosPath)) {
    Gritar "installed_plugins.json nao encontrado em $instaladosPath -- NAO-VERIFICADO, nao 'esta igual'."
    exit 1
}

$entrada = $null
try {
    $instalados = Get-Content -LiteralPath $instaladosPath -Raw | ConvertFrom-Json
    $chave = $instalados.plugins.PSObject.Properties | Where-Object { $_.Name -like "percus-review@*" } | Select-Object -First 1
    if ($chave) { $entrada = @($chave.Value)[0] }
} catch {
    Gritar "installed_plugins.json ilegivel: $($_.Exception.Message) -- NAO-VERIFICADO."
    exit 1
}
if (-not $entrada) {
    Gritar "percus-review nao aparece em installed_plugins.json. O plugin foi desinstalado?"
    exit 1
}

$obsVersao = "$($entrada.version)"
$obsSha    = "$($entrada.gitCommitSha)"
$obsLeaf   = Split-Path -Leaf "$($entrada.installPath)"

$obsHarness = "(nao obtido)"
try {
    $saida = & claude --version 2>&1 | Out-String
    if ($saida -match '(\d+\.\d+\.\d+)') { $obsHarness = $matches[1] }
} catch {
    $obsHarness = "(nao obtido)"
}

$obsCaches = @()
$cacheDir = Join-Path $cfgDir "plugins\cache\percus-tools\percus-review"
if (Test-Path -LiteralPath $cacheDir) {
    $obsCaches = @(Get-ChildItem -LiteralPath $cacheDir -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Sort-Object)
}

# --- Compara ------------------------------------------------------------------
$esp = $esperado.ambiente
$divergencias = @()

if ($obsVersao -ne "$($esp.percus_review_instalado.version)") {
    $divergencias += [pscustomobject]@{
        Peso  = "PLUGIN"
        Campo = "versao do percus-review instalado"
        Antes = "$($esp.percus_review_instalado.version)"
        Agora = $obsVersao
    }
}
if ($obsSha -ne "$($esp.percus_review_instalado.gitCommitSha)") {
    $divergencias += [pscustomobject]@{
        Peso  = "PLUGIN"
        Campo = "gitCommitSha do plugin instalado"
        Antes = "$($esp.percus_review_instalado.gitCommitSha)"
        Agora = $obsSha
    }
}
if ($obsLeaf -ne "$($esp.percus_review_instalado.installPathLeaf)") {
    $divergencias += [pscustomobject]@{
        Peso  = "PLUGIN"
        Campo = "pasta de cache instalada"
        Antes = "$($esp.percus_review_instalado.installPathLeaf)"
        Agora = $obsLeaf
    }
}
if ($obsHarness -ne "$($esp.claude_code)") {
    $divergencias += [pscustomobject]@{
        Peso  = "HARNESS"
        Campo = "versao do Claude Code"
        Antes = "$($esp.claude_code)"
        Agora = $obsHarness
    }
}

# Pastas de cache orfas nao mudam semantica -- so avisam sobre entulho.
$espCaches = @($esp.cache_dirs | Sort-Object)
$difCache = Compare-Object -ReferenceObject $espCaches -DifferenceObject $obsCaches -ErrorAction SilentlyContinue

# --- Reporta ------------------------------------------------------------------
Escrever "snapshot: $EstadoPath (medido em $($esperado.medido_em))"
Escrever "harness: esperado $($esp.claude_code) / observado $obsHarness"
function Curto($sha) { if ("$sha".Length -ge 8) { "$sha".Substring(0, 8) } else { "$sha" } }
Escrever "plugin:  esperado $($esp.percus_review_instalado.version) ($(Curto $esp.percus_review_instalado.gitCommitSha)) / observado $obsVersao ($(Curto $obsSha))"

if ($difCache) {
    Escrever "aviso: as pastas de cache mudaram (esperado: $($espCaches -join ', ') / agora: $($obsCaches -join ', ')). Pasta orfa nao muda semantica -- e entulho, nao risco."
}

if ($divergencias.Count -eq 0) {
    Escrever "OK -- a medicao de $($esperado.medido_em) ainda vale para este ambiente."
    exit 0
}

Gritar ""
Gritar "A MEDICAO ENVELHECEU. O ambiente nao e mais o que foi medido:"
Gritar ""
foreach ($d in $divergencias) {
    Gritar ("  [{0}] {1}" -f $d.Peso, $d.Campo)
    Gritar ("           antes: {0}" -f $d.Antes)
    Gritar ("           agora: {0}" -f $d.Agora)
}
Gritar ""

$afetados = @()
if ($divergencias | Where-Object { $_.Peso -eq "PLUGIN" })  { $afetados += @($esperado.itens_dependentes.versao_do_plugin) }
if ($divergencias | Where-Object { $_.Peso -eq "HARNESS" }) { $afetados += @($esperado.itens_dependentes.versao_do_harness) }

Gritar "Itens da medicao que foram observados contra o ambiente antigo:"
foreach ($i in ($afetados | Sort-Object -Unique)) { Gritar "  - item $i" }
Gritar ""
Gritar "O que fazer: refazer esses itens em $($esperado.medicao) e atualizar o snapshot."
Gritar "O que NAO fazer: seguir com a Task 6 assumindo que a resposta continua valendo."
exit 1
