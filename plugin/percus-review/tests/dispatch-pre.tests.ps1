# Testes do dispatcher PreToolUse (camada 1 cmd.exe + camada 2 PowerShell).
#
# Escritos ANTES da implementacao (TDD). Cada bloco corresponde a um criterio de
# pronto da spec 2026-09-12-consolidacao-cadeia-de-hooks-design.md.
#
# DISCIPLINA DESTE ARQUIVO: prova COMPORTAMENTAL -- roda o .cmd/.ps1 de verdade
# contra payload real e olha exit code/stderr. Nenhum teste inspeciona codigo
# fonte procurando string: inspecao de fonte prova que alguem escreveu algo, nao
# que o programa faz algo.
#
# ATENCAO ao escrever casos novos: o payload NAO pode conter a sequencia
# `git`+`commit` literal no COMANDO deste processo de teste -- o pre-commit-check
# casa por texto e barraria a propria suite. Monte em runtime (ver $tokCommit).

BeforeAll {
    $script:hooksDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks'
    $script:dispCmd  = Join-Path $hooksDir 'percus-dispatch-pre.cmd'
    $script:dispPs1  = Join-Path $hooksDir 'percus-dispatch-pre.ps1'
    $script:gatilhos = Join-Path $hooksDir 'gatilhos-pre.txt'
    $script:manifest = Join-Path $hooksDir 'hooks-manifest.json'

    # Montado em runtime: literal no fonte faria o pre-commit-check barrar a suite.
    $script:tokCommit = 'com' + 'mit'

    function New-Payload {
        param([string]$Comando, [string]$Cwd = $PWD.Path)
        @{ tool_name = 'Bash'; tool_input = @{ command = $Comando }; cwd = $Cwd } |
            ConvertTo-Json -Compress -Depth 5
    }

    # Roda a camada 1 (o .cmd) com o payload em stdin, devolve exit code + stderr.
    function Invoke-Dispatch {
        param([string]$Payload, [hashtable]$Env = @{})
        # Os TRES temporarios nascem ANTES de mexer no ambiente: um dos casos de teste
        # aponta TEMP pra um caminho inexistente de proposito, e GetTempFileName() usa
        # TEMP -- criar o terceiro depois fazia o HELPER estourar e o teste reprovar por
        # defeito proprio, com o dispatcher se comportando corretamente.
        $tmpIn  = [IO.Path]::GetTempFileName()
        $tmpErr = [IO.Path]::GetTempFileName()
        $tmpOut = [IO.Path]::GetTempFileName()
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
                -RedirectStandardOutput $tmpOut `
                -NoNewWindow -Wait -PassThru
            [pscustomobject]@{
                ExitCode = $p.ExitCode
                Stderr   = (Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue)
            }
        } finally {
            foreach ($k in $Env.Keys) { [Environment]::SetEnvironmentVariable($k, $antigos[$k]) }
            foreach ($t in $tmpIn, $tmpErr, $tmpOut) {
                Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'dispatcher PreToolUse -- camada 1 (triagem em cmd.exe)' {

    It 'existe como .cmd e .ps1 (paridade de arquivos)' {
        Test-Path $script:dispCmd | Should -BeTrue
        Test-Path $script:dispPs1 | Should -BeTrue
    }

    It 'gatilhos-pre.txt NAO tem BOM -- BOM vira parte do 1o literal e mata o gatilho' {
        # Medido em 2026-09-12: arquivo UTF-8 COM BOM faz findstr devolver rc=1
        # num payload que contem o literal. Falha silenciosa: a cadeia inteira
        # deixa de rodar e nada avisa.
        $bytes = [IO.File]::ReadAllBytes($script:gatilhos)
        $temBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $temBom | Should -BeFalse -Because 'BOM no gatilhos.txt mata o primeiro literal (medido)'
    }

    It 'comando sem nenhum gatilho sai 0 sem subir PowerShell' {
        $r = Invoke-Dispatch -Payload (New-Payload -Comando 'echo ola')
        $r.ExitCode | Should -Be 0
        $r.Stderr   | Should -BeNullOrEmpty
    }

    It 'casa o gatilho mesmo em MAIUSCULA -- -match do PowerShell e case-insensitive' {
        # Sem /I no findstr, `GIT COMMIT` nao casaria a triagem e os 7 hooks de
        # pre-commit nunca rodariam -- mas eles PROPRIOS casariam o comando.
        # Buraco silencioso. Medido em 2026-09-12.
        #
        # O observavel e a linha de DEBUG do dispatcher, nao o stderr dos checks. A primeira
        # versao afirmava "a cadeia falou algo" e ficava VERMELHA so na suite inteira: outro
        # teste cria uma autorizacao R20 de verdade no repo (silencia o external-action-guard)
        # e um review recente silencia o pre-commit-check. Os checks estavam CERTOS em calar.
        # Teste que depende do que OUTRO componente decide falar e refem do estado do repo.
        $r = Invoke-Dispatch -Payload (New-Payload -Comando ('GIT ' + $script:tokCommit.ToUpper() + ' -m x')) `
                             -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.ExitCode | Should -BeIn @(0, 2)
        $r.Stderr   | Should -Match 'checks rodados' -Because 'a camada 2 tem de ter subido com payload em MAIUSCULA'
        if ($r.Stderr -match 'checks rodados: (\d+)') {
            [int]$matches[1] | Should -BeGreaterThan 0 -Because 'triagem casou, logo algum check tinha de rodar'
        }
    }

    It 'sem gatilho a camada 2 NEM SOBE -- e o que faz a triagem valer 62 ms' {
        # O par complementar do anterior. Sem este, "casa em maiuscula" passaria igual num
        # dispatcher que simplesmente roda tudo sempre -- e o ganho medido (3716 -> 62 ms)
        # viria de lugar nenhum.
        $r = Invoke-Dispatch -Payload (New-Payload -Comando 'echo ola') `
                             -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Stderr | Should -Not -Match 'checks rodados' -Because 'nenhum gatilho: o PowerShell nao pode ter subido'
    }
}

Describe 'dispatcher PreToolUse -- camada 2 (agregacao e defesas)' {

    It 'roda TODOS os checks que casaram, sem parar no primeiro que bloqueia' {
        # A contrapartida da defesa 2: se aviso nao pode ser engolido por excecao,
        # tambem nao pode ser engolido por curto-circuito. Quase todo check do kit
        # e warn-only -- parar no primeiro exit 2 apagaria justamente o sinal deles.
        #
        # A prova e a CONTAGEM do dispatcher, nao o stderr dos checks: `commit` e gatilho
        # declarado de 7 checks, entao os 7 tem de aparecer no contador. Se o dispatcher
        # parasse no primeiro exit 2, a contagem cairia -- e nenhum estado do repo muda isso,
        # porque o contador incrementa por check EXECUTADO, nao por check que falou.
        $r = Invoke-Dispatch -Payload (New-Payload -Comando ('git ' + $script:tokCommit + ' -m "x"')) `
                             -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Stderr | Should -Match 'checks rodados'
        if ($r.Stderr -match 'checks rodados: (\d+)') {
            [int]$matches[1] | Should -BeGreaterOrEqual 7 -Because 'os 7 checks que declaram o gatilho `commit` tem de rodar todos'
        }
    }

    It 'payload truncado/invalido FALHA ALTO, nunca sai 0 calado' {
        # Captura de stdin em cmd.exe trunca acima de ~80 KB (medido). Payload
        # cortado = JSON invalido = todo check cai no proprio catch e sai 0.
        # A cadeia passaria calada exatamente no comando maior. Fail-loud e a
        # unica escolha honesta: stdin ja foi consumido e e irrecuperavel.
        $quebrado = '{"tool_input":{"command":"git ' + $script:tokCommit + ' -m ' + ('a' * 50)
        $r = Invoke-Dispatch -Payload $quebrado
        $r.ExitCode | Should -Be 2
        $r.Stderr   | Should -Match 'payload'
    }

    It 'PERCUS_HOOKS_DISABLED=1 sai 0 antes de qualquer trabalho' {
        $r = Invoke-Dispatch -Payload (New-Payload -Comando ('git ' + $script:tokCommit + ' -m x')) `
                             -Env @{ PERCUS_HOOKS_DISABLED = '1' }
        $r.ExitCode | Should -Be 0
        $r.Stderr   | Should -BeNullOrEmpty
    }

    It 'PERCUS_DISPATCHER_BYPASS=1 cai na cadeia legada e mantem o comportamento' {
        # Defesa 1: lento e correto > rapido e mudo. Bug no dispatcher nao pode
        # deixar a frota sem enforcement ate o proximo ciclo de auto-update.
        #
        # A primeira versao so afirmava `ExitCode -Be 0` com payload `echo ola` -- e um
        # dispatcher que IGNORASSE o bypass inteiro devolve 0 do mesmo jeito (sem gatilho
        # -> :sai_limpo). Passava com a feature quebrada. Achado do review cross-provider.
        # O discriminador e a AUSENCIA da linha de debug: no bypass a camada 2 nao sobe.
        $r = Invoke-Dispatch -Payload (New-Payload -Comando ('git ' + $script:tokCommit + ' -m x')) `
                             -Env @{ PERCUS_DISPATCHER_BYPASS = '1'; PERCUS_DISPATCH_DEBUG = '1' }
        $r.ExitCode | Should -BeIn @(0, 2)
        $r.Stderr   | Should -Not -Match 'checks rodados' -Because 'no bypass quem roda e a cadeia antiga, nao a camada 2'
    }

    It 'BUG do EAP: check que chama git em repo inexistente ainda BLOQUEIA' {
        # O achado mais grave do review, provado A/B por ele: $ErrorActionPreference='Stop'
        # e HERDADO pelo script chamado com `&`, e no PowerShell 5.1 transforma stderr de
        # comando NATIVO em erro terminante -- mesmo com 2>$null. Os 8 checks assumem o
        # contrario (`& git ... 2>$null` + teste de $LASTEXITCODE). Sob Stop, o git que
        # reclama vira excecao, o catch do proprio check engole, e ele sai 0:
        #   EAP=Continue -> exit 2 (BLOCK: nenhum review)
        #   EAP=Stop     -> exit 0 ("hook crashed, allowing commit")
        # Perda de enforcement 100% calada. Este teste fixa o COMPORTAMENTO (bloqueia),
        # nao o mecanismo (qual EAP), pra continuar valendo se a implementacao mudar.
        $r = Invoke-Dispatch -Payload (New-Payload -Comando ('cd "C:\naoexiste-repo-percus" && git ' + $script:tokCommit + ' -m teste'))
        $r.ExitCode | Should -Be 2 -Because 'commit em caminho inexistente nao pode passar por crash de hook'
        $r.Stderr   | Should -Not -Match 'crashed' -Because 'o check tem de decidir, nao estourar'
    }

    It 'BUG do temp: sem lugar pra gravar o payload, FALHA ALTO em vez de sair 0 calado' {
        # Medido pelo review com TEMP=Z:\nao\existe: o findstr da triagem devolvia rc=1
        # -- indistinguivel de "nenhum gatilho casou" -- e a cadeia saia 0 com ZERO checks,
        # deixando so "O sistema nao pode encontrar o caminho" sem assinatura [percus:].
        # O fail-open do `rc GEQ 2` nao cobria este caso, que e o mais provavel dos dois.
        $r = Invoke-Dispatch -Payload (New-Payload -Comando ('git ' + $script:tokCommit + ' -m x')) `
                             -Env @{ TEMP = 'Z:\nao\existe\percus'; TMP = 'Z:\nao\existe\percus' }
        $r.ExitCode | Should -Be 2
        $r.Stderr   | Should -Match 'percus:dispatch-pre' -Because 'falha de enforcement tem de sair assinada'
    }
}

Describe 'dispatcher PreToolUse -- contencao dos gatilhos (defesa 3)' {

    It 'todo gatilho declarado por um check esta na uniao de gatilhos-pre.txt' {
        # O teste que fecha a classe `categoria-nova-esquecida-em-lista-de-enumeracao`:
        # quem adicionar gatilho num check e esquecer a uniao deixa a suite VERMELHA,
        # em vez de o hook sumir calado.
        $m = Get-Content $script:manifest -Raw | ConvertFrom-Json
        $uniao = @(Get-Content $script:gatilhos | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim().ToLower() })

        $declarados = @()
        foreach ($h in $m.hooks) {
            if ($h.evento -ne 'PreToolUse') { continue }
            if ($h.matcher -ne 'Bash|PowerShell') { continue }
            if ($h.forma -eq 'dispatcher') { continue }   # carrega a uniao, nao declara gatilho proprio
            $h.gatilhos | Should -Not -BeNullOrEmpty -Because "o check '$($h.nome)' precisa declarar gatilhos para ser triavel"
            $declarados += @($h.gatilhos | ForEach-Object { $_.ToLower() })
        }

        $faltando = @($declarados | Sort-Object -Unique | Where-Object { $uniao -notcontains $_ })
        $faltando | Should -BeNullOrEmpty -Because "estes gatilhos estao declarados num check mas fora da uniao: $($faltando -join ', ')"
    }

    It 'a uniao nao tem gatilho orfao (nenhum check o declara)' {
        # O lado vacuo: uniao inchada faz o PowerShell subir a toa e devolve o
        # custo que a triagem existe pra eliminar.
        $m = Get-Content $script:manifest -Raw | ConvertFrom-Json
        $uniao = @(Get-Content $script:gatilhos | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim().ToLower() })
        $declarados = @()
        foreach ($h in $m.hooks) {
            if ($h.evento -ne 'PreToolUse' -or $h.matcher -ne 'Bash|PowerShell') { continue }
            if ($h.forma -eq 'dispatcher') { continue }
            $declarados += @($h.gatilhos | ForEach-Object { $_.ToLower() })
        }
        $orfaos = @($uniao | Where-Object { $declarados -notcontains $_ })
        $orfaos | Should -BeNullOrEmpty -Because "gatilhos na uniao que nenhum check declara: $($orfaos -join ', ')"
    }

    It 'a cadeia de FALLBACK lista exatamente os checks dispatchados do manifesto' {
        # A lista do `:legado` no .cmd e hardcoded. Um 9o check com registro='dispatcher'
        # rodaria na camada 2 e sumiria CALADO do fallback -- que so e exercitado quando o
        # PowerShell nao sobe, ou seja, no pior momento possivel pra descobrir. E a mesma
        # classe `categoria-nova-esquecida-em-lista-de-enumeracao` que o design cita.
        # Achado do review cross-provider.
        $m = Get-Content $script:manifest -Raw | ConvertFrom-Json
        $esperados = @($m.hooks | Where-Object { $_.registro -ceq 'dispatcher' } | ForEach-Object { $_.nome } | Sort-Object)
        $esperados.Count | Should -BeGreaterThan 0 -Because 'piso: sem dispatchados este It passaria vazio'

        $noFallback = @(Get-Content $script:dispCmd |
            ForEach-Object { if ($_ -match '^\s*call :roda\s+(\S+)') { $matches[1] } } |
            Sort-Object)

        ($noFallback -join ',') | Should -BeExactly ($esperados -join ',') -Because "o fallback tem de rodar os MESMOS checks da camada 2"
    }

    It 'o denominador do debug conta so os checks, nao o proprio dispatcher' {
        # Observado ao vivo pelo review: "checks rodados: 7 de 9". O 9 incluia o proprio
        # dispatcher e um hook de outro matcher. Nao era so cosmetico: sem o filtro por
        # registro='dispatcher', qualquer hook futuro com entrada propria no hooks.json
        # rodaria DUAS vezes -- uma pelo harness, outra aqui.
        $m = Get-Content $script:manifest -Raw | ConvertFrom-Json
        $n = @($m.hooks | Where-Object { $_.registro -ceq 'dispatcher' }).Count
        $r = Invoke-Dispatch -Payload (New-Payload -Comando ('git ' + $script:tokCommit + ' -m x')) `
                             -Env @{ PERCUS_DISPATCH_DEBUG = '1' }
        $r.Stderr | Should -Match "de $n\b" -Because "o denominador tem de ser os $n dispatchados"
    }

    It 'nenhum gatilho contem espaco -- \s+ do regex casa TAB e espaco multiplo' {
        # `git\s+commit` casa `git<TAB>commit` e `git   commit`; o literal
        # "git commit" com UM espaco nao casaria nenhum dos dois. Token unico, sempre.
        foreach ($g in (Get-Content $script:gatilhos | Where-Object { $_.Trim() })) {
            $g.Trim() | Should -Not -Match '\s' -Because "gatilho '$g' tem espaco: use tokens separados"
        }
    }
}
