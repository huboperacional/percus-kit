#requires -Version 5.1
# Prova que hooks-manifest.json descreve o mundo que existe, e nao um mundo desejado.
#
# O manifesto virou fonte unica da verdade: dele saem o registro (hooks.json hoje,
# settings.json depois da Task 6), o canario da Task 5 e o health check da Task 7. Fonte
# da verdade que mente propaga a mentira pra tudo que deriva dela, em silencio -- que e
# exatamente a classe de bug que o plano 2 existe pra fechar.
#
# O teste mais importante daqui e o da ASSINATURA. O canario conta execucoes procurando a
# assinatura em stderr; se a assinatura declarada nao existir no .ps1, o canario conta ZERO
# e chama de aprovado. Uma assinatura errada nao quebra nada visivelmente -- ela apaga a
# unica evidencia de que o hook rodou.

Describe "hooks-manifest.json" {

    BeforeAll {
        $script:hooksDir     = Join-Path $PSScriptRoot ".." "hooks"
        $script:manifestPath = Join-Path $script:hooksDir "hooks-manifest.json"
        $script:manifesto    = Get-Content $script:manifestPath -Raw | ConvertFrom-Json
        $script:todos        = @($script:manifesto.hooks)
        $script:vivos        = @($script:todos | Where-Object { $_.registrado })
    }

    It "existe e e JSON valido" {
        Test-Path $script:manifestPath | Should -Be $true
        $script:todos.Count | Should -BeGreaterThan 0
    }

    It "declara 16 hooks registrados (10 guarda / 5 observador / 1 dispatcher) + o orfao" {
        # Piso de contagem, mesma razao do hook-wrapper-fail-loud: manifesto esvaziado faria
        # todos os It abaixo iterarem sobre lista vazia e passarem sem verificar nada.
        # 6.45.0: +1 observador (context-budget-guard, PostToolUse). 6.47.0: +1 guarda de comando
        # (spec-analyze-check, o gate [S] que faltava).
        # 6.49.0: +1 dispatcher (percus-dispatch-pre). Os 10 guarda continuam 10 -- oito deles
        # apenas deixaram de ter entrada propria no hooks.json e passaram a ser rodados pela
        # camada 2. Guarda dispatchada segue sendo guarda: e o campo `registro` que mudou, nao a
        # forma. Confundir os dois faria "saiu do hooks.json" ler como "deixou de valer".
        $script:vivos.Count | Should -Be 16 -Because "piso: manifesto vazio nao guarda nada"
        @($script:vivos | Where-Object { $_.forma -ceq 'guarda' }).Count     | Should -Be 10
        @($script:vivos | Where-Object { $_.forma -ceq 'observador' }).Count | Should -Be 5
        @($script:vivos | Where-Object { $_.forma -ceq 'dispatcher' }).Count | Should -Be 1
        @($script:todos | Where-Object { -not $_.registrado }).Count | Should -Be 1 -Because "canon-version-check e orfao conhecido; orfao novo aparecendo sem ninguem decidir e drift"
    }

    It "nao tem nome repetido" {
        # Nome repetido faria o consumidor pegar 'o primeiro que achar' -- e qual e o primeiro
        # depende da ordem do arquivo, que ninguem trata como significativa.
        $nomes = @($script:todos | ForEach-Object { $_.nome })
        @($nomes | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }) |
            Should -BeNullOrEmpty
    }

    It "a assinatura declarada de cada hook e EMISSIVEL EM STDERR, nao so presente no arquivo" {
        # O teste que sustenta o canario. O canario conta execucoes procurando a assinatura no
        # STDERR; assinatura que o hook nunca manda pro stderr faz o canario contar zero e
        # concluir 'nao rodou duas vezes' -- quando na verdade ele so nao sabe contar. Falso
        # verde do tipo mais caro: o que parece medicao.
        #
        # A primeira versao deste It so procurava a string no arquivo, e passava PELO MOTIVO
        # ERRADO. Medido em mock-scan-pre-commit.ps1: o caminho de BLOCK real (linha 70) chama
        # Write-PercusBlock -HookName 'mock-scan', que monta "[percus:hook mock-scan] BLOCK:"
        # em RUNTIME -- o literal nao esta la. O literal aparece so na linha 78, num Write-Host
        # de crash, que vai pro stdout do host e nunca pro stderr. Ou seja: o teste aprovava por
        # causa de uma linha que o canario jamais veria. Se o -HookName divergisse do manifesto,
        # o teste continuaria verde e o canario contaria zero.
        #
        # O discriminador certo nao e "o literal existe", e "isto sai no stderr". Tres fontes
        # contam, e Write-Host nao e nenhuma delas.
        $semAssinatura = @()
        foreach ($h in $script:todos) {
            $ps1 = Join-Path $script:hooksDir ($h.nome + ".ps1")
            if (-not (Test-Path $ps1)) {
                $semAssinatura += "$($h.nome): .ps1 nao encontrado em $ps1"
                continue
            }
            # Arquivo ilegivel conta como NAO-VERIFICADO, nunca como limpo -- licao da Task 6
            # da fase 1, provada la por mutacao com ACL negando leitura.
            try {
                $linhas = Get-Content $ps1 -ErrorAction Stop
            } catch {
                $semAssinatura += "$($h.nome): .ps1 ilegivel ($($_.Exception.Message)) -- nao-verificado, nao 'ok'"
                continue
            }

            $emissiveis = New-Object System.Collections.Generic.HashSet[string]
            $naoVerificavel = @()
            foreach ($linha in $linhas) {
                $t = "$linha".TrimStart()
                if ($t.StartsWith('#')) { continue }          # comentario nao emite nada
                if ($t -match 'Write-Host') { continue }      # stdout do host, invisivel pro canario

                # Fonte 1: o helper compartilhado, que escreve em [Console]::Error e monta a
                # assinatura a partir do -HookName. Deriva-se do argumento, nao de um literal.
                if ($t -match "Write-PercusBlock\s+-HookName\s+['""]([^'""]+)['""]") {
                    [void]$emissiveis.Add("[percus:hook $($matches[1])]")
                }
                elseif ($t -match "Write-PercusBlock\s+-HookName\s+(\S+)") {
                    # -HookName vindo de variavel ou expressao: a assinatura so existe em runtime.
                    # Isto NAO e "assinatura ausente" -- e "nao consegui verificar estaticamente",
                    # e tratar os dois como a mesma coisa e o erro que o verbete
                    # #fact-check-infundado-e-nao-verificado descreve. Falha, mas dizendo qual dos
                    # dois casos e, senao quem le conserta a coisa errada.
                    $naoVerificavel += "-HookName $($matches[1])"
                }
                # Fonte 2 e 3: literal em linha viva -- escrita direta no stderr, ou string
                # montada numa variavel que depois vai pro stderr (pre-compact-checkpoint faz assim).
                if ($t -match '(\[percus:[^\]]+\])') {
                    [void]$emissiveis.Add($matches[1])
                }
            }

            if (-not $emissiveis.Contains($h.assinatura)) {
                if ($naoVerificavel.Count -and $emissiveis.Count -eq 0) {
                    $semAssinatura += ("{0}: NAO-VERIFICAVEL -- o -HookName vem de expressao ({1}), entao a assinatura so existe em runtime. Convencao do kit: -HookName literal, para o canario poder ser conferido sem executar o hook. Isto nao afirma que a assinatura esta errada; afirma que nao da pra saber daqui." -f $h.nome, ($naoVerificavel -join '; '))
                } else {
                    $semAssinatura += ("{0}: declara '{1}', mas o que o .ps1 consegue mandar pro stderr e: {2}" -f `
                        $h.nome, $h.assinatura, $(if ($emissiveis.Count) { ($emissiveis -join ', ') } else { '<nada>' }))
                }
            }
        }
        @($semAssinatura) | Should -BeNullOrEmpty -Because "assinatura que nao chega ao stderr faz o canario contar zero e chamar de aprovado:`n$($semAssinatura -join "`n")"
    }

    It "a forma declarada concorda com a forma DERIVADA do evento" {
        # Este arquivo diz no cabecalho que prova que o manifesto nao mente -- entao a checagem
        # tem que morar aqui, e nao so em hook-wrapper-fail-loud.tests.ps1. Sem ela, um manifesto
        # que TROCASSE a forma de dois hooks entre si manteria a soma 8/3 do It de contagem e
        # passaria limpo neste arquivo, so sendo pego por acaso porque o outro roda na mesma suite.
        # Promessa cumprida por vizinho e promessa nao cumprida.
        # O dispatcher e a unica forma que NAO se deriva do evento: ele e PreToolUse e nao e
        # guarda -- nao inspeciona nada, so roteia. A excecao nao pode ser uma lista de nomes
        # (envelhece calada), entao ela e ESTRUTURAL e conferida logo abaixo: e dispatcher quem
        # tem outros hooks apontando pra ele via registro='dispatcher'.
        $ehDispatcher = @($script:vivos | Where-Object { $_.forma -ceq 'dispatcher' })
        $ehDispatcher.Count | Should -Be 1 -Because "mais de um dispatcher e ambiguidade de roteamento"
        $ehDispatcher[0].evento | Should -BeExactly 'PreToolUse'
        $ehDispatcher[0].registro | Should -BeExactly 'hooks.json' -Because "o dispatcher precisa de entrada propria, senao nada o chama"
        $dispatchados = @($script:vivos | Where-Object { $_.registro -ceq 'dispatcher' })
        $dispatchados.Count | Should -BeGreaterThan 0 -Because "dispatcher sem ninguem atras dele e processo a toa"
        foreach ($d in $dispatchados) {
            # Se o evento/matcher do check nao bate com o do dispatcher, o harness nunca entrega
            # aquela chamada -- o check some CALADO, que e a falha que este arquivo existe pra pegar.
            $d.evento  | Should -BeExactly $ehDispatcher[0].evento  -Because "$($d.nome) so e alcancavel se compartilhar o evento do dispatcher"
            $d.matcher | Should -BeExactly $ehDispatcher[0].matcher -Because "$($d.nome) so e alcancavel se compartilhar o matcher do dispatcher"
        }

        $mentiras = @()
        foreach ($h in $script:vivos) {
            if ($h.forma -ceq 'dispatcher') { continue }
            $derivada = if ($h.evento -ceq 'PreToolUse') { 'guarda' } else { 'observador' }
            if ($h.forma -cne $derivada) {
                $mentiras += "$($h.nome): forma='$($h.forma)' mas evento='$($h.evento)' deriva '$derivada'"
            }
        }
        @($mentiras) | Should -BeNullOrEmpty -Because "forma e derivavel do evento; declarar diferente propaga classificacao errada pro registro, canario e health check:`n$($mentiras -join "`n")"
    }

    It "o escape declarado de cada hook e LIDO pelo .ps1, nao so mencionado" {
        # Mesma doenca da assinatura: escape documentado que o script nao LE e uma saida de
        # emergencia que nao abre, e o operador descobre no pior momento possivel. Mencao num
        # comentario ('escape: PERCUS_SKIP_X') e exatamente o caso que passaria numa busca
        # textual e falharia na hora do aperto.
        #
        # Exigir '$env:NOME' em linha viva resolve duas coisas de uma vez: prova leitura de
        # verdade, e a fronteira de palavra impede que PERCUS_SKIP_MOCK case com um
        # PERCUS_SKIP_MOCK_SCAN que esteja no arquivo por outro motivo.
        $semEscape = @()
        foreach ($h in @($script:todos | Where-Object { $_.escape })) {
            # O escape do dispatcher e lido na CAMADA 1 (.cmd), e tem de ser: se so o .ps1 o
            # lesse, o bypass custaria o startup do PowerShell que ele existe pra evitar.
            $alvo = if ($h.forma -ceq 'dispatcher') { Join-Path $script:hooksDir ($h.nome + ".cmd") }
                    else                            { Join-Path $script:hooksDir ($h.nome + ".ps1") }
            $ps1 = $alvo
            if (-not (Test-Path $ps1)) {
                $semEscape += "$($h.nome): $(Split-Path $alvo -Leaf) nao encontrado -- nao-verificado, nao 'ok'"
                continue
            }
            # A sintaxe da leitura depende do runtime do arquivo: PowerShell le $env:NOME,
            # cmd.exe le %NOME%. Exigir a forma do PowerShell num .cmd reprovaria o dispatcher
            # por ele estar CERTO -- e falso positivo em trava e o que faz alguem afrouxa-la.
            # O comentario tambem muda de marcador: '#' no PowerShell, 'REM' no cmd.
            $ehCmd  = $ps1.EndsWith('.cmd')
            $padrao = if ($ehCmd) { '%' + [regex]::Escape($h.escape) + '%' }
                      else        { '\$env:' + [regex]::Escape($h.escape) + '\b' }
            $le = @(Get-Content $ps1 | Where-Object {
                $t = "$_".TrimStart()
                $morto = if ($ehCmd) { $t -match '^(?i)REM\b' -or $t.StartsWith('::') } else { $t.StartsWith('#') }
                (-not $morto) -and ($t -match $padrao)
            })
            if ($le.Count -eq 0) {
                $semEscape += "$($h.nome): declara escape '$($h.escape)' e nenhuma linha viva le `$env:$($h.escape)"
            }
        }
        @($semEscape) | Should -BeNullOrEmpty -Because "escape que nao abre e pior que escape nenhum:`n$($semEscape -join "`n")"
    }

    It "concorda com o hooks.json, que hoje e o registro vivo" {
        # Enquanto o hooks.json for quem o harness le, divergir dele e erro -- o manifesto
        # descreveria um registro que nao existe. Quando a Task 6 mover o registro pro
        # settings.json e esvaziar o hooks.json, este It passa a comparar com o registro novo;
        # ate la, ele e a amarra que impede o manifesto de virar ficcao.
        $hooksJson = Get-Content (Join-Path $script:hooksDir "hooks.json") -Raw | ConvertFrom-Json

        $registrado = @{}
        foreach ($ev in $hooksJson.hooks.PSObject.Properties) {
            foreach ($bloco in @($ev.Value)) {
                foreach ($h in @($bloco.hooks)) {
                    if ($h.command -match '([^/\\"]+)\.cmd') {
                        $registrado[$matches[1]] = [pscustomobject]@{
                            Evento  = $ev.Name
                            Matcher = $bloco.matcher
                        }
                    }
                }
            }
        }

        $divergencias = @()

        # 6.49.0: registro deixou de ser binario. `registro` diz por QUAL caminho o hook esta
        # vivo, e cada caminho tem a sua obrigacao:
        #   hooks.json  -> TEM de estar no hooks.json, com evento e matcher iguais
        #   dispatcher  -> tem de estar FORA do hooks.json (entrada propria seria execucao dupla)
        #                  e declarar gatilhos, senao a camada 1 nunca o acorda
        # Sem essa separacao, mover os 8 pra tras do dispatcher reprovaria aqui, e a saida facil
        # seria afrouxar o teste -- matando justamente a trava que impede o manifesto virar ficcao.
        foreach ($h in @($script:vivos | Where-Object { $_.registro -ceq 'dispatcher' })) {
            if ($registrado.ContainsKey($h.nome)) {
                $divergencias += "$($h.nome): registro='dispatcher' mas tem entrada propria no hooks.json (rodaria DUAS vezes)"
            }
            if (-not $h.gatilhos -or @($h.gatilhos).Count -eq 0) {
                $divergencias += "$($h.nome): registro='dispatcher' sem gatilhos declarados -- a camada 1 nunca o acordaria"
            }
        }

        foreach ($h in @($script:vivos | Where-Object { $_.registro -cne 'dispatcher' })) {
            if (-not $registrado.ContainsKey($h.nome)) {
                $divergencias += "$($h.nome): manifesto diz registrado, hooks.json nao tem"
                continue
            }
            $r = $registrado[$h.nome]
            if ($r.Evento -cne $h.evento) {
                $divergencias += "$($h.nome): evento manifesto='$($h.evento)' hooks.json='$($r.Evento)'"
            }
            # matcher ausente no hooks.json chega como $null; no manifesto e null explicito.
            $mManifesto = if ($null -eq $h.matcher) { "" } else { "$($h.matcher)" }
            $mRegistro  = if ($null -eq $r.Matcher) { "" } else { "$($r.Matcher)" }
            if ($mManifesto -cne $mRegistro) {
                $divergencias += "$($h.nome): matcher manifesto='$mManifesto' hooks.json='$mRegistro'"
            }
        }

        foreach ($nome in $registrado.Keys) {
            $decl = @($script:vivos | Where-Object { $_.nome -ceq $nome })
            if ($decl.Count -eq 0) {
                $divergencias += "$nome : hooks.json registra, manifesto nao declara"
            } elseif ($decl[0].registro -ceq 'dispatcher') {
                $divergencias += "$nome : hooks.json registra, mas o manifesto diz registro='dispatcher'"
            }
        }

        @($divergencias) | Should -BeNullOrEmpty -Because "manifesto e registro vivo tem que contar a mesma historia:`n$($divergencias -join "`n")"
    }

    It "as guardas de comando cobrem os DOIS shells, nao so o Bash" {
        # O buraco que abriu o plano 2: o matcher era "Bash" e mais nada, enquanto o harness expoe
        # DUAS tools de shell. Observado em 2026-07-31, mesma maquina e mesmo instante: a mesma
        # acao externa barrada pela tool Bash e livre pela tool PowerShell.
        #
        # Medido junto (item 4): o matcher e regex e aceita alternancia, e e CASE-SENSITIVE --
        # escrever "bash" produziria uma guarda que nunca dispara, que e a ausencia silenciosa que
        # este plano existe pra matar. Por isso a assercao e exata, e nao "contem bash".
        # A fronteira agora e DECLARADA no campo 'alvo', nao derivada por exclusao. Derivar
        # ("PreToolUse que nao seja ExitPlanMode") funcionou enquanto guarda de PreToolUse era
        # sinonimo de guarda de comando; quando entrou a primeira guarda de CAMINHO
        # (knowledge-write-guard, matcher Edit|Write), a derivacao passou a exigir
        # 'Bash|PowerShell' de um hook que le tool_input.file_path -- teria proibido por
        # construcao a guarda nova, que e correta. Lista de excecao que cresce e cheiro de
        # criterio faltando: o criterio e o alvo.
        $deComando = @($script:vivos | Where-Object { $_.evento -ceq 'PreToolUse' -and $_.alvo -ceq 'comando' })
        $deComando.Count | Should -Be 9 -Because "piso: 8 guardas de COMANDO + o dispatcher (pre-plan-exit olha plano, knowledge-write-guard olha caminho)"
        foreach ($h in $deComando) {
            $h.matcher | Should -BeExactly 'Bash|PowerShell' -Because "$($h.nome) precisa cobrir as duas tools de shell, com a caixa exata"
        }
    }

    It "nenhuma GUARDA DE COMANDO decide pelo NOME da tool -- o payload das duas traz o comando no mesmo campo" {
        # O conserto e so no matcher justamente porque nenhuma guarda de comando olha tool_name:
        # todas leem tool_input.command, campo que as duas tools preenchem. Se alguma passasse a
        # ramificar por tool_name, o matcher novo entregaria a chamada e o hook a descartaria em
        # silencio -- e o teste do matcher, sozinho, seguiria verde.
        #
        # O escopo e so as 7 de comando, e essa fronteira foi ENSINADA por este teste falhando:
        # pre-plan-exit.ps1:14 checa 'tool_name -ne ExitPlanMode' e sai 0, o que e legitimo -- ele
        # confere por dentro o proprio matcher, que nao tem nada a ver com shell. Generalizar
        # "nenhum hook olha tool_name" teria proibido uma pratica correta.
        $olhamNome = @()
        foreach ($h in @($script:vivos | Where-Object { $_.matcher -ceq 'Bash|PowerShell' })) {
            $ps1 = Join-Path $script:hooksDir ($h.nome + ".ps1")
            if (-not (Test-Path $ps1)) { continue }
            $vivas = @(Get-Content $ps1 | Where-Object { -not "$_".TrimStart().StartsWith('#') })
            if ($vivas -match 'tool_name') { $olhamNome += $h.nome }
        }
        @($olhamNome) | Should -BeNullOrEmpty -Because "hook que ramifica por tool_name precisa de teste proprio nos dois caminhos:`n$($olhamNome -join ', ')"
    }

    It "o orfao declarado nao tem wrapper -- e isso e o que o torna orfao" {
        # Invariante POSITIVO sobre o orfao: se um dia alguem criar canon-version-check.cmd,
        # ele deixou de ser orfao e o manifesto precisa parar de dizer que e. Sem este It, o
        # manifesto continuaria declarando registrado=false sobre um hook ja registrado.
        foreach ($h in @($script:todos | Where-Object { -not $_.registrado })) {
            Test-Path (Join-Path $script:hooksDir ($h.nome + ".cmd")) |
                Should -Be $false -Because "$($h.nome) ganhou wrapper: ou foi registrado de verdade, ou o wrapper e lixo -- decida e atualize o manifesto"
        }
    }
}
