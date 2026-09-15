# agy-falso.ps1 -- costura de teste para gemini-ler-longo.ps1 (nao declara param(): usa $args cru
# para nunca colidir com CommonParameters ambiguos como "-p" vs "-PipelineVariable").
#
# Duas chamadas simuladas:
#   1) "-p" "/usage"            -> imprime o texto de AGY_FALSO_USAGE_FIXTURE (ou um default) e sai.
#   2) protocolo stream-json    -> grava o stdin recebido em <AGY_FALSO_OUTDIR>\stdin-<n>.bin
#                                   (contador por arquivos existentes) e devolve o conteudo de
#                                   AGY_FALSO_FIXTURE, com o placeholder AGY_FALSO_CWD_PLACEHOLDER
#                                   trocado pelo cwd real deste processo (para o caso de teste que
#                                   confere init.cwd).

$isUsage = ($args -contains '/usage')

if ($isUsage) {
    $usageFixture = $env:AGY_FALSO_USAGE_FIXTURE
    if ($usageFixture -and (Test-Path -LiteralPath $usageFixture)) {
        [Console]::Out.Write([System.IO.File]::ReadAllText($usageFixture, [System.Text.Encoding]::UTF8))
    } else {
        [Console]::Out.Write("Gemini Models`tWeekly Limit Remaining`t0%`t2026-01-01T00:00:00Z`n")
    }
    exit 0
}

$outDir = $env:AGY_FALSO_OUTDIR
if (-not $outDir) { $outDir = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$existentes = @(Get-ChildItem -LiteralPath $outDir -Filter 'stdin-*.bin' -ErrorAction SilentlyContinue)
$n = $existentes.Count + 1
$stdinPath = Join-Path $outDir "stdin-$n.bin"

$stdinStream = [Console]::OpenStandardInput()
$memStream = New-Object System.IO.MemoryStream
$stdinStream.CopyTo($memStream)
[System.IO.File]::WriteAllBytes($stdinPath, $memStream.ToArray())

$fixturePath = $env:AGY_FALSO_FIXTURE
if (-not $fixturePath -or -not (Test-Path -LiteralPath $fixturePath)) {
    [Console]::Error.WriteLine("agy-falso: AGY_FALSO_FIXTURE nao definido ou nao existe: $fixturePath")
    exit 1
}

$conteudo = [System.IO.File]::ReadAllText($fixturePath, [System.Text.Encoding]::UTF8)
$cwdAtual = (Get-Location).Path
$cwdJson = $cwdAtual.Replace('\', '\\')
$conteudo = $conteudo.Replace('AGY_FALSO_CWD_PLACEHOLDER', $cwdJson)
[Console]::Out.Write($conteudo)
exit 0
