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
#
# v6.7.2 (Proposta F+G, incidente 2026-05-19): hook agora detecta o repo target
# do commit parseando `cd <dir>`, `Set-Location <dir>` e `git -C <dir>` do comando,
# e resolve `git rev-parse --show-toplevel` desse target. Cross-repo work (CWD do
# agente != repo target) passa a ser observavel.

function Get-CommitTargetDir {
    param([string]$cmd, [string]$fallback)

    # git -C <dir> commit  (suporta quotes simples/duplas)
    if ($cmd -match '\bgit\s+-C\s+(?:"([^"]+)"|''([^'']+)''|(\S+))\s+.*\bcommit\b') {
        foreach ($g in $matches[1], $matches[2], $matches[3]) { if ($g) { return $g } }
    }

    # cd <dir> && git commit  (compound bash; tambem aceita `;`)
    if ($cmd -match '\bcd\s+(?:"([^"]+)"|''([^'']+)''|(\S+))\s*(?:&&|;)') {
        foreach ($g in $matches[1], $matches[2], $matches[3]) { if ($g) { return $g } }
    }

    # Set-Location <dir>  (PowerShell)
    if ($cmd -match '\b(?:Set-Location|sl)\s+(?:"([^"]+)"|''([^'']+)''|(\S+))') {
        foreach ($g in $matches[1], $matches[2], $matches[3]) { if ($g) { return $g } }
    }

    return $fallback
}

try {
    # PowerShell -File com stdin via pipe (testes Pester) consome stdin pelo automatic
    # $input enumerator e [Console]::In.ReadToEnd() retorna vazio. Em producao via
    # Claude Code hook runtime, stdin chega via OS pipe e [Console]::In funciona.
    # Tenta ambos os caminhos pra cobrir os dois cenarios.
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin -and $input) {
        $stdin = ($input | Out-String).Trim()
    }
    if (-not $stdin) { exit 0 }

    $parsed = $stdin | ConvertFrom-Json
    $command = $parsed.tool_input.command

    # Não-commit -> libera
    if ($command -notmatch '\bgit\s+(?:-C\s+\S+\s+)?commit\b') { exit 0 }

    # Amend sem edit (rebase) -> libera
    if ($command -match '\bgit\s+(?:-C\s+\S+\s+)?commit\s+--amend\s+--no-edit\b') { exit 0 }

    # Escape pro user (motivo declarado em voz alta)
    if ($env:PERCUS_HOOKS_DISABLED) { exit 0 }

    # Resolver repo target do commit
    $cwd = (Get-Location).Path
    $targetDir = Get-CommitTargetDir -cmd $command -fallback $cwd
    $repoRoot = & git -C "$targetDir" rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $repoRoot) { $repoRoot = $targetDir }
    $repoRoot = $repoRoot.Trim()
    $reviewDir = Join-Path $repoRoot ".deepseek/reviews"

    # Diagnostic helper (Proposta G)
    function Write-BlockContext {
        param([string]$searched)
        [Console]::Error.WriteLine("  git root: $repoRoot")
        if ($cwd -ne $repoRoot) {
            [Console]::Error.WriteLine("  cwd:      $cwd")
        }
        [Console]::Error.WriteLine("  searched: $searched")
    }

    if (-not (Test-Path $reviewDir)) {
        [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: nenhum /percus-review:review em .deepseek/reviews/ do repo target")
        Write-BlockContext -searched $reviewDir
        [Console]::Error.WriteLine("Rode /percus-review:review do repo target antes de commitar (R11).")
        exit 2
    }

    $latest = Get-ChildItem $reviewDir -Filter "*.jsonl" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: .deepseek/reviews/ vazia no repo target")
        Write-BlockContext -searched $reviewDir
        [Console]::Error.WriteLine("Rode /percus-review:review do repo target antes de commitar (R11).")
        exit 2
    }

    $age = (Get-Date) - $latest.LastWriteTime
    if ($age.TotalMinutes -gt 5) {
        $mins = [math]::Round($age.TotalMinutes, 1)
        [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: ultimo /percus-review:review tem $mins min (max 5).")
        Write-BlockContext -searched $reviewDir
        [Console]::Error.WriteLine("  latest:   $($latest.Name)")
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
