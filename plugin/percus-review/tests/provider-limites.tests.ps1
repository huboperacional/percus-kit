#requires -Version 5.1
# Prova que os limites de cada provider (sampling param, teto de tokens, timeout) batem com a
# NATUREZA do modelo que eles chamam hoje -- e que .ps1 e .sh concordam sobre esses limites.
#
# Medido em 2026-08-16, rodando o conselho com um prompt de design real (nao "responda PONG"):
#
#   cross-claude.sh   HTTP 400 "temperature is deprecated for this model"  -> perna bash MUDA
#   deepseek (ps1)    reasoning 6784..8192+ contra teto 8192               -> ok/truncated/empty
#                                                                             na sorte
#
# As duas sao a MESMA classe: alguem trocou o modelo e nao reavaliou os parametros ao lado.
# A 6.36.2 subiu Cross-Claude pra Sonnet 5; a 6.36.3 tirou o temperature do fact-check.sh e
# do cross-claude.ps1 -- e deixou o cross-claude.sh, que e o provider em si. O teste de
# paridade da 6.36.3 compara a tabela de MODELOS dos dois orquestradores, entao ficou verde
# enquanto o provider bash estava 100% quebrado. Modelo igual, parametro diferente, ninguem viu.
#
# Nenhum teste aqui chama API: todos leem o fonte.

Describe "sampling param proibido na familia Sonnet 5 / Opus 5" {

    BeforeAll {
        $script:provDir = Join-Path (Split-Path $PSScriptRoot -Parent) "providers"

        # Remove comentario pra nao confundir "o arquivo FALA de temperature" (cross-claude.ps1
        # documenta por que nao manda) com "o arquivo MANDA temperature" (era o caso do .sh).
        function script:Remove-Comentarios([string]$src, [string]$tipo) {
            if ($tipo -eq 'ps1') {
                $src = [regex]::Replace($src, '(?s)<#.*?#>', '')
                $src = [regex]::Replace($src, '(?m)#.*$', '')
            } else {
                $src = [regex]::Replace($src, '(?m)^\s*#.*$', '')
            }
            return $src
        }
    }

    It "<Arq> nao envia sampling param (a API devolve 400 e a perna fica muda)" -ForEach @(
        @{ Arq = 'cross-claude.ps1'; Tipo = 'ps1' }
        @{ Arq = 'cross-claude.sh';  Tipo = 'sh'  }
    ) {
        $src = Get-Content (Join-Path $script:provDir $Arq) -Raw
        $codigo = script:Remove-Comentarios $src $Tipo

        # Anti-vacuidade: se o strip comesse o arquivo inteiro, tudo passaria sem aferir nada.
        $codigo | Should -Match 'max_tokens' -Because "o corpo da requisicao tem que sobrar apos remover comentario"

        $codigo | Should -Not -Match '(?i)temperature' -Because "Sonnet 5 / Opus 5 rejeitam com HTTP 400"
        $codigo | Should -Not -Match '(?i)top_p'       -Because "mesmo motivo: sampling param removido nessa familia"
        $codigo | Should -Not -Match '(?i)top_k'       -Because "mesmo motivo: sampling param removido nessa familia"
    }
}

Describe "teto de tokens dimensionado pra modelo que raciocina" {

    BeforeAll {
        $script:provDir = Join-Path (Split-Path $PSScriptRoot -Parent) "providers"
        # Teto minimo pra quem raciocina por padrao. Medido: prompt de review real gastou
        # 6784-8192+ tokens SO raciocinando, e o teto cobre pensamento + resposta juntos.
        # 16000 e o numero que a 6.36.2 ja tinha estabelecido no cross-claude.ps1.
        $script:TETO_MIN_RACIOCINIO = 16000
    }

    It "<Prov> tem teto >= 16000 nos dois runtimes (o modelo pensa antes de responder)" -ForEach @(
        @{ Prov = 'cross-claude' }   # Sonnet 5 / Opus 5: thinking ligado por padrao
        @{ Prov = 'deepseek' }       # deepseek-v4-flash: reasoning_tokens dentro de completion
    ) {
        $ps1 = Get-Content (Join-Path $script:provDir "$Prov.ps1") -Raw
        $sh  = Get-Content (Join-Path $script:provDir "$Prov.sh")  -Raw

        $mPs = [regex]::Match($ps1, '\[int\]\$MaxTokens\s*=\s*(?<n>\d+)')
        $mSh = [regex]::Match($sh,  '(?m)^MAX_TOKENS="(?<n>\d+)"')
        $mPs.Success | Should -BeTrue -Because "o default de MaxTokens do .ps1 tem que ser localizavel"
        $mSh.Success | Should -BeTrue -Because "o default de MAX_TOKENS do .sh tem que ser localizavel"

        [int]$mPs.Groups['n'].Value | Should -BeGreaterOrEqual $script:TETO_MIN_RACIOCINIO
        [int]$mSh.Groups['n'].Value | Should -BeGreaterOrEqual $script:TETO_MIN_RACIOCINIO
    }
}

