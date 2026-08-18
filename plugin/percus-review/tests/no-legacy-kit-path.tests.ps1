#requires -Version 5.1
# Varredura como GATE, nao como ato de memoria: o pre-mortem do conselho apontou que uma
# referencia escapa e quebra em silencio, so aparecendo quando trava em producao. Historico
# (plans, specs, handoffs, contracts, .archive, changelog) fica de fora por desenho:
# reescrever o registro do passado falsifica o registro.

Describe "nenhum arquivo VIVO referencia o path legado do kit" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path

        # VIVO = o que o git versiona, mais o que ainda vai entrar (untracked nao-ignorado).
        # Definir assim, em vez de varrer o disco com uma lista de pastas-lixo escrita na mao,
        # fecha duas classes: node_modules/.deepseek/__pycache__/.pytest_cache pintando vermelho
        # numa maquina e verde na outra, e a lista de exclusao apodrecendo calada. De quebra,
        # nao le os 56M de templates\login-ui\node_modules a cada suite.
        function Get-ArquivosVivos {
            $saida = & git -C $script:kitRoot ls-files --cached --others --exclude-standard 2>&1
            if ($LASTEXITCODE -ne 0) { throw "git ls-files falhou em $($script:kitRoot): $saida" }
            @($saida) |
                ForEach-Object { Join-Path $script:kitRoot ("$_" -replace '/', '\') } |
                Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
        }

        # O nome antigo do kit e '_Novo_Projeto'. A lookahead poupa '_Novo_Projeto_V2': e OUTRA
        # pasta (o experimento avulso, que sai no Task 9) e o nome antigo do kit e prefixo dela.
        # Mesma fronteira de token que renomear-kit-local.ps1 aplica pra nao corromper mencao a ela.
        # A busca e CASE-SENSITIVE de proposito: sem isso, 'CHECKLIST_AUTH_NOVO_PROJETO.md' e
        # 'auth_novo_projeto' (receitas de projeto novo, sem relacao com a pasta) pintam vermelho,
        # e o gate passa a empurrar quem le pra "consertar" um link que estava certo.
        $script:legado = '_Novo_Projeto(?!_V2)'

        $script:permitido = @(
            '\\\.archive\\',                     # camada aposentada = registro
            '\\docs\\superpowers\\plans\\',
            '\\docs\\superpowers\\specs\\',
            '\\docs\\handoffs\\',
            '\\docs\\contracts\\',
            '\\CANON_VERSION\.md$',              # changelog = registro
            # Isenta o ARQUIVO, nao a pasta: uma referencia acidental futura em qualquer outro
            # arquivo de conhecimento/ tem que continuar pintando vermelho (R11, 2026-08-16).
            # Verbete = registro de incidente, mesma razao do changelog. Neste verbete o nome
            # antigo e o ASSUNTO: ele existe pra explicar que aquele path morreu. Reescrever
            # apaga a pista que faz o verbete achavel por quem bate no erro. (2026-08-16: esta
            # ausencia deixava a suite vermelha por 6 ocorrencias legitimas.)
            #
            # Desde a 6.38.0 a base e um-arquivo-por-verbete, entao a isencao ficou MAIS estreita
            # do que era: antes cobria o monolito inteiro (398 verbetes), agora cobre exatamente
            # o unico verbete que precisa. Continua isentando o ARQUIVO, nunca a pasta.
            '\\conhecimento\\resolver\\claudemd-caminho-canon-stale\.md$',
            # INDICE.md e GERADO a partir dos titulos: ele herda o nome antigo por derivacao, nao
            # por alguem te-lo escrito ali. A checagem de verdade acontece no verbete de origem.
            '\\conhecimento\\resolver\\INDICE\.md$',
            '\\renomear-kit-local\.ps1$',        # aqui o nome antigo e o ASSUNTO: renomeia DE la
            '\\renomear-kit-local\.tests\.ps1$',
            '\\no-legacy-kit-path\.tests\.ps1$'
        )
    }

    It "nenhum arquivo vivo fora da allowlist cita o nome antigo do kit" {
        $vivos = @(Get-ArquivosVivos)

        # Piso: varredura vazia (cwd errada, git fora do PATH, filtro que nao casa nada) satisfaz
        # o Should -BeNullOrEmpty e deixa o teste verde guardando NADA -- exatamente a classe de
        # falso-verde que os 34 .ps1 sem BOM produziram em 2026-07-30.
        $vivos.Count | Should -BeGreaterThan 150 -Because "o kit tem centenas de arquivos vivos; varredura curta e varredura quebrada, nao kit limpo"

        # Arquivo que o gate nao CONSEGUIU ler (path > 260 chars sem long-path no 5.1, lock de
        # outro processo, ACL) conta como NAO-VERIFICADO, nunca como limpo. Engolir a excecao
        # com -ErrorAction SilentlyContinue tiraria o arquivo de $hits sem uma palavra -- e o
        # teste ficaria verde justamente sobre o arquivo que ele nao olhou.
        $ilegiveis = @()
        $hits      = @()
        foreach ($f in $vivos) {
            if ($script:permitido | Where-Object { $f -match $_ }) { continue }
            $rel = $f.Replace($script:kitRoot + '\', '')
            try {
                if (Select-String -LiteralPath $f -Pattern $script:legado -CaseSensitive -Quiet -ErrorAction Stop) {
                    $hits += $rel
                }
            } catch {
                $ilegiveis += "$rel  --  $($_.Exception.Message)"
            }
        }

        @($ilegiveis) | Should -BeNullOrEmpty -Because "arquivo vivo ilegivel e arquivo nao-verificado; da-lo por limpo e o falso-verde que este teste existe pra impedir:`n$($ilegiveis -join "`n")"

        @($hits) | Should -BeNullOrEmpty -Because "arquivo vivo apontando pro nome antigo quebra em silencio -- troque por 'percus-kit':`n$($hits -join "`n")"
    }

    It "a busca poupa '_Novo_Projeto_V2' e o CAIXA-ALTA, e ainda pega o nome antigo cru" {
        # As duas partes sutis deste arquivo: a lookahead e o -CaseSensitive. Sem esta prova
        # alguem remove uma delas pra "simplificar", e o gate passa a exigir que se corrompa
        # ou a mencao a outra pasta, ou os links de CHECKLIST_AUTH_NOVO_PROJETO.md -- os dois
        # falsos positivos medidos em 2026-07-30.
        '_Novo_Projeto_V2/virou arquivo historico'         | Should -Not -CMatch $script:legado
        'checklists\CHECKLIST_AUTH_NOVO_PROJETO.md'        | Should -Not -CMatch $script:legado
        'inicio - feature_nova - auth_novo_projeto'        | Should -Not -CMatch $script:legado
        'D:\Claud Automations\_Novo_Projeto\v2'            | Should -CMatch $script:legado
        '_Novo_Projeto/comandos/SETUP.md'                  | Should -CMatch $script:legado
    }

    It "os artefatos do rename AINDA citam o nome antigo (allowlist nao virou cemiterio)" {
        # Invariante POSITIVO: renomear-kit-local.ps1 renomeia DE '_Novo_Projeto'. Se alguem
        # "consertar" o nome la dentro achando que e ponteiro morto, o script para de casar a
        # pasta que ele existe pra renomear -- e falha calado, porque nada pra renomear e sucesso.
        foreach ($rel in @('scripts\renomear-kit-local.ps1',
                           'plugin\percus-review\tests\renomear-kit-local.tests.ps1')) {
            $p = Join-Path $script:kitRoot $rel
            Test-Path -LiteralPath $p | Should -BeTrue -Because "$rel esta na allowlist do It acima; se sumiu, a allowlist mente"
            (Get-Content -LiteralPath $p -Raw) | Should -CMatch '_Novo_Projeto' -Because "$rel tem o nome antigo como ASSUNTO, nao como ponteiro"
        }
    }
}
