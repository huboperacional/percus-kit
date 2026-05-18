#requires -Version 5.1
<#
.SYNOPSIS
  Wrapper kit-level pra agente Claude Code auto-disparar /percus-review:review
  via Bash tool, sem precisar de paste do usuário no chat.

.DESCRIPTION
  Resolve plugin percus-review instalado a nível de usuário (CLAUDE_CONFIG_DIR
  ou ~/.claude default), localiza versão mais recente, dispatch via review-router
  + deepseek-review da versão instalada. Path absoluto estável -- agente chama
  por path direto (${env:PERCUS_CANON_DIR}/scripts/percus-review-auto.ps1).

  Quando decisão exige Cross-Claude (cross-claude ou dual), wrapper emite marker
  __PERCUS_NEEDS_CROSS_CLAUDE__ no stderr -- agente lê e dispatch Sonnet subagent
  via Agent tool (não dá pra fazer de PowerShell).

  F3 — Fact-check pipeline obrigatorio: apos reviewer principal, findings [SEV: risco|bug]
  sao validados via Sonnet fact-check. Findings INFUNDADO sao filtrados antes do output
  principal. Audit block preserva todos os veredictos. Opt-out via -NoFactCheck.

.PARAMETER Base
  Branch/commit base pra git diff. Default: vazio (usa staged + unstaged).

.PARAMETER NoFactCheck
  Desabilita fact-check pipeline (opt-out pra reviews triviais: doc-only, etc).

.EXAMPLE
  pwsh -File "${env:PERCUS_CANON_DIR}/scripts/percus-review-auto.ps1"
  pwsh -File "${env:PERCUS_CANON_DIR}/scripts/percus-review-auto.ps1" -Base main
  pwsh -File "${env:PERCUS_CANON_DIR}/scripts/percus-review-auto.ps1" -NoFactCheck

.NOTES
  Exit codes: 0 = success, 1 = plugin não encontrado, 2 = router falhou, 3 = deepseek-review falhou
#>
[CmdletBinding()]
param(
    [string]$Base = "",
    [switch]$NoFactCheck
)
$ErrorActionPreference = "Stop"

# Force UTF-8 console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# === Resolve PowerShell host (pwsh preferred, fallback to powershell.exe) ===
# pwsh = PowerShell Core 7+, available cross-platform.
# powershell.exe = Windows PowerShell 5.1, ships with Windows.
# Many Percus dev machines have only powershell.exe (no Core install).
# Without this fallback, wrapper crashes "pwsh: command not found" and forces
# users to declare PERCUS_HOOKS_DISABLED=1 to commit.
$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

# === Resolve plugin install path ===
$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
$pluginsDir = Join-Path $claudeHome "plugins\cache\percus-tools\percus-review"

if (-not (Test-Path $pluginsDir)) {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: plugin nao encontrado em $pluginsDir")
    [Console]::Error.WriteLine("Instale via /plugin install percus-review@percus-tools no chat 'claude' standalone.")
    exit 1
}

$current = Get-ChildItem $pluginsDir -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [Version]$_.Name } -Descending |
    Select-Object -First 1

if (-not $current) {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: nenhuma versao valida instalada em $pluginsDir")
    exit 1
}

[Console]::Error.WriteLine("[percus-review-auto] plugin v$($current.Name) em $($current.FullName)")

$routerScript   = Join-Path $current.FullName "scripts\review-router.ps1"
$deepseekScript = Join-Path $current.FullName "scripts\deepseek-review.ps1"
$factCheckScript = Join-Path $current.FullName "scripts\fact-check.ps1"

if (-not (Test-Path $routerScript)) {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: review-router.ps1 ausente em $($current.FullName)\scripts\")
    exit 1
}

