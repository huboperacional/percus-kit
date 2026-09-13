#requires -Version 5.1
# Harness de teste: sobe um socket local, deixa o wrapper fazer o POST de verdade nele, e
# devolve o CORPO que saiu. Nao e mock do provider -- o wrapper roda inteiro, so o destino
# muda (`-Endpoint` / `--endpoint`).
#
# Existe porque grep no fonte prova que o texto ESTA la, nao que ele SAI. Placeholder que
# ninguem substitui, ou titulo de regra que envelheceu, so aparecem olhando o que foi
# efetivamente enviado. Nao e arquivo *.tests.ps1 de proposito: o Pester nao deve descobri-lo
# como suite; quem precisa faz dot-source.

function Invoke-CapturaCorpoHttp {
    <#
      .PARAMETER Disparo
        Scriptblock que recebe a porta e devolve o Job que invoca o wrapper.
      .OUTPUTS
        O corpo da requisicao (string), ou $null se ninguem conectou dentro do timeout.
    #>
    param([scriptblock]$Disparo, [int]$TimeoutSeg = 60)

    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        $porta = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
        $job = & $Disparo $porta

        $limite = (Get-Date).AddSeconds($TimeoutSeg)
        while (-not $listener.Pending() -and (Get-Date) -lt $limite) { Start-Sleep -Milliseconds 100 }
        if (-not $listener.Pending()) {
            if ($job) { Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue }
            return $null
        }

        $cliente = $listener.AcceptTcpClient()
        $stream = $cliente.GetStream()
        $stream.ReadTimeout = 15000
        $buf = New-Object byte[] 262144
        $sb = New-Object System.Text.StringBuilder
        $tamanho = -1
        while ($true) {
            $lidos = $stream.Read($buf, 0, $buf.Length)
            if ($lidos -le 0) { break }
            [void]$sb.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $lidos))
            $txt = $sb.ToString()
            $fim = $txt.IndexOf("`r`n`r`n")
            if ($fim -ge 0) {
                if ($tamanho -lt 0) {
                    $m = [regex]::Match($txt.Substring(0, $fim), '(?im)^Content-Length:\s*(\d+)')
                    if ($m.Success) { $tamanho = [int]$m.Groups[1].Value } else { $tamanho = 0 }
                }
                $corpoLido = [System.Text.Encoding]::UTF8.GetByteCount($txt.Substring($fim + 4))
                if ($corpoLido -ge $tamanho) { break }
            }
        }

        # Resposta minima no formato Anthropic, so pra o wrapper encerrar limpo.
        $corpoResp = '{"content":[{"type":"text","text":"Sem findings criticos"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}'
        $bytesResp = [System.Text.Encoding]::UTF8.GetBytes(
            "HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nContent-Length: $($corpoResp.Length)`r`nConnection: close`r`n`r`n$corpoResp")
        $stream.Write($bytesResp, 0, $bytesResp.Length)
        $stream.Flush()
        $cliente.Close()

        if ($job) {
            Wait-Job $job -Timeout 30 | Out-Null
            Remove-Job $job -Force -ErrorAction SilentlyContinue
        }

        $texto = $sb.ToString()
        $corte = $texto.IndexOf("`r`n`r`n")
        if ($corte -lt 0) { return $null }
        return $texto.Substring($corte + 4)
    } finally {
        $listener.Stop()
    }
}
