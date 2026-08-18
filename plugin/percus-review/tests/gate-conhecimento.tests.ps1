#requires -Version 5.1
# Prova COMPORTAMENTAL do gate de conhecimento: roda o script de verdade num repo
# temporario e afere o que ele barra. Nao inspeciona o codigo do gate -- inspecao de
# codigo foi o que deixou passar o gate cego de 2026-07-29 (via 33 de 105 verbetes).
#
# LAYOUT (desde 6.38.0): um verbete por arquivo em conhecimento/{resolver,fazer}/<slug>.md.
# O monolito COMO_RESOLVER.md/COMO_FAZER.md nao existe mais, e a caixa de entrada foi
# aposentada junto -- ela existia PORQUE o destino era um arquivo unico.

Describe "percus-gate.sh — higiene de verbete (um arquivo por verbete)" {
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

        # Repo temporario com conhecimento/<area>/<slug>.md. Sempre planta um verbete
        # VALIDO ao lado: fixture de um arquivo so nao prova que o gate continua olhando
        # os vizinhos depois de achar (ou nao achar) problema no primeiro.
        function New-BaseRepo {
            param(
                [string]$Slug,
                [string[]]$Linhas,
                [string]$Area = "resolver",
                [switch]$ComBom,
                [switch]$SemIndice,
                [hashtable]$Extras
            )
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-kb-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            foreach ($a in @("resolver","fazer")) {
                New-Item -ItemType Directory -Path (Join-Path $dir "conhecimento\$a") -Force | Out-Null
            }
            $enc = New-Object System.Text.UTF8Encoding($ComBom.IsPresent)
            if ($Slug) {
                [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\$Area\$Slug.md"), $Linhas, $enc)
            }
            # vizinho valido, em cada area
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\resolver\base.md"), @(
                '## Base {#base}', '', '`tags: base`', '', 'corpo.'
            ), (New-Object System.Text.UTF8Encoding($false)))
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\fazer\base-fazer.md"), @(
                '## Base fazer {#base-fazer}', '', '`tags: base`', '', 'passos.'
            ), (New-Object System.Text.UTF8Encoding($false)))
            # INDICE.md coerente, montado a partir do que existe. Area real SEMPRE tem um, e o
            # bloco 2d exige sincronia -- fixture sem indice testaria um estado que nao existe.
            if (-not $SemIndice) {
                foreach ($a in @("resolver","fazer")) {
                    $linhasIdx = New-Object System.Collections.ArrayList
                    [void]$linhasIdx.Add('# Indice')
                    [void]$linhasIdx.Add('')
                    $verbetes = @(Get-ChildItem (Join-Path $dir "conhecimento\$a") -Filter *.md |
                                  Where-Object { $_.BaseName -notin @('INDICE','LEIA-ME') } | Sort-Object Name)
                    foreach ($v in $verbetes) {
                        $tit = @(Get-Content $v.FullName | Where-Object { $_ -match '^##[ \t]+.*\{#' })
                        if ($tit.Count -gt 0) {
                            $t = [regex]::Match($tit[0], '^##[ \t]+(?<t>.+?)[ \t]*\{#').Groups['t'].Value
                            [void]$linhasIdx.Add("- [$t]($($v.BaseName).md)")
                        }
                    }
                    [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\$a\INDICE.md"), $linhasIdx, (New-Object System.Text.UTF8Encoding($false)))
                }
            }
            if ($Extras) {
                foreach ($k in $Extras.Keys) {
                    $alvo = Join-Path $dir $k
                    New-Item -ItemType Directory -Path (Split-Path $alvo -Parent) -Force | Out-Null
                    [IO.File]::WriteAllLines($alvo, $Extras[$k], (New-Object System.Text.UTF8Encoding($false)))
                }
            }
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

    It "verbete VALIDO passa" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'ok-mesmo' -Linhas @(
            '## Titulo bom {#ok-mesmo}', '', '`tags: a, b`', '', '**Sintoma:** ok.'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "verbete sem linha tags: barra (nasceria invisivel a busca)" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'sem-tags' -Linhas @(
            '## Sem tags {#sem-tags}', '', '**Sintoma:** invisivel pra busca.'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'sem linha tags'
    }

    It "slug divergente do nome do arquivo barra (o nome do arquivo E o slug)" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'nome-do-arquivo' -Linhas @(
            '## Titulo {#outro-slug}', '', '`tags: a`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'diverge do nome do arquivo'
    }

    It "mais de um verbete no mesmo arquivo barra" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'dois' -Linhas @(
            '## Um {#dois}', '', '`tags: a`', '', 'corpo.', '',
            '## Outro {#outro}', '', '`tags: b`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
    }

    It "texto DEPOIS da ancora barra (a ancora tem de fechar a linha)" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'sobra' -Linhas @(
            '## Titulo {#sobra} sobra aqui', '', '`tags: a`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
    }

    It "TAB depois do ## passa" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'com-tab' -Linhas @(
            "##`tTitulo com tab {#com-tab}", '', '`tags: a`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "titulo VAZIO ('## {#slug}') barra" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'vazio' -Linhas @(
            '## {#vazio}', '', '`tags: a`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
    }

    It "linha '##' pelada barra" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'pelado' -Linhas @(
            '## Titulo {#pelado}', '', '`tags: a`', '', '##', '', 'corpo.'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
    }

    It "'## Titulo' SEM ancora barra -- escapava das checagens de indice e de tags" {
        # Os checks chaveiam em '{#'. Sem ancora a linha nao casa nenhum deles: o verbete
        # nao e "orfao", ele nao existe pro gate. Medido no canon 2026-08-18: 14 verbetes
        # nesse estado, todos tambem sem tags:, 11 commitados havia semanas.
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'sem-ancora' -Linhas @(
            '## Verbete sem ancora nenhuma', '', '`tags: b`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
    }

    It "titulo que comeca com chave ('## {chave} ... {#slug}') e aceito" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'com-chave' -Linhas @(
            '## {chave} no comeco {#com-chave}', '', '`tags: a`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "verbete gravado COM BOM passa (o awk nao enxergava o '##')" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'com-bom' -ComBom -Linhas @(
            '## Titulo com bom {#com-bom}', '', '`tags: a`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "bloco de codigo aberto e nunca fechado barra (cega o gate dali pra frente)" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'fence-aberto' -Linhas @(
            '## Titulo {#fence-aberto}', '', '`tags: a`', '', '```sh', 'echo oi'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'nunca fechado'
    }

    It "titulo de EXEMPLO dentro de fence nao conta como segundo verbete" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'exemplo-em-fence' -Linhas @(
            '## Titulo {#exemplo-em-fence}', '', '`tags: a`', '', 'modelo:', '```md',
            '## Exemplo {#exemplo}', '```', '', 'fim.'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "tags: depois de linhas de citacao nao e acusado de ausente" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'tags-apos-citacao' -Linhas @(
            '## Titulo {#tags-apos-citacao}', '', '> citacao', '> mais citacao', '> ainda',
            '> e mais', '', '`tags: a`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "tags: SEM crase e aceito (parte dos verbetes reais escreve assim)" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'tags-sem-crase' -Linhas @(
            '## Titulo {#tags-sem-crase}', '', 'tags: a, b', '', 'corpo.'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "verbete AUSENTE do INDICE barra (escrever sem regerar deixa o indice mentindo)" {
        # Achado do review R11 (2026-08-18): o gerador ganhou -Verificar e o gate NAO o chamava.
        # Um verbete novo commitado sem regerar passava calado -- reintroduzindo exatamente o
        # defeito que a migracao existe pra matar (indice divergente = verbete invisivel).
        # O teste do gerador nao cobre isso: ele vive na suite do plugin, que projeto-consumidor
        # nao roda por commit. Quem tem de pegar e o gate.
        $repo = New-BaseRepo -Slug 'fora-do-indice' -SemIndice -Linhas @(
            '## Fora do indice {#fora-do-indice}', '', '`tags: a`', '', 'corpo.'
        )
        # indice que existe mas NAO lista o verbete novo
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\resolver\INDICE.md"), @(
            '# Indice', '', '- [Base](base.md)'
        ), (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\fazer\INDICE.md"), @(
            '# Indice', '', '- [Base fazer](base-fazer.md)'
        ), (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'fora-do-indice'
    }

    It "INDICE que aponta pra verbete INEXISTENTE barra" {
        $repo = New-BaseRepo -Slug $null -Linhas @() -SemIndice
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\resolver\INDICE.md"), @(
            '# Indice', '', '- [Base](base.md)', '- [Fantasma](nunca-existiu.md)'
        ), (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\fazer\INDICE.md"), @(
            '# Indice', '', '- [Base fazer](base-fazer.md)'
        ), (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'nunca-existiu'
    }

    It "NEGATIVO: INDICE em dia passa" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug 'no-indice-certo' -Linhas @(
            '## No indice certo {#no-indice-certo}', '', '`tags: a`', '', 'corpo.'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "arquivo VAZIO barra -- ele escapava de TODAS as checagens" {
        # O awk nunca ve um arquivo de zero bytes: sem registros, FNR==1 nunca dispara, o arquivo
        # nunca vira 'atual' e nunca e finalizado. Se ainda estiver listado no INDICE, o bloco 2d
        # tambem nao reclama. Resultado: um "verbete" sem ancora, sem tags e sem conteudo,
        # invisivel a todas as guardas -- a classe exata que esta migracao existe pra matar.
        # Achado do R11 (2026-08-18) e confirmado empiricamente antes do conserto.
        $repo = New-BaseRepo -Slug $null -Linhas @() -SemIndice
        [IO.File]::WriteAllText((Join-Path $repo "conhecimento\resolver\vazio.md"), "")
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\resolver\INDICE.md"), @(
            '# Indice', '', '- [Base](base.md)', '- [Vazio](vazio.md)'
        ), (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllLines((Join-Path $repo "conhecimento\fazer\INDICE.md"), @(
            '# Indice', '', '- [Base fazer](base-fazer.md)'
        ), (New-Object System.Text.UTF8Encoding($false)))
        $r = Invoke-Gate -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'vazio\.md'
    }

    It "verbete SOLTO na raiz de conhecimento/ barra (posicao antes de conteudo)" {
        # O antigo bloco 3c aferia POSICAO antes de conteudo, e a migracao tinha perdido essa
        # metade: o glob dos blocos acima nao e recursivo, o gerador so indexa <area>/*.md, e o
        # guard so barra monolito e indice. Um verbete criado por engano fora do lugar nasce
        # invisivel -- ninguem afere, ninguem indexa, ninguem reclama (R11, 2026-08-18).
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug $null -Linhas @() -Extras @{
            'conhecimento/perdido.md' = @('## Perdido {#perdido}', '', '`tags: a`', '', 'corpo.')
        })
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'perdido\.md'
    }

    It "verbete em SUBPASTA de area valida barra" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug $null -Linhas @() -Extras @{
            'conhecimento/resolver/sub/fundo.md' = @('## Fundo {#fundo}', '', '`tags: a`', '', 'corpo.')
        })
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'profundidade errada'
    }

    It "area DESCONHECIDA em conhecimento/ barra" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug $null -Linhas @() -Extras @{
            'conhecimento/inventada/x.md' = @('## X {#x}', '', '`tags: a`', '', 'corpo.')
        })
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'area desconhecida'
    }

    It "LEIA-ME.md e INDICE.md NAO sao tratados como verbete" {
        $r = Invoke-Gate -Repo (New-BaseRepo -Slug $null -Linhas @() -Extras @{
            'conhecimento\resolver\LEIA-ME.md' = @('# Como Resolver', '', 'documentacao da area.')
            'conhecimento\resolver\INDICE.md'  = @('# Indice', '', '- [Base](base.md)')
        })
        $r.Exit | Should -Be 0 -Because "senao a documentacao da area barra o commit. Saida: $($r.Saida)"
    }
}