# NAO use "<->" no nome de um Describe/It: o Pester trata <algo> como placeholder de dado e
# expande pra $algo, entao "<->" vira $- e o bloco inteiro morre com CommandNotFoundException
# ANTES de rodar qualquer assercao -- verde nenhum, vermelho nenhum, so um bloco ausente.
Describe "paridade ps1 vs sh nos limites do provider" {

    BeforeAll {
        $script:provDir = Join-Path (Split-Path $PSScriptRoot -Parent) "providers"
    }

    # Nao basta os dois orquestradores escolherem o mesmo MODELO (isso a 6.36.3 ja garante):
    # o wrapper bash tem os proprios defaults, e o orquestrador .sh nao passa --max-tokens.
    # Entao quem manda no runtime bash e o default do arquivo -- que ficou em 4096 com Sonnet 5.
    It "<Prov>: teto default igual nos dois runtimes" -ForEach @(
        @{ Prov = 'cross-claude' }
        @{ Prov = 'deepseek' }
        @{ Prov = 'groq-llama' }
    ) {
        $ps1 = Get-Content (Join-Path $script:provDir "$Prov.ps1") -Raw
        $sh  = Get-Content (Join-Path $script:provDir "$Prov.sh")  -Raw

        $mPs = [regex]::Match($ps1, '\[int\]\$MaxTokens\s*=\s*(?<n>\d+)')
        $mSh = [regex]::Match($sh,  '(?m)^MAX_TOKENS="(?<n>\d+)"')
        $mPs.Success | Should -BeTrue -Because "teto do .ps1 localizavel"
        $mSh.Success | Should -BeTrue -Because "teto do .sh localizavel"

        $mSh.Groups['n'].Value | Should -BeExactly $mPs.Groups['n'].Value `
            -Because "quem roda o conselho por bash tem que receber o mesmo teto de quem roda por PowerShell"
    }

    It "<Prov>: timeout igual nos dois runtimes" -ForEach @(
        @{ Prov = 'cross-claude' }
        @{ Prov = 'deepseek' }
        @{ Prov = 'groq-llama' }
    ) {
        $ps1 = Get-Content (Join-Path $script:provDir "$Prov.ps1") -Raw
        $sh  = Get-Content (Join-Path $script:provDir "$Prov.sh")  -Raw

        $mPs = [regex]::Match($ps1, '-TimeoutSec\s+(?<n>\d+)')
        $mSh = [regex]::Match($sh,  '--max-time\s+(?<n>\d+)')
        $mPs.Success | Should -BeTrue -Because "timeout do .ps1 localizavel"
        $mSh.Success | Should -BeTrue -Because "timeout do .sh localizavel"

        $mSh.Groups['n'].Value | Should -BeExactly $mPs.Groups['n'].Value `
            -Because "timeout diferente faz a mesma pergunta caber num runtime e estourar no outro"
    }

    It "<Prov>: timeout comporta o teto (subir teto sem subir timeout troca 'vazia' por 'timeout')" -ForEach @(
        @{ Prov = 'cross-claude' }
        @{ Prov = 'deepseek' }
    ) {
        # Medido 2026-08-16: chamadas de review que RESPONDERAM levaram 67s e 80s com teto 8192.
        # Com teto 16000 o tempo cresce junto -- 60s corta resposta boa no meio.
        $ps1 = Get-Content (Join-Path $script:provDir "$Prov.ps1") -Raw
        $m = [regex]::Match($ps1, '-TimeoutSec\s+(?<n>\d+)')
        $m.Success | Should -BeTrue -Because "timeout localizavel"
        [int]$m.Groups['n'].Value | Should -BeGreaterOrEqual 180 `
            -Because "resposta legitima ja levou 80s no teto antigo"
    }
}

Describe "Join-Path com 3+ argumentos nao sobrevive ao PS 5.1" {

    # Achado pelo proprio R11 em 2026-08-16, revisando esta versao. `-AdditionalChildPath` (o
    # parametro que aceita 3+ argumentos posicionais) so existe do PowerShell 6 em diante. No
    # 5.1 -- runtime real dos hooks -- a chamada lanca "Nao e possivel localizar um parametro
    # posicional que aceite o argumento 'x'".
    #
    # Por que nenhuma guarda existente pegava: o ps51-compat afere PARSE, e isto parseia
    # perfeitamente; quebra so em runtime. E a suite roda em pwsh 7, onde funciona. Verde nos
    # dois lugares, morto no unico que importa. Havia 3 sitios no kit, um deles um HOOK.
    #
    # Testes ficam de fora: eles so rodam sob Pester em pwsh 7, nunca sob 5.1.
    It "nenhum .ps1 de producao chama Join-Path com mais de um child path" {
        $raiz = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
        $arqs = @(Get-ChildItem $raiz -Recurse -Include *.ps1 -File -ErrorAction SilentlyContinue |
                  Where-Object { $_.FullName -notmatch '\\tests\\' })

        # Piso anti-vacuidade: varredura curta e varredura quebrada, nao kit limpo.
        $arqs.Count | Should -BeGreaterThan 10 -Because "o plugin tem dezenas de .ps1 de producao"

        # Um arg de destino + 2 ou mais child paths (string literal ou variavel). E tambem o
        # parametro EXPLICITO -AdditionalChildPath, que e PS 6+ por definicao: escrever o nome
        # dele ja e o bug, mesmo com um child path so. (R11 apontou os dois furos, 2026-08-16.)
        #
        # O separador entre argumentos e espaco HORIZONTAL, nunca `\s`. Com `\s` o regex casa
        # atraves de quebra de linha e um `Join-Path $a "b"` seguido de `$outraCoisa` na linha
        # DE BAIXO vira falso positivo -- aconteceu em 4 arquivos na primeira versao desta
        # guarda. Guarda que grita no arquivo certo pelo motivo errado ensina a ignorar guarda.
        $h   = '[^\S\r\n]'
        $arg = '(?:\([^)]*\)|\$\w+|"[^"]*"|''[^'']*'')'
        $padrao = "Join-Path$h+$arg$h+$arg$h+$arg"
        $padraoExplicito = '-AdditionalChildPath'
        $hits = @()
        foreach ($a in $arqs) {
            $texto = [IO.File]::ReadAllText($a.FullName)
            # Continuacao de linha com backtick vira linha unica ANTES de casar: sem isso,
            # quebrar a chamada em duas linhas escapa da guarda -- e quem quebra chamada longa
            # em duas linhas e justamente quem tem muitos argumentos.
            $texto = [regex]::Replace($texto, "`` *\r?\n[^\S\r\n]*", ' ')
            # Comentario fora: este proprio teste, e os comentarios que os consertos deixaram,
            # CITAM '-AdditionalChildPath' pra explicar o bug. Sem o strip, a guarda acusaria
            # a documentacao do conserto como se fosse o defeito.
            $texto = [regex]::Replace($texto, '(?s)<#.*?#>', '')
            $texto = [regex]::Replace($texto, '(?m)#.*$', '')
            $rel = $a.FullName.Replace($raiz + '\', '')
            foreach ($p in @($padrao, $padraoExplicito)) {
                if ([regex]::IsMatch($texto, $p)) { $hits += "$rel  (padrao: $p)" }
            }
        }
        @($hits) | Should -BeNullOrEmpty -Because "no PS 5.1 isso lanca em runtime e a guarda morre calada:`n$($hits -join "`n")"
    }
}

