#requires -Version 5.1
# Hook pre-commit Percus mock-scan (R3).
# Bloqueia commit se staged diff contem padroes de mock/placeholder.
# Skip explicito: prefixar commit message com `MOCK-OK:` OU `$env:PERCUS_SKIP_MOCK_SCAN=1`.
# Falha graceful: qualquer erro -> exit 0.

. "$PSScriptRoot\_helpers.ps1"

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $command = $input.tool_input.command

    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }
    if ($env:PERCUS_HOOKS_DISABLED -or $env:PERCUS_SKIP_MOCK_SCAN) { exit 0 }

    # Detect MOCK-OK: escape on commit message
    # PowerShell: capture group with -match
    $msgMatch = [regex]::Match($command, '-m\s+"([^"]+)"')
    if ($msgMatch.Success -and $msgMatch.Groups[1].Value -match '(?i)\bMOCK-OK:') { exit 0 }
    $msgMatch2 = [regex]::Match($command, "-m\s+'([^']+)'")
    if ($msgMatch2.Success -and $msgMatch2.Groups[1].Value -match '(?i)\bMOCK-OK:') { exit 0 }

    $projectRoot = Resolve-PercusProjectRoot -Command $command
    if (-not (Test-Path (Join-Path $projectRoot ".git"))) { exit 0 }

    # Scan staged code files
    $codeExts = @('.py','.ts','.tsx','.js','.jsx','.go','.rs','.java','.css','.html','.vue','.svelte','.sql')
    $files = Get-PercusStagedFiles -ProjectRoot $projectRoot -Extensions $codeExts
    if (-not $files -or $files.Count -eq 0) { exit 0 }

    # Forbidden patterns. Each one captures intent of "fake/placeholder/TODO leftover".
    $patterns = @(
        @{ Re = '\bMOCK_(?!OK\b)\w+';                    Why = 'identificador MOCK_*' },
        @{ Re = '\b(?:TODO|FIXME|XXX|HACK)\b[: ]';        Why = 'TODO/FIXME/XXX/HACK pendente' },
        @{ Re = '(?i)\blorem\s+ipsum\b';                  Why = 'lorem ipsum' },
        @{ Re = '(?i)\bdummy_';                           Why = 'dummy_' },
        @{ Re = '(?i)\bplaceholder_value\b';              Why = 'placeholder_value' },
        @{ Re = 'https?://localhost:\d+';                 Why = 'URL localhost:porta hardcoded' },
        @{ Re = '(?i)\bhardcoded\b';                      Why = 'comentario hardcoded' }
    )

    $findings = @()
    foreach ($f in $files) {
        $content = Get-PercusStagedContent -ProjectRoot $projectRoot -RelPath $f
        if (-not $content) { continue }
        $lineNum = 0
        foreach ($line in $content -split "`n") {
            $lineNum++
            foreach ($p in $patterns) {
                if ($line -match $p.Re) {
                    $findings += "${f}:${lineNum} -> $($p.Why) :: $($line.Trim().Substring(0,[Math]::Min(80,$line.Trim().Length)))"
                    break
                }
            }
            if ($findings.Count -ge 10) { break }
        }
        if ($findings.Count -ge 10) { break }
    }

    if ($findings.Count -eq 0) { exit 0 }

    Write-PercusBlock -HookName 'mock-scan' -Lines (@(
        "encontrados $($findings.Count)+ padrao(es) de mock/placeholder em arquivos staged (R3)."
    ) + $findings + @(
        "Remova o mock OU use commit message comecando com 'MOCK-OK: <motivo>' pra pular.",
        "Skip permanente: `$env:PERCUS_SKIP_MOCK_SCAN=1 (declarar motivo em voz alta)."
    ))
    exit 2
} catch {
    Write-Host "[percus:hook mock-scan] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
