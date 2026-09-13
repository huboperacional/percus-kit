# Utilitarios dos testes de paridade .ps1/.sh dos dispatchers (dot-source no BeforeAll).
# Nao e arquivo de teste: o rodar-suite so coleta *.tests.ps1.
#
# O MOLDE, e por que cada funcao existe (verbetes regra-duplicada-ps1-sh e
# paridade-testada-no-caso-facil-nao-e-paridade):
#
#  - Invoke-Runtime roda UM runtime; os testes rodam os DOIS contra o mesmo payload e comparam.
#    Dois testes independentes, um por lado, ficam verdes lado a lado enquanto divergem.
#  - O lado Windows e o `.cmd` real (camada 1 cmd.exe -> camada 2 powershell.exe), nao o `.ps1`
#    solto: e ele que o hooks.json chama, e a camada 1 tem comportamento proprio (triagem,
#    porta, fallback) que o `.ps1` sozinho nao exercita.
#  - Fixture ISOLADO (diretorio temporario com copias dos dispatchers, manifesto e checks
#    sinteticos): os checks reais tem paridade propria, e mistura-los aqui faria divergencia de
#    CHECK parecer divergencia de dispatcher.
#  - PERCUS_CANON_DIR e apagado em toda chamada: setado, o trampolim desviaria as duas camadas
#    para o kit e o teste mediria o repo, nao o fixture.

$script:kitHooks = Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks'
$script:utf8 = New-Object Text.UTF8Encoding($false)

