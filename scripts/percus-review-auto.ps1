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
  Exit codes: 0 = success (inclui deepseek-review falho -- placeholder deferred gravado,
  ver marker __PERCUS_NEEDS_CROSS_CLAUDE__ no stderr), 1 = plugin não encontrado, 2 = router falhou
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

# A versao real e a do plugin.json; o NOME DA PASTA reflete o ultimo republish e fica
# legitimamente atras (republish descartado em 01/07/2026 — ver CANON_VERSION.md).
# Logar so a pasta ja fez sessao de adocao reportar "drift" que nao existe.
$manifestVersion = "?"
$manifestPath = Join-Path $current.FullName "plugin.json"
if (Test-Path $manifestPath) {
    try { $manifestVersion = (Get-Content $manifestPath -Raw | ConvertFrom-Json).version } catch { $manifestVersion = "?" }
}
[Console]::Error.WriteLine("[percus-review-auto] plugin pasta=$($current.Name) plugin.json=$manifestVersion em $($current.FullName)")

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

# === Placeholder "deferred" em .deepseek/reviews/latest.jsonl ===
# Usado sempre que o registro real (findings de DeepSeek e/ou Cross-Claude) não pode
# ser persistido no momento em que o wrapper decide "dual"/"council" (ex.: DeepSeek
# fora do ar / API key inválida) -- SEM isto, o caminho antigo fazia `exit` direto
# nesse ponto, sem nunca gravar nada em .deepseek/reviews/ e sem emitir o marker de
# Cross-Claude. O gate de 5min (R11, pre-commit-check.ps1/.sh) então nunca achava
# registro fresco pro commit e bloqueava até o operador declarar PERCUS_HOOKS_DISABLED
# -- exatamente no caminho sensível (dual/council), que é o de maior risco. Mesmo
# padrão que já existia só pro caso "cross-claude": grava ANTES de emitir o marker/sair.
function Write-DeferredReviewPlaceholder {
    param([string]$Decision, [string]$Reason)
    $reviewDir = ".deepseek\reviews"
    New-Item -ItemType Directory -Path $reviewDir -Force | Out-Null
    $logFile = Join-Path $reviewDir 'latest.jsonl'
    $logTmp  = Join-Path $reviewDir 'latest.jsonl.tmp'
    @{
        deferred    = $true
        reason      = $Reason
        decision    = $Decision
        timestamp   = (Get-Date -Format 'o')
        placeholder = $true
        note        = "Agente DEVE dispatchar Sonnet subagent agora; substituir este placeholder pelas findings reais quando possível."
    } | ConvertTo-Json -Compress | Set-Content -Path $logTmp -Encoding UTF8
    Move-Item -Path $logTmp -Destination $logFile -Force
    [Console]::Error.WriteLine("[percus-review-auto] placeholder escrito em $logFile (libera hook por TTL)")
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

# Avisos do router (v6.31.0): o router e chamado com 2>$null, entao eles vem DENTRO
# do JSON. Rebaixamento silencioso por config quebrada foi o bug de 2026-07-27.
foreach ($w in @($decision.warnings)) {
    if ($w) { [Console]::Error.WriteLine("[percus-review-auto] WARN (router): $w") }
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
            # Mesmo fix dos branches dual/cross-claude/council: rota solo tambem nao pode
            # travar o commit inteiro so porque a chave DeepSeek caiu -- essa e a rota mais
            # comum do portfolio, entao `exit 3` aqui derrubava o review de TODOS os commits
            # nao-sensiveis. Conselho 3/3 (deepseek+llama+cross-claude, consult 2026-08-05)
            # confirmou: escalar pra Cross-Claude via marker, nao bloquear.
            [Console]::Error.WriteLine("[percus-review-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE) -- registrando placeholder deferred pra não travar o gate.")
            Write-DeferredReviewPlaceholder -Decision "deepseek" -Reason "decision=deepseek (rota solo), DeepSeek falhou (exit $LASTEXITCODE) -- provável outage/API key inválida. Sem segunda perna de review por padrão nesta rota; escalado pra Cross-Claude."
            [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: rota solo (decision=deepseek), DeepSeek indisponível. DEVE dispatchar Sonnet subagent via Agent tool agora com prompt de review R11 (escopo: commit atual).")
            break
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
            # DeepSeek falhou (outage/API key inválida/etc.). ANTES: `exit 3` aqui matava
            # o wrapper inteiro sem gravar nada em .deepseek/reviews/ e sem emitir o marker
            # -- gate de 5min nunca achava registro pro caminho dual, forçando escape manual
            # em TODO commit sensível. Fix: registra placeholder deferred e ainda sinaliza
            # Cross-Claude, pra R11 poder ser cumprido só pela perna que sobrou de pé.
            [Console]::Error.WriteLine("[percus-review-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE) -- registrando placeholder deferred pra não travar o gate.")
            Write-DeferredReviewPlaceholder -Decision "dual" -Reason "decision=dual, DeepSeek falhou (exit $LASTEXITCODE) -- provável outage/API key inválida. Registro parcial; Cross-Claude ainda precisa rodar (R11)."
            [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__: pasta sensitive detectada (decision=dual, DeepSeek indisponível). DEVE dispatchar Sonnet subagent via Agent tool agora com prompt R11 cross-claude-review.")
            break
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
        Write-DeferredReviewPlaceholder -Decision $decision.decision -Reason "decision=cross-claude (commit from DeepSeek). R11 anti auto-revisao -- so Sonnet revisa."
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
            # Mesmo fix do caso "dual" acima: DeepSeek fora do ar nao pode matar o
            # wrapper inteiro antes de registrar nada e antes do marker -- Llama e
            # Cross-Claude ainda cobrem o conselho enquanto DeepSeek estiver indisponivel.
            [Console]::Error.WriteLine("[percus-review-auto] ERRO: deepseek-review.ps1 falhou (exit $LASTEXITCODE) -- registrando placeholder deferred pra não travar o gate.")
            Write-DeferredReviewPlaceholder -Decision "council" -Reason "decision=council, DeepSeek falhou (exit $LASTEXITCODE) -- provável outage/API key inválida. Registro parcial; Llama/Cross-Claude cobrem o resto."
        } else {
            # F3: fact-check pipeline obrigatorio
            $finalOutput = Invoke-FactCheck -ReviewOutput $reviewOutput
            Write-Output $finalOutput
        }

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
