#requires -Version 5.1
<#
.SYNOPSIS
  Bumpa a versao do kit Percus nos 7 pontos, de uma vez.

.DESCRIPTION
  A versao do kit mora em 7 lugares espalhados por 4 arquivos:

    CANON_VERSION.md                        cabecalho (fonte unica declarada, R25)
    CANON_VERSION.md                        secao de changelog da versao
    plugin/percus-review/plugin.json        .version
    plugin/percus-review/plugin.json        .description (abre com "vX.Y.Z | ")
    .claude-plugin/marketplace.json         plugins[0].version
    .claude-plugin/marketplace.json         plugins[0].description (mesmo prefixo)
    .percus-version                         versao adotada pelo repo

  Fazer isso na mao e o que produz drift: os 6 testes de version-alignment.tests.ps1
  existem justamente porque bumpar e esquecer um ponto ja aconteceu. Este script
  torna o caminho certo mais barato que o errado -- sem isso, o gate que exige bump
  vira estorvo e passa a ser escapado.

  Edita por regex no texto cru de proposito: reserializar o JSON reformataria o
  arquivo inteiro e produziria um diff ilegivel.

.EXAMPLE
  .\scripts\bump-canon.ps1 -Versao 6.36.0
  .\scripts\bump-canon.ps1 -Versao 6.36.0 -Raiz D:\caminho\do\canon -Data 2026-08-13
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Versao,
    [string]$Raiz = "",
    [string]$Data = ""
)

# Console UTF-8: o canon tem acento em tudo, e PS 5.1 no Windows abre em Win-1252.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $Raiz) { $Raiz = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path }
if (-not $Data) { $Data = (Get-Date -Format "yyyy-MM-dd") }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$fCanon  = Join-Path $Raiz "CANON_VERSION.md"
$fPlugin = Join-Path $Raiz "plugin/percus-review/plugin.json"
$fMarket = Join-Path $Raiz ".claude-plugin/marketplace.json"
$fVersao = Join-Path $Raiz ".percus-version"

# === VALIDACAO — antes de escrever qualquer coisa ===
if ($Versao -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "Versao '$Versao' invalida: use semver X.Y.Z (so numeros, tres partes)."
    exit 1
}

foreach ($f in @($fCanon, $fPlugin, $fMarket, $fVersao)) {
    if (-not (Test-Path $f)) { Write-Error "Nao achei '$f' -- a raiz '$Raiz' e mesmo o canon?"; exit 1 }
}

$canon = [IO.File]::ReadAllText($fCanon)
$mCab = [regex]::Match($canon, '(?m)^\*\*Vers.*`([0-9]+\.[0-9]+\.[0-9]+)`')
if (-not $mCab.Success) {
    Write-Error "Nao achei o cabecalho de versao em CANON_VERSION.md."
    exit 1
}
$atual = $mCab.Groups[1].Value

if ([version]$Versao -le [version]$atual) {
    Write-Error "Versao '$Versao' nao avanca: a atual e '$atual'. Bump pra tras ou repetido nao e suportado."
    exit 1
}

# Drift pre-existente aborta o bump. Sem isto o bump e PARCIAL e SILENCIOSO: o
# script troca a string da versao ANTIGA, entao o arquivo que ja estava divergente
# nao casa com o padrao e fica pra tras -- o drift sobrevive justamente ao comando
# que deveria elimina-lo.
function Get-VersaoDe {
    param([string]$Arquivo, [string]$Padrao)
    $txt = [IO.File]::ReadAllText($Arquivo)
    $m = [regex]::Match($txt, $Padrao)
    if ($m.Success) { return $m.Groups[1].Value }
    return "(nao encontrada)"
}

$padraoVersao = '"version"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"'
# A description duplica o numero de proposito (e o que aparece no painel de
# plugins), entao ela tambem pode driftar sozinha -- e driftaria calada, porque
# o prefixo e reescrito por regex que nao olha o valor antigo.
$padraoDesc = '"description"\s*:\s*"v([0-9]+\.[0-9]+\.[0-9]+) \|'

$encontradas = [ordered]@{
    "CANON_VERSION.md"              = $atual
    "plugin.json (version)"         = Get-VersaoDe $fPlugin $padraoVersao
    "plugin.json (description)"     = Get-VersaoDe $fPlugin $padraoDesc
    "marketplace.json (version)"    = Get-VersaoDe $fMarket $padraoVersao
    "marketplace.json (description)"= Get-VersaoDe $fMarket $padraoDesc
    ".percus-version"               = ([IO.File]::ReadAllText($fVersao)).Trim()
}
$divergentes = $encontradas.Keys | Where-Object { $encontradas[$_] -ne $atual }
if ($divergentes) {
    $detalhe = ($encontradas.Keys | ForEach-Object { "    $_ = $($encontradas[$_])" }) -join "`n"
    Write-Error "Drift entre os arquivos de versao -- conserte antes de bumpar:`n$detalhe"
    exit 1
}

# === ESCRITA ===
$canon = $canon -replace ('(?m)^(\*\*Vers.*)`' + [regex]::Escape($atual) + '`(.*)$'), ('${1}`' + $Versao + '`${2}')

$secao = "## Changelog v$Versao — $Data`n`n- (descreva a mudanca desta versao)`n`n"
$mChangelog = [regex]::Match($canon, '(?m)^## Changelog ')
if ($mChangelog.Success) {
    $canon = $canon.Insert($mChangelog.Index, $secao)
} else {
    $canon = $canon.TrimEnd() + "`n`n" + $secao
}
[IO.File]::WriteAllText($fCanon, $canon, $utf8)

foreach ($f in @($fPlugin, $fMarket)) {
    $txt = [IO.File]::ReadAllText($f)
    $txt = $txt -replace ('("version"\s*:\s*")' + [regex]::Escape($atual) + '(")'), ('${1}' + $Versao + '${2}')
    # A descricao duplica o numero de proposito -- e o que aparece no painel de plugins.
    $txt = $txt -replace '("description"\s*:\s*")v\d+\.\d+\.\d+ \| ', ('${1}v' + $Versao + ' | ')
    [IO.File]::WriteAllText($f, $txt, $utf8)
}

[IO.File]::WriteAllText($fVersao, "$Versao`n", $utf8)

Write-Host "Canon $atual -> $Versao"
Write-Host "  CANON_VERSION.md          cabecalho + secao de changelog (preencha a secao!)"
Write-Host "  plugin.json               version + description"
Write-Host "  marketplace.json          version + description"
Write-Host "  .percus-version           $Versao"
Write-Host ""
Write-Host "Agora: descreva a mudanca no changelog e rode"
Write-Host "  Invoke-Pester .\plugin\percus-review\tests\version-alignment.tests.ps1"
