#requires -Version 5.1
# Testes do hook context-budget-guard (v6.45.0).
#
# Hook PostToolUse em TODAS as tools (matcher vazio), OBSERVADOR (exit 0 sempre).
# Mede o contexto VIVO da sessao lendo a ultima `usage` do transcript e avisa o agente
# (additionalContext) e o operador (systemMessage) quando passa dos limiares. Nao bloqueia:
# bloqueio em contexto vivo vira escape rotineiro, e escape rotineiro mata o sinal (foi o
# que o teto do CONTEXT.md provou).
#
# Por que existe (medido 2026-09-12): uma sessao de 14h foi de 69k a 610k tokens sem reset,
# com 11 mencoes a "checkpoint" -- checkpoint escreve arquivo, nao reseta contexto. Retomada
# 2 dias depois, a compactacao falhou e a sessao morreu com "Prompt is too long".
# Nada no kit MEDIA o contexto. Este hook mede tamanho, nao delta (CONSTITUICAO Sec. 6).
#
# Aqui validamos: silencio abaixo do limiar, aviso acima, debounce por nivel, leitura por
# CAUDA (transcript de MB nao pode ser lido inteiro a cada tool call), idade da sessao,
# escape, e que NUNCA sai != 0.

Describe "context-budget-guard hook (orcamento de contexto, warn-only)" {
    BeforeAll {
        $script:hook = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.ps1"

        # Fabrica um transcript jsonl com a forma que o harness grava: primeira linha com
        # timestamp, linhas de enchimento SEM "usage", e a ultima chamada com usage.
        function New-Transcript {
            param(
                [int]$Tokens,
                [double]$HorasAtras = 0.5,
                [int]$PaddingKB = 4,
                [string]$Model = "claude-opus-5"
            )
            $dir = Join-Path ([IO.Path]::GetTempPath()) "ctxbudget-test-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $path = Join-Path $dir "transcript.jsonl"
            $inicio = (Get-Date).ToUniversalTime().AddHours(-$HorasAtras).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            $agora  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.AppendLine('{"type":"user","timestamp":"' + $inicio + '","message":{"role":"user","content":"oi"}}')
            # enchimento: linhas longas sem a palavra usage, pra provar que a leitura e por cauda
            $linha = '{"type":"assistant","timestamp":"' + $inicio + '","message":{"role":"assistant","content":[{"type":"text","text":"' + ('x' * 1000) + '"}]}}'
            $n = [Math]::Max(1, [int](($PaddingKB * 1024) / ($linha.Length + 2)))
            for ($i = 0; $i -lt $n; $i++) { [void]$sb.AppendLine($linha) }
            # a ultima chamada: a soma dos 3 campos e o contexto vivo
            $cacheRead = [int]($Tokens * 0.9)
            $inp = $Tokens - $cacheRead
            [void]$sb.AppendLine('{"type":"assistant","timestamp":"' + $agora + '","message":{"role":"assistant","model":"' + $Model + '","usage":{"input_tokens":' + $inp + ',"cache_read_input_tokens":' + $cacheRead + ',"cache_creation_input_tokens":0,"output_tokens":12},"content":[{"type":"text","text":"ok"}]}}')
            $enc = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($path, $sb.ToString(), $enc)
            return $path
        }

        # Roda o hook como o harness roda: payload JSON no stdin, cwd = pasta do projeto.
        function Invoke-Guard {
            param(
                [string]$Transcript,
                [string]$SessionId = "sess-$(Get-Random)",
                [string]$Cwd,
                [string]$RawStdin
            )
            if (-not $Cwd) { $Cwd = Split-Path $Transcript -Parent }
            if ($RawStdin) {
                $stdin = $RawStdin
            } else {
                $stdin = @{
                    session_id      = $SessionId
                    transcript_path = $Transcript
                    cwd             = $Cwd
                    hook_event_name = "PostToolUse"
                    tool_name       = "Edit"
                    tool_input      = @{ file_path = "x.py" }
                } | ConvertTo-Json -Compress
            }
            Push-Location $Cwd
            try {
                $sw = [Diagnostics.Stopwatch]::StartNew()
                $out = $stdin | & pwsh -NoProfile -File $script:hook 2>$null
                $sw.Stop()
                $code = $LASTEXITCODE
            } finally { Pop-Location }
            $texto = ($out -join "`n").Trim()
            $json = $null
            if ($texto) { try { $json = $texto | ConvertFrom-Json } catch { $json = $null } }
            return [pscustomobject]@{ Code = $code; Out = $texto; Json = $json; Ms = $sw.ElapsedMilliseconds; Cwd = $Cwd }
        }
    }

    It "existe" {
        Test-Path $hook | Should -Be $true
    }

    Context "abaixo do limiar: silencio" {
        It "90k tokens, sessao de 30min -> stdout vazio, exit 0" {
            $t = New-Transcript -Tokens 90000
            $r = Invoke-Guard -Transcript $t
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }
    }

    Context "acima do limiar de aviso (150k): fala com o AGENTE; o operador so se pedir" {
        It "160k -> additionalContext dirigido ao agente, com a assinatura e o valor medido" {
            $t = New-Transcript -Tokens 160000
            $r = Invoke-Guard -Transcript $t
            $r.Code | Should -Be 0
            $r.Json | Should -Not -BeNullOrEmpty -Because "a saida tem que ser JSON que o harness entende:`n$($r.Out)"
            $r.Json.hookSpecificOutput.hookEventName    | Should -Be "PostToolUse"
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '\[percus:context-budget\]'
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '160k'
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'checkpoint'
        }

        # O operador ve o contexto no painel do proprio VSCode e dispara o checkpoint na mao
        # (decisao dele, 2026-09-12). O aviso a ele era ruido duplicado; o aviso ao AGENTE nao e,
        # porque o agente nao ve painel nenhum -- foi um agente que NAO SABIA que produziu a
        # sessao de 610k que originou este hook.
        It "160k -> NAO emite systemMessage por padrao (o operador tem o painel)" {
            $t = New-Transcript -Tokens 160000
            $r = Invoke-Guard -Transcript $t
            $r.Json.hookSpecificOutput.additionalContext | Should -Not -BeNullOrEmpty
            $r.Json.PSObject.Properties.Name | Should -Not -Contain 'systemMessage'
        }

        It "PERCUS_CTX_OPERADOR=1 devolve o aviso ao operador" {
            $t = New-Transcript -Tokens 160000
            $env:PERCUS_CTX_OPERADOR = "1"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_OPERADOR -ErrorAction SilentlyContinue }
            $r.Json.systemMessage | Should -Match '\[percus:hook context-budget-guard\]'
        }

        It "160k -> grava estado da sessao e loga o evento (prova que disparou)" {
            $t = New-Transcript -Tokens 160000
            $sid = "sess-prova-$(Get-Random)"
            $r = Invoke-Guard -Transcript $t -SessionId $sid
            Test-Path (Join-Path $r.Cwd ".deepseek\context-budget\$sid.json") | Should -Be $true
            $log = Join-Path $r.Cwd ".deepseek\context-budget\eventos.jsonl"
            Test-Path $log | Should -Be $true
            (Get-Content $log -Raw) | Should -Match $sid
        }
    }

    Context "debounce: um aviso por nivel, nao um por tool call" {
        It "segunda chamada na MESMA sessao a 162k -> silencio" {
            $sid = "sess-debounce-$(Get-Random)"
            $t1 = New-Transcript -Tokens 160000
            $cwd = Split-Path $t1 -Parent
            $r1 = Invoke-Guard -Transcript $t1 -SessionId $sid -Cwd $cwd
            $r1.Json | Should -Not -BeNullOrEmpty
            $t2 = New-Transcript -Tokens 162000
            $r2 = Invoke-Guard -Transcript $t2 -SessionId $sid -Cwd $cwd
            $r2.Code | Should -Be 0
            $r2.Out  | Should -BeNullOrEmpty -Because "ja avisou neste nivel; repetir a cada tool e ruido, e ruido e ignorado"
        }

        It "mas cruzar o limiar DURO (180k) na mesma sessao fala de novo, mais duro" {
            $sid = "sess-hard-$(Get-Random)"
            $t1 = New-Transcript -Tokens 160000
            $cwd = Split-Path $t1 -Parent
            Invoke-Guard -Transcript $t1 -SessionId $sid -Cwd $cwd | Out-Null
            $t2 = New-Transcript -Tokens 185000
            $r2 = Invoke-Guard -Transcript $t2 -SessionId $sid -Cwd $cwd
            $r2.Json | Should -Not -BeNullOrEmpty
            $r2.Json.hookSpecificOutput.additionalContext | Should -Match '185k'
            $r2.Json.hookSpecificOutput.additionalContext | Should -Match 'LIMITE DURO'
        }

        It "sessao DIFERENTE no mesmo cwd nao herda o debounce" {
            $t1 = New-Transcript -Tokens 160000
            $cwd = Split-Path $t1 -Parent
            Invoke-Guard -Transcript $t1 -SessionId "sess-a-$(Get-Random)" -Cwd $cwd | Out-Null
            $r2 = Invoke-Guard -Transcript $t1 -SessionId "sess-b-$(Get-Random)" -Cwd $cwd
            $r2.Json | Should -Not -BeNullOrEmpty
        }
    }

    Context "le por CAUDA: transcript grande nao e lido inteiro a cada tool call" {
        It "6 MB de enchimento com a usage so no fim -> mede certo e responde rapido" {
            $t = New-Transcript -Tokens 170000 -PaddingKB 6144
            $r = Invoke-Guard -Transcript $t
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '170k'
            # pwsh frio custa ~0,5-1 s no Windows; o que se proibe aqui e o custo LINEAR no
            # tamanho do arquivo. 6 MB lidos inteiros e parseados passariam de 3 s facil.
            $r.Ms | Should -BeLessThan 3000 -Because "levou $($r.Ms) ms -- leitura inteira do transcript"
        }

        It "tool_result de 400 KB DEPOIS da ultima usage nao esconde a medicao (fallback de janela maior)" {
            # PostToolUse roda logo apos o harness gravar o tool_result -- que vem DEPOIS da linha
            # de usage do assistant. Um resultado maior que a janela de 256 KB empurraria a usage
            # pra fora da cauda e o hook ficaria mudo justamente na chamada mais pesada. O hook
            # tenta uma segunda janela maior antes de desistir. (Finding R11, 2026-09-12.)
            $t = New-Transcript -Tokens 170000
            $enc = New-Object System.Text.UTF8Encoding($false)
            $grande = '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"' + ('y' * 409600) + '"}]}}' + "`n"
            [System.IO.File]::AppendAllText($t, $grande, $enc)
            $r = Invoke-Guard -Transcript $t
            $r.Json | Should -Not -BeNullOrEmpty -Because "a usage esta 400 KB antes do fim; a 2a janela tem que alcancar"
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '170k'
        }

        It "o codigo nao le o transcript inteiro (nenhuma linha viva usa Get-Content no transcript)" {
            $vivas = @(Get-Content $hook -ErrorAction Stop | Where-Object { -not "$_".TrimStart().StartsWith('#') })
            @($vivas | Where-Object { $_ -match 'Get-Content' }) | Should -BeNullOrEmpty -Because "Get-Content carrega o arquivo todo; a cauda e lida por FileStream"
        }
    }

    Context "tempo de parede e idade: sessao velha avisa mesmo com poucos tokens" {
        It "100k tokens mas 9h de sessao -> avisa citando as horas" {
            $t = New-Transcript -Tokens 100000 -HorasAtras 9
            $r = Invoke-Guard -Transcript $t
            $r.Json | Should -Not -BeNullOrEmpty
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '9h'
        }

        It "100k tokens mas transcript iniciado ha 3 dias (resume velho) -> avisa citando os dias" {
            $t = New-Transcript -Tokens 100000 -HorasAtras 72
            $r = Invoke-Guard -Transcript $t
            $r.Json | Should -Not -BeNullOrEmpty
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '3 dias'
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'sess[aã]o nova'
        }
    }

    # O bug que estes testes fecham (medido 2026-09-12): os limiares 150k/180k eram absolutos e
    # supunham janela de 200k. Numa sessao claude-opus-5[1m] (janela de 1M) o hook mandou RESET
    # com 777k livres -- 18% de uso. Ele media certo e errava o DENOMINADOR. O conserto nao
    # inventa numero: mantem 75%/90%, que reproduz 150k/180k exatos numa janela de 200k, e passa
    # a descobrir a janela em vez de supo-la.
    Context "janela do modelo: o denominador deixa de ser suposto" {
        It "PERCUS_CTX_WINDOW=1000000 -> 160k fica em silencio (limiar vira 750k)" {
            $t = New-Transcript -Tokens 160000
            $env:PERCUS_CTX_WINDOW = "1000000"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_WINDOW -ErrorAction SilentlyContinue }
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }

        It "PERCUS_CTX_WINDOW=1000000 -> 800k avisa (750k e 75% de 1M)" {
            $t = New-Transcript -Tokens 800000
            $env:PERCUS_CTX_WINDOW = "1000000"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_WINDOW -ErrorAction SilentlyContinue }
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '800k'
        }

        It "modelo com marcador [1m] no transcript -> 160k fica em silencio" {
            $t = New-Transcript -Tokens 160000 -Model 'claude-opus-5[1m]'
            $r = Invoke-Guard -Transcript $t
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }

        It "sem marcador nenhum -> piso de 200k, comportamento de hoje preservado (160k avisa)" {
            $t = New-Transcript -Tokens 160000 -Model 'claude-opus-4-7'
            $r = Invoke-Guard -Transcript $t
            $r.Json.hookSpecificOutput.additionalContext | Should -Match '160k'
        }

        # A perna que teria pego o caso de hoje SOZINHA, sem depender de o transcript trazer o
        # marcador -- que e justamente o que nao consegui verificar que ele traz.
        It "medicao falsifica a suposicao: 210k com piso de 200k nao e LIMITE DURO" {
            $t = New-Transcript -Tokens 210000 -Model 'claude-opus-4-7'
            $r = Invoke-Guard -Transcript $t
            $r.Json.hookSpecificOutput.additionalContext | Should -Not -Match 'LIMITE DURO'
        }

        # Achado da 3a rodada do review: falsificar promovendo pra 1M era trocar uma suposicao
        # invisivel por outra. Se a janela real fosse 400k o hook ficaria mudo do mesmo jeito.
        It "falsificar NAO inventa 1M: declara a janela INDETERMINADA e diz que nao sabe" {
            $t = New-Transcript -Tokens 210000 -Model 'claude-opus-4-7'
            $r = Invoke-Guard -Transcript $t
            $msg = $r.Json.hookSpecificOutput.additionalContext
            $msg | Should -Match 'INDETERMINADA'
            $msg | Should -Match 'nao sei quanto'
            $msg | Should -Match 'PERCUS_CTX_WINDOW'
            $msg | Should -Not -Match '1000k|~1000k' -Because "promover pra 1M seria a suposicao invisivel de volta"
        }

        It "janela indeterminada nao emite percentual (nao ha denominador pra calcular)" {
            $t = New-Transcript -Tokens 210000 -Model 'claude-opus-4-7'
            $r = Invoke-Guard -Transcript $t
            $r.Json.hookSpecificOutput.additionalContext | Should -Not -Match '\d+% de uma janela'
        }

        # Achados da 4a rodada. O primeiro e o que os testes de paridade anteriores nao pegavam
        # porque so usavam janelas redondas: [int]() no PowerShell e banker's rounding, NAO
        # truncamento, entao trocar Round por [int] tinha sido um no-op.
        It "janela NAO-redonda e tokens com fracao: mensagem identica entre .ps1 e .sh" {
            $bashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
            if (-not $bashPath) {
                $bashPath = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
                            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            }
            if (-not $bashPath) { Set-ItResult -Skipped -Because "sem bash"; return }
            # 161500/200000 = 80,75% -> banker's da 81, truncamento da 80. E o caso exato do finding.
            $t = New-Transcript -Tokens 161500
            $cwd = Split-Path $t -Parent
            $env:PERCUS_CTX_WINDOW = "200002"   # nao-redonda: 200002*0,75 = 150001,5
            try {
                $rPs = Invoke-Guard -Transcript $t -SessionId "fr-ps" -Cwd $cwd
                $shPath = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.sh"
                $payload = @{ session_id = "fr-sh"; transcript_path = $t; cwd = $cwd; hook_event_name = "PostToolUse" } | ConvertTo-Json -Compress
                Push-Location $cwd
                try { $outSh = ($payload | & $bashPath $shPath 2>$null) -join "" } finally { Pop-Location }
            } finally { Remove-Item Env:PERCUS_CTX_WINDOW -ErrorAction SilentlyContinue }
            $msgPs = $rPs.Json.hookSpecificOutput.additionalContext
            $msgSh = ($outSh | ConvertFrom-Json).hookSpecificOutput.additionalContext
            $msgSh | Should -Be $msgPs -Because "ps: $msgPs`nsh: $msgSh"
            $msgPs | Should -Match '80% de uma janela' -Because "truncamento da 80; banker's daria 81"
        }

        # Achados da 5a rodada: a certeza falsa voltava por tres portas que eu nao tinha limpado.
        It "janela indeterminada: NENHUMA parte da mensagem reafirma um denominador" {
            $t = New-Transcript -Tokens 210000 -Model 'claude-opus-4-7'
            $r = Invoke-Guard -Transcript $t
            $msg = $r.Json.hookSpecificOutput.additionalContext
            # a linha de acao dizia "resume em janela ~200k falha" logo depois de "nao sei quanto"
            $msg | Should -Not -Match 'janela ~\d+k falha'
            $msg | Should -Not -Match '\d+% de uma janela'
        }

        It "janela indeterminada: o aviso ao OPERADOR tambem nao inventa percentual" {
            # o pct sairia contra a janela recem-declarada desconhecida ("105% da janela"), e
            # nenhum teste do agente pegava porque e outra mensagem
            $t = New-Transcript -Tokens 210000 -Model 'claude-opus-4-7'
            $env:PERCUS_CTX_OPERADOR = "1"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_OPERADOR -ErrorAction SilentlyContinue }
            $r.Json.systemMessage | Should -Match 'janela indeterminada'
            $r.Json.systemMessage | Should -Not -Match '\d+% da janela'
        }

        It "se a janela veio do MARCADOR e foi ultrapassada, nao chama de 'piso'" {
            # 1,1M num modelo que declara [1m]: a suposicao veio do modelo, nao de um piso
            $t = New-Transcript -Tokens 1100000 -Model 'claude-opus-5[1m]'
            $r = Invoke-Guard -Transcript $t
            $msg = $r.Json.hookSpecificOutput.additionalContext
            $msg | Should -Match 'INDETERMINADA'
            $msg | Should -Not -Match 'piso que eu supunha'
            $msg | Should -Match 'marcador do modelo'
        }

        It "PERCUS_CTX_HARD explicito vence a janela indeterminada (env explicito sempre vence)" {
            # 210k passa do piso de 200k -> indeterminada. Mas o operador declarou o teto dele;
            # rebaixar para warn silenciaria o limite que ele mesmo configurou.
            $t = New-Transcript -Tokens 210000 -Model 'claude-opus-4-7'
            $env:PERCUS_CTX_HARD = "180000"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_HARD -ErrorAction SilentlyContinue }
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'LIMITE DURO'
        }

        # 6a rodada: era a combinacao que nenhum teste fazia -- HARD explicito COM janela
        # indeterminada. O nivel 2 sobrevivia (correto) mas a mensagem voltava a cravar ~200k.
        It "HARD explicito + janela indeterminada: avisa duro SEM reafirmar a janela" {
            $t = New-Transcript -Tokens 210000 -Model 'claude-opus-4-7'
            $env:PERCUS_CTX_HARD = "180000"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_HARD -ErrorAction SilentlyContinue }
            $msg = $r.Json.hookSpecificOutput.additionalContext
            $msg | Should -Match 'LIMITE DURO'
            $msg | Should -Match 'PERCUS_CTX_HARD'
            $msg | Should -Not -Match 'janela ~\d+k e impossivel'
        }

        It "HARD explicito + janela indeterminada: mesma mensagem no .sh" {
            $bashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
            if (-not $bashPath) {
                $bashPath = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
                            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            }
            if (-not $bashPath) { Set-ItResult -Skipped -Because "sem bash"; return }
            $t = New-Transcript -Tokens 210000 -Model 'claude-opus-4-7'
            $cwd = Split-Path $t -Parent
            $env:PERCUS_CTX_HARD = "180000"
            try {
                $rPs = Invoke-Guard -Transcript $t -SessionId "hi-ps" -Cwd $cwd
                $shPath = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.sh"
                $payload = @{ session_id = "hi-sh"; transcript_path = $t; cwd = $cwd; hook_event_name = "PostToolUse" } | ConvertTo-Json -Compress
                Push-Location $cwd
                try { $outSh = ($payload | & $bashPath $shPath 2>$null) -join "" } finally { Pop-Location }
            } finally { Remove-Item Env:PERCUS_CTX_HARD -ErrorAction SilentlyContinue }
            $msgSh = ($outSh | ConvertFrom-Json).hookSpecificOutput.additionalContext
            $msgSh | Should -Be $rPs.Json.hookSpecificOutput.additionalContext
        }

        It "PERCUS_CTX_OPERADOR=0 DESLIGA (presenca da env ligava, ao contrario dos outros PERCUS_CTX_*)" {
            $t = New-Transcript -Tokens 160000
            $env:PERCUS_CTX_OPERADOR = "0"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_OPERADOR -ErrorAction SilentlyContinue }
            $r.Json.PSObject.Properties.Name | Should -Not -Contain 'systemMessage'
        }

        It "a mensagem declara a janela E de onde a tirou (suposicao invisivel foi o que criou o bug)" {
            $t = New-Transcript -Tokens 160000 -Model 'claude-opus-4-7'
            $r = Invoke-Guard -Transcript $t
            # tem que dizer o VALOR da janela e a FONTE, nao so a palavra "janela"
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'janela ~?200k'
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'piso|modelo|PERCUS_CTX_WINDOW|falsificad'
        }

        # Os tres achados do review R11 desta versao. Sem teste, voltam.
        It "no LIMITE DURO sobre um PISO adivinhado, avisa que a propria janela pode estar errada" {
            # 185k de uma janela SUPOSTA de 200k: acima do duro (180k) e abaixo da falsificacao
            # (190k). E a faixa exata em que o hook mandou RESET com 78% do contexto livre.
            $t = New-Transcript -Tokens 185000 -Model 'claude-opus-4-7'
            $r = Invoke-Guard -Transcript $t
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'LIMITE DURO'
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'PISO adivinhado'
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'PERCUS_CTX_WINDOW'
        }

        It "com janela DECLARADA, o limite duro nao carrega a ressalva do piso" {
            $t = New-Transcript -Tokens 185000 -Model 'claude-opus-4-7'
            $env:PERCUS_CTX_WINDOW = "200000"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_WINDOW -ErrorAction SilentlyContinue }
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'LIMITE DURO'
            $r.Json.hookSpecificOutput.additionalContext | Should -Not -Match 'PISO adivinhado'
        }

        It "o marcador de janela casa igual nos dois runtimes (fronteira m/_)" {
            # '\b' do .NET nao ve fronteira entre 'm' e '_'; o .sh usa [^a-z0-9], que ve.
            # O nome deste teste prometia comparar os DOIS runtimes e so rodava o .ps1 --
            # a mesma classe que o changelog critica (finding R11, 4a rodada). Agora roda os dois.
            $t = New-Transcript -Tokens 160000 -Model 'claude-opus-5-1m_preview'
            $r = Invoke-Guard -Transcript $t
            $r.Out | Should -BeNullOrEmpty -Because "o marcador -1m_ tem que ser reconhecido como janela de 1M no .ps1"

            $bashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
            if (-not $bashPath) {
                $bashPath = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
                            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            }
            if (-not $bashPath) { Set-ItResult -Skipped -Because "sem bash"; return }
            $cwd = Split-Path $t -Parent
            $shPath = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.sh"
            $payload = @{ session_id = "mu-sh"; transcript_path = $t; cwd = $cwd; hook_event_name = "PostToolUse" } | ConvertTo-Json -Compress
            Push-Location $cwd
            try { $outSh = ($payload | & $bashPath $shPath 2>$null) -join "" } finally { Pop-Location }
            $outSh.Trim() | Should -BeNullOrEmpty -Because "e no .sh tambem -- era so aqui que a divergencia de fronteira apareceria"
        }

        # Achados da 2a rodada do review R11. Os dois primeiros sao regressoes que EU introduzi
        # tentando consertar o bug original -- e nenhum teste meu os cobria.
        It "sessao de 200k GENUINA a 190k continua no LIMITE DURO (falsificar em 95% silenciava ela)" {
            # Foi a regressao: falsificar a 95% saltava a janela pra 1M, limHard ia pra 900k, e o
            # hook ficava mudo justamente na faixa em que ele existe pra gritar mais alto.
            $t = New-Transcript -Tokens 190000 -Model 'claude-opus-4-7'
            $r = Invoke-Guard -Transcript $t
            $r.Json.hookSpecificOutput.additionalContext | Should -Match 'LIMITE DURO'
        }

        It "janela nao-redonda: os k derivados batem entre .ps1 e .sh (Round divergia de truncamento)" {
            $bashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
            if (-not $bashPath) {
                $bashPath = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
                            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            }
            if (-not $bashPath) { Set-ItResult -Skipped -Because "sem bash"; return }
            # 750000 * 0.75 = 562500 -> Round da 563k, divisao inteira da 562k
            $t = New-Transcript -Tokens 600000
            $cwd = Split-Path $t -Parent
            $env:PERCUS_CTX_WINDOW = "750000"
            try {
                $rPs = Invoke-Guard -Transcript $t -SessionId "nr-ps" -Cwd $cwd
                $sh = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.sh"
                $payload = @{ session_id = "nr-sh"; transcript_path = $t; cwd = $cwd; hook_event_name = "PostToolUse" } | ConvertTo-Json -Compress
                Push-Location $cwd
                try { $outSh = ($payload | & $bashPath $sh 2>$null) -join "" } finally { Pop-Location }
            } finally { Remove-Item Env:PERCUS_CTX_WINDOW -ErrorAction SilentlyContinue }
            $msgSh = ($outSh | ConvertFrom-Json).hookSpecificOutput.additionalContext
            $msgSh | Should -Be $rPs.Json.hookSpecificOutput.additionalContext
        }

        It "o .sh reconhece o marcador [1m] de verdade (o sed dele estava quebrado e falhava calado)" {
            $bashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
            if (-not $bashPath) {
                $bashPath = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
                            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
            }
            if (-not $bashPath) { Set-ItResult -Skipped -Because "sem bash"; return }
            # O teste de paridade usava o modelo default e por isso nao via o sed corrompido
            # (o \1 virou \x01): MODELO saia vazio e o marcador nunca casava.
            $t = New-Transcript -Tokens 160000 -Model 'claude-opus-5[1m]'
            $cwd = Split-Path $t -Parent
            $shPath = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.sh"
            $payload = @{ session_id = "m1m-sh"; transcript_path = $t; cwd = $cwd; hook_event_name = "PostToolUse" } | ConvertTo-Json -Compress
            Push-Location $cwd
            try { $outSh = ($payload | & $bashPath $shPath 2>$null) -join "" } finally { Pop-Location }
            $outSh.Trim() | Should -BeNullOrEmpty -Because "160k numa janela de 1M esta muito abaixo do limiar; se falar, o marcador nao foi reconhecido"
        }

        It "nao ha mais '200k' cravado no texto quando a janela nao e 200k" {
            $t = New-Transcript -Tokens 800000
            $env:PERCUS_CTX_WINDOW = "1000000"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_WINDOW -ErrorAction SilentlyContinue }
            $r.Json.hookSpecificOutput.additionalContext | Should -Not -Match '200k'
        }
    }

    Context "limiares sao configuraveis por env (o hook mede o que o operador mandar)" {
        It "PERCUS_CTX_WARN=50000 faz 90k avisar" {
            $t = New-Transcript -Tokens 90000
            $env:PERCUS_CTX_WARN = "50000"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_CTX_WARN -ErrorAction SilentlyContinue }
            $r.Json | Should -Not -BeNullOrEmpty
        }
    }

    Context "escape e falha graciosa: NUNCA sai != 0" {
        It "PERCUS_SKIP_CONTEXT_BUDGET=1 -> silencio mesmo a 185k" {
            $t = New-Transcript -Tokens 185000
            $env:PERCUS_SKIP_CONTEXT_BUDGET = "1"
            try { $r = Invoke-Guard -Transcript $t } finally { Remove-Item Env:PERCUS_SKIP_CONTEXT_BUDGET -ErrorAction SilentlyContinue }
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }

        It "stdin vazio -> exit 0, silencio" {
            $r = Invoke-Guard -RawStdin "" -Cwd ([IO.Path]::GetTempPath())
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }

        It "JSON quebrado -> exit 0, silencio" {
            $r = Invoke-Guard -RawStdin "{isto nao e json" -Cwd ([IO.Path]::GetTempPath())
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }

        It "transcript inexistente -> exit 0, silencio" {
            $stdin = @{ session_id = "s"; transcript_path = "C:\nao\existe.jsonl"; hook_event_name = "PostToolUse" } | ConvertTo-Json -Compress
            $r = Invoke-Guard -RawStdin $stdin -Cwd ([IO.Path]::GetTempPath())
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }

        It "transcript sem nenhuma usage -> exit 0, silencio" {
            $dir = Join-Path ([IO.Path]::GetTempPath()) "ctxbudget-nousage-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $p = Join-Path $dir "t.jsonl"
            Set-Content -Path $p -Value '{"type":"user","timestamp":"2026-01-01T00:00:00Z","message":{"content":"oi"}}'
            $r = Invoke-Guard -Transcript $p
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }
    }

    Context "os runtimes que rodam DE VERDADE: .cmd (powershell.exe 5.1) e .sh -- nao so pwsh" {
        # O hooks.json chama o .cmd, que chama powershell.exe, nao pwsh. Um teste que so roda em
        # pwsh prova o runtime errado (finding Cross-Claude, 2026-09-12). Efeito colateral do hook
        # e so escrever em <cwd>/.deepseek/, e o cwd aqui e temporario -- seguro rodar o wrapper real.
        It "via .cmd (powershell.exe): mede e responde o mesmo JSON" {
            $t = New-Transcript -Tokens 160000
            $cwd = Split-Path $t -Parent
            $cmd = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.cmd"
            $payload = Join-Path $cwd "payload.json"
            @{ session_id = "cmd-$(Get-Random)"; transcript_path = $t; cwd = $cwd; hook_event_name = "PostToolUse" } | ConvertTo-Json -Compress | Set-Content -Path $payload -Encoding ascii
            Push-Location $cwd
            try { $out = cmd.exe /c "type `"$payload`" | `"$cmd`"" 2>$null; $code = $LASTEXITCODE } finally { Pop-Location }
            $code | Should -Be 0
            ($out -join "") | Should -Match '"additionalContext"'
            ($out -join "") | Should -Match '160k'
        }

        It "via .sh (bash): mesmo valor em k que o .ps1 para o mesmo transcript (paridade)" {
            # Get-Command sozinho NAO acha o bash do Git (o pwsh nao tem o bin do Git no PATH), e
            # o skip silencioso fazia a paridade do .sh nunca ser verificada nesta maquina --
            # justamente o buraco calado que o kit existe pra evitar. Procura nos caminhos padrao.
            $bashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
            if (-not $bashPath) {
                $bashPath = @(
                    "$env:ProgramFiles\Git\bin\bash.exe",
                    "$env:ProgramFiles\Git\usr\bin\bash.exe",
                    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
                    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
                ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
            }
            if (-not $bashPath) { Set-ItResult -Skipped -Because "sem bash nesta maquina; paridade do .sh nao verificavel aqui" ; return }
            $bash = [pscustomobject]@{ Source = $bashPath }
            # 160.500: banker's rounding daria 160k e half-up daria 161k -- e exatamente o caso que divergia
            $t = New-Transcript -Tokens 160500
            $cwd = Split-Path $t -Parent
            $rPs = Invoke-Guard -Transcript $t -SessionId "par-ps" -Cwd $cwd
            $sh = Join-Path $PSScriptRoot ".." "hooks" "context-budget-guard.sh"
            $payload = @{ session_id = "par-sh"; transcript_path = $t; cwd = $cwd; hook_event_name = "PostToolUse" } | ConvertTo-Json -Compress
            Push-Location $cwd
            try { $outSh = ($payload | & $bash.Source $sh 2>$null) -join "" } finally { Pop-Location }
            $kPs = [regex]::Match($rPs.Json.hookSpecificOutput.additionalContext, '~(\d+)k').Groups[1].Value
            $kSh = [regex]::Match($outSh, '~(\d+)k').Groups[1].Value
            $kSh | Should -Be $kPs -Because "as duas implementacoes tem que medir a mesma coisa (ps=$kPs sh=$kSh)"
            $kPs | Should -Be "161"
            # Comparar so o k deixou o % divergir calado (Round no .ps1 vs truncamento no .sh:
            # 80,75 -> 81 contra 80). Paridade e da MENSAGEM inteira, nao de um campo escolhido.
            $msgPs = $rPs.Json.hookSpecificOutput.additionalContext
            $msgSh = ($outSh | ConvertFrom-Json).hookSpecificOutput.additionalContext
            $msgSh | Should -Be $msgPs -Because "as duas implementacoes tem que dizer a MESMA coisa`nps: $msgPs`nsh: $msgSh"
        }
    }
}
