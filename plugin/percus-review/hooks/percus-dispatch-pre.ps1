# ============================================================================
# Dispatcher PreToolUse -- CAMADA 2 (decisao precisa, UM processo PowerShell).
#
# Chamado pela camada 1 (percus-dispatch-pre.cmd) somente quando a triagem por
# substring indicou que ALGUEM poderia disparar. Recebe o caminho do payload ja
# capturado -- stdin nao pode ser lido de novo.
#
# Tres fatos medidos em 2026-09-12 que sustentam este desenho:
#
#  1. `[Console]::SetIn([IO.StringReader]$payload)` re-alimenta stdin antes de
#     cada check, entao os 8 checks seguem fazendo `[Console]::In.ReadToEnd()`
#     SEM UMA LINHA DE MUDANCA. Sem isso seria preciso um contrato novo
#     (PERCUS_HOOK_STDIN_FILE) em 8 arquivos -- e contrato que nao existe nao
#     pode ser esquecido por um hook futuro.
#  2. `exit` dentro de um .ps1 chamado com `&` NAO mata o chamador, e o
#     $LASTEXITCODE chega intacto. Por isso os checks rodam sem reescrever o
#     fluxo de controle de nenhum.
#  3. A captura em cmd.exe trunca acima de ~80 KB saindo 0. Payload cortado e
#     JSON invalido; sem a validacao abaixo, todo check cairia no proprio catch
#     e a cadeia passaria CALADA justo no comando maior.
#
# Spec: docs/superpowers/specs/2026-09-12-consolidacao-cadeia-de-hooks-design.md
# ============================================================================

param([Parameter(Mandatory)][string]$PayloadPath)

$ErrorActionPreference = 'Stop'
$e = [Console]::Error

function Sair([int]$codigo) { exit $codigo }

# --- Payload ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $PayloadPath)) {
    $e.WriteLine("[percus:dispatch-pre] payload ausente em '$PayloadPath'.")
    Sair 9   # nem 0 nem 2: a camada 1 cai no fallback
}

$bruto = [IO.File]::ReadAllText($PayloadPath)
if (-not $bruto -or -not $bruto.Trim()) { Sair 0 }   # sem payload, nada a fazer

try {
    $parsed = $bruto | ConvertFrom-Json
} catch {
    # FALHA ALTO, nunca calado. Ver fato 3 no cabecalho: a causa mais provavel e
    # truncagem da captura (~80 KB). Nao ha recuperacao -- stdin ja foi consumido
    # e e irreproduzivel -- entao a escolha real e entre barrar avisando e passar
    # calado, e passar calado num gate de enforcement nao e escolha.
    $kb = [Math]::Round($bruto.Length / 1KB, 1)
    $e.WriteLine("[percus:dispatch-pre] BLOCK: payload nao parseia como JSON ($kb KB).")
    $e.WriteLine("  Causa provavel: a captura de stdin em cmd.exe trunca acima de ~80 KB.")
    $e.WriteLine("  Nenhum check pode rodar -- e passar em silencio esconderia isso.")
    $e.WriteLine("  Contorno: PERCUS_DISPATCHER_BYPASS=1 (cadeia antiga) ou comando menor.")
    Sair 2
}

$comando = [string]$parsed.tool_input.command
if (-not $comando) { Sair 0 }

