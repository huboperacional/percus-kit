#requires -Version 5.1
<#
.SYNOPSIS
  Registra no marcador R11 uma review feita fora do cliente DeepSeek (ex.: subagente Cross-Claude).

.DESCRIPTION
  Existe porque, com a DeepSeek fora, o wrapper pedia o subagente mas nao havia jeito suportado de
  gravar o resultado: em 2026-09-14 o hash foi calculado a mao e o d-<hash>.jsonl escrito na unha.
  Hash IGUAL ao do hook (SHA-256 do arquivo de `git diff HEAD --output=`, 12 hex). Grava primeiro
  d-<hash>.jsonl e depois latest.jsonl, cada um por arquivo temporario unico + troca. Se a segunda
  gravacao falhar, desfaz a primeira: remove o d-<hash>.jsonl que nao existia antes ou restaura o
  conteudo anterior do que ja existia (a mensagem do exit 3 diz qual).

  Saida de sucesso pelo pipeline: `$r = & registrar-review.ps1 ...` captura `hash=<h> latest=<c> d=<c>`.
  Embutido, nao altera [Console]::OutputEncoding do chamador; com -File, o stdout sai em UTF-8.

  Exit: 0 ok | 1 ambiente/hash vazio | 2 entrada recusada | 3 falha de gravacao (desfeita).

.EXAMPLE
  & registrar-review.ps1 -Arquivo findings.txt -Canal cross-claude -Modelo claude-sonnet-5
#>
[CmdletBinding()]
param(
    [string]$Arquivo = "",
    [string]$Canal = "",
    [string]$Modelo = "",
    [string]$Repo = ""
)
# SEM $ErrorActionPreference='Stop': no 5.1 ele transforma stderr do git em excecao mesmo com 2>$null.
$u8 = New-Object System.Text.UTF8Encoding($false)
$ws = [char[]]@(32, 9, 10, 13)

# Processo proprio (-File) x embutido (& script.ps1): pela linha de comando do processo, nao por $Host.Name
# (ConsoleHost nos dois). Processo proprio: stdout em UTF-8 ate o fim. Embutido: a codificacao do chamador
# fica como estava; so a leitura da saida do git e trocada, e desfeita logo depois.
# So vale o script do -File (ou, sem -File, o primeiro .ps1 existente): um chamador `-File chamador.ps1
# -Reg <este script>` tem o caminho deste script na linha de comando e continua sendo embutido.
$processoProprio = $false
$argsProc = @([Environment]::GetCommandLineArgs() | Select-Object -Skip 1)
$scriptDoProcesso = $null
for ($i = 0; $i -lt $argsProc.Count; $i++) {
    if ([string]$argsProc[$i] -match '^[-/](f|fi|fil|file)$') {
        if ($i + 1 -lt $argsProc.Count) { $scriptDoProcesso = [string]$argsProc[$i + 1] }
        break
    }
    if ([string]$argsProc[$i] -match '^[-/](c|co|com|comm|comma|comman|command|e|ec|en|enc|encodedcommand)$') { break }
    $cand = ([string]$argsProc[$i]).Trim('"', "'")
    if ($cand -and -not $cand.StartsWith('-') -and $cand.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $cand -PathType Leaf)) {
        $scriptDoProcesso = $cand
        break
    }
}
if ($scriptDoProcesso) {
    $a = $scriptDoProcesso.Trim('"', "'")
    try {
        if ([string]::Equals([IO.Path]::GetFullPath($a), $PSCommandPath, [StringComparison]::OrdinalIgnoreCase)) { $processoProprio = $true }
        elseif ([string]::Equals([IO.Path]::GetFileName($a), [IO.Path]::GetFileName($PSCommandPath), [StringComparison]::OrdinalIgnoreCase)) {
            # O proprio script por outra grafia do caminho (ex.: nome 8.3 curto do %TEMP%).
            $processoProprio = $true
        }
    } catch { }
}
if ($processoProprio) {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
}

function Stop-Registro {
    param([int]$Codigo, [string]$Motivo)
    [Console]::Error.WriteLine("[registrar-review] ERRO: $Motivo")
    exit $Codigo
}

