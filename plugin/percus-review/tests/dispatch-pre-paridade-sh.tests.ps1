# Paridade .ps1/.sh do dispatcher PreToolUse -- criterio de pronto 4 da spec
# docs/superpowers/specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md.
#
# Cada cenario roda o .cmd real E o .sh contra o MESMO payload e exige exit code, stderr e stdout
# iguais (molde e razoes em _dispatch-paridade.ps1). Alem da igualdade, cada cenario afirma o
# valor ESPERADO do lado Windows: sem isso, os dois runtimes quebrando do mesmo jeito (fixture
# errado, bash devolvendo 127 dos dois lados) passariam como "paridade".
#
# O QUE CADA PECA DO FIXTURE TORNA VISIVEL (verbete paridade-testada-no-caso-facil-nao-e-paridade):
#   gatilhos-pre.txt em CRLF ............ grep -f do bash com o \r colado nunca casa
#   'ZETA' no comando ................... findstr /I x grep sem -i
#   beta declara 'ZeTa' ................. IndexOf OrdinalIgnoreCase x comparacao exata
#   delta declara ['omega', ''] ......... gatilho vazio: o .ps1 filtra; "*$g*" no bash casaria tudo
#   gama sem gatilhos ................... "sem gatilho = roda sempre", o default seguro
#   kapa com evento 'pretooluse' ........ -eq do PowerShell ignora caixa; == do jq nao
#   lambda com registro 'Percus-...' .... -ceq diferencia caixa: fica fora
#   epsilon/eta/teta/iota ............... registro, matcher, registrado e evento errados: fora
#   gatilho so no cwd ................... camada 1 casa o JSON inteiro, camada 2 so o comando
#   beta sai 2 e os outros seguem ....... agregacao sem curto-circuito
#
# ATENCAO: nenhum comando deste arquivo pode ter `git`+`commit` literal -- o pre-commit-check casa
# por texto e barraria a propria suite. Monte em runtime ($tokCommit).

BeforeAll {
    . (Join-Path $PSScriptRoot '_dispatch-paridade.ps1')
    $script:tokCommit = 'com' + 'mit'
    $script:legado = @('pre-commit-check', 'mock-scan-pre-commit', 'auth-import-pre-commit',
                       'migration-check-pre-commit', 'types-check-pre-commit', 'external-action-guard',
                       'crud-evidence-warn', 'spec-analyze-check')
    $script:avisosLegado = @($script:legado | ForEach-Object {
        "[percus:dispatch-pre] AVISO: wrapper de fallback ausente: $_.<ext> -- este check NAO rodou." })

    function New-PayloadPre {
        param([string]$Comando = 'echo ola', [string]$Cwd = 'C:\pasta-neutra', [switch]$SemComando)
        $ti = if ($SemComando) { @{ file_path = 'x.txt' } } else { @{ command = $Comando } }
        @{ tool_name = 'Bash'; tool_input = $ti; cwd = $Cwd } | ConvertTo-Json -Compress -Depth 5
    }

    function Invoke-ParPre {
        param([string]$Dir, [string]$Payload, [hashtable]$Env = @{})
        $c = Invoke-Runtime -Runtime cmd -Evento pre -Dir $Dir -Payload $Payload -Env $Env
        $s = Invoke-Runtime -Runtime sh -Evento pre -Dir $Dir -Payload $Payload -Env $Env
        Assert-Paridade -Cmd $c -Sh $s
        return [pscustomobject]@{ Cmd = $c; Sh = $s }
    }

    $script:fxPrincipal = New-Fixture -Evento pre -Hooks @(
        (New-Entrada -Nome alfa -Gatilhos 'zeta'),
        (New-Entrada -Nome beta -Gatilhos 'ZeTa'),
        (New-Entrada -Nome gama),
        (New-Entrada -Nome delta -Gatilhos @('omega', '')),
        (New-Entrada -Nome epsilon -Gatilhos 'zeta' -Registro 'hooks.json'),
        (New-Entrada -Nome eta -Gatilhos 'zeta' -Matcher 'Edit|Write'),
        (New-Entrada -Nome teta -Gatilhos 'zeta' -Registrado $false),
        (New-Entrada -Nome iota -Gatilhos 'zeta' -Evento 'PostToolUse'),
        (New-Entrada -Nome kapa -Gatilhos 'zeta' -Evento 'pretooluse'),
        (New-Entrada -Nome lambda -Gatilhos 'zeta' -Registro 'Percus-Dispatch-Pre')
    )
    New-CheckPar -Dir $script:fxPrincipal -Nome alfa -Ve
    New-CheckPar -Dir $script:fxPrincipal -Nome beta -Rc 2 -Fala 'beta bloqueou'
    New-CheckPar -Dir $script:fxPrincipal -Nome gama
    New-CheckPar -Dir $script:fxPrincipal -Nome delta -Fala 'delta falou'
    New-CheckPar -Dir $script:fxPrincipal -Nome kapa -Fala 'kapa rodou'
    foreach ($n in 'epsilon', 'eta', 'teta', 'iota', 'lambda') {
        New-CheckPar -Dir $script:fxPrincipal -Nome $n -Rc 2 -Fala "$n NAO devia rodar"
    }

    $script:fxIntegridade = New-Fixture -Evento pre -Hooks @(
        (New-Entrada -Nome fantasma -Gatilhos 'zeta'),
        (New-Entrada -Nome curto -Gatilhos 'zeta'),
        (New-Entrada -Nome alfa -Gatilhos 'zeta')
    )
    New-CheckPar -Dir $script:fxIntegridade -Nome curto -Truncado
    New-CheckPar -Dir $script:fxIntegridade -Nome alfa -Ve
}

