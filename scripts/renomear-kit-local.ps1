#requires -Version 5.1
<#
.SYNOPSIS
  Renomeia a pasta local do kit Percus e conserta o settings.json do usuario.
.DESCRIPTION
  O nome do diretorio de trabalho NAO vem por git pull — e local de cada maquina.
  Rode uma vez por maquina apos o rename entrar no canon. Idempotente.
#>
[CmdletBinding()]
param(
    [string]$KitAtual = $env:PERCUS_CANON_DIR,
    [string]$NomeNovo = "percus-kit",
    [string]$SettingsPath
)
$ErrorActionPreference = "Stop"

# Default calculado no corpo, nao no bloco param: expressao condicional em default de
# parametro e fragil entre PS 5.1 e 7, e este script roda nos dois.
if (-not $SettingsPath) {
    $claudeHome   = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$env:USERPROFILE\.claude" }
    $SettingsPath = Join-Path $claudeHome "settings.json"
}

if (-not $KitAtual) { throw "Informe -KitAtual ou defina PERCUS_CANON_DIR." }
$KitAtual = $KitAtual.TrimEnd('\','/')
# Split-Path -Parent lanca excecao (nao devolve string vazia) para caminhos sem pasta
# pai como "D:" -- por isso o try/catch, alem do "-not $pai" para os casos em que ele
# devolve vazio sem lancar.
try { $pai = Split-Path $KitAtual -Parent } catch { $pai = $null }
if (-not $pai) { throw "-KitAtual precisa ser um caminho com pasta pai (recebi '$KitAtual'). Exemplo: D:\Claud Automations\_Novo_Projeto" }
$destino = Join-Path $pai $NomeNovo

# 0. Valida o settings ANTES de qualquer mudanca. Renomear primeiro e falhar depois
#    deixaria PERCUS_CANON_DIR apontando pra um caminho que nao existe mais -- e o
#    operador so descobriria debugando.
if (Test-Path $SettingsPath) {
    try { $null = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw "settings.json JA esta invalido antes de qualquer mudanca ($SettingsPath). Conserte o JSON primeiro. NADA foi renomeado." }
}

# 1. Rename (idempotente: se ja esta no nome novo, segue pro settings)
if ((Split-Path $KitAtual -Leaf) -ne $NomeNovo) {
    if (-not (Test-Path $KitAtual)) { throw "Pasta nao encontrada: $KitAtual" }
    if (Test-Path $destino) { throw "Destino ja existe: $destino (resolva a mao)" }
    try { Rename-Item -LiteralPath $KitAtual -NewName $NomeNovo }
    catch { throw "Nao consegui renomear '$KitAtual': $($_.Exception.Message). Causa mais provavel: um terminal, editor ou processo esta com essa pasta aberta. Feche e rode de novo -- nada foi alterado no settings." }
    Write-Host "[renomear-kit] pasta: $KitAtual -> $destino"
} else {
    $destino = $KitAtual
    Write-Host "[renomear-kit] pasta ja esta como '$NomeNovo' — so o settings"
}

# 2. Settings: backup datado ANTES de qualquer escrita
if (-not (Test-Path $SettingsPath)) { Write-Host "[renomear-kit] settings nao encontrado: $SettingsPath"; return }
$stamp  = Get-Date -Format "yyyyMMdd-HHmmss-fff"
Copy-Item $SettingsPath "$SettingsPath.bak-$stamp"

# 3. Troca o nome da pasta em todas as formas de path (barra, contrabarra, escapada).
#    As duas guardas sao obrigatorias e cobrem casos diferentes:
#    - a da direita impede casar o PREFIXO: '_Novo_Projeto' e prefixo de
#      '_Novo_Projeto_V2', que viraria 'percus-kit_V2';
#    - as duas juntas impedem troca no MEIO de token maior (ex.: 'backup_Novo_Projeto_old'),
#      que corromperia a chave em silencio.
#    Nao uso \b porque '_' conta como caractere de palavra e a semantica fica ambigua.
$antigoLeaf = Split-Path $KitAtual -Leaf
# -Encoding UTF8 explicito: no PS 5.1 o default de leitura e ANSI, entao um settings
# UTF-8 sem BOM com acento no path (C:\Users\Joao vs Joäo) seria lido errado e gravado
# de volta corrompido. O script roda em 5.1 e em 7.
$raw = Get-Content $SettingsPath -Raw -Encoding UTF8
$padrao = '(?<![A-Za-z0-9_])' + [regex]::Escape($antigoLeaf) + '(?![A-Za-z0-9_])'
$raw = [regex]::Replace($raw, $padrao, $NomeNovo)

# 4. Valida ANTES de salvar — JSON quebrado desativa todos os hooks em silencio
try { $null = $raw | ConvertFrom-Json } catch {
    throw "Resultado nao e JSON valido; o settings NAO foi salvo. ATENCAO: a pasta JA foi renomeada para '$destino' -- corrija o JSON e rode de novo com -KitAtual '$destino'. Backup em $SettingsPath.bak-$stamp"
}
[IO.File]::WriteAllText($SettingsPath, $raw, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[renomear-kit] settings atualizado (backup: $SettingsPath.bak-$stamp)"
Write-Host "[renomear-kit] PRONTO. Reabra o Claude Code para o PERCUS_CANON_DIR novo valer."
