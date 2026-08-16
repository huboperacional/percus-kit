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
