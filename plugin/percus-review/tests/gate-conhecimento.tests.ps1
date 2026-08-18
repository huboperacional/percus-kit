#requires -Version 5.1
# Prova COMPORTAMENTAL do gate de conhecimento: roda o script de verdade num repo
# temporario e afere o que ele barra. Nao inspeciona o codigo do gate — inspecao de
# codigo foi o que deixou passar o gate cego de 2026-07-29 (via 33 de 105 verbetes).

Describe "percus-gate.sh — higiene de conhecimento" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:gate    = Join-Path $script:kitRoot "v2\gates\percus-gate.sh"
        $script:temps   = New-Object System.Collections.ArrayList

        function Get-BashExe {
            $c = Get-Command bash -ErrorAction SilentlyContinue
            if ($c) { return $c.Source }
            foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe")) {
                if (Test-Path $p) { return $p }
            }
            return $null
        }

        # Cria repo temporario com um conhecimento/x.md montado a partir das linhas dadas.
        function New-KnowledgeRepo {
            param([string[]]$Linhas)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-gate-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path (Join-Path $dir "conhecimento") -Force | Out-Null
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\x.md"), $Linhas, (New-Object System.Text.UTF8Encoding($false)))
            [void]$script:temps.Add($dir)
            return $dir
        }

        function Invoke-Gate {
            param([string]$Repo)
            $bash = Get-BashExe
            Push-Location $Repo
            try {
                $saida = & $bash $script:gate 2>&1 | Out-String
                return [pscustomobject]@{ Exit = $LASTEXITCODE; Saida = $saida.Trim() }
            } finally { Pop-Location }
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "enxerga verbete DEPOIS de fence dentro de blockquote (a causa dos 72 invisiveis)" {
        # O padrao antigo casava '> ```' como fence de verdade; o toggle dessincronizava
        # e tudo dali pra frente sumia da vista. Com fence ESTRITO (coluna 0), '> ```'
        # e so texto e o verbete seguinte continua sendo aferido.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '- [Sem tags](#sem-tags)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a, b`', '', '**Sintoma:** ok.', '',
            '> Modelo pra copiar:', '> ```', '> ## Exemplo {#exemplo}', '> ```', '',
            '## Sem tags {#sem-tags}', '', '**Sintoma:** invisivel pra busca.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "o verbete sem tags vem depois e precisa ser visto. Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'sem linha tags'
    }

    It "enxerga verbete depois de UM fence espurio impar (a dessincronizacao real)" {
        # Um unico '> ```' (blockquote seguido IMEDIATAMENTE de crase tripla, sem texto
        # entre os dois) bastava pro padrao antigo togglar uma vez so e considerar TODO
        # o resto do arquivo como dentro de bloco. Foi assim que 72 dos 105 verbetes
        # sumiram da vista do gate no canon real. (Um '> ``` texto solto' NAO reproduz:
        # o padrao antigo so casa crase tripla logo apos '> ', sem nada no meio.)
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '- [Sem tags](#sem-tags)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '> ```', '',
            '## Sem tags {#sem-tags}', '', '**Sintoma:** precisa ser acusada mesmo vindo depois.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "um fence espurio nao pode apagar o resto do arquivo. Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'sem linha tags'
    }

    It "BARRA arquivo com bloco de codigo aberto e nunca fechado" {
        # Fence nao fechado cega o gate dali pra frente. Em vez de passar calado, acusa.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '```', 'bloco aberto e nunca fechado'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "cegueira silenciosa e pior que falso positivo. Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'nunca fechado'
    }

    It "NAO acusa titulo de exemplo dentro de bloco de codigo" {
        # ^## sozinho enxergaria este exemplo como verbete real e acusaria ancora orfa.
        # Por isso o fence ESTRITO continua no gate — so ele, e so na coluna 0.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            'Exemplo de como escrever um verbete:', '',
            '```markdown', '## Titulo de exemplo {#exemplo-em-bloco}', '`tags: x`', '```'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "exemplo em bloco de codigo nao e verbete. Saida do gate: $($r.Saida)"
    }

    It "aceita tags: SEM crase (18 de ~105 verbetes escrevem assim e sao encontraveis)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', 'tags: a, b', '', '**Sintoma:** ok.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "NAO acusa o bloco-modelo em blockquote (falso positivo de 2026-07-27)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '> Modelo pra copiar:', '> ## <sintoma curto> {#ancora-kebab}', '> `tags:` ...'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "barra ancora que nao esta no indice" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '## Orfa {#orfa}', '', '`tags: c`', '', '**Sintoma:** fora do indice.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'nao esta no indice'
    }

    It "NAO acusa verbete cujo tags: vem depois de linhas de citacao" {
        # Blockquote nao pode consumir a janela de 4 linhas do tags: -- senao o gate
        # bloqueia commit legitimo, e gate que bloqueia demais ensina a desliga-lo.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '> Nota 1', '> Nota 2', '> Nota 3', '> Nota 4', '',
            '`tags: a, b`', '', '**Sintoma:** ok.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "o verbete TEM tags, so estao depois da citacao. Saida do gate: $($r.Saida)"
    }

    It "acusa ancora fora do padrao kebab (antes escapava dos dois checks)" {
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '## Ruim {#AncoraRuim}', '', '**Sintoma:** sem tags e com ancora fora do padrao.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "ancora fora do padrao ficava invisivel aos dois checks. Saida do gate: $($r.Saida)"
    }

    It "BARRA verbete '## Titulo' SEM ancora -- escapava dos blocos 2 e 3 de uma vez" {
        # Os blocos 2 (orfao do indice) e 3 (sem tags:) ambos chaveiam em '^## .*\{#'.
        # Sem ancora, a linha nao casa NENHUM dos dois: o verbete nao e "orfao", ele
        # simplesmente nao existe pro gate. Medido no canon 2026-08-18: 14 verbetes
        # nesse estado, todos tambem sem tags:, 11 deles ja commitados havia semanas.
        # O mesclador ja recusava isso na CAIXA; o gate nao cobria o MONOLITO -- e era
        # exatamente a assimetria que fazia do caminho proibido o de menor resistencia.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '## Verbete sem ancora nenhuma', '', '`tags: b`', '', '**Sintoma:** invisivel ao indice e ao link.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "'## ' sem ancora nasce inalcancavel por link e ausente do indice. Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'sem ancora'
    }

    It "NAO acusa '## Indice' nem subtitulo '###' (senao todo verbete legitimo barra)" {
        # O cabecalho do indice e os subtitulos de secao sao '##'/'###' legitimos sem
        # ancora. Guarda que barra os dois e guarda que ninguem consegue satisfazer.
        $repo = New-KnowledgeRepo @(
            '# T', '', '## Indice', '', '- [Boa](#boa)', '', '---', '',
            '## Boa {#boa}', '', '`tags: a`', '', '**Sintoma:** ok.', '',
            '### Subsecao do verbete', '', 'texto.'
        )
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "roda limpo no canon de verdade (exit 0) — e enxergando os 105 verbetes" {
        $reais = @(Select-String -Path (Join-Path $script:kitRoot "conhecimento\COMO_RESOLVER.md") -Pattern '^## .*\{#').Count
        $reais | Should -BeGreaterThan 100 -Because "sanity: o arquivo tem ~105 verbetes"
        $r = Invoke-Gate -Repo $script:kitRoot
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }
}