Describe "R11 nao libera commit com review vazia ou cortada" {

    BeforeAll {
        $script:reviewPath = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts") "deepseek-review.ps1"
    }

    # O marcador latest.jsonl E o que libera o commit. Ate 2026-08-16 ele era escrito
    # incondicionalmente: se o modelo devolvesse content="" (gastou o teto raciocinando), o
    # commit passava com ZERO review e nada dizia. Fail-open num gate.
    It "classifica a resposta com Get-StatusResposta antes de escrever o marcador" {
        $src = Get-Content $script:reviewPath -Raw

        $src | Should -Match '_resposta\.ps1' -Because "precisa carregar o classificador compartilhado"

        $idxCls   = $src.IndexOf('Get-StatusResposta')
        $idxMarca = $src.IndexOf('Move-Item -Path $logTmp')

        $idxCls   | Should -BeGreaterThan -1 -Because "o review tem que classificar a resposta"
        $idxMarca | Should -BeGreaterThan -1 -Because "a escrita do marcador tem que ser localizavel"
        $idxCls   | Should -BeLessThan $idxMarca -Because "classificar DEPOIS de liberar o commit nao serve pra nada"
    }

    It "o lado bash barra os MESMOS dois estados (vazia e cortada)" {
        # O .sh ja barrava vazia desde sempre e o .ps1 nao -- divergencia na direcao contraria
        # da usual. Nenhum dos dois barrava CORTADA, que tem texto e passa no teste de vazio.
        $sh = Get-Content (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts") "deepseek-review.sh") -Raw

        $idxMarca = $sh.IndexOf('mv -f "$LOG_TMP"')
        $idxMarca | Should -BeGreaterThan -1 -Because "a escrita do marcador tem que ser localizavel"
        $antes = $sh.Substring(0, $idxMarca)

        $antes | Should -Match '\-z "\$FINDINGS"'  -Because "resposta vazia nao pode liberar commit"
        $antes | Should -Match 'finish_reason'      -Because "resposta cortada tambem nao"
        $antes | Should -Match '"\$FINISH" == "length"' -Because "o sinal autoritativo de corte e finish_reason"
    }

    It "<Arq>: finish_reason desconhecido conta como FALHA, nao como sucesso" -ForEach @(
        @{ Arq = 'deepseek-review.ps1' }
        @{ Arq = 'deepseek-review.sh'  }
    ) {
        # Apontado pelo proprio R11 em 2026-08-16: barrar apenas "length" deixa passar
        # finish_reason ausente ou anomalo (content_filter, valor novo da API) -- num gate,
        # desconhecido tem que contar como falha. A regra vive por provider, NAO no
        # _resposta.ps1 compartilhado: "stop" e o encerramento normal da DeepSeek, mas a
        # Anthropic devolve "end_turn", entao um "!= stop" generico reprovaria toda resposta
        # do Cross-Claude -- a correcao obvia quebraria a perna vizinha.
        $src = Get-Content (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "scripts") $Arq) -Raw
        $idxMarca = if ($Arq -like '*.ps1') { $src.IndexOf('Move-Item -Path $logTmp') }
                    else                    { $src.IndexOf('mv -f "$LOG_TMP"') }
        $idxMarca | Should -BeGreaterThan -1 -Because "a escrita do marcador tem que ser localizavel"

        $antes = $src.Substring(0, $idxMarca)
        $antes | Should -Match '(-ne|!=)\s*"stop"' -Because "so 'stop' e encerramento normal na DeepSeek"
    }

    It "aborta com codigo nao-zero quando a resposta nao e utilizavel" {
        $src = Get-Content $script:reviewPath -Raw
        $idxCls   = $src.IndexOf('Get-StatusResposta')
        $idxMarca = $src.IndexOf('Move-Item -Path $logTmp')
        $idxCls   | Should -BeGreaterThan -1
        $idxMarca | Should -BeGreaterThan $idxCls

        $trecho = $src.Substring($idxCls, $idxMarca - $idxCls)
        $trecho | Should -Match 'Status -ne\s+["'']ok["'']' -Because "so 'ok' pode seguir pro marcador"
        $trecho | Should -Match '(?m)^\s*exit\s+[1-9]'      -Because "sair 0 sem marcador deixa o hook adivinhar"
    }
}
Describe "output_config.effort so vai para modelo que aceita" {
    # Os testes de COMPORTAMENTO aqui montam o corpo de verdade e olham as chaves, em vez de
    # raspar o fonte com regex -- foi teste-que-le-fonte que deixou o `temperature` vivo um mes
    # no cross-claude.sh, com o teste de paridade verde e a perna 100% quebrada.
    #
    # Duas excecoes deliberadas leem o fonte, e leem METADADO, nao logica: o conteudo do
    # ValidateSet (que nao da para observar montando corpo) e a ausencia de lista de modelo
    # hardcoded nos wrappers. Metadado nao tem como ser exercitado; logica tem, e ai vale a regra.
    #
    # Matriz medida contra POST /v1/messages em 2026-08-19 (max_tokens:16, prompt de uma palavra):
    #   claude-haiku-4-5   sem effort 200 | effort=low   400 "does not support the effort parameter"
    #   claude-sonnet-4-6  sem effort 200 | effort=xhigh 400 "Supported levels: high, low, max, medium"
    #   sonnet-5 / opus-5 / opus-4-7: 200 nos dois casos.

    BeforeAll {
        $script:provDir = Join-Path (Split-Path $PSScriptRoot -Parent) "providers"
        . (Join-Path $script:provDir "_cross-claude-body.ps1")
        $script:caps = Get-EffortCapabilities
    }

    It "a tabela _effort-capabilities.json existe e e JSON valido" {
        # Se ela sumir, os dois wrappers abortam alto de proposito -- este teste garante que o
        # arquivo viaja junto no pacote do plugin, que e onde ele pode se perder.
        $script:caps.sem_effort | Should -Not -BeNullOrEmpty
    }

    It "NAO manda output_config para <Model> (a API devolve 400)" -ForEach @(
        @{ Model = 'claude-haiku-4-5' }
    ) {
        $body = Build-CrossClaudeBody -Model $Model -MaxTokens 16 -Effort 'low' -Caps $script:caps
        $body.ContainsKey('output_config') | Should -Be $false
    }

    It "manda output_config para <Model>, que aceita" -ForEach @(
        @{ Model = 'claude-sonnet-5' }
        @{ Model = 'claude-opus-5'   }
        @{ Model = 'claude-opus-4-7' }
    ) {
        $body = Build-CrossClaudeBody -Model $Model -MaxTokens 16 -Effort 'low' -Caps $script:caps
        $body.output_config.effort | Should -Be 'low'
    }

    It "-Effort none desliga o parametro em qualquer modelo" {
        $body = Build-CrossClaudeBody -Model 'claude-opus-5' -MaxTokens 16 -Effort 'none' -Caps $script:caps
        $body.ContainsKey('output_config') | Should -Be $false
    }

    It "rebaixa nivel que o modelo nao conhece em vez de tomar 400" {
        # claude-sonnet-4-6 aceita effort, mas nao o nivel xhigh -- e o ValidateSet do wrapper
        # oferece xhigh. Latente hoje (o default e low); vira 400 no dia que alguem passar xhigh.
        $body = Build-CrossClaudeBody -Model 'claude-sonnet-4-6' -MaxTokens 16 -Effort 'xhigh' -Caps $script:caps
        $body.output_config.effort | Should -Be 'high'
    }

    It "normaliza o nivel para minusculas antes de mandar" {
        # -Effort "HIGH" passa no ValidateSet (case-insensitive) e passaria no -contains tambem,
        # entao seria enviado como "HIGH". A API recusa: medido 2026-08-19, HTTP 400
        # "Input should be 'low', 'medium', 'high', 'xhigh' or 'max'". O .sh normaliza com tr;
        # este teste impede o .ps1 de divergir no MESMO env var.
        $body = Build-CrossClaudeBody -Model 'claude-opus-5' -MaxTokens 16 -Effort 'HIGH' -Caps $script:caps
        $body.output_config.effort | Should -BeExactly 'high'
    }

    It "NONE em caixa alta desliga igual a none" {
        $body = Build-CrossClaudeBody -Model 'claude-opus-5' -MaxTokens 16 -Effort 'NONE' -Caps $script:caps
        $body.ContainsKey('output_config') | Should -Be $false
    }

    It "o nivel de rebaixamento vem da tabela, nao do codigo" {
        $script:caps.fallback_nivel | Should -Not -BeNullOrEmpty
    }

    It "<Arq> le o nivel de fallback da tabela em vez de fixar no codigo" -ForEach @(
        @{ Arq = '_cross-claude-body.ps1' }
        @{ Arq = 'cross-claude.sh'        }
    ) {
        # "rebaixa para high" escrito nos dois wrappers e mais uma copia da mesma regra: muda
        # num, o outro segue calado. A politica mora na tabela; aqui so se le.
        $src    = Get-Content (Join-Path $script:provDir $Arq) -Raw
        $codigo = ($src -split "`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $codigo | Should -Match 'max_tokens|EFFORT|Effort' -Because "anti-vacuidade: tem que sobrar codigo apos tirar comentario"
        $codigo | Should -Match 'fallback_nivel'           -Because "o nivel preferido e lido da tabela"
        $codigo | Should -Not -Match 'high'                -Because "nivel fixo no codigo e a duplicacao voltando"
    }

    It "o ValidateSet do wrapper aceita 'none' -- sem isso nao ha como desligar" {
        $src = Get-Content (Join-Path $script:provDir "cross-claude.ps1") -Raw
        $src | Should -Match 'ValidateSet\("low","medium","high","xhigh","max","none"\)'
    }

    It "<Arq> nao tem lista de modelo propria: le a tabela compartilhada" -ForEach @(
        @{ Arq = 'cross-claude.ps1' }
        @{ Arq = 'cross-claude.sh'  }
    ) {
        # Anti-drift. Se um dos dois voltar a decidir por conta propria, as duas copias divergem
        # calado -- que e literalmente a historia deste arquivo (#regra-duplicada-ps1-sh).
        $src = Get-Content (Join-Path $script:provDir $Arq) -Raw
        $src | Should -Match '_effort-capabilities\.json' -Because "a fonte da regra e o JSON, nao o wrapper"
        $src | Should -Not -Match 'claude-haiku-4-5"?\s*(\)|\]|,)' -Because "nome de modelo hardcoded aqui e a duplicacao voltando"
    }
}
Describe "teto de ENTRADA por provider (o 413 da Groq nao era tamanho, era taxa)" {
    # Medido 2026-08-19 contra a API viva: HTTP 413 "Payload Too Large" da Groq traz no CORPO
    # `on tokens per minute (TPM): Limit 8000, Requested 10329`. Nao e limite de requisicao, e
    # cota por MINUTO somando entrada + saida entre todas as chamadas. Com -MaxInputTokens 8000
    # e -MaxTokens 2048 de saida, uma chamada cheia pede 10048 contra teto de 8000: impossivel.
    # 39 ocorrencias nos council-log antes disto, todas nesta perna.

    BeforeAll {
        $script:raiz    = Split-Path $PSScriptRoot -Parent
        $script:provDir = Join-Path $script:raiz "providers"
        $script:lim     = Get-Content (Join-Path $script:provDir "_provider-limites.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    It "a tabela declara teto para a perna groq-llama" {
        $script:lim.entrada_max_tokens.'groq-llama' | Should -BeGreaterThan 0
    }

    It "entrada + saida da Groq cabe nos 8000 TPM do tier on_demand" {
        # A aritmetica que o defeito violava. Se alguem subir o teto de entrada sem olhar a
        # saida, este teste reprova ANTES de a perna voltar a cair em producao.
        $entrada = [int]$script:lim.entrada_max_tokens.'groq-llama'
        $wrapper = Get-Content (Join-Path $script:provDir "groq-llama.ps1") -Raw
        $m = [regex]::Match($wrapper, '\$MaxTokens\s*=\s*(\d+)')
        $m.Success | Should -Be $true -Because "o default de saida tem que ser localizavel"
        $saida = [int]$m.Groups[1].Value
        ($entrada + $saida) | Should -BeLessThan 8000
    }

    It "<Arq> le a tabela em vez de fixar o teto no codigo" -ForEach @(
        @{ Arq = 'scripts/council-orchestrator.ps1' }
        @{ Arq = 'scripts/council-orchestrator.sh'  }
    ) {
        $src = Get-Content (Join-Path $script:raiz $Arq) -Raw
        $src | Should -Match '_provider-limites\.json'
    }

    It "<Arq> emite respostas_usaveis (perna muda tem que aparecer no relatorio)" -ForEach @(
        @{ Arq = 'scripts/council-orchestrator.ps1' }
        @{ Arq = 'scripts/council-orchestrator.sh'  }
    ) {
        # Ate 6.43.0 so o .ps1 emitia. No caminho bash o agente lia null e nao tinha como saber
        # que o "conselho de 3" era de 1 -- degradacao que se parece com sucesso.
        $src = Get-Content (Join-Path $script:raiz $Arq) -Raw
        $src | Should -Match 'respostas_usaveis'
        $src | Should -Match 'respostas_degradadas'
    }
}

Describe "prompt nao passa pelo argv do jq nos wrappers bash" {
    # Medido 2026-08-19: com prompt de ~8000 tokens, `jq --arg usr "$USER_PROMPT"` morre com
    # "Argument list too long" (exit 126), stdout sai VAZIO e o orquestrador conta a perna como
    # error SEM mensagem. Falhava so em prompt grande -- quando a terceira voz faz mais falta.
    #
    # O comentario sobre esta MESMA classe ja existia nos arquivos, aplicado ao corpo do curl.
    # Consertaram o curl e deixaram o jq ao lado: por isso o teste varre os tres de uma vez.

    BeforeAll { $script:provDir = Join-Path (Split-Path $PSScriptRoot -Parent) "providers" }

    It "<Arq> usa --rawfile para o prompt, nao --arg" -ForEach @(
        @{ Arq = 'cross-claude.sh' }
        @{ Arq = 'deepseek.sh'     }
        @{ Arq = 'groq-llama.sh'   }
    ) {
        $src    = Get-Content (Join-Path $script:provDir $Arq) -Raw
        $codigo = ($src -split "`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $codigo | Should -Match 'jq -n'                        -Because "anti-vacuidade: o bloco jq tem que sobrar"
        $codigo | Should -Match '--rawfile usr'
        $codigo | Should -Match '--rawfile sys'
        $codigo | Should -Not -Match '--arg usr'
        $codigo | Should -Not -Match '--arg sys'
    }

    It "o jq FINAL do orquestrador tambem usa --rawfile" {
        # A QUARTA reincidencia da classe aconteceu AQUI, nao nos wrappers -- e o guard original
        # so varria os wrappers, entao teria ficado verde. Guard que nao cobre o lugar onde o
        # defeito reincidiu nao e guard, e memoria seletiva.
        #
        # Aqui o estrago e maior que numa perna: se este jq morre, o RESULT inteiro sai vazio e o
        # conselho some com as tres pernas tendo respondido.
        $orq    = Join-Path (Split-Path $script:provDir -Parent) "scripts/council-orchestrator.sh"
        $src    = Get-Content $orq -Raw
        $codigo = ($src -split "`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $codigo | Should -Match 'RESULT=\$\(jq -n'   -Because "anti-vacuidade: o bloco final tem que existir"
        $codigo | Should -Match '--rawfile prompt'
        $codigo | Should -Match '--rawfile sys'
        $codigo | Should -Not -Match '--arg prompt'
        $codigo | Should -Not -Match '--arg sys'
    }

    It "o orquestrador bash nao joga stderr do wrapper dentro do JSON" {
        # `> "$OUT" 2>&1` fazia qualquer aviso do wrapper virar lixo antes do JSON, e a perna
        # era contada como error. Latente ate a 6.42.0 acrescentar um aviso que dispara sempre.
        $src = Get-Content (Join-Path (Split-Path $script:provDir -Parent) "scripts/council-orchestrator.sh") -Raw
        # Strip de comentario e obrigatorio aqui: o proprio conserto deixou o padrao antigo
        # CITADO num comentario, para explicar o que mudou. Sem o strip, o teste reprova o
        # arquivo por FALAR do defeito em vez de por COMETE-LO -- a armadilha que este mesmo
        # arquivo de teste ja registra no bloco de sampling param.
        $codigo = ($src -split "`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $codigo | Should -Match '--prompt-file'    -Because "anti-vacuidade: o dispatch tem que existir"
        $codigo | Should -Not -Match '> "\$OUT" 2>&1'
    }
}
