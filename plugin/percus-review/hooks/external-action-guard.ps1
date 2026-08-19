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
    #
    # ATENCAO -- ISTO E BLOCKLIST POR ENUMERACAO, e blocklist erra sempre pro mesmo lado: o que
    # nasce depois dela passa. Medido em 2026-08-19: um `wrangler versions deploy` rodado por ssh
    # publicou um site em PRODUCAO e nao casou padrao nenhum. O operador tinha autorizado na
    # conversa, mas o guard teria deixado passar do mesmo jeito -- a protecao naquele caminho era
    # ilusoria. A 6.41.0 ja documentara esta exata classe ("a coisa N+1 nasceu fora da guarda").
    # Por isso os padroes abaixo descrevem CLASSES de acao -- publicar, executar em outra maquina,
    # mutar estado alheio por HTTP -- em vez de nomes de ferramenta, um a um.
    #
    # O que ele CONTINUA sem cobrir, declarado aqui para nao virar falsa seguranca: chamada de SDK
    # dentro de um script (`python deploy.py`), ferramenta de deploy que ainda nao existe, e
    # qualquer coisa que nao passe pelo campo `command` do Bash. A R20 segue sendo
    # responsabilidade do agente e do operador; este hook e rede, nao garantia.
    #
    # ⚠️ Efeito colateral conhecido: como o guard le o TEXTO do comando, procurar ou editar estes
    # padroes dispara o proprio guard (`grep 'slack-cli' guard.sh` bloqueia). Editar este arquivo
    # exige ferramenta de edicao, nao shell.

    # Inicio de comando: comeco da string, ou logo depois de um separador de shell. Serve para
    # distinguir EXECUTAR de MENCIONAR -- ver o bloco "publicar" abaixo.
    # `[;&|(]+` com o MAIS: o irmao .sh ja usava, e este nao -- divergencia pega pelo review.
    # `;; ssh vps` escapava so aqui. Regra duplicada em duas linguagens diverge no detalhe, nao
    # no desenho; e o detalhe que decide se a guarda pega.
    $cmdIni = '(?:^|[;&|(]+\s*|&&\s*|\|\|\s*|\bthen\s+|\bdo\s+)'

    $externalPatterns = @(
        # --- interacao publica em plataforma de terceiros ---
        'gh\s+(pr|issue)\s+comment',
        'gh\s+pr\s+(close|merge)',
        'gh\s+issue\s+close',
        'slack-cli',
        'git\s+push',
        'mailto:',
        # --- publicar: o resultado fica visivel pra quem nao e a gente (add. 2026-08-19) ---
        #
        # ⚠️ Estes vem ANCORADOS em POSICAO DE COMANDO (`$cmdIni` = inicio da linha, ou depois de
        # ; & | ( && ||), e a razao foi medida na mesma sessao em que nasceram: sem a ancora, a
        # primeira versao bloqueou a redacao de um documento que apenas CITAVA `wrangler versions
        # deploy` dentro de uma tag HTML. Guard que impede escrever sobre deploy vira imposto, e
        # imposto acaba desligado -- pior que guard nenhum. Os padroes de cima (gh/git/slack) NAO
        # sao ancorados de proposito: sao especificos o bastante para prosa raramente casar, e
        # afrouxa-los custaria deteccao real.
        "$cmdIni(sudo\s+)?(npx\s+|npm\s+exec\s+|yarn\s+)?wrangler\s+(versions\s+|pages\s+|triggers\s+)?(deploy|publish)",
        "$cmdIni(sudo\s+)?docker\s+stack\s+deploy",
        "$cmdIni(sudo\s+)?docker\s+service\s+(create|update|scale|rm)",
        "$cmdIni(sudo\s+)?(npx\s+)?vercel\s+(deploy|--prod)",
        "$cmdIni(sudo\s+)?(npx\s+)?netlify\s+deploy",
        "$cmdIni(sudo\s+)?kubectl\s+(apply|rollout|delete)",
        # --- executar em OUTRA maquina: o efeito nao fica nesta (ancorado pelo mesmo motivo) ---
        #
        # ⚠️ NAO exige `user@host`. A primeira versao exigia, e o review pegou o buraco: `ssh vps
        # 'cmd'`, com alias do ~/.ssh/config, e a forma MAIS comum de execucao remota e nao tem
        # arroba nenhuma -- passava batido. O `\s` depois de `ssh` ja exclui `ssh-keygen`/`ssh-add`,
        # e o `[^\s-]` no host impede casar uma flag solta.
        # O host pode terminar em espaco, em separador de comando OU no fim da string:
        # `ssh host;` e `ssh host &` sao execucao remota igual, e a 1a versao exigia espaco
        # depois do host -- as duas formas escapavam. Achado do review.
        "$cmdIni(sudo\s+)?ssh\s+(-\S+\s+)*[^\s-]\S*(\s|[;&|]|$)"
    )

    # --- mutar estado alheio por HTTP. Lista SEPARADA de proposito: so ela aceita a isencao de
    #     host local, e por isso nao precisa da lista negativa que a versao anterior usava para
    #     decidir quem podia ser isentado. O review pegou o defeito daquela: um POST para localhost
    #     num comando que por acaso contivesse a substring "gh" (num nome de arquivo, p.ex.) ficava
    #     sem a isencao e era bloqueado. Separar as duas familias resolve pela estrutura.
    #
    #     GET fica de fora DE PROPOSITO: ler e livre, escrever e que precisa do operador.
    #     Ancorados como os de deploy, e pelo mesmo motivo -- prosa que CITA `curl -X POST` nao e
    #     um POST.
    $httpMutationPatterns = @(
        "$cmdIni(sudo\s+)?curl\b[^|;]*\s-X\s*[`"']?(POST|PUT|PATCH|DELETE)",
        "$cmdIni(sudo\s+)?curl\b[^|;]*\s--request\s+[`"']?(POST|PUT|PATCH|DELETE)"
    )

    $isExternalAction = $false
    foreach ($p in $externalPatterns) {
        if ($command -match $p) { $isExternalAction = $true; break }
    }

    if (-not $isExternalAction) {
        foreach ($p in $httpMutationPatterns) {
            if ($command -match $p) { $isExternalAction = $true; break }
        }
        # Isencao de host local: mutacao HTTP contra a propria maquina nao sai daqui, e bloquear
        # isso transformaria o guard em imposto sobre desenvolvimento normal -- guard barulhento
        # acaba desligado, que e pior que guard ausente (licao das travas de invocacao da 6.41.0).
        # Conservador: basta UMA url externa no comando para continuar valendo.
        if ($isExternalAction) {
            $urls = [regex]::Matches($command, '(?i)https?://[^\s"''`)]+')
            if ($urls.Count -gt 0) {
                $externas = @($urls | Where-Object { $_.Value -notmatch '(?i)://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])' })
                if ($externas.Count -eq 0) { $isExternalAction = $false }
            }
        }
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
