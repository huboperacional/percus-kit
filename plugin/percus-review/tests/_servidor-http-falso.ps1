#requires -Version 5.1
# Servidor HTTP roteirizado para testar retry/timeout sem rede real. Nao e *.tests.ps1: dot-source.
# Cada conexao aceita consome o proximo item do roteiro (o ultimo se repete) e incrementa
# contador.txt -- e assim que os testes afirmam "exatamente 1 requisicao" ou "2 tentativas".
# Item com pendurar=true aceita o TCP, le o pedido e NUNCA responde (o caso que travava 4 min).

function New-RespostaFalsa {
    param([int]$Status = 200, [string]$Corpo = '', [switch]$Pendurar)
    return @{ status = $Status; corpo = $Corpo; pendurar = [bool]$Pendurar }
}

function Start-ServidorFalso {
    param([object[]]$Roteiro)
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-srv-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $u8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $dir 'roteiro.json'), (ConvertTo-Json -InputObject @($Roteiro) -Depth 5), $u8)
    $servidor = @'
param([string]$Dir)
$u8 = New-Object System.Text.UTF8Encoding($false)
$roteiro = @([IO.File]::ReadAllText((Join-Path $Dir 'roteiro.json'), $u8) | ConvertFrom-Json)
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$porta = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
[IO.File]::WriteAllText((Join-Path $Dir 'porta.tmp'), "$porta", $u8)
Move-Item -LiteralPath (Join-Path $Dir 'porta.tmp') -Destination (Join-Path $Dir 'porta.txt') -Force
$pendurados = New-Object System.Collections.ArrayList
$n = 0
while ($true) {
    $cli = $listener.AcceptTcpClient()
    $idx = [Math]::Min($n, $roteiro.Count - 1)
    $item = $roteiro[$idx]
    $n++
    [IO.File]::WriteAllText((Join-Path $Dir 'contador.tmp'), "$n", $u8)
    Move-Item -LiteralPath (Join-Path $Dir 'contador.tmp') -Destination (Join-Path $Dir 'contador.txt') -Force
    try {
        $s = $cli.GetStream()
        $s.ReadTimeout = 5000
        $buf = New-Object byte[] 65536
        $ms = New-Object System.IO.MemoryStream
        $tam = -1; $fimCab = -1
        while ($true) {
            $lidos = $s.Read($buf, 0, $buf.Length)
            if ($lidos -le 0) { break }
            $ms.Write($buf, 0, $lidos)
            $txt = [Text.Encoding]::ASCII.GetString($ms.ToArray())
            if ($fimCab -lt 0) { $fimCab = $txt.IndexOf("`r`n`r`n") }
            if ($fimCab -ge 0) {
                if ($tam -lt 0) {
                    $m = [regex]::Match($txt.Substring(0, $fimCab), '(?im)^Content-Length:\s*(\d+)')
                    if ($m.Success) { $tam = [int]$m.Groups[1].Value } else { $tam = 0 }
                }
                if ($ms.Length - ($fimCab + 4) -ge $tam) { break }
            }
        }
        # Cabecalho recebido em pedido-<n>.txt (bytes crus, CRLF preservado): e assim que o teste
        # prova que o Authorization chegou, sem a chave passar pelo argv do cliente.
        $bytesPedido = $ms.ToArray()
        $fimGravar = $bytesPedido.Length
        if ($fimCab -ge 0) { $fimGravar = $fimCab + 4 }
        $cabPedido = New-Object byte[] $fimGravar
        [Array]::Copy($bytesPedido, $cabPedido, $fimGravar)
        [IO.File]::WriteAllBytes((Join-Path $Dir ("pedido-" + $n + ".txt")), $cabPedido)
        # Corpo em corpo-<n>.txt (2026-09-15, fatiamento R11): o teste afere o que cada fatia mandou.
        # ANTES do desvio de `pendurar`, de proposito: o pedido ja chegou inteiro (o laco acima le
        # ate o Content-Length), e quem pendura tambem quer poder aferir o que foi enviado.
        # $fimGravar e $fimCab + 4 sempre que $fimCab >= 0 (ver acima), entao a guarda por $fimCab
        # garante offset valido; sem cabecalho completo nao ha corpo para separar.
        if ($fimCab -ge 0 -and $bytesPedido.Length -gt $fimGravar) {
            $corpoPedido = New-Object byte[] ($bytesPedido.Length - $fimGravar)
            [Array]::Copy($bytesPedido, $fimGravar, $corpoPedido, 0, $corpoPedido.Length)
            [IO.File]::WriteAllBytes((Join-Path $Dir ("corpo-" + $n + ".txt")), $corpoPedido)
        }
        if ($item.pendurar) { [void]$pendurados.Add($cli); continue }
        $corpo = $u8.GetBytes([string]$item.corpo)
        $cab = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $($item.status) Falso`r`nContent-Type: application/json`r`nContent-Length: $($corpo.Length)`r`nConnection: close`r`n`r`n")
        $s.Write($cab, 0, $cab.Length)
        if ($corpo.Length -gt 0) { $s.Write($corpo, 0, $corpo.Length) }
        $s.Flush()
        $cli.Close()
    } catch {
        try { $cli.Close() } catch { }
    }
}
'@
    $script = Join-Path $dir 'servidor.ps1'
    [IO.File]::WriteAllText($script, $servidor, (New-Object System.Text.UTF8Encoding($true)))
    $exe = (Get-Process -Id $PID).Path
    # Aspas manuais: Start-Process junta ArgumentList com espaco sem citar.
    $proc = Start-Process -FilePath $exe -ArgumentList @('-NoProfile', '-File', ('"' + $script + '"'), '-Dir', ('"' + $dir + '"')) -PassThru -WindowStyle Hidden
    $arqPorta = Join-Path $dir 'porta.txt'
    $limite = (Get-Date).AddSeconds(20)
    while (-not (Test-Path -LiteralPath $arqPorta) -and (Get-Date) -lt $limite) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path -LiteralPath $arqPorta)) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        throw "servidor falso nao subiu em 20 s ($dir)"
    }
    $porta = [int]([IO.File]::ReadAllText($arqPorta).Trim())
    return [pscustomobject]@{ Porta = $porta; Url = "http://127.0.0.1:$porta/v1/chat/completions"; Processo = $proc; Dir = $dir }
}

function Get-ContagemServidorFalso {
    param($Servidor)
    $arq = Join-Path $Servidor.Dir 'contador.txt'
    if (-not (Test-Path -LiteralPath $arq)) { return 0 }
    return [int]([IO.File]::ReadAllText($arq).Trim())
}

function Get-PedidoServidorFalso {
    # Cabecalho cru do pedido <N> (1 = primeira conexao), ou $null se ele nao chegou.
    param($Servidor, [int]$N = 1)
    $arq = Join-Path $Servidor.Dir ("pedido-" + $N + ".txt")
    if (-not (Test-Path -LiteralPath $arq)) { return $null }
    return [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($arq))
}

function Get-CorpoServidorFalso {
    # Corpo UTF-8 do pedido <N> (1 = primeira conexao), ou $null se ele nao chegou.
    param($Servidor, [int]$N = 1)
    $arq = Join-Path $Servidor.Dir ("corpo-" + $N + ".txt")
    if (-not (Test-Path -LiteralPath $arq)) { return $null }
    return [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($arq))
}

function Stop-ServidorFalso {
    param($Servidor)
    if (-not $Servidor) { return }
    Stop-Process -Id $Servidor.Processo.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 200
    Remove-Item -Recurse -Force $Servidor.Dir -ErrorAction SilentlyContinue
}
