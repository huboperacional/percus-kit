#requires -Version 5.1
<#
.SYNOPSIS
  Cria o arquivo de autorizacao em lote pra acoes externas bloqueadas pelo R20.
.DESCRIPTION
  Chamado pelo AGENTE depois de confirmacao explicita do operador na conversa -- nunca antes.
  Ver docs/superpowers/specs/2026-08-06-r20-autorizacao-lote-design.md pro raciocinio completo,
  inclusive o risco aceito conscientemente (o agente cria o proprio arquivo que o hook confia).

  ASCII puro nos comentarios, mesma disciplina dos scripts irmaos deste kit
  (renomear-kit-local.ps1, registrar-hooks-settings.ps1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Motivo,
    [string]$ProjetoRoot
)
$ErrorActionPreference = "Stop"

if (-not $ProjetoRoot) { $ProjetoRoot = (Get-Location).Path }

$dir = Join-Path $ProjetoRoot ".percus"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$agora = Get-Date
$epoch = [DateTimeOffset]::new($agora).ToUnixTimeSeconds()
$auth = [pscustomobject]@{
    id             = [guid]::NewGuid().ToString()
    motivo         = $Motivo
    autorizado_em  = $agora.ToString("o")
    timestamp_unix = $epoch
}

$caminho = Join-Path $dir "acao-externa-autorizada.json"
$texto = $auth | ConvertTo-Json
[IO.File]::WriteAllText($caminho, $texto, (New-Object System.Text.UTF8Encoding($false)))

$expiraEm = $agora.AddMinutes(60).ToString("HH:mm")
Write-Host "[autorizar-acao-externa] autorizacao criada: id=$($auth.id) motivo='$Motivo' valida ate $expiraEm"