Describe "percus-gate.sh — integridade de link entre verbetes" {
    # Risco apontado por 2/2 no pre-mortem do conselho (2026-08-18): link quebra em
    # silencio. Medido no canon no mesmo dia: 16 cross-refs ja apontavam pra slug
    # inexistente. Mas o MESMO pre-mortem avisou que este gate vira falso positivo e
    # acaba desligado -- por isso os testes NEGATIVOS abaixo nascem junto com o positivo.

    BeforeAll {
        $script:temps3 = New-Object System.Collections.ArrayList
        function New-LinkRepo {
            param([string[]]$Linhas)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-lnk-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            foreach ($a in @("resolver","fazer")) {
                New-Item -ItemType Directory -Path (Join-Path $dir "conhecimento\$a") -Force | Out-Null
            }
            $enc = New-Object System.Text.UTF8Encoding($false)
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\resolver\origem.md"), $Linhas, $enc)
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\resolver\destino.md"), @(
                '## Destino {#destino}', '', '`tags: a`', '', 'corpo.'
            ), $enc)
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\resolver\INDICE.md"), @(
                '# Indice', '', '- [Destino](destino.md)', '- [Origem](origem.md)'
            ), $enc)
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\fazer\receita.md"), @(
                '## Receita {#receita}', '', '`tags: a`', '', 'passos.'
            ), $enc)
            [void]$script:temps3.Add($dir)
            return $dir
        }
        function Invoke-Gate3 {
            param([string]$Repo)
            $bash = Get-Command bash -ErrorAction SilentlyContinue
            $exe = if ($bash) { $bash.Source } else { "$env:ProgramFiles\Git\bin\bash.exe" }
            $gate = Join-Path (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path "v2\gates\percus-gate.sh"
            Push-Location $Repo
            try {
                $saida = & $exe $gate 2>&1 | Out-String
                return [pscustomobject]@{ Exit = $LASTEXITCODE; Saida = $saida.Trim() }
            } finally { Pop-Location }
        }
    }

    AfterAll { foreach ($d in $script:temps3) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "POSITIVO: link para verbete que NAO existe barra" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '',
            '**Relacionado:** [morto](nao-existe-mesmo.md)'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'nao-existe-mesmo'
    }

    It "link para verbete que existe passa" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '',
            '**Relacionado:** [destino](destino.md)'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "NEGATIVO: link de exemplo dentro de fence NAO barra" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '', 'exemplo:', '```md',
            '**Relacionado:** [algum](slug-inventado-de-exemplo.md)', '```', '', 'fim.'
        ))
        $r.Exit | Should -Be 0 -Because "a base fala de si mesma o tempo todo. Saida: $($r.Saida)"
    }

    It "NEGATIVO: link em linha de citacao NAO barra" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '',
            '> modelo: **Relacionado:** [algum](outro-inventado.md)'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "NEGATIVO: link para INDICE.md NAO barra" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '', 'ver [indice](INDICE.md).'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "NEGATIVO: link entre areas (../fazer/<slug>.md) NAO barra" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '',
            'procedimento em [receita](../fazer/receita.md).'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "POSITIVO: ](#slug) apontando pra verbete QUE EXISTE barra -- e cross-ref na forma morta" {
        # Era a forma DOMINANTE de cross-ref no monolito (origem e destino no mesmo arquivo).
        # Com um arquivo por verbete a ancora nao resolve mais: 50 links quebraram na fatiagem,
        # e a primeira versao deste bloco era cega a eles -- so olhava ](x.md).
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '', 'ver [destino](#destino)'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'destino\.md'
    }

    It "NEGATIVO: ](#secao) que NAO e verbete passa -- ancora interna e markdown legitimo" {
        # O sentido da checagem e o oposto do intuitivo, e de proposito: '](#causa-raiz)' e a
        # forma canonica de link pra secao do MESMO documento. Barrar toda ancora tornaria o gate
        # um estorvo, e estorvo se desliga -- exatamente o risco que 2/2 do conselho apontaram no
        # pre-mortem. So vira erro quando o alvo e um verbete de verdade.
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '',
            '### Causa raiz', '', 'volte a [causa](#causa-raiz) quando precisar.'
        ))
        $r.Exit | Should -Be 0 -Because "ancora de secao nao pode barrar commit. Saida: $($r.Saida)"
    }

    It "NEGATIVO: AUTO-referencia ](#proprio-slug) NAO barra" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '', 'volta pro [topo](#origem).'
        ))
        $r.Exit | Should -Be 0 -Because "ancora pro proprio verbete e legitima. Saida: $($r.Saida)"
    }

    It "NEGATIVO: ancora de exemplo dentro de fence NAO barra" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '', 'modelo:', '```md',
            'ver [algum](#slug-so-de-exemplo)', '```', '', 'fim.'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "POSITIVO: link WIKI [[slug]] para verbete inexistente barra" {
        # Terceira notacao do monolito. Cada rodada de review descobriu que este bloco era cego
        # a mais uma forma: primeiro ](x.md), depois ](#slug), depois [[slug]]. "Valida link" so
        # vale se enumerar TODAS as notacoes em uso -- cobrir a minoritaria e passar a majoritaria
        # e pior que nada, porque da sensacao de cobertura.
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '', 'ver [[wiki-que-nao-existe]].'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'wiki-que-nao-existe'
    }

    It "link WIKI para verbete que EXISTE passa" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '', 'ver [[destino]].'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "POSITIVO: link ](arquivo.md#secao) valida a parte ANTES do '#'" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '', 'ver [x](sumiu-de-vez.md#uma-secao).'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'sumiu-de-vez'
    }

    It "link ](arquivo.md#secao) com arquivo existente passa" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '', 'ver [x](destino.md#alguma-secao).'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "NEGATIVO: link dentro de CRASE (code span) NAO barra" {
        # Crase inline e a forma do markdown de dizer "isto e literal, nao link" -- nenhum
        # renderizador linkifica ali dentro. Sem esta excecao, um verbete que DOCUMENTA notacao
        # de link e barrado pelos proprios exemplos. Aconteceu de verdade: o verbete que explica
        # este bloco tem uma tabela com as formas que escapavam, e o gate o recusou (2026-08-18).
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '',
            'As formas que escapavam eram `](#slug-de-exemplo)`, `[[wiki-de-exemplo]]` e',
            '`](arquivo-de-exemplo.md#secao)` -- todas citadas aqui como texto.'
        ))
        $r.Exit | Should -Be 0 -Because "a base documenta a si mesma. Saida: $($r.Saida)"
    }

    It "link REAL na mesma linha de um code span continua sendo aferido" {
        # A remocao do code span nao pode cegar o resto da linha: senao bastaria uma crase em
        # qualquer lugar pra desligar a checagem daquela linha inteira.
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '',
            'exemplo `](#nao-conta)` e link de verdade [x](morreu-de-vez.md).'
        ))
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        $r.Saida | Should -Match 'morreu-de-vez'
    }

    It "NEGATIVO: link externo (http) NAO barra" {
        $r = Invoke-Gate3 -Repo (New-LinkRepo @(
            '## Origem {#origem}', '', '`tags: a`', '',
            'ver [doc](https://exemplo.com/pagina.md).'
        ))
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }
}

