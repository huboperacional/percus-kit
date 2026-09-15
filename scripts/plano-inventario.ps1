#requires -Version 5.1
<#
.SYNOPSIS
  Inventario deterministico de secoes de um PLANO.md, e arquivamento byte a byte.

.DESCRIPTION
  Modo inventario (-Saida): le o PLANO por secao ("## " fora de cerca de codigo),
  classifica cada secao (FECHADA / ABERTA / CONTRADITORIA / SEM-MARCADOR) e confere
  referencias a commit e a caminho de arquivo (se -Repo for informado). Grava um
  array JSON em -Saida e imprime um resumo de uma linha no stdout.

  Modo arquivar (-Arquivar): move secoes ja FECHADAS do PLANO para o fim de um
  arquivo de historico, byte a byte (preserva BOM e fim de linha de cada arquivo),
  deixando uma unica linha -Ponteiro no lugar da primeira secao movida. Recusa
  (exit 3) qualquer secao que nao esteja classificada como FECHADA.

  Le e grava bytes crus ([IO.File]::ReadAllBytes / WriteAllBytes) de proposito:
  Get-Content/Set-Content do PowerShell 5.1 perdem BOM e normalizam fim de linha,
  o que quebraria a garantia de bytes removidos do PLANO = bytes acrescentados ao
  destino.

.EXAMPLE
  .\scripts\plano-inventario.ps1 -Plano .\docs\PLANO.md -Saida .\out\inventario.json
  .\scripts\plano-inventario.ps1 -Plano .\docs\PLANO.md -Repo . -Saida .\out\inventario.json
  .\scripts\plano-inventario.ps1 -Plano .\docs\PLANO.md -Arquivar 3,7 -Destino .\docs\historico\2026-09.md -Ponteiro "> Arquivado em docs/historico/2026-09.md (2026-09-15)."

.NOTES
  Exits: 0 ok; 2 uso invalido; 3 recusa (arquivar secao que nao e FECHADA).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Plano,
    [string]$Repo = "",
    [string]$Saida = "",
    # string[] de proposito: "-Arquivar 3,7" sem aspas chega ao PowerShell como
    # array de 2 elementos ("3","7"), nao como uma unica string "3,7" -- se o
    # parametro fosse [string], o binding junta os elementos com espaco (via
    # $OFS) e o -split ',' devolve um token so, quebrando o exemplo do proprio
    # .EXAMPLE. Aceitar array cobre os dois jeitos de chamar (com ou sem aspas).
    [string[]]$Arquivar = @(),
    [string]$Destino = "",
    [string]$Ponteiro = ""
)

# Write-Error + exit so garante o codigo de saida documentado no .NOTES se o
# stream de erro continuar nao-terminante; forca isso aqui em vez de confiar
# no $ErrorActionPreference herdado de quem chamou o script.
$ErrorActionPreference = 'Continue'

# === Validacao de uso — antes de tocar em qualquer arquivo ===
$modoInventario = [bool]$Saida
$modoArquivar = ($Arquivar.Count -gt 0)

if ($modoInventario -and $modoArquivar) {
    Write-Error "Use -Saida (inventario) OU -Arquivar (arquivar), nao os dois."
    exit 2
}
if (-not $modoInventario -and -not $modoArquivar) {
    Write-Error "Informe -Saida <arq.json> (modo inventario) ou -Arquivar <id,id,...> -Destino <arq> -Ponteiro <texto> (modo arquivar)."
    exit 2
}
if ($modoArquivar -and (-not $Destino -or -not $Ponteiro)) {
    Write-Error "-Arquivar exige -Destino e -Ponteiro."
    exit 2
}
if (-not (Test-Path -LiteralPath $Plano)) {
    Write-Error "Plano nao encontrado: $Plano"
    exit 2
}
if ($modoArquivar) {
    # -Destino igual a -Plano corromperia os dois: a escrita atomica do destino
    # (que roda primeiro) sobrescreveria o PLANO antes mesmo da secao ser
    # removida dele -- a secao "arquivada" simplesmente some.
    $planoResolvido = (Resolve-Path -LiteralPath $Plano).Path
    $destinoTeste = $Destino
    if (Test-Path -LiteralPath $Destino) { $destinoTeste = (Resolve-Path -LiteralPath $Destino).Path }
    if ($destinoTeste -eq $planoResolvido) {
        Write-Error "-Destino nao pode ser o mesmo arquivo que -Plano."
        exit 2
    }

    $idsPedidos = @()
    foreach ($item in $Arquivar) {
        foreach ($tok in ($item -split ',')) {
            $t = $tok.Trim()
            if ($t -eq '') { continue }
            $n = 0
            if (-not [int]::TryParse($t, [ref]$n)) {
                Write-Error "-Arquivar contem um id nao numerico: '$t'."
                exit 2
            }
            $idsPedidos += $n
        }
    }
    if ($idsPedidos.Count -eq 0) {
        Write-Error "-Arquivar nao tem nenhum id valido."
        exit 2
    }
}

