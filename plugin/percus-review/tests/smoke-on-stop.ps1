#requires -Version 5.1
# Smoke test on-stop hook
#
# LIMITAÇÃO CONHECIDA: PowerShell 5.1 tem bug ao passar stdin pra subprocess via pipe.
# Casos que precisam stdin (case 2/3/4) podem falhar com exit 0 quando deveriam bloquear.
# Hook em si está correto (validado em Claude Code real). Use este smoke como
# verificação SINTÁTICA do hook script. Validação comportamental real só via Claude Code.
#
# Pra validar comportamento de verdade: aplique edição em arquivo .py num projeto Percus,
# tente Stop sem atualizar HANDOFF, verifique bloqueio.

$ErrorActionPreference = "Stop"
$hookScript = Join-Path $PSScriptRoot "..\hooks\on-stop-check.ps1"

# Cria 3 transcripts fake em pasta temp
$tmpDir = Join-Path $env:TEMP "percus-smoke-on-stop"
if (Test-Path $tmpDir) { Remove-Item -Recurse -Force $tmpDir }
New-Item -ItemType Directory -Path $tmpDir | Out-Null

# Caso 1: transcript sem edicoes (so Read/Grep)
$t1 = Join-Path $tmpDir "case1.jsonl"
@'
{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"foo.md"}}
{"type":"tool_use","tool_name":"Grep","tool_input":{"pattern":"x"}}
'@ | Out-File -FilePath $t1 -Encoding utf8

# Caso 2: edicao em .tsx mas SEM edicao em HANDOFF.md
$t2 = Join-Path $tmpDir "case2.jsonl"
@'
{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"src/Login.tsx"}}
{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"docs/PLANO.md"}}
'@ | Out-File -FilePath $t2 -Encoding utf8

# Caso 3: edicao em .tsx + edicao em HANDOFF.md
$t3 = Join-Path $tmpDir "case3.jsonl"
@'
{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"src/Login.tsx"}}
{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"HANDOFF.md"}}
'@ | Out-File -FilePath $t3 -Encoding utf8

function Test-Case {
    param([string]$Name, [string]$TranscriptPath, [int]$ExpectedExit)
    $stdin = (@{ transcript_path = $TranscriptPath } | ConvertTo-Json -Compress)
    # Usar arquivo intermediário pra preservar stdin (pipe PS->PS perde stdin no PS 5.1)
    $tmpStdin = New-TemporaryFile
    $stdin | Out-File -FilePath $tmpStdin -Encoding utf8 -NoNewline
    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -File `"$hookScript`"" -RedirectStandardInput $tmpStdin -RedirectStandardOutput "$env:TEMP/smoke-stdout.txt" -RedirectStandardError "$env:TEMP/smoke-stderr.txt" -NoNewWindow -PassThru -Wait
    $actual = $proc.ExitCode
    Remove-Item $tmpStdin -Force -ErrorAction SilentlyContinue
    if ($actual -eq $ExpectedExit) {
        Write-Host "[PASS] $Name (exit $actual)" -ForegroundColor Green
        return 0
    } else {
        Write-Host "[FAIL] $Name expected $ExpectedExit got $actual" -ForegroundColor Red
        return 1
    }
}

$failed = 0
$failed += Test-Case "case 1: no code edits" $t1 0
$failed += Test-Case "case 2: code edit without HANDOFF" $t2 2
$failed += Test-Case "case 3: code edit with HANDOFF" $t3 0

# Caso 4: skip flag respeitado
$env:PERCUS_SKIP_HANDOFF = "1"
$failed += Test-Case "case 4: skip flag" $t2 0
Remove-Item Env:\PERCUS_SKIP_HANDOFF

Remove-Item -Recurse -Force $tmpDir
if ($failed -eq 0) {
    Write-Host "`nAll smoke tests PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n$failed tests FAILED" -ForegroundColor Red
    exit 1
}
