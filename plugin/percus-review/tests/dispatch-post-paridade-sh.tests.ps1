# Paridade .ps1/.sh do dispatcher PostToolUse -- criterio de pronto 4 da spec
# docs/superpowers/specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md.
# Molde em _dispatch-paridade.ps1 e no cabecalho de dispatch-pre-paridade-sh.tests.ps1.
#
# O QUE MUDA EM RELACAO AO `pre`: stdout e o canal do produto (fusao de saidas), a triagem e uma
# porta por tempo POR SESSAO, e depois de ler stdin nao existe fallback.
#
# O QUE CADA PECA DO FIXTURE TORNA VISIVEL:
#   jsonum emite JSON com campo extra ...... a fusao reembrulha: so hookSpecificOutput/systemMessage sobrevivem
#   dois checks crus ....................... repasse verbatim e por EMISSOR UNICO, nao por "nenhum JSON"
#   vazio (additionalContext "") ........... "" e falso no -and do PowerShell; o // do jq NAO filtra ""
#   escalar ("123") ........................ JSON valido que nao e objeto: nao e cru, e nao tem contexto
#   evento 'posttooluse' ................... -eq do PowerShell ignora caixa
#   payload invalido de 256 bytes .......... 0,25 KB: [Math]::Round bancario da 0,2 (medido); meio-pra-cima daria 0,3
#   porta "030" e BOM no porta-post.txt .... octal do set /a e lixo no arquivo: fail-open, nunca porta calada

BeforeAll {
    . (Join-Path $PSScriptRoot '_dispatch-paridade.ps1')

    function New-PayloadPost {
        param([string]$Tool = 'Read', [string]$Resposta = 'ok', [string]$Sessao = 'sess-par')
        @{ session_id = $Sessao; transcript_path = 'C:\nao\existe.jsonl'; cwd = 'C:\pasta-neutra'
           tool_name = $Tool; tool_input = @{ file_path = 'x.txt' }; tool_response = $Resposta } |
            ConvertTo-Json -Compress -Depth 5
    }

    # Com o runId: e por ele que o AfterAll apaga SO os carimbos de porta deste arquivo.
    function New-SidPar { "par-$($script:runId)-" + [Guid]::NewGuid().ToString('N').Substring(0, 12) }

    function New-FixturePost {
        # Catalogo de checks por nome; 'fantasma' = registrado sem arquivo, 'curto' = truncado.
        param([string[]]$Checks, [string]$Evento = 'PostToolUse', [string]$Porta = '30')
        $d = New-Fixture -Evento post -Porta $Porta -Hooks @($Checks | ForEach-Object {
            New-Entrada -Nome $_ -Evento $Evento -Matcher '' -Registro 'percus-dispatch-post' })
        foreach ($n in $Checks) {
            switch ($n) {
                'jsonum'  { New-CheckPar -Dir $d -Nome $n -Emite '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"ctx-um tool={TOOL}"},"systemMessage":"sys-um","extra":1}' }
                'crualfa' { New-CheckPar -Dir $d -Nome $n -Emite 'crualfa: texto puro de {TOOL}' }
                'crubeta' { New-CheckPar -Dir $d -Nome $n -Emite 'crubeta: outro texto puro' }
                'mudo'    { New-CheckPar -Dir $d -Nome $n }
                'vazio'   { New-CheckPar -Dir $d -Nome $n -Emite '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":""}}' }
                'escalar' { New-CheckPar -Dir $d -Nome $n -Emite '123' }
                'sistema' { New-CheckPar -Dir $d -Nome $n -Emite '{"systemMessage":"so-sistema"}' }
                'curto'   { New-CheckPar -Dir $d -Nome $n -Truncado }
                'fantasma' { }
                default   { throw "check desconhecido no catalogo: $n" }
            }
        }
        return $d
    }

    # Porta ABERTA por padrao: sessao nova em cada runtime, em cada chamada.
    function Invoke-ParPost {
        param([string]$Dir, [string]$Payload, [hashtable]$Env = @{}, [switch]$StdoutJson)
        $ec = $Env.Clone(); if (-not $ec.ContainsKey('CLAUDE_CODE_SESSION_ID')) { $ec.CLAUDE_CODE_SESSION_ID = New-SidPar }
        $es = $Env.Clone(); if (-not $es.ContainsKey('CLAUDE_CODE_SESSION_ID')) { $es.CLAUDE_CODE_SESSION_ID = New-SidPar }
        $c = Invoke-Runtime -Runtime cmd -Evento post -Dir $Dir -Payload $Payload -Env $ec
        $s = Invoke-Runtime -Runtime sh -Evento post -Dir $Dir -Payload $Payload -Env $es
        Assert-Paridade -Cmd $c -Sh $s -StdoutJson:$StdoutJson
        return [pscustomobject]@{ Cmd = $c; Sh = $s }
    }

    # Duas chamadas seguidas na MESMA sessao, por runtime (cada runtime com a sua sessao).
    # Devolve a SEGUNDA chamada de cada lado, depois de exigir paridade nas duas.
    function Invoke-DuasVezes {
        param([string]$Dir, [hashtable]$Env = @{})
        $lados = @{}
        foreach ($rt in 'cmd', 'sh') {
            $e = $Env.Clone()
            if (-not $e.ContainsKey('CLAUDE_CODE_SESSION_ID')) { $e.CLAUDE_CODE_SESSION_ID = New-SidPar }
            $e.PERCUS_DISPATCH_DEBUG = '1'
            $p = New-PayloadPost
            $lados[$rt] = @(
                (Invoke-Runtime -Runtime $rt -Evento post -Dir $Dir -Payload $p -Env $e),
                (Invoke-Runtime -Runtime $rt -Evento post -Dir $Dir -Payload $p -Env $e)
            )
        }
        Assert-Paridade -Cmd $lados.cmd[0] -Sh $lados.sh[0] -StdoutJson
        Assert-Paridade -Cmd $lados.cmd[1] -Sh $lados.sh[1] -StdoutJson
        return [pscustomobject]@{ Primeira = $lados.cmd[0]; Segunda = $lados.cmd[1] }
    }

    $script:avisoLegado = '[percus:dispatch-post] AVISO: wrapper de fallback ausente: context-budget-guard.<ext> -- este check NAO rodou.'
    $script:ctxUm = '{"hookSpecificOutput":{"additionalContext":"ctx-um tool=Read","hookEventName":"PostToolUse"},"systemMessage":"sys-um"}'
}

