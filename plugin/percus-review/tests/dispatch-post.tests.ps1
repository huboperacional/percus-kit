# Testes do dispatcher PostToolUse (camada 1 cmd.exe + camada 2 PowerShell).
#
# Escritos ANTES da implementacao (TDD), no mesmo molde do dispatch-pre.tests.ps1.
#
# DISCIPLINA: prova COMPORTAMENTAL -- roda o .cmd/.ps1 de verdade contra payload
# real e olha exit code, stdout e stderr. Nenhum teste inspeciona fonte procurando
# string: inspecao de fonte prova que alguem escreveu algo, nao que o programa faz.
#
# O QUE MUDA EM RELACAO AO `pre`, e por que os testes nao sao os mesmos:
#
#  1. A triagem da camada 1 e uma PORTA POR TIMESTAMP, nao um findstr de gatilhos.
#     O `context-budget-guard` tem matcher VAZIO de proposito (contexto cresce com
#     Read/Edit tanto quanto com Bash), entao nao ha substring que o trie.
#  2. A camada 1 NAO captura stdin. O payload de PostToolUse carrega `tool_response`
#     -- MEDIDO em 60 476 tool_results reais: mediana 344 B, p99 26 KB, MAX 681 KB,
#     e 0,59% passam de 80 KB, que e onde a captura do `pre` (findstr "^") trunca.
#     Copiar aquela captura traria truncagem ROTINEIRA. Como a porta nao precisa ler
#     o payload, a camada 1 repassa stdin DIRETO pro PowerShell, como o .cmd antigo
#     ja fazia -- sem temp, sem limite de tamanho, sem a classe de falha inteira.
#  3. O guard devolve o aviso em JSON no STDOUT. No `pre` so importavam exit code e
#     stderr; aqui stdout e o canal do produto. Mangear stdout = perder o aviso calado.

