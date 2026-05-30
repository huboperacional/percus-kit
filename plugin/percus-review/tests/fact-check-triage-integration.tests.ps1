#requires -Version 5.1
# Integracao da triagem Llama (Vetor B / v6.14.0) no fact-check.ps1.
#
# Modos via $env:PERCUS_FACTCHECK_TRIAGE:
#   OFF (default)  -> Sonnet em tudo, sem Llama, sem metricas, output historico.
#   "1"/"shadow"   -> Llama + Sonnet nos dois; loga concordancia; output INALTERADO.
#   "gate"         -> Llama plausivel PULA o Sonnet (economia).
#
# Stubs offline: cross-claude devolve sempre INFUNDADO (detector: se um finding sai
# INFUNDADO, o Sonnet rodou; se sai CONFIRMADO em gate, o Sonnet foi pulado).

Describe "fact-check.ps1 — integracao triagem Llama (Vetor B)" {
    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot ".." "scripts" "fact-check.ps1"
        $script:stubDir = Join-Path $env:TEMP "fc-integ-$(Get-Random)"
        New-Item -ItemType Directory -Force $stubDir | Out-Null

        # Stub cross-claude: SEMPRE INFUNDADO (detecta se o Sonnet rodou).
        $script:stubCC = Join-Path $stubDir "stub-cc.ps1"
        Set-Content -Path $stubCC -Encoding utf8 -Value @'
param([string]$PromptFile,[string]$Mode,[string]$SystemPrompt,[int]$MaxTokens,[string]$Model)
@{ status="ok"; content="INFUNDADO: stub refuta sempre" } | ConvertTo-Json -Compress
exit 0
'@
        # Stub groq-llama (triador): PLAUSIVEL/SUSPEITA conforme marcador.
        $script:stubTriage = Join-Path $stubDir "stub-triage.ps1"
        Set-Content -Path $stubTriage -Encoding utf8 -Value @'
param([string]$PromptFile,[string]$SystemPrompt,[double]$Temperature,[int]$MaxTokens,[string]$Model,[string]$Endpoint)
$p = if ($PromptFile -and (Test-Path $PromptFile)) { Get-Content $PromptFile -Raw } else { [Console]::In.ReadToEnd() }
$v = if ($p -match 'MARKER_PLAUSIVEL') { "PLAUSIVEL" } else { "SUSPEITA" }
@{ provider="groq-llama"; status="ok"; content="$v razao"; latency_ms=5 } | ConvertTo-Json -Compress
exit 0
'@

        function Invoke-FC {
            param([string]$Findings, [string]$Mode, [string]$MetricsDir)
            if ($Mode) { $env:PERCUS_FACTCHECK_TRIAGE = $Mode } else { Remove-Item env:PERCUS_FACTCHECK_TRIAGE -ErrorAction SilentlyContinue }
            $a = @('-Wrapper', $script:stubCC, '-TriageWrapper', $script:stubTriage)
            if ($MetricsDir) { $a += @('-MetricsDir', $MetricsDir) }
            $out = $Findings | & pwsh -NoProfile -File $script:scriptPath @a 2>&1
            Remove-Item env:PERCUS_FACTCHECK_TRIAGE -ErrorAction SilentlyContinue
            $txt = ($out -join "`n")
            $json = $null; try { $json = $txt | ConvertFrom-Json } catch { }
            return [pscustomobject]@{ Out = $txt; Json = $json }
        }

        function New-MetricsDir { $d = Join-Path $script:stubDir "m-$(Get-Random)"; New-Item -ItemType Directory -Force $d | Out-Null; return $d }

        $script:fPlausivel = "[SEV: bug]`nArquivo: a.py:1`nProblema: typo na constante MARKER_PLAUSIVEL"
        $script:fSuspeita  = "[SEV: bug]`nArquivo: b.py:2`nProblema: race condition MARKER_SUSPEITA"
    }

    AfterAll { if (Test-Path $stubDir) { Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue } }

    It "1. DEFAULT (triage OFF): Sonnet roda em tudo, output historico, sem metricas" {
        $md = New-MetricsDir
        $r = Invoke-FC -Findings $fPlausivel -Mode $null -MetricsDir $md
        $r.Json.audit[0].fact_check | Should -Be "INFUNDADO" -Because "sem triagem, Sonnet (stub) refuta"
        $r.Json.triage_mode | Should -Be "off"
        (Test-Path (Join-Path $md "factcheck-triage.jsonl")) | Should -Be $false -Because "OFF nao gera metricas"
    }

    It "2. SHADOW (=1): output INALTERADO (Sonnet ainda decide), mas grava metricas Llama-vs-Sonnet" {
        $md = New-MetricsDir
        $r = Invoke-FC -Findings $fPlausivel -Mode "1" -MetricsDir $md
        $r.Json.audit[0].fact_check | Should -Be "INFUNDADO" -Because "shadow NAO pula o Sonnet"
        $r.Json.triage_mode | Should -Be "1"
        $metrics = Join-Path $md "factcheck-triage.jsonl"
        (Test-Path $metrics) | Should -Be $true
        $line = (Get-Content $metrics -Raw)
        $line | Should -Match "plausivel"
        $line | Should -Match "INFUNDADO"
    }

    It "3. GATE (=gate) + PLAUSIVEL: Sonnet PULADO -> CONFIRMADO via triagem" {
        $md = New-MetricsDir
        $r = Invoke-FC -Findings $fPlausivel -Mode "gate" -MetricsDir $md
        $r.Json.audit[0].fact_check | Should -Be "CONFIRMADO" -Because "gate confia no Llama plausivel e pula o Sonnet (que diria INFUNDADO)"
        (Get-Content (Join-Path $md "factcheck-triage.jsonl") -Raw) | Should -Match "skipped"
    }

    It "4. GATE (=gate) + SUSPEITA: escala pro Sonnet -> INFUNDADO" {
        $md = New-MetricsDir
        $r = Invoke-FC -Findings $fSuspeita -Mode "gate" -MetricsDir $md
        $r.Json.audit[0].fact_check | Should -Be "INFUNDADO" -Because "suspeita escala pro Sonnet (stub refuta)"
    }

    It "5. param -MetricsDir/-TriageWrapper existem (static)" {
        $c = Get-Content $scriptPath -Raw
        $c | Should -Match "TriageWrapper"
        $c | Should -Match "PERCUS_FACTCHECK_TRIAGE"
    }
}
