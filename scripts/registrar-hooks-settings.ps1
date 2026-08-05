#requires -Version 5.1
<#
.SYNOPSIS
  Registra os hooks de enforcement Percus (guardas e/ou observadores) no settings.json,
  usando caminho absoluto para os wrappers do kit. Idempotente.
.DESCRIPTION
  ASCII PURO, sem excecao -- mesma disciplina do renomear-kit-local.ps1 (script irmao que
  mexe no mesmo settings.json): em dash dentro de string corrompe em PowerShell 5.1 sem BOM.

  Fonte da verdade dos hooks e hooks-manifest.json, dentro do proprio kit (plugin/percus-review/hooks/).

  Escopo por risco (Task 6 do plano 2 -- enforcement-nao-silencioso):
    Guardas       -- so os hooks PreToolUse. Seguro registrar junto com o hooks.json do
                     plugin, porque duplicar guarda so decide duas vezes o mesmo bloqueio.
    Observadores  -- os hooks Stop/PreCompact/SessionStart. So registrar depois de uma
                     publicacao do plugin que esvazie as entradas correspondentes do
                     hooks.json -- observador duplicado e efeito colateral duplicado de
                     verdade (ex.: POST duplicado), nao decisao redundante.
    Todos         -- todos os hooks registrados no manifesto. Para maquina onde o hooks.json
                     do plugin ja esta vazio.

  Valida a existencia de cada wrapper .cmd em disco ANTES de escrever qualquer coisa --
  registro parcial e pior que nenhum registro, porque mente sobre o que esta protegido.
#>
[CmdletBinding()]
param(
    [ValidateSet('Guardas','Observadores','Todos')]
    [string]$Escopo = 'Guardas',
    [string]$SettingsPath,
    [string]$KitRoot,
    [switch]$DryRun
)
$ErrorActionPreference = "Stop"

# Default calculado no corpo, nao no bloco param: mesma razao do renomear-kit-local.ps1 --
# expressao condicional em default de parametro e fragil entre PS 5.1 e 7.
if (-not $KitRoot) {
    $KitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $SettingsPath) {
    $claudeHome   = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
    $SettingsPath = Join-Path $claudeHome "settings.json"
}

$hooksDir     = Join-Path $KitRoot "plugin\percus-review\hooks"
$manifestPath = Join-Path $hooksDir "hooks-manifest.json"

if (-not (Test-Path $manifestPath)) { throw "manifesto nao encontrado: $manifestPath" }

$manifesto = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$vivos = @($manifesto.hooks | Where-Object { $_.registrado })

$formaAlvo = switch ($Escopo) {
    'Guardas'      { 'guarda' }
    'Observadores' { 'observador' }
    'Todos'        { $null }
}
if ($formaAlvo) {
    $vivos = @($vivos | Where-Object { $_.forma -ceq $formaAlvo })
}

# Fail-closed: confere TODOS antes de escrever qualquer coisa. Registro parcial mente sobre
# o que esta protegido -- licao do item 11 da medicao (command malformado tranca a maquina).
$faltando = New-Object System.Collections.Generic.List[string]
$hooks    = New-Object System.Collections.Generic.List[object]
foreach ($h in $vivos) {
    $cmdPath = Join-Path $hooksDir ($h.nome + ".cmd")
    if (-not (Test-Path $cmdPath)) {
        [void]$faltando.Add("$($h.nome): esperado em $cmdPath")
        continue
    }
    $absoluto = (Resolve-Path $cmdPath).Path
    $matcher  = if ($h.matcher) { "$($h.matcher)" } else { "" }
    [void]$hooks.Add([pscustomobject]@{
        Nome    = $h.nome
        Evento  = $h.evento
        Matcher = $matcher
        Command = $absoluto
        Forma   = $h.forma
    })
}

if ($faltando.Count -gt 0) {
    throw ("registro abortado: $($faltando.Count) hook(s) do manifesto sem wrapper .cmd em disco -- NADA foi gravado:`n" + ($faltando -join "`n"))
}

Write-Host "[registrar-hooks] $($hooks.Count) hook(s) no escopo '$Escopo', todos com wrapper confirmado em disco"
foreach ($h in $hooks) { Write-Host "[registrar-hooks]   - $($h.Nome) ($($h.Evento))" }

$settingsAtual = if (Test-Path $SettingsPath) {
    try { Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw "settings.json JA esta invalido antes de qualquer mudanca ($SettingsPath). Conserte o JSON primeiro. NADA foi registrado." }
} else {
    [pscustomobject]@{}
}

if (-not $settingsAtual.PSObject.Properties['hooks']) {
    $settingsAtual | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}

$adicionados = New-Object System.Collections.Generic.List[string]
$jaPresentes = New-Object System.Collections.Generic.List[string]

foreach ($h in $hooks) {
    if (-not $settingsAtual.hooks.PSObject.Properties[$h.Evento]) {
        $settingsAtual.hooks | Add-Member -NotePropertyName $h.Evento -NotePropertyValue @()
    }
    $blocos = @($settingsAtual.hooks.($h.Evento))

    $normAlvo = ($h.Command -replace '/', '\').ToLowerInvariant()
    $jaTem = $false
    foreach ($b in $blocos) {
        foreach ($hk in @($b.hooks)) {
            $normExistente = ("$($hk.command)".Trim('"') -replace '/', '\').ToLowerInvariant()
            if ($normExistente -eq $normAlvo) { $jaTem = $true; break }
        }
        if ($jaTem) { break }
    }

    if ($jaTem) {
        [void]$jaPresentes.Add($h.Nome)
        continue
    }

    $novoBloco = [pscustomobject]@{
        matcher = $h.Matcher
        hooks   = @([pscustomobject]@{ type = "command"; command = $h.Command })
    }
    $settingsAtual.hooks.($h.Evento) = @($blocos) + $novoBloco
    [void]$adicionados.Add($h.Nome)
}

if ($adicionados.Count -eq 0) {
    Write-Host "[registrar-hooks] nada novo -- todos os $($hooks.Count) hook(s) do escopo ja estavam registrados em $SettingsPath"
} else {
    Write-Host "[registrar-hooks] novo(s): $($adicionados -join ', ')"
}
if ($jaPresentes.Count -gt 0) {
    Write-Host "[registrar-hooks] ja presentes (pulados): $($jaPresentes -join ', ')"
}

$texto = $settingsAtual | ConvertTo-Json -Depth 20
try { $null = $texto | ConvertFrom-Json }
catch { throw "resultado seria JSON invalido -- NADA foi gravado em '$SettingsPath'" }

if ($DryRun) {
    Write-Host "[registrar-hooks] DRY RUN -- nada foi gravado. Conteudo proposto:"
    Write-Host $texto
    return
}

$backup = $null
if (Test-Path $SettingsPath) {
    $stamp  = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    $backup = "$SettingsPath.bak-$stamp"
    Copy-Item -LiteralPath $SettingsPath -Destination $backup
} else {
    $pai = Split-Path $SettingsPath -Parent
    if ($pai -and -not (Test-Path $pai)) { New-Item -ItemType Directory -Path $pai -Force | Out-Null }
}
[IO.File]::WriteAllText($SettingsPath, $texto, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[registrar-hooks] gravado em $SettingsPath$(if ($backup) { " (backup: $backup)" })"
