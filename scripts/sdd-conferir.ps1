#requires -Version 5.1
<#
.SYNOPSIS
  Confere um intervalo de commits do kit percus (ponto 14): uma chamada, uma linha por checagem.

.DESCRIPTION
  Reune as conferencias que hoje sao manuais no fim de uma tarefa SDD: arvore limpa, Base ancestral
  de Head, .sh/.cmd alterado em ASCII puro (LF exigido so de .sh; .cmd de proposito fica de fora --
  CRLF e comum em .cmd), .ps1 alterado com BOM quando tem byte alto, mensagem de commit com assunto
  e trailer Co-Authored-By, e marcador R11 gravado por commit que toca codigo. Uma linha por
  checagem: "OK|FALHA|AVISO <nome>: <detalhe>". Ultima linha: RESUMO.

  Le blobs como bytes puros (git cat-file via Process.StandardOutput.BaseStream), nunca como texto:
  a saida de texto do PowerShell perde CR e BOM.

  arvore-limpa pressupoe que o repo-alvo gitignora `.deepseek/` (assim e no percus-kit: veja o
  .gitignore do repo). Se o repo-alvo nao ignorar essa pasta, um marcador gravado por review vira
  arquivo nao-rastreado e a checagem reprova mesmo com a arvore "de fato" limpa.

  Exit: 0 sem FALHA | 1 com FALHA | 2 uso invalido (rev inexistente, repo nao-git).

.EXAMPLE
  & sdd-conferir.ps1 -Base 3784af6 -Head 71c2849
#>
[CmdletBinding()]
param(
    [string]$Base = '',
    [string]$Head = 'HEAD',
    [string]$Repo = ''
)
# SEM $ErrorActionPreference='Stop': git escreve em stderr no caminho normal (converteria em excecao).

function Write-ErroUso {
    param([string]$Motivo)
    [Console]::Error.WriteLine("[sdd-conferir] ERRO: $Motivo")
}

# --- repo ---
$baseDir = $Repo
if (-not $baseDir) { $baseDir = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $baseDir -PathType Container)) {
    Write-ErroUso "diretorio nao existe: '$baseDir'"
    exit 2
}
$top = & git -C $baseDir rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $top) {
    Write-ErroUso "'$baseDir' nao e um repositorio git"
    exit 2
}
$top = ([string]$top).Trim()

if (-not $Base) {
    Write-ErroUso "uso: sdd-conferir.ps1 -Base <rev> [-Head <rev>=HEAD] [-Repo <dir>=cwd]"
    exit 2
}
$null = & git -C $top rev-parse --verify --quiet "$Base^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) { Write-ErroUso "Base invalida: '$Base'"; exit 2 }
$null = & git -C $top rev-parse --verify --quiet "$Head^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) { Write-ErroUso "Head invalida: '$Head'"; exit 2 }
$baseSha = ([string](& git -C $top rev-parse $Base 2>$null)).Trim()
$headSha = ([string](& git -C $top rev-parse $Head 2>$null)).Trim()