function Invoke-GitTexto {
    # Saida de git em UTF-8 (caminho com acento). Embutido: troca a codificacao so durante a chamada.
    param([string[]]$Argumentos)
    $encAntes = $null
    if (-not $processoProprio) {
        try { $encAntes = [Console]::OutputEncoding; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { $encAntes = $null }
    }
    try {
        $saida = & git @Argumentos 2>$null
        $script:gitExit = $LASTEXITCODE
        return $saida
    } finally {
        if ($null -ne $encAntes) { try { [Console]::OutputEncoding = $encAntes } catch { } }
    }
}

function Write-Atomico {
    # Temporario unico por processo + troca: nunca ha conteudo parcial nem intercalado no destino.
    param([string]$Destino, [string]$Conteudo, [byte[]]$Bytes)
    if (Test-Path -LiteralPath $Destino -PathType Container) { throw "destino e um diretorio: $Destino" }
    $tmp = "$Destino.$PID." + [Guid]::NewGuid().ToString('N').Substring(0, 8) + ".tmp"
    try {
        if ($PSBoundParameters.ContainsKey('Bytes')) { [IO.File]::WriteAllBytes($tmp, $Bytes) }
        else { [IO.File]::WriteAllText($tmp, $Conteudo, $u8) }
        if (Test-Path -LiteralPath $Destino -PathType Leaf) {
            [IO.File]::Replace($tmp, $Destino, [NullString]::Value)
        } else {
            try { [IO.File]::Move($tmp, $Destino) }
            catch [System.IO.IOException] { [IO.File]::Replace($tmp, $Destino, [NullString]::Value) }
        }
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

# --- entrada ---
if ([string]::IsNullOrWhiteSpace($Arquivo) -or -not (Test-Path -LiteralPath $Arquivo -PathType Leaf)) { Stop-Registro 2 "arquivo de findings ausente: '$Arquivo'" }
if ([string]::IsNullOrWhiteSpace($Canal)) { Stop-Registro 2 "canal vazio (use -Canal cross-claude)" }
$caminhoArq = (Resolve-Path -LiteralPath $Arquivo).Path
$tam = (Get-Item -LiteralPath $caminhoArq).Length
if ($tam -gt 262144) { Stop-Registro 2 "findings acima do teto (256 KB): $tam bytes" }
$bytes = [IO.File]::ReadAllBytes($caminhoArq)
$ini = 0
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $ini = 3 }
$texto = $u8.GetString($bytes, $ini, $bytes.Length - $ini)
$limpo = $texto.Trim($ws)
if ($limpo.Length -eq 0) { Stop-Registro 2 "findings vazio ou so espaco" }
# So o arquivo que e INTEIRO um objeto placeholder e recusado; texto livre citando "deferred" passa.
if ($limpo.StartsWith('{')) {
    $obj = $null
    try { $obj = ConvertFrom-Json -InputObject $texto -ErrorAction Stop } catch { $obj = $null }
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $obj.PSObject.Properties) {
            if (($p.Name -ceq 'deferred' -or $p.Name -ceq 'placeholder') -and ($p.Value -is [bool]) -and $p.Value) {
                Stop-Registro 2 "o arquivo e um placeholder ($($p.Name):true), nao uma review"
            }
        }
    }
}
if ($texto.Contains('__PERCUS_NEEDS_CROSS_CLAUDE__')) { Stop-Registro 2 "o texto contem o marcador __PERCUS_NEEDS_CROSS_CLAUDE__ -- isso e o pedido de review, nao a review" }

# --- repo ---
$baseDir = $Repo
if (-not $baseDir) { $baseDir = (Get-Location).Path }
if (-not (Test-Path -LiteralPath $baseDir -PathType Container)) { Stop-Registro 2 "diretorio do repo nao existe: '$baseDir'" }
$script:gitExit = 1
$top = Invoke-GitTexto @('-C', $baseDir, 'rev-parse', '--show-toplevel')
if ($script:gitExit -ne 0 -or -not $top) { Stop-Registro 2 "'$baseDir' nao e um repositorio git" }
$top = ([string]$top).Trim()
$null = & git -C $top rev-parse --verify --quiet 'HEAD^{commit}' 2>$null
if ($LASTEXITCODE -ne 0) { Stop-Registro 2 ('reposit' + [char]0x00F3 + 'rio sem commit') }

# --- hash (identico ao hook) ---
$tmpDiff = [IO.Path]::GetTempFileName()
$hash = $null
$diffLinhas = 0
try {
    & git -C $top diff HEAD --output=$tmpDiff 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-Registro 1 "git diff HEAD falhou (exit $LASTEXITCODE) -- hash vazio, nada gravado" }
    $diffBytes = [IO.File]::ReadAllBytes($tmpDiff)
    if ($diffBytes.Length -eq 0) { Stop-Registro 2 "git diff HEAD vazio -- nao ha o que registrar" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = ([BitConverter]::ToString($sha.ComputeHash($diffBytes)) -replace '-', '').ToLower().Substring(0, 12)
    # Latin-1 decodifica 1 byte = 1 char: conta 0x0A sem laco por byte (lento no 5.1 em diff grande).
    $diffLinhas = [Text.Encoding]::GetEncoding(28591).GetString($diffBytes).Split([char]10).Count - 1
} finally { Remove-Item -LiteralPath $tmpDiff -Force -ErrorAction SilentlyContinue }
if (-not $hash -or $hash -eq 'e3b0c44298fc') { Stop-Registro 1 "hash vazio -- nada gravado" }

