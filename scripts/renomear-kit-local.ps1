#requires -Version 5.1
<#
.SYNOPSIS
  Renomeia a pasta local do kit Percus e conserta TODOS os ponteiros locais pra ela.
.DESCRIPTION
  O nome do diretorio de trabalho NAO vem por git pull — e local de cada maquina.
  Rode uma vez por maquina apos o rename entrar no canon. Idempotente.

  Sao TRES familias de ponteiro local, nao uma (medido em 2026-07-30 nesta maquina):
    1. variaveis de ambiente de USUARIO (registro HKCU) — sao ELAS, e nao o settings.json,
       que apontam as sessoes pro kit: PERCUS_CANON_DIR (a pasta) e PERCUS_CANON_V2_DIR
       (a pasta\v2). Por isso a varredura e por VALOR, nao por nome fixo;
    2. o settings.json do usuario (16 ocorrencias, em 4 formas de path diferentes);
    3. os .claude/settings*.json de projetos VIZINHOS que hardcodam o path do kit num
       hook de review (4 projetos, 18 ocorrencias).
  Consertar so um deixa os outros apontando pro caminho morto.

  Qualquer falha depois do rename desfaz TUDO: arquivos voltam do proprio backup, a
  variavel volta ao valor antigo, a pasta volta ao nome antigo.
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

# Calculados antes do rename porque o rollback precisa deles: depois do Rename-Item,
# $KitAtual e um caminho que nao existe mais.
$antigoLeaf = Split-Path $KitAtual -Leaf
# Troca o nome da pasta em todas as formas de path (barra, contrabarra, escapada).
# As duas guardas sao obrigatorias e cobrem casos diferentes:
# - a da direita impede casar o PREFIXO: '_Novo_Projeto' e prefixo de '_Novo_Projeto_V2',
#   que viraria 'percus-kit_V2';
# - as duas juntas impedem troca no MEIO de token maior (ex.: 'backup_Novo_Projeto_old'),
#   que corromperia a chave em silencio.
# Nao uso \b porque '_' conta como caractere de palavra e a semantica fica ambigua.
$padrao = '(?<![A-Za-z0-9_])' + [regex]::Escape($antigoLeaf) + '(?![A-Za-z0-9_])'