# === Funcoes de baixo nivel — leitura/escrita byte a byte ===

function Get-BomInfo {
    param([byte[]]$Bytes)
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        return [pscustomobject]@{ HasBom = $true; Offset = 3 }
    }
    return [pscustomobject]@{ HasBom = $false; Offset = 0 }
}

function Split-Lines {
    # Recebe bytes (sem BOM) e devolve uma lista de byte[] por linha, cada uma
    # incluindo seu proprio terminador (CRLF ou LF) -- exceto a ultima linha, se o
    # arquivo nao terminar em quebra de linha.
    param([byte[]]$Bytes)
    $lines = New-Object System.Collections.Generic.List[byte[]]
    $start = 0
    for ($i = 0; $i -lt $Bytes.Length; $i++) {
        if ($Bytes[$i] -eq 0x0A) {
            $len = $i - $start + 1
            $line = New-Object byte[] $len
            [Array]::Copy($Bytes, $start, $line, 0, $len)
            [void]$lines.Add($line)
            $start = $i + 1
        }
    }
    if ($start -lt $Bytes.Length) {
        $len = $Bytes.Length - $start
        $line = New-Object byte[] $len
        [Array]::Copy($Bytes, $start, $line, 0, $len)
        [void]$lines.Add($line)
    }
    # Operador virgula: sem ele, um PLANO de 1 linha faz o PowerShell desenrolar
    # a List[byte[]] de 1 elemento e devolver o byte[] cru daquela linha em vez
    # da lista -- corrompe .Count e indexacao por linha em todo o resto do script.
    return ,$lines
}

# === Inventario de secoes (usado pelos dois modos) ===