AfterAll { Remove-FixturesParidade }

Describe 'paridade .sh do dispatcher PostToolUse -- pre-condicoes' {

    It 'o .sh existe ao lado do .cmd e do .ps1' {
        Test-Path (Join-Path $script:kitHooks 'percus-dispatch-post.sh') | Should -BeTrue
    }

    It 'ha bash nesta maquina -- VERMELHO, nao Skipped' {
        $script:bash | Should -Not -BeNullOrEmpty
    }

    It 'o .cmd roda na codepage OEM, a do cmd.exe dos hooks -- nao na herdada do pwsh' {
        # A porta le porta-post.txt com `set /p`, e com BOM o resultado DEPENDE da codepage (medido).
        $script:oemcp | Should -Not -BeNullOrEmpty -Because 'sem a OEM do registro nao ha contra o que conferir'
        Get-CodepageDoCmdDeTeste | Should -Be $script:oemcp
    }
}

Describe 'paridade .sh do dispatcher PostToolUse -- o aviso tem de chegar igual' {

    It 'um check JSON: reembrulhado igual (campo extra cai, hookEventName fixo)' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'jsonum') -Payload (New-PayloadPost) -StdoutJson
        $r.Cmd.ExitCode | Should -Be 0
        (ConvertTo-JsonCanonico $r.Cmd.Stdout) | Should -BeExactly $script:ctxUm
    }

    It 'um check CRU: repassado verbatim, byte a byte' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'crualfa') -Payload (New-PayloadPost)
        $r.Cmd.Stdout | Should -BeExactly 'crualfa: texto puro de Read'
    }

    It 'dois crus: fundidos num JSON so, cada um nomeado, e o stderr avisa' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'crualfa', 'crubeta') -Payload (New-PayloadPost) -StdoutJson
        (ConvertTo-JsonCanonico $r.Cmd.Stdout) | Should -BeExactly ('{"hookSpecificOutput":{"additionalContext":"[crualfa] crualfa: texto puro de Read\n[crubeta] crubeta: outro texto puro","hookEventName":"PostToolUse"}}')
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly (@(
            "[percus:dispatch-post] saida nao-JSON de 'crualfa' embrulhada na fusao (stdout compartilhado com outro check)."
            "[percus:dispatch-post] saida nao-JSON de 'crubeta' embrulhada na fusao (stdout compartilhado com outro check)."
        ) -join "`n")
    }

    It 'cru antes de JSON no manifesto: o contexto JSON vem primeiro, o cru entra nomeado depois' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'crualfa', 'jsonum') -Payload (New-PayloadPost) -StdoutJson
        (ConvertTo-JsonCanonico $r.Cmd.Stdout) | Should -BeExactly ('{"hookSpecificOutput":{"additionalContext":"ctx-um tool=Read\n[crualfa] crualfa: texto puro de Read","hookEventName":"PostToolUse"},"systemMessage":"sys-um"}')
    }

    It 'systemMessage de dois emissores: juntadas com espaco, na ordem do manifesto' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'sistema', 'jsonum') -Payload (New-PayloadPost) -StdoutJson
        (ConvertTo-JsonCanonico $r.Cmd.Stdout) | Should -BeExactly ('{"hookSpecificOutput":{"additionalContext":"ctx-um tool=Read","hookEventName":"PostToolUse"},"systemMessage":"so-sistema sys-um"}')
    }

    It 'check mudo: stdout vazio, nada inventado' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'mudo') -Payload (New-PayloadPost)
        $r.Cmd.ExitCode | Should -Be 0
        $r.Cmd.Stdout | Should -BeNullOrEmpty
        $r.Cmd.Stderr | Should -BeNullOrEmpty
    }

    It 'contexto vazio e JSON escalar: nao sao texto cru e nao tem o que dizer -- stdout vazio' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'vazio', 'escalar') -Payload (New-PayloadPost)
        $r.Cmd.Stdout | Should -BeNullOrEmpty
        $r.Cmd.Stderr | Should -BeNullOrEmpty
    }

    It 'evento em caixa baixa entra na cadeia (-eq ignora caixa)' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'jsonum' -Evento 'posttooluse') -Payload (New-PayloadPost) -StdoutJson
        (ConvertTo-JsonCanonico $r.Cmd.Stdout) | Should -BeExactly $script:ctxUm
    }

    It 'payload maior que 80 KB: o aviso sai igual' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'jsonum') -Payload (New-PayloadPost -Resposta ('x' * 300000)) -StdoutJson
        (ConvertTo-JsonCanonico $r.Cmd.Stdout) | Should -BeExactly $script:ctxUm
    }
}

