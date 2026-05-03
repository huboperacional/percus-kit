#requires -Version 5.1
# Hook pre-commit Percus (Layer 1 — UX dentro do Claude Code).
# Bloqueia commit sem /percus-review:review recente quando Claude executa via Bash tool.
# Falha graceful: qualquer erro -> exit 0.
#
# IMPORTANTE: este hook tem brecha conhecida em comandos bash compostos
# (ex: `rm -rf .deepseek/reviews && git commit`) porque PreToolUse avalia o estado
# UMA vez antes do bash rodar e nao observa mudancas durante a execucao.
# Layer 2 (anti-bypass) eh `.git/hooks/pre-commit` nativo do git, instalado por
# `/percus-review:install-git-hooks` no projeto-alvo. Ver git-hooks/pre-commit.template.sh.

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $command = $input.tool_input.command

    # Não-commit -> libera
    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }

    # Amend sem edit (rebase) -> libera
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }

    # Escape pro user (motivo declarado em voz alta)
    if ($env:PERCUS_HOOKS_DISABLED) { exit 0 }

    # Procurar review recente
    $cwd = (Get-Location).Path
    $reviewDir = Join-Path $cwd ".deepseek/reviews"
    if (-not (Test-Path $reviewDir)) {
        [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: nenhum /percus-review:review encontrado em .deepseek/reviews/")
        [Console]::Error.WriteLine("Rode /percus-review:review antes de commitar (R11).")
        exit 2
    }

    $latest = Get-ChildItem $reviewDir -Filter "*.jsonl" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: pasta .deepseek/reviews/ vazia")
        [Console]::Error.WriteLine("Rode /percus-review:review antes de commitar (R11).")
        exit 2
    }

    $age = (Get-Date) - $latest.LastWriteTime
    if ($age.TotalMinutes -gt 5) {
        $mins = [math]::Round($age.TotalMinutes, 1)
        [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: ultimo /percus-review:review tem $mins min (max 5).")
        [Console]::Error.WriteLine("Rode /percus-review:review de novo antes de commitar (R11).")
        exit 2
    }

    # Review fresco -> libera
    exit 0
} catch {
    # Falha do hook nao bloqueia workflow
    Write-Host "[percus:hook pre-commit] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