$script:bash = (Get-Command bash -ErrorAction SilentlyContinue).Source
if (-not $script:bash) {
    # O pwsh aberto fora do Git Bash nao tem bash no PATH (medido 2026-09-13). Sem este fallback
    # todo teste .sh vira Skipped -- paridade "provada" por teste que nao rodou.
    $script:bash = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe") |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

# Codepage OEM da maquina: e a que o cmd.exe dos hooks recebe (ver Invoke-Runtime). Lida do
# registro para a pre-condicao dos testes comparar com a que o .cmd de fato recebeu.
$script:oemcp = [string](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage' -ErrorAction SilentlyContinue).OEMCP

function Get-CodepageDoCmdDeTeste {
    # A codepage que o .cmd recebe no Invoke-Runtime (mesmo console novo e oculto). Com isto a
    # premissa "o teste roda na codepage do harness" e PROVADA a cada execucao, nao suposta.
    $o = Join-Path $script:raizTmp ([Guid]::NewGuid().ToString('N') + '.cp')
    $null = Start-Process -FilePath $env:ComSpec -ArgumentList @('/c', 'chcp') -RedirectStandardOutput $o `
        -WindowStyle Hidden -Wait -PassThru
    $t = [IO.File]::ReadAllText($o)
    [IO.File]::Delete($o)
    if ($t -match '(\d+)\s*$') { return $matches[1] }
    return $null
}

# runId escopa tudo que este arquivo cria: o rodar-suite roda arquivos de teste EM PARALELO, e uma
# limpeza por padrao generico apagaria os carimbos de porta do OUTRO arquivo no meio da execucao.
$script:runId = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$script:raizTmp = Join-Path ([IO.Path]::GetTempPath()) ('percus-par-' + $script:runId)
New-Item -ItemType Directory -Force -Path $script:raizTmp | Out-Null

# Variaveis que mudam o comportamento dos dispatchers. Toda chamada parte delas VAZIAS: a suite
# roda dentro de sessao do Claude Code, que herda CLAUDE_CODE_SESSION_ID e PERCUS_CANON_DIR.
$script:envBase = @(
    'PERCUS_HOOKS_DISABLED', 'PERCUS_DISPATCHER_BYPASS', 'PERCUS_DISPATCH_DEBUG', 'PERCUS_CANON_DIR',
    'CLAUDE_CODE_SESSION_ID', 'PERCUS_POST_PORTA_SEGUNDOS', 'PERCUS_CTX_WINDOW'
)

$script:enchimento = '# check sintetico de teste de paridade. Este comentario existe para o arquivo passar dos 200 bytes do tripwire de integridade dos dispatchers, que trata arquivo menor como instalacao corrompida.'

function New-CheckPar {
    # Escreve o MESMO check nos dois runtimes.
    #   -Fala     linha em stderr
    #   -Ve       ecoa em stderr o comando recebido: prova que o payload foi re-alimentado ao
    #             check, e nao so que o check rodou
    #   -Emite    texto no STDOUT; '{TOOL}' vira o tool_name do payload (mesma prova do -Ve)
    #   -Truncado arquivo abaixo dos 200 bytes do tripwire
    param([string]$Dir, [string]$Nome, [int]$Rc = 0, [string]$Fala = '', [switch]$Ve,
          [string]$Emite = '', [switch]$Truncado)
    if ($Truncado) {
        [IO.File]::WriteAllText((Join-Path $Dir "$Nome.ps1"), "exit 0`n", $script:utf8)
        [IO.File]::WriteAllText((Join-Path $Dir "$Nome.sh"), "exit 0`n", $script:utf8)
        return
    }
    $ps = @($script:enchimento, '$bruto = [Console]::In.ReadToEnd()')
    $sh = @('#!/usr/bin/env bash', $script:enchimento, 'BRUTO=$(cat)')
    if ($Ve) {
        $ps += "[Console]::Error.WriteLine('$Nome viu: ' + (`$bruto | ConvertFrom-Json).tool_input.command)"
        $sh += "echo `"$Nome viu: `$(printf '%s' `"`$BRUTO`" | jq -r '.tool_input.command')`" >&2"
    }
    if ($Fala) {
        $ps += "[Console]::Error.WriteLine('$Fala')"
        $sh += "echo '$Fala' >&2"
    }
    if ($Emite) {
        # Write-Output e nao [Console]::Out: a camada 2 do .ps1 captura o PIPELINE do `& script`.
        $ps += "Write-Output ('$($Emite.Replace("'", "''"))'.Replace('{TOOL}', [string](`$bruto | ConvertFrom-Json).tool_name))"
        $sh += "T='$Emite'; TOOL=`$(printf '%s' `"`$BRUTO`" | jq -r '.tool_name'); printf '%s' `"`${T//'{TOOL}'/`$TOOL}`""
    }
    $ps += "exit $Rc"
    $sh += "exit $Rc"
    [IO.File]::WriteAllText((Join-Path $Dir "$Nome.ps1"), ($ps -join "`n") + "`n", $script:utf8)
    [IO.File]::WriteAllText((Join-Path $Dir "$Nome.sh"), ($sh -join "`n") + "`n", $script:utf8)
}

function New-Entrada {
    # -RegistradoCru grava em `registrado` um valor NAO booleano (0, "", []). O .ps1 decide pela
    # verdade do PowerShell e o jq pela dele, e as duas discordam nesses valores (achado do R11
    # Cross-Claude, 2026-09-13). Atribuido direto na hashtable: passar @() por `if` desenrolaria o
    # array vazio em $null.
    param([string]$Nome, [string]$Evento = 'PreToolUse', [string]$Matcher = 'Bash|PowerShell',
          [object]$Gatilhos = $null, [bool]$Registrado = $true, [string]$Registro = 'percus-dispatch-pre',
          [object]$RegistradoCru)
    $h = [ordered]@{ nome = $Nome; evento = $Evento; matcher = $Matcher; forma = 'guarda'
                     registrado = $Registrado; registro = $Registro }
    if ($PSBoundParameters.ContainsKey('RegistradoCru')) { $h.registrado = $RegistradoCru }
    if ($null -ne $Gatilhos) { $h.gatilhos = @($Gatilhos) }
    return $h
}

function New-Fixture {
    # Diretorio com copias dos dispatchers do kit + manifesto sintetico.
    #   -Gatilhos     linhas do gatilhos-pre.txt, gravadas em CRLF como o real: grep -f do bash
    #                 levaria o \r junto e nunca casaria
    #   -ManifestoCru texto literal do manifesto (para o caso ilegivel)
    param([ValidateSet('pre', 'post')][string]$Evento, [object[]]$Hooks = @(),
          [string[]]$Gatilhos = @('zeta', 'omega'), [string]$ManifestoCru = $null,
          [switch]$SemGatilhos, [string]$Porta = '30')
    $d = Join-Path $script:raizTmp ([Guid]::NewGuid().ToString('N').Substring(0, 10))
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    foreach ($ext in 'cmd', 'ps1', 'sh') {
        $src = Join-Path $script:kitHooks "percus-dispatch-$Evento.$ext"
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $d }
    }
    $man = if ($ManifestoCru) { $ManifestoCru } else { @{ hooks = @($Hooks) } | ConvertTo-Json -Depth 6 }
    [IO.File]::WriteAllText((Join-Path $d 'hooks-manifest.json'), $man, $script:utf8)
    if ($Evento -eq 'pre' -and -not $SemGatilhos) {
        [IO.File]::WriteAllText((Join-Path $d 'gatilhos-pre.txt'), (($Gatilhos | ForEach-Object { "$_`r`n" }) -join ''), $script:utf8)
    }
    if ($Evento -eq 'post' -and $Porta) {
        [IO.File]::WriteAllText((Join-Path $d 'porta-post.txt'), "$Porta`n", $script:utf8)
    }
    return $d
}

