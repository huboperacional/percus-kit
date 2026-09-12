#requires -Version 5.1
<#
.SYNOPSIS
  Mede o custo FIXO de boot de cada sessao Claude Code: os tokens da PRIMEIRA chamada a API.

.DESCRIPTION
  READ-ONLY. Para cada transcript em <ClaudeHome>/projects/<projeto>/*.jsonl, le a primeira linha
  com `usage` e soma input_tokens + cache_read_input_tokens + cache_creation_input_tokens. E o que
  a sessao custa ANTES da primeira palavra do operador: system prompt + definicoes de tool (MCP:
  Canva, Gmail, Drive, Calendar, chrome-devtools...) + hooks + lista de skills.

  Medido em 2026-09-12 na frota inteira: 65-73k tokens em todo projeto, ou seja um terco de uma
  janela de 200k gasto em overhead. O kit NAO consegue decompor esse numero por conector -- as
  definicoes de tool nao ficam em disco -- entao a decomposicao e por EXPERIMENTO: desligue um
  conector, abra uma sessao, rode este script, compare. Este script e o medidor estavel desse
  experimento; a decisao de desligar o que e do operador.

.PARAMETER ClaudeHome
  Pasta de configuracao do Claude Code (a que tem projects/). Default: $env:CLAUDE_CONFIG_DIR,
  senao $env:USERPROFILE\.claude.

.PARAMETER Projeto
  Substring do nome da pasta do projeto (ex.: "Empresa-Milionaria"). Sem filtro: todos.

.PARAMETER Ultimos
  Mostra so as N sessoes mais recentes (apos o filtro). 0 = todas.

.EXAMPLE
  pwsh -File scripts/medir-baseline-boot.ps1
  pwsh -File scripts/medir-baseline-boot.ps1 -Projeto Empresa-Milionaria -Ultimos 5
#>
[CmdletBinding()]
param(
    [string]$ClaudeHome = "",
    [string]$Projeto = "",
    [int]$Ultimos = 0
)

if (-not $ClaudeHome) {
    $ClaudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".claude" }
}
$projectsDir = Join-Path $ClaudeHome "projects"
if (-not (Test-Path -LiteralPath $projectsDir)) {
    Write-Output "[medir-baseline] nenhum diretorio projects/ em $ClaudeHome"
    exit 0
}

# Le so ate a PRIMEIRA usage: transcript real tem 5-8 MB e a resposta esta nas primeiras linhas.
function Get-PrimeiraUsage {
    param([string]$Caminho)
    # FileShare.ReadWrite: o harness mantem o transcript ABERTO pra escrita enquanto a sessao
    # vive, e este script existe pra medir a frota com sessoes vivas. StreamReader padrao pede
    # FileShare.Read e leva IOException (finding Cross-Claude, 2026-09-12). Arquivo que ainda
    # assim nao abrir e pulado com aviso -- nunca some da conta em silencio.
    try {
        $fsArq = [System.IO.File]::Open($Caminho, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    } catch {
        Write-Output "[medir-baseline] ignorado (nao abriu): $Caminho -- $($_.Exception.Message)"
        return $null
    }
    $sr = New-Object System.IO.StreamReader($fsArq, [System.Text.Encoding]::UTF8)
    try {
        $primeiraData = ""
        while ($null -ne ($linha = $sr.ReadLine())) {
            if (-not $primeiraData -and $linha -match '"timestamp"\s*:\s*"(\d{4}-\d{2}-\d{2})') { $primeiraData = $matches[1] }
            if ($linha -notmatch '"usage"\s*:\s*\{') { continue }
            if ($linha -notmatch '"input_tokens"\s*:\s*(\d+)') { continue }
            $t = [long]$matches[1]
            if ($linha -match '"cache_read_input_tokens"\s*:\s*(\d+)')     { $t += [long]$matches[1] }
            if ($linha -match '"cache_creation_input_tokens"\s*:\s*(\d+)') { $t += [long]$matches[1] }
            # Visto na frota: o primeiro registro com usage pode ser um <synthetic> com 0 tokens.
            # O boot e a primeira chamada REAL -- 0k contado como baseline afundaria a mediana.
            if ($t -le 0) { continue }
            $modelo = "?"
            if ($linha -match '"model"\s*:\s*"([^"]+)"') { $modelo = $matches[1] }
            $data = $primeiraData
            if ($linha -match '"timestamp"\s*:\s*"(\d{4}-\d{2}-\d{2})') { $data = $matches[1] }
            return [pscustomobject]@{ Data = $data; Tokens = $t; Modelo = $modelo }
        }
    } finally { $sr.Close(); $fsArq.Close() }
    return $null
}

$linhas = New-Object System.Collections.Generic.List[object]
foreach ($pasta in (Get-ChildItem -LiteralPath $projectsDir -Directory)) {
    if ($Projeto -and $pasta.Name -notlike "*$Projeto*") { continue }
    foreach ($arq in (Get-ChildItem -LiteralPath $pasta.FullName -Filter *.jsonl -File)) {
        $u = Get-PrimeiraUsage $arq.FullName
        if ($null -eq $u) { continue }
        $linhas.Add([pscustomobject]@{
            Data    = $u.Data
            Tokens  = $u.Tokens
            Modelo  = $u.Modelo
            Projeto = $pasta.Name
            Sessao  = $arq.BaseName.Substring(0, [Math]::Min(8, $arq.BaseName.Length))
        })
    }
}

if ($linhas.Count -eq 0) {
    Write-Output "[medir-baseline] nenhum transcript com usage encontrado em $projectsDir (filtro: '$Projeto')"
    exit 0
}

$ordenadas = @($linhas | Sort-Object -Property Data -Descending)
if ($Ultimos -gt 0 -and $ordenadas.Count -gt $Ultimos) { $ordenadas = @($ordenadas[0..($Ultimos - 1)]) }

Write-Output "[medir-baseline] custo da 1a chamada (input + cache_read + cache_creation) por sessao:"
foreach ($l in $ordenadas) {
    $k = [Math]::Round($l.Tokens / 1000)
    Write-Output ("  {0}  {1,5}k  {2,-24} {3}  ({4})" -f $l.Data, $k, $l.Modelo, $l.Projeto, $l.Sessao)
}

$valores = @($ordenadas | ForEach-Object { $_.Tokens } | Sort-Object)
$n = $valores.Count
if ($n % 2 -eq 1) { $mediana = $valores[[int](($n - 1) / 2)] } else { $mediana = ($valores[[int]($n / 2) - 1] + $valores[[int]($n / 2)]) / 2 }
Write-Output ("[medir-baseline] n={0}  mediana: {1}k  faixa: {2}k..{3}k" -f $n, [Math]::Round($mediana / 1000), [Math]::Round($valores[0] / 1000), [Math]::Round($valores[$n - 1] / 1000))
exit 0