BeforeAll {
    $script:hooksDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks'
    $script:dispCmd  = Join-Path $hooksDir 'percus-dispatch-post.cmd'
    $script:dispPs1  = Join-Path $hooksDir 'percus-dispatch-post.ps1'
    $script:portaTxt = Join-Path $hooksDir 'porta-post.txt'
    $script:manifest = Join-Path $hooksDir 'hooks-manifest.json'

    # Transcript sintetico: uma linha de `usage` com tokens altos o bastante pra o
    # guard falar. Sem isso o guard sai 0 calado e o teste de passagem de stdout
    # passaria VAZIO -- provaria que nada foi mangeado porque nada foi produzido.
    $script:tmpRaiz = Join-Path ([IO.Path]::GetTempPath()) ("percus-post-t-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:tmpRaiz -Force | Out-Null
    $script:transcript = Join-Path $script:tmpRaiz 'sessao.jsonl'
    $linha = '{"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":190000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
    [IO.File]::WriteAllText($script:transcript, $linha + "`n", (New-Object Text.UTF8Encoding($false)))

    function New-PayloadPost {
        param([string]$ToolName = 'Read', [string]$Resposta = 'ok', [string]$Sessao = 'sess-teste')
        @{
            session_id      = $Sessao
            transcript_path = $script:transcript
            cwd             = $script:tmpRaiz
            tool_name       = $ToolName
            tool_input      = @{ file_path = 'x.txt' }
            tool_response   = $Resposta
        } | ConvertTo-Json -Compress -Depth 5
    }

    # Roda a camada 1 com o payload em stdin. Devolve exit code + stdout + stderr.
    # Cada chamada recebe uma SESSAO propria por padrao, senao a porta de um teste
    # fecharia a do seguinte e os casos ficariam acoplados pela ordem de execucao.
    function Invoke-DispatchPost {
        param([string]$Payload, [hashtable]$Env = @{})
        $tmpIn  = Join-Path $script:tmpRaiz ([Guid]::NewGuid().ToString('N') + '.in')
        $tmpErr = Join-Path $script:tmpRaiz ([Guid]::NewGuid().ToString('N') + '.err')
        $tmpOut = Join-Path $script:tmpRaiz ([Guid]::NewGuid().ToString('N') + '.out')
        [IO.File]::WriteAllText($tmpIn, $Payload, (New-Object Text.UTF8Encoding($false)))
        $antigos = @{}
        foreach ($k in $Env.Keys) {
            $antigos[$k] = [Environment]::GetEnvironmentVariable($k)
            [Environment]::SetEnvironmentVariable($k, $Env[$k])
        }
        try {
            $p = Start-Process -FilePath $env:ComSpec `
                -ArgumentList @('/c', "`"$script:dispCmd`"") `
                -RedirectStandardInput $tmpIn -RedirectStandardError $tmpErr `
                -RedirectStandardOutput $tmpOut -NoNewWindow -Wait -PassThru
            [pscustomobject]@{
                ExitCode = $p.ExitCode
                Stdout   = (Get-Content $tmpOut -Raw -ErrorAction SilentlyContinue)
                Stderr   = (Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue)
            }
        } finally {
            foreach ($k in $Env.Keys) { [Environment]::SetEnvironmentVariable($k, $antigos[$k]) }
            foreach ($t in $tmpIn, $tmpErr, $tmpOut) { Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue }
        }
    }

    # Sessao nova a cada chamada = porta sempre ABERTA, isolando o caso sob teste.
    function New-SessaoId { 'sess-' + [Guid]::NewGuid().ToString('N').Substring(0, 12) }
}

AfterAll {
    Remove-Item -LiteralPath $script:tmpRaiz -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'dispatcher PostToolUse -- camada 1 (porta por timestamp)' {

    It 'existe como .cmd e .ps1 (paridade de arquivos)' {
        Test-Path $script:dispCmd | Should -BeTrue
        Test-Path $script:dispPs1 | Should -BeTrue
    }

    It 'porta-post.txt existe, e um inteiro positivo e NAO tem BOM' {
        # Mesma classe medida no gatilhos-pre.txt: BOM vira parte do primeiro token
        # e o `set /p` do cmd leria lixo -- a porta cairia no fail-open e o ganho
        # sumiria CALADO (o dispatcher continuaria correto, so caro).
        Test-Path $script:portaTxt | Should -BeTrue
        $bytes = [IO.File]::ReadAllBytes($script:portaTxt)
        ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) |
            Should -BeFalse -Because 'BOM faria o set /p do cmd.exe ler lixo'
        $n = 0
        [int]::TryParse((Get-Content $script:portaTxt -First 1).Trim(), [ref]$n) | Should -BeTrue
        $n | Should -BeGreaterThan 0
    }

    It 'primeira chamada da sessao ABRE a porta e sobe a camada 2' {
        $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId)) `
                                 -Env @{ PERCUS_DISPATCH_DEBUG = '1'; CLAUDE_CODE_SESSION_ID = (New-SessaoId) }
        $r.Stderr | Should -Match 'checks rodados' -Because 'sem porta anterior, a camada 2 tem de subir'
    }

    It 'segunda chamada dentro da janela DORME -- a camada 2 nem sobe' {
        # Este e o teste que da sentido ao pacote inteiro: se ele passasse num
        # dispatcher que sempre sobe o PowerShell, a economia viria de lugar nenhum.
        $s = New-SessaoId
        $e = @{ PERCUS_DISPATCH_DEBUG = '1'; PERCUS_POST_PORTA_SEGUNDOS = '3600'; CLAUDE_CODE_SESSION_ID = $s }
        $null = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao $s) -Env $e
        $r2 = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao $s) -Env $e
        $r2.ExitCode | Should -Be 0
        $r2.Stderr   | Should -Not -Match 'checks rodados' -Because 'dentro da janela o PowerShell nao pode subir'
    }

    It 'porta de 0 segundos NUNCA dorme -- o par complementar do teste acima' {
        # Sem este, "dorme dentro da janela" passaria num dispatcher que dorme SEMPRE,
        # e o guard teria sido desligado em silencio em vez de otimizado.
        $s = New-SessaoId
        $e = @{ PERCUS_DISPATCH_DEBUG = '1'; PERCUS_POST_PORTA_SEGUNDOS = '0'; CLAUDE_CODE_SESSION_ID = $s }
        $null = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao $s) -Env $e
        $r2 = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao $s) -Env $e
        $r2.Stderr | Should -Match 'checks rodados' -Because 'porta 0 = medir toda call'
    }

    It 'sessoes diferentes tem portas INDEPENDENTES' {
        # Porta global faria a sessao B fechar a porta da sessao A: A poderia estourar
        # a janela enquanto as chamadas de B seguram o guard fechado. Degradacao
        # silenciosa, e o operador roda 2+ sessoes na mesma arvore rotineiramente.
        $a = New-SessaoId; $b = New-SessaoId
        $null = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao $a) `
                    -Env @{ PERCUS_DISPATCH_DEBUG = '1'; PERCUS_POST_PORTA_SEGUNDOS = '3600'; CLAUDE_CODE_SESSION_ID = $a }
        $rb = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao $b) `
                    -Env @{ PERCUS_DISPATCH_DEBUG = '1'; PERCUS_POST_PORTA_SEGUNDOS = '3600'; CLAUDE_CODE_SESSION_ID = $b }
        $rb.Stderr | Should -Match 'checks rodados' -Because 'a porta de A nao pode calar B'
    }
}

