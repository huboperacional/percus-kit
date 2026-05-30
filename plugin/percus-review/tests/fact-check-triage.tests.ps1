#requires -Version 5.1
# Testes do fact-check-triage.ps1 (Vetor B / v6.14.0).
#
# Triagem Llama upstream do Sonnet: classifica cada finding critico como
# PLAUSIVEL (coerente, nao precisa do Sonnet) ou SUSPEITA (duvidoso/exige ler
# codigo -> escalar pro Sonnet). Em duvida -> SUSPEITA (conservador).
#
# Testado OFFLINE: injeta um wrapper-stub via -Wrapper que devolve veredito
# canonico conforme marcador no texto do finding. NUNCA chama a API Groq real.

Describe "fact-check-triage.ps1 (Vetor B)" {
    BeforeAll {
        $script:script = Join-Path $PSScriptRoot ".." "scripts" "fact-check-triage.ps1"

        # Stub do wrapper groq-llama: mesma interface (-PromptFile -SystemPrompt ...),
        # devolve JSON {status,content} conforme marcador no prompt.
        $script:stubDir = Join-Path $env:TEMP "triage-stub-$(Get-Random)"
        New-Item -ItemType Directory -Force $stubDir | Out-Null

        $script:stubOk = Join-Path $stubDir "stub-ok.ps1"
        Set-Content -Path $stubOk -Encoding utf8 -Value @'
param([string]$PromptFile,[string]$SystemPrompt,[double]$Temperature,[int]$MaxTokens,[string]$Model,[string]$Endpoint)
$p = if ($PromptFile -and (Test-Path $PromptFile)) { Get-Content $PromptFile -Raw } else { [Console]::In.ReadToEnd() }
$verd = if ($p -match 'MARKER_PLAUSIVEL') { "PLAUSIVEL" } elseif ($p -match 'MARKER_SUSPEITA') { "SUSPEITA" } else { "SUSPEITA" }
@{ provider="groq-llama"; status="ok"; content="$verd`nrazao do veredito"; latency_ms=12 } | ConvertTo-Json -Compress
exit 0
'@

        $script:stubErr = Join-Path $stubDir "stub-err.ps1"
        Set-Content -Path $stubErr -Encoding utf8 -Value @'
param([string]$PromptFile,[string]$SystemPrompt,[double]$Temperature,[int]$MaxTokens,[string]$Model,[string]$Endpoint)
@{ provider="groq-llama"; status="error"; error="boom" } | ConvertTo-Json -Compress
exit 1
'@

        function Invoke-Triage {
            param([string]$Findings, [string]$Wrapper = $script:stubOk)
            $out = $Findings | & pwsh -NoProfile -File $script:script -Wrapper $Wrapper 2>&1
            $txt = ($out -join "`n")
            $json = $null
            try { $json = $txt | ConvertFrom-Json } catch { }
            return [pscustomobject]@{ Code = $LASTEXITCODE; Out = $txt; Json = $json }
        }

        $script:twoFindings = @'
[SEV: bug]
Arquivo: auth/handler.py:42
Problema: race condition no refresh do token MARKER_SUSPEITA

[SEV: risco]
Arquivo: utils/format.ts:10
Problema: typo no nome da constante exportada MARKER_PLAUSIVEL
'@
    }

    AfterAll {
        if (Test-Path $stubDir) { Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue }
    }

    It "existe" {
        Test-Path $script | Should -Be $true
    }

    It "1. particiona 2 findings: 1 PLAUSIVEL + 1 SUSPEITA" {
        $r = Invoke-Triage -Findings $twoFindings
        $r.Code | Should -Be 0
        $r.Json | Should -Not -BeNullOrEmpty
        $r.Json.triage_total     | Should -Be 2
        $r.Json.triage_plausivel | Should -Be 1
        $r.Json.triage_suspeita  | Should -Be 1
    }

    It "2. SUSPEITA e unverified entram em 'escalate' (vao pro Sonnet); PLAUSIVEL nao" {
        $r = Invoke-Triage -Findings $twoFindings
        @($r.Json.escalate).Count | Should -Be 1 -Because "so o finding SUSPEITA escala pro Sonnet"
        ($r.Json.escalate | ConvertTo-Json) | Should -Match "handler\.py"
    }

    It "3. wrapper com erro -> triage 'unverified' e escala (conservador, graceful)" {
        $one = "[SEV: bug]`nArquivo: x.py:1`nProblema: algo MARKER_PLAUSIVEL"
        $r = Invoke-Triage -Findings $one -Wrapper $script:stubErr
        $r.Code | Should -Be 0
        $r.Json.triage_unverified | Should -Be 1
        @($r.Json.escalate).Count  | Should -Be 1 -Because "em duvida, escala pro Sonnet"
    }

    It "4. input vazio -> JSON graceful (exit 0)" {
        $r = Invoke-Triage -Findings ""
        $r.Code | Should -Be 0
        $r.Json.triage_total | Should -Be 0
    }

    It "5. 'Sem findings criticos' -> skip graceful" {
        $r = Invoke-Triage -Findings "Sem findings criticos.`n`nDiff limpo."
        $r.Code | Should -Be 0
        $r.Json.triage_total | Should -Be 0
    }

    It "6. wrapper inexistente -> tudo unverified/escala (nao quebra)" {
        $r = Invoke-Triage -Findings "[SEV: bug]`nArquivo: a.py:1`nProblema: x MARKER_PLAUSIVEL" -Wrapper (Join-Path $stubDir "nao-existe.ps1")
        $r.Code | Should -Be 0
        $r.Json.triage_unverified | Should -Be 1
    }

    It "7. usa Llama/groq como triador (static)" {
        $c = Get-Content $script -Raw
        $c | Should -Match "(?i)groq|llama"
    }

    It "8. em duvida responde SUSPEITA (prompt conservador, static)" {
        $c = Get-Content $script -Raw
        $c | Should -Match "(?i)SUSPEITA"
        $c | Should -Match "(?i)d[uú]vida"
    }
}
