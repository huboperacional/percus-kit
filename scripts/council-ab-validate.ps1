#requires -Version 5.1
<#
.SYNOPSIS
  A/B validation: roda 3 consultas com config A vs 3 com config B, agrega.
.PARAMETER PromptFile
  Arquivo com prompt comum aos 6 runs.
.PARAMETER ConfigA
  String JSON: {"name":"baseline","args":["-Providers","deepseek,groq-llama"]}
.PARAMETER ConfigB
  String JSON: {"name":"truncation-8k","args":["-Providers","deepseek,groq-llama","-MaxInputTokens","8000"]}
.PARAMETER Out
  Path do markdown de saida.
#>
param(
    [Parameter(Mandatory)][string]$PromptFile,
    [Parameter(Mandatory)][string]$ConfigA,
    [Parameter(Mandatory)][string]$ConfigB,
    [string]$Out = "ab-validate-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
)
$orch = "${env:PERCUS_CANON_DIR}\plugin\percus-review\scripts\council-orchestrator.ps1"
if (-not (Test-Path $orch)) { Write-Error "Orchestrator nao encontrado: $orch"; exit 1 }
if (-not ($ConfigA | Test-Json -ErrorAction SilentlyContinue)) {
    Write-Error "-ConfigA nao e JSON valido: $ConfigA"; exit 1
}
if (-not ($ConfigB | Test-Json -ErrorAction SilentlyContinue)) {
    Write-Error "-ConfigB nao e JSON valido: $ConfigB"; exit 1
}
$a = $ConfigA | ConvertFrom-Json
$b = $ConfigB | ConvertFrom-Json

function Run-Config($cfg, $i) {
    $out = pwsh -NoProfile -File $orch -PromptFile $PromptFile @($cfg.args) 2>&1 | Out-String
    return @{ idx = $i; config = $cfg.name; output = $out }
}

$results = @()
for ($i = 1; $i -le 3; $i++) { $results += Run-Config $a $i }
for ($i = 1; $i -le 3; $i++) { $results += Run-Config $b $i }

$md = "# A/B validation $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`nPrompt: $PromptFile`n`n"
foreach ($r in $results) {
    $md += "## [$($r.config)] run $($r.idx)`n`n``````json`n$($r.output)`n```````n`n"
}
$md += "## Decisao manual`n`n- [ ] Qualidade B >= A? (sim/nao)`n- [ ] Custo B < A? (sim/nao)`n- [ ] Promover B a default? (sim/nao)`n"
Set-Content -Path $Out -Value $md -Encoding utf8
Write-Host "Wrote $Out"