# --- utilitarios ---
function Get-BlobBytes {
    param([string]$Top, [string]$BlobSha)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = "-C `"$Top`" cat-file blob $BlobSha"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    # stderr drenado por EVENTO (assincrono), nao por leitura sincrona depois do stdout: se o
    # stdout e o stderr enchessem o buffer do SO ao mesmo tempo, ler um so depois do outro trava
    # (deadlock classico de Process com os dois redirecionados). BeginErrorReadLine roda em thread
    # separada do runtime, entao o CopyTo do stdout abaixo nunca fica esperando um leitor de stderr.
    $errBuilder = New-Object System.Text.StringBuilder
    $errEvent = Register-ObjectEvent -InputObject $p -EventName ErrorDataReceived -Action {
        if ($Event.SourceEventArgs.Data) { [void]$Event.MessageData.AppendLine($Event.SourceEventArgs.Data) }
    } -MessageData $errBuilder
    try {
        $p.BeginErrorReadLine()
        $ms = New-Object System.IO.MemoryStream
        $p.StandardOutput.BaseStream.CopyTo($ms)
        $p.WaitForExit()
        $bytes = $ms.ToArray()
        $ms.Dispose()
        if ($p.ExitCode -ne 0) { throw "git cat-file blob $BlobSha falhou (exit $($p.ExitCode)): $($errBuilder.ToString())" }
        # Operador virgula: sem ele, o PowerShell desenrola o array de retorno -- um blob vazio
        # vira $null e um blob de 1 byte vira escalar [byte], quebrando .Length/indexacao no chamador.
        return , $bytes
    } finally {
        Unregister-Event -SourceIdentifier $errEvent.Name -ErrorAction SilentlyContinue
        Remove-Job -Id $errEvent.Id -Force -ErrorAction SilentlyContinue
    }
}

function Get-BlobShaEmRev {
    param([string]$Top, [string]$Rev, [string]$Caminho)
    $saida = & git -C $Top rev-parse --verify --quiet "${Rev}:${Caminho}" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $saida) { return $null }
    return ([string]$saida).Trim()
}

function Get-HashDiffCommit {
    # Identico ao hook: SHA-256 do ARQUIVO escrito por `git diff --output=`, 12 hex, minusculo.
    param([string]$Top, [string]$Sha)
    $tmp = [IO.Path]::GetTempFileName()
    try {
        & git -C $Top diff "${Sha}^" $Sha --output=$tmp 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return $null }
        $bytes = [IO.File]::ReadAllBytes($tmp)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha256.ComputeHash($bytes)) -replace '-', '').ToLower().Substring(0, 12)
        } finally { $sha256.Dispose() }
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Format-Lista {
    param([string[]]$Itens)
    if (-not $Itens -or $Itens.Count -eq 0) { return '' }
    $mostra = @($Itens | Select-Object -First 5)
    $txt = ($mostra -join ', ')
    if ($Itens.Count -gt 5) { $txt = "$txt (+$($Itens.Count - 5) mais)" }
    return $txt
}

$script:linhas = New-Object System.Collections.Generic.List[string]
$script:okN = 0
$script:falhaN = 0
$script:avisoN = 0

function Add-LinhaResultado {
    param([string]$Nome, [string]$Status, [string]$Detalhe)
    $linha = "$Status $Nome"
    if ($Detalhe) { $linha = "$Status ${Nome}: $Detalhe" }
    $script:linhas.Add($linha)
    if ($Status -eq 'OK') { $script:okN++ }
    elseif ($Status -eq 'FALHA') { $script:falhaN++ }
    else { $script:avisoN++ }
}

# 1) arvore-limpa
$statusPorcelain = @(& git -C $top status --porcelain 2>$null | Where-Object { $_ })
$exitStatus = $LASTEXITCODE
if ($exitStatus -ne 0) {
    # Sem checar o exit code, uma saida vazia por falha do git (ex.: "dubious ownership", indice
    # corrompido) passaria como arvore limpa -- falso OK. Trata como FALHA, nao como uso invalido:
    # o Base/Head/repo ja foram validados antes deste ponto.
    Add-LinhaResultado 'arvore-limpa' 'FALHA' "git status falhou (exit $exitStatus)"
} elseif ($statusPorcelain.Count -gt 0) {
    Add-LinhaResultado 'arvore-limpa' 'FALHA' (Format-Lista $statusPorcelain)
} else {
    Add-LinhaResultado 'arvore-limpa' 'OK' ''
}

# 2) base-ancestral
$null = & git -C $top merge-base --is-ancestor $baseSha $headSha 2>$null
if ($LASTEXITCODE -eq 0) {
    Add-LinhaResultado 'base-ancestral' 'OK' ''
} else {
    Add-LinhaResultado 'base-ancestral' 'FALHA' "$Base nao e ancestral de $Head"
}

# arquivos alterados no intervalo (para sh-ascii, sh-lf, ps1-bom)
$arquivosRaw = & git -C $top diff --name-only -z $baseSha $headSha 2>$null
$exitDiffNomes = $LASTEXITCODE
$arquivos = @()
if ($arquivosRaw) {
    $arquivos = @(([string]$arquivosRaw) -split "`0" | Where-Object { $_ })
}

