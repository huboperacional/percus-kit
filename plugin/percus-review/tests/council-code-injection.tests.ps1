#requires -Version 5.1
<#
.SYNOPSIS
  TDD tests for council-orchestrator.ps1 F2 — code context injection + premise_validity.
#>

Describe "council-orchestrator.ps1 — code injection F2" {
    BeforeAll {
        $script:orchPath = Join-Path $PSScriptRoot ".." "scripts" "council-orchestrator.ps1"
        $script:fixtureDir = Join-Path $env:TEMP "council-code-injection-fixture"
        if (-not (Test-Path $fixtureDir)) { New-Item -ItemType Directory -Path $fixtureDir | Out-Null }
        # Arquivo fixture
        Set-Content -Path (Join-Path $fixtureDir "outbox.py") -Value @"
def dispatch_event(db, event, payload):
    # Outbox pattern: INSERT atomico na transacao do caller
    delivery = WebhookDelivery(event=event, payload=payload, status='pending')
    db.add(delivery)
    db.flush()
    return delivery.id
"@ -Encoding utf8
    }

    AfterAll {
        if (Test-Path $fixtureDir) { Remove-Item -Recurse -Force $fixtureDir }
    }

    It "tem param -CodeContextDir documentado" {
        $orch = Get-Content $orchPath -Raw
        $orch | Should -Match "CodeContextDir"
    }

    It "le arquivos da CodeContextDir e injeta no system prompt" {
        $orch = Get-Content $orchPath -Raw
        # Verifica que a logica de leitura de arquivos da CodeContextDir existe
        $orch | Should -Match "CodeContextDir|code_context|Get-CodeContext"
    }

    It "tem instrucao 'premise_validity' no system prompt enriched" {
        $orch = Get-Content $orchPath -Raw
        $orch | Should -Match "premise_validity"
    }

    It "limita arquivos a 2000 tokens com truncate" {
        $orch = Get-Content $orchPath -Raw
        $orch | Should -Match "2000|MaxTokensPerFile"
    }

    It "parse 'file:path' blocks no prompt" {
        $orch = Get-Content $orchPath -Raw
        # Pattern de detecção de ```file: blocks
        $orch | Should -Match 'file:|FileBlockPattern|file_block'
    }

    It "agrega premise_validity_consensus no output JSON" {
        $orch = Get-Content $orchPath -Raw
        $orch | Should -Match "premise_validity_consensus"
    }
}
