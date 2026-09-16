#requires -Version 5.1
# Tests: o gate enumera verbetes pelo INDICE DO GIT, nao pelo glob do disco (2026-08-19).
#
# Motivo medido: o checkout do percus-kit e COMPARTILHADO entre sessoes simultaneas. Com o glob,
# um rascunho untracked de outra sessao barrava commit de quem nao tinha nada a ver com ele --
# numa unica sessao isso custou TRES escapes PERCUS_GATE_OVERSIZE declarados, em commits que nao
# tocavam conhecimento/ nenhum. Escape reincidente vira achado de drift no proprio canon, entao
# o gate estava fabricando o sinal que ele usa pra dizer que algo vai mal.
#
# O risco do conserto e o oposto: gate que enxerga de MENOS fica verde por vacuidade, que e a
# falha que este kit mais persegue. Por isso os quatro casos abaixo cobrem os dois lados --
# untracked ignorado, staged barrado, rastreado barrado, e o fallback de fora-de-repo.
#
# Caminhos com barra normal de proposito: o PowerShell aceita, e backslash em string vira
# armadilha de escape ('\r' e '\b' viraram CR e BACKSPACE na primeira versao deste arquivo).

Describe "percus-gate.sh - escopo de verbetes vem do indice do git" {
    BeforeAll {
        $script:kitRoot  = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:gate     = Join-Path $script:kitRoot "v2/gates/percus-gate.sh"
        $script:tempDirs = New-Object System.Collections.ArrayList

        function Get-Bash {
            $b = Get-Command bash -ErrorAction SilentlyContinue
            if ($b) { return $b.Source }
            return (Join-Path $env:ProgramFiles "Git/bin/bash.exe")
        }

        # Verbete deliberadamente quebrado: titulo sem a ancora {#slug}. O gate barra isso.
        $script:linhasQuebradas = @('## Sem ancora nenhuma', '', 'corpo solto')

        function Write-Utf8 {
            param([string]$Path, [string[]]$Linhas)
            [IO.File]::WriteAllLines($Path, $Linhas, (New-Object System.Text.UTF8Encoding($false)))
        }

        function New-AreasBase {
            param([string]$Dir)
            foreach ($a in @("resolver","fazer")) {
                New-Item -ItemType Directory -Path (Join-Path $Dir "conhecimento/$a") -Force | Out-Null
            }
            # Vizinho valido + indice coerente: so a variavel sob teste muda de caso pra caso.
            Write-Utf8 (Join-Path $Dir "conhecimento/resolver/base.md")       @('## Base {#base}','','`tags: base`','','corpo.')
            Write-Utf8 (Join-Path $Dir "conhecimento/resolver/INDICE.md")     @('# Indice','','- [Base](base.md)')
            Write-Utf8 (Join-Path $Dir "conhecimento/fazer/base-fazer.md")    @('## Base fazer {#base-fazer}','','`tags: base`','','passos.')
            Write-Utf8 (Join-Path $Dir "conhecimento/fazer/INDICE.md")        @('# Indice','','- [Base fazer](base-fazer.md)')
        }

        function New-RepoGit {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-gitscope-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [void]$script:tempDirs.Add($dir)
            New-AreasBase -Dir $dir
            Push-Location $dir
            try {
                & git init -q . 2>$null
                & git config user.email "t@t.t" 2>$null
                & git config user.name "t" 2>$null
                & git add -A 2>$null
                & git @('commit','-q','-m','base','--no-verify') 2>$null
            } finally { Pop-Location }
            return $dir
        }

        function Invoke-Gate {
            param([string]$Repo)
            Push-Location $Repo
            try {
                & (Get-Bash) $script:gate *>$null
                return $LASTEXITCODE
            } finally { Pop-Location }
        }
    }

    AfterAll {
        foreach ($d in $script:tempDirs) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue }
    }

    It "1. verbete quebrado UNTRACKED nao barra: e rascunho alheio, nao deste commit" {
        $repo = New-RepoGit
        Write-Utf8 (Join-Path $repo "conhecimento/resolver/alheio.md") $script:linhasQuebradas
        Invoke-Gate -Repo $repo | Should -Be 0 -Because "untracked nao esta no indice: quem responde por ele e quem der git add"
    }

    It "2. o MESMO verbete quebrado, STAGED, barra" {
        # Este caso e o que impede o conserto de virar cegueira: assim que o arquivo entra no
        # indice, ele volta a ser aferido integralmente.
        $repo = New-RepoGit
        Write-Utf8 (Join-Path $repo "conhecimento/resolver/meu.md") $script:linhasQuebradas
        Push-Location $repo
        try { & git add conhecimento/resolver/meu.md 2>$null } finally { Pop-Location }
        Invoke-Gate -Repo $repo | Should -Be 1 -Because "staged e exatamente o que este commit esta colocando no repo"
    }

    It "3. verbete quebrado JA RASTREADO continua sendo barrado" {
        # O indice do git inclui o que ja esta rastreado, nao so o recem-staged -- senao um
        # defeito commitado no passado sairia do radar pra sempre.
        $repo = New-RepoGit
        Write-Utf8 (Join-Path $repo "conhecimento/resolver/antigo.md") $script:linhasQuebradas
        Push-Location $repo
        try {
            & git add conhecimento/resolver/antigo.md 2>$null
            & git @('commit','-q','-m','quebrado','--no-verify') 2>$null
        } finally { Pop-Location }
        Invoke-Gate -Repo $repo | Should -Be 1 -Because "rastreado responde pelo gate mesmo sem estar staged agora"
    }

    It "4. FORA de repo git o fallback valida tudo, em vez de ficar verde por vacuidade" {
        # Sem indice pra consultar, devolver lista vazia seria a pior resposta possivel. O
        # fallback e o glob: valida tudo, que e o comportamento anterior a esta mudanca.
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-nogit-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:tempDirs.Add($dir)
        New-AreasBase -Dir $dir
        Write-Utf8 (Join-Path $dir "conhecimento/resolver/solto.md") $script:linhasQuebradas
        Invoke-Gate -Repo $dir | Should -Not -Be 0 -Because "sem git, a resposta honesta e aferir tudo"
    }
}