Describe "percus-gate.sh — referencia orfa ao monolito aposentado" {
    # Terceiro risco de consenso do pre-mortem: referencia esquecida a COMO_RESOLVER.md
    # falha em silencio dias depois, na primeira sessao que tentar ler o arquivo que nao
    # existe mais.

    BeforeAll {
        $script:temps4 = New-Object System.Collections.ArrayList
        function New-RefRepo {
            param([hashtable]$Arquivos)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-ref-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            foreach ($a in @("resolver","fazer")) {
                New-Item -ItemType Directory -Path (Join-Path $dir "conhecimento\$a") -Force | Out-Null
            }
            $enc = New-Object System.Text.UTF8Encoding($false)
            [IO.File]::WriteAllLines((Join-Path $dir "conhecimento\resolver\base.md"), @(
                '## Base {#base}', '', '`tags: a`', '', 'corpo.'
            ), $enc)
            foreach ($k in $Arquivos.Keys) {
                $alvo = Join-Path $dir $k
                New-Item -ItemType Directory -Path (Split-Path $alvo -Parent) -Force | Out-Null
                [IO.File]::WriteAllLines($alvo, $Arquivos[$k], $enc)
            }
            [void]$script:temps4.Add($dir)
            return $dir
        }
        function Invoke-Gate4 {
            param([string]$Repo)
            $bash = Get-Command bash -ErrorAction SilentlyContinue
            $exe = if ($bash) { $bash.Source } else { "$env:ProgramFiles\Git\bin\bash.exe" }
            $gate = Join-Path (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path "v2\gates\percus-gate.sh"
            Push-Location $Repo
            try {
                $saida = & $exe $gate 2>&1 | Out-String
                return [pscustomobject]@{ Exit = $LASTEXITCODE; Saida = $saida.Trim() }
            } finally { Pop-Location }
        }
    }

    AfterAll { foreach ($d in $script:temps4) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "POSITIVO: referencia viva a COMO_RESOLVER.md barra" {
        $r = Invoke-Gate4 -Repo (New-RefRepo @{
            'comandos\ALGUM.md' = @('Consulte `conhecimento/COMO_RESOLVER.md` antes.')
        })
        $r.Exit | Should -Be 1 -Because "Saida do gate: $($r.Saida)"
        # A mensagem NAO cita o nome aposentado de proposito: o padrao do bloco 2c usa
        # alternancia com parenteses justamente pra nao casar a si mesmo, e um literal na
        # mensagem faria o gate se autoacusar. A assercao afere o ARQUIVO denunciado.
        $r.Saida | Should -Match 'comandos/ALGUM\.md'
        $r.Saida | Should -Match 'aposentado'
    }

    It "NEGATIVO: referencia em docs/superpowers/plans/ NAO barra (e historico)" {
        $r = Invoke-Gate4 -Repo (New-RefRepo @{
            'docs\superpowers\plans\2026-01-01-algum.md' = @('Na epoca, `conhecimento/COMO_RESOLVER.md` tinha 900 KB.')
        })
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "NEGATIVO: referencia em .archive/ NAO barra (e historico)" {
        $r = Invoke-Gate4 -Repo (New-RefRepo @{
            '.archive\velho.md' = @('O arquivo `conhecimento/COMO_FAZER.md` ficava aqui.')
        })
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "NEGATIVO: o NOME solto em prosa NAO barra -- so o CAMINHO e instrucao de uso" {
        # A base de conhecimento conta a propria historia o tempo todo ("medido no monolito de
        # 912 KB"). Barrar o nome solto tornaria impossivel escrever a licao sobre esta propria
        # migracao. Medido em 2026-08-18: das 28 ocorrencias no canon, 15 eram narrativa.
        $r = Invoke-Gate4 -Repo (New-RefRepo @{
            'conhecimento/resolver/historia.md' = @(
                '## Historia da migracao {#historia}', '', '`tags: a`', '',
                'O COMO_RESOLVER.md tinha 1 MB antes de virar um arquivo por verbete.'
            )
        })
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }

    It "NEGATIVO: referencia no CANON_VERSION.md NAO barra (changelog cita o passado)" {
        $r = Invoke-Gate4 -Repo (New-RefRepo @{
            'CANON_VERSION.md' = @('# Canon', '', '**Versao:** `9.9.9`', '', 'Migramos `conhecimento/COMO_RESOLVER.md`.')
        })
        $r.Exit | Should -Be 0 -Because "Saida do gate: $($r.Saida)"
    }
}

Describe "percus-gate.sh — higiene do proprio script" {
    It "nenhum comentario DENTRO de programa awk usa aspa simples" {
        # Os programas awk do gate vivem entre aspas SIMPLES no shell. Uma aspa simples num
        # comentario ali dentro FECHA a string: no melhor caso vira erro de sintaxe (aconteceu
        # em 2026-08-18, 53 testes vermelhos de uma vez), e no pior as aspas se equilibram por
        # acaso, o script roda, e o awk recebe um texto diferente do escrito -- sem barulho.
        # bash -n pega o primeiro caso; so uma checagem estatica pega o segundo.
        $gate = Join-Path (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path "v2\gates\percus-gate.sh"
        $dentroDeAwk = $false
        $ruins = @()
        $n = 0
        foreach ($l in (Get-Content $gate)) {
            $n++
            # O bloco fecha numa linha que COMECA com a aspa simples (ex.: "  ' 2>/dev/null)").
            if ($l -match "awk\s+'")                  { $dentroDeAwk = $true;  continue }
            if ($dentroDeAwk -and $l -match "^\s*'")  { $dentroDeAwk = $false; continue }
            if ($dentroDeAwk -and $l -match "^\s*#" -and $l.Contains("'")) {
                $ruins += "linha ${n}: $($l.Trim())"
            }
        }
        @($ruins) | Should -BeNullOrEmpty -Because "aspa simples em comentario de awk fecha a string do shell:`n$($ruins -join "`n")"
    }
}

Describe "percus-gate.sh — nao esconde erro de ferramenta" {
    It "rodar no canon nao produz erro de grep/awk/sed no stderr" {
        # Tres vezes nesta sessao um escape comido (\r, \n) quebrou um comando DENTRO do gate:
        # o grep recebia 'r'/'n' como arquivo, errava, e o erro sumia no 2>/dev/null que existe
        # pra silenciar ruido de permissao. O gate seguia saindo 0 e a guarda afetada
        # simplesmente nao valia. Exit code nao pega isso; so olhar o stderr pega.
        #
        # A assercao e sobre PREFIXO de ferramenta, nao sobre o texto do gate: as violacoes
        # legitimas tambem saem no stderr (com 'BLOQUEADO:'), e nao podem ser confundidas com
        # defeito.
        $kit = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $bash = Get-Command bash -ErrorAction SilentlyContinue
        $exe = if ($bash) { $bash.Source } else { "$env:ProgramFiles\Git\bin\bash.exe" }
        Push-Location $kit
        try {
            $saida = & $exe (Join-Path $kit "v2\gates\percus-gate.sh") 2>&1 | Out-String
        } finally { Pop-Location }

        $erros = @($saida -split "`n" | Where-Object { $_ -match '^\s*(grep|awk|sed|find|xargs|sort|uniq):' })
        @($erros) | Should -BeNullOrEmpty -Because "ferramenta reclamando dentro do gate = guarda que nao esta valendo:`n$($erros -join "`n")"
    }
}

Describe "percus-gate.sh — no canon de verdade" {
    It "roda limpo (exit 0) e enxergando os ~400 verbetes reais" {
        $kit = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $n = @(Get-ChildItem (Join-Path $kit "conhecimento\resolver") -Filter *.md |
               Where-Object { $_.BaseName -notin @('INDICE','LEIA-ME') }).Count
        $n | Should -BeGreaterThan 300 -Because "sanity: a base tem ~400 verbetes"

        $bash = Get-Command bash -ErrorAction SilentlyContinue
        $exe = if ($bash) { $bash.Source } else { "$env:ProgramFiles\Git\bin\bash.exe" }
        Push-Location $kit
        try {
            $saida = & $exe (Join-Path $kit "v2\gates\percus-gate.sh") 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0 -Because "Saida do gate: $($saida.Trim())"
        } finally { Pop-Location }
    }
}
