#requires -Version 5.1
# Hook on-stop Percus — bloqueia stop se sessão tocou código sem atualizar HANDOFF.md (R8).
# Falha graceful: qualquer erro -> exit 0.

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $input = $stdin | ConvertFrom-Json
    $transcriptPath = $input.transcript_path
    if (-not $transcriptPath -or -not (Test-Path $transcriptPath)) { exit 0 }

    # Skip flag (escape pro user)
    if ($env:PERCUS_SKIP_HANDOFF) {
        $logDir = Join-Path (Get-Location) ".deepseek"
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        "$(Get-Date -Format 'o') | skip flag used | transcript=$transcriptPath" | Out-File -Append -FilePath (Join-Path $logDir "handoff-skipped.log") -Encoding utf8
        exit 0
    }

    # Extensoes codigo vs nao-codigo
    $codeExts = @('.py', '.ts', '.tsx', '.js', '.jsx', '.sql', '.go', '.rs', '.java', '.css', '.html', '.vue', '.svelte')

    $codeEdits = 0
    $handoffEdited = $false

    # foreach loop normal (NÃO ForEach-Object) pra preservar scope de variáveis no PS 5.1
    $lines = Get-Content $transcriptPath -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if ($line -match '"name"\s*:\s*"(Edit|Write|NotebookEdit)"') {
            if ($line -match '"file_path"\s*:\s*"([^"]+)"') {
                $file = $matches[1]
                $ext = [System.IO.Path]::GetExtension($file).ToLower()
                $base = [System.IO.Path]::GetFileName($file)
                if ($base -eq 'HANDOFF.md') { $handoffEdited = $true }
                elseif ($codeExts -contains $ext) { $codeEdits++ }
            }
        }
    }

    if ($codeEdits -eq 0) { exit 0 }
    if ($handoffEdited) { exit 0 }

    # Bloqueia
    [Console]::Error.WriteLine("[percus:hook on-stop] BLOCK: sessao tocou $codeEdits arquivo(s) de codigo mas HANDOFF.md nao foi atualizado (R8).")
    [Console]::Error.WriteLine("Atualize HANDOFF.md antes de encerrar OU defina `$env:PERCUS_SKIP_HANDOFF=1 com motivo declarado em voz alta.")
    [Console]::Error.WriteLine("Skip fica logado em .deepseek/handoff-skipped.log.")
    exit 2
} catch {
    exit 0
}
