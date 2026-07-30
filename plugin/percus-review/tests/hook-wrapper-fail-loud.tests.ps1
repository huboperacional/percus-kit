#requires -Version 5.1
# O .cmd e a fronteira entre o harness e o hook. O harness NAO le "nao-zero": ele le tres
# faixas de exit code -- 0 = segue, 2 = BLOQUEIA e manda o stderr pro modelo, qualquer outro
# (1, -196608) = erro nao-bloqueante que so aparece no transcript e DEIXA SEGUIR.
#
# O que "bloquear" significa depende do EVENTO, e por isso a forma do wrapper depende do
# evento declarado em hooks.json -- nao existe uma forma unica certa pros 11:
#
#   PreToolUse  -> forma GUARDA (fail-closed). exit 2 barra a FERRAMENTA. Guarda que morre e
#                  sai 1 grita e libera: fail-OPEN, contra o canon do kit ("gate instalado que
#                  nao consegue rodar BLOQUEIA"). Entao o wrapper traduz qualquer nao-zero em 2.
#
#   Stop /      -> forma OBSERVADOR. exit 2 aqui barra o ENCERRAMENTO DA SESSAO / a COMPACTACAO
#   PreCompact     de contexto. Traduzir erro em 2 trancaria o usuario fora da propria sessao por
#                  causa de um .ps1 quebrado -- e os tres .ps1 desses eventos se documentam
#                  fail-open ("qualquer erro -> exit 0"; pre-compact-checkpoint nem tem exit 2
#                  no corpo). O wrapper entao NAO traduz codigo: repassa o exit do .ps1. Assim
#                  .ps1 morto devolve 1 (visivel no transcript, nao-bloqueante) e o exit 2 que o
#                  proprio hook decide emitir continua bloqueando.
#
# Fail-closed sem porta de saida e maquina trancada: com o .ps1 quebrado, o escape
# PERCUS_HOOKS_DISABLED lido DENTRO do .ps1 nunca roda. Por isso o escape esta tambem no
# .cmd, antes da invocacao, NAS DUAS FORMAS -- e por isso ele tem It proprio aqui.
#
# O .ps1 e sintetico de proposito, e o .cmd e o REAL: o artefato sob teste e o wrapper.
# O par copiado roda sozinho porque o .cmd resolve o script por %~dp0.

