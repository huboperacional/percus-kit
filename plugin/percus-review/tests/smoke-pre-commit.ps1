#requires -Version 5.1
# Smoke test pre-commit hook
$ErrorActionPreference = "Stop"
$hookScript = Join-Path $PSScriptRoot "..\hooks\pre-commit-check.ps1"

function Test-Case {
    param([string]$Name, [string]$Stdin, [int]$ExpectedExit)
    $tmp = New-TemporaryFile
    $Stdin | Out-File -FilePath $tmp -Encoding utf8 -NoNewline
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -File `"$hookScript`"" -RedirectStandardInput $tmp -RedirectStandardOutput "$env:TEMP/smoke-stdout.txt" -RedirectStandardError "$env:TEMP/smoke-stderr.txt" -NoNewWindow -PassThru -Wait
    $actual = $proc.ExitCode
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    if ($actual -eq $ExpectedExit) {
        Write-Host "[PASS] $Name (exit $actual)" -ForegroundColor Green
        return 0
    } else {
        Write-Host "[FAIL] $Name expected $ExpectedExit got $actual" -ForegroundColor Red
        return 1
    }
}

$failed = 0

# Caso 1: command sem 'git commit' -> libera (exit 0)
$json1 = '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
$failed += Test-Case "non-commit command" $json1 0

# Caso 2: 'git commit --amend --no-edit' -> libera (rebase exception)
$json3 = '{"tool_name":"Bash","tool_input":{"command":"git commit --amend --no-edit"}}'
$failed += Test-Case "amend no-edit (rebase)" $json3 0

# Caso 3: PERCUS_HOOKS_DISABLED ativo -> libera
$env:PERCUS_HOOKS_DISABLED = "1"
$json4 = '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}'
$failed += Test-Case "PERCUS_HOOKS_DISABLED escape" $json4 0
Remove-Item Env:\PERCUS_HOOKS_DISABLED

if ($failed -eq 0) {
    Write-Host "`nAll smoke tests PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$failed tests FAILED" -ForegroundColor Red
    exit 1
}
