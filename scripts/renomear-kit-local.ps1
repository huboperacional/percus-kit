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

# Calculado antes do rename porque o rollback precisa dele: depois do Rename-Item,
# $KitAtual e um caminho que nao existe mais.
$antigoLeaf = Split-Path $KitAtual -Leaf

# 1. Rename (idempotente: se ja esta no nome novo, segue pro settings)
$renomeou = $false
if ($antigoLeaf -ne $NomeNovo) {
    if (-not (Test-Path $KitAtual)) { throw "Pasta nao encontrada: $KitAtual" }
    if (Test-Path $destino) { throw "Destino ja existe: $destino (resolva a mao)" }
    try { Rename-Item -LiteralPath $KitAtual -NewName $NomeNovo }
    catch { throw "Nao consegui renomear '$KitAtual': $($_.Exception.Message). Causa mais provavel: um terminal, editor ou processo esta com essa pasta aberta. Feche e rode de novo -- nada foi alterado no settings." }
    $renomeou = $true
    Write-Host "[renomear-kit] pasta: $KitAtual -> $destino"
} else {
    $destino = $KitAtual
    Write-Host "[renomear-kit] pasta ja esta como '$NomeNovo' — so o settings"
}

# Daqui pra baixo, QUALQUER falha deixaria a pasta renomeada com o PERCUS_CANON_DIR do
# settings apontando pro caminho morto -- estado que o operador so descobre debugando.
# Por isso tudo que acontece depois do rename roda dentro deste try, e o catch desfaz o
# rename. Nao basta proteger o Rename-Item: o backup e a escrita final tambem falham
# (ACL, arquivo somente-leitura, disco cheio) e cada uma e uma porta pro mesmo estado.
$backup   = $null
$escreveu = $false
try {
    # 2. Settings: backup datado ANTES de qualquer escrita
    if (-not (Test-Path $SettingsPath)) { Write-Host "[renomear-kit] settings nao encontrado: $SettingsPath"; return }
    $stamp  = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    Copy-Item $SettingsPath "$SettingsPath.bak-$stamp"
    $backup = "$SettingsPath.bak-$stamp"

    # 3. Troca o nome da pasta em todas as formas de path (barra, contrabarra, escapada).
    #    As duas guardas sao obrigatorias e cobrem casos diferentes:
    #    - a da direita impede casar o PREFIXO: '_Novo_Projeto' e prefixo de
    #      '_Novo_Projeto_V2', que viraria 'percus-kit_V2';
    #    - as duas juntas impedem troca no MEIO de token maior (ex.: 'backup_Novo_Projeto_old'),
    #      que corromperia a chave em silencio.
    #    Nao uso \b porque '_' conta como caractere de palavra e a semantica fica ambigua.
    # -Encoding UTF8 explicito: no PS 5.1 o default de leitura e ANSI, entao um settings
    # UTF-8 sem BOM com acento no path (C:\Users\Joao vs Joäo) seria lido errado e gravado
    # de volta corrompido. O script roda em 5.1 e em 7.
    $raw = Get-Content $SettingsPath -Raw -Encoding UTF8
    $padrao = '(?<![A-Za-z0-9_])' + [regex]::Escape($antigoLeaf) + '(?![A-Za-z0-9_])'
    $raw = [regex]::Replace($raw, $padrao, $NomeNovo)

    # 4. Valida ANTES de salvar — JSON quebrado desativa todos os hooks em silencio
    try { $null = $raw | ConvertFrom-Json } catch { throw "o resultado da troca nao e JSON valido, o settings NAO foi salvo" }
    $escreveu = $true   # marcado ANTES: se a escrita estourar no meio, o arquivo pode ter sido truncado
    [IO.File]::WriteAllText($SettingsPath, $raw, (New-Object System.Text.UTF8Encoding($false)))
    $escreveu = $false  # concluida sem erro; nao ha escrita parcial a relatar
}
catch {
    $erro = $_.Exception.Message
    if (-not $renomeou) { throw }   # nada a desfazer: a pasta ja estava com o nome novo

    $falhaRollback = $null
    try { Rename-Item -LiteralPath $destino -NewName $antigoLeaf -ErrorAction Stop }
    catch { $falhaRollback = $_.Exception.Message }

    # Se a falha foi DURANTE a escrita, o backup pode ser a unica copia boa do settings --
    # mandar apagar nesse caso seria armadilha.
    $sobreBackup =
        if (-not $backup)  { " Nenhum backup foi criado." }
        elseif ($escreveu) { " Backup do settings em '$backup' -- NAO apague antes de conferir." }
        else               { " Backup do settings em '$backup' (pode apagar)." }

    if ($falhaRollback) {
        $estadoSettings = if ($escreveu) {
            "o settings '$SettingsPath' PODE ter sido gravado parcialmente -- compare com o backup antes de usar."
        } else {
            "o settings '$SettingsPath' NAO foi alterado."
        }
        throw "FALHOU depois do rename: $erro. E O ROLLBACK TAMBEM FALHOU: $falhaRollback. ESTADO ATUAL: a pasta esta com o nome NOVO em '$destino' e $estadoSettings COMO RETOMAR: resolva a causa acima e rode de novo com -KitAtual '$destino' (a pasta ja esta renomeada, o script vai direto pro settings); ou renomeie '$destino' de volta para '$antigoLeaf' a mao.$sobreBackup"
    }

    $ressalva = if ($escreveu) { " ATENCAO: a falha foi durante a escrita, entao o settings '$SettingsPath' pode ter sido gravado parcialmente -- compare com o backup." } else { " O settings NAO foi alterado." }
    throw "FALHOU depois do rename: $erro. ROLLBACK OK: a pasta voltou para '$KitAtual'.$ressalva Resolva a causa acima e rode de novo.$sobreBackup"
}

Write-Host "[renomear-kit] settings atualizado (backup: $backup)"
Write-Host "[renomear-kit] PRONTO. Reabra o Claude Code para o PERCUS_CANON_DIR novo valer."