# === Fact-check pipeline helper ===
# Recebe output do reviewer, passa pelo fact-check, emite filtered_output + audit block.
# Se fact-check nao disponivel ou -NoFactCheck, passa output direto.
function Invoke-FactCheck {
    param([string]$ReviewOutput, [switch]$Skip)

    if ($Skip -or $NoFactCheck) {
        [Console]::Error.WriteLine("[percus-review-auto] fact-check: skipped (--no-fact-check)")
        return $ReviewOutput
    }

    if (-not (Test-Path $factCheckScript)) {
        [Console]::Error.WriteLine("[percus-review-auto] WARN: fact-check.ps1 nao encontrado em $factCheckScript — passando output direto")
        return $ReviewOutput
    }

    [Console]::Error.WriteLine("[percus-review-auto] fact-check: iniciando pipeline F3...")
    $tmpFindings = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tmpFindings, $ReviewOutput, [System.Text.Encoding]::UTF8)
        $fcOut = & $PsExe -NoProfile -ExecutionPolicy Bypass -File $factCheckScript -FindingsFile $tmpFindings 2>&1
        $fcJson = $fcOut | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($fcJson -and $fcJson.filtered_output -ne $null) {
            $stats = "total=$($fcJson.findings_total) confirmado=$($fcJson.findings_confirmed) infundado=$($fcJson.findings_infundado) parcial=$($fcJson.findings_parcial)"
            [Console]::Error.WriteLine("[percus-review-auto] fact-check: $stats")
            if ($fcJson.findings_infundado -gt 0) {
                [Console]::Error.WriteLine("[percus-review-auto] WARN: $($fcJson.findings_infundado) finding(s) INFUNDADO(s) filtrado(s) do output principal — ver bloco Audit")
            }
            return $fcJson.filtered_output
        } else {
            [Console]::Error.WriteLine("[percus-review-auto] WARN: fact-check retornou JSON invalido — passando output original")
            return $ReviewOutput
        }
    } catch {
        [Console]::Error.WriteLine("[percus-review-auto] WARN: fact-check falhou: $($_.Exception.Message) — passando output original")
        return $ReviewOutput
    } finally {
        Remove-Item $tmpFindings -Force -ErrorAction SilentlyContinue
    }
}

# === Run router (decisão deepseek/cross-claude/dual) ===
$routerArgs = @("-Json")
if ($Base) { $routerArgs += @("-Base", $Base) }

$decisionJson = & $PsExe -NoProfile -ExecutionPolicy Bypass -File $routerScript @routerArgs 2>$null
if ($LASTEXITCODE -ne 0 -or -not $decisionJson) {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: router falhou (exit $LASTEXITCODE)")
    exit 2
}

try {
    $decision = $decisionJson | ConvertFrom-Json
} catch {
    [Console]::Error.WriteLine("[percus-review-auto] ERRO: router retornou JSON invalido: $decisionJson")
    exit 2
}

[Console]::Error.WriteLine("[percus-review-auto] decisao: $($decision.decision) (sensitive=$($decision.sensitive), from_deepseek=$($decision.from_deepseek), $($decision.files_count) arquivo(s))")