# Compara caminho com caminho, nao string com string: barra vs contrabarra, barra final
# e caixa sao a mesma pasta no Windows.
function Get-PathNormalizado {
    param([string]$P)
    if (-not $P) { return "" }
    return ($P -replace '/', '\').TrimEnd('\').ToLowerInvariant()
}
$kitNorm = Get-PathNormalizado $KitAtual
# A normalizacao e 1:1 em tamanho (troca / por \, minusculas, corta barra final), entao a
# posicao do leaf no valor normalizado vale pro valor original -- e por isso da pra trocar
# so o nome da pasta preservando a forma do resto (barra normal, caixa, subpasta).
$inicioLeaf = $kitNorm.Length - $antigoLeaf.Length

# Reaponta UM segmento de valor de variavel de ambiente. So mexe se o segmento E a pasta
# do kit ou esta DENTRO dela; senao devolve intacto. Valor que apenas cita o nome antigo
# pode ser de outra coisa, e reescrever seria estragar config alheia.
function Get-SegmentoReapontado {
    param([string]$Segmento, [string]$KitNorm, [int]$InicioLeaf, [string]$Novo)
    $n = Get-PathNormalizado $Segmento
    if ($n -ne $KitNorm -and -not $n.StartsWith($KitNorm + '\')) { return $Segmento }
    return $Segmento.Substring(0, $InicioLeaf) + $Novo + $Segmento.Substring($KitNorm.Length)
}

# Reescreve UM settings.json: valida o JSON resultante ANTES de salvar, faz backup datado
# e registra o que foi feito pra que o catch la embaixo possa desfazer. Devolve $true se
# mexeu no arquivo. A ordem aqui e deliberada: backup -> registro -> escrita. Assim uma
# escrita que morre no meio ja tem backup registrado e volta no rollback.
function Update-SettingsJson {
    param([string]$Caminho, [string]$Padrao, [string]$Novo, [string]$Stamp, $Registro)
    # -Encoding UTF8 explicito: no PS 5.1 o default de leitura e ANSI, entao um settings
    # UTF-8 sem BOM com acento no path (C:\Users\Joao vs Joäo) seria lido errado e gravado
    # de volta corrompido. O script roda em 5.1 e em 7.
    $conteudo = Get-Content $Caminho -Raw -Encoding UTF8
    if ($conteudo -notmatch $Padrao) { return $false }
    # MatchEvaluator em vez de string de substituicao: na string, '$' e metacaractere
    # ('$&' = a match inteira, '$1' = grupo 1). Com o nome cru, -NomeNovo 'percus$&kit'
    # gravava 'percus_Novo_Projetokit' no settings enquanto a pasta ficava com o nome
    # certo -- path corrompido em silencio. '$' e caractere legal em nome de pasta no
    # Windows, entao isso era alcancavel. O avaliador devolve o texto literal.
    $trocado = [regex]::Replace($conteudo, $Padrao, { param($m) $Novo })
    # JSON quebrado desativa todos os hooks em silencio -- valida antes de gravar.
    try { $null = $trocado | ConvertFrom-Json }
    catch { throw "a troca deixaria '$Caminho' com JSON invalido; nada foi gravado nele" }
    $bak = "$Caminho.bak-$Stamp"
    Copy-Item -LiteralPath $Caminho -Destination $bak
    [void]$Registro.Add(@{ Tipo = 'arquivo'; Path = $Caminho; Backup = $bak })
    [IO.File]::WriteAllText($Caminho, $trocado, (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

# 0. Valida o settings ANTES de qualquer mudanca. Renomear primeiro e falhar depois
#    deixaria PERCUS_CANON_DIR apontando pra um caminho que nao existe mais -- e o
#    operador so descobriria debugando.
if (Test-Path $SettingsPath) {
    try { $null = Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw "settings.json JA esta invalido antes de qualquer mudanca ($SettingsPath). Conserte o JSON primeiro. NADA foi renomeado." }
}

# 1. Rename (idempotente: se ja esta no nome novo, segue pros ponteiros)
$renomeou = $false
if ($antigoLeaf -ne $NomeNovo) {
    if (-not (Test-Path $KitAtual)) { throw "Pasta nao encontrada: $KitAtual" }
    if (Test-Path $destino) { throw "Destino ja existe: $destino (resolva a mao)" }
    try { Rename-Item -LiteralPath $KitAtual -NewName $NomeNovo }
    catch { throw "Nao consegui renomear '$KitAtual': $($_.Exception.Message). Causa mais provavel: um terminal, editor ou processo esta com essa pasta aberta. Feche e rode de novo -- nada foi alterado." }
    $renomeou = $true
    Write-Host "[renomear-kit] pasta: $KitAtual -> $destino"
} else {
    $destino = $KitAtual
    Write-Host "[renomear-kit] pasta ja esta como '$NomeNovo' — so os ponteiros"
}

# Daqui pra baixo, QUALQUER falha deixaria a pasta renomeada com os ponteiros apontando
# pro caminho morto -- estado que o operador so descobre debugando. Por isso tudo que
# acontece depois do rename roda dentro deste try, e o catch desfaz na ordem inversa.
# Nao basta proteger o Rename-Item: backup, escrita e variavel de ambiente tambem falham
# (ACL, arquivo somente-leitura, disco cheio) e cada uma e uma porta pro mesmo estado.
$stamp  = Get-Date -Format "yyyyMMdd-HHmmss-fff"
$feitos = New-Object System.Collections.ArrayList
try {
    # 2. Variaveis de ambiente de USUARIO que apontam pra pasta renomeada -- ou pra DENTRO
    #    dela. Nesta maquina sao DUAS (PERCUS_CANON_DIR e PERCUS_CANON_V2_DIR) e nenhuma
    #    esta no settings.json: sao env var de usuario (HKCU). Consertar so o settings
    #    deixaria todo shell e toda sessao nova apontando pro caminho morto.
    #    A varredura e por VALOR, nao por nome: nome fixo teria achado uma e deixado a
    #    outra quebrada. O split/join por ';' e pra nao estragar variavel com lista
    #    (PATH e afins) por causa de um segmento.
    $varsUsuario = [Environment]::GetEnvironmentVariables('User')
    foreach ($nomeVar in ($varsUsuario.Keys | Sort-Object)) {
        $valor = [string]$varsUsuario[$nomeVar]
        if (-not $valor) { continue }
        $novoValor = (($valor -split ';') | ForEach-Object {
            Get-SegmentoReapontado -Segmento $_ -KitNorm $kitNorm -InicioLeaf $inicioLeaf -Novo $NomeNovo
        }) -join ';'
        if ($novoValor -eq $valor) { continue }
        [Environment]::SetEnvironmentVariable($nomeVar, $novoValor, 'User')
        [void]$feitos.Add(@{ Tipo = 'env'; Nome = $nomeVar; Antigo = $valor })
        Write-Host "[renomear-kit] variavel de usuario ${nomeVar}: $valor -> $novoValor"
    }
    # Escopo MACHINE exige admin: nao mexo, mas nao deixo passar calado.
    $varsMaquina = [Environment]::GetEnvironmentVariables('Machine')
    foreach ($nomeVar in ($varsMaquina.Keys | Sort-Object)) {
        $valor = [string]$varsMaquina[$nomeVar]
        if (-not $valor) { continue }
        $temSegmentoDoKit = ($valor -split ';') | Where-Object {
            (Get-SegmentoReapontado -Segmento $_ -KitNorm $kitNorm -InicioLeaf $inicioLeaf -Novo $NomeNovo) -ne $_
        }
        if ($temSegmentoDoKit) {
            Write-Warning "[renomear-kit] a variavel de MAQUINA $nomeVar aponta pra pasta renomeada ('$valor'). NAO mexi: escopo Machine exige terminal como administrador. Corrija a mao trocando '$antigoLeaf' por '$NomeNovo' nela."
        }
    }

    # 3. Settings.json do usuario
    if (Test-Path $SettingsPath) {
        if (Update-SettingsJson -Caminho $SettingsPath -Padrao $padrao -Novo $NomeNovo -Stamp $stamp -Registro $feitos) {
            Write-Host "[renomear-kit] settings atualizado: $SettingsPath (backup: $SettingsPath.bak-$stamp)"
        } else {
            Write-Host "[renomear-kit] settings nao citava '$antigoLeaf', nada a fazer: $SettingsPath"
        }
    } else {
        Write-Host "[renomear-kit] settings nao encontrado: $SettingsPath"
    }

    # 4. Settings de projetos VIZINHOS (irmaos da pasta do kit) que hardcodam o path do
    #    kit num hook. A propria pasta do kit fica FORA da varredura de proposito: o que
    #    esta dentro dela e versionado, o gate do Task 6 cuida disso, e mexer aqui
    #    sujaria o git status do kit no meio do rename.
    foreach ($dir in (Get-ChildItem -LiteralPath $pai -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if ((Get-PathNormalizado $dir.FullName) -eq (Get-PathNormalizado $destino)) { continue }
        foreach ($nome in @("settings.json", "settings.local.json")) {
            $arq = Join-Path $dir.FullName ".claude\$nome"
            if (-not (Test-Path $arq)) { continue }
            if ((Get-PathNormalizado $arq) -eq (Get-PathNormalizado $SettingsPath)) { continue }
            if (Update-SettingsJson -Caminho $arq -Padrao $padrao -Novo $NomeNovo -Stamp $stamp -Registro $feitos) {
                Write-Host "[renomear-kit] projeto vizinho atualizado: $arq"
            }
        }
    }
}
catch {
    $erro = $_.Exception.Message
    if (-not $renomeou -and $feitos.Count -eq 0) { throw }

    # Desfaz na ordem inversa do que foi feito: arquivo volta do proprio backup, variavel
    # volta ao valor antigo, e por ultimo a pasta volta ao nome antigo.
    $restaurados  = New-Object System.Collections.ArrayList
    $naoDesfeitos = New-Object System.Collections.ArrayList
    for ($i = $feitos.Count - 1; $i -ge 0; $i--) {
        $f = $feitos[$i]
        try {
            if ($f.Tipo -eq 'env') {
                [Environment]::SetEnvironmentVariable($f.Nome, $f.Antigo, 'User')
                [void]$restaurados.Add("variavel de usuario $($f.Nome)")
            } else {
                Copy-Item -LiteralPath $f.Backup -Destination $f.Path -Force -ErrorAction Stop
                [void]$restaurados.Add("'$($f.Path)'")
            }
        } catch {
            if ($f.Tipo -eq 'env') { [void]$naoDesfeitos.Add("a variavel de usuario $($f.Nome) (devia voltar para '$($f.Antigo)')") }
            else { [void]$naoDesfeitos.Add("'$($f.Path)' (restaure a mao do backup '$($f.Backup)')") }
        }
    }

    $falhaRename = $null
    if ($renomeou) {
        try { Rename-Item -LiteralPath $destino -NewName $antigoLeaf -ErrorAction Stop }
        catch { $falhaRename = $_.Exception.Message }
    }

    $oQueVoltou = if ($restaurados.Count) { " Restaurado ao estado anterior: $($restaurados -join '; ')." } else { "" }
    $pendencias = if ($naoDesfeitos.Count) { " NAO consegui desfazer: $($naoDesfeitos -join '; '). NAO apague os backups .bak-$stamp antes de conferir." } else { "" }

    if ($falhaRename) {
        throw "FALHOU depois do rename: $erro. E O ROLLBACK DA PASTA TAMBEM FALHOU: $falhaRename. ESTADO ATUAL: a pasta esta com o nome NOVO em '$destino'.$oQueVoltou$pendencias COMO RETOMAR: resolva a causa acima e rode de novo com -KitAtual '$destino' (a pasta ja esta renomeada; o script segue direto pros ponteiros); ou renomeie '$destino' de volta para '$antigoLeaf' a mao."
    }
    if ($naoDesfeitos.Count) {
        throw "FALHOU depois do rename: $erro. ROLLBACK PARCIAL: a pasta voltou para '$KitAtual'.$oQueVoltou$pendencias"
    }
    throw "FALHOU depois do rename: $erro. ROLLBACK OK: a pasta voltou para '$KitAtual' e nada ficou pela metade.$oQueVoltou Resolva a causa acima e rode de novo."
}

Write-Host "[renomear-kit] PRONTO. Reabra o Claude Code para as variaveis de ambiente novas valerem."
