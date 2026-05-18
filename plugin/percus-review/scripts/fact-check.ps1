#requires -Version 5.1
<#
.SYNOPSIS
  Fact-check pipeline F3 — valida findings criticos contra codigo real.

.DESCRIPTION
  Recebe via stdin (ou -FindingsFile) o output markdown do reviewer principal.
  Parse cada finding [SEV: risco|bug], dispara fact-check via cross-claude
  wrapper (Anthropic Sonnet), classifica CONFIRMADO|INFUNDADO|PARCIAL.
  Findings INFUNDADO sao filtrados do output principal mas preservados em audit.

  Output JSON estruturado:
  {
    findings_total, findings_confirmed, findings_infundado, findings_parcial,
    findings_unverified, filtered_output, audit: [...]
  }

.PARAMETER FindingsFile
  Path pro markdown de findings. Se omitido, le stdin.

.PARAMETER Wrapper
  Path pro cross-claude.ps1. Default: providers/cross-claude.ps1 relativo a este script.

.PARAMETER NoFactCheck
  Skip fact-check completo, retorna findings sem modificacao (opt-out pra reviews triviais).

.EXAMPLE
  Get-Content findings.md | pwsh -File fact-check.ps1
  pwsh -File fact-check.ps1 -FindingsFile findings.md
  pwsh -File fact-check.ps1 -NoFactCheck  # passa findings sem verificar
#>
[CmdletBinding()]
param(
    [string]$FindingsFile,
    [string]$Wrapper = "",
    [switch]$NoFactCheck
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# === Resolve wrapper path ===
if (-not $Wrapper) {
    $baseDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path $MyInvocation.MyCommand.Path }
    $Wrapper = Join-Path (Split-Path $baseDir) "providers\cross-claude.ps1"
}

# === Read input ===
if ($FindingsFile -and (Test-Path $FindingsFile)) {
    $findingsRaw = Get-Content $FindingsFile -Raw
} else {
    $findingsRaw = [Console]::In.ReadToEnd()
}

if (-not $findingsRaw -or $findingsRaw.Trim() -eq '') {
    @{
        findings_total    = 0
        findings_confirmed = 0
        findings_infundado = 0
        findings_parcial  = 0
        findings_unverified = 0
        filtered_output   = ""
        audit             = @()
    } | ConvertTo-Json -Depth 5
    exit 0
}

# === Opt-out: --no-fact-check passado ===
if ($NoFactCheck) {
    @{
        findings_total    = -1
        filtered_output   = $findingsRaw
        audit             = @()
        skipped           = $true
        skip_reason       = "NoFactCheck flag ativo"
    } | ConvertTo-Json -Depth 5
    exit 0
}

# === Quick skip: sem findings criticos ===
if ($findingsRaw -match '(?i)Sem findings cr[ií]ticos') {
    @{
        findings_total    = 0
        findings_confirmed = 0
        findings_infundado = 0
        findings_parcial  = 0
        findings_unverified = 0
        filtered_output   = $findingsRaw
        audit             = @()
        skipped           = $true
        skip_reason       = "Sem findings criticos detectado no input"
    } | ConvertTo-Json -Depth 5
    exit 0
}

# === Parse findings: blocos comecando com [SEV: risco] ou [SEV: bug] ===
# Cada bloco vai do [SEV: risco|bug] ate o proximo [SEV: ou fim
$findings = [System.Collections.Generic.List[hashtable]]::new()
$pattern = '(?ms)(\[SEV:\s*(risco|bug)\][^\[]*?)(?=\[SEV:|$)'
$regexMatches = [regex]::Matches($findingsRaw, $pattern)

foreach ($m in $regexMatches) {
    $block = $m.Groups[1].Value.Trim()
    $sev   = $m.Groups[2].Value.Trim()

    # Extrair file_path: padrao "arquivo.ext:N" ou backtick-path
    $filePath = ""
    # Tenta match de path com extensao (py, ts, js, go, rb, java, sh, ps1, etc) seguido de :N opcional
    if ($block -match '(?:^|\s|`|")([A-Za-z0-9_./-]+\.[A-Za-z]{1,5}(?::\d+(?:-\d+)?)?)') {
        $filePath = $Matches[1].Trim().Trim('`"')
    }

    $findings.Add(@{
        severity    = $sev
        file_path   = $filePath
        description = $block
        fact_check  = "unverified"
        reason      = ""
    })
}

# Sem findings criticos parseaveis
if ($findings.Count -eq 0) {
    @{
        findings_total    = 0
        findings_confirmed = 0
        findings_infundado = 0
        findings_parcial  = 0
        findings_unverified = 0
        filtered_output   = $findingsRaw
        audit             = @()
    } | ConvertTo-Json -Depth 5
    exit 0
}

# === Dispatch fact-check por finding via cross-claude wrapper ===
$wrapperAvailable = (Test-Path $Wrapper)

$systemPrompt = @"
Voce e fact-checker tecnico de codigo. Sua tarefa: validar se um claim tecnico sobre codigo e factualmente correto.
Voce vai receber o texto do finding com o claim e o path do arquivo citado (se houver).