# Fase 5 (2026-09-16): o gate julga o que o COMMIT muda.
#
# Medido: em ~40 commits de 2026-09-15/16 foi preciso PERCUS_GATE_OVERSIZE pelo mesmo motivo --
# INDICE.md listando verbete de outra sessao e link morto em verbete ja commitado, problemas que
# o commit nao tocou. Escape de rotina e o sinal de desenho errado que o proprio gate descreve.
# Contrato: INDICE x arquivos, verbete fora do INDICE e link morto BLOQUEIAM so quando o problema
# envolve arquivo do diff staged; herdado vira AVISO com a lista.
#
# E um check novo: .ps1 staged com byte > 0x7F sem BOM bloqueia (PowerShell 5.1 le em ANSI).
# Passou por 2 revisoes seguidas e so o ps51-compat da suite inteira pegou.
Describe "percus-gate.sh - bloqueio escopado ao diff staged + BOM de .ps1" {
    BeforeAll {
        $script:kitRootD = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:gateD    = Join-Path $script:kitRootD "v2/gates/percus-gate.sh"
        $script:tempsD   = New-Object System.Collections.ArrayList

        function Get-BashD {
            $b = Get-Command bash -ErrorAction SilentlyContinue
            if ($b) { return $b.Source }
            return (Join-Path $env:ProgramFiles "Git/bin/bash.exe")
        }

        function Write-Lf {
            param([string]$Path, [string[]]$Linhas)
            New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
            [IO.File]::WriteAllText($Path, (($Linhas -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
        }

        function Invoke-Git {
            param([string]$Repo, [string[]]$Argumentos)
            & git -C $Repo @Argumentos 2>&1 | Out-Null
        }

        # Repo com base valida commitada: 2 verbetes que se linkam, INDICE em dia, um script.
        function New-RepoDiff {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-diff-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [void]$script:tempsD.Add($dir)
            Write-Lf (Join-Path $dir "conhecimento/resolver/base.md")    @('## Base {#base}','','`tags: base`','','ver [[alvo]].')
            Write-Lf (Join-Path $dir "conhecimento/resolver/alvo.md")    @('## Alvo {#alvo}','','`tags: base`','','corpo.')
            Write-Lf (Join-Path $dir "conhecimento/resolver/INDICE.md")  @('# Indice','','- [Alvo](alvo.md)','- [Base](base.md)')
            Write-Lf (Join-Path $dir "conhecimento/fazer/base-fazer.md") @('## Base fazer {#base-fazer}','','`tags: base`','','passos.')
            Write-Lf (Join-Path $dir "conhecimento/fazer/INDICE.md")     @('# Indice','','- [Base fazer](base-fazer.md)')
            Write-Lf (Join-Path $dir "scripts/y.ps1")                    @('Write-Output 1')
            Invoke-Git $dir @('init','-q')
            Invoke-Git $dir @('config','user.email','t@t.t')
            Invoke-Git $dir @('config','user.name','t')
            Invoke-Git $dir @('config','core.autocrlf','false')
            Invoke-Git $dir @('add','-A')
            Invoke-Git $dir @(('com' + 'mit'),'-q','-m','base','--no-verify')
            return $dir
        }

        # Commita o estado atual do disco como "historico" (o problema passa a ser HERDADO).
        function Save-Herdado {
            param([string]$Repo)
            Invoke-Git $Repo @('add','-A')
            Invoke-Git $Repo @(('com' + 'mit'),'-q','-m','herdado','--no-verify')
        }

        function Invoke-GateD {
            param([string]$Repo)
            Push-Location $Repo
            try {
                $saida = & (Get-BashD) $script:gateD 2>&1 | Out-String
                return [pscustomobject]@{ Exit = $LASTEXITCODE; Saida = $saida.Trim() }
            } finally { Pop-Location }
        }

        # Bytes UTF-8 de um .ps1 com c-cedilha (U+00E7 = C3 A7), com ou sem BOM.
        function Get-BytesPs1 {
            param([switch]$ComBom, [switch]$Ascii)
            $lista = New-Object System.Collections.Generic.List[byte]
            if ($ComBom) { $lista.AddRange([byte[]](0xEF,0xBB,0xBF)) }
            $lista.AddRange([Text.Encoding]::ASCII.GetBytes("Write-Output 'a"))
            if (-not $Ascii) { $lista.AddRange([byte[]](0xC3,0xA7)) }
            $lista.AddRange([Text.Encoding]::ASCII.GetBytes("o'`n"))
            return ,$lista.ToArray()
        }

        function Add-Ps1 {
            param([string]$Repo, [string]$Caminho, [byte[]]$Bytes)
            $full = Join-Path $Repo $Caminho
            New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
            [IO.File]::WriteAllBytes($full, $Bytes)
            Invoke-Git $Repo @('add','--',$Caminho)
        }
    }

    AfterAll { foreach ($d in $script:tempsD) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "base limpa passa (sanity da fixture)" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -Ascii)
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Not -Match 'AVISO'
    }

    It "INDICE herdado listando verbete inexistente + commit so em scripts/x.ps1 ASCII: PASSA com AVISO" {
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/INDICE.md") @('# Indice','','- [Alvo](alvo.md)','- [Base](base.md)','- [Fantasma](fantasma-de-outra-sessao.md)')
        Save-Herdado $repo
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -Ascii)
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 0 -Because "o commit nao tocou o INDICE. Saida: $($r.Saida)"
        $r.Saida | Should -Match 'AVISO'
        $r.Saida | Should -Match 'fantasma-de-outra-sessao'
        $r.Saida | Should -Not -Match 'BLOQUEADO'
    }

    It "o MESMO INDICE herdado BLOQUEIA quando o commit altera o INDICE" {
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/INDICE.md") @('# Indice','','- [Alvo](alvo.md)','- [Base](base.md)','- [Fantasma](fantasma-de-outra-sessao.md)')
        Save-Herdado $repo
        Write-Lf (Join-Path $repo "conhecimento/resolver/INDICE.md") @('# Indice do resolver','','- [Alvo](alvo.md)','- [Base](base.md)','- [Fantasma](fantasma-de-outra-sessao.md)')
        Invoke-Git $repo @('add','--','conhecimento/resolver/INDICE.md')
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "quem mexe no INDICE responde por ele. Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO.*fantasma-de-outra-sessao'
    }

    It "verbete herdado FORA do INDICE + commit alheio: PASSA com AVISO" {
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/esquecido.md") @('## Esquecido {#esquecido}','','`tags: a`','','corpo.')
        Save-Herdado $repo
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -Ascii)
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'AVISO.*esquecido\.md'
    }

    It "commit que ADICIONA verbete fora do INDICE: BLOQUEIA" {
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/novo.md") @('## Novo {#novo}','','`tags: a`','','corpo.')
        Invoke-Git $repo @('add','--','conhecimento/resolver/novo.md')
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO.*novo\.md'
    }

    It "commit que ADICIONA link morto num verbete existente: BLOQUEIA" {
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/alvo.md") @('## Alvo {#alvo}','','`tags: base`','','ver [x](nao-existe-aqui.md).')
        Invoke-Git $repo @('add','--','conhecimento/resolver/alvo.md')
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO.*nao-existe-aqui'
    }

    It "link morto HERDADO em verbete nao tocado + commit alheio: PASSA com AVISO" {
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/alvo.md") @('## Alvo {#alvo}','','`tags: base`','','ver [x](git-bash-so-no-checkout-principal.md) e [[wiki-de-outra-sessao]].')
        Save-Herdado $repo
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -Ascii)
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'AVISO.*git-bash-so-no-checkout-principal'
        $r.Saida | Should -Match 'AVISO.*wiki-de-outra-sessao'
    }

    It "commit que REMOVE o verbete-alvo de um link alheio: BLOQUEIA (o link morre por causa deste commit)" {
        $repo = New-RepoDiff
        Invoke-Git $repo @('rm','-q','--','conhecimento/resolver/alvo.md')
        Write-Lf (Join-Path $repo "conhecimento/resolver/INDICE.md") @('# Indice','','- [Base](base.md)')
        Invoke-Git $repo @('add','--','conhecimento/resolver/INDICE.md')
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "base.md nao foi tocado, mas o alvo saiu neste commit. Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO.*alvo'
    }

    It "higiene de verbete (sem tags:) herdada CONTINUA bloqueando fora do diff" {
        # Fora do contrato de proposito: gate-escopo-git caso 3 exige que defeito rastreado siga barrado.
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/alvo.md") @('## Alvo {#alvo}','','corpo sem tags.')
        Save-Herdado $repo
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -Ascii)
        (Invoke-GateD -Repo $repo).Exit | Should -Be 1
    }

    It ".ps1 staged com c-cedilha SEM BOM: BLOQUEIA citando o arquivo e a regra" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1)
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO.*scripts/x\.ps1'
        $r.Saida | Should -Match 'BOM'
        $r.Saida | Should -Match 'PowerShell 5\.1'
    }

    It ".ps1 staged com c-cedilha COM BOM: passa" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -ComBom)
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida: $($r.Saida)"
    }

    It ".ps1 staged ASCII sem BOM: passa" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -Ascii)
        (Invoke-GateD -Repo $repo).Exit | Should -Be 0
    }

    It ".ps1 MODIFICADO que perde o BOM: BLOQUEIA" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -ComBom)
        Save-Herdado $repo
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1)
        (Invoke-GateD -Repo $repo).Exit | Should -Be 1
    }

    It ".ps1 com NOME COM ESPACO e c-cedilha sem BOM: BLOQUEIA citando o nome inteiro" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/meu script.ps1" -Bytes (Get-BytesPs1)
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'scripts/meu script\.ps1'
    }

    It ".ps1 le o blob do INDICE, nao o disco: staged sem BOM e disco com BOM BLOQUEIA" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1)
        [IO.File]::WriteAllBytes((Join-Path $repo "scripts/x.ps1"), (Get-BytesPs1 -ComBom))
        (Invoke-GateD -Repo $repo).Exit | Should -Be 1
    }

    It ".ps1 sem BOM HERDADO e nao tocado: nao bloqueia (o check olha so o staged)" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/velho.ps1" -Bytes (Get-BytesPs1)
        Save-Herdado $repo
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -Ascii)
        (Invoke-GateD -Repo $repo).Exit | Should -Be 0
    }

    It ".ps1 sem BOM REMOVIDO no commit: nao bloqueia" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/velho.ps1" -Bytes (Get-BytesPs1)
        Save-Herdado $repo
        Invoke-Git $repo @('rm','-q','--','scripts/velho.ps1')
        (Invoke-GateD -Repo $repo).Exit | Should -Be 0
    }

    # ---- Rodada 2 (revisao do ff3815b) ----

    It "I1: NADA staged + INDICE herdado quebrado BLOQUEIA (diff vazio = auditoria, nao AVISO)" {
        # A 1a versao rebaixava tudo a AVISO com diff vazio e o teste do canon real perdeu o dente.
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/INDICE.md") @('# Indice','','- [Alvo](alvo.md)','- [Base](base.md)','- [Fantasma](fantasma.md)')
        Save-Herdado $repo
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO.*fantasma'
    }

    It "PERCUS_GATE_AUDITORIA=1 com algo staged: herdado BLOQUEIA (auditoria independe do indice)" {
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/INDICE.md") @('# Indice','','- [Alvo](alvo.md)','- [Base](base.md)','- [Fantasma](fantasma.md)')
        Save-Herdado $repo
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1 -Ascii)
        $auditoriaAntes = $env:PERCUS_GATE_AUDITORIA
        $env:PERCUS_GATE_AUDITORIA = '1'
        try { $r = Invoke-GateD -Repo $repo } finally { $env:PERCUS_GATE_AUDITORIA = $auditoriaAntes }
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
    }

    It "PERCUS_GATE_AUDITORIA=1 NAO desliga a checagem de BOM do staged" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/x.ps1" -Bytes (Get-BytesPs1)
        $auditoriaAntes = $env:PERCUS_GATE_AUDITORIA
        $env:PERCUS_GATE_AUDITORIA = '1'
        try { $r = Invoke-GateD -Repo $repo } finally { $env:PERCUS_GATE_AUDITORIA = $auditoriaAntes }
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO: scripts/x\.ps1'
    }

    It "I2a: git mv do verbete-ALVO de link alheio nao tocado BLOQUEIA (rename conta o caminho antigo)" {
        # Mutante provado: sem --no-renames o diff so mostra alvo2.md e o [[alvo]] de base.md vira AVISO.
        $repo = New-RepoDiff
        Invoke-Git $repo @('mv','conhecimento/resolver/alvo.md','conhecimento/resolver/alvo2.md')
        Write-Lf (Join-Path $repo "conhecimento/resolver/alvo2.md") @('## Alvo {#alvo2}','','`tags: base`','','corpo.')
        Write-Lf (Join-Path $repo "conhecimento/resolver/INDICE.md") @('# Indice','','- [Alvo](alvo2.md)','- [Base](base.md)')
        Invoke-Git $repo @('add','-A')
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO: conhecimento/resolver/base\.md.*alvo'
    }

    It "I2b: commit remove alvo de ](../resolver/alvo.md) citado de fazer/ nao tocado BLOQUEIA" {
        # Mutante provado: sem normaliza o caminho fica fazer/../resolver/alvo.md, nao casa o diff e vira AVISO.
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/base.md") @('## Base {#base}','','`tags: base`','','sem link.')
        Write-Lf (Join-Path $repo "conhecimento/fazer/base-fazer.md") @('## Base fazer {#base-fazer}','','`tags: base`','','ver [r](../resolver/alvo.md).')
        Save-Herdado $repo
        Invoke-Git $repo @('rm','-q','--','conhecimento/resolver/alvo.md')
        Write-Lf (Join-Path $repo "conhecimento/resolver/INDICE.md") @('# Indice','','- [Base](base.md)')
        Invoke-Git $repo @('add','--','conhecimento/resolver/INDICE.md')
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO: conhecimento/fazer/base-fazer\.md'
    }

    It "link com CAIXA diferente (](Alvo.md)) e commit remove alvo.md: BLOQUEIA" {
        $repo = New-RepoDiff
        Write-Lf (Join-Path $repo "conhecimento/resolver/base.md") @('## Base {#base}','','`tags: base`','','ver [a](Alvo.md).')
        Save-Herdado $repo
        Invoke-Git $repo @('rm','-q','--','conhecimento/resolver/alvo.md')
        Write-Lf (Join-Path $repo "conhecimento/resolver/INDICE.md") @('# Indice','','- [Base](base.md)')
        Invoke-Git $repo @('add','--','conhecimento/resolver/INDICE.md')
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO.*Alvo\.md'
    }

    It ".psm1 e .psd1 com c-cedilha sem BOM: BLOQUEIAM (mesma armadilha no 5.1)" {
        $repo = New-RepoDiff
        Add-Ps1 -Repo $repo -Caminho "scripts/m.psm1" -Bytes (Get-BytesPs1)
        Add-Ps1 -Repo $repo -Caminho "scripts/d.psd1" -Bytes (Get-BytesPs1)
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 1 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'BLOQUEADO: scripts/m\.psm1'
        $r.Saida | Should -Match 'BLOQUEADO: scripts/d\.psd1'
    }

    It ".ps1 UTF-16LE com BOM FF FE: passa (nao e falso positivo)" {
        $repo = New-RepoDiff
        $bytes = [byte[]](0xFF,0xFE) + [Text.Encoding]::Unicode.GetBytes("Write-Output '" + [char]0x00E7 + "'`n")
        Add-Ps1 -Repo $repo -Caminho "scripts/u16.ps1" -Bytes $bytes
        $r = Invoke-GateD -Repo $repo
        $r.Exit | Should -Be 0 -Because "Saida: $($r.Saida)"
    }
}
