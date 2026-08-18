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

        # O wrapper rejeita .ps1 abaixo de 200 bytes (ver o It do piso). Um 'exit 0' sintetico tem
        # 7 bytes, entao TODO fixture sadio precisa de enchimento -- senao o teste mede a rejeicao
        # por tamanho em vez do comportamento que ele quer medir, e passa/falha pelo motivo errado.
        # Conteudo VAZIO fica vazio de proposito: e o caso que o piso existe pra pegar.
        function Add-Enchimento {
            param([string]$Conteudo)
            if ([string]::IsNullOrEmpty($Conteudo)) { return $Conteudo }
            return $Conteudo + "`n" + ("# enchimento para o fixture passar do piso de 200 bytes do wrapper" * 4)
        }

        # Copia o .cmd real e planta um .ps1 sintetico com o mesmo nome ao lado dele.
        function New-ParDeTeste {
            param([string]$Nome, [string]$ConteudoPs1, [bool]$ComBom)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("wrap-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Copy-Item (Join-Path $script:hooksDir "$Nome.cmd") (Join-Path $dir "$Nome.cmd")
            [IO.File]::WriteAllText((Join-Path $dir "$Nome.ps1"), (Add-Enchimento $ConteudoPs1), (New-Object System.Text.UTF8Encoding($ComBom)))
            [void]$script:temps.Add($dir)
            return (Join-Path $dir "$Nome.cmd")
        }

        # Planta um "kit" falso com a arvore que o trampolim procura, e um .ps1 dentro.
        function New-KitFalso {
            param([string]$Nome, [string]$ConteudoPs1, [bool]$ComBom = $true)
            $raiz = Join-Path ([IO.Path]::GetTempPath()) ("kit-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            $dir  = Join-Path $raiz "plugin\percus-review\hooks"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $dir "$Nome.ps1"), (Add-Enchimento $ConteudoPs1), (New-Object System.Text.UTF8Encoding($ComBom)))
            [void]$script:temps.Add($raiz)
            return $raiz
        }

        function Invoke-Wrapper {
            param([string]$Cmd, [string]$CanonDir)
            # PERCUS_CANON_DIR e controlada explicitamente aqui, NUNCA herdada de quem roda a
            # suite. O trampolim prefere o .ps1 do kit quando a variavel aponta pra um -- e a
            # maquina do operador SEMPRE tem ela setada. Sem este controle, todo teste que planta
            # um .ps1 sintetico ao lado do .cmd rodaria o hook de verdade em vez do sintetico e
            # passaria pelo motivo errado: verde medindo outra coisa.
            $anterior = $env:PERCUS_CANON_DIR
            try {
                if ($CanonDir) { $env:PERCUS_CANON_DIR = $CanonDir }
                else { Remove-Item env:PERCUS_CANON_DIR -ErrorAction SilentlyContinue }
                $null = ('{"tool_name":"Bash","tool_input":{"command":"git status"}}' | & cmd.exe /c "`"$Cmd`"" 2>&1)
                return $LASTEXITCODE
            } finally {
                if ($null -ne $anterior) { $env:PERCUS_CANON_DIR = $anterior }
                else { Remove-Item env:PERCUS_CANON_DIR -ErrorAction SilentlyContinue }
            }
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

    Context "trampolim: o codigo executado vem do kit, nao do cache" {
        # O motivo de existir do plano 2. CLAUDE_PLUGIN_ROOT resolve o plugin INSTALADO, entao
        # fix de hook so chegava por ciclo de publicacao -- e ja houve fix inerte por cache
        # dessincronizado. Com o trampolim, o .cmd do cache passa a executar o .ps1 do KIT, e
        # todo fix passa a chegar por git pull.
        #
        # Estes It distinguem QUAL .ps1 rodou por exit code, e nao por saida: saida de hook que
        # sai 0 e invisivel (medido, item 10 de 2026-07-31-semantica-hooks-harness.md), entao
        # depender dela seria depender de um canal que nao existe.

        It "com PERCUS_CANON_DIR valido, roda o .ps1 do KIT e nao o vizinho" {
            $par = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "exit 0" -ComBom $true
            $kit = New-KitFalso   -Nome "external-action-guard" -ConteudoPs1 "exit 2"
            # vizinho aprova, kit bloqueia: se o resultado e 2, quem rodou foi o do kit.
            Invoke-Wrapper -Cmd $par -CanonDir $kit | Should -Be 2 -Because "o .ps1 do kit tem que ganhar do vizinho"
        }

        It "sem PERCUS_CANON_DIR, roda o vizinho" {
            $par = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "exit 0" -ComBom $true
            $null = New-KitFalso  -Nome "external-action-guard" -ConteudoPs1 "exit 2"
            # kit existe mas a variavel nao aponta pra ele: tem que rodar o vizinho, que aprova.
            Invoke-Wrapper -Cmd $par | Should -Be 0 -Because "sem a variavel nao ha kit pra preferir"
        }

        It "com PERCUS_CANON_DIR apontando pra arvore SEM o hook, cai no vizinho" {
            $par = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "exit 2" -ComBom $true
            $kitVazio = Join-Path ([IO.Path]::GetTempPath()) ("kitvazio-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $kitVazio -Force | Out-Null
            [void]$script:temps.Add($kitVazio)
            # vizinho bloqueia: se o resultado e 2, o fallback aconteceu de verdade.
            Invoke-Wrapper -Cmd $par -CanonDir $kitVazio | Should -Be 2 -Because "kit sem o hook nao pode sequestrar a execucao"
        }

        It "GUARDA: com o .ps1 do KIT quebrado, o fail-closed sobrevive ao trampolim" {
            # A fresta mais cara possivel: o trampolim passa a executar um arquivo que vem de
            # outra arvore, e essa arvore pode estar no meio de um git pull, de um rebase, ou
            # simplesmente errada. Se o fail-closed nao valesse pro alvo remoto, o trampolim
            # teria trocado "fix nao chega" por "guarda morta que aprova tudo".
            $par = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "exit 0" -ComBom $true
            $kit = New-KitFalso   -Nome "external-action-guard" -ConteudoPs1 $script:ps1Quebrado -ComBom $false
            Invoke-Wrapper -Cmd $par -CanonDir $kit | Should -Be 2 -Because "kit quebrado tem que BARRAR, nao cair calado no vizinho que aprova"
        }

        It "o piso de 200 bytes fica MUITO abaixo do menor hook real -- nao pode rejeitar hook legitimo" {
            # O piso e numero magico, e numero magico apodrece. Este It e a amarra: se algum dia
            # um hook legitimo encolher pra perto de 200 bytes, ele falha aqui ANTES de o wrapper
            # comecar a barrar um hook sadio em producao.
            $man = Get-Content (Join-Path $script:hooksDir "hooks-manifest.json") -Raw | ConvertFrom-Json
            $menor = @($man.hooks | Where-Object { $_.registrado } | ForEach-Object {
                (Get-Item (Join-Path $script:hooksDir ($_.nome + ".ps1"))).Length
            } | Measure-Object -Minimum).Minimum
            $menor | Should -BeGreaterThan 600 -Because "o menor hook real precisa de folga confortavel sobre o piso de 200 bytes (hoje: $menor)"
        }

        It "GUARDA: .ps1 do KIT VAZIO ou so-BOM barra -- script vazio nao e script sadio" -ForEach @(
            @{ Rotulo = "0 bytes";  Bom = $false }
            @{ Rotulo = "so BOM";   Bom = $true  }
        ) {
            # Achado por review (Cross-Claude), confirmado por medicao antes de aceitar:
            # powershell.exe -File <arquivo de 0 bytes> sai 0. Script vazio nao e "quebrado" pro
            # parser -- e um script valido que nao faz nada. Sem checagem, a guarda traduzia isso
            # em "aprovado" e virava a guarda morta que aprova tudo.
            #
            # A janela nao e teorica: e a que o trampolim abre. git pull no Windows pode truncar
            # antes de gravar o conteudo novo, e o alvo do trampolim e uma copia de trabalho que
            # recebe pull.
            #
            # O caso "so BOM" so entrou porque a PRIMEIRA versao deste teste falhou: eu plantava
            # string vazia com BOM e o arquivo tinha 3 bytes, nao 0. A checagem de zero byte que
            # eu tinha escrito nao pegaria arquivo truncado que preservou o BOM. O teste que
            # falhou por acidente mostrou que o conserto era estreito demais -- por isso virou
            # piso de tamanho, e nao comparacao com zero.
            $par = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "exit 0" -ComBom $true
            $kit = New-KitFalso   -Nome "external-action-guard" -ConteudoPs1 "" -ComBom $Bom
            Invoke-Wrapper -Cmd $par -CanonDir $kit | Should -Be 2 -Because "kit com .ps1 de $Rotulo tem que BARRAR, nao aprovar"
        }

        It "OBSERVADOR: .ps1 do KIT vazio grita (1), nao tranca (2)" {
            $par = New-ParDeTeste -Nome "on-stop-check" -ConteudoPs1 "exit 0" -ComBom $true
            $kit = New-KitFalso   -Nome "on-stop-check" -ConteudoPs1 "" -ComBom $false
            Invoke-Wrapper -Cmd $par -CanonDir $kit | Should -Be 1 -Because "observador com arquivo vazio grita, mas nao pode trancar o Stop"
        }

        It "GUARDA: fail-closed vale no caminho que RODA DE VERDADE (com PERCUS_CANON_DIR setado)" {
            # Finding do review: os It de fail-closed pre-existentes rodam todos SEM
            # PERCUS_CANON_DIR -- e na maquina do operador a variavel esta sempre setada, entao
            # eles passaram a exercitar um ramo que nunca executa em producao. A contagem de
            # testes subiu e a cobertura do caminho real nao acompanhou. Estes dois It cobrem as
            # mesmas falhas no ramo que de fato roda.
            $par = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "exit 0" -ComBom $true
            $kit = New-KitFalso   -Nome "external-action-guard" -ConteudoPs1 $script:ps1Quebrado -ComBom $false
            Invoke-Wrapper -Cmd $par -CanonDir $kit | Should -Be 2 -Because "parse quebrado no kit barra"
        }

        It "GUARDA: PERCUS_HOOKS_DISABLED vence o trampolim -- o escape nao depende de qual .ps1 seria escolhido" {
            # O escape esta na linha 2, ANTES de qualquer resolucao. Se um dia ele descesse pra
            # depois do trampolim, um kit quebrado passaria a trancar a maquina mesmo com o
            # escape declarado -- e o operador ficaria sem saida de emergencia justamente na
            # situacao em que mais precisa dela.
            $par = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "exit 2" -ComBom $true
            $kit = New-KitFalso   -Nome "external-action-guard" -ConteudoPs1 $script:ps1Quebrado -ComBom $false
            $anterior = $env:PERCUS_HOOKS_DISABLED
            $env:PERCUS_HOOKS_DISABLED = "1"
            try {
                Invoke-Wrapper -Cmd $par -CanonDir $kit | Should -Be 0 -Because "o escape roda antes do trampolim, entao nao importa qual .ps1 seria escolhido"
            } finally {
                if ($null -ne $anterior) { $env:PERCUS_HOOKS_DISABLED = $anterior }
                else { Remove-Item env:PERCUS_HOOKS_DISABLED -ErrorAction SilentlyContinue }
            }
        }

        It "OBSERVADOR: o trampolim vale pros 3 de Stop/PreCompact tambem" {
            # Sem isto, o trampolim poderia ter sido aplicado so nas guardas e a suite ficaria
            # verde -- a meia-correcao que deixou 3 guardas mortas sem ninguem ver.
            $par = New-ParDeTeste -Nome "on-stop-check" -ConteudoPs1 "exit 0" -ComBom $true
            $kit = New-KitFalso   -Nome "on-stop-check" -ConteudoPs1 "exit 2"
            Invoke-Wrapper -Cmd $par -CanonDir $kit | Should -Be 2 -Because "observador tambem tem que executar o codigo do kit"
        }
    }

    It "TODOS os 13 wrappers .cmd tem a forma do SEU evento no manifesto (9 guarda / 4 observador)" {
        # Os It anteriores provam o comportamento em UM wrapper de cada forma. Sem este, a
        # correcao poderia acertar so alguns dos 11 e a suite ficaria verde -- exatamente o tipo
        # de meia-correcao que deixou 3 guardas mortas sem ninguem ver.
        #
        # Aqui e inspecao de forma, e nao comportamento, de proposito: rodar os 11 wrappers de
        # verdade dispararia hook real (git, rede, escrita) como efeito colateral de teste.
        #
        # A forma esperada e DERIVADA do evento declarado, nunca de uma lista de nomes escrita
        # aqui: lista de nomes envelhece calada, e foi generalizar "todo wrapper e guarda" que
        # trancou o stop e a compactacao.
        #
        # A fonte passou a ser hooks-manifest.json, e nao hooks.json, porque o hooks.json e
        # justamente o arquivo que a migracao do registro ESVAZIA (Task 6 do plano 2). Se ele
        # continuasse sendo a fonte, este It iria afirmando cada vez menos ate nao afirmar nada,
        # em silencio, no ultimo commit da migracao -- a garantia de forma ficaria sem dono
        # exatamente quando mais precisa existir.
        #
        # A assercao e POSITIVA (forma exata esperada) e nao negativa (ausencia de '-Command').
        # Medido: a versao negativa era furada -- '-c' e abreviacao valida de -Command e passava
        # verde, e '-File' seguido de 'exit /b 0' engole a falha igual. So a forma inteira,
        # linha a linha e com o nome do proprio arquivo no %~dp0, fecha essas frestas.
        $manifesto = Get-Content (Join-Path $script:hooksDir "hooks-manifest.json") -Raw | ConvertFrom-Json

        # registrado=false e o orfao (canon-version-check): existe .ps1, nao existe .cmd. Entra
        # no manifesto pra deixar de ser invisivel, e fica fora da conta dos wrappers.
        $vivos = @($manifesto.hooks | Where-Object { $_.registrado })

        $evento = @{}
        $formaDeclarada = @{}
        foreach ($h in $vivos) {
            $evento[$h.nome]         = $h.evento
            $formaDeclarada[$h.nome] = $h.forma
        }

        $cmds = @(Get-ChildItem $script:hooksDir -Filter *.cmd | Sort-Object Name)

        # Piso de contagem: sem ele, uma pasta VAZIA faz este It passar sem verificar nada --
        # e a migracao dos hooks pro settings.json (spec sec. 9) esvazia exatamente esta pasta.
        $cmds.Count | Should -Be 13 -Because "piso de contagem: It que passa vazio nao guarda nada"

        # .cmd nao declarado no manifesto nao tem evento -- e a forma dele seria ADIVINHADA.
        # Adivinhar e o erro que este It existe pra impedir, entao aqui e falha, nao default.
        $orfaos = @($cmds | Where-Object { -not $evento.ContainsKey([IO.Path]::GetFileNameWithoutExtension($_.Name)) })
        @($orfaos.Name) | Should -BeNullOrEmpty -Because "sem evento no manifesto nao da pra saber se e guarda ou observador"

        # E o caminho inverso: hook declarado no manifesto sem .cmd em disco. Sem esta, apagar um
        # wrapper passaria como "nao ha divergencia" -- ausencia lendo como acordo.
        $semWrapper = @($vivos | Where-Object { -not (Test-Path (Join-Path $script:hooksDir ($_.nome + '.cmd'))) })
        @($semWrapper.nome) | Should -BeNullOrEmpty -Because "manifesto declara hook registrado que nao tem wrapper em disco"

        $nGuarda = 0
        $nObservador = 0
        $fora = @()
        $formaMentida = @()
        foreach ($c in $cmds) {
            $base = [IO.Path]::GetFileNameWithoutExtension($c.Name)
            $ev   = $evento[$base]

            # As oito primeiras linhas sao iguais nas duas formas -- inclusive o escape
            # PERCUS_HOOKS_DISABLED, que o observador tambem precisa (ver cabecalho), e o
            # trampolim, que observador tambem tem: fix de hook tem que chegar por git pull nos
            # 11, nao so nas guardas.
            #
            # O trampolim resolve o .ps1 do KIT quando PERCUS_CANON_DIR aponta pra um que tenha o
            # hook, e cai no proprio diretorio quando nao. Nao ha guarda anti-recursao porque nao
            # ha recursao possivel: o alvo e sempre um .ps1, nunca outro .cmd -- mesmo que
            # PERCUS_CANON_DIR aponte pro proprio cache, o pior caso e rodar o .ps1 que ja seria
            # rodado. Guarda que protege de nada e codigo que envelhece mentindo.
            $kitPs1 = '%PERCUS_CANON_DIR%\plugin\percus-review\hooks\' + $base + '.ps1'
            $esperado = @(
                '@echo off'
                'if "%PERCUS_HOOKS_DISABLED%"=="1" exit /b 0'
                ('set "PERCUS_HOOK_PS1=%~dp0' + $base + '.ps1"')
                'if not defined PERCUS_CANON_DIR goto :percus_roda'
                ('if not exist "' + $kitPs1 + '" goto :percus_roda')
                ('set "PERCUS_HOOK_PS1=' + $kitPs1 + '"')
                ':percus_roda'
                # O piso de tamanho ocupa TRES linhas, e nao uma, por causa de como o cmd expande.
                # 'if defined X if %X% LSS 200' numa linha so NAO funciona: o cmd expande a linha
                # inteira antes de avaliar o primeiro if, entao com X indefinido a linha vira
                # 'if  LSS 200' -- erro de sintaxe. Medido: dava exit 255 quando o .ps1 sumia.
                # Com o default de 999999 antes do for, a variavel nunca esta indefinida na hora
                # da comparacao, e arquivo ausente segue pro powershell, que falha e o fail-closed
                # traduz -- que e o comportamento que o It de '.ps1 ausente' ja exigia.
                'set "PERCUS_HOOK_TAM=999999"'
                'for %%A in ("%PERCUS_HOOK_PS1%") do if not "%%~zA"=="" set "PERCUS_HOOK_TAM=%%~zA"'
                ('if %PERCUS_HOOK_TAM% LSS 200 exit /b ' + $(if ($ev -eq 'PreToolUse') { '2' } else { '1' }))
                'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PERCUS_HOOK_PS1%"'
            )
            if ($ev -eq 'PreToolUse') {
                # GUARDA: traduz qualquer nao-zero em 2 pra guarda morta BARRAR a ferramenta.
                $esperado += @('if %ERRORLEVEL%==0 exit /b 0', 'exit /b 2')
                $nGuarda++
                $forma = "GUARDA (evento $ev)"
                $formaDerivada = 'guarda'
            } else {
                # OBSERVADOR: sem traducao de codigo. .ps1 morto devolve 1 (grita, nao tranca) e
                # o exit 2 que o proprio hook decide emitir passa direto e continua bloqueando.
                $nObservador++
                $forma = "OBSERVADOR (evento $ev)"
                $formaDerivada = 'observador'
            }

            # O manifesto declara a forma E o evento. Se os dois discordarem, o manifesto esta
            # mentindo -- e como ele e a fonte da verdade de tudo que vem depois (registro,
            # canario, health check), mentira aqui se propaga calada. A forma continua sendo
            # DERIVADA do evento; o campo declarado e conferido contra a derivacao, nunca usado
            # no lugar dela.
            if ($formaDeclarada[$base] -cne $formaDerivada) {
                $formaMentida += ("{0}: manifesto declara forma='{1}' mas o evento '{2}' deriva '{3}'" -f $base, $formaDeclarada[$base], $ev, $formaDerivada)
            }

            $linhas = @((Get-Content $c.FullName) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

            if (($linhas -join "`n") -cne ($esperado -join "`n")) {
                $fora += ("{0} -- esperado {1}:`n--- tem ---`n{2}`n--- esperado ---`n{3}" -f $c.Name, $forma, ($linhas -join "`n"), ($esperado -join "`n"))
            }
        }

        # Contagem por forma: sem ela, trocar o evento de um hook em hooks.json reclassificaria o
        # wrapper em silencio e este It seguiria verde medindo a coisa errada. Contagem errada e
        # a forma mais provavel deste teste apodrecer, entao os dois numeros sao afirmados.
        $nGuarda     | Should -Be 9 -Because "9 wrappers de PreToolUse tem que estar na forma GUARDA"
        $nObservador | Should -Be 4 -Because "on-stop-check + state-drift-check (Stop), pre-compact-checkpoint (PreCompact) e enforcement-health (SessionStart)"

        @($formaMentida) | Should -BeNullOrEmpty -Because "manifesto com forma divergente do evento propaga classificacao errada pro registro, pro canario e pro health check:`n$($formaMentida -join "`n")"

        @($fora) | Should -BeNullOrEmpty -Because "wrapper na forma errada pro evento dele bloqueia o que nao devia, ou nao bloqueia o que devia:`n$($fora -join "`n`n")"
    }
}