# --- gravacao: d-<hash> primeiro, latest depois, desfaz em falha ---
$reviewDir = Join-Path $top '.deepseek'
$reviewDir = Join-Path $reviewDir 'reviews'
$dPath = Join-Path $reviewDir "d-$hash.jsonl"
$latestPath = Join-Path $reviewDir 'latest.jsonl'
$modeloJson = $null
if ($Modelo) { $modeloJson = $Modelo }
$agora = [DateTime]::UtcNow
$json = [ordered]@{
    timestamp  = $agora.ToString('yyyy-MM-ddTHH:mm:ssZ')
    base       = ''
    diff_lines = $diffLinhas
    model      = $modeloJson
    usage      = $null
    findings   = $texto
    canal      = $Canal
} | ConvertTo-Json -Compress -Depth 3
try {
    New-Item -ItemType Directory -Force -Path $reviewDir -ErrorAction Stop | Out-Null
} catch {
    Stop-Registro 3 "nao consegui criar $reviewDir ($($_.Exception.Message)) -- nada gravado"
}
# d-<hash> pre-existente (ex.: review anterior do mesmo diff): copia antes de gravar, para restaurar e nao apagar.
$backup = $null
if (Test-Path -LiteralPath $dPath -PathType Leaf) {
    $backup = "$dPath.$PID." + [Guid]::NewGuid().ToString('N').Substring(0, 8) + ".bak"
    try { [IO.File]::Copy($dPath, $backup, $false) }
    catch {
        try { [IO.File]::Delete($backup) } catch { }
        Stop-Registro 3 "nao consegui copiar o d-$hash.jsonl pre-existente ($($_.Exception.Message)) -- nada gravado"
    }
}
$dGravado = $false
try {
    Write-Atomico -Destino $dPath -Conteudo ($json + "`n"); $dGravado = $true
    Write-Atomico -Destino $latestPath -Conteudo ($json + "`n")
} catch {
    $erroGravacao = $_.Exception.Message
    if (-not $dGravado) {
        if ($backup) { try { [IO.File]::Delete($backup) } catch { } }
        Stop-Registro 3 "falha ao gravar marcador ($erroGravacao) -- nada gravado"
    }
    if (-not $backup) {
        Remove-Item -LiteralPath $dPath -Force -ErrorAction SilentlyContinue
        Stop-Registro 3 "falha ao gravar marcador ($erroGravacao) -- d-$hash.jsonl nao existia antes e foi removido"
    }
    # Restauracao atomica; o backup so sai depois de conferido byte a byte no destino.
    $restaurado = $false
    try {
        $anterior = [IO.File]::ReadAllBytes($backup)
        Write-Atomico -Destino $dPath -Bytes $anterior
        $atual = [IO.File]::ReadAllBytes($dPath)
        $restaurado = ($atual.Length -eq $anterior.Length) -and ([Convert]::ToBase64String($atual) -ceq [Convert]::ToBase64String($anterior))
    } catch { $restaurado = $false }
    if ($restaurado) {
        try { [IO.File]::Delete($backup) } catch { }
        Stop-Registro 3 "falha ao gravar marcador ($erroGravacao) -- d-$hash.jsonl pre-existente restaurado ao conteudo anterior"
    }
    Stop-Registro 3 "falha ao gravar marcador ($erroGravacao) -- NAO consegui restaurar o d-$hash.jsonl pre-existente; o conteudo anterior esta em $backup"
}
if ($backup) { try { [IO.File]::Delete($backup) } catch { } }

# --- telemetria: falha nao muda o exit ---
try {
    $spendDir = Join-Path $top '.deepseek'
    $spendDir = Join-Path $spendDir 'spend'
    New-Item -ItemType Directory -Force -Path $spendDir -ErrorAction Stop | Out-Null
    $linha = [ordered]@{
        timestamp  = $agora.ToString('yyyy-MM-ddTHH:mm:ssZ')
        tool       = 'registrar-review'
        provider   = $Canal
        model      = $modeloJson
        usage      = $null
        diff_lines = $diffLinhas
    } | ConvertTo-Json -Compress
    [IO.File]::AppendAllText((Join-Path $spendDir ($agora.ToString('yyyy-MM') + '.jsonl')), $linha + "`n", $u8)
} catch { }

# Pipeline, nao [Console]::Out: `$r = & registrar-review.ps1 ...` captura a linha.
Write-Output "hash=$hash latest=$latestPath d=$dPath"
exit 0