$falhasShAscii = @()
$falhasShLf = @()
$falhasPs1Bom = @()
if ($exitDiffNomes -ne 0) {
    # Mesma logica da arvore-limpa: sem checar o exit code, uma falha do git viraria lista de
    # arquivos vazia e as tres checagens abaixo dariam falso OK por vacuidade.
    $falhasShAscii += "git diff falhou (exit $exitDiffNomes)"
    $falhasShLf += "git diff falhou (exit $exitDiffNomes)"
    $falhasPs1Bom += "git diff falhou (exit $exitDiffNomes)"
    $arquivos = @()
}
foreach ($caminho in $arquivos) {
    $ext = [IO.Path]::GetExtension($caminho).ToLowerInvariant()
    if ($ext -ne '.sh' -and $ext -ne '.cmd' -and $ext -ne '.ps1') { continue }
    $blobSha = Get-BlobShaEmRev -Top $top -Rev $headSha -Caminho $caminho
    if (-not $blobSha) { continue } # deletado no Head: nada a conferir
    $bytes = $null
    try { $bytes = Get-BlobBytes -Top $top -BlobSha $blobSha }
    catch {
        # Leitura falhou: nao da pra afirmar conformidade. Conservador, marca FALHA em vez de
        # passar em silencio (um $bytes vazio por falha de leitura pareceria arquivo OK).
        if ($ext -eq '.sh' -or $ext -eq '.cmd') { $falhasShAscii += "$caminho (leitura falhou)" }
        if ($ext -eq '.sh') { $falhasShLf += "$caminho (leitura falhou)" }
        if ($ext -eq '.ps1') { $falhasPs1Bom += "$caminho (leitura falhou)" }
        continue
    }
    if ($ext -eq '.sh' -or $ext -eq '.cmd') {
        $temByteAlto = $false
        foreach ($b in $bytes) { if ($b -ge 0x80) { $temByteAlto = $true; break } }
        if ($temByteAlto) { $falhasShAscii += $caminho }
        if ($ext -eq '.sh') {
            $temCr = $false
            foreach ($b in $bytes) { if ($b -eq 0x0D) { $temCr = $true; break } }
            if ($temCr) { $falhasShLf += $caminho }
        }
    } elseif ($ext -eq '.ps1') {
        $temBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        if (-not $temBom) {
            $temByteAlto = $false
            for ($i = 0; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -ge 0x80) { $temByteAlto = $true; break } }
            if ($temByteAlto) { $falhasPs1Bom += $caminho }
        }
    }
}

# 3) sh-ascii
if ($falhasShAscii.Count -gt 0) { Add-LinhaResultado 'sh-ascii' 'FALHA' (Format-Lista $falhasShAscii) }
else { Add-LinhaResultado 'sh-ascii' 'OK' '' }

# 4) sh-lf
if ($falhasShLf.Count -gt 0) { Add-LinhaResultado 'sh-lf' 'FALHA' (Format-Lista $falhasShLf) }
else { Add-LinhaResultado 'sh-lf' 'OK' '' }

# 5) ps1-bom
if ($falhasPs1Bom.Count -gt 0) { Add-LinhaResultado 'ps1-bom' 'FALHA' (Format-Lista $falhasPs1Bom) }
else { Add-LinhaResultado 'ps1-bom' 'OK' '' }

# commits no intervalo, sem merge. NUNCA [string] no array de saida do git: PowerShell ja quebra a
# saida multilinha em array por elemento, e o cast [string] junta tudo com espaco ($OFS).
$commits = @(& git -C $top log --no-merges --pretty=format:%H "$baseSha..$headSha" 2>$null | Where-Object { $_ })

