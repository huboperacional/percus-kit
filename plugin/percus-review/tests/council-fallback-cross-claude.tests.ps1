#requires -Version 5.1
# Prova que a perna Cross-Claude NUNCA morre calada.
#
# Bug medido em 2026-09-12, duas vezes na mesma sessao (consult e analyze de spec): a perna
# devolveu `400 Bad Request: Your credit balance is too low to access the Anthropic API` e o
# marcador `__PERCUS_NEEDS_CROSS_CLAUDE__` -- que existe justamente pra o agente completar a perna
# com um subagente -- NAO foi emitido. O conselho de 3 virou 2 e seguiu.
#
# Causa (council-orchestrator.ps1, linha ~326): a decisao de usar a API em vez do subagente e
# tomada ANTES de tentar, olhando so se a variavel ANTHROPIC_API_KEY EXISTE -- nunca se a chave
# FUNCIONA. Quando ela existe, o orchestrator seta $wantsCrossClaude = $false e o bloco que emite
# o marcador fica inalcancavel. Chave presente mas sem credito = perna morta em silencio.
#
# E a mesma classe do resposta-degradada.tests.ps1 (a coisa nao aconteceu e ninguem soube), so que
# um nivel acima: la era a RESPOSTA que mentia "ok"; aqui e a TENTATIVA que some.
#
# Aqui o orchestrator roda de verdade, com providers falsos, porque o defeito esta no fluxo de
# decisao dele -- um teste unitario da funcao nao alcancaria.

