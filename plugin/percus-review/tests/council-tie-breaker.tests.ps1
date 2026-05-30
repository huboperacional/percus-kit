#requires -Version 5.1
# Testes do Vetor D (v6.14.0): Llama tie-breaker do conselho.
#
# Funcoes puras em scripts/council-tiebreaker.ps1 (dot-sourcavel, sem main body).
# Test-CouncilNeedsTieBreaker decide QUANDO chamar; Invoke-LlamaTieBreaker FAZ a chamada.
# Gatilho (decisao do operador): exatamente 2 providers OK, groq-llama NAO entre eles,
# e premise_validity divergente (>=1 nao-vazio). Conservador.

Describe "council-tiebreaker.ps1 (Vetor D)" {
    BeforeAll {
        $script:lib = Join-Path $PSScriptRoot ".." "scripts" "council-tiebreaker.ps1"
        if (Test-Path $lib) { . $lib }

        function Resp { param($provider,$status="ok",$pv="",$content="opiniao") @{ provider=$provider; status=$status; premise_validity=$pv; content=$content } }

        # stub groq-llama pro Invoke
        $script:stubDir = Join-Path $env:TEMP "tb-$(Get-Random)"; New-Item -ItemType Directory -Force $stubDir | Out-Null
        $script:stub = Join-Path $stubDir "stub.ps1"
        Set-Content -Path $stub -Encoding utf8 -Value @'
param([string]$PromptFile,[string]$SystemPrompt,[double]$Temperature,[int]$MaxTokens,[string]$Model,[string]$Endpoint)
@{ provider="groq-llama"; status="ok"; content="TIE-BREAK: deepseek mais defensavel"; latency_ms=9; model="llama-3.3-70b-versatile" } | ConvertTo-Json -Compress
exit 0
'@
    }
    AfterAll { if (Test-Path $stubDir) { Remove-Item -Recurse -Force $stubDir -ErrorAction SilentlyContinue } }

    It "lib existe" { Test-Path $lib | Should -Be $true }

    Context "Test-CouncilNeedsTieBreaker" {
        It "1. 2 OK sem llama + premise_validity divergente (ok vs invalid) -> TRUE" {
            $resp = @( (Resp "deepseek" "ok" "ok"), (Resp "cross-claude" "ok" "invalid") )
            Test-CouncilNeedsTieBreaker -Responses $resp | Should -Be $true
        }
        It "2. 2 OK sem llama mas mesma premise_validity -> FALSE" {
            $resp = @( (Resp "deepseek" "ok" "ok"), (Resp "cross-claude" "ok" "ok") )
            Test-CouncilNeedsTieBreaker -Responses $resp | Should -Be $false
        }
        It "3. 2 OK mas um deles E groq-llama -> FALSE (nao auto-chama llama de novo)" {
            $resp = @( (Resp "deepseek" "ok" "ok"), (Resp "groq-llama" "ok" "invalid") )
            Test-CouncilNeedsTieBreaker -Responses $resp | Should -Be $false
        }
        It "4. 3 OK -> FALSE" {
            $resp = @( (Resp "deepseek" "ok" "ok"), (Resp "cross-claude" "ok" "invalid"), (Resp "x" "ok" "unverified") )
            Test-CouncilNeedsTieBreaker -Responses $resp | Should -Be $false
        }
        It "5. so 1 OK -> FALSE" {
            $resp = @( (Resp "deepseek" "ok" "ok"), (Resp "cross-claude" "error" "") )
            Test-CouncilNeedsTieBreaker -Responses $resp | Should -Be $false
        }
        It "6. 2 OK sem llama mas ambos premise_validity vazio -> FALSE (sem sinal)" {
            $resp = @( (Resp "deepseek" "ok" ""), (Resp "cross-claude" "ok" "") )
            Test-CouncilNeedsTieBreaker -Responses $resp | Should -Be $false
        }
        It "7. responses vazio/null -> FALSE (graceful)" {
            Test-CouncilNeedsTieBreaker -Responses @() | Should -Be $false
        }
    }

    Context "Invoke-LlamaTieBreaker" {
        It "8. chama wrapper e retorna status ok + conteudo TIE-BREAK" {
            $resp = @( (Resp "deepseek" "ok" "ok" "renomear"), (Resp "cross-claude" "ok" "invalid" "nao renomear") )
            $tb = Invoke-LlamaTieBreaker -Responses $resp -UserPrompt "Devo renomear?" -Wrapper $script:stub -PsExe "pwsh"
            $tb.status | Should -Be "ok"
            $tb.content | Should -Match "TIE-BREAK"
        }
        It "9. wrapper ausente -> status error (graceful)" {
            $resp = @( (Resp "deepseek" "ok" "ok"), (Resp "cross-claude" "ok" "invalid") )
            $tb = Invoke-LlamaTieBreaker -Responses $resp -UserPrompt "x" -Wrapper (Join-Path $stubDir "nope.ps1") -PsExe "pwsh"
            $tb.status | Should -Be "error"
        }
    }
}