Describe 'dispatcher PostToolUse -- camada 2 (o aviso tem de CHEGAR)' {

    It 'o JSON que o guard escreve no stdout passa INTACTO' {
        # O canal do produto no PostToolUse e o stdout: o harness le
        # hookSpecificOutput.additionalContext e injeta no contexto do agente.
        # Dispatcher que engole, reordena ou concatena stdout mata o aviso sem
        # deixar rastro -- a falha exata que este pacote existe pra nao causar.
        $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId)) `
                                 -Env @{ PERCUS_CTX_WINDOW = '200000'; CLAUDE_CODE_SESSION_ID = (New-SessaoId) }
        $r.ExitCode | Should -Be 0
        $r.Stdout   | Should -Not -BeNullOrEmpty -Because 'o guard tinha 190k tokens numa janela de 200k: ele TEM de falar'
        { $r.Stdout | ConvertFrom-Json } | Should -Not -Throw -Because 'stdout precisa continuar sendo UM JSON valido'
        $o = $r.Stdout | ConvertFrom-Json
        $o.hookSpecificOutput.hookEventName     | Should -Be 'PostToolUse'
        $o.hookSpecificOutput.additionalContext | Should -Match 'context-budget'
    }

    It 'payload MAIOR que 80 KB nao quebra -- a classe que mata a captura do `pre`' {
        # 0,59% dos tool_results reais passam de 80 KB (medido em 60 476). Se a
        # camada 1 capturasse stdin como o `pre` faz, esses truncariam, o JSON ficaria
        # invalido e o dispatcher falaria erro em toda tool call grande. Como ela
        # repassa stdin direto, o tamanho e irrelevante -- e este teste fixa isso.
        $grande = 'x' * 300000
        $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId) -Resposta $grande) `
                                 -Env @{ PERCUS_CTX_WINDOW = '200000'; CLAUDE_CODE_SESSION_ID = (New-SessaoId) }
        $r.ExitCode | Should -Be 0
        $r.Stderr   | Should -Not -Match 'nao parseia|truncad' -Because 'payload grande e rotina no PostToolUse, nao erro'
        $o = $r.Stdout | ConvertFrom-Json
        $o.hookSpecificOutput.additionalContext | Should -Match 'context-budget' -Because 'o aviso tem de sair igual com payload grande'
    }

    It 'PERCUS_HOOKS_DISABLED=1 sai 0 antes de qualquer trabalho' {
        $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId)) `
                                 -Env @{ PERCUS_HOOKS_DISABLED = '1'; PERCUS_DISPATCH_DEBUG = '1' }
        $r.ExitCode | Should -Be 0
        $r.Stdout   | Should -BeNullOrEmpty
        $r.Stderr   | Should -Not -Match 'checks rodados'
    }

    It 'PERCUS_DISPATCHER_BYPASS=1 cai na cadeia antiga E o aviso continua saindo' {
        # Defesa 1. O discriminador e duplo de proposito: AUSENCIA da linha da camada 2
        # (prova que o bypass pegou) E PRESENCA do aviso (prova que a rota antiga
        # entrega). So o primeiro passaria num bypass que simplesmente nao faz nada --
        # que e "rapido e mudo", exatamente o que a defesa 1 proibe.
        $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId)) `
                                 -Env @{ PERCUS_DISPATCHER_BYPASS = '1'; PERCUS_DISPATCH_DEBUG = '1'
                                         PERCUS_CTX_WINDOW = '200000'; CLAUDE_CODE_SESSION_ID = (New-SessaoId) }
        $r.Stderr | Should -Not -Match 'checks rodados' -Because 'no bypass quem roda e a cadeia antiga'
        $o = $r.Stdout | ConvertFrom-Json
        $o.hookSpecificOutput.additionalContext | Should -Match 'context-budget' -Because 'lento e correto > rapido e mudo'
    }

    It 'check que nao fala nada nao inventa stdout' {
        # Contexto baixo: o guard sai 0 calado. O dispatcher nao pode emitir um JSON
        # vazio -- o harness trataria como saida de hook e o transcript ganharia ruido
        # em TODA tool call.
        $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId)) `
                                 -Env @{ PERCUS_CTX_WINDOW = '100000000'; CLAUDE_CODE_SESSION_ID = (New-SessaoId) }
        $r.ExitCode | Should -Be 0
        $r.Stdout   | Should -BeNullOrEmpty -Because 'silencio do check tem de virar silencio do dispatcher'
    }
}

Describe 'dispatcher PostToolUse -- registro e contencao (defesa 3)' {

    It 'a cadeia de FALLBACK lista exatamente os checks dispatchados de PostToolUse' {
        # Mesma classe do `pre`: um check novo com registro='percus-dispatch-post' que
        # nao entre no fallback sumiria CALADO justo quando o PowerShell nao sobe.
        $m = Get-Content $script:manifest -Raw | ConvertFrom-Json
        $esperados = @($m.hooks | Where-Object { $_.registro -ceq 'percus-dispatch-post' } | ForEach-Object { $_.nome } | Sort-Object)
        $esperados.Count | Should -BeGreaterThan 0 -Because 'piso: sem dispatchados este It passaria vazio'
        $noFallback = @(Get-Content $script:dispCmd |
                ForEach-Object { if ($_ -match '^\s*call :roda\s+(\S+)') { $matches[1] } } | Sort-Object)
        ($noFallback -join ',') | Should -BeExactly ($esperados -join ',')
    }

    It 'o denominador do debug conta so os checks de PostToolUse' {
        $m = Get-Content $script:manifest -Raw | ConvertFrom-Json
        $n = @($m.hooks | Where-Object { $_.registro -ceq 'percus-dispatch-post' }).Count
        $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId)) `
                                 -Env @{ PERCUS_DISPATCH_DEBUG = '1'; CLAUDE_CODE_SESSION_ID = (New-SessaoId) }
        $r.Stderr | Should -Match "de $n\b"
    }

    It 'nenhum check de PostToolUse ficou registrado direto no hooks.json' {
        # Se o context-budget-guard continuasse com entrada propria no hooks.json
        # ALEM de estar no dispatcher, ele rodaria DUAS vezes por tool call -- o
        # dobro do custo que este pacote existe pra remover, e sem nenhum aviso.
        $hooksJson = Get-Content (Join-Path $script:hooksDir 'hooks.json') -Raw | ConvertFrom-Json
        $cmdsPost = @($hooksJson.hooks.PostToolUse | ForEach-Object { $_.hooks } | ForEach-Object { $_.command })
        $cmdsPost.Count | Should -BeGreaterThan 0
        foreach ($c in $cmdsPost) {
            $c | Should -Match 'percus-dispatch-post' -Because "PostToolUse so pode chamar o dispatcher, mas achei: $c"
        }
    }
}