Describe "percus-gate.sh — caixa de entrada de conhecimento" {
    # A caixa (conhecimento/entrada/<area>/<slug>.md, um verbete por arquivo) existe pra que
    # sessoes concorrentes parem de colidir no monolito. Mas entrada fora de gate e entrada
    # que nasce invisivel -- exatamente o que a caixa deveria evitar.
    #
    # A regra NAO e a mesma do monolito: a checagem de "verbete orfao do indice" exige que a
    # ancora apareca como (#ancora) no MESMO arquivo. Num arquivo de um verbete so isso nunca
    # e verdade, entao estender o glob sem pensar reprovaria TODA entrada valida.

    BeforeAll {
        $script:kitRoot2 = (Resolve-Path (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "..")).Path
        $script:gate2    = Join-Path $script:kitRoot2 "v2\gates\percus-gate.sh"
        $script:temps2   = New-Object System.Collections.ArrayList

        function Get-BashExe2 {
            $c = Get-Command bash -ErrorAction SilentlyContinue
            if ($c) { return $c.Source }
            foreach ($p in @("$env:ProgramFiles\Git\bin\bash.exe", "$env:ProgramFiles\Git\usr\bin\bash.exe")) {
                if (Test-Path $p) { return $p }
            }
            return $null
        }

        function New-CaixaRepo {
            param([string]$Slug, [string[]]$Linhas, [string]$Area = "resolver", [switch]$SemMonolito)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-caixa-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            $caixa = Join-Path (Join-Path (Join-Path $dir "conhecimento") "entrada") $Area
            New-Item -ItemType Directory -Path $caixa -Force | Out-Null
            [IO.File]::WriteAllLines((Join-Path $caixa "$Slug.md"), $Linhas, (New-Object System.Text.UTF8Encoding($false)))
            # Repo real SEMPRE tem o monolito; fixture sem ele testava um estado que nao existe
            # e mascarava a checagem "caixa com entrada e destino ausente". -SemMonolito e pra
            # quem quer aferir justamente esse caso.
            if (-not $SemMonolito) {
                [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\COMO_RESOLVER.md"), @(
                    '# Como Resolver', '', '- [Base](#base)', '', '---', '',
                    '## Base {#base}', '', '`tags: base`', '', 'corpo.'
                ), (New-Object System.Text.UTF8Encoding($false)))
                [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\COMO_FAZER.md"), @(
                    '# Como Fazer', '', '- [Base](#base-fazer)', '', '---', '',
                    '## Base {#base-fazer}', '', '`tags: base`', '', 'passos.'
                ), (New-Object System.Text.UTF8Encoding($false)))
            }
            [void]$script:temps2.Add($dir)
            return $dir
        }

        function Invoke-Gate2 {
            param([string]$Repo)
            $bash = Get-BashExe2
            Push-Location $Repo
            try {
                $saida = & $bash $script:gate2 2>&1 | Out-String
                return [pscustomobject]@{ Exit = $LASTEXITCODE; Saida = $saida.Trim() }
            } finally { Pop-Location }
        }
    }

    AfterAll { foreach ($d in $script:temps2) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "entrada VALIDA passa — e NAO e acusada de orfa do indice" {
        # O caso que uma extensao ingenua do glob quebraria.
        $repo = New-CaixaRepo -Slug "verbete-bom" -Linhas @(
            '## Titulo qualquer {#verbete-bom}', '', '`tags: alfa, beta`', '',
            '**Sintoma:** algo.', '', '**Ref:** teste.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit  | Should -Be 0 -Because "entrada valida nao pode barrar commit. Saida: $($r.Saida)"
        $r.Saida | Should -Not -Match 'indice' -Because "arquivo de um verbete so nao tem indice, e nao deve ter"
    }

    It "entrada sem linha tags: barra (nasceria invisivel a busca)" {
        $repo = New-CaixaRepo -Slug "sem-tags" -Linhas @(
            '## Titulo {#sem-tags}', '', '**Sintoma:** sem tags.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit  | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'tags'
    }

    It "entrada com slug divergente do nome do arquivo barra" {
        # O nome do arquivo E o slug: e o que torna o merge deterministico e o split mecanico.
        $repo = New-CaixaRepo -Slug "nome-do-arquivo" -Linhas @(
            '## Titulo {#outro-slug}', '', '`tags: a`', '', '**Sintoma:** divergente.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit  | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'slug|nome do arquivo'
    }

    It "entrada com mais de um verbete barra (a caixa e um-verbete-por-arquivo)" {
        $repo = New-CaixaRepo -Slug "dois-verbetes" -Linhas @(
            '## Um {#dois-verbetes}', '', '`tags: a`', '', 'corpo.', '',
            '## Dois {#outro-aqui}', '', '`tags: b`', '', 'corpo.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
    }

    It "entrada com slug que JA existe no monolito barra no gate, nao so no merge" {
        # Achado do R11 (2026-08-16): sem isto o gate aprova, o commit passa, e o checkpoint
        # quebra depois -- gate que aprova o que o passo seguinte recusa ensina a ignorar gate.
        $repo = New-CaixaRepo -Slug "ja-existe-la" -Linhas @(
            '## Titulo {#ja-existe-la}', '', '`tags: a`', '', '**Sintoma:** duplicata.'
        )
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\COMO_RESOLVER.md"), @(
            '# Como Resolver', '', '- [Ja existe](#ja-existe-la)', '', '---', '',
            '## Ja existe {#ja-existe-la}', '', '`tags: a`', '', 'corpo.'
        ), (New-Object System.Text.UTF8Encoding($false)))

        $r = Invoke-Gate2 -Repo $repo
        $r.Exit  | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'existe|duplicad'
    }

    It "entrada com texto DEPOIS da ancora barra (o mesclador exige ancora no fim da linha)" {
        # Achado do R11 (2026-08-16): o awk do gate casava '## Titulo {#slug} sobra' porque nao
        # ancorava no fim da linha, e o mesclador recusa. Gate aprovando o que o passo seguinte
        # recusa e a MESMA classe que esta versao diz ter eliminado pra fence e blockquote.
        $repo = New-CaixaRepo -Slug "com-sobra" -Linhas @(
            '## Titulo {#com-sobra} sobra depois da ancora', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
    }

    It "entrada com TAB depois do ## passa (o mesclador aceita, o gate tem de aceitar)" {
        $repo = New-CaixaRepo -Slug "com-tab" -Linhas @(
            "##`tTitulo {#com-tab}", '', '`tags: a`', '', '**Sintoma:** x.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 0 -Because "divergencia na direcao contraria e igualmente ruim. Saida: $($r.Saida)"
    }

    It "slug que so aparece dentro de fence no monolito nao conta como duplicata (espelha o mesclador)" {
        $repo = New-CaixaRepo -Slug "so-no-exemplo" -Linhas @(
            '## Titulo {#so-no-exemplo}', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\COMO_RESOLVER.md"), @(
            '# Como Resolver', '', '- [Outro](#outro)', '', '---', '',
            '## Outro {#outro}', '', '`tags: a`', '', 'Formato:', '',
            '```markdown', '## Exemplo {#so-no-exemplo}', '```'
        ), (New-Object System.Text.UTF8Encoding($false)))

        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 0 -Because "citacao em bloco de codigo nao e verbete. Saida: $($r.Saida)"
    }

    It "area desconhecida em entrada/ barra (o mesclador so processa resolver e fazer)" {
        # Gate que aprova entrada que o mesclador IGNORA PARA SEMPRE e o cenario exato que o
        # bloco 3c existe pra impedir: conhecimento escrito e invisivel.
        $repo = New-CaixaRepo -Slug "verbete-perdido" -Area "outra-area" -Linhas @(
            '## Titulo {#verbete-perdido}', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit  | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'area'
    }

    It "titulo VAZIO ('## {#slug}') barra (o mesclador exige titulo, o gate aceitava)" {
        $repo = New-CaixaRepo -Slug "titulo-vazio" -Linhas @(
            '## {#titulo-vazio}', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 1 -Because "sem titulo nao da pra montar a linha de indice. Saida: $($r.Saida)"
    }

    It "duplicata e detectada mesmo com caixa diferente (o mesclador ja rejeita)" {
        # Ancora que difere so em maiuscula/minuscula colide na renderizacao. Alinhado na
        # direcao SEGURA: os dois recusam, em vez de os dois aceitarem.
        $repo = New-CaixaRepo -Slug "slug-repetido" -Linhas @(
            '## Titulo {#slug-repetido}', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\COMO_RESOLVER.md"), @(
            '# Como Resolver', '', '- [Outro](#Slug-Repetido)', '', '---', '',
            '## Outro {#Slug-Repetido}', '', '`tags: a`', '', 'corpo.'
        ), (New-Object System.Text.UTF8Encoding($false)))

        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
    }

    It "arquivo em SUBPASTA de area valida barra (o mesclador nunca o processaria)" {
        # O glob */*.md do gate e o Get-ChildItem nao-recursivo do mesclador ignoram os dois
        # em silencio: escrito e invisivel PARA SEMPRE, que e o que o bloco 3c existe pra barrar.
        $repo = New-CaixaRepo -Slug "normal" -Linhas @(
            '## Normal {#normal}', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        $sub = Join-Path $repo "conhecimento\entrada\resolver\subpasta"
        New-Item -ItemType Directory -Path $sub -Force | Out-Null
        [IO.File]::WriteAllLines((Join-Path $sub "escondido.md"), @(
            '## Escondido {#escondido}', '', '`tags: a`', '', '**Sintoma:** x.'
        ), (New-Object System.Text.UTF8Encoding($false)))

        $r = Invoke-Gate2 -Repo $repo
        $r.Exit  | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'subpasta|escondido|profundidade'
    }

    It "arquivo solto em entrada/ barra, mas o LEIA-ME nao" {
        $repo = New-CaixaRepo -Slug "normal2" -Linhas @(
            '## Normal {#normal2}', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        $ent = Join-Path $repo "conhecimento\entrada"
        [IO.File]::WriteAllLines((Join-Path $ent "LEIA-ME.md"), @('# Caixa', '', 'documentacao.'), (New-Object System.Text.UTF8Encoding($false)))
        $r1 = Invoke-Gate2 -Repo $repo
        $r1.Exit | Should -Be 0 -Because "LEIA-ME e documentacao da caixa. Saida: $($r1.Saida)"

        [IO.File]::WriteAllLines((Join-Path $ent "solto.md"), @(
            '## Solto {#solto}', '', '`tags: a`', '', '**Sintoma:** x.'
        ), (New-Object System.Text.UTF8Encoding($false)))
        $r2 = Invoke-Gate2 -Repo $repo
        $r2.Exit | Should -Be 1 -Because "verbete fora de area nunca seria mesclado. Saida: $($r2.Saida)"
    }

    It "mencao inline a '{#slug}' no monolito nao e duplicata (espelha o mesclador)" {
        $repo = New-CaixaRepo -Slug "citado-em-prosa" -Linhas @(
            '## Titulo {#citado-em-prosa}', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\COMO_RESOLVER.md"), @(
            '# Como Resolver', '', '- [Outro](#outro)', '', '---', '',
            '## Outro {#outro}', '', '`tags: a`', '',
            'A ancora e escrita como {#citado-em-prosa} na linha do titulo.'
        ), (New-Object System.Text.UTF8Encoding($false)))

        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 0 -Because "citacao em prosa nao e ancora. Saida: $($r.Saida)"
    }

    It "titulo que comeca com chave ('## {chave} ... {#slug}') e aceito, como no mesclador" {
        # O mesclador aceita (o '.+?' casa qualquer coisa antes da ancora final). O gate exigia
        # que o primeiro caractere nao fosse '{' -- divergencia na direcao contraria.
        $repo = New-CaixaRepo -Slug "titulo-com-chave" -Linhas @(
            '## {chave} no comeco do titulo {#titulo-com-chave}', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida: $($r.Saida)"
    }

    It "linha '##' pelada barra (o mesclador tambem recusa)" {
        $repo = New-CaixaRepo -Slug "hash-pelado" -Linhas @(
            '## Titulo {#hash-pelado}', '', '`tags: a`', '', '##', '', '**Sintoma:** x.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
    }

    It "caixa com entrada e monolito de destino AUSENTE barra (o mesclador falha nesse caso)" {
        # Gate aprovando o que o mesclador recusa, agora com o destino inexistente.
        $repo = New-CaixaRepo -Slug "sem-destino" -SemMonolito -Linhas @(
            '## Titulo {#sem-destino}', '', '`tags: a`', '', '**Sintoma:** x.'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit  | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'destino|COMO_RESOLVER'
    }

    It "entrada gravada COM BOM passa (o mesclador aceita; o awk nao enxergava o '##')" {
        # Editor do Windows grava .md com BOM sem avisar. O ReadAllText(UTF8) do mesclador
        # descarta o BOM sozinho e aceita; o awk do gate via "\xEF\xBB\xBF## Titulo", nao
        # casava '^##' e rejeitava com "achei 0 titulos". Divergencia gate<->mesclador de novo,
        # agora por BOM -- que e o tema que ja mordeu tres vezes nesta mesma sessao.
        $repo = New-CaixaRepo -Slug "com-bom" -Linhas @('placeholder')
        $alvo = Join-Path $repo "conhecimento\entrada\resolver\com-bom.md"
        [IO.File]::WriteAllText($alvo, (@(
            '## Titulo {#com-bom}', '', '`tags: a`', '', '**Sintoma:** x.'
        ) -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($true)))

        $b = [IO.File]::ReadAllBytes($alvo)
        ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) | Should -BeTrue -Because "o fixture tem de ter BOM de verdade"

        $r = Invoke-Gate2 -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida: $($r.Saida)"
    }

    It "entrada com bloco de codigo aberto barra (cega o gate dali pra frente)" {
        $repo = New-CaixaRepo -Slug "fence-aberto" -Linhas @(
            '## Titulo {#fence-aberto}', '', '`tags: a`', '', '```bash', 'echo oi'
        )
        $r = Invoke-Gate2 -Repo $repo
        $r.Exit  | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'fechado|aberto'
    }
}