AfterAll { Remove-FixturesParidade }

Describe 'paridade .sh do dispatcher PreToolUse -- pre-condicoes' {

    It 'o .sh existe ao lado do .cmd e do .ps1' {
        Test-Path (Join-Path $script:kitHooks 'percus-dispatch-pre.sh') | Should -BeTrue
    }

    It 'ha bash nesta maquina -- VERMELHO, nao Skipped: paridade que nao rodou nao pode sair verde' {
        $script:bash | Should -Not -BeNullOrEmpty
    }

    It 'o .cmd roda na codepage OEM, a do cmd.exe dos hooks -- nao na herdada do pwsh' {
        $script:oemcp | Should -Not -BeNullOrEmpty -Because 'sem a OEM do registro nao ha contra o que conferir'
        Get-CodepageDoCmdDeTeste | Should -Be $script:oemcp
    }
}

Describe 'paridade .sh do dispatcher PreToolUse -- triagem e selecao' {

    It 'comando sem gatilho: os dois saem 0 calados, sem subir a camada 2' {
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload (New-PayloadPre -Comando 'echo ola') -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        $r.Cmd.Stderr | Should -BeNullOrEmpty
    }

    It 'gatilho em MAIUSCULA, gatilhos-pre.txt em CRLF: mesmos checks, mesma ordem, sem curto-circuito' {
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload (New-PayloadPre -Comando 'ZETA agora') -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 2
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly (@(
            'alfa viu: ZETA agora'
            'beta bloqueou'
            'kapa rodou'
            '[percus:dispatch-pre] checks rodados: 4 de 5 | veredito: 2'
        ) -join "`n")
    }

    It 'gatilho vazio no manifesto nao casa tudo: so omega sobe o delta' {
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload (New-PayloadPre -Comando 'omega agora') -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly (@(
            'delta falou'
            '[percus:dispatch-pre] checks rodados: 2 de 5 | veredito: 0'
        ) -join "`n")
    }

    It 'gatilho so no cwd acorda a triagem, mas a camada 2 decide pelo comando' {
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload (New-PayloadPre -Comando 'echo ola' -Cwd 'C:\zeta-pasta') -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly '[percus:dispatch-pre] checks rodados: 1 de 5 | veredito: 0'
    }

    It 'payload sem tool_input.command sai 0 calado, mesmo com gatilho no JSON' {
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload (New-PayloadPre -SemComando -Cwd 'C:\zeta-pasta') -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        $r.Cmd.Stderr | Should -BeNullOrEmpty
    }

    It 'stdin vazio sai 0 calado' {
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload '' -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        $r.Cmd.Stderr | Should -BeNullOrEmpty
    }
}

