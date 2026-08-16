#requires -Version 5.1
# Prova o mesclador da caixa de entrada de conhecimento.
#
# Por que a caixa existe: COMO_RESOLVER.md tem 335 verbetes num arquivo so, e toda sessao de
# todo projeto escreve nele. O git resolve conflito em ARQUIVO, entao duas sessoes escrevendo
# licoes sobre assuntos diferentes colidem assim mesmo -- medido 2026-08-16: um commit levaria
# o rascunho inacabado de outra sessao junto, e o gate barrou.
#
# Com a caixa, cada sessao escreve conhecimento/entrada/<area>/<slug>.md -- arquivos diferentes,
# colisao zero. O merge para o monolito vira ato UNICO, no checkpoint.
#
# A regra que sustenta o desenho: se o monolito ja esta modificado na arvore (outra sessao
# mexendo), o mesclador NAO mescla -- ele adia, e as entradas ficam na caixa. Isso so e aceitavel
# porque a caixa e duravel: adiar nao custa nada. Sem a caixa, adiar significava perder o verbete
# ou travar o commit.
#
# Testes rodam sobre fixture em pasta temporaria, NUNCA sobre o COMO_RESOLVER.md real.

Describe "mesclar-conhecimento.ps1" {

    BeforeAll {
        $script:mesclador = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "scripts\mesclar-conhecimento.ps1"

        # Fixture: repo git de mentira com monolito minimo + caixa vazia.
        function script:New-Fixture {
            $raiz = Join-Path ([IO.Path]::GetTempPath()) ("cknh-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path (Join-Path $raiz "conhecimento\entrada\resolver") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $raiz "conhecimento\entrada\fazer")    -Force | Out-Null

            # CRLF de proposito: o arquivo real e CRLF, e um mesclador que normaliza para LF
            # produziria um diff de 12 mil linhas no primeiro merge.
            $mono = @(
                "# Como Resolver"
                ""
                "- [Verbete existente](#verbete-existente)"
                ""
                "---"
                ""
                "## Verbete existente {#verbete-existente}"
                ""
                '`tags: exemplo, ja-existia`'
                ""
                "Corpo do verbete que ja existia."
            ) -join "`r`n"
            [IO.File]::WriteAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md"), $mono + "`r`n")

            $fazer = @(
                "# Como Fazer"
                ""
                "- [Proc existente](#proc-existente)"
                ""
                "---"
                ""
                "## Proc existente {#proc-existente}"
                ""
                '`tags: exemplo`'
                ""
                "Passos."
            ) -join "`r`n"
            [IO.File]::WriteAllText((Join-Path $raiz "conhecimento\COMO_FAZER.md"), $fazer + "`r`n")

            Push-Location $raiz
            try {
                & git init --quiet 2>&1 | Out-Null
                & git -c user.email=t@t -c user.name=t add -A 2>&1 | Out-Null
                & git -c user.email=t@t -c user.name=t commit -q -m base 2>&1 | Out-Null
            } finally { Pop-Location }
            return $raiz
        }

        function script:New-Entrada {
            param([string]$Raiz, [string]$Slug, [string]$Area = "resolver", [string]$Titulo = "Titulo novo", [switch]$SemTags, [string]$SlugInterno)
            $ancora = if ($SlugInterno) { $SlugInterno } else { $Slug }
            $linhas = @("## $Titulo {#$ancora}", "")
            if (-not $SemTags) { $linhas += @('`tags: alfa, beta`', "") }
            $linhas += @("**Sintoma:** algo aconteceu.", "", "**Ref:** teste.")
            $p = Join-Path $Raiz "conhecimento\entrada\$Area\$Slug.md"
            [IO.File]::WriteAllText($p, ($linhas -join "`r`n") + "`r`n")
            return $p
        }

        # Roda como PROCESSO FILHO de proposito. Chamar o .ps1 no mesmo processo nao captura
        # nada: Write-Host vai pro host e [Console]::Error escreve direto no stderr do
        # processo -- nenhum dos dois passa pelo `2>&1` do PowerShell. A primeira versao
        # deste helper chamava in-process e as assercoes de mensagem viam string vazia,
        # entao o teste "provava" silencio em vez de provar a mensagem. De quebra, processo
        # filho e como o checkpoint realmente invoca, e da $LASTEXITCODE de verdade.
        $script:exePs = if ($PSVersionTable.PSEdition -eq 'Core') { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'powershell.exe' }

        function script:Invoke-Mesclador { param([string]$Raiz)
            $saida = & $script:exePs -NoProfile -ExecutionPolicy Bypass -File $script:mesclador -Raiz $Raiz 2>&1 | Out-String
            return [pscustomobject]@{ Saida = $saida; Codigo = $LASTEXITCODE }
        }
    }

    It "mescla entrada valida: verbete no monolito, linha no indice, arquivo sai da caixa" {
        $raiz = script:New-Fixture
        try {
            $entrada = script:New-Entrada -Raiz $raiz -Slug "meu-verbete-novo"
            $r = script:Invoke-Mesclador -Raiz $raiz

            $r.Codigo | Should -Be 0
            $mono = [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md"))

            $mono | Should -Match '## Titulo novo \{#meu-verbete-novo\}' -Because "o verbete tem que entrar no monolito"
            $mono | Should -Match '\(#meu-verbete-novo\)'                -Because "sem linha de indice o gate acusa verbete orfao"
            Test-Path $entrada | Should -BeFalse -Because "entrada mesclada sai da caixa, senao mescla de novo no proximo checkpoint"

            # O que ja existia continua la, intacto.
            $mono | Should -Match '## Verbete existente \{#verbete-existente\}'
            $mono | Should -Match 'Corpo do verbete que ja existia'
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "preserva CRLF do monolito (normalizar produziria diff de 12 mil linhas)" {
        $raiz = script:New-Fixture
        try {
            $null = script:New-Entrada -Raiz $raiz -Slug "verbete-crlf"
            $null = script:Invoke-Mesclador -Raiz $raiz
            $txt = [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md"))
            $lf   = ([regex]::Matches($txt, "(?<!`r)`n")).Count
            $lf | Should -Be 0 -Because "todo `n do arquivo tem que vir precedido de `r"
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "ADIA quando o monolito ja esta modificado na arvore (outra sessao mexendo)" {
        $raiz = script:New-Fixture
        try {
            $mono = Join-Path $raiz "conhecimento\COMO_RESOLVER.md"
            [IO.File]::AppendAllText($mono, "`r`nedicao de outra sessao`r`n")
            $antes = [IO.File]::ReadAllText($mono)

            $entrada = script:New-Entrada -Raiz $raiz -Slug "nao-deve-mesclar-agora"
            $r = script:Invoke-Mesclador -Raiz $raiz

            # Adiar NAO e erro: e o comportamento correto, e a caixa e duravel.
            $r.Codigo | Should -Be 0 -Because "adiar e normal, nao falha"
            $r.Saida  | Should -Match 'adia|ADIA' -Because "o operador tem que saber que adiou, senao parece que mesclou"
            Test-Path $entrada | Should -BeTrue -Because "a entrada fica na caixa pro proximo checkpoint"
            [IO.File]::ReadAllText($mono) | Should -BeExactly $antes -Because "nao pode tocar em arquivo que outra sessao esta editando"
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "recusa entrada cujo slug interno diverge do nome do arquivo" {
        $raiz = script:New-Fixture
        try {
            $entrada = script:New-Entrada -Raiz $raiz -Slug "nome-do-arquivo" -SlugInterno "outro-slug-qualquer"
            $r = script:Invoke-Mesclador -Raiz $raiz

            $r.Codigo | Should -Not -Be 0 -Because "divergencia tem que falhar alto"
            $r.Saida  | Should -Match 'slug'
            Test-Path $entrada | Should -BeTrue -Because "entrada invalida fica na caixa; descartar perderia o verbete"
            [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md")) |
                Should -Not -Match 'outro-slug-qualquer'
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "recusa entrada sem linha tags: (a busca de conhecimento nao acharia)" {
        $raiz = script:New-Fixture
        try {
            $entrada = script:New-Entrada -Raiz $raiz -Slug "sem-tags-aqui" -SemTags
            $r = script:Invoke-Mesclador -Raiz $raiz

            $r.Codigo | Should -Not -Be 0
            $r.Saida  | Should -Match 'tags'
            Test-Path $entrada | Should -BeTrue
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "recusa slug que ja existe no monolito (duplicata silenciosa quebra os links)" {
        $raiz = script:New-Fixture
        try {
            $entrada = script:New-Entrada -Raiz $raiz -Slug "verbete-existente"
            $r = script:Invoke-Mesclador -Raiz $raiz

            $r.Codigo | Should -Not -Be 0
            $r.Saida  | Should -Match 'existe|duplicad'
            Test-Path $entrada | Should -BeTrue
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "entrada boa mescla mesmo quando outra na mesma leva e invalida" {
        # Uma entrada podre nao pode reter as saudaveis: o proximo checkpoint mesclaria tudo
        # junto e o operador perderia a rastreabilidade de qual sessao escreveu o que.
        $raiz = script:New-Fixture
        try {
            $boa  = script:New-Entrada -Raiz $raiz -Slug "entrada-boa"
            $ruim = script:New-Entrada -Raiz $raiz -Slug "entrada-ruim" -SemTags
            $r = script:Invoke-Mesclador -Raiz $raiz

            $r.Codigo | Should -Not -Be 0 -Because "a invalida ainda tem que ser denunciada"
            Test-Path $boa  | Should -BeFalse -Because "a valida mescla"
            Test-Path $ruim | Should -BeTrue  -Because "a invalida fica"
            [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md")) |
                Should -Match '\{#entrada-boa\}'
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "aceita verbete com '## X {#y}' DENTRO de bloco de codigo (o gate ja ignora fence)" {
        # Achado do R11 (2026-08-16): o gate 3c pula fence ao contar titulos e ao procurar
        # tags:. Se o mesclador nao pular, um verbete com exemplo de markdown passa no gate e
        # e recusado no merge -- gate e mesclador discordando sobre o que e valido e pior que
        # os dois errarem juntos, porque o commit passa e o checkpoint quebra depois.
        $raiz = script:New-Fixture
        try {
            $p = Join-Path $raiz "conhecimento\entrada\resolver\com-fence.md"
            [IO.File]::WriteAllText($p, (@(
                '## Titulo real {#com-fence}'
                ''
                '`tags: alfa`'
                ''
                'Exemplo de como escrever um verbete:'
                ''
                '```markdown'
                '## Exemplo que NAO conta {#exemplo-ignorado}'
                '`tags: nao-conta`'
                '```'
                ''
                '**Ref:** teste.'
            ) -join "`r`n") + "`r`n")

            $r = script:Invoke-Mesclador -Raiz $raiz
            $r.Codigo | Should -Be 0 -Because "titulo dentro de fence nao e verbete. Saida: $($r.Saida)"
            $mono = [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md"))
            $mono | Should -Match '\{#com-fence\}'
            $mono | Should -Not -Match '\(#exemplo-ignorado\)' -Because "o exemplo nao pode virar linha de indice"
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "aceita blockquote antes do tags: (a citacao nao pode consumir a janela de 4 linhas)" {
        # O awk do gate pula '^[[:space:]]*>' SEM incrementar o contador, e o comentario dele
        # diz por que: sem isso o gate acusava "sem tags:" um verbete que TEM tags, barrando
        # commit legitimo. O mesclador tem de contar do mesmo jeito.
        $raiz = script:New-Fixture
        try {
            $p = Join-Path $raiz "conhecimento\entrada\resolver\com-citacao.md"
            [IO.File]::WriteAllText($p, (@(
                '## Titulo {#com-citacao}'
                ''
                '> nota de contexto'
                '> segunda linha da nota'
                '> terceira linha da nota'
                '> quarta linha da nota'
                ''
                '`tags: alfa, beta`'
                ''
                '**Ref:** teste.'
            ) -join "`r`n") + "`r`n")

            $r = script:Invoke-Mesclador -Raiz $raiz
            $r.Codigo | Should -Be 0 -Because "o verbete TEM tags, so estao depois da citacao. Saida: $($r.Saida)"
            [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md")) | Should -Match '\{#com-citacao\}'
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "se a gravacao do monolito falhar, a entrada CONTINUA na caixa" {
        # A durabilidade da caixa e a premissa que sustenta o desenho inteiro (e o que torna
        # 'adiar' de graca). Remover a entrada antes de gravar o destino troca uma colisao
        # de git por PERDA de verbete -- o unico desfecho pior que o problema original.
        $raiz = script:New-Fixture
        try {
            $entrada = script:New-Entrada -Raiz $raiz -Slug "sobrevive-a-falha"
            $mono = Join-Path $raiz "conhecimento\COMO_RESOLVER.md"
            Set-ItemProperty -Path $mono -Name IsReadOnly -Value $true

            $r = script:Invoke-Mesclador -Raiz $raiz

            Set-ItemProperty -Path $mono -Name IsReadOnly -Value $false
            $r.Codigo | Should -Not -Be 0 -Because "falha de gravacao tem de ser denunciada"
            Test-Path $entrada | Should -BeTrue -Because "verbete perdido e o pior desfecho possivel aqui"
        } finally {
            $m = Join-Path $raiz "conhecimento\COMO_RESOLVER.md"
            if (Test-Path $m) { Set-ItemProperty -Path $m -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue }
            Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "nao toca no monolito quando NADA foi mesclado (so entradas invalidas)" {
        $raiz = script:New-Fixture
        try {
            $null = script:New-Entrada -Raiz $raiz -Slug "so-invalida" -SemTags
            $mono = Join-Path $raiz "conhecimento\COMO_RESOLVER.md"
            $antesTexto = [IO.File]::ReadAllText($mono)
            $antesMtime = (Get-Item $mono).LastWriteTimeUtc

            Start-Sleep -Milliseconds 20
            $r = script:Invoke-Mesclador -Raiz $raiz

            $r.Codigo | Should -Not -Be 0
            [IO.File]::ReadAllText($mono) | Should -BeExactly $antesTexto
            (Get-Item $mono).LastWriteTimeUtc | Should -Be $antesMtime -Because "reescrever sem mesclar nada so gera ruido e risco"
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "monolito que TERMINA no bloco de indice nao e corrompido" {
        # Achado do R11 (2026-08-16): a fatia $linhas[($fim+1)..($Count-1)] vira Count..Count-1
        # quando o indice e a ultima linha -- e no PowerShell range decrescente conta PRA TRAS,
        # devolvendo @($null, ultimo) e duplicando linha. Hoje o monolito real sempre tem corpo
        # depois do indice, entao o bug e silencioso ate o dia em que nao tiver.
        $raiz = script:New-Fixture
        try {
            $mono = Join-Path $raiz "conhecimento\COMO_RESOLVER.md"
            # SEM quebra de linha final de proposito: com ela, o split gera um elemento vazio
            # no fim e o range degenerado nunca acontece -- a primeira versao deste teste
            # passava sem exercitar o bug, que e o falso-verde que esta sessao inteira persegue.
            [IO.File]::WriteAllText($mono, (@(
                "# Como Resolver"
                ""
                "- [Verbete existente](#verbete-existente)"
            ) -join "`r`n"))
            Push-Location $raiz
            try { & git -c user.email=t@t -c user.name=t commit -q -am "so indice" 2>&1 | Out-Null } finally { Pop-Location }

            $null = script:New-Entrada -Raiz $raiz -Slug "apos-indice-puro"
            $r = script:Invoke-Mesclador -Raiz $raiz

            $r.Codigo | Should -Be 0 -Because "Saida: $($r.Saida)"
            $txt = [IO.File]::ReadAllText($mono)
            $txt | Should -Match '\{#apos-indice-puro\}'
            ([regex]::Matches($txt, '\(#verbete-existente\)')).Count | Should -Be 1 -Because "a linha de indice existente nao pode ser duplicada"
            $txt | Should -Not -Match '(?m)^\s*$\r?\n\s*$\r?\n\s*$' -Because "fatia invertida injeta linha vazia/null"
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "se a entrada nao puder sair da caixa apos o merge, o script denuncia (estado ambiguo)" {
        # Achado do R11: gravado no monolito E ainda na caixa faz o PROXIMO checkpoint falhar
        # por slug duplicado -- e o operador nao tem como saber por que. Falhar alto agora e
        # melhor que falhar confuso depois.
        $raiz = script:New-Fixture
        try {
            $entrada = script:New-Entrada -Raiz $raiz -Slug "presa-na-caixa"
            # Lock exclusivo: no Windows isso impede a remocao do arquivo.
            $fs = [IO.File]::Open($entrada, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            try {
                $r = script:Invoke-Mesclador -Raiz $raiz
                $r.Codigo | Should -Not -Be 0 -Because "estado ambiguo tem de ser denunciado. Saida: $($r.Saida)"
                # Exige a mensagem EXPLICATIVA, nao uma excecao crua: sem ela o operador ve um
                # stack trace e nao sabe que o verbete ja esta no monolito e vai colidir depois.
                $r.Saida  | Should -Match 'ja esta em|proximo checkpoint' -Because "a saida tem de dizer o que fazer. Saida: $($r.Saida)"
            } finally { $fs.Close(); $fs.Dispose() }
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "slug que aparece SO dentro de bloco de codigo no monolito nao conta como duplicata" {
        # Achado do R11: o resto do bloco 3c pula fence de proposito, mas a checagem de
        # duplicata varria o texto cru -- entao um verbete que CITA '{#slug}' como exemplo
        # dentro de ``` bloqueava uma entrada nova legitima com aquele slug.
        $raiz = script:New-Fixture
        try {
            $mono = Join-Path $raiz "conhecimento\COMO_RESOLVER.md"
            $txt = [IO.File]::ReadAllText($mono).TrimEnd() + (@(
                ""
                ""
                "Formato de uma entrada:"
                ""
                '```markdown'
                '## Exemplo {#slug-so-no-exemplo}'
                '```'
            ) -join "`r`n") + "`r`n"
            [IO.File]::WriteAllText($mono, $txt)
            Push-Location $raiz
            try { & git -c user.email=t@t -c user.name=t commit -q -am exemplo 2>&1 | Out-Null } finally { Pop-Location }

            $null = script:New-Entrada -Raiz $raiz -Slug "slug-so-no-exemplo"
            $r = script:Invoke-Mesclador -Raiz $raiz
            $r.Codigo | Should -Be 0 -Because "citacao em bloco de codigo nao e verbete. Saida: $($r.Saida)"
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "recusa '##' sem ancora no corpo (viraria verbete novo e sem tags no monolito)" {
        # Divergencia apontada pelo R11: o gate acusa qualquer '##' sem ancora fechando a linha,
        # e o mesclador ignorava. Alinhado na direcao SEGURA -- e o gate esta certo: verbete do
        # monolito usa '**Negrito:**' pra secao, nunca '##'. Um '##' solto no corpo viraria um
        # verbete novo depois do merge, sem ancora e sem tags, e o gate seguinte barraria tudo.
        $raiz = script:New-Fixture
        try {
            $p = Join-Path $raiz "conhecimento\entrada\resolver\com-subtitulo.md"
            [IO.File]::WriteAllText($p, (@(
                '## Titulo {#com-subtitulo}'
                ''
                '`tags: alfa`'
                ''
                '## Subtitulo sem ancora'
                ''
                '**Ref:** teste.'
            ) -join "`r`n") + "`r`n")

            $r = script:Invoke-Mesclador -Raiz $raiz
            $r.Codigo | Should -Not -Be 0 -Because "Saida: $($r.Saida)"
            Test-Path $p | Should -BeTrue
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "mencao inline a '{#slug}' no corpo do monolito nao conta como duplicata" {
        # Achado do R11 (round 5): a duplicata varria o texto todo fora de fence, entao um
        # verbete que CITA '{#slug}' em prosa -- e o verbete #grep-if-aborta-git-bash faz
        # exatamente isso -- bloquearia uma entrada nova legitima com aquele nome. Ancora e
        # so o que esta na LINHA DE TITULO.
        $raiz = script:New-Fixture
        try {
            $mono = Join-Path $raiz "conhecimento\COMO_RESOLVER.md"
            $txt = [IO.File]::ReadAllText($mono).TrimEnd() + (@(
                ""
                ""
                "A ancora markdown e escrita como {#meu-slug} na linha do titulo."
            ) -join "`r`n") + "`r`n"
            [IO.File]::WriteAllText($mono, $txt)
            Push-Location $raiz
            try { & git -c user.email=t@t -c user.name=t commit -q -am inline 2>&1 | Out-Null } finally { Pop-Location }

            $null = script:New-Entrada -Raiz $raiz -Slug "meu-slug"
            $r = script:Invoke-Mesclador -Raiz $raiz
            $r.Codigo | Should -Be 0 -Because "citacao em prosa nao e ancora. Saida: $($r.Saida)"
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "recusa linha '##' pelada (viraria titulo vazio no monolito)" {
        $raiz = script:New-Fixture
        try {
            $p = Join-Path $raiz "conhecimento\entrada\resolver\hash-pelado.md"
            [IO.File]::WriteAllText($p, (@(
                '## Titulo {#hash-pelado}', '', '`tags: a`', '', '##', '', '**Ref:** teste.'
            ) -join "`r`n") + "`r`n")
            $r = script:Invoke-Mesclador -Raiz $raiz
            $r.Codigo | Should -Not -Be 0 -Because "Saida: $($r.Saida)"
            Test-Path $p | Should -BeTrue
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "nao duplica o separador quando o monolito ja termina em '---'" {
        $raiz = script:New-Fixture
        try {
            $mono = Join-Path $raiz "conhecimento\COMO_RESOLVER.md"
            [IO.File]::WriteAllText($mono, ([IO.File]::ReadAllText($mono).TrimEnd() + "`r`n`r`n---`r`n"))
            Push-Location $raiz
            try { & git -c user.email=t@t -c user.name=t commit -q -am sep 2>&1 | Out-Null } finally { Pop-Location }

            $null = script:New-Entrada -Raiz $raiz -Slug "apos-separador"
            $r = script:Invoke-Mesclador -Raiz $raiz
            $r.Codigo | Should -Be 0 -Because "Saida: $($r.Saida)"
            [IO.File]::ReadAllText($mono) | Should -Not -Match '(?m)^---\s*\r?\n\s*\r?\n---\s*$' -Because "separador duplicado polui o diff"
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "caixa vazia: nao faz nada e nao falha (roda em todo checkpoint)" {
        $raiz = script:New-Fixture
        try {
            $antes = [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md"))
            $r = script:Invoke-Mesclador -Raiz $raiz
            $r.Codigo | Should -Be 0
            [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md")) | Should -BeExactly $antes
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "roteia pela pasta: entrada/fazer vai pro COMO_FAZER.md, nao pro COMO_RESOLVER.md" {
        $raiz = script:New-Fixture
        try {
            $null = script:New-Entrada -Raiz $raiz -Slug "procedimento-novo" -Area "fazer"
            $r = script:Invoke-Mesclador -Raiz $raiz
            $r.Codigo | Should -Be 0
            [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_FAZER.md"))     | Should -Match '\{#procedimento-novo\}'
            [IO.File]::ReadAllText((Join-Path $raiz "conhecimento\COMO_RESOLVER.md")) | Should -Not -Match 'procedimento-novo'
        } finally { Remove-Item $raiz -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
