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
                [int]$PaddingKB = 4
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
            [void]$sb.AppendLine('{"type":"assistant","timestamp":"' + $agora + '","message":{"role":"assistant","model":"claude-opus-5","usage":{"input_tokens":' + $inp + ',"cache_read_input_tokens":' + $cacheRead + ',"cache_creation_input_tokens":0,"output_tokens":12},"content":[{"type":"text","text":"ok"}]}}')
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

    Context "acima do limiar de aviso (150k): fala com o agente E com o operador" {
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

        It "160k -> systemMessage pro operador, com a assinatura do hook" {
            $t = New-Transcript -Tokens 160000
            $r = Invoke-Guard -Transcript $t
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
            $bash = Get-Command bash -ErrorAction SilentlyContinue
            if (-not $bash) { Set-ItResult -Skipped -Because "sem bash nesta maquina; paridade do .sh nao verificavel aqui" ; return }
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
        }
    }
}
