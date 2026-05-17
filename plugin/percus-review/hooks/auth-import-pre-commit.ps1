#requires -Version 5.1
# Hook pre-commit Percus auth-import (R7).
# Bloqueia commit se staged code contem imports de auth providers vetados
# (Supabase, GoTrue, NextAuth). Percus usa auth-service proprio.
# Skip: $env:PERCUS_SKIP_AUTH_IMPORT=1 (declarar motivo em voz alta).

. "$PSScriptRoot\_helpers.ps1"

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $command = $input.tool_input.command

    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }
    if ($env:PERCUS_HOOKS_DISABLED -or $env:PERCUS_SKIP_AUTH_IMPORT) { exit 0 }

    $projectRoot = Resolve-PercusProjectRoot -Command $command
    if (-not (Test-Path (Join-Path $projectRoot ".git"))) { exit 0 }

    # Forbidden imports (regex per language)
    $forbiddenPy = @(
        @{ Re = '(?im)^\s*(?:from|import)\s+(?:gotrue|gotrue_py)\b'; Why = 'gotrue (Supabase) — use percus-auth' },
        @{ Re = '(?im)^\s*(?:from|import)\s+supabase\b';              Why = 'supabase-py — use percus-auth' }
    )
    $forbiddenTs = @(
        @{ Re = '(?im)from\s+[''"]@supabase/[^''"]+[''"]';            Why = '@supabase/* — use percus-auth' },
        @{ Re = '(?im)from\s+[''"]next-auth(?:/[^''"]*)?[''"]';       Why = 'next-auth — use percus-auth' },
        @{ Re = '(?im)from\s+[''"]@auth/[^''"]+[''"]';                Why = '@auth/* (NextAuth v5) — use percus-auth' },
        @{ Re = '(?im)require\([''"]@supabase/[^''"]+[''"]';          Why = '@supabase/* (require) — use percus-auth' }
    )

    # PyFiles
    $pyFiles = Get-PercusStagedFiles -ProjectRoot $projectRoot -Extensions @('.py')
    $tsFiles = Get-PercusStagedFiles -ProjectRoot $projectRoot -Extensions @('.ts','.tsx','.js','.jsx','.mjs','.cjs')

    $findings = @()

    foreach ($f in $pyFiles) {
        $content = Get-PercusStagedContent -ProjectRoot $projectRoot -RelPath $f
        if (-not $content) { continue }
        foreach ($p in $forbiddenPy) {
            $m = [regex]::Matches($content, $p.Re)
            foreach ($match in $m) {
                $lineNum = ($content.Substring(0, $match.Index) -split "`n").Count
                $findings += "${f}:${lineNum} -> $($p.Why) :: $($match.Value.Trim())"
                if ($findings.Count -ge 10) { break }
            }
            if ($findings.Count -ge 10) { break }
        }
        if ($findings.Count -ge 10) { break }
    }

    if ($findings.Count -lt 10) {
        foreach ($f in $tsFiles) {
            $content = Get-PercusStagedContent -ProjectRoot $projectRoot -RelPath $f
            if (-not $content) { continue }
            foreach ($p in $forbiddenTs) {
                $m = [regex]::Matches($content, $p.Re)
                foreach ($match in $m) {
                    $lineNum = ($content.Substring(0, $match.Index) -split "`n").Count
                    $findings += "${f}:${lineNum} -> $($p.Why) :: $($match.Value.Trim())"
                    if ($findings.Count -ge 10) { break }
                }
                if ($findings.Count -ge 10) { break }
            }
            if ($findings.Count -ge 10) { break }
        }
    }

    if ($findings.Count -eq 0) { exit 0 }

    Write-PercusBlock -HookName 'auth-import' -Lines (@(
        "encontrados $($findings.Count) import(s) de auth providers vetados (R7 — usar auth-service Percus)."
    ) + $findings + @(
        "Migre pra percus-auth ou GET https://auth.huboperacional.com.br/.",
        "Ver ${env:PERCUS_CANON_DIR}\02_INFRA_E_STACK_PERCUS.md secao 'Auth'.",
        "Skip (raro, declare motivo): `$env:PERCUS_SKIP_AUTH_IMPORT=1"
    ))
    exit 2
} catch {
    Write-Host "[percus:hook auth-import] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