Describe "council-orchestrator -- perna Cross-Claude que falha cai no subagente" {

    BeforeAll {
        $script:pluginReal = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
        # Sem isto, cada rodada dos 11 casos deixa ~8 arvores de plugin em %TEMP%. Lixo de teste
        # em diretorio temporario compartilhado e a mesma classe de estado stale que esta versao
        # documenta -- nao da pra corrigir num arquivo e produzir no outro.
        $script:temporarios = New-Object System.Collections.Generic.List[string]

        # Copia o plugin pra um temp e troca os providers por falsos. Nao da pra injetar
        # providersDir por parametro (linha 269 do orchestrator resolve de $pluginRoot), entao a
        # substituicao e por arvore -- mesmo padrao do New-KitFalso em hook-wrapper-fail-loud.
        function New-PluginFalso {
            param(
                [string]$CrossClaudeSaida,   # JSON que o provider falso imprime
                [int]$CrossClaudeExit = 0
            )
            $raiz = Join-Path ([IO.Path]::GetTempPath()) "council-fb-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $raiz | Out-Null
            $script:temporarios.Add($raiz)
            foreach ($sub in @('scripts','providers')) {
                Copy-Item -Path (Join-Path $script:pluginReal $sub) -Destination (Join-Path $raiz $sub) -Recurse -Force
            }
            $enc = New-Object System.Text.UTF8Encoding($true)

            # Provider falso generico: aceita qualquer parametro e imprime o JSON pedido.
            function Set-ProviderFalso {
                param([string]$Nome, [string]$Json, [int]$Code = 0)
                $corpo = @"
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]`$PromptFile,
    [string]`$SystemPrompt,
    [string]`$Model,
    [string]`$Mode,
    [string]`$ReasoningEffort,
    [Parameter(ValueFromRemainingArguments = `$true)] `$Resto
)
Write-Output '$Json'
exit $Code
"@
                [System.IO.File]::WriteAllText((Join-Path (Join-Path $raiz 'providers') "$Nome.ps1"), $corpo, $enc)
            }

            Set-ProviderFalso -Nome 'deepseek'   -Json '{"provider":"deepseek","model":"falso","status":"ok","content":"opiniao da deepseek","latency_ms":1}'
            Set-ProviderFalso -Nome 'groq-llama' -Json '{"provider":"groq-llama","model":"falso","status":"ok","content":"opiniao da llama","latency_ms":1}'
            Set-ProviderFalso -Nome 'cross-claude' -Json $CrossClaudeSaida -Code $CrossClaudeExit
            return $raiz
        }

        function Invoke-Orchestrator {
            param(
                [string]$PluginRoot,
                [string]$Pergunta = "PERGUNTA: A ou B?",
                [hashtable]$Env = @{}
            )
            $q = Join-Path ([IO.Path]::GetTempPath()) "council-q-$([guid]::NewGuid().ToString('N')).txt"
            Set-Content -LiteralPath $q -Value $Pergunta -Encoding utf8
            $errFile = "$q.err"
            # PERCUS_CROSS_CLAUDE entra na lista SEMPRE, mesmo quando o caso nao a passa: a
            # maquina do operador tende a ter ela setada como 'subagent' (e o ponto da feature),
            # e herdar isso faria o caso "chave boa: nada muda" falhar sem defeito nenhum no
            # codigo -- teste vermelho que nao aponta bug e teste que sera ignorado.
            $chaves = @($Env.Keys) + @('PERCUS_CROSS_CLAUDE') | Select-Object -Unique
            $antigos = @{}
            foreach ($k in $chaves) { $antigos[$k] = [Environment]::GetEnvironmentVariable($k) }
            try {
                foreach ($k in $chaves) {
                    if ($Env.ContainsKey($k)) { Set-Item -Path "env:$k" -Value $Env[$k] }
                    else { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
                }
                $out = & pwsh -NoProfile -File (Join-Path (Join-Path $PluginRoot 'scripts') 'council-orchestrator.ps1') `
                    -PromptFile $q -Mode consult -Providers "deepseek,groq-llama,cross-claude" 2>$errFile
                $code = $LASTEXITCODE
            } finally {
                foreach ($k in $chaves) {
                    if ($null -eq $antigos[$k]) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
                    else { Set-Item -Path "env:$k" -Value $antigos[$k] }
                }
            }
            $err = if (Test-Path $errFile) { (Get-Content $errFile -Raw) } else { "" }
            $json = $null
            try { $json = ($out -join "`n") | ConvertFrom-Json } catch { }
            Remove-Item -LiteralPath $q, $errFile -Force -ErrorAction SilentlyContinue
            return [pscustomobject]@{ Code = $code; Json = $json; Err = $err; Out = ($out -join "`n") }
        }

        # O erro REAL de 2026-09-12, copiado do log -- nao um valor inventado que confirmaria o que eu quero.
        $script:erroCredito = '{"provider":"cross-claude","model":"claude-sonnet-5","status":"error","error":"Your credit balance is too low to access the Anthropic API.","latency_ms":417}'
    }

    Context "chave presente mas quebrada: o marcador TEM que sair" {
        It "provider direto devolve status=error -> stderr traz __PERCUS_NEEDS_CROSS_CLAUDE__" {
            $p = New-PluginFalso -CrossClaudeSaida $script:erroCredito
            $r = Invoke-Orchestrator -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = "sk-quebrada" }
            $r.Err | Should -Match '__PERCUS_NEEDS_CROSS_CLAUDE__' -Because "perna que falha tem que pedir o subagente, nao sumir:`n$($r.Err)"
        }

        It "o marcador vem acompanhado do PROMPT, senao o agente nao tem o que despachar" {
            $p = New-PluginFalso -CrossClaudeSaida $script:erroCredito
            $r = Invoke-Orchestrator -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = "sk-quebrada" }
            $r.Err | Should -Match '---PROMPT---'
            $r.Err | Should -Match '---MODEL-HINT---'
        }

        It "cross_claude_pending=true no log -- o campo tem que concordar com o marcador emitido" {
            # Achado da perna Cross-Claude (2026-09-12): o campo era calculado a partir da decisao
            # tomada ANTES da tentativa. No caminho novo, $wantsCrossClaude ja esta zerado, entao o
            # log persistido em .deepseek/council-log/ dizia pending=false EXATAMENTE no cenario
            # que esta versao corrige. E a mesma classe de bug ("decidir pela presenca, nao pelo
            # resultado") sobrevivendo num campo colateral -- e o log e o que alguem le depois.
            $p = New-PluginFalso -CrossClaudeSaida $script:erroCredito
            $r = Invoke-Orchestrator -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = "sk-quebrada" }
            $r.Err  | Should -Match '__PERCUS_NEEDS_CROSS_CLAUDE__'
            $r.Json.cross_claude_pending | Should -Be $true -Because "marcador emitido e pending=false e o log mentindo"
        }

        It "a perna continua contada como DEGRADADA (o marcador nao maquia o veredito)" {
            $p = New-PluginFalso -CrossClaudeSaida $script:erroCredito
            $r = Invoke-Orchestrator -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = "sk-quebrada" }
            $r.Json.respostas_degradadas -join ' ' | Should -Match 'cross-claude'
            $r.Json.respostas_usaveis | Should -Be 2
        }
    }

    Context "chave presente e boa: nada muda (sem marcador, sem subagente a toa)" {
        It "provider direto devolve ok -> nenhum marcador" {
            $ok = '{"provider":"cross-claude","model":"claude-sonnet-5","status":"ok","content":"opiniao do sonnet","latency_ms":900}'
            $p = New-PluginFalso -CrossClaudeSaida $ok
            $r = Invoke-Orchestrator -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = "sk-boa" }
            $r.Err | Should -Not -Match '__PERCUS_NEEDS_CROSS_CLAUDE__'
            $r.Json.respostas_usaveis | Should -Be 3
        }
    }

    Context "PERCUS_CROSS_CLAUDE=subagent: a assinatura vence a chave" {
        # O operador usa o credito mensal do login, nao a API. Sem esta alavanca, a unica forma de
        # nao gastar API e apagar a variavel do ambiente -- que outros componentes podem usar.
        It "com a flag, o marcador sai mesmo com chave BOA presente" {
            $ok = '{"provider":"cross-claude","model":"claude-sonnet-5","status":"ok","content":"nao deveria ter sido chamado","latency_ms":900}'
            $p = New-PluginFalso -CrossClaudeSaida $ok
            $r = Invoke-Orchestrator -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = "sk-boa"; PERCUS_CROSS_CLAUDE = "subagent" }
            $r.Err | Should -Match '__PERCUS_NEEDS_CROSS_CLAUDE__' -Because "a flag manda usar a assinatura, nao a API"
        }

        It "com a flag, o provider direto NAO e chamado (o conteudo dele nao aparece na saida)" {
            $ok = '{"provider":"cross-claude","model":"claude-sonnet-5","status":"ok","content":"MARCA-QUE-NAO-DEVE-APARECER","latency_ms":900}'
            $p = New-PluginFalso -CrossClaudeSaida $ok
            $r = Invoke-Orchestrator -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = "sk-boa"; PERCUS_CROSS_CLAUDE = "subagent" }
            $r.Out | Should -Not -Match 'MARCA-QUE-NAO-DEVE-APARECER' -Because "gastar a API depois de mandar usar a assinatura e o oposto do pedido"
            # Sem esta linha o It passa por VACUIDADE: saida vazia por qualquer outro motivo
            # tambem satisfaria o Should -Not -Match.
            $r.Json.respostas_usaveis | Should -Be 2 -Because "so deepseek+groq-llama respondem; a perna direta nao foi chamada"
        }
    }

    Context "o caminho que ja funcionava continua funcionando" {
        It "-CrossClaudeFile preenche a perna e nao emite marcador" {
            $p = New-PluginFalso -CrossClaudeSaida $script:erroCredito
            $cc = Join-Path ([IO.Path]::GetTempPath()) "council-cc-$([guid]::NewGuid().ToString('N')).txt"
            Set-Content -LiteralPath $cc -Value "resposta do subagente Sonnet" -Encoding utf8
            $q = Join-Path ([IO.Path]::GetTempPath()) "council-q-$([guid]::NewGuid().ToString('N')).txt"
            Set-Content -LiteralPath $q -Value "PERGUNTA: A ou B?" -Encoding utf8
            $errFile = "$q.err"
            $out = & pwsh -NoProfile -File (Join-Path (Join-Path $p 'scripts') 'council-orchestrator.ps1') `
                -PromptFile $q -Mode consult -Providers "deepseek,groq-llama,cross-claude" -CrossClaudeFile $cc 2>$errFile
            $err = if (Test-Path $errFile) { Get-Content $errFile -Raw } else { "" }
            $err | Should -Not -Match '__PERCUS_NEEDS_CROSS_CLAUDE__'
            (($out -join "`n") | ConvertFrom-Json).respostas_usaveis | Should -Be 3
            Remove-Item -LiteralPath $cc, $q, $errFile -Force -ErrorAction SilentlyContinue
        }
    }

    Context "paridade .sh -- a outra implementacao faz a MESMA coisa" {
        # O changelog prometia "paridade provada com execucao real do .sh" e o diff so trazia
        # teste .ps1 (achado da perna Cross-Claude, 2026-09-12). Promessa sem artefato e
        # exatamente o que este kit chama de afirmacao nao sustentada -- entao aqui o .sh roda
        # de verdade, com providers falsos .sh, e as duas implementacoes sao comparadas.
        BeforeAll {
            $script:bash = (Get-Command bash -ErrorAction SilentlyContinue)

            function New-PluginFalsoSh {
                param([string]$CrossClaudeSaida)
                $raiz = Join-Path ([IO.Path]::GetTempPath()) "council-fb-sh-$(Get-Random)"
                New-Item -ItemType Directory -Force -Path $raiz | Out-Null
                $script:temporarios.Add($raiz)
                foreach ($sub in @('scripts','providers')) {
                    Copy-Item -Path (Join-Path $script:pluginReal $sub) -Destination (Join-Path $raiz $sub) -Recurse -Force
                }
                $encSemBom = New-Object System.Text.UTF8Encoding($false)
                foreach ($par in @(
                    @{ n = 'deepseek';     j = '{"provider":"deepseek","model":"falso","status":"ok","content":"ok","latency_ms":1}' }
                    @{ n = 'groq-llama';   j = '{"provider":"groq-llama","model":"falso","status":"ok","content":"ok","latency_ms":1}' }
                    @{ n = 'cross-claude'; j = $CrossClaudeSaida }
                )) {
                    $corpo = "#!/usr/bin/env bash`ncat <<'JSONEOF'`n$($par.j)`nJSONEOF`n"
                    [System.IO.File]::WriteAllText((Join-Path (Join-Path $raiz 'providers') "$($par.n).sh"), $corpo.Replace("`r`n", "`n"), $encSemBom)
                }
                return $raiz
            }

            function Invoke-OrchestratorSh {
                param([string]$PluginRoot, [hashtable]$Env = @{})
                $q = Join-Path ([IO.Path]::GetTempPath()) "council-q-sh-$([guid]::NewGuid().ToString('N')).txt"
                [System.IO.File]::WriteAllText($q, "PERGUNTA: A ou B?`n".Replace("`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
                $errFile = "$q.err"
                $shScript = (Join-Path (Join-Path $PluginRoot 'scripts') 'council-orchestrator.sh').Replace([char]92, [char]47)
                $qU = $q.Replace([char]92, [char]47)
                # As env vars vao pelo AMBIENTE do processo, nao como prefixo da linha: prefixo
                # dentro de `bash -lc` e re-parseado pelo proprio bash, que remove as aspas do
                # valor -- o caso "valor com aspas" nunca chegava ao codigo sob teste e o It
                # passava por vacuidade (achado do R11, 2026-09-12).
                $chavesSh = @($Env.Keys) + @('PERCUS_CROSS_CLAUDE', 'ANTHROPIC_API_KEY') | Select-Object -Unique
                $antigosSh = @{}
                foreach ($k in $chavesSh) { $antigosSh[$k] = [Environment]::GetEnvironmentVariable($k) }
                try {
                    foreach ($k in $chavesSh) {
                        if ($Env.ContainsKey($k)) { Set-Item -Path "env:$k" -Value $Env[$k] }
                        else { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
                    }
                    $cmd = "bash '$shScript' --prompt-file '$qU' --mode consult --providers 'deepseek,groq-llama,cross-claude'"
                    $out = & $script:bash.Source -lc $cmd 2>$errFile
                } finally {
                    foreach ($k in $chavesSh) {
                        if ($null -eq $antigosSh[$k]) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
                        else { Set-Item -Path "env:$k" -Value $antigosSh[$k] }
                    }
                }
                $err = if (Test-Path $errFile) { Get-Content $errFile -Raw } else { "" }
                $json = $null
                try { $json = ($out -join "`n") | ConvertFrom-Json } catch { }
                Remove-Item -LiteralPath $q, $errFile -Force -ErrorAction SilentlyContinue
                return [pscustomobject]@{ Json = $json; Err = $err; Out = ($out -join "`n") }
            }
        }

        It ".sh: chave quebrada -> marcador sai E cross_claude_pending=true" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "sem bash nesta maquina"; return }
            $p = New-PluginFalsoSh -CrossClaudeSaida $script:erroCredito
            $r = Invoke-OrchestratorSh -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = 'sk-quebrada'; PERCUS_CROSS_CLAUDE = '' }
            $r.Err  | Should -Match '__PERCUS_NEEDS_CROSS_CLAUDE__' -Because "paridade com o .ps1:`n$($r.Err)"
            $r.Json.cross_claude_pending | Should -Be $true
        }

        It ".sh: PERCUS_CROSS_CLAUDE=subagent -> marcador sai mesmo com chave boa" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "sem bash nesta maquina"; return }
            $ok = '{"provider":"cross-claude","model":"claude-sonnet-5","status":"ok","content":"nao deveria ser chamado","latency_ms":900}'
            $p = New-PluginFalsoSh -CrossClaudeSaida $ok
            $r = Invoke-OrchestratorSh -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = 'sk-boa'; PERCUS_CROSS_CLAUDE = 'subagent' }
            $r.Err | Should -Match '__PERCUS_NEEDS_CROSS_CLAUDE__'
        }

        It ".sh: aspas no valor da flag nao quebram o trim (era xargs, virou sed)" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "sem bash nesta maquina"; return }
            $ok = '{"provider":"cross-claude","model":"claude-sonnet-5","status":"ok","content":"ok","latency_ms":900}'
            $p = New-PluginFalsoSh -CrossClaudeSaida $ok
            # aspas LITERAIS no valor (o xargs antigo errava o parsing aqui); via ambiente, o
            # bash nao re-parseia, entao a string chega inteira ao trim.
            $r = Invoke-OrchestratorSh -PluginRoot $p -Env @{ ANTHROPIC_API_KEY = 'sk-boa'; PERCUS_CROSS_CLAUDE = ([char]34 + 'aspas' + [char]34) }
            $r.Json | Should -Not -BeNullOrEmpty -Because "valor estranho nao pode derrubar o orchestrator:`n$($r.Err)"
            # e o valor com aspas NAO e 'subagent', entao a perna direta roda normalmente:
            $r.Json.respostas_usaveis | Should -Be 3 -Because "sem isto o It passa por vacuidade (achado do R11)"
            $r.Err | Should -Not -Match '__PERCUS_NEEDS_CROSS_CLAUDE__'
        }
    }

    AfterAll {
        foreach ($d in $script:temporarios) {
            Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
