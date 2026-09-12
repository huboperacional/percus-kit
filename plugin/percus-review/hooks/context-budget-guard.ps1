#requires -Version 5.1
# Hook PostToolUse Percus (TODAS as tools) -- orcamento de contexto. OBSERVADOR: exit 0 sempre.
#
# Por que existe (medido 2026-09-12, transcript de Empresa-Milionaria): uma sessao de 14h foi de
# 69k a 610k tokens sem nenhum reset, com 11 mencoes a "checkpoint" -- checkpoint ESCREVE arquivo,
# nao reseta contexto. Retomada 2 dias depois, a compactacao gerou resumo de 4k mas a 1a chamada
# ja marcava 188k (custo fixo); a compactacao seguinte caiu em rate-limit e a sessao morreu com
# "Prompt is too long". Nada no kit MEDIA o contexto vivo. Este hook mede tamanho, nao delta
# (CONSTITUICAO Sec. 6): le a ultima `usage` que o harness gravou no transcript e avisa o agente
# (additionalContext) e o operador (systemMessage) quando passa dos limiares.
#
# NAO bloqueia. Bloqueio em contexto vivo vira escape rotineiro, e escape rotineiro mata o
# sinal -- foi o que o teto do CONTEXT.md provou. O que ele faz e nao deixar o agente NAO SABER.
#
# Le por CAUDA (FileStream nos ultimos 256 KB): transcript real tem 5-8 MB e este hook roda a
# CADA tool call. Get-Content inteiro aqui seria custo linear no tamanho da sessao, pago a cada
# passo, justamente quando a sessao ja esta pesada.
#
# Debounce: um aviso por NIVEL cruzado (warn, hard) e um por condicao de tempo (horas, dias),
# por sessao, em .deepseek/context-budget/<session_id>.json. Repetir a cada tool e ruido.
#
# Limiares (env-overridable):
#   PERCUS_CTX_WARN=150000   PERCUS_CTX_HARD=180000   PERCUS_CTX_HOURS=8   PERCUS_CTX_RESUME_DAYS=2
# Escape: PERCUS_SKIP_CONTEXT_BUDGET=1 (o geral PERCUS_HOOKS_DISABLED e tratado no wrapper).
# Falha graciosa: qualquer erro -> exit 0.

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }
    if ($env:PERCUS_SKIP_CONTEXT_BUDGET) { exit 0 }

    try { $payload = $stdin | ConvertFrom-Json } catch { exit 0 }
    $transcript = $payload.transcript_path
    if (-not $transcript -or -not (Test-Path -LiteralPath $transcript)) { exit 0 }

    $sessionId = "$($payload.session_id)"
    if (-not $sessionId) { $sessionId = "sem-id" }
    $sessionId = $sessionId -replace '[^A-Za-z0-9_\-]', ''   # mesma regra do .sh (tr -cd): apaga, nao troca

    $cwd = "$($payload.cwd)"
    if (-not $cwd -or -not (Test-Path -LiteralPath $cwd)) { $cwd = (Get-Location).Path }

    function Get-Limiar { param([string]$Nome, [int]$Padrao)
        $v = [Environment]::GetEnvironmentVariable($Nome)
        $n = 0
        if ($v -and [int]::TryParse($v, [ref]$n) -and $n -gt 0) { return $n }
        return $Padrao
    }
    $limWarn  = Get-Limiar 'PERCUS_CTX_WARN'        150000
    $limHard  = Get-Limiar 'PERCUS_CTX_HARD'        180000
    $limHoras = Get-Limiar 'PERCUS_CTX_HOURS'       8
    $limDias  = Get-Limiar 'PERCUS_CTX_RESUME_DAYS' 2

    # ---- cauda: ultima usage ----
    # Duas janelas, nao uma: PostToolUse roda logo apos o harness gravar o tool_result, que vem
    # DEPOIS da linha de usage do assistant. Um resultado maior que a 1a janela empurraria a
    # usage pra fora da cauda e o hook ficaria mudo justamente na chamada mais pesada (finding
    # R11, 2026-09-12). A 2a janela e o teto do que se le por chamada; acima disso a medicao
    # daquela chamada se perde e a seguinte recupera.
    function Read-Cauda { param([System.IO.FileStream]$Fs, [long]$Janela)
        $len = $Fs.Length
        $inicio = [Math]::Max(0, $len - $Janela)
        [void]$Fs.Seek($inicio, [System.IO.SeekOrigin]::Begin)
        $buf = New-Object byte[] ($len - $inicio)
        $lidos = 0
        while ($lidos -lt $buf.Length) {
            $n = $Fs.Read($buf, $lidos, $buf.Length - $lidos)
            if ($n -le 0) { break }
            $lidos += $n
        }
        return [pscustomobject]@{ Texto = [System.Text.Encoding]::UTF8.GetString($buf, 0, $lidos); Inicio = $inicio }
    }
    function Find-UltimaUsage { param([string]$Texto, [long]$Inicio)
        $linhas = $Texto -split "`n"
        $primeira = 0
        if ($Inicio -gt 0) { $primeira = 1 }   # a primeira linha da cauda pode estar cortada
        for ($i = $linhas.Length - 1; $i -ge $primeira; $i--) {
            $l = $linhas[$i]
            if ($l -notmatch '"usage"\s*:\s*\{') { continue }
            if ($l -notmatch '"input_tokens"\s*:\s*(\d+)') { continue }
            $t = [long]$matches[1]
            if ($l -match '"cache_read_input_tokens"\s*:\s*(\d+)')     { $t += [long]$matches[1] }
            if ($l -match '"cache_creation_input_tokens"\s*:\s*(\d+)') { $t += [long]$matches[1] }
            return $t
        }
        return -1
    }

    $fs = [System.IO.File]::Open($transcript, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $len = $fs.Length
        $tokens = -1
        foreach ($janela in @((256 * 1024), (2048 * 1024))) {
            $c = Read-Cauda -Fs $fs -Janela $janela
            $tokens = Find-UltimaUsage -Texto $c.Texto -Inicio $c.Inicio
            if ($tokens -ge 0 -or $c.Inicio -eq 0) { break }   # achou, ou ja leu o arquivo inteiro
        }

        # ---- cabeca: primeiro timestamp ----
        [void]$fs.Seek(0, [System.IO.SeekOrigin]::Begin)
        $bufCab = New-Object byte[] ([Math]::Min(8192, $len))
        $lidosCab = $fs.Read($bufCab, 0, $bufCab.Length)
        $cabeca = [System.Text.Encoding]::UTF8.GetString($bufCab, 0, $lidosCab)
    } finally { $fs.Close() }

    if ($tokens -lt 0) { exit 0 }

    $horas = 0.0
    if ($cabeca -match '"timestamp"\s*:\s*"([^"]+)"') {
        try {
            $ini = [DateTime]::Parse($matches[1], [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
            $horas = ((Get-Date).ToUniversalTime() - $ini.ToUniversalTime()).TotalHours
            if ($horas -lt 0) { $horas = 0.0 }
        } catch { $horas = 0.0 }
    }
    $dias = [Math]::Floor($horas / 24)

    # ---- niveis desta medicao ----
    $nivel = 0
    if ($tokens -ge $limWarn) { $nivel = 1 }
    if ($tokens -ge $limHard) { $nivel = 2 }
    $condHoras = ($horas -ge $limHoras)
    $condDias  = ($dias  -ge $limDias)

    # ---- debounce por sessao ----
    $stateDir = Join-Path $cwd ".deepseek\context-budget"
    if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    $stateFile = Join-Path $stateDir "$sessionId.json"
    $st = @{ nivel = 0; horas = $false; dias = $false }
    if (Test-Path -LiteralPath $stateFile) {
        try {
            $lido = [System.IO.File]::ReadAllText($stateFile) | ConvertFrom-Json
            $st.nivel = [int]$lido.nivel
            $st.horas = [bool]$lido.horas
            $st.dias  = [bool]$lido.dias
        } catch { }
    }

    $fala = ($nivel -gt $st.nivel) -or ($condHoras -and -not $st.horas) -or ($condDias -and -not $st.dias)
    if (-not $fala) { exit 0 }

    $novo = @{
        nivel = [Math]::Max($nivel, $st.nivel)
        horas = ($st.horas -or $condHoras)
        dias  = ($st.dias  -or $condDias)
        ts    = (Get-Date -Format 'o')
        tokens = $tokens
    }
    [System.IO.File]::WriteAllText($stateFile, ($novo | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))

    # ---- mensagem ----
    # AwayFromZero = mesma regra do .sh ((T+500)/1000); o Round padrao do .NET e banker's e
    # divergia em .500 (finding R11, 2026-09-12)
    $k     = [Math]::Round($tokens / 1000, [MidpointRounding]::AwayFromZero)
    $kWarn = [Math]::Round($limWarn / 1000)
    $kHard = [Math]::Round($limHard / 1000)
    $h     = [Math]::Floor($horas)

    $partes = New-Object System.Collections.Generic.List[string]
    $partes.Add("[percus:context-budget] contexto vivo ~${k}k tokens, ${h}h de sessao (limiar de aviso ${kWarn}k).")
    if ($nivel -ge 2) {
        $partes.Add("LIMITE DURO (${kHard}k) cruzado: a partir daqui a compactacao automatica e a unica saida e ela pode falhar (rate-limit); um resume em janela de 200k e impossivel.")
    }
    if ($condDias) {
        $partes.Add("Este transcript foi iniciado ha $dias dias -- e uma sessao retomada/velha. Nao continue nela: abra sessao nova e cole o bloco de retomada do HANDOFF.")
    } elseif ($condHoras) {
        $partes.Add("${h}h de parede na mesma sessao: o custo por passo so sobe daqui.")
    }
    $partes.Add("Acao: rode percus-review:checkpoint AGORA e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto. Acima de ~${kWarn}k um resume futuro em janela 200k falha.")
    $msgAgente = ($partes -join ' ')
    $msgOperador = "[percus:hook context-budget-guard] contexto ~${k}k tokens / ${h}h. Hora de checkpoint + sessao nova (veja o aviso ao agente)."

    # ---- log fail-loud (prova que disparou) ----
    try {
        $ev = @{ ts = (Get-Date -Format 'o'); session_id = $sessionId; tokens = $tokens; horas = [Math]::Round($horas, 2); nivel = $nivel; dias = $dias } | ConvertTo-Json -Compress
        [System.IO.File]::AppendAllText((Join-Path $stateDir "eventos.jsonl"), "$ev`n", (New-Object System.Text.UTF8Encoding($false)))
    } catch { }

    $saida = @{
        hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = $msgAgente }
        systemMessage      = $msgOperador
    }
    Write-Output ($saida | ConvertTo-Json -Compress -Depth 4)
    exit 0
} catch {
    exit 0
}
