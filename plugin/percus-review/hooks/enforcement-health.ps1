#requires -Version 5.1
# Hook SessionStart -- diz, no inicio de cada sessao, se o enforcement esta de fato ligado
# e DE ONDE o codigo dele vem.
#
# POR QUE ISTO EXISTE
#
# Todo incidente registrado deste kit tem a mesma forma: a coisa nao aconteceu e ninguem soube.
# Gate cego vendo 33 de 105 verbetes. Tres guardas respondendo verde sem rodar. Fix inerte por
# cache dessincronizado. Matcher cobrindo um caminho de dois. Nenhum foi "aconteceu algo errado";
# todos foram ausencia silenciosa.
#
# O trampolim (6.33.0) resolveu a ENTREGA -- o .cmd do cache passa a executar o .ps1 do kit -- mas
# criou uma ausencia silenciosa nova: numa maquina sem PERCUS_CANON_DIR ele cai na copia velha do
# cache sem dizer nada, e tudo parece normal. O lugar obvio pra avisar seria o proprio trampolim,
# e ele NAO SERVE: medido em 2026-07-31 (item 10 de docs/superpowers/medicoes/), saida de hook que
# sai 0 e invisivel, stderr e stdout. Barulho no vacuo e indistinguivel de silencio.
#
# SessionStart e o unico canal provadamente visivel -- e a prova e positiva, nao inferida: o hook
# [GATE INICIO] deste kit aparece na abertura de toda sessao.
#
# CORRECAO (2026-07-31, mesma sessao que fechou a Task 7 -- e reabriu):
# a prova acima so cobria STDOUT. Este hook falava por [Console]::Error (stderr), seguindo a
# convencao de assinatura-em-stderr das guardas -- e medido na sessao real, stderr de um hook
# SessionStart que sai 0 NAO aparece, exatamente como o item 10 ja tinha achado pra outro evento.
# O [GATE INICIO] e o hook do superpowers que aparecem usam stdout; este usava stderr e nunca foi
# visto. Por isso Falar fala por stdout agora -- e nao por convencao, por medicao.
#
# CONTRATO
#
# OBSERVADOR, sempre exit 0. Nunca bloqueia. Health check que tranca a sessao troca um problema
# por outro pior, e seria o unico hook capaz de deixar a maquina inutilizavel logo na abertura.
#
# FALA MESMO QUANDO ESTA TUDO CERTO. Health check que so fala em caso de erro e indistinguivel de
# health check que nao rodou -- que e exatamente a classe de bug que ele existe pra fechar.

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ASSINATURA = "[percus:health]"
$achados = New-Object System.Collections.Generic.List[string]

function Falar($msg) { [Console]::Out.WriteLine("$ASSINATURA $msg") }

