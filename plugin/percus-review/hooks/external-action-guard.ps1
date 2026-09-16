#requires -Version 5.1
# Hook PreToolUse Percus (Layer 1 R20 enforcement).
# Bloqueia tools externos publicos quando council recente tem premise_validity != ok
# OU quando findings criticos nao tem fact_check: CONFIRMADO.
# Erro interno: exit 0 SO se o comando nao foi (nem poderia ser) acao externa. Depois de detectada
# a acao externa, qualquer excecao bloqueia (exit 2) -- ver o catch no fim (Fase 5, rodada 2).

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$detectado = $false
$command = $null
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
    # dentro de um script cujo NOME nao denuncia o destino (`python deploy.py`, `python sync.py`),
    # ferramenta de deploy que ainda nao existe, e qualquer coisa que nao passe pelo campo
    # `command` do Bash. A R20 segue sendo responsabilidade do agente e do operador; este hook e
    # rede, nao garantia.
    # 📌 Em 2026-08-21 esta lacuna ENCOLHEU, mas nao fechou: wrapper cujo nome carrega `vps`/`ssh`
    # passou a casar (ver o padrao no fim da lista). O caso que motivou foi medido -- o guard
    # barrou o comando remoto direto e deixou passar o wrapper equivalente do projeto. Um script
    # com nome neutro continua invisivel, e nomear isso e mais honesto do que deixar parecer
    # coberto.
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

    # git e gh: DETECCAO LARGA, nao enumeracao de forma (Fase 5, rodada 2, 2026-09-16).
    # 🔴 Historico medido: `git\s+push` exigia o subcomando colado no `git`, e `git -C "<kit>" push`
    # saiu SEM autorizacao e sem auditoria. A 1a correcao enumerou opcoes globais e a revisao de
    # seguranca achou 20+ formas que ainda passavam (`git "push"`, `git -C x 2>/dev/null push`,
    # `git -c alias.x=push x`, `\`+LF, `bash -c` com aspa escapada...) e um fail-open novo sob PS 5.1.
    # Lista textual nunca fecha. Regra agora: normaliza o texto (tira aspas, barra invertida,
    # continuacao de linha, ${IFS}) e trata como acao externa TODO comando com um token `git` E um
    # token `push`/`send-pack` em qualquer posicao; idem token `gh` com comment/close/merge/create/sync.
    # FALSO POSITIVO E ACEITO de proposito (`git log --grep push` pede autorizacao). A mensagem de
    # bloqueio diz como liberar. Ofuscacao que nem assim aparece fica para o hook pre-push do git.
    # Fronteira de token: nao-[A-Za-z0-9_] dos dois lados (identica no .sh).
    $fronteira = '[^A-Za-z0-9_]'
    $reGit    = '(?i)(?:^|' + $fronteira + ')git(?:\.exe)?(?:' + $fronteira + '|$)'
    $rePush   = '(?i)(?:^|' + $fronteira + ')(?:push|send-pack)(?:' + $fronteira + '|$)'
    $reGh     = '(?i)(?:^|' + $fronteira + ')gh(?:\.exe)?(?:' + $fronteira + '|$)'
    $reGhAcao = '(?i)(?:^|' + $fronteira + ')(?:comment|close|merge|create|sync)(?:' + $fronteira + '|$)'

    function ConvertTo-TextoNormal {
        param([string]$Texto)
        $t = $Texto -replace '\\\r?\n', ' '
        $t = $t -replace '\$\{IFS\}|\$IFS', ' '
        $t = $t -replace '["'']', ''
        $t = $t -replace '\\(.)', '$1'
        return $t
    }
    # Testa o texto CRU e o NORMALIZADO: a normalizacao apaga a barra de caminho Windows
    # (`D:\x\git.exe` vira `D:xgit.exe`), e o cru nao ve `git p\ush`. Um dos dois basta.
    function Test-Token {
        param([string]$Texto, [string]$Re)
        if ($Texto -match $Re) { return $true }
        return ((ConvertTo-TextoNormal $Texto) -match $Re)
    }

    $externalPatterns = @(
        # --- interacao publica em plataforma de terceiros (git/gh: ver deteccao larga acima) ---
        'slack-cli',
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
        "$cmdIni(sudo\s+)?ssh\s+(-\S+\s+)*[^\s-]\S*(\s|[;&|]|$)",
        # ⚠️ Wrapper LOCAL que abre sessao remota. Medido em 2026-08-21: o guard barrou o `ssh`
        # direto e o MESMO efeito passou pelo wrapper do projeto (`python scripts/vps_exec.py`),
        # porque o texto do comando nao carrega a palavra que o padrao acima procura. O agente
        # respeitou o bloqueio e reportou em vez de usar o atalho -- mas contar com isso e contar
        # com disciplina, nao com rede.
        # O sinal usado e o NOME do script declarar destino remoto (`vps`/`ssh`), nao o que ele
        # faz por dentro: adivinhar conteudo de script arbitrario e o buraco que o bloco "o que
        # ele continua sem cobrir" mantem aberto de proposito.
        # ⛔ Exige INTERPRETADOR na frente. Sem isso, `cat scripts/vps_exec.py` e
        # `grep vps_exec RUNBOOK.md` bloqueariam -- guard que impede LER o wrapper vira imposto,
        # e imposto acaba desligado. Ha teste para os dois lados.
        # ⛔ NAO use `\b` aqui. Ele parece a escolha obvia e DIVERGE do gemeo .sh em dois pontos,
        # os dois pegos pelo review cross-provider:
        #   1. `\b` trata `_` como caractere de PALAVRA, entao `my_vps.py` nao casava aqui e
        #      casava no .sh -- e `_` e justamente o separador mais comum em nome de script.
        #   2. `\b` no fim da extensao nao tem equivalente automatico em ERE, e `vps_exec.pyfoo`
        #      casava so no .sh.
        # A fronteira agora e explicita e identica nas duas linguagens: nao-alfanumerico dos dois
        # lados. Lookaround aqui, classe de caractere la -- mesma semantica, sintaxe de cada uma.
        "$cmdIni(sudo\s+)?(python[0-9.]*|py|uv\s+run|poetry\s+run|node|bash|sh|pwsh|powershell(\.exe)?)\s+(-\S+\s+)*\S*(?<![A-Za-z0-9])(vps|ssh)[-_]?[A-Za-z0-9_]*\.(py|sh|ps1|mjs|js)(?![A-Za-z0-9])"
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

    # Acao externa das listas "por padrao" (tudo que nao e git/gh). Isencao de host local: mutacao
    # HTTP contra a propria maquina nao sai daqui, e bloquear isso transformaria o guard em imposto
    # sobre desenvolvimento normal -- guard barulhento acaba desligado (licao da 6.41.0).
    # Conservador: basta UMA url externa no texto para continuar valendo.
    function Test-ExternoPorPadrao {
        param([string]$Texto)
        foreach ($padrao in $externalPatterns) {
            if ($Texto -match $padrao) { return $true }
        }
        foreach ($padrao in $httpMutationPatterns) {
            if ($Texto -match $padrao) {
                $urls = [regex]::Matches($Texto, '(?i)https?://[^\s"''`)]+')
                if ($urls.Count -eq 0) { return $true }
                $externas = @($urls | Where-Object { $_.Value -notmatch '(?i)://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])' })
                return ($externas.Count -gt 0)
            }
        }
        return $false
    }

    $temGit = Test-Token $command $reGit
    $temGh  = Test-Token $command $reGh
    $ehGitPush = $temGit -and (Test-Token $command $rePush)
    $ehGh      = $temGh -and (Test-Token $command $reGhAcao)
    $isExternalAction = $ehGitPush -or $ehGh -or (Test-ExternoPorPadrao $command) -or (Test-ExternoPorPadrao (ConvertTo-TextoNormal $command))

    if (-not $isExternalAction) { exit 0 }
    # A partir daqui NENHUMA excecao libera: o catch do fim ve esta flag e sai 2.
    $detectado = $true

    $cwd = (Get-Location).Path

    # ESCOPO: de qual repositorio e a acao. A autorizacao e o log sao por projeto, entao o hook so
    # libera o que consegue atribuir a UM repositorio SEM interpretar shell. Tudo que exigiria
    # interpretar (cd, variavel, --git-dir, -C relativo ou com `..`, duas acoes, redirecionamento,
    # aspas no meio) e AMBIGUO e bloqueia MESMO COM autorizacao. A revisao mediu o que acontece
    # quando o hook tenta resolver: `cd B && git -C . push` e `git -C "$X/.." push` liberavam push
    # em B com a autorizacao de A, e `IsPathRooted` lancava sob PS 5.1 e caia no fail-open.
    # Forma liberavel: `git -C "<caminho absoluto>" <subcomando> <args simples>` (ou sem -C = cwd),
    # e para gh: `[VAR=valor ...] gh <args>` no cwd.
    $motivos = @()
    $escopoRepo = $temGit -or $temGh
    if ($command -match '(?i)--git-dir|--work-tree|GIT_DIR|GIT_WORK_TREE') { $motivos += '--git-dir/--work-tree/GIT_DIR' }
    if ($escopoRepo) {
        if ($command -match '(?i)(?:^|[^A-Za-z0-9_-])(?:cd|pushd|popd|chdir|Set-Location|Push-Location)(?:[^A-Za-z0-9_-]|$)') { $motivos += 'cd no comando' }
        if ($command -match '\$') { $motivos += 'variavel ($) no comando' }
        if ($command -match '%[A-Za-z_][A-Za-z0-9_]*%') { $motivos += 'variavel (%VAR%) no comando' }
        if ($command.Contains([string][char]96)) { $motivos += 'crase no comando' }
    }

    # Segmentos por separador de shell. `2>&1` sai antes (o `&` dele nao separa comando).
    $semRedir = $command -replace '(?<=\s)[12]?>&[12](?=\s|$)', ' '
    $segmentos = @($semRedir -split '&&|\|\||[;|&\r\n()]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    # Relevante = trecho com token git, token gh ou padrao externo. `push` SOLTO (`... | grep push`) nao
    # conta: push so executa via git, e aspas que atravessam separador deixam o trecho do git fora da
    # forma simples (ela nao aceita aspa aberta) -- ex. `git -C "a|b" push` continua ambiguo. Achado R11.
    $relevantes = @($segmentos | Where-Object {
        (Test-Token $_ $reGit) -or (Test-Token $_ $reGh) -or (Test-ExternoPorPadrao $_)
    })
    if ($relevantes.Count -ne 1) { $motivos += "$($relevantes.Count) trechos de acao externa no comando (um por comando)" }

    $dirProjeto = $cwd
    if ($motivos.Count -eq 0 -and $escopoRepo) {
        $trecho = $relevantes[0]
        # Subcomando NU logo depois do `git` (ou do unico -C); argumentos depois dele podem vir citados
        # inteiros (`commit -m "corrige push"`) -- argumento de subcomando nao muda o repositorio.
        # `(?i:git)`: `Git.exe` e o mesmo binario no Windows; `-C` segue sensivel a caixa (`-c` e outra coisa).
        $reGitSimples = '^(?i:git(?:\.exe)?)(?:\s+-C\s+(?:"(?<dir>[^"]*)"|''(?<dir>[^'']*)''|(?<dir>[^\s"''$%<>|&;*?]+)))?\s+[A-Za-z][A-Za-z0-9-]*(?:\s+(?:[A-Za-z0-9_./:+@^~=,-]+|"[^"]*"|''[^'']*''))*$'
        $reGhSimples  = '^(?:[A-Za-z_][A-Za-z0-9_]*=\S+\s+)*gh(?:\.exe)?\s+\S'
        if (Test-Token $trecho $reGit) {
            $mGit = [regex]::Match($trecho, $reGitSimples)
            if (-not $mGit.Success) {
                $motivos += 'git fora da forma simples'
            } elseif ($mGit.Groups['dir'].Success) {
                $dirC = $mGit.Groups['dir'].Value
                if ($dirC -notmatch '^(?:[A-Za-z]:[\\/]|/)') { $motivos += '-C relativo' }
                elseif ($dirC -match '(?:^|[\\/])\.{1,2}(?:[\\/]|$)') { $motivos += '-C com . ou ..' }
                elseif ($dirC -match '[$%<>|&;*?"''\t]') { $motivos += '-C com caractere especial' }
                else {
                    if ($env:OS -eq 'Windows_NT' -and $dirC -match '^/(?:cygdrive/)?([a-zA-Z])(?:/(.*))?$') {
                        $dirC = $matches[1].ToUpper() + ':\' + ($matches[2] -replace '/', '\')
                    }
                    $dirProjeto = $dirC
                }
            }
        } elseif ($trecho -notmatch $reGhSimples) {
            $motivos += 'gh fora da forma simples'
        }
    }

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

    # LIMITE DECLARADO (R11): so enxerga o MESMO comando. Config persistente feita antes, em outro
    # comando (`git config --global core.hooksPath x`, `setx GIT_CONFIG_GLOBAL`), nao aparece aqui.
    # `-n` em push e --dry-run (inofensivo) e bloqueia mesmo assim, por decisao do controlador.
    # Formas que DESLIGAM o hook pre-push do git (camada 2, commit f440c4d, medido): bloqueiam SEMPRE,
    # antes do override e da autorizacao -- aceitar qualquer uma delas faria a camada 2 nao existir.
    # `--no-v...` cobre a abreviacao que o git aceita (`--no-verif`); `-n` em push (em cluster
    # tambem, `-fn`); core.hooksPath por -c/--config-env/`git config`; GIT_CONFIG* (COUNT/KEY/VALUE/
    # PARAMETERS/GLOBAL) e include.path/includeIf, que carregam um hooksPath de outro arquivo.
    if ($ehGitPush) {
        $textoBypass = $command + "`n" + (ConvertTo-TextoNormal $command)
        $bypass = @()
        if ($textoBypass -match '(?i)--no-v') { $bypass += '--no-verify' }
        # `-n` so no trecho do git (`| tail -n 3` e de outro comando).
        foreach ($trechoGit in @($textoBypass -split '&&|\|\||[;|&\r\n()]' | Where-Object { $_ -match $reGit })) {
            if ($trechoGit -cmatch '(?<![A-Za-z0-9_-])-[A-Za-z]*n[A-Za-z]*(?![A-Za-z0-9_-])') { $bypass += '-n'; break }
        }
        # Sem exigir `core.`: `-c CORE.HOOKSPATH`, `--config-env`, include e arquivos de config
        # alternativos (GIT_CONFIG_GLOBAL/SYSTEM/NOSYSTEM, XDG_CONFIG_HOME, HOME=) trocam o hooksPath
        # sem o texto `core.hooksPath` aparecer (revisao de ataque da camada 2, achado 3).
        if ($textoBypass -match '(?i)hookspath') { $bypass += 'hooksPath' }
        if ($textoBypass -match '(?i)--config-env') { $bypass += '--config-env' }
        if ($textoBypass -match '(?i)GIT_CONFIG') { $bypass += 'GIT_CONFIG*' }
        if ($textoBypass -match '(?i)include\.path|includeif') { $bypass += 'include.path/includeIf' }
        if ($textoBypass -match '(?i)XDG_CONFIG_HOME|home\s*=') { $bypass += 'HOME/XDG_CONFIG_HOME' }
        # Copia do .git no mesmo comando: a copia leva a config sem o hook, e o push sai dela.
        if (($textoBypass -match '(?i)(?:^|[^A-Za-z0-9_-])(?:cp|robocopy|xcopy|copy|copy-item|cpi|rsync|mv|move|move-item|tar)(?:[^A-Za-z0-9_-]|$)') -and
            ($textoBypass -match '(?i)\.git(?:[^A-Za-z0-9_]|$)')) { $bypass += 'copia do .git' }
        if ($bypass.Count -gt 0) {
            [Console]::Error.WriteLine("")
            [Console]::Error.WriteLine("[percus:hook external-action-guard] BLOCK (R20):")
            [Console]::Error.WriteLine("  Comando: $comandoLog")
            [Console]::Error.WriteLine("  Razao: $($bypass -join ', '): essas formas desligam o hook pre-push do git (camada 2) e NAO sao aceitas,")
            [Console]::Error.WriteLine("  nem com autorizacao nem com PERCUS_EXTERNAL_OVERRIDE. Rode sem elas: git -C `"<caminho absoluto>`" push <remoto> <branch>")
            [Console]::Error.WriteLine("")
            exit 2
        }
    }

    # Escopo ambiguo bloqueia ANTES do override e da autorizacao: liberar aqui seria atribuir a acao a
    # um repositorio que o hook nao conseguiu determinar -- e o override nem grava auditoria. Achado
    # R11 (rodada 2): com o override antes, `cd B && git -C . push` saia 0 sem linha nenhuma.
    if ($motivos.Count -gt 0) {
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine("[percus:hook external-action-guard] BLOCK (R20):")
        [Console]::Error.WriteLine("  Comando: $comandoLog")
        [Console]::Error.WriteLine("  Razao: escopo ambiguo -- $($motivos -join '; '). A autorizacao e por projeto e o hook so libera o que atribui a UM repositorio sem interpretar shell.")
        [Console]::Error.WriteLine("  use a forma simples: git -C `"<caminho absoluto>`" push <remoto> <branch>")
        [Console]::Error.WriteLine("  (uma acao externa por comando; sem cd, sem variavel, sem --git-dir/--work-tree, sem aspas fora do -C)")
        [Console]::Error.WriteLine("  Nem autorizacao nem PERCUS_EXTERNAL_OVERRIDE liberam escopo ambiguo. Falso positivo (ex.: git log --grep push")
        [Console]::Error.WriteLine("  junto de outro comando)? Rode o comando sozinho na forma simples, com autorizacao.")
        [Console]::Error.WriteLine("")
        exit 2
    }

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
    # do fim do script. (O catch generico era fail-OPEN; desde a Fase 5 ele bloqueia depois da
    # deteccao, mas a mensagem daqui e mais util.) Erro NESTA checagem especifica (arquivo ilegivel, JSON
    # corrompido, campo faltando) tem que continuar pro fluxo normal do R20 -- ou seja, tem que
    # poder BLOQUEAR. Fail-open aqui seria: permissao negada no arquivo = "ah, deu erro, libera
    # geral" -- o oposto do que devia acontecer.
    try {
        $authFile = Join-Path $dirProjeto ".percus/acao-externa-autorizada.json"
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
                $logPath = Join-Path $dirProjeto ".percus/autorizacoes-usadas.jsonl"

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
    $councilDir = Join-Path $dirProjeto ".deepseek/council-log"
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
    [Console]::Error.WriteLine("  Para autorizar: scripts/autorizar-acao-externa.ps1 -Motivo '<motivo>' (vale 60 min, por projeto)")
    [Console]::Error.WriteLine("  ou PERCUS_EXTERNAL_OVERRIDE=1 com motivo declarado no commit/log.")
    [Console]::Error.WriteLine("  Deteccao e LARGA de proposito: qualquer comando com git + a palavra push (ou gh + comment/close/merge/create/sync)")
    [Console]::Error.WriteLine("  conta como acao externa. Falso positivo (ex.: git log --grep push) libera do mesmo jeito, com autorizacao.")
    [Console]::Error.WriteLine("")
    exit 2
} catch {
    # Erro interno. Libera SO o que nao e (nem pode ser) acao externa: depois da deteccao, ou com
    # texto que um dos gatilhos casaria, excecao BLOQUEIA. A revisao da Fase 5 mediu o contrario:
    # `IsPathRooted` lancava sob PS 5.1 com `>` no `-C`, caia aqui e liberava o push (exit 0).
    $erroMsg = $_.Exception.Message
    $gatilho = $false
    try { $gatilho = ($command -and ([string]$command -match '(?i)push|send-pack|gh|git|slack|mailto|wrangler|docker|vercel|netlify|kubectl|ssh|vps|curl')) } catch { $gatilho = $true }
    if ($detectado -or $gatilho) {
        [Console]::Error.WriteLine("[percus:hook external-action-guard] BLOCK (R20): erro interno ao avaliar possivel acao externa -- bloqueando (fail-closed): $erroMsg")
        exit 2
    }
    [Console]::Error.WriteLine("[percus:hook external-action-guard] erro interno (skip): $erroMsg")
    exit 0
}
