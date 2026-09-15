<#
.SYNOPSIS
    Le documentos longos via `agy` (Gemini headless, ponto 20 do programa 32 pontos), numerando cada
    linha para que a resposta cite `[<nome>:L<a>-L<b>]`. Fatiar em varias chamadas quando o documento
    excede -MaxLinhas.

.DESCRIPTION
    Uma linha por fatia, sempre pelo protocolo stream-json do `agy` (ver
    D:\Claud Automations\percus-kit\conhecimento\fazer\gemini-agy-leitor-de-documento-longo.md para a
    invocacao medida e as armadilhas). O prompt fixo pede citacao obrigatoria; sem citacao, a fatia nao
    escreve nada. A saida .md tem um cabecalho com custo e cota, e um .json paralelo com os campos
    estruturados para outro script consumir sem reparsear markdown.

.PARAMETER Documento
    Um ou mais caminhos de arquivo, separados por virgula (ou array). Cada arquivo vira um bloco
    numerado `<nome>:L<n>| <texto>` com a numeracao ORIGINAL do arquivo (preservada entre fatias).

.PARAMETER Pergunta
    Texto da pergunta, ou `@<arquivo>` para ler de um arquivo.

.PARAMETER Saida
    Caminho do .md de saida. O .json paralelo sai em "<Saida>.json".

.PARAMETER Faixa
    Opcional, formato "<ini>-<fim>". Restringe a leitura a esse intervalo de linhas (numeracao ainda
    a original do arquivo).

.PARAMETER AgyExe
    Caminho do executavel `agy`. Se terminar em ".ps1", roda via
    `powershell.exe -NoProfile -File <ps1> <args>` -- costura de teste (agy-falso.ps1).
#>
[CmdletBinding()]
param(
    # [string], nao [string[]]: parametro array tipado sofre bind guloso quando splatado a partir
    # de um array plano de tokens (consome os tokens seguintes, incluindo outros "-Flag", em vez de
    # parar no proximo nome de parametro). O contrato ja pede lista separada por virgula num unico
    # argumento; o split por virgula acontece abaixo.
    [Parameter(Mandatory = $true)]
    [string]$Documento,

    [Parameter(Mandatory = $true)]
    [string]$Pergunta,

    [Parameter(Mandatory = $true)]
    [string]$Saida,

    [string]$Modelo = 'gemini-3.1-pro-high',

    [int]$MaxLinhas = 1500,

    [int]$TimeoutMin = 9,

    [string]$AgyExe,

    [string]$Faixa
)

$ErrorActionPreference = 'Continue'

# === Exits (contrato T1) ===
# 0 = todas as fatias com result SUCCESS e resposta nao vazia.
# 2 = uso invalido (documento ausente, faixa invalida, pergunta @arquivo ausente).
# 3 = alguma fatia vazia/sem result/escalate_admin (as outras fatias sao gravadas mesmo assim).
# 4 = agy ausente ou nao iniciou.
$EXIT_OK = 0
$EXIT_USO = 2
$EXIT_FATIA_FALHOU = 3
$EXIT_AGY_AUSENTE = 4

function Write-Erro($msg) {
    Write-Error $msg -ErrorAction Continue
}

