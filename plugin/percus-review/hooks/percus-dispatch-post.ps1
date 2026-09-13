# ============================================================================
# Dispatcher PostToolUse -- CAMADA 2 (decisao precisa, UM processo PowerShell).
#
# Chamado pela camada 1 (percus-dispatch-post.cmd) somente quando a porta por
# timestamp abriu. LE STDIN DIRETO -- ao contrario do dispatcher `pre`, que recebe
# o caminho de um payload ja capturado. Motivo medido no cabecalho do .cmd: o
# payload de PostToolUse carrega `tool_response` e 0,59% dos reais passam de 80 KB,
# que e onde a captura em cmd.exe trunca. Aqui nao ha captura, entao nao ha limite.
#
# TRES DIFERENCAS EM RELACAO AO `pre`, todas com consequencia:
#
#  1. STDOUT E O CANAL DO PRODUTO. O guard devolve
#     {"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}}
#     e o harness injeta isso no contexto do agente. No `pre` so importavam exit
#     code e stderr. Dispatcher que engole ou concatena stdout mata o aviso sem
#     deixar rastro -- por isso a fusao logo abaixo, e nao um simples repasse:
#     dois checks emitindo dois objetos JSON colados dariam stdout invalido, e o
#     harness descartaria OS DOIS calado. Hoje ha um so check; a fusao existe pro
#     segundo, que e exatamente quando ninguem estaria olhando.
#
#  2. NAO HA FALLBACK DEPOIS DE LER STDIN. Stream so pode ser lido uma vez, entao
#     tudo que possa mandar a camada 1 pro fallback (exit 9) e decidido ANTES da
#     leitura: manifesto ilegivel e check ausente do disco. Depois disso, falha
#     vira mensagem no stderr, nunca uma rota alternativa que rodaria o check com
#     stdin vazio -- isso seria um no-op se fazendo passar por fallback.
#
#  3. O VEREDITO E DE OBSERVADOR. A cadeia de PostToolUse nao barra nada: a tool
#     ja rodou. `exit 2` aqui nao desfaz nada, so faz o stderr chegar ao agente --
#     entao ele fica reservado a quebra ESTRUTURAL (check registrado que sumiu do
#     disco), que e rara e alta. Operacao normal sai 0.
#
# Spec: docs/superpowers/specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md
# ============================================================================

$ErrorActionPreference = 'Stop'
$e = [Console]::Error

function Sair([int]$codigo) { exit $codigo }

$hooksDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- TUDO QUE PODE PEDIR FALLBACK VEM ANTES DE TOCAR EM STDIN ---------------
try {
    $manifesto = Get-Content (Join-Path $hooksDir 'hooks-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    $e.WriteLine("[percus:dispatch-post] hooks-manifest.json ilegivel: $($_.Exception.Message)")
    Sair 9   # stdin intacto: a camada 1 roda a cadeia antiga
}

# `registro -ceq 'percus-dispatch-post'` separa esta cadeia da do `pre`. Sem o filtro,
# um hook com entrada propria no hooks.json rodaria DUAS vezes -- uma pelo harness,
# outra aqui. Mesmo achado que o review cross-provider levantou no `pre`.
$checks = @($manifesto.hooks | Where-Object {
        $_.evento -eq 'PostToolUse' -and $_.registrado -and $_.registro -ceq 'percus-dispatch-post'
    })
if ($checks.Count -eq 0) {
    $e.WriteLine("[percus:dispatch-post] nenhum check de PostToolUse registrado no manifesto.")
    Sair 9
}

# Integridade em disco, ainda antes de stdin: se NENHUM check sobreviver, a camada 1
# ainda pode rodar a cadeia antiga. Se alguns sobreviverem, seguimos com esses e o
# sumico do outro vira ruido alto -- nunca silencio.
$rodaveis = @()
$estrutural = $false
foreach ($c in $checks) {
    $script = Join-Path $hooksDir ($c.nome + '.ps1')
    if (-not (Test-Path -LiteralPath $script)) {
        $e.WriteLine("[percus:dispatch-post] check registrado mas AUSENTE do disco: $($c.nome).ps1")
        $estrutural = $true
        continue
    }
    # Test-Path nao ve arquivo truncado, e o tripwire dos .cmd antigos usava tamanho.
    if ((Get-Item -LiteralPath $script).Length -lt 200) {
        $e.WriteLine("[percus:dispatch-post] check '$($c.nome)' esta TRUNCADO em disco (< 200 bytes) -- instalacao corrompida.")
        $estrutural = $true
        continue
    }
    $rodaveis += [pscustomobject]@{ Nome = $c.nome; Script = $script }
}
if ($rodaveis.Count -eq 0) { Sair 9 }

# --- A PARTIR DAQUI STDIN FOI CONSUMIDO: sem volta pro fallback -------------
#
# ATENCAO: TUDO daqui pra baixo vive dentro de UM try/catch que sai 0, e isso e
# obrigatorio, nao zelo. A camada 1 traduz "codigo de saida estranho" em FALLBACK,
# e o comentario dela afirma que nesses casos stdin nao foi consumido. Depois
# desta linha essa afirmacao e FALSA: uma excecao aqui faria o .cmd chamar o
# `context-budget-guard.cmd`, que herda o mesmo handle de stdin -- ja drenado --,
# le vazio, cai no proprio `if (-not $stdin) { exit 0 }` e nao emite nada.
# Resultado provado pelo review R11 (throw injetado numa COPIA, .cmd real do repo
# apontado pra ela): exit 0, stdout vazio, aviso de contexto perdido em silencio,
# tudo com cara de saudavel. O `context-budget-guard.ps1` embrulha o corpo inteiro
# em try/catch pelo mesmo motivo; a camada 2 precisava fazer igual.
try {

$bruto = [Console]::In.ReadToEnd()
if (-not $bruto -or -not $bruto.Trim()) { Sair 0 }

# O payload nao passa por captura de cmd.exe, entao JSON invalido aqui nao e
# truncagem -- e payload estranho do harness. Fala alto e sai 0: o guard faria o
# mesmo (ele proprio tem `catch { exit 0 }`), e derrubar a tool call ja concluida
# por causa disso seria ruido sem remedio.
try {
    $null = $bruto | ConvertFrom-Json
} catch {
    $kb = [Math]::Round($bruto.Length / 1KB, 1)
    $e.WriteLine("[percus:dispatch-post] payload nao parseia como JSON ($kb KB) -- nenhum check rodou.")
    Sair 0
}

$rodaram = 0
# Guarda o NOME junto com o texto. A versao anterior guardava so a string e
# decidia o repasse cru por CONTAGEM AGREGADA -- o review R11 registrou dois
# checks de teste, os dois emitindo texto puro, e o stdout saiu com as duas
# mensagens coladas: `ConvertFrom-Json` falhou e o harness descartaria AS DUAS,
# calado. Exatamente a falha que a fusao existe pra impedir, entrando pelo ramo
# nao-JSON. Sem o nome nao da pra saber se "uma saida crua" veio de um emissor so.
$saidas = New-Object System.Collections.Generic.List[object]

foreach ($c in $rodaveis) {
    $leitor = New-Object IO.StringReader($bruto)
    # $ErrorActionPreference='Stop' e HERDADO pelo script chamado com `&`, e no
    # Windows PowerShell 5.1 transforma stderr de comando NATIVO em erro terminante
    # -- mesmo com 2>$null. Os checks foram escritos assumindo o contrario. Provado
    # A/B no dispatcher `pre`: sob Stop, o check caia no proprio catch e saia 0,
    # perda de enforcement 100% calada. Os checks rodam no runtime em que nasceram.
    $eapAnterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = 0
    try {
        [Console]::SetIn($leitor)
        # `& $script` devolve o que o check escreve em stdout -- e o que permite
        # fundir em vez de deixar dois objetos colidirem no stdout do processo.
        $out = & $c.Script
        $rodaram++
        if ($out) {
            $texto = ($out | Out-String).Trim()
            if ($texto) { $saidas.Add([pscustomobject]@{ Nome = $c.Nome; Texto = $texto }) }
        }
    } catch {
        # DEFESA 2: check que explode e REPORTADO, nunca engolido.
        $e.WriteLine("[percus:dispatch-post] check '$($c.Nome)' lancou excecao: $($_.Exception.Message)")
    } finally {
        $ErrorActionPreference = $eapAnterior
        $leitor.Dispose()
    }
}

# --- Fusao do stdout -------------------------------------------------------
# Um check calado tem de virar dispatcher calado: emitir um JSON vazio faria o
# harness tratar como saida de hook e o transcript ganharia ruido em TODA tool call.
if ($saidas.Count -gt 0) {
    $contextos = New-Object System.Collections.Generic.List[string]
    $sistemas = New-Object System.Collections.Generic.List[string]
    $naoJson = New-Object System.Collections.Generic.List[object]

    foreach ($s in $saidas) {
        try { $o = $s.Texto | ConvertFrom-Json } catch { $naoJson.Add($s); continue }
        if ($o.hookSpecificOutput -and $o.hookSpecificOutput.additionalContext) {
            $contextos.Add([string]$o.hookSpecificOutput.additionalContext)
        }
        if ($o.systemMessage) { $sistemas.Add([string]$o.systemMessage) }
    }

    if ($saidas.Count -eq 1 -and $naoJson.Count -eq 1) {
        # UM check, e ele falou texto cru: repassa VERBATIM. Reembrulhar mudaria a
        # semantica de um check que talvez dependa dela.
        # A condicao e `$saidas.Count -eq 1`, e nao "nenhum JSON apareceu": com dois
        # emissores crus a versao anterior colava os dois no stdout e o harness
        # descartava ambos (provado no review R11).
        [Console]::Out.Write($naoJson[0].Texto)
    } else {
        # Dois ou mais emissores: tudo vira UM objeto. O texto cru NAO e descartado
        # -- ele entra como contexto nomeado. Descartar seria trocar um stdout
        # invalido por um silencio, que e a mesma perda com menos rastro.
        foreach ($n in $naoJson) {
            $e.WriteLine("[percus:dispatch-post] saida nao-JSON de '$($n.Nome)' embrulhada na fusao (stdout compartilhado com outro check).")
            $contextos.Add("[$($n.Nome)] $($n.Texto)")
        }
        $saida = @{}
        if ($contextos.Count -gt 0) {
            $saida.hookSpecificOutput = @{
                hookEventName     = 'PostToolUse'
                additionalContext = ($contextos -join "`n")
            }
        }
        if ($sistemas.Count -gt 0) { $saida.systemMessage = ($sistemas -join ' ') }
        if ($saida.Count -gt 0) {
            [Console]::Out.Write(($saida | ConvertTo-Json -Compress -Depth 6))
        }
    }
}

if ($env:PERCUS_DISPATCH_DEBUG -eq '1') {
    $e.WriteLine("[percus:dispatch-post] checks rodados: $rodaram de $($checks.Count)")
}

if ($estrutural) { Sair 2 }
Sair 0

} catch {
    # Ver o bloco no alto do try: stdin ja foi drenado, entao NAO existe rota
    # alternativa -- a cadeia antiga leria vazio e sairia 0 calada. Falar aqui e a
    # unica coisa honesta que sobra, e sair 0 impede que o .cmd chame um fallback
    # que so produziria silencio com cara de sucesso.
    $e.WriteLine("[percus:dispatch-post] ERRO depois de consumir stdin: $($_.Exception.Message)")
    $e.WriteLine("  A medicao de contexto desta tool call foi perdida (a proxima recupera).")
    $e.WriteLine("  Contorno: PERCUS_DISPATCHER_BYPASS=1 roda a cadeia antiga direto.")
    exit 0
}
