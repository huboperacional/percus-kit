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

# MASCARA credencial antes de gravar -- IGUAL ao bloco do hook external-action-guard.ps1, que
# escreve neste mesmo arquivo. Nao da pra compartilhar funcao: o hook roda a partir do plugin
# INSTALADO (plugins/cache/...) e este script a partir do kit, raizes diferentes. Por isso existe
# teste de paridade passando o MESMO comando pelos dois e exigindo mascara identica -- a receita do
# #regra-duplicada-ps1-sh para quando fonte unica nao e possivel.
# VIES DECLARADO: na duvida, mascara DEMAIS. Log de seguranca -- destruir uma palavra de prosa
# custa quase nada, vazar um PAT custa a conta inteira. Blocklist e best-effort por natureza:
# cobre 12 formas reais medidas, nao promete cobrir todas.
$comandoLog = $Comando
# 1. credencial em URL -- QUALQUER coisa entre :// e @, com ou sem dois-pontos (cobre
#    https://TOKEN@host, a forma mais comum de push com PAT).
$comandoLog = [regex]::Replace($comandoLog, '(?<=://)[^/@\s]+(?=@)', '***')
# 2. chave sensivel com separador : ou = -- inclui prefixo/sufixo colado (GH_TOKEN) e chave
#    entre aspas do JSON.
$comandoLog = [regex]::Replace($comandoLog, '(?i)([A-Za-z_-]*(?:token|password|passwd|senha|secret|api[_-]?key|apikey|pat)[A-Za-z_-]*)["'']?\s*[:=]\s*["'']?[^\s"'',}&]+', '$1=***')
# 3. flag separada por ESPACO (--token VALOR) ou COLADA (-uusuario:senha). ASPA OPCIONAL antes do
#    valor: sem ela, `--token "x"` nao casava em regra nenhuma e ia pro disco em claro.
$comandoLog = [regex]::Replace($comandoLog, '(?i)(--?(?:token|password|passwd|senha|secret|api[_-]?key|apikey|pat|user|u))(\s+["'']?)[^\s"'']+', '$1$2***')
$comandoLog = [regex]::Replace($comandoLog, '(?i)(\s-[up])(?=["'']?[^\s"''-])["'']?[^\s"'']+', '$1***')
# 4. header de credencial -- esquema ENUMERADO; valor sem \S+ para nao comer aspa de fechamento.
$comandoLog = [regex]::Replace($comandoLog, '(?i)((?:authorization|x-api-key|x-auth-token|private-token)\s*:\s*["'']?)((?:bearer|basic|token|digest)\s+)?[^\s"'']+', '${1}${2}***')

$linha = [pscustomobject]@{
    id      = $auth.id
    motivo  = $auth.motivo
    comando = $comandoLog
    quando  = (Get-Date).ToString("o")
    origem  = "script"
} | ConvertTo-Json -Compress

$logPath = Join-Path $ProjetoRoot ".percus/autorizacoes-usadas.jsonl"
# AppendAllText + UTF8Encoding($false), NAO Add-Content -Encoding UTF8: no 5.1 o -Encoding UTF8
# grava COM BOM e no pwsh 7 grava SEM. Este script e o HOOK external-action-guard.ps1 escrevem
# no MESMO arquivo, entao duas convencoes produziriam BOM no meio de um .jsonl append-only --
# onde ele nao e marcador de arquivo, e byte de dado no meio de uma linha. Medido em 2026-08-17
# pelo teste de paridade: o hook gravava sem BOM e este script gravava com. Ver
# #regra-duplicada-ps1-sh -- a guarda que pega isto e a que compara as DUAS copias.
[IO.File]::AppendAllText($logPath, ($linha + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))

# Ecoa o comando MASCARADO, nao o original: mascarar o arquivo e imprimir o segredo no stdout nao
# protege nada -- stdout de script vai parar em log de CI, em `tee`, no scrollback do terminal.
# Achado do R11/DeepSeek na terceira rodada da 6.36.7.
Write-Host "[registrar-uso-autorizacao] registrado: id=$($auth.id) comando='$comandoLog'"