# --- Registro dos checks: o manifesto e a fonte unica ----------------------
# Ler daqui (em vez de recopiar a lista) e o que faz o teste de contencao ter
# sentido: quem adiciona gatilho num check e esquece a uniao fica VERMELHO, em
# vez de o hook sumir calado.
$hooksDir = Split-Path -Parent $MyInvocation.MyCommand.Path
try {
    $manifesto = Get-Content (Join-Path $hooksDir 'hooks-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    $e.WriteLine("[percus:dispatch-pre] hooks-manifest.json ilegivel: $($_.Exception.Message)")
    Sair 9   # fallback: a cadeia antiga nao depende do manifesto
}

# `registro -ceq 'dispatcher'` NAO e detalhe: sem ele o proprio dispatcher entra na
# lista (observado ao vivo: "checks rodados: 7 de 9"), e qualquer hook futuro com
# entrada propria no hooks.json rodaria DUAS vezes -- uma pelo harness, outra aqui.
# Hoje o dispatcher so nao se auto-executa por acidente (gatilhos null nunca casam),
# e acidente nao e desenho. Achado do review cross-provider.
$checks = @($manifesto.hooks | Where-Object {
    $_.evento -eq 'PreToolUse' -and $_.matcher -eq 'Bash|PowerShell' -and
    $_.registrado -and $_.registro -ceq 'dispatcher'
})
if ($checks.Count -eq 0) {
    $e.WriteLine("[percus:dispatch-pre] nenhum check registrado no manifesto.")
    Sair 9
}

# --- Decisao PRECISA -------------------------------------------------------
# A camada 1 casou os gatilhos contra o JSON INTEIRO (cwd, tool_name, tudo).
# Aqui casamos so contra tool_input.command -- e o ganho de precisao que
# justifica a assimetria: um `cwd` com "docker" no caminho acorda a camada 1,
# mas nao faz o external-action-guard rodar.
$veredito = 0
$rodaram = 0

foreach ($c in $checks) {
    $script = Join-Path $hooksDir ($c.nome + '.ps1')
    if (-not (Test-Path -LiteralPath $script)) {
        # Tripwire de integridade, herdado dos .cmd: check registrado e ausente
        # do disco e instalacao corrompida, e isso se grita.
        $e.WriteLine("[percus:dispatch-pre] check registrado mas AUSENTE do disco: $($c.nome).ps1")
        $veredito = 2
        continue
    }

    # `@($c.gatilhos)` com a propriedade ausente ou null tem Count 1 (um elemento $null),
    # nao 0 -- o loop entao compara contra $null, nunca casa, e o check e PULADO em
    # silencio: o oposto exato do default declarado abaixo. Filtrar os vazios faz
    # Count 0 voltar a significar "roda sempre". Achado do review cross-provider.
    $gatilhos = @($c.gatilhos | Where-Object { $_ })
    if ($gatilhos.Count -gt 0) {
        $casou = $false
        foreach ($g in $gatilhos) {
            if ($comando.IndexOf($g, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $casou = $true; break }
        }
        if (-not $casou) { continue }
    }
    # Sem gatilhos declarados => roda sempre. Default seguro: check novo que
    # esqueceu de declarar paga 400 ms, nao vira buraco.

    # Tripwire de integridade, herdado dos .cmd (cada um fazia `if %TAM% LSS 200 exit /b 2`).
    # Test-Path sozinho nao cobre .ps1 truncado/vazio -- e o Test-Path acima ja passou.
    if ((Get-Item -LiteralPath $script).Length -lt 200) {
        $e.WriteLine("[percus:dispatch-pre] check '$($c.nome)' esta TRUNCADO em disco (< 200 bytes) -- instalacao corrompida.")
        $veredito = 2
        continue
    }

    $leitor = New-Object IO.StringReader($bruto)
    # $ErrorActionPreference='Stop' e HERDADO pelo script chamado com `&`, e no Windows
    # PowerShell 5.1 isso transforma stderr de comando NATIVO em erro terminante -- mesmo
    # com `2>$null`. Os 8 checks foram escritos assumindo o contrario: `& git ... 2>$null`
    # seguido de teste de $LASTEXITCODE. Sob Stop, um `git` que reclama vira excecao, o
    # catch do proprio check engole e sai 0. Provado A/B pelo review: o mesmo payload que
    # hoje da BLOCK (exit 2) passava a sair 0 com "hook crashed, allowing commit".
    # Perda de enforcement 100% calada. Os checks rodam no runtime em que foram escritos.
    $eapAnterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    # Sem zerar, um .ps1 que retorna sem `exit` deixa o $LASTEXITCODE do check ANTERIOR
    # intacto -- e o veredito herdaria um bloqueio que nao foi deste check.
    $global:LASTEXITCODE = 0
    try {
        [Console]::SetIn($leitor)
        & $script
        $ec = $LASTEXITCODE
        $rodaram++
        if ($ec -ne 0) { $veredito = 2 }
    } catch {
        # DEFESA 2: check que explode e REPORTADO, nunca engolido. O `exit 0`
        # universal de hoje protege contra BLOQUEAR por engano -- nao pode virar
        # protecao contra AVISAR.
        $e.WriteLine("[percus:dispatch-pre] check '$($c.nome)' lancou excecao: $($_.Exception.Message)")
    } finally {
        $ErrorActionPreference = $eapAnterior
        $leitor.Dispose()
    }
    # NAO para no primeiro exit 2. Contrapartida da defesa 2: se aviso nao pode
    # ser engolido por excecao, tambem nao pode ser engolido por curto-circuito.
    # Quase todo check do kit e warn-only; parar aqui apagaria justo o sinal deles.
}

if ($env:PERCUS_DISPATCH_DEBUG -eq '1') {
    $e.WriteLine("[percus:dispatch-pre] checks rodados: $rodaram de $($checks.Count) | veredito: $veredito")
}

Sair $veredito