function Get-Inventario {
    param(
        [System.Collections.Generic.List[byte[]]]$Lines,
        [string]$Repo
    )

    $checkMark = [string][char]0x2713
    $cCedil = [char]0x00C7
    $cAtil  = [char]0x00C3
    $palavraExecucao = "EM EXECU" + $cCedil + $cAtil + "O"
    $reMarcador = '\[[0-5](-[A-Z])?\]'
    $reFechada  = 'FECHADA|RESOLVIDO|TODOS CORRIGIDOS'

    $textos = New-Object System.Collections.Generic.List[string]
    foreach ($l in $Lines) {
        [void]$textos.Add(([System.Text.Encoding]::UTF8.GetString($l)).TrimEnd("`r", "`n"))
    }

    $emCerca = $false
    $idxHeading = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $textos.Count; $i++) {
        $trim = $textos[$i].Trim()
        if ($trim.StartsWith('```')) { $emCerca = -not $emCerca; continue }
        if ((-not $emCerca) -and $textos[$i].StartsWith('## ')) { [void]$idxHeading.Add($i) }
    }

    $out = New-Object System.Collections.Generic.List[object]
    for ($k = 0; $k -lt $idxHeading.Count; $k++) {
        $iniIdx = $idxHeading[$k]
        if ($k + 1 -lt $idxHeading.Count) { $fimIdx = $idxHeading[$k + 1] - 1 } else { $fimIdx = $textos.Count - 1 }

        $tituloLinha = $textos[$iniIdx]
        $titulo = $tituloLinha.Substring(3).Trim()
        if ($fimIdx -ge $iniIdx + 1) {
            $corpoLinhas = New-Object System.Collections.Generic.List[string]
            for ($j = $iniIdx + 1; $j -le $fimIdx; $j++) { [void]$corpoLinhas.Add($textos[$j]) }
            $corpo = [string]::Join("`n", $corpoLinhas.ToArray())
        } else {
            $corpo = ''
        }
        $textoCompleto = $tituloLinha + "`n" + $corpo

        $marcadores = [ordered]@{}
        $temMarcadorAberto = $false
        foreach ($m in [regex]::Matches($textoCompleto, $reMarcador)) {
            $v = $m.Value
            if ($marcadores.Contains($v)) { $marcadores[$v] = [int]$marcadores[$v] + 1 } else { $marcadores[$v] = 1 }
            if ($v -ne '[5-T]') { $temMarcadorAberto = $true }
        }
        $checkN = [regex]::Matches($textoCompleto, [regex]::Escape($checkMark)).Count
        if ($checkN -gt 0) { $marcadores[$checkMark] = $checkN }

        $abertaDeclarada = $temMarcadorAberto
        if (-not $abertaDeclarada) {
            if ($textoCompleto -match [regex]::Escape($palavraExecucao)) { $abertaDeclarada = $true }
            elseif ($textoCompleto -match '\bpendente\b') { $abertaDeclarada = $true }
            elseif ($textoCompleto -match '\bfalta\b') { $abertaDeclarada = $true }
        }
        $fechadaDeclarada = [bool]($textoCompleto -match $reFechada)

        if ($fechadaDeclarada -and $abertaDeclarada) { $classe = 'CONTRADITORIA' }
        elseif ($fechadaDeclarada) { $classe = 'FECHADA' }
        elseif ($abertaDeclarada) { $classe = 'ABERTA' }
        else { $classe = 'SEM-MARCADOR' }

        $datas = New-Object System.Collections.Generic.List[string]
        foreach ($m in [regex]::Matches($textoCompleto, '\d{4}-\d{2}-\d{2}')) {
            if (-not $datas.Contains($m.Value)) { [void]$datas.Add($m.Value) }
        }

        $refsCommitOk = New-Object System.Collections.Generic.List[string]
        $refsCommitAusente = New-Object System.Collections.Generic.List[string]
        foreach ($m in [regex]::Matches($textoCompleto, '`([0-9a-fA-F]{7,40})`')) {
            $hash = $m.Groups[1].Value
            # Exigir digito E letra e o contrato pedido (nao um descuido): um hex
            # entre crases tambem pega cor CSS ("`ffffff`"); a troca deliberada e
            # deixar de contar a fatia rara (~3.5%) de short-hash so-digito ou
            # so-letra em favor de nao confundir referencia real com cor.
            if ($hash -notmatch '[0-9]') { continue }
            if ($hash -notmatch '[a-fA-F]') { continue }
            if (-not $Repo) { continue }
            git -C $Repo cat-file -e "$hash^{commit}" 2>$null
            if ($LASTEXITCODE -eq 0) {
                if (-not $refsCommitOk.Contains($hash)) { [void]$refsCommitOk.Add($hash) }
            } else {
                if (-not $refsCommitAusente.Contains($hash)) { [void]$refsCommitAusente.Add($hash) }
            }
        }

        $refsCaminhoOk = New-Object System.Collections.Generic.List[string]
        $refsCaminhoAusente = New-Object System.Collections.Generic.List[string]
        foreach ($m in [regex]::Matches($textoCompleto, '`([^`\r\n]+)`')) {
            $cand = $m.Groups[1].Value
            if ($cand -notmatch '[\\/]') { continue }
            if ($cand -notmatch '\.[A-Za-z0-9]+$') { continue }
            if (-not $Repo) { continue }
            $full = Join-Path $Repo $cand
            if (Test-Path -LiteralPath $full) {
                if (-not $refsCaminhoOk.Contains($cand)) { [void]$refsCaminhoOk.Add($cand) }
            } else {
                if (-not $refsCaminhoAusente.Contains($cand)) { [void]$refsCaminhoAusente.Add($cand) }
            }
        }

        [void]$out.Add([pscustomobject]@{
            Id                 = $k + 1
            IniIdx             = $iniIdx
            FimIdx             = $fimIdx
            Titulo             = $titulo
            Marcadores         = $marcadores
            FechadaDeclarada   = $fechadaDeclarada
            AbertaDeclarada    = $abertaDeclarada
            Datas              = $datas.ToArray()
            RefsCommitOk       = $refsCommitOk.ToArray()
            RefsCommitAusente  = $refsCommitAusente.ToArray()
            RefsCaminhoOk      = $refsCaminhoOk.ToArray()
            RefsCaminhoAusente = $refsCaminhoAusente.ToArray()
            Classe             = $classe
        })
    }
    # Mesma armadilha do comentario em Split-Lines: com exatamente 1 secao, sem a
    # virgula o PowerShell desenrola e devolve o pscustomobject solto, nao a lista.
    return ,$out
}

# === Leitura do PLANO (bytes crus, BOM detectado, linhas divididas) ===

$planoBytesFull = [IO.File]::ReadAllBytes($Plano)
$bomInfo = Get-BomInfo $planoBytesFull
$conteudoBytes = New-Object byte[] ($planoBytesFull.Length - $bomInfo.Offset)
[Array]::Copy($planoBytesFull, $bomInfo.Offset, $conteudoBytes, 0, $conteudoBytes.Length)
$linhas = Split-Lines $conteudoBytes

