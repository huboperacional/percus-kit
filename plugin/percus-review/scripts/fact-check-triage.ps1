#requires -Version 5.1
<#
.SYNOPSIS
  Vetor B (v6.14.0): triagem Llama upstream do fact-check Sonnet.

.DESCRIPTION
  Recebe o mesmo markdown de findings do reviewer (stdin ou -FindingsFile),
  parseia cada finding [SEV: risco|bug] e roda Llama 3.3 70B (via groq-llama
  wrapper) como TRIADOR conservador: cada claim vira PLAUSIVEL (coerente, nao
  precisa do Sonnet) ou SUSPEITA (duvidoso / exige ler codigo -> escalar pro
  Sonnet). Em duvida -> SUSPEITA.

  Objetivo: cortar o custo do Sonnet (item mais caro da pipeline) sem perder
  rigor onde importa. O gate (pular Sonnet nos PLAUSIVEL) e ATIVADO pelo
  fact-check.ps1 so apos calibracao (dual-run) — este script apenas triagem.

  Output JSON:
  {
    triage_total, triage_plausivel, triage_suspeita, triage_unverified,
    escalate: [ {severity,file_path,triage,reason,description}... ],  # SUSPEITA+unverified
    results:  [ ...todos... ]
  }

  Fonte 100% ASCII de proposito (PS 5.1 le .ps1 sem BOM como cp1252).

.PARAMETER FindingsFile
  Path pro markdown de findings. Se omitido, le stdin.

.PARAMETER Wrapper
  Path pro groq-llama.ps1. Default: providers/groq-llama.ps1 relativo a este script.

.PARAMETER Model
  Modelo Groq. Default: llama-3.3-70b-versatile.
#>
[CmdletBinding()]
param(
    [string]$FindingsFile,
    [string]$Wrapper = "",
    [string]$Model = "llama-3.3-70b-versatile"
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Write-EmptyTriage {
    param([string]$Reason = "")
    $o = [ordered]@{
        triage_total      = 0
        triage_plausivel  = 0
        triage_suspeita   = 0
        triage_unverified = 0
        escalate          = @()
        results           = @()
    }
    if ($Reason) { $o["skip_reason"] = $Reason }
    $o | ConvertTo-Json -Depth 6
    exit 0
}

# === Resolve wrapper path ===
if (-not $Wrapper) {
    $baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path }
    $Wrapper = Join-Path (Split-Path $baseDir) "providers\groq-llama.ps1"
}

# === Read input ===
if ($FindingsFile -and (Test-Path $FindingsFile)) {
    $findingsRaw = Get-Content $FindingsFile -Raw
} else {
    $findingsRaw = [Console]::In.ReadToEnd()
}

if (-not $findingsRaw -or $findingsRaw.Trim() -eq '') { Write-EmptyTriage }
if ($findingsRaw -match '(?i)Sem findings cr[ií]ticos') { Write-EmptyTriage -Reason "Sem findings criticos detectado no input" }

# === Parse findings ===
# NOTA: usa (?s) + .*? + \z (NAO o (?ms)...[^\[]*?...$ do fact-check.ps1, que em
# multiline trunca cada bloco no primeiro fim-de-linha -> bug latente reportado no
# handoff). Aqui o bloco vai do [SEV: risco|bug] ate o proximo [SEV:...] ou fim.
$findings = [System.Collections.Generic.List[hashtable]]::new()
$pattern = '(?s)(\[SEV:\s*(risco|bug)\].*?)(?=\[SEV:\s*(?:risco|bug)\]|\z)'
foreach ($m in [regex]::Matches($findingsRaw, $pattern)) {
    $block = $m.Groups[1].Value.Trim()
    $sev   = $m.Groups[2].Value.Trim()
    $filePath = ""
    if ($block -match '(?:^|\s|`|")([A-Za-z0-9_./-]+\.[A-Za-z]{1,5}(?::\d+(?:-\d+)?)?)') {
        $filePath = $Matches[1].Trim().Trim('`"')
    }
    $findings.Add(@{
        severity    = $sev
        file_path   = $filePath
        description = $block
        triage      = "unverified"
        reason      = ""
    })
}

if ($findings.Count -eq 0) { Write-EmptyTriage }

# === Triage prompt (conservador) ===
$systemPrompt = @"
Voce e triador de claims tecnicos sobre codigo. Para o claim recebido, responda com UMA palavra na PRIMEIRA linha:
- PLAUSIVEL  (claim coerente e provavelmente correto; nao exige ler o codigo pra confiar)
- SUSPEITA   (claim duvidoso, generico demais, ou que exige ler o codigo pra confirmar/refutar)
Em duvida, responda SUSPEITA. Depois da palavra, no maximo 1 frase de razao. Maximo 40 palavras no total.
"@

$wrapperAvailable = (Test-Path $Wrapper)
$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

foreach ($f in $findings) {
    if (-not $wrapperAvailable) {
        $f.triage = "unverified"
        $f.reason = "wrapper groq-llama.ps1 nao encontrado em: $Wrapper"
        continue
    }
    $userPrompt = "Claim do reviewer:`n$($f.description)`n`nArquivo citado: $($f.file_path)`n`nTriagem (comece com PLAUSIVEL ou SUSPEITA):"
    $tmpIn = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmpIn, $userPrompt, [System.Text.Encoding]::UTF8)
        $rawOut = & $PsExe -NoProfile -ExecutionPolicy Bypass -File $Wrapper `
            -PromptFile $tmpIn `
            -SystemPrompt $systemPrompt `
            -Model $Model `
            -MaxTokens 64 2>&1
        $json = $rawOut | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($json -and $json.status -eq "ok" -and $json.content) {
            $firstLine = (($json.content -split "`n") | Where-Object { $_.Trim() } | Select-Object -First 1)
            if ($firstLine -match '(?i)^\s*PLAUSIVEL') {
                $f.triage = "plausivel"
                if ($firstLine -match '(?i)PLAUSIVEL[:\s-]+(.+)') { $f.reason = $Matches[1].Trim() }
            } elseif ($firstLine -match '(?i)^\s*SUSPEITA') {
                $f.triage = "suspeita"
                if ($firstLine -match '(?i)SUSPEITA[:\s-]+(.+)') { $f.reason = $Matches[1].Trim() }
            } else {
                $f.triage = "unverified"
                $f.reason = "triador retornou formato inesperado"
            }
        } else {
            $f.triage = "unverified"
            $f.reason = if ($json.error) { "Llama error: $($json.error)" } else { "resposta nao parseavel do wrapper" }
        }
    } catch {
        $f.triage = "unverified"
        $f.reason = "excecao ao chamar wrapper: $($_.Exception.Message)"
    } finally {
        Remove-Item $tmpIn -Force -ErrorAction SilentlyContinue
    }
}

# === Particionar: PLAUSIVEL passa; SUSPEITA + unverified escalam pro Sonnet (conservador) ===
$plausivel  = @($findings | Where-Object { $_.triage -eq "plausivel" })
$suspeita   = @($findings | Where-Object { $_.triage -eq "suspeita" })
$unverified = @($findings | Where-Object { $_.triage -eq "unverified" })
$escalate   = @($findings | Where-Object { $_.triage -ne "plausivel" })

[ordered]@{
    triage_total      = $findings.Count
    triage_plausivel  = $plausivel.Count
    triage_suspeita   = $suspeita.Count
    triage_unverified = $unverified.Count
    escalate          = $escalate
    results           = @($findings)
} | ConvertTo-Json -Depth 10
exit 0