Describe 'paridade .sh do dispatcher PostToolUse -- falhas' {

    It 'payload que nao parseia (256 bytes): fala alto com o MESMO arredondamento, sai 0' {
        $pre = '{"tool_input":{"command":"x '
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'jsonum') -Payload ($pre + ('a' * (256 - $pre.Length))) -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        $r.Cmd.Stdout | Should -BeNullOrEmpty
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly '[percus:dispatch-post] payload nao parseia como JSON (0.2 KB) -- nenhum check rodou.'
    }

    It 'stdin vazio: sai 0 calado' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'jsonum') -Payload '' -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        $r.Cmd.Stdout | Should -BeNullOrEmpty
        $r.Cmd.Stderr | Should -BeNullOrEmpty
    }

    It 'check AUSENTE com outro rodavel: denuncia, entrega o aviso do outro e sai 2' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'fantasma', 'jsonum') -Payload (New-PayloadPost) -StdoutJson
        $r.Cmd.ExitCode | Should -Be 2
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly '[percus:dispatch-post] check registrado mas AUSENTE do disco: fantasma.<ext>'
        (ConvertTo-JsonCanonico $r.Cmd.Stdout) | Should -BeExactly $script:ctxUm
    }

    It 'check TRUNCADO com outro rodavel: denuncia e sai 2' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'curto', 'jsonum') -Payload (New-PayloadPost) -StdoutJson
        $r.Cmd.ExitCode | Should -Be 2
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly "[percus:dispatch-post] check 'curto' esta TRUNCADO em disco (< 200 bytes) -- instalacao corrompida."
    }

    It 'TODOS ausentes: cadeia antiga, decidido antes de tocar stdin' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'fantasma') -Payload (New-PayloadPost)
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly (@(
            '[percus:dispatch-post] check registrado mas AUSENTE do disco: fantasma.<ext>'
            $script:avisoLegado
        ) -join "`n")
    }

    It 'manifesto ilegivel: cadeia antiga' {
        $d = New-Fixture -Evento post -ManifestoCru '{ isto nao e json'
        $r = Invoke-ParPost -Dir $d -Payload (New-PayloadPost)
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly (@('[percus:dispatch-post] hooks-manifest.json ilegivel:', $script:avisoLegado) -join "`n")
    }

    It 'manifesto sem check de PostToolUse: avisa e cai na cadeia antiga' {
        $d = New-Fixture -Evento post -Hooks @((New-Entrada -Nome alfa -Gatilhos 'zeta'))
        $r = Invoke-ParPost -Dir $d -Payload (New-PayloadPost)
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly (@('[percus:dispatch-post] nenhum check de PostToolUse registrado no manifesto.', $script:avisoLegado) -join "`n")
    }
}