# === Modo inventario ===

if ($modoInventario) {
    $secoes = Get-Inventario -Lines $linhas -Repo $Repo

    $resultado = New-Object System.Collections.Generic.List[object]
    foreach ($s in $secoes) {
        [void]$resultado.Add([ordered]@{
            id                = $s.Id
            linha_ini         = $s.IniIdx + 1
            linha_fim         = $s.FimIdx + 1
            titulo            = $s.Titulo
            marcadores        = $s.Marcadores
            fechada_declarada = $s.FechadaDeclarada
            aberta_declarada  = $s.AbertaDeclarada
            datas             = $s.Datas
            refs_commit       = [ordered]@{ ok = $s.RefsCommitOk; ausente = $s.RefsCommitAusente }
            refs_caminho      = [ordered]@{ ok = $s.RefsCaminhoOk; ausente = $s.RefsCaminhoAusente }
            classe            = $s.Classe
        })
    }

    if ($resultado.Count -eq 0) {
        $json = '[]'
    } elseif ($resultado.Count -eq 1) {
        $json = '[' + ($resultado[0] | ConvertTo-Json -Depth 8) + ']'
    } else {
        $json = $resultado.ToArray() | ConvertTo-Json -Depth 8
    }

    $saidaDir = Split-Path -Parent $Saida
    if ($saidaDir -and -not (Test-Path -LiteralPath $saidaDir)) {
        New-Item -ItemType Directory -Force -Path $saidaDir | Out-Null
    }
    $saidaTmp = "$Saida.tmp"
    [IO.File]::WriteAllText($saidaTmp, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $saidaTmp -Destination $Saida -Force

    $fechadasN = 0; $abertasN = 0; $contraditoriasN = 0; $refsAusentesN = 0
    foreach ($r in $resultado) {
        switch ($r.classe) {
            'FECHADA' { $fechadasN++ }
            'ABERTA' { $abertasN++ }
            'CONTRADITORIA' { $contraditoriasN++ }
        }
        $refsAusentesN += $r.refs_commit.ausente.Count + $r.refs_caminho.ausente.Count
    }
    # Write-Output (nao Write-Host): precisa ir para o stream de saida real, tanto
    # para quem le o stdout do processo quanto para quem captura via "$x = & script".
    Write-Output "secoes=$($resultado.Count) fechadas=$fechadasN abertas=$abertasN contraditorias=$contraditoriasN refs_ausentes=$refsAusentesN"
    exit 0
}

# === Modo arquivar ===

$secoes = Get-Inventario -Lines $linhas -Repo $Repo

foreach ($id in $idsPedidos) {
    $sec = $secoes | Where-Object { $_.Id -eq $id }
    if (-not $sec) {
        Write-Error "Secao id=$id nao existe no PLANO."
        exit 2
    }
    if ($sec.Classe -ne 'FECHADA') {
        Write-Error "Secao id=$id nao esta FECHADA (classe=$($sec.Classe)) -- recusado."
        exit 3
    }
}

# Offset (em bytes, relativo ao conteudo sem BOM) do inicio de cada linha.
$byteInicioLinha = New-Object int[] ($linhas.Count + 1)
$acc = 0
for ($i = 0; $i -lt $linhas.Count; $i++) {
    $byteInicioLinha[$i] = $acc
    $acc += $linhas[$i].Length
}
$byteInicioLinha[$linhas.Count] = $acc

$remover = @($secoes | Where-Object { $idsPedidos -contains $_.Id } | Sort-Object IniIdx)
$primeiraIniIdx = $remover[0].IniIdx

$blocosParaDestino = New-Object System.Collections.Generic.List[byte[]]
foreach ($sec in $remover) {
    $ini = $byteInicioLinha[$sec.IniIdx]
    $fimExcl = $byteInicioLinha[$sec.FimIdx + 1]
    $len = $fimExcl - $ini
    $bloco = New-Object byte[] $len
    [Array]::Copy($conteudoBytes, $ini, $bloco, 0, $len)
    [void]$blocosParaDestino.Add($bloco)
}

# Terminador de linha do PLANO -- olha a propria linha do heading que vira o
# ponteiro (nao a primeira linha do arquivo: um PLANO pode ter EOL misto).
$terminador = "`n"
if ($linhas.Count -gt $primeiraIniIdx) {
    $linhaHeadingTxt = [System.Text.Encoding]::UTF8.GetString($linhas[$primeiraIniIdx])
    if ($linhaHeadingTxt.EndsWith("`r`n")) { $terminador = "`r`n" }
}
$ponteiroBytes = [System.Text.Encoding]::UTF8.GetBytes($Ponteiro + $terminador)

$removerLookup = @{}
foreach ($sec in $remover) { $removerLookup[$sec.IniIdx] = $sec }

$novoPlano = New-Object System.Collections.Generic.List[byte]
$i = 0
while ($i -lt $linhas.Count) {
    if ($removerLookup.ContainsKey($i)) {
        $sec = $removerLookup[$i]
        if ($sec.IniIdx -eq $primeiraIniIdx) {
            $novoPlano.AddRange($ponteiroBytes)
        }
        $i = $sec.FimIdx + 1
        continue
    }
    $novoPlano.AddRange($linhas[$i])
    $i++
}
$novoPlanoBytes = $novoPlano.ToArray()
if ($bomInfo.HasBom) {
    $bomBytes = [byte[]](0xEF, 0xBB, 0xBF)
    $novoPlanoBytes = $bomBytes + $novoPlanoBytes
}

# Destino: preserva bytes existentes tal como estao e acrescenta os blocos movidos
# (nessa ordem). Sem separador quando o destino nasce agora (mantem a garantia de
# bytes removidos do PLANO == bytes acrescentados ao destino, sem contar o
# ponteiro). Quando o destino ja tinha conteudo e nao termina em quebra de linha,
# insere o terminador antes do primeiro bloco -- senao o ultimo paragrafo antigo
# colaria no heading movido (markdown invalido).
$destinoExistia = Test-Path -LiteralPath $Destino
if ($destinoExistia) {
    $destinoBytesAntigo = [IO.File]::ReadAllBytes($Destino)
} else {
    if ($bomInfo.HasBom) { $destinoBytesAntigo = [byte[]](0xEF, 0xBB, 0xBF) } else { $destinoBytesAntigo = [byte[]]@() }
}
$novoDestino = New-Object System.Collections.Generic.List[byte]
$novoDestino.AddRange($destinoBytesAntigo)
# So separa quando o destino JA EXISTIA e tinha conteudo sem quebra de linha no
# fim -- o BOM semeado para um destino novo nao conta como "conteudo antigo" (nao
# e' isso que dispara o cuidado de nao colar paragrafo antigo no heading movido).
$precisaSeparador = $destinoExistia -and ($destinoBytesAntigo.Length -gt 0) -and ($destinoBytesAntigo[$destinoBytesAntigo.Length - 1] -ne 0x0A)
if ($precisaSeparador) {
    $novoDestino.AddRange([System.Text.Encoding]::UTF8.GetBytes($terminador))
}
foreach ($bloco in $blocosParaDestino) { $novoDestino.AddRange($bloco) }
$novoDestinoBytes = $novoDestino.ToArray()

$destinoDir = Split-Path -Parent $Destino
if ($destinoDir -and -not (Test-Path -LiteralPath $destinoDir)) {
    New-Item -ItemType Directory -Force -Path $destinoDir | Out-Null
}

# Escrita atomica (tmp + Move-Item -Force), destino primeiro. Se o PLANO falhar,
# restaura o destino ao estado anterior -- sem isso, uma falha no meio do caminho
# deixaria a secao duplicada (nos dois arquivos) ou perdida (em nenhum).
$destinoTmp = "$Destino.tmp"
[IO.File]::WriteAllBytes($destinoTmp, $novoDestinoBytes)
Move-Item -LiteralPath $destinoTmp -Destination $Destino -Force

try {
    $planoTmp = "$Plano.tmp"
    [IO.File]::WriteAllBytes($planoTmp, $novoPlanoBytes)
    Move-Item -LiteralPath $planoTmp -Destination $Plano -Force
} catch {
    if ($destinoExistia) {
        $restauraTmp = "$Destino.restaura.tmp"
        [IO.File]::WriteAllBytes($restauraTmp, $destinoBytesAntigo)
        Move-Item -LiteralPath $restauraTmp -Destination $Destino -Force
    } else {
        # Destino nao existia antes desta chamada -- restaurar "estado anterior"
        # significa apagar o arquivo que acabamos de criar, nao deixar um residuo
        # (vazio ou so BOM) para tras.
        Remove-Item -LiteralPath $Destino -Force -ErrorAction SilentlyContinue
    }
    Write-Error "Falha ao escrever o PLANO; destino restaurado. $_"
    exit 1
}

Write-Output "Arquivadas $($remover.Count) secao(oes) de '$Plano' para '$Destino'."
exit 0