Describe 'paridade .sh do dispatcher PreToolUse -- falha alta' {

    It 'payload que nao parseia BLOQUEIA assinado, com o mesmo tamanho reportado' {
        # 300 bytes, e nao o empate de 256: a captura do .cmd (findstr "^") acrescenta CRLF, entao
        # o .ps1 ve 302. 300 e 302 arredondam igual (0,3). O empate do arredondamento bancario e
        # provado no dispatcher post, onde nao ha captura.
        $pre = '{"tool_input":{"command":"zeta '
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload ($pre + ('a' * (300 - $pre.Length)))
        $r.Cmd.ExitCode | Should -Be 2
        $r.Cmd.Stderr | Should -Match '\[percus:dispatch-pre\] BLOCK: payload nao parseia como JSON \(0\.3 KB\)\.'
        foreach ($lado in $r.Cmd, $r.Sh) {
            $lado.Stderr | Should -Match 'Causa provavel:' -Because "o $($lado.Runtime) tem de dizer a causa (que difere de proposito)"
        }
    }

    It 'check AUSENTE e TRUNCADO: denunciados, bloqueiam, e o check sadio ainda roda' {
        $r = Invoke-ParPre -Dir $script:fxIntegridade -Payload (New-PayloadPre -Comando 'zeta x') -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 2
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly (@(
            '[percus:dispatch-pre] check registrado mas AUSENTE do disco: fantasma.<ext>'
            "[percus:dispatch-pre] check 'curto' esta TRUNCADO em disco (< 200 bytes) -- instalacao corrompida."
            'alfa viu: zeta x'
            '[percus:dispatch-pre] checks rodados: 1 de 3 | veredito: 2'
        ) -join "`n")
    }

    It 'AUSENTE e denunciado ANTES do gatilho; TRUNCADO so depois dele (a ordem do .ps1)' {
        $r = Invoke-ParPre -Dir $script:fxIntegridade -Payload (New-PayloadPre -Comando 'echo ola' -Cwd 'C:\zeta-pasta') -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 2
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly (@(
            '[percus:dispatch-pre] check registrado mas AUSENTE do disco: fantasma.<ext>'
            '[percus:dispatch-pre] checks rodados: 0 de 3 | veredito: 2'
        ) -join "`n")
    }

    It 'o tamanho do payload invalido segue o arredondamento BANCARIO do .ps1 (256 bytes -> 0.2)' {
        # So o .sh: do lado Windows a captura acrescenta bytes e o empate nao acontece (medido:
        # 256 bytes saem 0.3 KB pelo .cmd). O empate e comparado entre runtimes no dispatcher post.
        $pre = '{"tool_input":{"command":"zeta '
        $s = Invoke-Runtime -Runtime sh -Evento pre -Dir $script:fxPrincipal -Payload ($pre + ('a' * (256 - $pre.Length)))
        $s.ExitCode | Should -Be 2
        $s.Stderr | Should -Match '\(0\.2 KB\)'
    }
}

