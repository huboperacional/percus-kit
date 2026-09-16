#requires -Version 5.1

Describe "external-action-guard.ps1 hook" {
    BeforeAll {
        $script:hookPath = Join-Path $PSScriptRoot ".." "hooks" "external-action-guard.ps1"

        # Invoca o hook com um cwd controlado -- o hook le (Get-Location).Path pra montar o
        # caminho do arquivo de autorizacao, entao os testes precisam simular "rodando de
        # dentro do projeto X" sem tocar o .percus/ real do repo.
        function Invoke-HookEmDir {
            param([string]$Dir, [string]$Stdin)
            Push-Location $Dir
            try {
                return ($Stdin | & pwsh -NoProfile -File $script:hookPath 2>&1)
            } finally {
                Pop-Location
            }
        }

        # Planta um arquivo de autorizacao fixture com idade controlada (em minutos atras de
        # agora), no formato timestamp_unix que o hook espera.
        function New-AutorizacaoFixture {
            param([string]$Dir, [double]$IdadeMinutos = 5, [string]$Motivo = "teste")
            $percusDir = Join-Path $Dir ".percus"
            New-Item -ItemType Directory -Path $percusDir -Force | Out-Null
            $quando = (Get-Date).AddMinutes(-$IdadeMinutos)
            $epoch = [DateTimeOffset]::new($quando).ToUnixTimeSeconds()
            $auth = [pscustomobject]@{
                id             = [guid]::NewGuid().ToString()
                motivo         = $Motivo
                autorizado_em  = $quando.ToString("o")
                timestamp_unix = $epoch
            }
            $caminho = Join-Path $percusDir "acao-externa-autorizada.json"
            ($auth | ConvertTo-Json) | Set-Content -LiteralPath $caminho -Encoding utf8
            return $caminho
        }
    }

    It "existe" {
        Test-Path $hookPath | Should -Be $true
    }

    It "permite tool nao-externo (echo hello)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $stdin = '{"tool_input":{"command":"echo hello"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 0
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "permite gh pr list (read-only)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $stdin = '{"tool_input":{"command":"gh pr list"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 0
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "bloqueia gh pr comment sem aprovacao operador" {
        # Setup: sem .deepseek/council-log/ ou council log antigo > 5min OU premise_validity ruim
        # No env override
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"gh pr comment 123 --body \"test\""}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "gh pr comment requer aprovacao R20"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "permite gh pr comment com PERCUS_EXTERNAL_OVERRIDE setado" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $stdin = '{"tool_input":{"command":"gh pr comment 123 --body test"}}'
        $env:PERCUS_EXTERNAL_OVERRIDE = "1"
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $LASTEXITCODE | Should -Be 0
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "bloqueia slack-cli send" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"slack-cli send --channel general msg"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "bloqueia gh issue close" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"gh issue close 42"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    # --- wrapper local que executa em OUTRA maquina (add. 2026-08-21) ---
    #
    # 🔑 Nasceu de um caso medido: o guard barrou o comando remoto direto, mas o MESMO efeito
    # passou batido pelo wrapper do projeto, porque o texto do comando nao carrega a palavra que
    # o padrao procura. O bloco "o que ele continua sem cobrir" ja declarava essa lacuna; estes
    # testes a estreitam para a familia cujo NOME declara destino remoto.
    #
    # ⛔ Os dois ultimos It sao tao importantes quanto os tres primeiros: um guard que impede
    # LER ou CITAR o wrapper vira imposto, e imposto acaba desligado -- e ai nao guarda nada.
    It "bloqueia wrapper local que executa em outra maquina -- <Cmd>" -ForEach @(
        @{ Cmd = "python scripts/vps_exec.py uptime" }
        @{ Cmd = "python3 scripts/vps_put.py local.txt /root/x" }
        @{ Cmd = "python scripts/vps_upload_stream.py a.bundle /root/a.bundle" }
    ) {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"' + $Cmd + '"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    # 🔴 LACUNA DECLARADA, e ela e a causa raiz das divergencias que este bloco corrige: esta
    # suite exercita SO o hook .ps1. O gemeo .sh nao tem teste automatizado nenhum, entao a
    # unica coisa que impede os dois de divergirem e alguem medir na mao. Em 2026-08-21 os dois
    # divergiram TRES vezes seguidas (fronteira antes do token, `_` como separador, fronteira
    # depois da extensao) e as tres so apareceram porque foram medidas.
    # Ate existir suite para o .sh, re-verifique assim, com os MESMOS casos do -ForEach abaixo:
    #   echo '{"tool_input":{"command":"python myvps.py"}}' > /tmp/c.json
    #   bash hooks/external-action-guard.sh < /tmp/c.json ; echo $?
    # Esperado: 2 = bloqueou, 0 = passou. Tem que bater com o `Esperado` de cada caso aqui.

    # ⚠️ Fronteira de TOKEN, e os dois lados sao deliberados. O review cross-provider pegou que a
    # 1a versao do gemeo .sh nao exigia fronteira: `myvps.py` bloqueava no bash e passava no
    # PowerShell -- bypass num dos provedores. Alinhado pela semantica de token (a do .ps1) em vez
    # de afrouxar, porque afrouxar bloquearia `transship.py`, que contem "ssh" no meio de uma
    # palavra e nao tem nada de remoto.
    It "so casa vps/ssh como TOKEN do nome, nunca no meio de palavra -- <Cmd>" -ForEach @(
        @{ Cmd = "python scripts/vps_exec.py uptime"; Esperado = 2 }
        @{ Cmd = "bash deploy-vps.sh"; Esperado = 2 }
        @{ Cmd = "python ssh_tunnel.py"; Esperado = 2 }
        @{ Cmd = "python transship.py"; Esperado = 0 }
        @{ Cmd = "python myvps.py"; Esperado = 0 }
        # ⛔ Estes dois vieram do review cross-provider, e cada um era um bypass POR PROVEDOR:
        # `_` e separador (o `\b` do .NET discordava do `[^[:alnum:]]` do ERE), e a extensao
        # precisa de fronteira no fim (so o .ps1 tinha). Se um dia divergirem de novo, e aqui
        # que aparece.
        @{ Cmd = "python my_vps.py"; Esperado = 2 }
        @{ Cmd = "python vps_exec.pyfoo"; Esperado = 0 }
    ) {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"' + $Cmd + '"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be $Esperado
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "NAO bloqueia LER ou CITAR o wrapper, so EXECUTAR -- <Cmd>" -ForEach @(
        @{ Cmd = "cat scripts/vps_exec.py" }
        @{ Cmd = "grep -n vps_exec docs/RUNBOOK_DEPLOY.md" }
    ) {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"' + $Cmd + '"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 0
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "permite git push se override setado (R20 escape)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $env:PERCUS_EXTERNAL_OVERRIDE = "1"
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $LASTEXITCODE | Should -Be 0
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "stderr message inclui R20 reference" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"gh pr comment 123 --body x"}}'
        $errOutput = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        ($errOutput -join " ") | Should -Match "R20|external-action-guard"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "graceful em stdin vazio (exit 0)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $null = Invoke-HookEmDir -Dir $dir -Stdin ""
        $LASTEXITCODE | Should -Be 0
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "barra a mesma acao vinda de QUALQUER tool -- <Tool>" -ForEach @(
        @{ Tool = "Bash" }
        @{ Tool = "PowerShell" }
    ) {
        # Ate 2026-07-31 o matcher era "Bash" e mais nada, e o harness expoe DUAS tools de shell.
        # Medido no mesmo instante e na mesma maquina: a mesma acao externa barrada pela tool Bash
        # e livre pela tool PowerShell. Foi por esse caminho que o push de 2026-07-30 saiu.
        #
        # O conserto e no matcher (Task 4), nao aqui: este hook nunca olhou tool_name, sempre leu
        # tool_input.command, que as duas tools preenchem. Este It amarra esse "sempre" -- se
        # alguem introduzir ramificacao por tool_name, o matcher entregaria a chamada e o hook a
        # descartaria em silencio, e o teste do matcher sozinho seguiria verde.
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_name":"' + $Tool + '","tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "acao externa pela tool $Tool tem que barrar igual"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "permite acao externa com autorizacao em lote fresca (timestamp_unix recente)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 0 -Because "autorizacao em lote fresca deve liberar"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "NAO permite acao externa com autorizacao em lote expirada (timestamp_unix ha mais de 60min)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 61 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "autorizacao expirada nao pode liberar"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "BLOQUEIA (fail-closed) quando o arquivo de autorizacao tem JSON corrompido" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $percusDir = Join-Path $dir ".percus"
        New-Item -ItemType Directory -Path $percusDir -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $percusDir "acao-externa-autorizada.json"), "{ isto nao e json", (New-Object System.Text.UTF8Encoding($false)))
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $saida = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "JSON corrompido nao pode liberar -- fail-closed desta checagem especifica"
        ($saida -join " ") | Should -Match "falha ao processar autorizacao em lote" -Because "erro tecnico tem que ser distinguivel de 'nunca autorizado' no log (achado R11/DeepSeek)"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "BLOQUEIA quando o arquivo de autorizacao existe mas NAO tem timestamp_unix" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $percusDir = Join-Path $dir ".percus"
        New-Item -ItemType Directory -Path $percusDir -Force | Out-Null
        '{"id":"x","motivo":"sem timestamp"}' | Set-Content -LiteralPath (Join-Path $percusDir "acao-externa-autorizada.json") -Encoding utf8
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "sem timestamp_unix nao da pra calcular idade -- bloqueia, nao libera"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "autorizacao criada num diretorio NAO libera acao rodada em outro diretorio (escopo por-projeto)" {
        $dirAutorizado = Join-Path ([IO.Path]::GetTempPath()) ("eag-auth-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $dirOutro      = Join-Path ([IO.Path]::GetTempPath()) ("eag-outro-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dirOutro -Force | Out-Null
        New-AutorizacaoFixture -Dir $dirAutorizado -IdadeMinutos 5 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dirOutro -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "autorizacao de outro diretorio nao pode vazar"
        Remove-Item -Recurse -Force $dirAutorizado,$dirOutro -ErrorAction SilentlyContinue
    }

    It "cobre acao externa alem de git push -- slack-cli tambem e liberado pela autorizacao em lote" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"slack-cli send --channel geral msg"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 0 -Because "escopo cobre TODAS as acoes externas do R20, nao so push"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    # -------------------------------------------------------------------------
    # Auditoria gravada pelo PROPRIO hook (v6.36.7).
    #
    # Ate 6.36.6 a linha em .percus/autorizacoes-usadas.jsonl dependia de o AGENTE lembrar de
    # chamar scripts/registrar-uso-autorizacao.ps1. Medido em 2026-08-17: o push saiu 07:37:49
    # e o log parou em 2026-08-16 -- a promessa em prosa quebrou calada, que e como promessa em
    # prosa quebra. O hook ja roda em toda acao externa, ja le a autorizacao e ja conhece o
    # comando; gravar aqui torna o log completo por construcao.
    #
    # O hook e PreToolUse: ele registra AUTORIZACAO CONCEDIDA, nao execucao concluida. Por isso
    # a linha carrega origem="hook" -- distingue das linhas que o agente/operador escrevem pelo
    # script depois do fato.
    # -------------------------------------------------------------------------

    It "registra o uso em .percus/autorizacoes-usadas.jsonl ao liberar pela autorizacao em lote" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $caminho = New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 -Motivo "fim do dia"
        $auth = Get-Content $caminho -Raw -Encoding UTF8 | ConvertFrom-Json
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin

        $logPath = Join-Path $dir ".percus\autorizacoes-usadas.jsonl"
        Test-Path $logPath | Should -Be $true -Because "liberar sem registrar e o defeito de 2026-08-17"
        $linhas = @(Get-Content $logPath)
        $linhas.Count | Should -Be 1
        $linha = $linhas[0] | ConvertFrom-Json
        $linha.id      | Should -Be $auth.id
        $linha.motivo  | Should -Be "fim do dia"
        $linha.comando | Should -Be "git push origin main"
        $linha.quando  | Should -Not -BeNullOrEmpty
        $linha.origem  | Should -Be "hook" -Because "PreToolUse registra autorizacao concedida, nao execucao concluida"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "NAO registra nada quando a autorizacao esta expirada (bloqueou, nao usou)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 61 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2 -Because "sem conferir o exit, 'nao gravou' tambem seria verdade se o hook tivesse quebrado por outro motivo"
        Test-Path (Join-Path $dir ".percus\autorizacoes-usadas.jsonl") | Should -Be $false -Because "log de uso registra USO, e acao bloqueada nao e uso"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "NAO registra nada quando nao ha autorizacao nenhuma" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $LASTEXITCODE | Should -Be 2
        Test-Path (Join-Path $dir ".percus\autorizacoes-usadas.jsonl") | Should -Be $false
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "NAO registra quando libera por PERCUS_EXTERNAL_OVERRIDE (nao e a autorizacao em lote)" {
        # O log audita a autorizacao em lote, que e o mecanismo que o AGENTE cria pra si mesmo.
        # PERCUS_EXTERNAL_OVERRIDE exige acao humana fora da sessao -- outro mecanismo, outra
        # trilha. Misturar os dois no mesmo arquivo faria o log dizer "a autorizacao X liberou
        # isto" quando nao foi ela. Decisao ja registrada no spec de 2026-08-06, item 4.
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        $env:PERCUS_EXTERNAL_OVERRIDE = "1"
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        $codigo = $LASTEXITCODE
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $codigo | Should -Be 0 -Because "sem esta assercao o teste passaria mesmo se o override tivesse regredido e BLOQUEADO -- 'nao gravou log' e verdade nos dois casos"
        Test-Path (Join-Path $dir ".percus\autorizacoes-usadas.jsonl") | Should -Be $false
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "duas acoes na mesma janela geram DUAS linhas (o lote continua sendo lote)" {
        # Regressao da decisao de 2026-08-06: uma autorizacao libera VARIAS acoes ate expirar.
        # Se algum dia alguem resolver "consumir no uso", este teste cai -- que e o ponto.
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $null = Invoke-HookEmDir -Dir $dir -Stdin '{"tool_input":{"command":"git push origin main"}}'
        $primeiroExit = $LASTEXITCODE
        $null = Invoke-HookEmDir -Dir $dir -Stdin '{"tool_input":{"command":"gh pr comment 7 --body ok"}}'
        $segundoExit = $LASTEXITCODE

        $primeiroExit | Should -Be 0
        $segundoExit  | Should -Be 0 -Because "a segunda acao na mesma janela tem que continuar passando"
        $linhas = @(Get-Content (Join-Path $dir ".percus\autorizacoes-usadas.jsonl"))
        $linhas.Count | Should -Be 2
        ($linhas[0] | ConvertFrom-Json).comando | Should -Be "git push origin main"
        ($linhas[1] | ConvertFrom-Json).comando | Should -Be "gh pr comment 7 --body ok"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "BLOQUEIA quando nao consegue gravar a auditoria, e diz que foi isso" {
        # Decisao do operador (2026-08-17): a auditoria e parte do gate, nao contabilidade a
        # parte. Se a linha nao pode ser gravada, a acao nao sai. Um push bloqueado se resolve
        # com um comando; uma linha de auditoria que nunca existiu e invisivel pra sempre --
        # que foi exatamente o desfecho de 2026-08-17.
        #
        # Falha forcada trocando o arquivo de log por um DIRETORIO de mesmo nome: AppendAllText
        # levanta UnauthorizedAccessException de forma deterministica, sem depender de ACL do
        # Windows (que nao vale nada quando o processo roda como administrador).
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $dir ".percus\autorizacoes-usadas.jsonl") -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $saida = Invoke-HookEmDir -Dir $dir -Stdin $stdin

        $LASTEXITCODE | Should -Be 2 -Because "sem auditoria nao ha acao externa"
        ($saida -join " ") | Should -Match "nao consegui registrar o uso" -Because "tem que ser distinguivel de 'nunca autorizado' e de 'autorizacao corrompida'"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "hook e registrar-uso-autorizacao.ps1 gravam a MESMA convencao de bytes no log (paridade)" {
        # #regra-duplicada-ps1-sh: dois escritores do MESMO arquivo, cada um com seu teste, ficam
        # verdes lado a lado enquanto divergem -- a divergencia nao e observavel de dentro de um
        # lado so. Este teste compara as DUAS copias, que e a regra pratica do verbete.
        #
        # A divergencia concreta que ele existe pra pegar: `Add-Content -Encoding UTF8` grava COM
        # BOM no 5.1 e SEM BOM no pwsh 7. Como o hook roda sob 5.1 e o script pode rodar sob os
        # dois, o mesmo .jsonl acabaria com linhas de encodings diferentes -- e o BOM no meio do
        # arquivo nao e separador, e byte de dado.
        #
        # TEM que rodar sob powershell.exe 5.1: sob pwsh os dois escrevem sem BOM e o teste
        # passaria verde com a divergencia intacta (mesma cegueira descrita em ps51-compat).
        $ps51 = Get-Command powershell.exe -ErrorAction SilentlyContinue
        if (-not $ps51) {
            Set-ItResult -Skipped -Because "sem powershell.exe 5.1 esta maquina nao roda o hook em producao"
            return
        }
        $kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        # codepoints: c-cedilha=0x00E7  a-til=0x00E3 -- literal acentuado neste .ps1 sem BOM
        # reproduziria a propria classe de bug que o teste afere.
        $motivo = "autoriza" + [char]0x00E7 + [char]0x00E3 + "o de fim de dia"
        # Comando COM credencial: a mascara existe duplicada nos dois escritores (nao da pra
        # compartilhar funcao entre o plugin instalado e o kit), entao e obrigatorio que a
        # paridade exercite justamente ela -- mascara que diverge produz um arquivo onde metade
        # das linhas vaza e metade nao.
        # Tres credenciais de FAMILIAS diferentes num comando so: exercita as regras 1, 3 e 4 da
        # mascara numa passada. A 1a versao deste teste usava so a forma de URL, entao as outras
        # regras nao tinham paridade aferida -- divergencia nelas passaria verde, que e exatamente
        # o buraco que este teste existe pra fechar. Achado do R11/Cross-Claude.
        $segA = "ghp_ParidadeUrl111"
        $segB = "ghp_ParidadeHeader222"
        $segC = "xoxb-ParidadeFlag333"
        $segD = "ghp_ParidadeChaveValor444"
        $segredoParidade = @($segA, $segB, $segC, $segD)
        # As QUATRO regras num comando so. A versao anterior deixava a regra 2 (chave=valor) sem
        # paridade aferida -- divergencia nela passaria com a suite toda verde, que e a doenca que
        # este teste existe pra impedir. Achado do R11/DeepSeek.
        # Em `gh`, e nao em `git`: desde a Fase 5 (rodada 2) o hook so libera git na forma simples
        # (sem VAR= na frente, sem aspas fora do -C); gh aceita os dois, e a mascara e a mesma.
        # URL sem `.git`: `x.git ` e token `git` para a deteccao larga, e o trecho viraria git fora da forma simples.
        $comando = "GH_TOKEN=$segD gh pr comment 1 --body https://percus:$segA@github.com/hub/x --header `"Authorization: Bearer $segB`" --token $segC"

        $dirHook   = Join-Path ([IO.Path]::GetTempPath()) ("par-h-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $dirScript = Join-Path ([IO.Path]::GetTempPath()) ("par-s-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dirHook,$dirScript -Force | Out-Null
        & (Join-Path $kitRoot "scripts\autorizar-acao-externa.ps1") -Motivo $motivo -ProjetoRoot $dirHook   | Out-Null
        & (Join-Path $kitRoot "scripts\autorizar-acao-externa.ps1") -Motivo $motivo -ProjetoRoot $dirScript | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue

        Push-Location $dirHook
        try {
            # Aspas do comando ESCAPADAS: o comando de paridade carrega um header entre aspas, e
            # sem escapar o stdin deixa de ser JSON valido -- o hook cai no catch, sai 0 sem
            # gravar, e o teste acusaria "nao gravou" por defeito do proprio teste.
            ('{"tool_input":{"command":"' + ($comando -replace '"', '\"') + '"}}') |
                & $ps51.Source -NoProfile -ExecutionPolicy Bypass -File $script:hookPath 2>&1 | Out-Null
        } finally { Pop-Location }

        & $ps51.Source -NoProfile -ExecutionPolicy Bypass -File (Join-Path $kitRoot "scripts\registrar-uso-autorizacao.ps1") `
            -Comando $comando -ProjetoRoot $dirScript 2>&1 | Out-Null

        $bytesHook   = [IO.File]::ReadAllBytes((Join-Path $dirHook   ".percus\autorizacoes-usadas.jsonl"))
        $bytesScript = [IO.File]::ReadAllBytes((Join-Path $dirScript ".percus\autorizacoes-usadas.jsonl"))

        $temBom = { param($b) $b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF }
        (& $temBom $bytesHook)   | Should -Be $false -Because "BOM no meio de um .jsonl append-only vira byte de dado"
        (& $temBom $bytesScript) | Should -Be $false -Because "o script escreve no MESMO arquivo que o hook"

        # Ancora ABSOLUTA antes da comparacao relativa. Comparar so hook-contra-script pega
        # divergencia entre os dois e NAO pega os dois regredindo juntos -- que e plausivel
        # justamente porque um foi copiado do outro (foi assim que o BOM entrou nos dois). Sem o
        # valor fixo, este teste seria "verde lado a lado enquanto os DOIS quebram igual", que e a
        # mesma familia do defeito que ele existe pra impedir.
        $fimHook   = $bytesHook[($bytesHook.Length-2)..($bytesHook.Length-1)]
        $fimScript = $bytesScript[($bytesScript.Length-2)..($bytesScript.Length-1)]
        ($fimHook -join ",") | Should -Be "13,10" -Because "CRLF e a convencao do .jsonl neste repo -- valor fixo, nao so 'igual ao outro'"
        ($fimHook -join ",") | Should -Be ($fimScript -join ",") -Because "quebra de linha divergente parte o .jsonl pra quem le linha a linha"

        $linhaHook   = [Text.Encoding]::UTF8.GetString($bytesHook).Trim()   | ConvertFrom-Json
        $linhaScript = [Text.Encoding]::UTF8.GetString($bytesScript).Trim() | ConvertFrom-Json
        $linhaHook.motivo   | Should -Be $motivo -Because "motivo acentuado escrito pelo hook sob 5.1 real"
        $linhaScript.motivo | Should -Be $motivo -Because "motivo acentuado escrito pelo script sob 5.1 real"

        $camposHook   = ($linhaHook.PSObject.Properties.Name   | Sort-Object) -join ","
        $camposScript = ($linhaScript.PSObject.Properties.Name | Sort-Object) -join ","
        $camposHook | Should -Be "comando,id,motivo,origem,quando" -Because "conjunto de campos fixado em valor, nao so espelhado no outro escritor"
        $camposHook | Should -Be $camposScript -Because "quem le o log nao deveria precisar saber qual escritor produziu a linha"
        $linhaHook.origem   | Should -Be "hook"
        $linhaScript.origem | Should -Be "script"

        # Mascara identica dos dois lados, e nenhum dos dois deixa nenhuma das tres passar.
        $textoHook   = [Text.Encoding]::UTF8.GetString($bytesHook)
        $textoScript = [Text.Encoding]::UTF8.GetString($bytesScript)
        foreach ($s in $segredoParidade) {
            $textoHook   | Should -Not -Match ([regex]::Escape($s)) -Because "hook nao pode gravar credencial ($s)"
            $textoScript | Should -Not -Match ([regex]::Escape($s)) -Because "script escreve no MESMO arquivo -- mascarar so de um lado nao protege nada ($s)"
        }
        $linhaHook.comando | Should -Be $linhaScript.comando -Because "mascara divergente entre os dois escritores e a mesma doenca do BOM, em outro campo"
        $linhaHook.comando | Should -Be 'GH_TOKEN=*** gh pr comment 1 --body https://***@github.com/hub/x --header "Authorization: Bearer ***" --token ***' -Because "ancora absoluta: os dois regredindo juntos passariam numa comparacao so relativa"

        Remove-Item -Recurse -Force $dirHook,$dirScript -ErrorAction SilentlyContinue
    }

    It "falha TRANSIENTE nao bloqueia: destrava no meio e a acao passa com 1 linha gravada" {
        # O retry existe pra UM cenario: duas sessoes no mesmo checkout disputando o .jsonl, a
        # primeira tentativa esbarra em lock e a seguinte funciona. O teste de "falha sempre"
        # (bloqueio) nao exercita isso -- ali as 3 tentativas falham. Sem este caso, quebrar o
        # laco (break no lugar errado, $registrado nao resetado, condicao do for trocada) deixaria
        # a suite inteira verde, porque o unico comportamento que o retry entrega nunca e medido.
        #
        # ARITMETICA das margens, porque teste de tempo sem ela e roleta. Sendo S o startup do
        # pwsh, o hook tenta em S, S+200 e S+600 (os dois Start-Sleep do retry). O bloqueio some
        # em t=250 contado do inicio do teste. Como S >= 0, a ULTIMA tentativa acontece em
        # S+600 >= 600 > 250 -- ou seja, ela sempre encontra o caminho livre, para QUALQUER
        # startup. Falso-vermelho e impossivel por construcao, nao por sorte.
        #
        # O que varia com S e so quanto do retry fica exercitado: com S < 250 a 1a tentativa pega
        # o bloqueio (caso alvo); com S > 250 ela ja passa direto e o teste degrada para o caso
        # "sem bloqueio", que outro teste ja cobre -- verde, sem cobrir o retry.
        #
        # A 1a versao disto usava 700ms e o comentario afirmava "so pode dar falso-verde". Era
        # falso: com startup rapido a 3a tentativa caia ANTES da remocao e o teste acusava o retry
        # por um defeito do proprio teste. Achado do R11/Cross-Claude, que refez a conta.
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        $logPath = Join-Path $dir ".percus\autorizacoes-usadas.jsonl"
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue

        $stdinFile = Join-Path $dir "stdin.json"
        [IO.File]::WriteAllText($stdinFile, '{"tool_input":{"command":"git push origin main"}}', (New-Object System.Text.UTF8Encoding($false)))

        Push-Location $dir
        try {
            # Caminho ENTRE ASPAS: -ArgumentList junta o array com espaco e nao cita nada, e a
            # raiz deste kit tem espaco ("D:\Claud Automations\..."). Sem as aspas o pwsh recebe
            # o caminho partido e sai 64 (linha de comando invalida) -- que nao e 0 nem 2, entao
            # o teste acusaria o retry por um erro que e do arranjo do teste.
            $proc = Start-Process -FilePath "pwsh" `
                -ArgumentList @("-NoProfile", "-File", ('"' + $script:hookPath + '"')) `
                -RedirectStandardInput $stdinFile -WorkingDirectory $dir -NoNewWindow -PassThru
            Start-Sleep -Milliseconds 250
            Remove-Item -Recurse -Force $logPath -ErrorAction SilentlyContinue
            $proc.WaitForExit()
            $codigo = $proc.ExitCode
        } finally { Pop-Location }

        $codigo | Should -Be 0 -Because "bloqueio transitorio tem que ser absorvido pelo retry, nao virar BLOCK"
        $linhas = @(Get-Content $logPath)
        $linhas.Count | Should -Be 1 -Because "retry nao pode gravar a mesma linha duas vezes"
        ($linhas[0] | ConvertFrom-Json).comando | Should -Be "git push origin main"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "MASCARA credencial no comando gravado -- <Forma>" -ForEach @(
        # As formas vem de medicao, nao de imaginacao: o R11/Cross-Claude rodou cada uma contra a
        # 1a versao da mascara e mostrou quais escapavam. A que mais importa e "URL token como
        # usuario" -- `https://TOKEN@host`, a forma MAIS comum de push com PAT do GitHub, que a
        # 1a versao deixava passar inteira enquanto mascarava a variante rara `user:token@`.
        @{ Forma = "URL usuario:token";     Comando = 'git push https://percus:SEGREDO@github.com/h/x.git main' }
        @{ Forma = "URL token como usuario";Comando = 'git push https://SEGREDO@github.com/h/x.git main' }
        @{ Forma = "Authorization Bearer";  Comando = 'gh pr comment 1 --body ok --header "Authorization: Bearer SEGREDO"' }
        @{ Forma = "Authorization token";   Comando = 'gh pr comment 1 --body ok --header "Authorization: token SEGREDO"' }
        @{ Forma = "flag --token";          Comando = 'slack-cli send --token SEGREDO --channel geral oi' }
        @{ Forma = "env GH_TOKEN=";         Comando = 'GH_TOKEN=SEGREDO gh issue close 42' }
        # Valor ENTRE ASPAS: [^\s"'] recusa a aspa de abertura, entao estas nao casavam em regra
        # NENHUMA e iam pro disco em claro. Medido: 4 de 9 formas vazavam por isto -- e escrever
        # valor entre aspas e a forma normal, nao a exotica.
        @{ Forma = "flag com aspas duplas"; Comando = 'slack-cli send --token "SEGREDO" --channel geral oi' }
        @{ Forma = "flag com aspas simples";Comando = "slack-cli send --token 'SEGREDO' --channel geral oi" }
        @{ Forma = "curl -u com aspas";     Comando = 'gh issue close 42 --user "percus:SEGREDO"' }
        # Aspa ENTRE esquema e valor, e valor citado COM ESPACO: os dois vazavam pelo mesmo
        # buraco -- nao existia uma nocao de "valor", existiam tres aproximacoes.
        @{ Forma = "Bearer com valor citado"; Comando = "gh pr comment 1 --body ok --header 'Authorization: Bearer `"SEGREDO`"'" }
        @{ Forma = "valor citado com espaco"; Comando = 'slack-cli send --token "SEGREDO com espaco" --channel geral oi' }
    ) {
        # A gravacao automatica introduziu um vazamento que nao existia: ate 6.36.6 o agente
        # escolhia o que passar pro registrar-uso; agora TODO comando autorizado e persistido em
        # texto claro, sem ninguem decidir. `git push https://user:token@host` e a forma mais
        # comum -- o token fica no arquivo, que sobrevive a sessao e e lido por qualquer um com
        # acesso ao checkout. Achado do R11/DeepSeek na revisao desta versao.
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 | Out-Null
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $segredo = "ghp_TOKENsecretoQUEnaoPODEvazar123"
        $cmd = $Comando.Replace("SEGREDO", $segredo)
        $stdin = '{"tool_input":{"command":"' + ($cmd -replace '"', '\"') + '"}}'
        $null = Invoke-HookEmDir -Dir $dir -Stdin $stdin

        $LASTEXITCODE | Should -Be 0 -Because "mascarar nao pode transformar acao autorizada em bloqueio"
        $bruto = Get-Content (Join-Path $dir ".percus\autorizacoes-usadas.jsonl") -Raw -Encoding UTF8
        $bruto | Should -Not -Match ([regex]::Escape($segredo)) -Because "o segredo nao pode chegar ao disco"
        ($bruto.Trim() | ConvertFrom-Json).comando | Should -Match "\*\*\*" -Because "mascarar e substituir, nao apagar a linha inteira"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "mensagem de BLOCK tambem nao vaza credencial -- <Caso>" -ForEach @(
        # A 1a versao mascarava DENTRO do ramo autorizado: o arquivo ficava limpo e o comando cru
        # continuava saindo pelo stderr nas mensagens de bloqueio. Mascara que cobre um canal e
        # deixa o outro aberto nao e mascara, e falsa sensacao -- stderr de hook vai parar em log
        # de sessao e de CI. Achado do R11/DeepSeek.
        @{ Caso = "sem autorizacao";        ComAuth = $false }
        @{ Caso = "autorizacao expirada";   ComAuth = $true  }
    ) {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        if ($ComAuth) { New-AutorizacaoFixture -Dir $dir -IdadeMinutos 61 | Out-Null }
        else { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $segredo = "ghp_SegredoNaMensagemDeBloqueio777"
        $stdin = '{"tool_input":{"command":"git push https://' + $segredo + '@github.com/h/x.git main"}}'
        $saida = Invoke-HookEmDir -Dir $dir -Stdin $stdin

        $LASTEXITCODE | Should -Be 2
        ($saida -join " ") | Should -Not -Match ([regex]::Escape($segredo)) -Because "o comando aparece na mensagem de BLOCK, e ela vai pro stderr"
        ($saida -join " ") | Should -Match "\*\*\*" -Because "a mensagem continua mostrando QUAL comando foi barrado, so que mascarado"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }

    It "mensagem de stderr ao usar autorizacao em lote inclui id e motivo" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $caminho = New-AutorizacaoFixture -Dir $dir -IdadeMinutos 5 -Motivo "fim do dia, autorizado"
        $auth = Get-Content $caminho -Raw | ConvertFrom-Json
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        $stdin = '{"tool_input":{"command":"git push origin main"}}'
        $saida = Invoke-HookEmDir -Dir $dir -Stdin $stdin
        ($saida -join " ") | Should -Match ([regex]::Escape($auth.id))
        ($saida -join " ") | Should -Match "fim do dia, autorizado"
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
    }
}

# -----------------------------------------------------------------------------
# Fase 5 (2026-09-16), rodadas 2 e 3: deteccao larga, escopo fail-closed, e PELO DISPATCHER REAL.
#
# Historia medida: `git\s+push` deixava `git -C "<kit>" push` sair sem autorizacao e sem auditoria. A
# 1a correcao enumerou opcoes e deixou 20+ formas e um fail-open sob powershell.exe 5.1. A rodada 2
# chamava o guard DIRETO -- e a re-revisao mostrou o que isso escondia: a triagem do dispatcher (o
# gatilho `git` custava +0,6 s em 11% dos comandos), send-pack/http-push e `(...)` liberando com
# autorizacao, atalhos que desligam o pre-push sem push no texto, e entrada grande passando.
# Por isso esta matriz roda pelo dispatcher de cada runtime: `percus-dispatch-pre.cmd` (camada 1 +
# powershell.exe 5.1), `percus-dispatch-pre.ps1` sob pwsh 7 e `percus-dispatch-pre.sh`.
#
# Formato: esperado_ps | esperado_sh | autorizacao (none|A|AB|OV) | cwd (A|B|E) | forma
#   `0A1B0` = veredito do guard 0, 1 linha de auditoria em A, 0 em B. OV = PERCUS_EXTERNAL_OVERRIDE=1.
#   `!` = a mensagem tem de dizer "desligam o hook pre-push". `*` = qualquer bloqueio conta (entrada
#   grande: o .cmd trunca o JSON e o proprio dispatcher barra).
# Veredito do GUARD = stderr com "external-action-guard] BLOCK"; outro check barrando (pre-commit-check
# num `commit`) nao conta. O .sh e stub sem autorizacao: toda acao detectada sai 2.
# ATENCAO: nao use `$p` como variavel neste arquivo.
# -----------------------------------------------------------------------------
BeforeDiscovery {
    $matrizTexto = @'
# esperado_ps|esperado_sh|auth|cwd|forma   (! = mensagem "desligam o hook pre-push"; * = qualquer bloqueio do dispatcher conta)
# Veredito medido = o do GUARD (stderr com "external-action-guard] BLOCK"), pelo dispatcher real.
# --- matriz do revisor (casos.txt): toda forma de push sem autorizacao -> 2 ---
2|2|none|E|git push origin main
2|2|none|E|git -C dir push
2|2|none|E|git -C "<A>" push
2|2|none|E|git -C=dir push
2|2|none|E|git --git-dir=x push
2|2|none|E|git --work-tree=x push
2|2|none|E|git -c a=b -c c=d push
2|2|none|E|git    push
2|2|none|E|git<TAB>push
2|2|none|E|GIT_DIR=x git push
2|2|none|E|env git push
2|2|none|E|command git push
2|2|none|E|\git push
2|2|none|E|"git" push
2|2|none|E|git.exe push
2|2|none|E|/usr/bin/git push
2|2|none|E|true; git push
2|2|none|E|true && git push
2|2|none|E|false || git push
2|2|none|E|echo | git push
2|2|none|E|echo $(git push)
2|2|none|E|bash -c "git push"
2|2|none|E|bash -c "git -C \"<A>\" push"
2|2|none|E|git config alias.p push && git p
2|2|none|E|gh repo sync
2|2|none|E|gh pr create --fill
2|2|none|E|gh pr merge 1
2|2|none|E|gh pr -R o/r merge 1
2|2|none|E|gh release create v1
2|2|none|E|git "push" origin main
2|2|none|E|git 'push'
2|2|none|E|git -C "<A>" "push"
2|2|none|E|git -c alias.x=push x origin main
2|2|none|E|git -C <AESC> push origin main
2|2|none|E|git -C "<A>"/. push
2|2|none|E|git -C /tmp/"a b" push
2|2|none|E|git -c user.name="a b" push
2|2|none|E|git \<LF> push origin main
2|2|none|E|git -C "<A>" \<LF>  push origin main
2|2|none|E|git 2>/dev/null push
2|2|none|E|git -C "<A>" >log.txt push
2|2|none|E|git -C <A>>log.txt push
2|2|none|E|git --attr-source HEAD push
2|2|none|E|git${IFS}push
2|2|none|E|GIT push
2|2|none|E|Git.exe push
2|2|none|E|git lfs push
2|2|none|E|git subtree push --prefix=x origin main
2|2|none|E|x=push; git $x
2|2|none|E|git -Cdir push
2|2|none|E|git --no-pager -C "<A>" -c k=v push
2|2|none|E|git -C "a|b" push
2|2|none|E|git -C "a<b" push
# --- ofuscacao que nao traz `push` literal: nao chega a camada 1 pelo dispatcher (aceito; o pre-push pega) ---
0|0|none|E|git p\ush
0|0|none|E|git pu"sh"
# --- casos2 do revisor ---
2|2|none|E|git -C D:/x>log.txt push origin main
2|2|none|E|git push origin main; git -C "a|b" push
2|2|none|E|git push origin main && git -C D:/x>log.txt push
2|2|none|E|git -C "a<TAB>b" push
2|2|none|E|bash -c "git -C \"D:/x\" push origin main"
2|2|none|E|git -C D:/Claud\ Automations/percus-kit push origin main
2|2|none|E|git -C "D:/x" push origin main 2>&1 | tail -3
# --- negativos ---
0|0|none|E|git -C "<A>" status
0|0|none|E|git -C "<A>" pull
0|0|none|E|git log --oneline -3
# --- falso positivo aceito ---
2|2|none|E|git -C "<A>" log --grep push
# --- com autorizacao: forma simples libera e audita no repo certo ---
0A1B0|2|A|B|git -C "<A>" push origin main
0A1B0|2|A|B|git -C '<A>' push origin main
0A1B0|2|A|E|git -C "<A>" push origin main 2>&1 | tail -3
0A1B0|2|A|E|git -C "<APOSIX>" push origin main
0A1B0|2|A|A|git push origin main
0A1B0|2|A|A|git -C "<A>" log --grep push
0A1B0|2|A|A|gh pr create --fill
0A1B0|2|A|A|GH_TOKEN=x gh pr -R o/r merge 1
# --- com autorizacao: escopo ambiguo bloqueia ---
2A0B0|2|A|A|git -C "$VAR" push
2A0B0|2|A|A|cd "<B>" && git -C sub push
2A0B0|2|A|A|cd "<B>" && git -C . push
2A0B0|2|A|A|git -C "$X/.." push
2A0B0|2|A|A|git --git-dir="<B>/.git" push
2A0B0|2|A|A|cd "<B>" && git push
2A0B0|2|A|A|git -C "<A>/.." push
2A0B0|2|A|A|git -C "<A>/sub/.." push
2A0B0|2|A|E|git -C sub push
2A0B0|2|A|A|GIT_DIR="<B>/.git" git push
2A0B0|2|A|A|git -C %USERPROFILE% push
2A0B0|2|AB|A|git -C "<A>" push; git -C "<B>" push
2A0B0|2|A|A|git push; git -C "<B>" push
2A0B0|2|A|A|git -C "<A>" push && git -C "<B>" "push"
2A0B0|2|A|A|git -C "<A>" push && cd "<B>" && git push
2A0B0|2|A|B|git -C "<A>" push; git -C "<A>/" push
2A0B0|2|A|A|git -C "<A>" push origin main; git -C "a|b" push
2A0B0|2|A|A|git -C D:/x>log.txt push origin main
2A0B0|2|A|A|git -C <AESC> push origin main
2A0B0|2|A|A|bash -c "git -C \"<A>\" push"
2A0B0|2|A|A|git -c alias.x=push x
2A0B0|2|A|A|git "push"
# --- camada 2: formas que desligam o hook bloqueiam SEMPRE ---
2!|2!|none|E|git -C "<A>" push --no-verify origin main
2A0B0!|2!|A|A|git -C "<A>" push --no-verify origin main
2A0B0!|2!|A|A|git -C "<A>" push --no-verif origin main
2A0B0!|2!|A|A|git -C "<A>" --no-verify push origin main
2A0B0!|2!|A|A|git -C "<A>" push -n origin main
2A0B0!|2!|A|A|git -C "<A>" push -fn origin main
2A0B0!|2!|A|A|git -c core.hooksPath=/dev/null push origin main
2A0B0!|2!|A|A|git -c CORE.HOOKSPATH=x push origin main
2A0B0!|2!|A|A|git --config-env=core.hooksPath=H push
2A0B0!|2!|A|A|git --config-env=x.y=H push
2A0B0!|2!|A|A|GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=x git push
2A0B0!|2!|A|A|GIT_CONFIG_PARAMETERS="'core.hooksPath=x'" git push
2A0B0!|2!|A|A|GIT_CONFIG_GLOBAL=D:/x.cfg git push origin main
2A0B0!|2!|A|A|GIT_CONFIG_SYSTEM=D:/x.cfg git push origin main
2A0B0!|2!|A|A|GIT_CONFIG_NOSYSTEM=1 git push origin main
2A0B0!|2!|A|A|XDG_CONFIG_HOME=D:/x git push origin main
2A0B0!|2!|A|A|HOME=D:/x git push origin main
2A0B0!|2!|A|A|git -c include.path=x.cfg push
2A0B0!|2!|A|A|git -c includeIf.onbranch:main.path=x.cfg push
2A0B0!|2!|A|A|cp -r "<A>/.git" D:/c/.git && git -C "D:/c" push origin main
2A0B0!|2!|A|A|robocopy "<A>/.git" D:/c/.git /E & git -C "D:/c" push origin main
2A0B0!|2!|A|A|Copy-Item "<A>/.git" D:/c/.git -Recurse; git -C "D:/c" push origin main
2A0B0!|2!|A|A|xcopy "<A>/.git" D:/c/.git /E /I; git -C "D:/c" push origin main
2A0B0!|2!|A|A|git -C "<A>" push origin main --n\o-verify
2A0B0!|2!|A|A|git -C "<A>" -c core.hooks\Path=x push origin main
2A0B0!|2!|A|A|git -C "<A>" -c alias.pp="push --no-verify" pp origin main
2!|2!|OV|A|git -C "<A>" push --no-verify origin main
2!|2!|OV|A|git -c core.hooksPath=x push
2!|2!|OV|A|GIT_CONFIG_COUNT=1 git push
2!|2!|OV|A|HOME=D:/x git push
2!|2!|OV|A|git -c includeIf.onbranch:main.path=x.cfg push
0|0|OV|A|git push origin main
2|2|OV|A|cd "<B>" && git -C . push
2|2|OV|A|git -C "<A>" push; git -C "<B>" push
2|2|OV|A|git -C "$VAR" push
2|2|OV|A|git --git-dir="<B>/.git" push
# --- R3 item 2: send-pack / http-push bloqueiam SEMPRE ---
2!|2!|none|E|git send-pack origin main
2!|2!|none|E|git http-push https://example.com/r/ main
2A0B0!|2!|A|A|git -C "<A>" send-pack origin main
2A0B0!|2!|A|A|git -C "<A>" http-push https://example.com/r/ main
2A0B0!|2!|A|A|"C:/Program Files/Git/mingw64/libexec/git-core/git-send-pack.exe" origin main
2!|2!|OV|A|git -C "<A>" send-pack origin main
# --- R3 item 3: parenteses/subexpressao/splatting (tool PowerShell) ---
2|2|none|E|git -C "<A>" push origin main ('--no-'+'verify')
2A0B0|2|A|A|git -C "<A>" push origin main ('--no-'+'verify')
2A0B0|2|A|A|git -C "<A>" push origin main @('--no-'+'verify')
2A0B0|2|A|A|git -C "<A>" push origin main (Get-Content D:/x/flags.txt)
2A0B0|2|A|A|git -C "<A>" push origin main @flags
2|2|OV|A|git -C "<A>" push origin main (Get-Content D:/x/flags.txt)
0A1B0|2|A|A|gh pr create --title "fix (x)" --body "ok"
# --- R3 item 4: atalhos que desligam o pre-push SEM push no texto ---
2!|2!|none|E|git -C "<A>" config core.hooksPath /dev/null
2A0B0!|2!|A|A|git -C "<A>" config core.hooksPath /dev/null
2!|2!|OV|A|git -C "<A>" config core.hooksPath /dev/null
2!|2!|none|E|git config --global core.hooksPath D:/x
2!|2!|none|E|git config --system core.hooksPath D:/x
0|0|none|E|git -C "<A>" config --unset core.hooksPath
2!|2!|none|E|git config --unset core.hooksPath; git config core.hooksPath D:/x
2!|2!|none|E|rm -rf "<A>/.git/hooks"
2!|2!|none|E|rm -r .git/hooks
2A0B0!|2!|A|A|rm -rf "<A>/.git/hooks"
2!|2!|none|E|Remove-Item -Recurse "<AWIN>\.git\hooks"
2!|2!|none|E|Remove-Item -Recurse -Force .git\hooks\pre-push
2!|2!|none|E|del "<AWIN>\.git\hooks\pre-push"
2!|2!|none|E|rmdir /s /q "<AWIN>\.git\hooks"
2!|2!|none|E|mv .git/hooks/pre-push .git/hooks/pre-push.off
2!|2!|none|E|Rename-Item .git\hooks\pre-push pre-push.off
2!|2!|none|E|echo exit 0 > .git/hooks/pre-push
2!|2!|OV|A|rm -rf .git/hooks
0|0|none|E|cat .git/hooks/pre-push
0|0|none|E|Get-Content .git\hooks\pre-push
0|0|none|E|ls -la .git/hooks 2>&1
# --- R3 item 5: falsos positivos liberados ---
0|0|none|E|git stash push -m wip
0A0B0|0|A|A|git stash push -m wip
0|0|none|E|git stash push
0|0|none|E|git rev-parse @{push}
0A0B0|0|A|A|git rev-parse @{push}
0|0|none|E|git add plugin/percus-review/git-hooks/pre-push.template.sh
0|0|none|E|git branch push-x
2|2|none|E|git grep -n push
0A1B0|2|A|A|git grep -n push
0|0|none|E|git log -n 5 -- plugin/percus-review/git-hooks/pre-push.template.sh
0A0B0|0|A|A|git log -n 5 -- plugin/percus-review/git-hooks/pre-push.template.sh
0A1B0|2|A|A|git -C "<A>" commit -m "camada 2: bloqueia --no-verify no push"
0|0|none|E|git -C "<A>" commit -m "instalador respeita core.hooksPath no pre-push"
0A0B0|0|A|A|git -C "<A>" commit -m "instalador respeita core.hooksPath no pre-push"
0A1B0|2|A|A|git -C "<A>" push -o ci.skip origin main
0A1B0|2|A|A|git -C "<A>" push --force-with-lease origin main
2|2|none|E|Start-Process git -ArgumentList 'push','origin','main'
# --- R11 rodada 2 ---
0A1B0|2|A|E|git -C "<A>" push origin main 2>&1 | tail -n 3
0A1B0|2|A|A|git -C "<A>" push origin main | grep push
0A1B0|2|A|A|git -C "<A>" commit -m "corrige push"
0A1B0|2|A|A|Git -C "<A>" push origin main
# --- R3 item 6: comando grande com push bloqueia rapido (qualquer bloqueio conta: o .cmd trunca o JSON) ---
2*|2*|none|E|git push origin main <BIG100>
2*|2*|none|E|git push origin main <BIG300>
2*|2*|none|E|<BIG300> ; git push origin main
2*|2*|A|A|git -C "<A>" push origin main <BIG300>
'@
    $script:casosPorRuntime = @{ ps51 = @(); pwsh = @(); sh = @() }
    foreach ($linhaCaso in ($matrizTexto -split "`r?`n" | Where-Object { $_ -and -not $_.StartsWith('#') })) {
        $partes = $linhaCaso.Split('|', 5)
        foreach ($rt in @('ps51', 'pwsh', 'sh')) {
            $esp = $partes[0]
            if ($rt -eq 'sh') { $esp = $partes[1] }
            $script:casosPorRuntime[$rt] += @{
                Runtime = $rt; Esperado = $esp.Replace('!', '').Replace('*', ''); MsgPrePush = $esp.Contains('!')
                QualquerBloqueio = $esp.Contains('*'); Auth = $partes[2]; Cwd = $partes[3]; Forma = $partes[4]
            }
        }
    }
}

BeforeAll {
    $script:hooksR3 = Join-Path $PSScriptRoot ".." "hooks"
    $script:bashR3 = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    $script:ps51R3 = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source

    function New-LabR3 {
        $lab = Join-Path ([IO.Path]::GetTempPath()) ("eag-r3-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        $l = @{ Lab = $lab; A = (Join-Path $lab "repo A"); B = (Join-Path $lab "repo B"); E = (Join-Path $lab "vazio") }
        foreach ($d in @($l.A, $l.B, $l.E, (Join-Path $l.A "sub"))) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
        return $l
    }
    function Clear-EstadoR3 {
        param($Lab)
        foreach ($d in @($Lab.A, $Lab.B, $Lab.E)) {
            $pd = Join-Path $d ".percus"
            if (Test-Path -LiteralPath $pd) { [IO.Directory]::Delete($pd, $true) }
        }
    }
    function Set-AutorizacaoR3 {
        param([string]$Dir)
        $pd = Join-Path $Dir ".percus"
        New-Item -ItemType Directory -Force -Path $pd | Out-Null
        $q = (Get-Date).AddMinutes(-2)
        $o = [pscustomobject]@{ id = [guid]::NewGuid().ToString(); motivo = "matriz"; autorizado_em = $q.ToString("o"); timestamp_unix = [DateTimeOffset]::new($q).ToUnixTimeSeconds() }
        [IO.File]::WriteAllText((Join-Path $pd "acao-externa-autorizada.json"), ($o | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
    }
    function Get-LinhasR3 {
        param([string]$Dir)
        $l = Join-Path $Dir ".percus\autorizacoes-usadas.jsonl"
        if (-not (Test-Path -LiteralPath $l)) { return 0 }
        return @(Get-Content -LiteralPath $l | Where-Object { $_ }).Count
    }
    function Expand-FormaR3 {
        param([string]$Forma, $Lab)
        $fa = $Lab.A -replace '\\', '/'
        $fb = $Lab.B -replace '\\', '/'
        $posix = '/' + $Lab.A.Substring(0,1).ToLower() + ($Lab.A.Substring(2) -replace '\\', '/')
        return $Forma.Replace('<BIG100>', ('a ' * 50000)).Replace('<BIG300>', ('a ' * 150000)).Replace('<AESC>', ($fa -replace ' ', '\ ')).Replace('<APOSIX>', $posix).Replace('<AWIN>', $Lab.A).Replace('<A>', $fa).Replace('<B>', $fb).Replace('<LF>', "`n").Replace('<TAB>', "`t")
    }
    # Pelo dispatcher de cada runtime, com o payload completo do PreToolUse e sem PERCUS_CANON_DIR.
    function Invoke-DispatcherR3 {
        param([string]$Runtime, [string]$Cwd, [string]$Comando, $Lab)
        $json = [ordered]@{ session_id = "r3"; transcript_path = "C:\t\r3.jsonl"; cwd = $Cwd; permission_mode = "default"; hook_event_name = "PreToolUse"; tool_name = "Bash"; tool_input = [ordered]@{ command = $Comando; description = "Executa caso" } } | ConvertTo-Json -Compress
        $entrada = Join-Path $Lab.Lab ("in-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".json")
        [IO.File]::WriteAllText($entrada, $json, (New-Object System.Text.UTF8Encoding($false)))
        $erro = $entrada + ".err"
        switch ($Runtime) {
            'ps51' { $exe = 'cmd.exe'; $argumentos = @('/d', '/c', ('"' + (Join-Path $script:hooksR3 'percus-dispatch-pre.cmd') + '"')) }
            'pwsh' {
                # Copia separada: o mesmo arquivo como stdin redirecionado fica travado para o ReadAllText da camada 2.
                $copia = $entrada + ".payload.json"
                [IO.File]::WriteAllText($copia, $json, (New-Object System.Text.UTF8Encoding($false)))
                $exe = 'pwsh'; $argumentos = @('-NoProfile', '-File', ('"' + (Join-Path $script:hooksR3 'percus-dispatch-pre.ps1') + '"'), ('"' + $copia + '"'))
            }
            'sh'   { $exe = $script:bashR3; $argumentos = @(('"' + (Join-Path $script:hooksR3 'percus-dispatch-pre.sh') + '"')) }
        }
        $antes = $env:PERCUS_CANON_DIR
        Remove-Item env:PERCUS_CANON_DIR -ErrorAction SilentlyContinue
        try {
            $proc = Start-Process -FilePath $exe -ArgumentList $argumentos -WorkingDirectory $Cwd -RedirectStandardInput $entrada `
                -RedirectStandardError $erro -NoNewWindow -PassThru
            if (-not $proc.WaitForExit(60000)) { try { $proc.Kill() } catch {}; $codigo = -1 } else { $proc.WaitForExit(); $codigo = $proc.ExitCode }
        } finally {
            if ($antes) { $env:PERCUS_CANON_DIR = $antes }
        }
        $saidaErro = ''
        try { $saidaErro = [IO.File]::ReadAllText($erro) } catch {}
        [IO.File]::Delete($entrada); if (Test-Path -LiteralPath $erro) { [IO.File]::Delete($erro) }
        if (Test-Path -LiteralPath ($entrada + ".payload.json")) { [IO.File]::Delete($entrada + ".payload.json") }
        return [pscustomobject]@{ Codigo = $codigo; Stderr = $saidaErro }
    }
    function Test-CasoR3 {
        param([string]$Runtime, [string]$Esperado, [bool]$MsgPrePush, [bool]$QualquerBloqueio, [string]$Auth, [string]$Cwd, [string]$Forma, $Lab)
        Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        Clear-EstadoR3 $Lab
        if ($Auth -eq 'OV') { $env:PERCUS_EXTERNAL_OVERRIDE = "1" }
        else {
            if ($Auth -match 'A') { Set-AutorizacaoR3 $Lab.A }
            if ($Auth -match 'B') { Set-AutorizacaoR3 $Lab.B }
        }
        $dirCwd = @{ A = $Lab.A; B = $Lab.B; E = $Lab.E }[$Cwd]
        try {
            $r = Invoke-DispatcherR3 -Runtime $Runtime -Cwd $dirCwd -Comando (Expand-FormaR3 $Forma $Lab) -Lab $Lab
        } finally {
            Remove-Item env:PERCUS_EXTERNAL_OVERRIDE -ErrorAction SilentlyContinue
        }
        $r.Codigo | Should -Not -Be -1 -Because "timeout de hook NAO bloqueia: lento e fail-open"
        if ($QualquerBloqueio) { $obtido = $(if ($r.Codigo -ne 0) { '2' } else { '0' }) }
        else {
            $obtido = $(if ($r.Stderr -match 'external-action-guard\] BLOCK') { '2' } else { '0' })
            if ($Runtime -ne 'sh' -and $Auth -ne 'none' -and $Auth -ne 'OV') { $obtido += "A$(Get-LinhasR3 $Lab.A)B$(Get-LinhasR3 $Lab.B)" }
        }
        $obtido | Should -Be $Esperado -Because "stderr: $($r.Stderr)"
        if ($MsgPrePush) { $r.Stderr | Should -Match 'desligam o hook pre-push' }
        $r.Stderr | Should -Not -Match 'erro interno \(skip\)' -Because "catch generico liberando acao externa e fail-open"
    }
}

Describe "external-action-guard -- matriz pelo dispatcher [ps51: percus-dispatch-pre.cmd]" {
    BeforeAll { $script:labPs51 = New-LabR3 }
    AfterAll { if (Test-Path -LiteralPath $script:labPs51.Lab) { [IO.Directory]::Delete($script:labPs51.Lab, $true) } }
    It "auth=<Auth> cwd=<Cwd> :: <Forma> -> <Esperado>" -ForEach $script:casosPorRuntime['ps51'] {
        if (-not $script:ps51R3) { Set-ItResult -Skipped -Because "sem powershell.exe"; return }
        Test-CasoR3 -Runtime $Runtime -Esperado $Esperado -MsgPrePush $MsgPrePush -QualquerBloqueio $QualquerBloqueio -Auth $Auth -Cwd $Cwd -Forma $Forma -Lab $script:labPs51
    }
}

Describe "external-action-guard -- matriz pelo dispatcher [pwsh: percus-dispatch-pre.ps1]" {
    BeforeAll { $script:labPwsh = New-LabR3 }
    AfterAll { if (Test-Path -LiteralPath $script:labPwsh.Lab) { [IO.Directory]::Delete($script:labPwsh.Lab, $true) } }
    It "auth=<Auth> cwd=<Cwd> :: <Forma> -> <Esperado>" -ForEach $script:casosPorRuntime['pwsh'] {
        Test-CasoR3 -Runtime $Runtime -Esperado $Esperado -MsgPrePush $MsgPrePush -QualquerBloqueio $QualquerBloqueio -Auth $Auth -Cwd $Cwd -Forma $Forma -Lab $script:labPwsh
    }
}

Describe "external-action-guard -- matriz pelo dispatcher [sh: percus-dispatch-pre.sh]" {
    BeforeAll { $script:labSh = New-LabR3 }
    AfterAll { if (Test-Path -LiteralPath $script:labSh.Lab) { [IO.Directory]::Delete($script:labSh.Lab, $true) } }
    It "auth=<Auth> cwd=<Cwd> :: <Forma> -> <Esperado>" -ForEach $script:casosPorRuntime['sh'] {
        if (-not $script:bashR3) { Set-ItResult -Skipped -Because "sem bash"; return }
        Test-CasoR3 -Runtime $Runtime -Esperado $Esperado -MsgPrePush $MsgPrePush -QualquerBloqueio $QualquerBloqueio -Auth $Auth -Cwd $Cwd -Forma $Forma -Lab $script:labSh
    }
}

# Guard chamado DIRETO com JSON invalido sai != 0 (rodada 3). Pelo dispatcher ja bloqueava; direto, saia 0.
Describe "external-action-guard -- JSON invalido chamado direto" {
    It "[<Runtime>] <Nome> sai 2" -ForEach @(
        @{ Runtime = 'ps51'; Nome = 'truncado' }
        @{ Runtime = 'pwsh'; Nome = 'truncado' }
        @{ Runtime = 'sh'; Nome = 'truncado' }
    ) {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("eag-json-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $entrada = Join-Path $dir "in.json"
        [IO.File]::WriteAllText($entrada, ('{"tool_name":"Bash","tool_input":{"command":"git pu' + 'sh origin'), (New-Object System.Text.UTF8Encoding($false)))
        $guardPs1 = Join-Path $PSScriptRoot ".." "hooks" "external-action-guard.ps1"
        $guardSh = Join-Path $PSScriptRoot ".." "hooks" "external-action-guard.sh"
        switch ($Runtime) {
            'ps51' { $exe = 'powershell.exe'; $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $guardPs1 + '"')) }
            'pwsh' { $exe = 'pwsh'; $argumentos = @('-NoProfile', '-File', ('"' + $guardPs1 + '"')) }
            'sh'   { $exe = "$env:ProgramFiles\Git\bin\bash.exe"; $argumentos = @(('"' + $guardSh + '"')) }
        }
        $proc = Start-Process -FilePath $exe -ArgumentList $argumentos -WorkingDirectory $dir -RedirectStandardInput $entrada `
            -RedirectStandardError (Join-Path $dir "err.txt") -NoNewWindow -PassThru -Wait
        $proc.ExitCode | Should -Be 2
        [IO.Directory]::Delete($dir, $true)
    }
}