Sua resposta DEVE comecar com exatamente UMA das seguintes palavras na primeira linha:
- CONFIRMADO  (claim e factualmente correto, leu o codigo e confirmou)
- INFUNDADO: <razao em 1 frase>  (claim e errado, leu o codigo e refutou)
- PARCIAL: <caveat em 1 frase>  (claim tem fundamento mas com nuance importante)

Se nao consegue verificar (arquivo nao existe, lib externa, sem path), responda:
INFUNDADO: nao foi possivel verificar (sem path verificavel ou arquivo ausente)

Maximo 100 palavras totais. Seja direto e objetivo.
"@

$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

foreach ($f in $findings) {
    if (-not $wrapperAvailable) {
        $f.fact_check = "unverified"
        $f.reason     = "wrapper cross-claude.ps1 nao encontrado em: $Wrapper"
        continue
    }

    $userPrompt = "Finding alega:`n$($f.description)`n`nArquivos citados: $($f.file_path)`n`nValide o claim. Resposta (comece com CONFIRMADO, INFUNDADO: ou PARCIAL:):"
    $tmpIn = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmpIn, $userPrompt, [System.Text.Encoding]::UTF8)

        $rawOut = & $PsExe -NoProfile -ExecutionPolicy Bypass -File $Wrapper `
            -PromptFile $tmpIn `
            -Mode review `
            -SystemPrompt $systemPrompt `
            -MaxTokens 256 2>&1

        $json = $rawOut | ConvertFrom-Json -ErrorAction SilentlyContinue

        if ($json -and $json.status -eq "ok" -and $json.content) {
            $firstLine = ($json.content -split "`n")[0].Trim()
            if ($firstLine -match '^CONFIRMADO') {
                $f.fact_check = "CONFIRMADO"
                # extrair razao opcional apos CONFIRMADO:
                if ($firstLine -match '^CONFIRMADO:\s*(.+)') { $f.reason = $Matches[1].Trim() }
            } elseif ($firstLine -match '^INFUNDADO:?\s*(.*)') {
                $f.fact_check = "INFUNDADO"
                $f.reason     = $Matches[1].Trim()
            } elseif ($firstLine -match '^PARCIAL:?\s*(.*)') {
                $f.fact_check = "PARCIAL"
                $f.reason     = $Matches[1].Trim()
            } else {
                $f.fact_check = "unverified"
                $f.reason     = "fact-checker retornou formato inesperado: $firstLine"
            }
        } elseif ($json -and $json.status -eq "error") {
            $f.fact_check = "unverified"
            $f.reason     = "API error: $($json.error)"
        } else {
            $f.fact_check = "unverified"
            $f.reason     = "resposta nao parseavel do wrapper"
        }
    } catch {
        $f.fact_check = "unverified"
        $f.reason     = "excecao ao chamar wrapper: $($_.Exception.Message)"
    } finally {
        Remove-Item $tmpIn -Force -ErrorAction SilentlyContinue
    }
}

# === Construir filtered_output: remove blocos INFUNDADO ===
$filtered = $findingsRaw
foreach ($f in $findings) {
    if ($f.fact_check -eq "INFUNDADO") {
        # Remove o bloco do output principal
        $escaped = [regex]::Escape($f.description)
        $filtered = [regex]::Replace($filtered, $escaped, "")
    }
}
# Limpar linhas em branco multiplas resultantes
$filtered = ($filtered -replace '(\r?\n){3,}', "`n`n").Trim()

# === Stats ===
$confirmed  = ($findings | Where-Object { $_.fact_check -eq "CONFIRMADO" }).Count
$infundado  = ($findings | Where-Object { $_.fact_check -eq "INFUNDADO"  }).Count
$parcial    = ($findings | Where-Object { $_.fact_check -eq "PARCIAL"    }).Count
$unverified = ($findings | Where-Object { $_.fact_check -eq "unverified" }).Count

# === Audit block markdown ===
$auditLines = [System.Collections.Generic.List[string]]::new()
$auditLines.Add("`n`n## Audit (fact-check v6.7.0+)`n")
$auditLines.Add("| Severity | File | Verdict | Reason |")
$auditLines.Add("|---|---|---|---|")
foreach ($f in $findings) {
    $verdictLabel = if ($f.fact_check -eq "INFUNDADO") { "**INFUNDADO** (filtrado)" } else { "**$($f.fact_check)**" }
    $reasonEsc = if ($f.reason) { $f.reason } else { "-" }
    $auditLines.Add("| $($f.severity) | $($f.file_path) | $verdictLabel | $reasonEsc |")
}
$auditBlock = $auditLines -join "`n"

# === Output final ===
@{
    findings_total      = $findings.Count
    findings_confirmed  = $confirmed
    findings_infundado  = $infundado
    findings_parcial    = $parcial
    findings_unverified = $unverified
    filtered_output     = $filtered + $auditBlock
    audit               = @($findings)
} | ConvertTo-Json -Depth 10 -Compress