function Invoke-Runtime {
    # Roda o dispatcher de UM runtime com o payload em stdin. Devolve exit code, stdout e stderr.
    param([ValidateSet('cmd', 'sh')][string]$Runtime, [ValidateSet('pre', 'post')][string]$Evento,
          [string]$Dir, [string]$Payload, [hashtable]$Env = @{}, [string]$Bash = $script:bash)
    $id = [Guid]::NewGuid().ToString('N')
    $tmpIn = Join-Path $script:raizTmp "$id.in"
    $tmpOut = Join-Path $script:raizTmp "$id.out"
    $tmpErr = Join-Path $script:raizTmp "$id.err"
    [IO.File]::WriteAllText($tmpIn, $Payload, $script:utf8)
    $antigos = @{}
    foreach ($k in (@($script:envBase) + @($Env.Keys) | Sort-Object -Unique)) {
        $antigos[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $(if ($Env.ContainsKey($k)) { $Env[$k] } else { $null }))
    }
    try {
        $sp = @{ RedirectStandardInput = $tmpIn; RedirectStandardOutput = $tmpOut
                 RedirectStandardError = $tmpErr; Wait = $true; PassThru = $true }
        if ($Runtime -eq 'cmd') {
            # CONSOLE NOVO E OCULTO, e nao -NoNewWindow: console novo nasce na codepage padrao (OEM),
            # que e a do cmd.exe dos hooks; -NoNewWindow herdaria a do pwsh que roda a suite (65001
            # aqui). Nao e detalhe -- medido 2026-09-13: `set /p` de arquivo com BOM le "3600" VALIDO
            # em 65001 e LIXO em 850. Na codepage herdada o .cmd honrava uma porta que em producao
            # ignora, e o .sh (que imita a producao) parecia o divergente. Mesma fronteira do verbete
            # cmd-com-byte-nao-ascii-desalinha-o-cmd-exe-e-come-o-inicio-das-linhas.
            # E NAO `chcp 850 & dispatcher`: o chcp LE STDIN, e o dispatcher recebia payload vazio
            # (medido: `chcp 850 >nul & findstr "^"` sai vazio) -- alem de deixar o console do pwsh
            # preso na 850 depois.
            $sp.FilePath = $env:ComSpec
            $sp.ArgumentList = @('/c', "`"$(Join-Path $Dir "percus-dispatch-$Evento.cmd")`"")
            $sp.WindowStyle = 'Hidden'
        } else {
            $sp.FilePath = $Bash
            $sp.ArgumentList = @("`"$((Join-Path $Dir "percus-dispatch-$Evento.sh").Replace('\', '/'))`"")
            $sp.NoNewWindow = $true
        }
        $p = Start-Process @sp
        [pscustomobject]@{
            Runtime  = $Runtime
            ExitCode = $p.ExitCode
            Stdout   = [IO.File]::ReadAllText($tmpOut)
            Stderr   = [IO.File]::ReadAllText($tmpErr)
        }
    } finally {
        foreach ($k in $antigos.Keys) { [Environment]::SetEnvironmentVariable($k, $antigos[$k]) }
        foreach ($t in $tmpIn, $tmpOut, $tmpErr) { Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue }
    }
}

function Invoke-BashComando {
    # Comando de bash com o ambiente trocado do mesmo jeito que o Invoke-Runtime troca. Serve para
    # PROVAR a pre-condicao de um cenario (ex.: "o jq de fato sumiu"): sem isso, o cenario pode
    # passar pelo caminho normal e o teste medir outra coisa -- foi o que aconteceu na 1a versao.
    param([string]$Bash, [string]$Comando, [hashtable]$Env = @{})
    $antigos = @{}
    foreach ($k in $Env.Keys) {
        $antigos[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $Env[$k])
    }
    try { return ((& $Bash -c $Comando 2>&1) -join "`n") }
    finally { foreach ($k in $antigos.Keys) { [Environment]::SetEnvironmentVariable($k, $antigos[$k]) } }
}

function Get-EnvSemJq {
    # Bash SEM o lancador (Git\bin\bash.exe re-adiciona %HOME%\bin ao PATH, e o jq desta maquina
    # mora la -- medido 2026-09-13) e HOME apontando para um diretorio vazio.
    return [pscustomobject]@{
        Bash = "$env:ProgramFiles\Git\usr\bin\bash.exe"
        Env  = @{ PATH = "$env:ProgramFiles\Git\usr\bin"; HOME = $script:raizTmp }
    }
}

function Format-Stderr {
    # Normaliza SO o que e do transporte ou do runtime, nunca o conteudo:
    #  - CRLF (cmd.exe) x LF (bash);
    #  - a extensao do arquivo citado (`fantasma.ps1` x `fantasma.sh`, `x.cmd` x `x.sh`);
    #  - o texto da excecao do .NET no manifesto ilegivel, que nao existe no bash;
    #  - a linha "Causa provavel:" do payload invalido, que DEVE diferir: no .cmd a causa e a
    #    captura de stdin truncando, e no bash nao ha captura. Quem usa confere que os dois a tem.
    param([string]$Texto)
    if (-not $Texto) { return '' }
    $linhas = ($Texto -replace "`r`n", "`n") -split "`n" |
        ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -ne '' } |
        Where-Object { $_ -notmatch '^\s*Causa provavel:' } |
        ForEach-Object { $_ -replace '\b([A-Za-z0-9_-]+)\.(ps1|sh|cmd)\b', '$1.<ext>' } |
        ForEach-Object { $_ -replace '(hooks-manifest\.json ilegivel):.*$', '$1:' }
    return (@($linhas) -join "`n")
}