# ProcessStartInfo.ArgumentList e' $null no .NET Framework do Windows PowerShell 5.1 desta maquina
# (medido: "Nao e possivel chamar um metodo em uma expressao de valor nulo"). Monta a string
# .Arguments a mao, com a regra de quoting do Win32 CommandLineToArgvW (aspas dobradas escapadas
# com barra invertida, barras antes de aspas dobradas).
function ConvertTo-ArgumentoCmd([string]$s) {
    if ($null -eq $s) { $s = '' }
    if ($s -eq '') { return '""' }
    if ($s -notmatch '[\s"]') { return $s }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    $barras = 0
    foreach ($c in $s.ToCharArray()) {
        if ($c -eq '\') {
            $barras++
        } elseif ($c -eq '"') {
            [void]$sb.Append('\' * (($barras * 2) + 1))
            [void]$sb.Append('"')
            $barras = 0
        } else {
            if ($barras -gt 0) { [void]$sb.Append('\' * $barras); $barras = 0 }
            [void]$sb.Append($c)
        }
    }
    if ($barras -gt 0) { [void]$sb.Append('\' * ($barras * 2)) }
    [void]$sb.Append('"')
    return $sb.ToString()
}

function New-LinhaArgumentos([string[]]$listaArgs) {
    # NAO nomear o parametro "$args": colide com a variavel automatica $args do PowerShell e a
    # funcao silenciosamente nao devolve nada (medido nesta sessao -- Arguments ficava vazio e o
    # powershell.exe filho abria sessao interativa em vez de rodar o -File).
    return (($listaArgs | ForEach-Object { ConvertTo-ArgumentoCmd $_ }) -join ' ')
}

# --- 1. Resolve AgyExe (real ou costura .ps1) ---
# Ordem: $env:AGY_EXE (configuravel por maquina/CI) -> PATH. SEM caminho de usuario/estacao
# hardcoded aqui (achado do R11, 2 rodadas seguidas): um fallback pessoal no fonte quebra em
# qualquer outro host Percus ou CI e embute identificador pessoal no repositorio. O caminho medido
# nesta sessao fica so no verbete, como exemplo, nunca no script.
if (-not $AgyExe) {
    if ($env:AGY_EXE -and (Test-Path -LiteralPath $env:AGY_EXE)) {
        $AgyExe = $env:AGY_EXE
    } else {
        $cmd = Get-Command 'agy' -ErrorAction SilentlyContinue
        if ($cmd) { $AgyExe = $cmd.Source }
    }
}
if (-not $AgyExe -or -not (Test-Path -LiteralPath $AgyExe)) {
    Write-Erro "gemini-ler-longo: agy nao encontrado (AgyExe='$AgyExe')."
    exit $EXIT_AGY_AUSENTE
}
$usaPs1 = $AgyExe.ToLowerInvariant().EndsWith('.ps1')

# --- 2. Valida documentos ---
$docsExpandidos = @()
foreach ($d in ($Documento -split ',')) {
    $d = $d.Trim()
    if ($d) { $docsExpandidos += $d }
}
if ($docsExpandidos.Count -eq 0) {
    Write-Erro 'gemini-ler-longo: -Documento vazio.'
    exit $EXIT_USO
}
foreach ($d in $docsExpandidos) {
    if (-not (Test-Path -LiteralPath $d -PathType Leaf)) {
        Write-Erro "gemini-ler-longo: documento nao existe: $d"
        exit $EXIT_USO
    }
}

# --- 3. Valida/resolve pergunta ---
if ($Pergunta.StartsWith('@')) {
    $arqPergunta = $Pergunta.Substring(1)
    if (-not (Test-Path -LiteralPath $arqPergunta -PathType Leaf)) {
        Write-Erro "gemini-ler-longo: arquivo de pergunta nao existe: $arqPergunta"
        exit $EXIT_USO
    }
    $Pergunta = [System.IO.File]::ReadAllText($arqPergunta, [System.Text.Encoding]::UTF8)
}

# --- 4. Valida faixa, se houver ---
$faixaIni = $null
$faixaFim = $null
if ($Faixa) {
    if ($Faixa -notmatch '^(\d+)-(\d+)$') {
        Write-Erro "gemini-ler-longo: -Faixa invalida: $Faixa"
        exit $EXIT_USO
    }
    $faixaIni = [int]$Matches[1]
    $faixaFim = [int]$Matches[2]
    if ($faixaIni -lt 1 -or $faixaFim -lt $faixaIni) {
        Write-Erro "gemini-ler-longo: -Faixa invalida: $Faixa"
        exit $EXIT_USO
    }
}

# -MaxLinhas <= 0 faz o fatiamento (passo 7) calcular $fimIdx < $inicio e o loop nunca avanca
# (achado do R11). MaxLinhas pequeno demais (ex.: 1) tambem pode gerar fatia vazia.
if ($MaxLinhas -lt 1) {
    Write-Erro "gemini-ler-longo: -MaxLinhas precisa ser >= 1 (recebido: $MaxLinhas)"
    exit $EXIT_USO
}

# --- 5. Le e numera cada documento (numeracao ORIGINAL do arquivo) ---
# Entrada combinada: um item por linha numerada, guardando de qual documento e qual numero original
# veio, para reconstruir "<nome>:L<a>-L<b>" por fatia mesmo quando a fatia cruza documentos.
$itens = New-Object System.Collections.Generic.List[object]
foreach ($d in $docsExpandidos) {
    $nome = Split-Path -Path $d -Leaf
    $texto = [System.IO.File]::ReadAllText($d, [System.Text.Encoding]::UTF8)
    # Normaliza quebras de linha e preserva string vazia final ausente (nao criar linha fantasma).
    $linhas = $texto -split "`r`n|`r|`n"
    if ($linhas.Count -gt 0 -and $linhas[$linhas.Count - 1] -eq '' -and $texto -match "(`r`n|`r|`n)$") {
        $linhas = $linhas[0..($linhas.Count - 2)]
    }
    for ($i = 0; $i -lt $linhas.Count; $i++) {
        $numeroOriginal = $i + 1
        if ($faixaIni -and ($numeroOriginal -lt $faixaIni -or $numeroOriginal -gt $faixaFim)) { continue }
        $itens.Add([pscustomobject]@{
            Doc      = $nome
            Linha    = $numeroOriginal
            Texto    = $linhas[$i]
            Numerada = "${nome}:L${numeroOriginal}| $($linhas[$i])"
        })
    }
}
if ($itens.Count -eq 0) {
    Write-Erro 'gemini-ler-longo: nenhuma linha para ler (documento vazio ou -Faixa fora do arquivo).'
    exit $EXIT_USO
}

# --- 6. Deteccao de cerca de codigo (``` ) e titulos `## ` fora de cerca, por item combinado ---
# O estado de cerca RESETA a cada troca de documento: uma cerca desbalanceada no fim de um arquivo
# nao pode vazar pro proximo (achado do R11) -- e com -Faixa, a cerca so e' vista dentro da propria
# faixa lida (limitacao aceita: uma cerca aberta antes do inicio da faixa nao e' detectavel).
$foraDeCerca = New-Object bool[] ($itens.Count)
$emCerca = $false
$docAnterior = $null
for ($i = 0; $i -lt $itens.Count; $i++) {
    if ($itens[$i].Doc -ne $docAnterior) {
        $emCerca = $false
        $docAnterior = $itens[$i].Doc
    }
    $t = $itens[$i].Texto
    if ($t -match '^\s*```') {
        $foraDeCerca[$i] = -not $emCerca   # a propria linha da cerca conta como "fora" antes de alternar
        $emCerca = -not $emCerca
    } else {
        $foraDeCerca[$i] = -not $emCerca
    }
}

function Test-Titulo([int]$idx) {
    return ($foraDeCerca[$idx] -and $itens[$idx].Texto -match '^## ')
}

# --- 7. Fatiamento: <= MaxLinhas, preferindo cortar num titulo `## ` fora de cerca, buscado numa
# janela de [inicio+0.8*MaxLinhas, inicio+1.2*MaxLinhas-1] (medido contra os casos do contrato: um
# titulo real perto do fim da fatia pode empurrar o corte ate 20% alem de MaxLinhas para nao partir
# uma secao ao meio; sem titulo na janela, corte duro em MaxLinhas).
$fatias = New-Object System.Collections.Generic.List[object]
$inicio = 0   # indice 0-based em $itens
$total = $itens.Count
while ($inicio -lt $total) {
    $restante = $total - $inicio
    if ($restante -le $MaxLinhas) {
        $fimIdx = $total - 1
    } else {
        $janelaIni = $inicio + [int][Math]::Floor($MaxLinhas * 0.8)
        $janelaFim = $inicio + [int][Math]::Floor($MaxLinhas * 1.2) - 1
        if ($janelaFim -gt $total - 1) { $janelaFim = $total - 1 }
        $corteEncontrado = -1
        for ($j = $janelaIni; $j -le $janelaFim; $j++) {
            if (Test-Titulo $j) { $corteEncontrado = $j; break }
        }
        if ($corteEncontrado -ge 0) {
            $fimIdx = $corteEncontrado - 1
        } else {
            $fimIdx = $inicio + $MaxLinhas - 1
        }
    }
    # Piso defensivo: nunca deixa a fatia recuar antes do proprio inicio (evita loop infinito se
    # -MaxLinhas for pequeno demais e um titulo cair bem no comeco da janela de busca).
    if ($fimIdx -lt $inicio) { $fimIdx = $inicio }
    $fatias.Add([pscustomobject]@{ IniIdx = $inicio; FimIdx = $fimIdx })
    $inicio = $fimIdx + 1
}

# --- 8. Cota antes ---
function Get-Cota([string]$agyExe, [bool]$viaPs1) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        if ($viaPs1) {
            $psi.FileName = 'powershell.exe'
            $psi.Arguments = New-LinhaArgumentos @('-NoProfile', '-File', $agyExe, '-p', '/usage')
        } else {
            $psi.FileName = $agyExe
            $psi.Arguments = New-LinhaArgumentos @('-p', '/usage')
        }
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $null = $proc.Start()
        # Le stdout E stderr em paralelo: so o stdout travava aqui, e com stderr nao-trivial o pipe
        # enche e o processo pendura (mesmo deadlock que o passo 11 evita) -- achado do R11.
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        $terminouCota = $proc.WaitForExit(30000)
        if (-not $terminouCota) {
            # Sem isto, WaitForExit(30000) e' um timeout ficticio: GetResult() logo abaixo bloqueia
            # ate EOF de verdade se o processo travar (achado do R11 nesta tarefa).
            try { $proc.Kill() } catch {}
            # Depois do Kill() os pipes fecham e as tasks terminam sozinhas; descarta sem esperar
            # mais que um instante, pra nao vazar handle nem arriscar bloquear de novo.
            try { $null = $outTask.GetAwaiter().GetResult() } catch {}
            try { $null = $errTask.GetAwaiter().GetResult() } catch {}
            return $null
        }
        $texto = $outTask.GetAwaiter().GetResult()
        $null = $errTask.GetAwaiter().GetResult()
        # Formato nao documentado (ver armadilhas do verbete): tenta achar a linha "Gemini Models ...
        # Weekly Limit Remaining"; se nao reconhecer, devolve o texto cru.
        if ($texto -match 'Gemini Models\s+Weekly Limit Remaining\s+(\S+)') {
            return $Matches[1]
        }
        return $texto.Trim()
    } catch {
        return $null
    }
}
$cotaAntes = Get-Cota -agyExe $AgyExe -viaPs1 $usaPs1

# --- 9. Prompt fixo ---
$prefixoFixo = 'Nao use ferramentas; todo o material esta nesta mensagem; toda afirmacao termina com [<nome>:L<a>-L<b>]; sem citacao = nao escreva.'

# --- 10. Regex de citacao: [<nome>:L<a>-L<b>] ou [<nome>:L<a>] ---
$reCitacao = [regex]'\[([^\]:]+):L(\d+)(?:-L(\d+))?\]'

# --- 11. Roda uma fatia via agy (stream-json), le stdout ANTES de escrever stdin (evita deadlock de
# pipe em fatias grandes -- ver verbete) ---
function Invoke-FatiaAgy {
    param(
        [string]$AgyExe,
        [bool]$ViaPs1,
        [string]$Modelo,
        [int]$TimeoutMin,
        [string]$Mensagem
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $argsAgy = @('--model', $Modelo, '--sandbox', '--disable-slash-commands',
        '--input-format', 'stream-json', '--output-format', 'stream-json',
        '--print-timeout', "${TimeoutMin}m", '-p=')
    if ($ViaPs1) {
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = New-LinhaArgumentos (@('-NoProfile', '-File', $AgyExe) + $argsAgy)
    } else {
        $psi.FileName = $AgyExe
        $psi.Arguments = New-LinhaArgumentos $argsAgy
    }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # Sem isto, o StreamReader do stdout/stderr cai no Console.OutputEncoding (codepage OEM) no
    # .NET Framework, e resposta do agy com acento/emoji sai corrompida no .md (achado do R11).
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $tempDir = Join-Path $env:TEMP ('agy-ler-' + [System.IO.Path]::GetRandomFileName().Substring(0, 8))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $psi.WorkingDirectory = $tempDir

    $resultado = [pscustomobject]@{
        Status         = $null
        Response       = $null
        Usage          = $null
        DuracaoSegundos = $null
        DeniedActions  = @()
        TemResult      = $false
        ExitCode       = $null
        InitCwd        = $null
    }

    try {
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $iniciou = $proc.Start()
        if (-not $iniciou) {
            $resultado.Status = 'ERRO_START'
            return $resultado
        }

        # Comeca a leitura assincrona de stdout/stderr ANTES de escrever no stdin.
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        $msgObj = @{ event = 'user'; message = @{ role = 'user'; content = $Mensagem } }
        $json = ($msgObj | ConvertTo-Json -Compress -Depth 10)
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json + "`n")
        $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
        $proc.StandardInput.BaseStream.Flush()
        $proc.StandardInput.BaseStream.Close()

        $timeoutMs = $TimeoutMin * 60 * 1000
        $terminou = $proc.WaitForExit($timeoutMs)
        if (-not $terminou) {
            try { $proc.Kill() } catch {}
            # Idem Get-Cota: descarta as tasks pendentes depois do Kill() em vez de abandona-las.
            try { $null = $stdoutTask.GetAwaiter().GetResult() } catch {}
            try { $null = $stderrTask.GetAwaiter().GetResult() } catch {}
            $resultado.Status = 'TIMEOUT'
            return $resultado
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $null = $stderrTask.GetAwaiter().GetResult()
        $resultado.ExitCode = $proc.ExitCode

        foreach ($linha in ($stdout -split "`n")) {
            $linha = $linha.Trim()
            if (-not $linha) { continue }
            try {
                $obj = $linha | ConvertFrom-Json -ErrorAction Stop
            } catch {
                continue
            }
            if ($obj.event -eq 'init' -and $obj.init) {
                $resultado.InitCwd = $obj.init.cwd
            } elseif ($obj.event -eq 'result' -and $obj.result) {
                $resultado.TemResult = $true
                $resultado.Status = $obj.result.status
                $resultado.Response = $obj.result.response
                $resultado.Usage = $obj.result.usage
                $resultado.DuracaoSegundos = $obj.result.duration_seconds
                if ($obj.result.denied_actions) { $resultado.DeniedActions = @($obj.result.denied_actions) }
            }
        }
    } finally {
        try {
            if (Test-Path -LiteralPath $tempDir) {
                [System.IO.Directory]::Delete($tempDir, $true)
            }
        } catch {}
    }

    return $resultado
}

# --- 12. Roda cada fatia ---
$respostasMd = New-Object System.Collections.Generic.List[string]
$fatiasFalhas = New-Object System.Collections.Generic.List[int]
$usageTotal = @{ input_tokens = 0; output_tokens = 0; thinking_tokens = 0; total_tokens = 0 }
$telemetriaFatias = New-Object System.Collections.Generic.List[object]
$segundosTotal = 0.0
$citacoesTotal = 0
$citacoesForaDaFatia = 0
$numFatias = $fatias.Count

for ($f = 0; $f -lt $numFatias; $f++) {
    $fatia = $fatias[$f]
    $subItens = @($itens.GetRange($fatia.IniIdx, $fatia.FimIdx - $fatia.IniIdx + 1))
    $materialLinhas = $subItens | ForEach-Object { $_.Numerada }
    $material = [string]::Join("`n", $materialLinhas)
    $mensagem = "$prefixoFixo`n`n$Pergunta`n`n$material"

    # Faixas por documento nesta fatia (para o cabecalho da fatia e para a checagem "fora da fatia").
    $faixasPorDoc = @{}
    foreach ($it in $subItens) {
        if (-not $faixasPorDoc.ContainsKey($it.Doc)) {
            $faixasPorDoc[$it.Doc] = [pscustomobject]@{ Min = $it.Linha; Max = $it.Linha }
        } else {
            if ($it.Linha -lt $faixasPorDoc[$it.Doc].Min) { $faixasPorDoc[$it.Doc].Min = $it.Linha }
            if ($it.Linha -gt $faixasPorDoc[$it.Doc].Max) { $faixasPorDoc[$it.Doc].Max = $it.Linha }
        }
    }
    $rotuloFaixas = ($faixasPorDoc.GetEnumerator() | ForEach-Object {
            "$($_.Key):L$($_.Value.Min)-L$($_.Value.Max)"
        }) -join ', '

    $r = Invoke-FatiaAgy -AgyExe $AgyExe -ViaPs1 $usaPs1 -Modelo $Modelo -TimeoutMin $TimeoutMin -Mensagem $mensagem

    $numFatiaHumano = $f + 1
    if ($r.Usage) {
        $usageTotal.input_tokens += [int]($r.Usage.input_tokens)
        $usageTotal.output_tokens += [int]($r.Usage.output_tokens)
        $usageTotal.thinking_tokens += [int]($r.Usage.thinking_tokens)
        $usageTotal.total_tokens += [int]($r.Usage.total_tokens)
    }
    if ($r.DuracaoSegundos) { $segundosTotal += [double]$r.DuracaoSegundos }

    # Telemetria E' POR FATIA (cada fatia e' uma chamada real ao agy): grava o usage/latencia DESTA
    # fatia, nao o acumulado ate aqui (achado do R11: gravar $usageTotal em cada linha infla o
    # gasto reportado em N vezes quando alguem soma o .jsonl inteiro).
    $telemetriaFatias.Add([pscustomobject]@{
        Usage     = if ($r.Usage) { $r.Usage } else { @{ input_tokens = 0; output_tokens = 0; thinking_tokens = 0; total_tokens = 0 } }
        LatencyMs = if ($r.DuracaoSegundos) { [int]([double]$r.DuracaoSegundos * 1000) } else { 0 }
    })

    $temEscalate = @($r.DeniedActions | Where-Object { $_.action -eq 'escalate_admin' }).Count -gt 0
    $respostaVazia = [string]::IsNullOrWhiteSpace($r.Response)

    if (-not $r.TemResult) {
        $fatiasFalhas.Add($numFatiaHumano)
        $respostasMd.Add("### Fatia $numFatiaHumano/$numFatias ($rotuloFaixas)`n`nFALHA fatia ${numFatiaHumano}/${numFatias}: sem result`n")
        continue
    }
    if ($temEscalate -and $respostaVazia) {
        $fatiasFalhas.Add($numFatiaHumano)
        $respostasMd.Add("### Fatia $numFatiaHumano/$numFatias ($rotuloFaixas)`n`nFALHA fatia ${numFatiaHumano}/${numFatias}: escalate_admin`n")
        continue
    }
    if ($respostaVazia) {
        $fatiasFalhas.Add($numFatiaHumano)
        $respostasMd.Add("### Fatia $numFatiaHumano/$numFatias ($rotuloFaixas)`n`nFALHA fatia ${numFatiaHumano}/${numFatias}: resposta vazia`n")
        continue
    }

    # Conta citacoes e citacoes fora da fatia.
    $citacoesDestaFatia = @($reCitacao.Matches($r.Response))
    foreach ($m in $citacoesDestaFatia) {
        $citacoesTotal++
        $nomeCitado = $m.Groups[1].Value
        $la = [int]$m.Groups[2].Value
        $lb = if ($m.Groups[3].Success) { [int]$m.Groups[3].Value } else { $la }
        $faixaDoc = $faixasPorDoc[$nomeCitado]
        if (-not $faixaDoc -or $la -lt $faixaDoc.Min -or $lb -gt $faixaDoc.Max) {
            $citacoesForaDaFatia++
        }
    }

    # Contrato ("sem citacao = nao escreva"): resposta nao-vazia mas SEM nenhuma citacao nao prova
    # linha nenhuma -- e' falha, nao sucesso silencioso (achado do R11).
    if ($citacoesDestaFatia.Count -eq 0) {
        $fatiasFalhas.Add($numFatiaHumano)
        $respostasMd.Add("### Fatia $numFatiaHumano/$numFatias ($rotuloFaixas)`n`nFALHA fatia ${numFatiaHumano}/${numFatias}: sem citacao`n")
        continue
    }

    $respostasMd.Add("### Fatia $numFatiaHumano/$numFatias ($rotuloFaixas)`n`n$($r.Response)`n")
}

# --- 13. Cota depois ---
$cotaDepois = Get-Cota -agyExe $AgyExe -viaPs1 $usaPs1

# --- 14. Telemetria de gasto (uma linha POR CHAMADA de fatia, com o usage DAQUELA fatia -- nao o
# acumulado; ver $telemetriaFatias no passo 12. Falha aqui nunca muda o exit.) ---
try {
    $spendDir = Join-Path (Get-Location) '.deepseek\spend'
    if (-not (Test-Path $spendDir)) { New-Item -ItemType Directory -Path $spendDir -Force | Out-Null }
    $agoraUtc = [DateTime]::UtcNow
    $spendFile = Join-Path $spendDir ($agoraUtc.ToString('yyyy-MM') + '.jsonl')
    foreach ($t in $telemetriaFatias) {
        $linha = @{
            tool       = 'gemini-ler-longo'
            provider   = 'gemini-agy'
            model      = $Modelo
            timestamp  = $agoraUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
            usage      = $t.Usage
            latency_ms = $t.LatencyMs
        } | ConvertTo-Json -Depth 5 -Compress
        # Add-Content -Encoding utf8 grava BOM na primeira linha do arquivo no Windows PowerShell
        # 5.1 (achado do R11), quebrando parser estrito de JSONL. AppendAllText com
        # UTF8Encoding($false) nunca escreve preambulo, existindo ou nao o arquivo.
        [System.IO.File]::AppendAllText($spendFile, $linha + "`n", (New-Object System.Text.UTF8Encoding($false)))
    }
} catch {
    # Silencio proposital -- telemetria nunca derruba o exit (mesmo padrao do deepseek-review.ps1).
}

# --- 15. Escreve .md ---
$cabecalho = @(
    '# gemini-ler-longo',
    '',
    "- Modelo: $Modelo",
    "- Fatias: $numFatias",
    "- Segundos: $([Math]::Round($segundosTotal, 1))",
    "- Tokens somados: $($usageTotal.total_tokens) (input=$($usageTotal.input_tokens), output=$($usageTotal.output_tokens), thinking=$($usageTotal.thinking_tokens))",
    "- Cota antes: $cotaAntes",
    "- Cota depois: $cotaDepois",
    ''
) -join "`n"
$corpoMd = $cabecalho + ($respostasMd -join "`n")
# Sem BOM, igual ao .json irmao logo abaixo (achado do R11: markdown com BOM e' inconsistente com
# o resto do par de saida e a maioria dos consumidores de .md assume UTF-8 sem preambulo). BOM em
# .ps1 e' outra regra, so' porque o Windows PowerShell 5.1 precisa dele pra ler acento no FONTE.
[System.IO.File]::WriteAllText($Saida, $corpoMd, (New-Object System.Text.UTF8Encoding($false)))

# --- 16. Escreve .json ---
$jsonSaida = @{
    documentos             = $docsExpandidos
    modelo                 = $Modelo
    fatias                 = $numFatias
    segundos               = $segundosTotal
    usage_total            = $usageTotal
    cota_antes             = $cotaAntes
    cota_depois            = $cotaDepois
    citacoes_total         = $citacoesTotal
    citacoes_fora_da_fatia = $citacoesForaDaFatia
    fatias_falhas          = @($fatiasFalhas)
} | ConvertTo-Json -Depth 6
$caminhoJson = "$Saida.json"
[System.IO.File]::WriteAllText($caminhoJson, $jsonSaida, (New-Object System.Text.UTF8Encoding($false)))

if ($fatiasFalhas.Count -gt 0) {
    exit $EXIT_FATIA_FALHOU
}
exit $EXIT_OK
