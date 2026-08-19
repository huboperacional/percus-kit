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