Describe "wrapper .cmd tem a forma do seu evento" {
    BeforeAll {
        $script:kitRoot  = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:hooksDir = Join-Path $script:kitRoot "plugin\percus-review\hooks"
        $script:temps    = New-Object System.Collections.ArrayList

        # Conteudo que NAO PARSEIA no 5.1: em dash DENTRO de string, arquivo SEM BOM. Sem BOM
        # o 5.1 le ANSI, o ultimo byte do em dash vira aspa curva e fecha a string cedo.
        # Nao uso chave desbalanceada nem lixo aleatorio: precisa ser falha de PARSE. Falha de
        # EXECUCAO o wrapper ja propagava certo, entao o teste passaria pelo motivo errado.
        #
        # O corpo sadio faz 'exit 0' de proposito: se um dia a corrupcao parar de corromper,
        # o script roda, sai 0, e o teste FALHA. A direcao da falha e segura.
        # [char]0x2014 em vez do caractere literal pra este arquivo de teste nao ser ele
        # proprio uma vitima do mesmo bug de encoding que ele testa.
        $script:ps1Quebrado = "Write-Host 'este script NAO deveria ter rodado'`nWrite-Host `"x " + [char]0x2014 + " y`"`nexit 0"

        # Copia o .cmd real e planta um .ps1 sintetico com o mesmo nome ao lado dele.
        function New-ParDeTeste {
            param([string]$Nome, [string]$ConteudoPs1, [bool]$ComBom)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("wrap-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Copy-Item (Join-Path $script:hooksDir "$Nome.cmd") (Join-Path $dir "$Nome.cmd")
            [IO.File]::WriteAllText((Join-Path $dir "$Nome.ps1"), $ConteudoPs1, (New-Object System.Text.UTF8Encoding($ComBom)))
            [void]$script:temps.Add($dir)
            return (Join-Path $dir "$Nome.cmd")
        }

        function Invoke-Wrapper {
            param([string]$Cmd)
            $null = ('{"tool_name":"Bash","tool_input":{"command":"git status"}}' | & cmd.exe /c "`"$Cmd`"" 2>&1)
            return $LASTEXITCODE
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "GUARDA: com .ps1 que nao PARSEIA, o wrapper sai 2 (BLOQUEIA)" {
        # Medido com -File puro: .ps1 que nao parseia devolve 1, e 1 nao bloqueia nada.
        # Exigir 2 -- e nao "nao-zero" -- e a diferenca entre gritar e barrar.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 $script:ps1Quebrado -ComBom $false

        Invoke-Wrapper -Cmd $cmd | Should -Be 2 -Because "guarda que nao roda tem que BLOQUEAR; exit 1 o harness deixa passar"
    }

    It "GUARDA: com .ps1 ausente, o wrapper sai 2 (BLOQUEIA)" {
        # Medido com -File puro: .ps1 ausente devolve -196608, tambem faixa nao-bloqueante.
        # Hook desinstalado pela metade e o mesmo perigo que hook quebrado.
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("wrap-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Copy-Item (Join-Path $script:hooksDir "external-action-guard.cmd") (Join-Path $dir "external-action-guard.cmd")
        [void]$script:temps.Add($dir)
        # de proposito: nenhum .ps1 ao lado
        Invoke-Wrapper -Cmd (Join-Path $dir "external-action-guard.cmd") | Should -Be 2
    }

    It "GUARDA: com PERCUS_HOOKS_DISABLED=1 e .ps1 QUEBRADO, o wrapper sai 0 (escape nao depende do arquivo quebrado)" {
        # Este It e o que impede fail-closed de virar maquina trancada. O escape que existia
        # so dentro do .ps1 e inutil justamente no caso em que ele importa -- o .ps1 nao roda.
        # Sem a linha do escape NO .cmd, um .ps1 corrompido tranca a maquina e a unica saida e
        # editar arquivo ou desabilitar o plugin inteiro.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 $script:ps1Quebrado -ComBom $false

        $env:PERCUS_HOOKS_DISABLED = "1"
        try {
            Invoke-Wrapper -Cmd $cmd | Should -Be 0 -Because "o escape tem que funcionar SEM depender do .ps1 que quebrou"
        } finally {
            Remove-Item env:PERCUS_HOOKS_DISABLED -ErrorAction SilentlyContinue
        }
    }

    It "GUARDA: com .ps1 sadio que APROVA, o wrapper sai 0" {
        # Contrapeso: sem este It, um .cmd que sempre devolvesse 2 passaria em tudo que mede
        # bloqueio. Fail-closed que bloqueia TAMBEM o caminho feliz e so uma guarda travada.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "Write-Host 'aprovado'`nexit 0" -ComBom $true
        Invoke-Wrapper -Cmd $cmd | Should -Be 0
    }

    It "GUARDA: com .ps1 sadio que BLOQUEIA, o wrapper propaga o bloqueio (exit 2)" {
        # A outra metade da prova: fechar o fail-open nao pode custar a semantica normal.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "Write-Host 'bloqueando'`nexit 2" -ComBom $true
        Invoke-Wrapper -Cmd $cmd | Should -Be 2
    }

    It "OBSERVADOR: .cmd de Stop repassa o exit do .ps1 -- quebrado da 1 (grita), exit 2 da 2 (bloqueia)" {
        # Par REAL de evento Stop: aqui exit 2 nao barra uma ferramenta, barra o ENCERRAMENTO DA
        # SESSAO. Os dois numeros sao a prova de que "grita" e "tranca" sao coisas diferentes.
        #
        # 1: o .ps1 morreu. O operador ve o erro no transcript e mesmo assim consegue fechar a
        # sessao. Se aqui desse 2, um .ps1 corrompido trancaria o usuario dentro da sessao --
        # num hook cujo proprio cabecalho promete "qualquer erro -> exit 0".
        $quebrado = New-ParDeTeste -Nome "on-stop-check" -ConteudoPs1 $script:ps1Quebrado -ComBom $false
        Invoke-Wrapper -Cmd $quebrado | Should -Be 1 -Because "hook morto de Stop grita no transcript; nao pode trancar o encerramento"

        # 2: nao-traduzir nao pode custar o bloqueio LEGITIMO. on-stop-check e state-drift-check
        # emitem exit 2 de proposito (R8: stop com HANDOFF stale / drift de status), e esse 2
        # tem que atravessar o wrapper intacto. Sem esta metade, um .cmd que sempre devolvesse 0
        # passaria no assert de cima e mataria os dois hooks em silencio.
        $bloqueia = New-ParDeTeste -Nome "on-stop-check" -ConteudoPs1 "Write-Host 'bloqueando'`nexit 2" -ComBom $true
        Invoke-Wrapper -Cmd $bloqueia | Should -Be 2 -Because "o bloqueio que o PROPRIO hook decide emitir tem que sobreviver ao wrapper"
    }

    It "TODOS os 11 wrappers .cmd tem a forma do SEU evento em hooks.json (8 guarda / 3 observador)" {
        # Os It anteriores provam o comportamento em UM wrapper de cada forma. Sem este, a
        # correcao poderia acertar so alguns dos 11 e a suite ficaria verde -- exatamente o tipo
        # de meia-correcao que deixou 3 guardas mortas sem ninguem ver.
        #
        # Aqui e inspecao de forma, e nao comportamento, de proposito: rodar os 11 wrappers de
        # verdade dispararia hook real (git, rede, escrita) como efeito colateral de teste.
        #
        # A forma esperada e DERIVADA do evento declarado em hooks.json, nunca de uma lista de
        # nomes escrita aqui: lista de nomes envelhece calada, e foi generalizar "todo wrapper e
        # guarda" que trancou o stop e a compactacao. hooks.json e a mesma fonte que o harness le.
        #
        # A assercao e POSITIVA (forma exata esperada) e nao negativa (ausencia de '-Command').
        # Medido: a versao negativa era furada -- '-c' e abreviacao valida de -Command e passava
        # verde, e '-File' seguido de 'exit /b 0' engole a falha igual. So a forma inteira,
        # linha a linha e com o nome do proprio arquivo no %~dp0, fecha essas frestas.
        $hooksJson = Get-Content (Join-Path $script:hooksDir "hooks.json") -Raw | ConvertFrom-Json

        $evento = @{}
        foreach ($ev in $hooksJson.hooks.PSObject.Properties) {
            foreach ($matcher in @($ev.Value)) {
                foreach ($h in @($matcher.hooks)) {
                    if ($h.command -match '([^/\\"]+)\.cmd') { $evento[$matches[1]] = $ev.Name }
                }
            }
        }

        $cmds = @(Get-ChildItem $script:hooksDir -Filter *.cmd | Sort-Object Name)

        # Piso de contagem: sem ele, uma pasta VAZIA faz este It passar sem verificar nada --
        # e a migracao dos hooks pro settings.json (spec sec. 9) esvazia exatamente esta pasta.
        $cmds.Count | Should -Be 11 -Because "piso de contagem: It que passa vazio nao guarda nada"

        # .cmd nao declarado em hooks.json nao tem evento -- e a forma dele seria ADIVINHADA.
        # Adivinhar e o erro que este It existe pra impedir, entao aqui e falha, nao default.
        $orfaos = @($cmds | Where-Object { -not $evento.ContainsKey([IO.Path]::GetFileNameWithoutExtension($_.Name)) })
        @($orfaos.Name) | Should -BeNullOrEmpty -Because "sem evento em hooks.json nao da pra saber se e guarda ou observador"

        $nGuarda = 0
        $nObservador = 0
        $fora = @()
        foreach ($c in $cmds) {
            $base = [IO.Path]::GetFileNameWithoutExtension($c.Name)
            $ev   = $evento[$base]

            # As tres primeiras linhas sao iguais nas duas formas -- inclusive o escape
            # PERCUS_HOOKS_DISABLED, que o observador tambem precisa (ver cabecalho).
            $esperado = @(
                '@echo off'
                'if "%PERCUS_HOOKS_DISABLED%"=="1" exit /b 0'
                ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0' + $base + '.ps1"')
            )
            if ($ev -eq 'PreToolUse') {
                # GUARDA: traduz qualquer nao-zero em 2 pra guarda morta BARRAR a ferramenta.
                $esperado += @('if %ERRORLEVEL%==0 exit /b 0', 'exit /b 2')
                $nGuarda++
                $forma = "GUARDA (evento $ev)"
            } else {
                # OBSERVADOR: sem traducao de codigo. .ps1 morto devolve 1 (grita, nao tranca) e
                # o exit 2 que o proprio hook decide emitir passa direto e continua bloqueando.
                $nObservador++
                $forma = "OBSERVADOR (evento $ev)"
            }

            $linhas = @((Get-Content $c.FullName) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

            if (($linhas -join "`n") -cne ($esperado -join "`n")) {
                $fora += ("{0} -- esperado {1}:`n--- tem ---`n{2}`n--- esperado ---`n{3}" -f $c.Name, $forma, ($linhas -join "`n"), ($esperado -join "`n"))
            }
        }

        # Contagem por forma: sem ela, trocar o evento de um hook em hooks.json reclassificaria o
        # wrapper em silencio e este It seguiria verde medindo a coisa errada. Contagem errada e
        # a forma mais provavel deste teste apodrecer, entao os dois numeros sao afirmados.
        $nGuarda     | Should -Be 8 -Because "8 wrappers de PreToolUse tem que estar na forma GUARDA"
        $nObservador | Should -Be 3 -Because "on-stop-check + state-drift-check (Stop) e pre-compact-checkpoint (PreCompact)"

        @($fora) | Should -BeNullOrEmpty -Because "wrapper na forma errada pro evento dele bloqueia o que nao devia, ou nao bloqueia o que devia:`n$($fora -join "`n`n")"
    }
}
