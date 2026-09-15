#requires -Version 5.1
# Fabrica um plugin percus-review falso (router + deepseek-review + registrar-review,
# ps1 e sh) sob um diretorio temporario, no layout que percus-review-auto.* e
# percus-milestone-review-auto.* esperam encontrar via CLAUDE_CONFIG_DIR.
#
# Extraido de percus-review-auto-registro.tests.ps1 (T1) pra ser reusado tambem por
# percus-milestone-review-auto.tests.ps1 (T2), sem mudar o comportamento: mesma
# estrutura de pastas, mesmo conteudo dos scripts falsos.

function New-PluginFalso {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TmpBase,
        [switch]$SemRegistrar
    )
    $u8 = New-Object System.Text.UTF8Encoding($false)
    $u8bom = New-Object System.Text.UTF8Encoding($true)
    $cfg = Join-Path $TmpBase ("cfg-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $ver = $cfg
    foreach ($p in @('plugins', 'cache', 'percus-tools', 'percus-review', '9.9.9', 'scripts')) { $ver = Join-Path $ver $p }
    New-Item -ItemType Directory -Force -Path $ver | Out-Null
    [IO.File]::WriteAllText((Join-Path (Split-Path $ver -Parent) 'plugin.json'), '{"version":"9.9.9"}', $u8)
    [IO.File]::WriteAllText((Join-Path $ver 'review-router.ps1'), "param([switch]`$Json, [string]`$Base)`nWrite-Output `$env:FAKE_ROUTER_JSON`n", $u8bom)
    [IO.File]::WriteAllText((Join-Path $ver 'deepseek-review.ps1'), "param([string]`$Base)`n[Console]::Error.WriteLine('[deepseek-review] tentativa 1 falhou: HTTP 503. Nova tentativa em 1s.')`nWrite-Output 'Sem findings criticos.'`nexit ([int]`$env:FAKE_DS_EXIT)`n", $u8bom)
    [IO.File]::WriteAllText((Join-Path $ver 'review-router.sh'), "#!/usr/bin/env bash`nprintf '%s\n' `"`$FAKE_ROUTER_JSON`"`n", $u8)
    [IO.File]::WriteAllText((Join-Path $ver 'deepseek-review.sh'), "#!/usr/bin/env bash`necho '[deepseek-review] tentativa 1 falhou: HTTP 503. Nova tentativa em 1s.' >&2`necho 'Sem findings criticos.'`nexit `"`${FAKE_DS_EXIT:-0}`"`n", $u8)
    if (-not $SemRegistrar) {
        [IO.File]::WriteAllText((Join-Path $ver 'registrar-review.ps1'), "# falso`n", $u8bom)
        [IO.File]::WriteAllText((Join-Path $ver 'registrar-review.sh'), "#!/usr/bin/env bash`n", $u8)
    }
    return [pscustomobject]@{ Cfg = $cfg; Scripts = $ver }
}