Describe 'paridade .sh do dispatcher PostToolUse -- escapes e porta' {

    It 'PERCUS_HOOKS_DISABLED=1 sai 0 antes de qualquer trabalho' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'jsonum') -Payload (New-PayloadPost) -Env @{ PERCUS_HOOKS_DISABLED = '1'; PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        $r.Cmd.Stdout | Should -BeNullOrEmpty
        $r.Cmd.Stderr | Should -BeNullOrEmpty
    }

    It 'PERCUS_DISPATCHER_BYPASS=1: cadeia antiga com a MESMA lista' {
        $r = Invoke-ParPost -Dir (New-FixturePost -Checks 'jsonum') -Payload (New-PayloadPost) -Env @{ PERCUS_DISPATCHER_BYPASS = '1'; PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly $script:avisoLegado
    }

    It 'segunda chamada da MESMA sessao dentro da janela DORME' {
        $r = Invoke-DuasVezes -Dir (New-FixturePost -Checks 'jsonum') -Env @{ PERCUS_POST_PORTA_SEGUNDOS = '3600' }
        $r.Primeira.Stderr | Should -Match 'checks rodados: 1 de 1'
        $r.Segunda.Stderr | Should -BeNullOrEmpty
        $r.Segunda.Stdout | Should -BeNullOrEmpty
    }

    It 'porta de 0 segundos nunca dorme' {
        $r = Invoke-DuasVezes -Dir (New-FixturePost -Checks 'jsonum') -Env @{ PERCUS_POST_PORTA_SEGUNDOS = '0' }
        $r.Segunda.Stderr | Should -Match 'checks rodados: 1 de 1'
    }

    It 'porta "030" (octal no set /a): fail-open, e sem lixo no stderr' {
        $r = Invoke-DuasVezes -Dir (New-FixturePost -Checks 'jsonum') -Env @{ PERCUS_POST_PORTA_SEGUNDOS = '030' }
        (Format-Stderr $r.Segunda.Stderr) | Should -BeExactly '[percus:dispatch-post] checks rodados: 1 de 1'
    }

    It 'porta-post.txt com BOM: fail-open, nunca porta calada' {
        # Vale na codepage OEM, a do harness: ali o `set /p` le o BOM como lixo. Em 65001 o mesmo
        # arquivo seria lido valido (medido) -- por isso o Invoke-Runtime fixa a OEM no .cmd.
        $d = New-FixturePost -Checks 'jsonum'
        [IO.File]::WriteAllText((Join-Path $d 'porta-post.txt'), "3600`n", (New-Object Text.UTF8Encoding($true)))
        $r = Invoke-DuasVezes -Dir $d
        $r.Segunda.Stderr | Should -Match 'checks rodados: 1 de 1'
    }

    It 'porta-post.txt com valor valido e sem env: a janela do ARQUIVO vale' {
        # O par do teste acima: sem ele, "BOM abre a porta" passaria num .sh que ignora o arquivo.
        $r = Invoke-DuasVezes -Dir (New-FixturePost -Checks 'jsonum' -Porta '3600')
        $r.Segunda.Stderr | Should -BeNullOrEmpty
    }

    It 'porta-post.txt ausente: nao ha porta' {
        $r = Invoke-DuasVezes -Dir (New-FixturePost -Checks 'jsonum' -Porta '')
        $r.Segunda.Stderr | Should -Match 'checks rodados: 1 de 1'
    }

    It 'sem CLAUDE_CODE_SESSION_ID nao ha porta (balde compartilhado calaria outra sessao)' {
        $r = Invoke-DuasVezes -Dir (New-FixturePost -Checks 'jsonum') -Env @{ PERCUS_POST_PORTA_SEGUNDOS = '3600'; CLAUDE_CODE_SESSION_ID = '' }
        $r.Segunda.Stderr | Should -Match 'checks rodados: 1 de 1'
    }

    It 'sessoes diferentes tem portas independentes' {
        $d = New-FixturePost -Checks 'jsonum'
        foreach ($rt in 'cmd', 'sh') {
            $base = @{ PERCUS_POST_PORTA_SEGUNDOS = '3600'; PERCUS_DISPATCH_DEBUG = '1' }
            $a = $base.Clone(); $a.CLAUDE_CODE_SESSION_ID = New-SidPar
            $b = $base.Clone(); $b.CLAUDE_CODE_SESSION_ID = New-SidPar
            $null = Invoke-Runtime -Runtime $rt -Evento post -Dir $d -Payload (New-PayloadPost) -Env $a
            $rb = Invoke-Runtime -Runtime $rt -Evento post -Dir $d -Payload (New-PayloadPost) -Env $b
            $rb.Stderr | Should -Match 'checks rodados: 1 de 1' -Because "no $rt a porta da sessao A nao pode calar a B"
        }
    }
}