function ConvertTo-JsonCanonico {
    # Chaves ordenadas: o .ps1 serializa um @{} (ordem de hashtable, arbitraria) e o jq preserva a
    # ordem de construcao. Quem le e o harness, que parseia -- ordem nao e comportamento.
    param([string]$Texto)
    if (-not $Texto) { return '' }
    function Ordena($v) {
        if ($v -is [System.Management.Automation.PSCustomObject]) {
            $h = [ordered]@{}
            foreach ($n in ($v.PSObject.Properties.Name | Sort-Object)) { $h[$n] = Ordena $v.$n }
            return $h
        }
        if ($v -is [array]) { return , @($v | ForEach-Object { Ordena $_ }) }
        return $v
    }
    return ((Ordena ($Texto | ConvertFrom-Json)) | ConvertTo-Json -Depth 10 -Compress)
}

function Assert-Paridade {
    # Exit code e stderr SEMPRE iguais. Stdout: -StdoutJson compara canonizado; sem ele, byte a byte.
    param($Cmd, $Sh, [switch]$StdoutJson)
    $Sh.ExitCode | Should -Be $Cmd.ExitCode -Because "exit code diverge (cmd=$($Cmd.ExitCode), sh=$($Sh.ExitCode)). stderr do sh: $($Sh.Stderr)"
    (Format-Stderr $Sh.Stderr) | Should -BeExactly (Format-Stderr $Cmd.Stderr) -Because 'stderr diverge entre os runtimes'
    if ($StdoutJson) {
        (ConvertTo-JsonCanonico $Sh.Stdout) | Should -BeExactly (ConvertTo-JsonCanonico $Cmd.Stdout) -Because 'stdout (JSON) diverge'
    } else {
        $Sh.Stdout | Should -BeExactly $Cmd.Stdout -Because 'stdout diverge'
    }
}

function Remove-FixturesParidade {
    Remove-Item -LiteralPath $script:raizTmp -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem ([IO.Path]::GetTempPath()) -Filter "percus-post-gate*par-$($script:runId)-*" -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
