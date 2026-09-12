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
# A JANELA e descoberta, nao suposta (consertado 2026-09-12). Antes os limiares eram absolutos
# (150k/180k) e supunham janela de 200k; numa sessao claude-opus-5[1m] o hook mandou RESET com
# 777k livres -- 18% de uso. Ele media certo e errava o DENOMINADOR, e nunca dizia que estava
# supondo. Quatro pernas, da mais confiavel pra menos:
#   1. PERCUS_CTX_WINDOW explicito
#   2. marcador [1m]/-1m no "model" da mesma linha do usage (best-effort: NAO foi possivel
#      verificar que o transcript sempre traz o marcador)
#   3. falsificacao pela medicao: se a sessao esta viva ACIMA da janela suposta, a suposicao esta
#      provada errada. Isso NAO promove pra 1M -- seria trocar uma suposicao invisivel por outra,
#      e com janela real de 400k o hook ficaria mudo igual. Vira INDETERMINADA: reporta a medicao,
#      diz que nao sabe o denominador, pede PERCUS_CTX_WINDOW e para de afirmar LIMITE DURO.
#   4. piso de 200k
# Limiares derivados: 75% da janela (aviso) e 90% (duro) -- reproduz 150k/180k exatos numa janela
# de 200k, entao a calibracao que ja existia fica de pe e nenhum numero novo foi inventado.
#
# Limiares e janela (env-overridable; env explicito sempre vence a descoberta):
#   PERCUS_CTX_WINDOW=0 (auto)   PERCUS_CTX_WARN=0 (75%)   PERCUS_CTX_HARD=0 (90%)
#   PERCUS_CTX_HOURS=8   PERCUS_CTX_RESUME_DAYS=2
# Quem fala com quem: o AGENTE sempre (additionalContext) -- ele nao ve painel de contexto, e foi
# um agente que NAO SABIA que produziu a sessao de 610k. O OPERADOR so com PERCUS_CTX_OPERADOR=1:
# ele ve o contexto no painel do VSCode e dispara o checkpoint na mao (decisao dele, 2026-09-12).
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
    $winEnv   = Get-Limiar 'PERCUS_CTX_WINDOW'      0
    $warnEnv  = Get-Limiar 'PERCUS_CTX_WARN'        0
    $hardEnv  = Get-Limiar 'PERCUS_CTX_HARD'        0
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
    # Devolve tokens E modelo: o harness grava os dois na MESMA linha (a mensagem do assistant),
    # entao descobrir a janela custa zero de I/O extra. Antes este hook so lia os tokens e supunha
    # a janela -- era o denominador suposto que fazia ele mandar RESET com 78% do contexto livre.
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
            $m = ''
            if ($l -match '"model"\s*:\s*"([^"]+)"') { $m = $matches[1] }
            return [pscustomobject]@{ Tokens = $t; Modelo = $m }
        }
        return $null
    }

    $fs = [System.IO.File]::Open($transcript, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $len = $fs.Length
        $tokens = -1
        $modelo = ''
        foreach ($jan in @((256 * 1024), (2048 * 1024))) {
            $c = Read-Cauda -Fs $fs -Janela $jan
            $u = Find-UltimaUsage -Texto $c.Texto -Inicio $c.Inicio
            if ($u) { $tokens = $u.Tokens; $modelo = $u.Modelo }
            if ($tokens -ge 0 -or $c.Inicio -eq 0) { break }   # achou, ou ja leu o arquivo inteiro
        }

        # ---- cabeca: primeiro timestamp ----
        [void]$fs.Seek(0, [System.IO.SeekOrigin]::Begin)
        $bufCab = New-Object byte[] ([Math]::Min(8192, $len))
        $lidosCab = $fs.Read($bufCab, 0, $bufCab.Length)
        $cabeca = [System.Text.Encoding]::UTF8.GetString($bufCab, 0, $lidosCab)
    } finally { $fs.Close() }

    if ($tokens -lt 0) { exit 0 }

    # ---- a janela: descoberta, nao suposta ----
    # Quatro pernas, da mais confiavel pra menos. A 3a existe porque NAO foi possivel verificar
    # que o transcript traz o marcador de janela no nome do modelo (nenhum transcript desta
    # maquina trazia) -- e sem ela o conserto reproduziria o bug calado.
    $janelaFonte = ''
    if ($winEnv -gt 0) {
        $janela = $winEnv; $janelaFonte = 'PERCUS_CTX_WINDOW'
    } elseif ($modelo -match '(?i)(\[1m\]|[-_]1m([^a-z0-9]|$))') {   # mesmo padrao do .sh: \b nao ve fronteira entre m e _
        $janela = 1000000; $janelaFonte = "modelo $modelo"
    } else {
        $janela = 200000;  $janelaFonte = 'piso (o modelo nao declara a janela)'
    }
    # Perna 3: a MEDICAO falsifica a suposicao. Se a sessao esta viva acima da janela que eu
    # supus, a suposicao esta provada errada -- nao preciso saber qual e a janela real pra saber
    # que NAO e essa. Foi exatamente o caso de 2026-09-12: 208k medidos contra 200k supostos.
    # Estritamente ACIMA da janela suposta, nao em 95%: a 95% eu silenciaria uma sessao de 200k
    # GENUINA a 190k -- regressao pior que o bug original, porque o hook ficaria mudo exatamente
    # onde tem que gritar mais alto (finding R11, 2a rodada).
    #
    # E falsificar NAO promove pra 1M: isso so trocaria uma suposicao invisivel por outra, e se a
    # janela real fosse 400k o hook ficaria mudo do mesmo jeito -- a mesma classe do bug original
    # com outra constante (finding R11, 3a rodada). Passar do piso prova que a janela NAO e a que
    # eu supunha; nao prova qual e. Entao o estado honesto e INDETERMINADA: reporto a medicao,
    # digo que nao sei o denominador, e paro de afirmar LIMITE DURO -- que e uma afirmacao que
    # depende de saber a janela.
    $janelaIncerta = $false
    if ($winEnv -le 0 -and $tokens -gt $janela) {
        $janelaIncerta = $true
        $kSuposta = [int][Math]::Floor($janela / 1000)
        # "piso" so e verdade quando a suposicao veio do piso. Se veio do marcador do modelo, o
        # modelo DECLAROU -- chamar de piso seria enganoso (finding R11, 5a rodada).
        $comoSupus = if ($janelaFonte -like 'piso*') { 'o piso que eu supunha' } else { "o que o marcador do modelo declarava ($modelo)" }
        $janelaFonte = "INDETERMINADA (passou de ~${kSuposta}k, $comoSupus, e a sessao continua viva)"
    }
    # 75% / 90% reproduz 150k / 180k exatos numa janela de 200k: mantem a calibracao que ja
    # existia e nao inventa numero novo. Env explicito continua vencendo.
    $limWarn = if ($warnEnv -gt 0) { $warnEnv } else { [int][Math]::Floor($janela * 0.75) }
    $limHard = if ($hardEnv -gt 0) { $hardEnv } else { [int][Math]::Floor($janela * 0.90) }

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
    # LIMITE DURO afirma "falta pouco para o teto" -- e com a janela indeterminada eu nao sei onde
    # o teto esta. Falar mesmo assim seria a certeza falsa de volta.
    # MAS: se o operador declarou PERCUS_CTX_HARD, o teto e dele, nao meu -- rebaixar ali seria
    # silenciar o limite que ele mesmo configurou, contrariando "env explicito sempre vence a
    # descoberta" (finding R11, 4a rodada).
    if ($janelaIncerta -and $hardEnv -le 0 -and $nivel -ge 2) { $nivel = 1 }
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
    # Floor, pelo mesmo motivo do $pct: limWarn=562700 daria 563 com [int]() e 562 no bash.
    $kWarn = [int][Math]::Floor($limWarn / 1000)
    $kHard = [int][Math]::Floor($limHard / 1000)
    $h     = [Math]::Floor($horas)

    $kJanela = [int][Math]::Floor($janela / 1000)
    # Math::Floor, nao [int]() -- [int]() no PowerShell e banker's rounding, NAO truncamento, entao
    # a troca de Round por [int] tinha sido um no-op e o .ps1 continuava dando 81 onde o bash da 80
    # (finding R11, 4a rodada). O bash trunca; aqui tem que truncar tambem.
    $pct     = [int][Math]::Floor(($tokens * 100) / $janela)

    $partes = New-Object System.Collections.Generic.List[string]
    # A janela e a FONTE dela entram na mensagem porque a suposicao invisivel foi o que criou o
    # bug: durante meses este hook assumiu 200k sem nunca dizer que assumia.
    if ($janelaIncerta) {
        $partes.Add("[percus:context-budget] contexto vivo ~${k}k tokens, ${h}h de sessao. Janela $janelaFonte -- entao ela e MAIOR que isso, mas eu nao sei quanto, e sem o denominador nao da pra dizer se voce esta perto do teto. Defina PERCUS_CTX_WINDOW pra eu voltar a medir percentual.")
    } else {
        $partes.Add("[percus:context-budget] contexto vivo ~${k}k tokens (${pct}% de uma janela ~${kJanela}k -- $janelaFonte), ${h}h de sessao; limiar de aviso ${kWarn}k.")
    }
    if ($nivel -ge 2 -and $janelaIncerta) {
        # Chegar aqui com a janela indeterminada so acontece com PERCUS_CTX_HARD declarado (senao
        # o nivel teria sido rebaixado). O teto e do operador, entao a mensagem e legitima -- mas
        # nao pode carregar a janela junto, que e o denominador que a 1a frase acabou de negar
        # (finding R11, 6a rodada). A ressalva do piso tambem nao serve aqui: $janelaFonte ja e
        # "INDETERMINADA...", entao o -like 'piso*' nao casaria e a contradicao ficaria calada.
        $partes.Add("LIMITE DURO (${kHard}k, que voce configurou em PERCUS_CTX_HARD) cruzado: a partir daqui a compactacao automatica e a unica saida e ela pode falhar (rate-limit).")
    } elseif ($nivel -ge 2) {
        $partes.Add("LIMITE DURO (${kHard}k) cruzado: a partir daqui a compactacao automatica e a unica saida e ela pode falhar (rate-limit); um resume em janela ~${kJanela}k e impossivel.")
        # A falsificacao (perna 3) so prova a suposicao errada ACIMA da janela suposta -- e o
        # limite duro e 90% dela. Entre 90% e 100% de um PISO adivinhado o hook nao tem como
        # saber, e foi exatamente nessa faixa que ele mandou RESET com 78% do contexto livre
        # (finding R11, 2026-09-12). Nao dava pra falsificar mais cedo sem arriscar calar uma
        # sessao que esta MESMO no limite -- entao a duvida vira linha acionavel em vez de
        # certeza falsa.
        if ($janelaFonte -like 'piso*') {
            $partes.Add("ATENCAO: a janela ~${kJanela}k acima e um PISO adivinhado -- o modelo nao a declara. Se esta sessao tem janela maior (ex.: variante 1M), este aviso e falso: confira o painel de contexto e, se for o caso, sete PERCUS_CTX_WINDOW.")
        }
    }
    if ($condDias) {
        $partes.Add("Este transcript foi iniciado ha $dias dias -- e uma sessao retomada/velha. Nao continue nela: abra sessao nova e cole o bloco de retomada do HANDOFF.")
    } elseif ($condHoras) {
        $partes.Add("${h}h de parede na mesma sessao: o custo por passo so sobe daqui.")
    }
    # A linha de acao tambem nao pode reafirmar o denominador que a 1a frase acabou de negar: dizer
    # "eu nao sei a janela" e depois "resume em janela ~200k falha" e a certeza falsa de volta pela
    # porta dos fundos (finding R11, 5a rodada).
    if ($janelaIncerta) {
        $partes.Add("Acao: rode percus-review:checkpoint e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto.")
    } else {
        $partes.Add("Acao: rode percus-review:checkpoint e encerre em RESET (sessao nova + bloco de retomada). Checkpoint escreve arquivos; so o reset salva contexto. Acima de ~${kWarn}k um resume futuro em janela ~${kJanela}k falha.")
    }
    $msgAgente = ($partes -join ' ')
    # O operador ve o contexto no painel do proprio VSCode e dispara o checkpoint na mao (decisao
    # dele, 2026-09-12) -- o aviso a ele era ruido duplicado. O aviso ao AGENTE fica: o agente nao
    # ve painel nenhum, e foi um agente que NAO SABIA que produziu a sessao de 610k que originou
    # este hook. Assimetria deliberada, nao esquecimento.
    $msgOperador = $null
    # Get-Limiar, nao presenca: o resto dos PERCUS_CTX_* usa semantica de inteiro positivo, e
    # `if ($env:X)` trataria "0" e "false" como LIGADO -- quem tentasse desligar com =0 ligaria
    # (finding R11, 3a rodada).
    if ((Get-Limiar 'PERCUS_CTX_OPERADOR' 0) -gt 0) {
        # sem percentual quando a janela e indeterminada: o pct sairia contra a janela que o hook
        # ACABOU de declarar desconhecida ("105% da janela"), e o teste do agente nao pega isso
        # porque e outra mensagem (finding R11, 5a rodada)
        $pctTxt = if ($janelaIncerta) { "janela indeterminada" } else { "${pct}% da janela" }
        $msgOperador = "[percus:hook context-budget-guard] contexto ~${k}k tokens / ${h}h ($pctTxt). Hora de checkpoint + sessao nova (veja o aviso ao agente)."
    }

    # ---- log fail-loud (prova que disparou) ----
    try {
        $ev = @{ ts = (Get-Date -Format 'o'); session_id = $sessionId; tokens = $tokens; horas = [Math]::Round($horas, 2); nivel = $nivel; dias = $dias } | ConvertTo-Json -Compress
        [System.IO.File]::AppendAllText((Join-Path $stateDir "eventos.jsonl"), "$ev`n", (New-Object System.Text.UTF8Encoding($false)))
    } catch { }

    $saida = @{
        hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = $msgAgente }
    }
    if ($msgOperador) { $saida.systemMessage = $msgOperador }
    Write-Output ($saida | ConvertTo-Json -Compress -Depth 4)
    exit 0
} catch {
    exit 0
}
