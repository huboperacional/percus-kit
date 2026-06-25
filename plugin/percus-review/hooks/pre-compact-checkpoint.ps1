#requires -Version 5.1
# Hook PreCompact Percus - backstop de checkpoint antes da compactacao de contexto.
# Contrato confirmado (docs.claude.com hooks): evento "PreCompact", stdin JSON com
#   { session_id, transcript_path, cwd, hook_event_name, trigger("manual"|"auto") }.
# Comportamento: NAO bloqueia. Loga fail-loud (prova que disparou) + emite systemMessage
#   lembrando de rodar /checkpoint. PreCompact nao injeta contexto pro agente (so avisa/loga).
# Falha graceful: qualquer erro -> exit 0. ASCII-only (PS 5.1 via .cmd le cp1252).

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }

    $data = $stdin | ConvertFrom-Json
    $trigger = if ($data.trigger) { $data.trigger } else { "unknown" }
    $sessionId = if ($data.session_id) { $data.session_id } else { "" }

    # Skip flag (escape pro user)
    if ($env:PERCUS_SKIP_PRECOMPACT) { exit 0 }

    # Log fail-loud: prova que o hook disparou (anti-falha-silenciosa do pre-mortem).
    $logDir = Join-Path (Get-Location) ".deepseek\checkpoint-log"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $entry = @{
        event      = "PreCompact"
        trigger    = $trigger
        session_id = $sessionId
        timestamp  = (Get-Date -Format 'o')
    } | ConvertTo-Json -Compress
    $entry | Out-File -Append -FilePath (Join-Path $logDir "precompact-$ts.jsonl") -Encoding utf8

    # systemMessage: aviso visivel pro operador (PreCompact suporta; nao bloqueia em exit 0).
    $msg = "[percus:PreCompact] Contexto vai compactar (trigger=$trigger). Se ainda nao rodou /checkpoint nesta sessao, rode antes: HANDOFF/PLANO podem ficar stale. (disparo logado em .deepseek/checkpoint-log/)"
    @{ systemMessage = $msg } | ConvertTo-Json -Compress | Write-Output

    exit 0
} catch {
    exit 0
}