# === Dispatch ===
switch ($decision.decision) {
    "deepseek" {
        $deepseekArgs = @()
        if ($Base) { $deepseekArgs += @("-Base", $Base) }
        # Captura output do reviewer pra passar pelo fact-check pipeline (F3)
        $reviewOutput = & $PsExe -NoProfile -ExecutionPolicy Bypass -File $deepseekScript @deepseekArgs 2>&1 |
            Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } |
            Out-String
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("[percus-review-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE)")
            exit 3
        }
        # F3: fact-check pipeline obrigatorio
        $finalOutput = Invoke-FactCheck -ReviewOutput $reviewOutput
        Write-Output $finalOutput
    }

    "dual" {
        # Roda DeepSeek (cobre layer cheap), agente faz Sonnet via Agent tool
        $deepseekArgs = @()
        if ($Base) { $deepseekArgs += @("-Base", $Base) }
        # Captura output do reviewer pra passar pelo fact-check pipeline (F3)
        $reviewOutput = & $PsExe -NoProfile -ExecutionPolicy Bypass -File $deepseekScript @deepseekArgs 2>&1 |
            Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } |
            Out-String
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("[percus-review-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE)")
            exit 3
        }
        # F3: fact-check pipeline obrigatorio
        $finalOutput = Invoke-FactCheck -ReviewOutput $reviewOutput
        Write-Output $finalOutput
        [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: pasta sensitive detectada (decision=dual). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt R11 cross-claude-review.")
    }

    "cross-claude" {
        # R11: DeepSeek nao pode auto-revisar (commit veio dele). So Sonnet revisa.
        # Mas hook precisa de .jsonl em .deepseek/reviews/ pra liberar commit.
        # Solucao: agente vai dispatchar Sonnet e DEVE salvar saida em .deepseek/reviews/
        # via wrapper save-review (ou criar manualmente).
        # Nota: fact-check nao aplicavel aqui — nao ha output de reviewer local; Sonnet
        # subagent (dispatched via Agent tool) e responsavel por validar seus proprios findings.
        $reviewDir = ".deepseek\reviews"
        New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null
        $placeholderPath = Join-Path $reviewDir "$(Get-Date -Format 'yyyyMMdd-HHmmss')-deferred-cross-claude.jsonl"
        @{
            deferred = $true
            reason = "decision=cross-claude (commit from DeepSeek). R11 anti auto-revisao -- so Sonnet revisa."
            decision = $decision.decision
            timestamp = (Get-Date).ToString('o')
            placeholder = $true
            note = "Agente DEVE dispatchar Sonnet subagent agora; substituir este placeholder pelas findings reais."
        } | ConvertTo-Json -Compress | Set-Content -Path $placeholderPath -Encoding UTF8
        [Console]::Error.WriteLine("[percus-review-auto] placeholder escrito em $placeholderPath (libera hook por TTL)")
        [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: commit veio de DeepSeek (decision=cross-claude). DEVE dispatchar Sonnet subagent via Agent tool agora -- DeepSeek NAO revisa proprio output (R11).")
    }

    "council" {
        # Fase 6 v6.1.0+: roda DeepSeek (cobre .deepseek/reviews/ pro hook) + dispatch
        # orchestrator com Llama (Cross-Claude via marker pro agente).
        # 3 perspectivas em paralelo pra mudanca grande+sensivel ou pra revisar mudanca DS.
        $deepseekArgs = @()
        if ($Base) { $deepseekArgs += @("-Base", $Base) }
        # Captura output do reviewer pra passar pelo fact-check pipeline (F3)
        $reviewOutput = & $PsExe -NoProfile -ExecutionPolicy Bypass -File $deepseekScript @deepseekArgs 2>&1 |
            Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } |
            Out-String
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("[percus-review-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE)")
            exit 3
        }
        # F3: fact-check pipeline obrigatorio
        $finalOutput = Invoke-FactCheck -ReviewOutput $reviewOutput
        Write-Output $finalOutput

        # Tambem invoca Llama via orchestrator pra adicionar 3a perspectiva ao log council-log/
        $orchScript = Join-Path $current.FullName "scripts\council-orchestrator.ps1"
        if (Test-Path $orchScript) {
            # Construir prompt minimo de review pra orchestrator (Llama-only,
            # ja que DS rodou via deepseek-review e CC vai via marker abaixo).
            $diff = if ($Base) {
                (& git diff "$Base...HEAD" 2>$null) -join "`n"
            } else {
                $cached = (& git diff --cached 2>$null) -join "`n"
                $unstaged = (& git diff 2>$null) -join "`n"
                "$cached`n$unstaged".Trim()
            }
            if ($diff) {
                $tmpPrompt = [System.IO.Path]::GetTempFileName()
                "Revise o git diff abaixo no padrao Percus R1-R19. Aponte bugs, regressoes, mocks, violacoes de auth, imports vetados. Se nada relevante: 'Sem findings criticos'.`n`n---DIFF---`n$diff" | Out-File -FilePath $tmpPrompt -Encoding utf8 -NoNewline
                try {
                    & $PsExe -NoProfile -ExecutionPolicy Bypass -File $orchScript -PromptFile $tmpPrompt -Mode review -Providers "groq-llama" 2>$null | Out-Null
                    [Console]::Error.WriteLine("[percus-review-auto] orchestrator Llama executado (log em .deepseek/council-log/)")
                } catch {
                    [Console]::Error.WriteLine("[percus-review-auto] WARN: orchestrator Llama falhou: $_ (DeepSeek ja cobriu hook)")
                } finally {
                    Remove-Item $tmpPrompt -Force -ErrorAction SilentlyContinue
                }
            }
        }

        [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: decision=council (sensitive + grande/from-DS). DEVE dispatchar Sonnet subagent via Agent tool agora pra completar conselho 3-membros.")
    }

    default {
        [Console]::Error.WriteLine("[percus-review-auto] ERRO: decisao desconhecida do router: $($decision.decision)")
        exit 2
    }
}

exit 0
