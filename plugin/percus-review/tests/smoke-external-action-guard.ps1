#requires -Version 5.1
$hookPath = Join-Path $PSScriptRoot ".." "hooks" "external-action-guard.ps1"

# Test 1: gh pr comment sem override -> expect exit 2
$stdin1 = '{"tool_input":{"command":"gh pr comment 1 --body test"}}'
$out1 = $stdin1 | & pwsh -NoProfile -File $hookPath 2>&1
"=== Test 1: gh pr comment (sem override) ==="
"Exit: $LASTEXITCODE"
($out1 -join "`n")
""

# Test 2: gh pr list -> expect exit 0
$stdin2 = '{"tool_input":{"command":"gh pr list"}}'
$out2 = $stdin2 | & pwsh -NoProfile -File $hookPath 2>&1
"=== Test 2: gh pr list (read-only, permitido) ==="
"Exit: $LASTEXITCODE"
($out2 -join "`n")
""

# Test 3: com override -> exit 0
$env:PERCUS_EXTERNAL_OVERRIDE = "1"
$stdin3 = '{"tool_input":{"command":"gh pr comment 1 --body test"}}'
$out3 = $stdin3 | & pwsh -NoProfile -File $hookPath 2>&1
"=== Test 3: gh pr comment com PERCUS_EXTERNAL_OVERRIDE=1 ==="
"Exit: $LASTEXITCODE"
($out3 -join "`n")
Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