try {
    # O manifesto viaja ao lado deste script, sempre -- self-relative, igual aos outros hooks.
    $hooksDir = $PSScriptRoot
    $manPath  = Join-Path $hooksDir "hooks-manifest.json"

    if (-not (Test-Path $manPath)) {
        Falar "manifesto nao encontrado em $manPath -- NAO consegui verificar o enforcement."
        exit 0
    }

    $man   = Get-Content -Encoding UTF8 $manPath -Raw | ConvertFrom-Json
    $vivos = @($man.hooks | Where-Object { $_.registrado })

    # ---- 1. De onde vem o codigo? -------------------------------------------------------
    # A pergunta que o trampolim nao consegue responder em voz alta.
    $canon = $env:PERCUS_CANON_DIR
    $origem = "cache"
    $porque = ""
    if (-not $canon) {
        $porque = "PERCUS_CANON_DIR nao esta setada no ambiente desta sessao"
    } else {
        $amostra = Join-Path $canon "plugin\percus-review\hooks\external-action-guard.ps1"
        if (Test-Path $amostra) { $origem = "kit" }
        else { $porque = "PERCUS_CANON_DIR aponta pra '$canon', que nao tem os hooks" }
    }

    if ($origem -ne "kit") {
        $achados.Add("o codigo dos hooks vem do CACHE, nao do kit ($porque). Conserto no kit NAO chega nesta maquina ate isso ser resolvido.")
    }

    # ---- 2. O registro vivo bate com o manifesto? ---------------------------------------
    $hooksJsonPath = Join-Path $hooksDir "hooks.json"
    if (Test-Path $hooksJsonPath) {
        $hj = Get-Content -Encoding UTF8 $hooksJsonPath -Raw | ConvertFrom-Json
        $registrados = @{}
        foreach ($ev in $hj.hooks.PSObject.Properties) {
            foreach ($bloco in @($ev.Value)) {
                foreach ($h in @($bloco.hooks)) {
                    if ($h.command -match '([^/\\"]+)\.cmd') { $registrados[$matches[1]] = $ev.Name }
                }
            }
        }
        # 6.50.0: ha DOIS caminhos de registro, e `registro` NOMEIA o dispatcher que roda o
        # check (nao existe mais o literal 'dispatcher'). Quem e rodado por um dispatcher NAO tem
        # entrada propria -- cobrar entrada dele seria falso positivo permanente, e health check
        # que grita sempre vira health check ignorado.
        $comEntradaPropria = @($vivos | Where-Object { -not $_.registro -or $_.registro -ceq 'hooks.json' })
        $faltando = @($comEntradaPropria | Where-Object { -not $registrados.ContainsKey($_.nome) } | ForEach-Object { $_.nome })
        if ($faltando.Count -gt 0) {
            $achados.Add("hook declarado no manifesto e AUSENTE do registro vivo: $($faltando -join ', ')")
        }

        # Mas o caminho do dispatcher tem a SUA propria forma de sumir calado, e ela e pior:
        # o check continua no manifesto, continua em disco, e simplesmente nunca e chamado.
        # 6.50.0: sao DOIS dispatchers, e `registro` nomeia qual roda cada check -- entao a
        # checagem e por dispatcher, nao mais sobre um unico $disp[0].
        $porNome = @{}
        foreach ($d in @($vivos | Where-Object { $_.forma -ceq 'dispatcher' })) { $porNome[$d.nome] = $d }

        $dispatchados = @($vivos | Where-Object { $_.registro -and $_.registro -cne 'hooks.json' })
        foreach ($h in $dispatchados) {
            $nomeDisp = "$($h.registro)"
            if (-not $porNome.ContainsKey($nomeDisp)) {
                $achados.Add("hook '$($h.nome)' aponta pro dispatcher '$nomeDisp', que o manifesto nao declara -- esta MUDO")
                continue
            }
            if (-not $registrados.ContainsKey($nomeDisp)) {
                $achados.Add("o dispatcher '$nomeDisp' nao esta no registro vivo -- os checks atras dele estao MUDOS")
                continue
            }
            # Gatilho ausente = a camada 1 nunca acorda aquele check. Some sem erro nenhum.
            # So vale atras de dispatcher que TRIA POR GATILHO: o de PostToolUse tria por
            # porta de tempo, e la check sem gatilho e o desenho, nao esquecimento.
            if ($porNome[$nomeDisp].triagem -ceq 'gatilhos' -and (-not $h.gatilhos -or @($h.gatilhos).Count -eq 0)) {
                $achados.Add("hook atras de '$nomeDisp' e SEM gatilho declarado (nunca sera acordado): $($h.nome)")
            }
        }

        # A porta do dispatcher de PostToolUse e chaveada por CLAUDE_CODE_SESSION_ID. Sem essa
        # variavel nao ha como isolar uma sessao da outra, e a camada 1 desliga a porta de
        # proposito (balde compartilhado silenciaria o guard de uma sessao inteira -- provado no
        # review R11 com dois processos reais). O enforcement continua correto, so mais caro.
        #
        # O aviso mora AQUI, e nao na camada 1, porque aqui ele sai UMA vez por sessao: la seria
        # uma linha de stderr em toda tool call, e aviso que repete sempre e aviso que ninguem le.
        if (@($vivos | Where-Object { $_.triagem -ceq 'porta' }).Count -gt 0 -and
            -not $env:CLAUDE_CODE_SESSION_ID) {
            $achados.Add("CLAUDE_CODE_SESSION_ID ausente: a porta do dispatcher de PostToolUse fica DESLIGADA (o guard roda em toda tool call, como antes de 6.50.0). Enforcement intacto, so mais lento.")
        }
    }

    # ---- 2b. Registro x DISCO: .ps1 de hook que ninguem declara ---------------------------
    # Defesa 3 da spec do dispatcher. A enumeracao so protege enquanto alguem a mantem; um .ps1
    # que entra no disco e nao entra no manifesto e enforcement que existe e nunca roda -- a
    # classe registrada em `categoria-nova-esquecida-em-lista-de-enumeracao`. Avisar alto e o
    # que a transforma de buraco silencioso em pendencia visivel.
    $declarados = @{}
    foreach ($h in $man.hooks) { $declarados[$h.nome] = $true }
    $naoDeclarados = @(Get-ChildItem $hooksDir -Filter *.ps1 -ErrorAction SilentlyContinue |
        Where-Object { -not $_.Name.StartsWith('_') } |
        ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) } |
        Where-Object { -not $declarados.ContainsKey($_) })
    if ($naoDeclarados.Count -gt 0) {
        $achados.Add(".ps1 em disco que o manifesto NAO declara (nunca sera chamado): $($naoDeclarados -join ', ')")
    }

    # ---- 3. O arquivo que o registro aponta existe? --------------------------------------
    $semArquivo = @()
    foreach ($h in $vivos) {
        $alvo = Join-Path $hooksDir ($h.nome + ".cmd")
        if (-not (Test-Path $alvo)) { $semArquivo += $h.nome }
    }
    if ($semArquivo.Count -gt 0) {
        $achados.Add("registro aponta pra arquivo que nao existe: $($semArquivo -join ', ')")
    }

    # ---- 4. A versao instalada e a do kit? ----------------------------------------------
    $verKit = $null; $verInst = $null
    $pjKit = Join-Path (Split-Path -Parent $hooksDir) "plugin.json"
    if (Test-Path $pjKit) { $verKit = (Get-Content -Encoding UTF8 $pjKit -Raw | ConvertFrom-Json).version }
    $cfg = $env:CLAUDE_CONFIG_DIR
    if (-not $cfg) { $cfg = Join-Path $env:USERPROFILE ".claude" }
    $instPath = Join-Path $cfg "plugins\installed_plugins.json"
    if (Test-Path $instPath) {
        try {
            $inst = Get-Content -Encoding UTF8 $instPath -Raw | ConvertFrom-Json
            $p = $inst.plugins.PSObject.Properties | Where-Object { $_.Name -like "percus-review@*" } | Select-Object -First 1
            if ($p) { $verInst = @($p.Value)[0].version }
        } catch { }
    }
    if ($verKit -and $verInst -and ($verKit -ne $verInst)) {
        $achados.Add("versao instalada ($verInst) diferente da do kit ($verKit) -- mudanca de REGISTRO (matcher, hook novo) ainda nao vale nesta maquina")
    }

    # ---- 5. O escape de emergencia virou estado permanente? ------------------------------
    # PERCUS_HOOKS_DISABLED desliga TRES camadas (hooks do plugin, git hook nativo, gate V2).
    # Como env var de USUARIO ele deixa de ser "escape declarado em voz alta" e vira silencio
    # permanente -- e o operador pode nem lembrar que setou.
    $disabledUser = [Environment]::GetEnvironmentVariable('PERCUS_HOOKS_DISABLED', 'User')
    if ($disabledUser) {
        $achados.Add("PERCUS_HOOKS_DISABLED esta setada como variavel de USUARIO (valor: '$disabledUser') -- o enforcement esta desligado de forma PERMANENTE, nao pontual. Se foi escape de uma vez so, remova.")
    }

    # ---- Fala ---------------------------------------------------------------------------
    if ($achados.Count -eq 0) {
        Falar "enforcement ok -- $($vivos.Count) hooks, codigo vindo do $origem, versao $verKit."
    } else {
        Falar "ATENCAO -- $($achados.Count) problema(s) no enforcement:"
        foreach ($a in $achados) { Falar "  - $a" }
        Falar "  (este aviso nao bloqueia nada; ele existe pra que a ausencia nao passe calada)"
    }
} catch {
    # Ate a falha do proprio health check tem que ser dita. Health check mudo e o pior estado
    # possivel: parece que esta tudo bem porque ninguem falou nada.
    Falar "o proprio health check falhou: $($_.Exception.Message) -- NAO conclua que o enforcement esta ok."
}

exit 0