Describe 'dispatcher PostToolUse -- achados do review R11 (2026-09-12)' {

    It 'porta 0 NAO suja o stderr com erro nativo do Windows' {
        # ACHADO 1 (critico). `SID`/`STAMP` eram resolvidos DEPOIS da validacao de N,
        # e tres `goto :abre` puravam esse bloco -- inclusive `N<=0`, que e o valor
        # que o teste "porta 0 nunca dorme" usa e aprova. Em `:abre` o `>"%STAMP%"`
        # com STAMP vazio vira `>""`: redirecionamento invalido, e o cmd.exe cospe
        # "O sistema nao pode encontrar o caminho especificado." em TODA tool call,
        # SEM prefixo [percus:] -- indistinguivel de problema do sistema. O `2>nul`
        # nao cobre: ele suprime o stderr do `echo`, nao o do parser de redirecao.
        #
        # O teste irmao afirma PRESENCA de "checks rodados"; este afirma AUSENCIA de
        # lixo. Sem o par, a otimizacao inteira degradava em silencio.
        $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId)) `
                                 -Env @{ PERCUS_POST_PORTA_SEGUNDOS = '0'; CLAUDE_CODE_SESSION_ID = (New-SessaoId) }
        $r.ExitCode | Should -Be 0
        $r.Stderr | Should -Not -Match 'sistema n|system cannot|caminho especificado' `
            -Because "erro nativo sem assinatura [percus:] em toda tool call"
    }

    It 'porta com zero a esquerda ("030") tambem nao suja o stderr' {
        # Mesmo mecanismo: `set /a` le "030" como OCTAL, o valor deixa de bater na
        # validacao e cai no mesmo `goto :abre`. Caso irmao apontado pelo review.
        $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId)) `
                                 -Env @{ PERCUS_POST_PORTA_SEGUNDOS = '030'; CLAUDE_CODE_SESSION_ID = (New-SessaoId) }
        $r.ExitCode | Should -Be 0
        $r.Stderr | Should -Not -Match 'sistema n|system cannot|caminho especificado'
    }

    It 'SEM CLAUDE_CODE_SESSION_ID a porta fica DESLIGADA, nao compartilhada' {
        # ACHADO 4 (alto). A versao anterior caia num balde fixo ("sem-sessao") e o
        # review provou, com dois processos reais, que a segunda sessao tinha o guard
        # SILENCIADO pela porta que a primeira abriu -- perda de medicao de uma sessao
        # inteira, calada. Sem chave de sessao nao ha porta: paga-se o custo antigo.
        #
        # Nenhum outro It deste arquivo exercita esse ramo -- todos definem a variavel.
        $e = @{ PERCUS_DISPATCH_DEBUG = '1'; PERCUS_POST_PORTA_SEGUNDOS = '3600'
                CLAUDE_CODE_SESSION_ID = '' }
        $r1 = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao 'a') -Env $e
        $r2 = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao 'b') -Env $e

        $r1.Stderr | Should -Match 'checks rodados'
        $r2.Stderr | Should -Match 'checks rodados' `
            -Because "sem chave de sessao, uma chamada nao pode calar a seguinte"
    }

    It 'DOIS checks emitindo texto cru nao colam stdout invalido' {
        # ACHADO 3 (alto). O repasse verbatim decidia por CONTAGEM AGREGADA
        # ("nenhum JSON apareceu"), nao por emissor unico. Com dois checks crus o
        # stdout saia com as mensagens coladas, `ConvertFrom-Json` falhava e o harness
        # descartava AS DUAS -- a falha exata que a fusao existe pra impedir, entrando
        # pelo ramo nao-JSON. Nenhum teste registrava um segundo check, entao o
        # cenario que a fusao foi desenhada pra cobrir nunca era exercitado.
        $manifestoOriginal = [IO.File]::ReadAllText($script:manifest)
        $criados = @()
        try {
            foreach ($n in 'check-alfa-teste', 'check-beta-teste') {
                $p = Join-Path $script:hooksDir "$n.ps1"
                [IO.File]::WriteAllText($p, @"
# check sintetico do teste de fusao -- emite TEXTO PURO, nao JSON.
# Precisa passar dos 200 bytes do tripwire de integridade da camada 2, por isso
# este comentario existe e e comprido de proposito.
`$null = [Console]::In.ReadToEnd()
Write-Output '${n}: aviso em texto puro'
exit 0
"@, (New-Object Text.UTF8Encoding($false)))
                $criados += $p
            }
            $m = $manifestoOriginal | ConvertFrom-Json
            foreach ($n in 'check-alfa-teste', 'check-beta-teste') {
                $m.hooks += [pscustomobject]@{
                    nome = $n; evento = 'PostToolUse'; matcher = ''; forma = 'observador'
                    assinatura = "[percus:$n]"; escape = $null; registrado = $true
                    registro = 'percus-dispatch-post'; alvo = 'transcript'
                }
            }
            [IO.File]::WriteAllText($script:manifest, ($m | ConvertTo-Json -Depth 8),
                                    (New-Object Text.UTF8Encoding($false)))

            $r = Invoke-DispatchPost -Payload (New-PayloadPost -Sessao (New-SessaoId)) `
                                     -Env @{ PERCUS_CTX_WINDOW = '100000000'; CLAUDE_CODE_SESSION_ID = (New-SessaoId) }

            $r.Stdout | Should -Not -BeNullOrEmpty -Because 'os dois checks falaram; nada pode sumir'
            { $r.Stdout | ConvertFrom-Json } | Should -Not -Throw `
                -Because 'stdout colado nao parseia e o harness descarta OS DOIS calado'
            $ctx = ($r.Stdout | ConvertFrom-Json).hookSpecificOutput.additionalContext
            $ctx | Should -Match 'check-alfa-teste'
            $ctx | Should -Match 'check-beta-teste' -Because 'embrulhar nao pode virar descartar'
        } finally {
            [IO.File]::WriteAllText($script:manifest, $manifestoOriginal,
                                    (New-Object Text.UTF8Encoding($false)))
            foreach ($p in $criados) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
        }
    }
}