# 6) commit-mensagem
$falhaAssunto = @()
$avisoTrailer = @()
foreach ($c in $commits) {
    $assunto = ([string](& git -C $top log -1 --pretty=format:%s $c 2>$null)).Trim()
    $curto = ([string](& git -C $top rev-parse --short $c 2>$null)).Trim()
    if (-not $assunto) { $falhaAssunto += $curto; continue }
    # NUNCA [string] no array de saida do git (mesma armadilha do $commits acima): %b pode ser
    # multilinha, e o cast juntaria tudo com espaco, apagando os \n de que o (?m) abaixo depende --
    # um trailer depois de descricao viraria falso AVISO.
    $corpo = (@(& git -C $top log -1 --pretty=format:%b $c 2>$null) -join "`n")
    if ($corpo -notmatch '(?m)^Co-Authored-By:') { $avisoTrailer += $curto }
}
if ($falhaAssunto.Count -gt 0) { Add-LinhaResultado 'commit-mensagem' 'FALHA' (Format-Lista $falhaAssunto) }
elseif ($avisoTrailer.Count -gt 0) { Add-LinhaResultado 'commit-mensagem' 'AVISO' (Format-Lista $avisoTrailer) }
else { Add-LinhaResultado 'commit-mensagem' 'OK' '' }

# 7) r11-marcador (so AVISO: o hash so bate se a arvore estava igual ao commit na hora da review)
$extsTexto = @('.md', '.txt', '.rst', '.adoc')
$reviewDir = Join-Path $top '.deepseek'
$reviewDir = Join-Path $reviewDir 'reviews'
$faltaMarcador = @()
foreach ($c in $commits) {
    $curto = ([string](& git -C $top rev-parse --short $c 2>$null)).Trim()
    $arquivosCommitRaw = & git -C $top diff-tree --no-commit-id --name-only -r -z $c 2>$null
    $exitDiffTree = $LASTEXITCODE
    if ($exitDiffTree -ne 0) {
        # Mesma classe de falso-OK por vacuidade das outras checagens: se o diff-tree falhar, a
        # lista de arquivos do commit fica vazia e $tocaCodigo nunca vira true -- o commit seria
        # pulado em silencio. Entra direto no AVISO (nunca FALHA, por contrato do check).
        $faltaMarcador += "$curto (diff-tree falhou)"
        continue
    }
    $arquivosCommit = @()
    if ($arquivosCommitRaw) { $arquivosCommit = @(([string]$arquivosCommitRaw) -split "`0" | Where-Object { $_ }) }
    $tocaCodigo = $false
    foreach ($ac in $arquivosCommit) {
        $extC = [IO.Path]::GetExtension($ac).ToLowerInvariant()
        if ($extsTexto -notcontains $extC) { $tocaCodigo = $true; break }
    }
    if (-not $tocaCodigo) { continue }
    $hash = Get-HashDiffCommit -Top $top -Sha $c
    if (-not $hash) {
        # NUNCA silencioso: se TODOS os commits do intervalo cairem aqui (ex.: commit raiz sem
        # pai), $faltaMarcador ficaria vazio e a checagem sairia OK em falso. Sem o hash nao da
        # pra confirmar o marcador, entao entra na mesma lista de AVISO (nunca vira FALHA).
        $faltaMarcador += "$curto (hash indisponivel)"
        continue
    }
    $marcador = Join-Path $reviewDir "d-$hash.jsonl"
    if (-not (Test-Path -LiteralPath $marcador -PathType Leaf)) { $faltaMarcador += $curto }
}
if ($faltaMarcador.Count -gt 0) { Add-LinhaResultado 'r11-marcador' 'AVISO' (Format-Lista $faltaMarcador) }
else { Add-LinhaResultado 'r11-marcador' 'OK' '' }

# --- saida ---
foreach ($l in $script:linhas) { Write-Output $l }
Write-Output "RESUMO ok=$script:okN falha=$script:falhaN aviso=$script:avisoN"

if ($script:falhaN -gt 0) { exit 1 } else { exit 0 }