Describe 'paridade .sh do dispatcher PreToolUse -- escapes, fallback e trampolim' {

    It 'PERCUS_HOOKS_DISABLED=1 sai 0 antes de qualquer trabalho' {
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload (New-PayloadPre -Comando 'ZETA') -Env @{ PERCUS_HOOKS_DISABLED = '1'; PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        $r.Cmd.Stderr | Should -BeNullOrEmpty
    }

    It 'PERCUS_DISPATCHER_BYPASS=1: cadeia antiga com a MESMA lista, e wrapper ausente AVISA' {
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload (New-PayloadPre -Comando 'zeta') -Env @{ PERCUS_DISPATCHER_BYPASS = '1'; PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly ($script:avisosLegado -join "`n")
    }

    It 'manifesto ilegivel: avisa e cai na cadeia antiga' {
        $d = New-Fixture -Evento pre -ManifestoCru '{ isto nao e json'
        $r = Invoke-ParPre -Dir $d -Payload (New-PayloadPre -Comando 'zeta')
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly ((@('[percus:dispatch-pre] hooks-manifest.json ilegivel:') + $script:avisosLegado) -join "`n")
    }

    It 'manifesto sem check dispatchado: avisa e cai na cadeia antiga' {
        $d = New-Fixture -Evento pre -Hooks @((New-Entrada -Nome epsilon -Gatilhos 'zeta' -Registro 'hooks.json'))
        $r = Invoke-ParPre -Dir $d -Payload (New-PayloadPre -Comando 'zeta')
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly ((@('[percus:dispatch-pre] nenhum check registrado no manifesto.') + $script:avisosLegado) -join "`n")
    }

    It 'gatilhos-pre.txt ausente: cadeia antiga, sem triagem' {
        $d = New-Fixture -Evento pre -Hooks @((New-Entrada -Nome alfa -Gatilhos 'zeta')) -SemGatilhos
        New-CheckPar -Dir $d -Nome alfa -Ve
        $r = Invoke-ParPre -Dir $d -Payload (New-PayloadPre -Comando 'echo ola')
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly ($script:avisosLegado -join "`n")
    }

    It 'trampolim: PERCUS_CANON_DIR com o dispatcher dentro desvia manifesto e checks para o canon' {
        $fxCanon = New-Fixture -Evento pre -Hooks @((New-Entrada -Nome docanon -Gatilhos 'zeta'))
        New-CheckPar -Dir $fxCanon -Nome docanon -Fala 'rodou o do canon'
        $canon = Join-Path $script:raizTmp ('canon-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        $hk = Join-Path $canon 'plugin\percus-review\hooks'
        New-Item -ItemType Directory -Force -Path $hk | Out-Null
        Get-ChildItem -LiteralPath $fxCanon -File | Copy-Item -Destination $hk

        $fxLocal = New-Fixture -Evento pre -Hooks @((New-Entrada -Nome dolocal -Gatilhos 'zeta'))
        New-CheckPar -Dir $fxLocal -Nome dolocal -Fala 'rodou o local'

        $r = Invoke-ParPre -Dir $fxLocal -Payload (New-PayloadPre -Comando 'zeta') -Env @{ PERCUS_CANON_DIR = $canon }
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly 'rodou o do canon'
    }
}

Describe 'paridade .sh do dispatcher PreToolUse -- contra os checks REAIS do kit' {

    It 'commit em caminho inexistente: os dois rodam os mesmos checks do manifesto real' {
        # So a CONTAGEM: o veredito aqui e dos checks reais, que tem (ou nao) paridade propria.
        $p = New-PayloadPre -Comando ('cd "C:\naoexiste-repo-percus" && git ' + $script:tokCommit + ' -m teste')
        $c = Invoke-Runtime -Runtime cmd -Evento pre -Dir $script:kitHooks -Payload $p -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $s = Invoke-Runtime -Runtime sh -Evento pre -Dir $script:kitHooks -Payload $p -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        # `-match` e nao `Should -Match`: so o operador preenche $matches.
        ($c.Stderr -match 'checks rodados: (\d+) de (\d+)') | Should -BeTrue -Because "stderr do cmd: $($c.Stderr)"
        $contaCmd = $matches[0]
        [int]$matches[1] | Should -BeGreaterOrEqual 7 -Because 'os 7 checks que declaram o gatilho commit tem de rodar'
        ($s.Stderr -match 'checks rodados: (\d+) de (\d+)') | Should -BeTrue -Because "stderr do sh: $($s.Stderr)"
        $matches[0] | Should -BeExactly $contaCmd
    }
}

Describe 'paridade .sh do dispatcher PreToolUse -- achados do R11 Cross-Claude (valores nao-string)' {
    # Os tres casos abaixo nao existem no manifesto de hoje. Existem porque "verdadeiro" e
    # "ausente" nao significam a mesma coisa no PowerShell e no jq, e um manifesto mal editado
    # atravessaria a diferenca sem nenhum teste de string denunciar.

    It 'command false no payload: o .ps1 le "False" e SEGUE -- o .sh nao pode sair calado' {
        # O `// empty` do jq troca false por vazio; o [string] do PowerShell da "False".
        $p = '{"tool_name":"Bash","tool_input":{"command":false},"cwd":"C:/zeta-pasta"}'
        $r = Invoke-ParPre -Dir $script:fxPrincipal -Payload $p -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly '[percus:dispatch-pre] checks rodados: 1 de 5 | veredito: 0'
    }

    It 'registrado 0, "", [] e [0] ficam fora e [0,0] entra; gatilhos 0 e false sao descartados como no Where-Object' {
        # Array de 1 elemento vale o que o elemento vale no PowerShell; com 2+ elementos e sempre
        # verdadeiro. No jq qualquer array nao vazio e verdadeiro. Achado da 2a rodada do R11
        # Cross-Claude: a 1a versao da funcao `verdade` so excluia o [] vazio.
        $d = New-Fixture -Evento pre -Hooks @(
            (New-Entrada -Nome reg0 -Gatilhos 'zeta' -RegistradoCru 0),
            (New-Entrada -Nome regvazio -Gatilhos 'zeta' -RegistradoCru ''),
            (New-Entrada -Nome reglista -Gatilhos 'zeta' -RegistradoCru @()),
            (New-Entrada -Nome regum -Gatilhos 'zeta' -RegistradoCru @(0)),
            (New-Entrada -Nome regdois -Gatilhos 'zeta' -RegistradoCru @(0, 0)),
            (New-Entrada -Nome gatfalso -Gatilhos @(0, $false)),
            (New-Entrada -Nome gatmisto -Gatilhos @(0, $false, 'omega'))
        )
        foreach ($n in 'reg0', 'regvazio', 'reglista', 'regum') { New-CheckPar -Dir $d -Nome $n -Rc 2 -Fala "$n NAO devia rodar" }
        New-CheckPar -Dir $d -Nome regdois -Fala 'regdois rodou'
        # So gatilhos falsos = nenhum gatilho = roda sempre.
        New-CheckPar -Dir $d -Nome gatfalso -Fala 'gatfalso rodou'
        # Sobra so omega, que o comando nao tem. Mantidos como texto, "0" e "false" casariam.
        New-CheckPar -Dir $d -Nome gatmisto -Rc 2 -Fala 'gatmisto NAO devia rodar'

        $r = Invoke-ParPre -Dir $d -Payload (New-PayloadPre -Comando 'zeta 0 false agora') -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Cmd.ExitCode | Should -Be 0
        (Format-Stderr $r.Cmd.Stderr) | Should -BeExactly (@(
            'regdois rodou'
            'gatfalso rodou'
            '[percus:dispatch-pre] checks rodados: 2 de 3 | veredito: 0'
        ) -join "`n")
    }
}

Describe 'dispatcher PreToolUse .sh -- o que so existe no bash' {

    It 'sem jq: avisa e cai na cadeia antiga, nunca some calado' {
        # O .ps1 nao tem este caso (ConvertFrom-Json e nativo). No bash, sem jq nao ha como ler o
        # manifesto -- e o analogo do "manifesto ilegivel", e tem de terminar no mesmo lugar.
        $sj = Get-EnvSemJq
        (Invoke-BashComando -Bash $sj.Bash -Env $sj.Env -Comando 'command -v jq || echo SEM-JQ') |
            Should -Match 'SEM-JQ' -Because 'pre-condicao: com o jq visivel o cenario seguiria o caminho normal'
        $s = Invoke-Runtime -Runtime sh -Evento pre -Dir $script:fxPrincipal -Payload (New-PayloadPre -Comando 'zeta') `
                            -Env $sj.Env -Bash $sj.Bash
        $s.ExitCode | Should -Be 0
        (Format-Stderr $s.Stderr) | Should -BeExactly ((@('[percus:dispatch-pre] jq ausente -- sem ele nao ha como ler o manifesto; rodando a cadeia antiga.') + $script:avisosLegado) -join "`n")
    }
}
