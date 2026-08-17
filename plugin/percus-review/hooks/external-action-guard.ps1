#requires -Version 5.1
# Hook PreToolUse Percus (Layer 1 R20 enforcement).
# Bloqueia tools externos publicos quando council recente tem premise_validity != ok
# OU quando findings criticos nao tem fact_check: CONFIRMADO.
# Falha graceful: qualquer erro -> exit 0 (nao bloqueia injustamente).

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin -or $stdin.Trim() -eq '') { exit 0 }

    $inputObj = $stdin | ConvertFrom-Json -ErrorAction Stop
    $command = $inputObj.tool_input.command
    if (-not $command) { exit 0 }

    # Lista de comandos que sao "acao externa publica" (R20)
    $externalPatterns = @(
        'gh\s+(pr|issue)\s+comment',
        'gh\s+pr\s+(close|merge)',
        'gh\s+issue\s+close',
        'slack-cli',
        'git\s+push',
        'mailto:'
    )

    $isExternalAction = $false
    foreach ($p in $externalPatterns) {
        if ($command -match $p) { $isExternalAction = $true; break }
    }

    if (-not $isExternalAction) { exit 0 }

    $cwd = (Get-Location).Path

    # MASCARA credencial AQUI, antes de qualquer saida -- nao so antes de gravar. A 1a versao
    # mascarava dentro do ramo autorizado, entao o arquivo ficava limpo e o comando CRU continuava
    # saindo nas mensagens de BLOCK pelo stderr. Mascara que cobre um canal e deixa o outro aberto
    # nao e mascara, e falsa sensacao: stderr de hook vai parar em log de sessao e de CI.
    # Achado do R11/DeepSeek na terceira rodada desta versao.
    #
    # VIES DECLARADO: na duvida, mascara DEMAIS. Log de seguranca -- destruir uma palavra de prosa
    # custa quase nada, vazar um PAT custa a conta inteira. Continua sendo blocklist, portanto
    # best-effort: cobre 12 formas reais medidas, nao promete cobrir todas.
    #
    # ATENCAO: este bloco existe IGUAL em scripts/registrar-uso-autorizacao.ps1, que escreve no
    # mesmo arquivo. Nao da pra compartilhar funcao: o hook roda a partir do plugin INSTALADO
    # (plugins/cache/...) e o script a partir do kit -- raizes diferentes, dot-source seria
    # dependencia quebrada. Por isso ha teste de paridade que passa o MESMO comando pelos dois e
    # exige mascara identica (#regra-duplicada-ps1-sh).
    # UMA nocao de "valor", usada pelas quatro regras: citado (aspas duplas ou simples, podendo
    # conter espaco) OU nu. Duas rodadas de R11 foram gastas remendando aspa caso a caso -- primeiro
    # `--token "x"` nao casava em regra nenhuma, depois `Authorization: Bearer "x"` vazava pela aspa
    # ENTRE esquema e valor, depois `--token "x com espaco"` mascarava so ate o primeiro espaco.
    # Eram tres sintomas do mesmo buraco: nao havia definicao de valor, havia tres aproximacoes.
    $VALOR = '(?:"[^"]*"|''[^'']*''|[^\s"'']+)'

    $comandoLog = $command
    # 1. credencial em URL -- QUALQUER coisa entre :// e @, com ou sem dois-pontos. A 1a versao
    #    exigia `usuario:segredo@` e deixava passar `https://TOKEN@host` (token como usuario), que
    #    e a forma MAIS comum de push com PAT do GitHub: mascarava a rara e vazava a comum.
    $comandoLog = [regex]::Replace($comandoLog, '(?<=://)[^/@\s]+(?=@)', '***')
    # 2. chave sensivel com separador : ou = -- inclui prefixo/sufixo colado (GH_TOKEN: o \b da 1a
    #    versao falhava porque `_` e caractere de palavra) e chave entre aspas do JSON.
    $comandoLog = [regex]::Replace($comandoLog, '(?i)([A-Za-z_-]*(?:token|password|passwd|senha|secret|api[_-]?key|apikey|pat)[A-Za-z_-]*)["'']?\s*[:=]\s*' + $VALOR, '$1=***')
    # 3. flag separada por ESPACO (--token VALOR) ou COLADA (-uusuario:senha do curl).
    $comandoLog = [regex]::Replace($comandoLog, '(?i)(--?(?:token|password|passwd|senha|secret|api[_-]?key|apikey|pat|user|u))\s+' + $VALOR, '$1 ***')
    $comandoLog = [regex]::Replace($comandoLog, '(?i)(\s-[up])(?=["'']?[^\s"''-])' + $VALOR, '$1***')
    # 4. header de credencial -- esquema ENUMERADO, nao opcional-livre: com `(bearer\s+)?` solto,
    #    `Authorization: token <PAT>` mascarava a palavra "token" e deixava o PAT depois dela.
    $comandoLog = [regex]::Replace($comandoLog, '(?i)((?:authorization|x-api-key|x-auth-token|private-token)\s*:\s*)((?:bearer|basic|token|digest)\s+)?' + $VALOR, '${1}${2}***')

    # Escape hatch: operador autorizou explicitamente
    if ($env:PERCUS_EXTERNAL_OVERRIDE -eq "1") {
        [Console]::Error.WriteLine("[percus:hook external-action-guard] PERCUS_EXTERNAL_OVERRIDE setado — permitindo.")
        exit 0
    }

    # Escape hatch: autorizacao em lote via arquivo (janela de 60min por timestamp_unix DENTRO do
    # JSON, nao LastWriteTime do filesystem -- metadado de filesystem pode mudar sem o conteudo
    # mudar; o timestamp gravado na criacao e mais confiavel). Arquivo atravessa a fronteira de
    # processo do hook; env var da sessao do Claude nao atravessa (achado 2026-07-31).
    #
    # IMPORTANTE: try/catch AQUI, LOCAL -- nao deixar erro desta checagem cair no catch generico
    # do fim do script. O catch generico do hook e fail-OPEN de proposito (erro interno do script
    # nao pode travar a maquina). Mas erro NESTA checagem especifica (arquivo ilegivel, JSON
    # corrompido, campo faltando) tem que continuar pro fluxo normal do R20 -- ou seja, tem que
    # poder BLOQUEAR. Fail-open aqui seria: permissao negada no arquivo = "ah, deu erro, libera
    # geral" -- o oposto do que devia acontecer.
    try {
        $authFile = Join-Path $cwd ".percus/acao-externa-autorizada.json"
        if (Test-Path $authFile) {
            $auth = Get-Content -Encoding UTF8 $authFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            # Comparacao em epoch puro, NUNCA converter pra hora local antes de subtrair --
            # subtracao de DateTime local e aritmetica de relogio de parede, nao tempo real
            # decorrido. Numa transicao de horario de verao isso podia fazer autorizacao
            # EXPIRADA parecer fresca. Epoch (segundos desde 1970 UTC) e imune a fuso/DST.
            $agoraUnix = [DateTimeOffset]::new((Get-Date)).ToUnixTimeSeconds()
            $idadeSeg = $agoraUnix - $auth.timestamp_unix
            if ($idadeSeg -ge 0 -and $idadeSeg -lt 3600) {
                # Auditoria gravada AQUI, pelo proprio hook -- nao pelo agente. Ate 6.36.6 a
                # linha dependia de o agente lembrar de chamar registrar-uso-autorizacao.ps1, e
                # em 2026-08-17 ele nao lembrou: o push saiu 07:37:49 e o log parou no dia
                # anterior. O hook ja esta neste caminho em toda acao externa, entao gravar aqui
                # torna o log completo por construcao em vez de por promessa.
                #
                # PreToolUse roda ANTES do comando: isto registra AUTORIZACAO CONCEDIDA, nao
                # execucao concluida -- dai o origem="hook".
                $logPath = Join-Path $cwd ".percus/autorizacoes-usadas.jsonl"

                # $comandoLog ja vem mascarado la de cima -- a mascara e feita antes de QUALQUER
                # saida, nao so antes desta gravacao, para cobrir tambem as mensagens de BLOCK.
                $linha = ([pscustomobject]@{
                    id      = $auth.id
                    motivo  = $auth.motivo
                    comando = $comandoLog
                    quando  = (Get-Date).ToString("o")
                    origem  = "hook"
                } | ConvertTo-Json -Compress)
                # AppendAllText + UTF8Encoding($false), NAO Add-Content -Encoding UTF8: no 5.1
                # (runtime real deste hook) o -Encoding UTF8 grava COM BOM e no pwsh 7 grava SEM.
                # O script irmao registrar-uso-autorizacao.ps1 escreve no MESMO arquivo, entao
                # duas convencoes de encoding produziriam bytes diferentes na mesma linha de log,
                # com motivo acentuado no meio. Ver #regra-duplicada-ps1-sh.
                #
                # Tres tentativas antes de desistir: o checkout e compartilhado entre sessoes
                # (duas sessoes do agente no mesmo repo e cenario real, nao hipotese), e append
                # concorrente pode esbarrar em lock momentaneo. Sem retry, colisao de milissegundo
                # viraria bloqueio de acao legitima.
                #
                # Espera 200ms depois da 1a tentativa e 400ms depois da 2a: 600ms de tolerancia
                # total. Nao ha sono depois da 3a -- nao existe 4a tentativa para esperar.
                #
                # Duas rodadas de R11 calibraram isto. A 1a versao usava 50/100ms e o DeepSeek
                # apontou que 150ms nao cobre contencao de lock em filesystem de rede. A correcao
                # virou 100/200/400 com o comentario alegando "700ms" -- e o Cross-Claude mediu:
                # o total real era 300ms, porque o `Pow(2,2)`=400 nunca chega a ser dormido. Numero
                # em comentario de decisao de seguranca nao e enfeite: a justificativa ("cobre
                # contencao") dependia de uma janela que o codigo nao entregava.
                $registrado = $false
                $erroRegistro = $null
                for ($tentativa = 1; $tentativa -le 3; $tentativa++) {
                    try {
                        [IO.File]::AppendAllText($logPath, ($linha + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
                        $registrado = $true
                        break
                    } catch {
                        $erroRegistro = $_.Exception.Message
                        if ($tentativa -lt 3) { Start-Sleep -Milliseconds (200 * $tentativa) }
                    }
                }

                # Sem registro nao sai acao externa. Decisao do operador (2026-08-17): a auditoria
                # e parte do gate R20, nao contabilidade a parte. Um push bloqueado se resolve com
                # um comando; uma linha de auditoria que nunca existiu e invisivel pra sempre.
                #
                # Mensagem PROPRIA, nao o BLOCK generico do fim do script: aqui a autorizacao E
                # valida e o operador autorizou de verdade -- dizer "requer aprovacao explicita"
                # mandaria ele reautorizar um problema que nao e de autorizacao.
                if (-not $registrado) {
                    [Console]::Error.WriteLine("")
                    [Console]::Error.WriteLine("[percus:hook external-action-guard] BLOCK (R20):")
                    [Console]::Error.WriteLine("  Comando: $comandoLog")
                    [Console]::Error.WriteLine("  Razao: autorizacao VALIDA (id: $($auth.id)), mas nao consegui registrar o uso em .percus/autorizacoes-usadas.jsonl apos 3 tentativas.")
                    [Console]::Error.WriteLine("  Erro tecnico: $erroRegistro")
                    [Console]::Error.WriteLine("")
                    [Console]::Error.WriteLine("  A auditoria e parte do gate R20 -- acao externa sem registro nao sai.")
                    [Console]::Error.WriteLine("  Libere a escrita do arquivo e repita o comando; a autorizacao continua valendo.")
                    [Console]::Error.WriteLine("")
                    exit 2
                }

                [Console]::Error.WriteLine("[percus:hook external-action-guard] autorizacao em lote ativa (id: $($auth.id), motivo: $($auth.motivo), idade: $([math]::Round($idadeSeg/60,1))min) -- permitindo.")
                exit 0
            }
        }
    } catch {
        # Qualquer falha nesta checagem especifica (arquivo ilegivel, JSON invalido, campo
        # faltando, relogio no passado) NAO libera -- so significa "nao consegui confirmar
        # autorizacao", cai pro fluxo normal do R20 abaixo. Fail-closed desta checagem, mesmo
        # com o resto do hook sendo fail-open pra erro interno inesperado.
        [Console]::Error.WriteLine("[percus:hook external-action-guard] falha ao processar autorizacao em lote: $($_.Exception.Message)")
    }

    # Verifica council recente (premise_validity)
    $councilDir = Join-Path $cwd ".deepseek/council-log"
    $councilBad = $false
    $councilBadReason = ""

    if (Test-Path $councilDir) {
        $latestCouncil = Get-ChildItem $councilDir -Filter "*.jsonl" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestCouncil -and ((Get-Date) - $latestCouncil.LastWriteTime).TotalMinutes -lt 60) {
            $councilContent = Get-Content -Encoding UTF8 $latestCouncil.FullName -Raw
            if ($councilContent -match '"premise_validity"\s*:\s*"(invalid|unverified)"') {
                $councilBad = $true
                $councilBadReason = "council log $($latestCouncil.Name) tem premise_validity=$($matches[1])"
            }
        }
    }

    # Fact-check (F3) ja roda no pipeline de review desde v6.7.0 (scripts/fact-check.ps1):
    # findings INFUNDADO sao filtrados antes do consolidador. Logo, qualquer finding que
    # chegue a uma acao externa ja passou por fact-check — nao ha check adicional aqui.

    if ($councilBad) {
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine("[percus:hook external-action-guard] BLOCK (R20):")
        [Console]::Error.WriteLine("  Comando: $comandoLog")
        [Console]::Error.WriteLine("  Razao: $councilBadReason")
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine("  R20 — Decisoes de conselho com premise_validity ruim NAO autorizam acao externa publica.")
        [Console]::Error.WriteLine("  Antes de prosseguir:")
        [Console]::Error.WriteLine("    1. Operador valida sintese do council explicitamente")
        [Console]::Error.WriteLine("    2. Findings passaram por fact-check")
        [Console]::Error.WriteLine("    3. OU setar PERCUS_EXTERNAL_OVERRIDE=1 com motivo declarado")
        [Console]::Error.WriteLine("")
        exit 2
    }

    # Default: bloqueia acao externa publica sem aprovacao explicita
    # (mesmo que council esteja OK — operador deve validar EXPLICITAMENTE cada acao publica)
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("[percus:hook external-action-guard] BLOCK (R20):")
    [Console]::Error.WriteLine("  Comando: $comandoLog")
    [Console]::Error.WriteLine("  Razao: acao externa publica requer aprovacao explicita do operador (R20)")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  Para autorizar: setar PERCUS_EXTERNAL_OVERRIDE=1 com motivo declarado no commit/log.")
    [Console]::Error.WriteLine("")
    exit 2
} catch {
    # Falha graceful — nao bloqueia injustamente
    [Console]::Error.WriteLine("[percus:hook external-action-guard] erro interno (skip): $($_.Exception.Message)")
    exit 0
}