Describe 'paridade .sh do dispatcher PostToolUse -- contra o context-budget-guard REAL' {

    It '190k tokens numa janela de 200k: o aviso ao agente sai IDENTICO pelos dois' {
        $raiz = Join-Path $script:raizTmp ('guard-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $raiz | Out-Null
        $t = Join-Path $raiz 'sessao.jsonl'
        [IO.File]::WriteAllText($t, '{"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":190000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}' + "`n", $script:utf8)
        $ctx = @{}
        foreach ($rt in 'cmd', 'sh') {
            # session_id proprio por runtime: o guard faz debounce por sessao no cwd.
            $p = @{ session_id = "guard-$rt-" + [Guid]::NewGuid().ToString('N').Substring(0, 6); transcript_path = $t
                    cwd = $raiz; tool_name = 'Read'; tool_input = @{ file_path = 'x' }; tool_response = 'ok' } | ConvertTo-Json -Compress -Depth 5
            $r = Invoke-Runtime -Runtime $rt -Evento post -Dir $script:kitHooks -Payload $p `
                                -Env @{ PERCUS_CTX_WINDOW = '200000'; CLAUDE_CODE_SESSION_ID = (New-SidPar) }
            $r.ExitCode | Should -Be 0 -Because "stderr do ${rt}: $($r.Stderr)"
            $ctx[$rt] = ($r.Stdout | ConvertFrom-Json).hookSpecificOutput.additionalContext
        }
        $ctx.cmd | Should -Match 'context-budget'
        $ctx.sh | Should -BeExactly $ctx.cmd
    }
}

Describe 'paridade .sh do dispatcher PostToolUse -- achados do R11 Cross-Claude' {

    It 'registrado 0, "" e [] ficam FORA da cadeia (falsos no PowerShell, verdadeiros no jq)' {
        $d = New-Fixture -Evento post -Hooks @(
            (New-Entrada -Nome jsonum -Evento 'PostToolUse' -Matcher '' -Registro 'percus-dispatch-post'),
            (New-Entrada -Nome crualfa -Evento 'PostToolUse' -Matcher '' -Registro 'percus-dispatch-post' -RegistradoCru 0),
            (New-Entrada -Nome crubeta -Evento 'PostToolUse' -Matcher '' -Registro 'percus-dispatch-post' -RegistradoCru ''),
            (New-Entrada -Nome sistema -Evento 'PostToolUse' -Matcher '' -Registro 'percus-dispatch-post' -RegistradoCru @())
        )
        New-CheckPar -Dir $d -Nome jsonum -Emite '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"ctx-um tool={TOOL}"},"systemMessage":"sys-um","extra":1}'
        New-CheckPar -Dir $d -Nome crualfa -Emite 'crualfa: NAO devia rodar'
        New-CheckPar -Dir $d -Nome crubeta -Emite 'crubeta: NAO devia rodar'
        New-CheckPar -Dir $d -Nome sistema -Emite '{"systemMessage":"sistema NAO devia rodar"}'

        $r = Invoke-ParPost -Dir $d -Payload (New-PayloadPost) -StdoutJson -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        (ConvertTo-JsonCanonico $r.Cmd.Stdout) | Should -BeExactly $script:ctxUm
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly '[percus:dispatch-post] checks rodados: 1 de 1'
    }

    It 'additionalContext em array de 1 elemento falso nao vira contexto -- o PowerShell recursa no elemento' {
        # [""] e FALSO no PowerShell e verdadeiro num `!= []` do jq. Achado da 2a rodada do R11
        # Cross-Claude, na funcao `verdade` da fusao.
        $d = New-Fixture -Evento post -Hooks @(
            (New-Entrada -Nome ctxarray -Evento 'PostToolUse' -Matcher '' -Registro 'percus-dispatch-post'))
        New-CheckPar -Dir $d -Nome ctxarray -Emite '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":[""]},"systemMessage":"so-sistema"}'
        $r = Invoke-ParPost -Dir $d -Payload (New-PayloadPost) -StdoutJson
        (ConvertTo-JsonCanonico $r.Cmd.Stdout) | Should -BeExactly '{"systemMessage":"so-sistema"}'
    }

    It 'porta de 10 digitos (ate 2147483647, o teto do set /a) fecha a porta nos dois' {
        $r = Invoke-DuasVezes -Dir (New-FixturePost -Checks 'jsonum') -Env @{ PERCUS_POST_PORTA_SEGUNDOS = '1500000000' }
        $r.Primeira.Stderr | Should -Match 'checks rodados: 1 de 1'
        $r.Segunda.Stderr | Should -BeNullOrEmpty -Because 'o set /a aceita 1500000000, entao o .cmd fecha a porta'
    }

    It 'porta acima de 2147483647 estoura o set /a: fail-open nos dois (o par do teste acima)' {
        # Sem este, "aceita 10 digitos" passaria num .sh que aceitasse qualquer tamanho.
        $r = Invoke-DuasVezes -Dir (New-FixturePost -Checks 'jsonum') -Env @{ PERCUS_POST_PORTA_SEGUNDOS = '2147483648' }
        $r.Segunda.Stderr | Should -Match 'checks rodados: 1 de 1'
    }
}

Describe 'dispatcher PostToolUse .sh -- o que so existe no bash' {

    It 'sem jq: avisa e cai na cadeia antiga antes de tocar stdin' {
        $sj = Get-EnvSemJq
        (Invoke-BashComando -Bash $sj.Bash -Env $sj.Env -Comando 'command -v jq || echo SEM-JQ') |
            Should -Match 'SEM-JQ' -Because 'pre-condicao: com o jq visivel o cenario seguiria o caminho normal'
        $e = $sj.Env.Clone(); $e.CLAUDE_CODE_SESSION_ID = New-SidPar
        $s = Invoke-Runtime -Runtime sh -Evento post -Dir (New-FixturePost -Checks 'jsonum') -Payload (New-PayloadPost) `
                            -Env $e -Bash $sj.Bash
        $s.ExitCode | Should -Be 0
        (Format-Stderr $s.Stderr) | Should -BeExactly (@(
            '[percus:dispatch-post] jq ausente -- sem ele nao ha como ler o manifesto; rodando a cadeia antiga.'
            $script:avisoLegado
        ) -join "`n")
    }
}
