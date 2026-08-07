#requires -Version 5.1
<#
.SYNOPSIS
  Registra o uso da autorizacao em lote no log de auditoria (.percus/autorizacoes-usadas.jsonl).
.DESCRIPTION
  Chamado pelo AGENTE toda vez que executa uma acao externa usando a autorizacao em lote
  (nao quando usa PERCUS_EXTERNAL_OVERRIDE ou aprovacao pontual do operador pra uma acao so).
  Le id e motivo do arquivo de autorizacao ja existente -- nao precisa que o chamador repita.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Comando,
    [string]$ProjetoRoot
)
$ErrorActionPreference = "Stop"

if (-not $ProjetoRoot) { $ProjetoRoot = (Get-Location).Path }

$authFile = Join-Path $ProjetoRoot ".percus/acao-externa-autorizada.json"
if (-not (Test-Path $authFile)) {
    throw "nenhuma autorizacao em lote ativa em '$authFile' -- nada pra registrar"
}
$auth = Get-Content $authFile -Raw -Encoding UTF8 | ConvertFrom-Json

$linha = [pscustomobject]@{
    id      = $auth.id
    motivo  = $auth.motivo
    comando = $Comando
    quando  = (Get-Date).ToString("o")
} | ConvertTo-Json -Compress

$logPath = Join-Path $ProjetoRoot ".percus/autorizacoes-usadas.jsonl"
Add-Content -LiteralPath $logPath -Value $linha -Encoding UTF8

Write-Host "[registrar-uso-autorizacao] registrado: id=$($auth.id) comando='$Comando'"
