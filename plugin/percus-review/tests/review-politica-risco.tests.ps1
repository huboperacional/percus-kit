#requires -Version 5.1
# Tests: a review R11 passou a ser exigida por CRITERIO DE RISCO, nao por frequencia (2026-08-19).
#
# Base da decisao, medida: nos logs de conselho, 26 chamadas em modo review geraram achado em 8
# (31%) -- dois tercos nao acham nada. E os dois achados MATERIAIS de uma sessao inteira vieram de
# diffs que mexiam em logica e contrato; nenhum veio de commit trivial. Valor real, distribuicao
# desigual: pagar 60-90 s uniformes por beneficio concentrado e o desperdicio.
#
# A dispensa e LISTA FECHADA de extensoes de texto puro, e nao lista de "extensoes perigosas".
# A diferenca decide o comportamento diante do DESCONHECIDO: com lista fechada, extensao nova
# exige review; com a inversa, extensao nova passa calada. Enforcement por enumeracao ja falhou
# duas vezes neste kit exatamente assim (matcher so-Bash em 2026-07-31, ausencia de Edit/Write em
# 2026-08-18), e as duas vezes o buraco foi "a coisa N+1 nasceu fora da guarda".

Describe "pre-commit-check.ps1 - review exigida por risco do diff" {
    BeforeAll {
        $script:hookPs1  = Join-Path $PSScriptRoot ".." "hooks" "pre-commit-check.ps1"
        $script:tempDirs = New-Object System.Collections.ArrayList

        function New-RepoSemReview {
            param([string[]]$Arquivos)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-risco-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [void]$script:tempDirs.Add($dir)
            $enc = New-Object System.Text.UTF8Encoding($false)
            Push-Location $dir
            try {
                & git init -q . 2>$null
                & git config user.email "t@t.t" 2>$null
                & git config user.name "t" 2>$null
                [IO.File]::WriteAllText((Join-Path $dir "seed.md"), "seed", $enc)
                & git add -A 2>$null
                & git @('commit','-q','-m','base','--no-verify') 2>$null
            } finally { Pop-Location }
            # Alteracoes pendentes E STAGED. O `git add` nao e detalhe da fixture: `git diff HEAD`
            # nao enxerga arquivo untracked, entao arquivo criado e nao staged simplesmente nao
            # esta sendo commitado -- e a politica nao tem o que decidir sobre ele. A primeira
            # versao deste teste esqueceu o add e "falhou" acusando o hook, que estava certo.
            foreach ($a in $Arquivos) {
                $alvo = Join-Path $dir $a
                New-Item -ItemType Directory -Path (Split-Path $alvo -Parent) -Force | Out-Null
                [IO.File]::WriteAllText($alvo, "conteudo alterado", $enc)
            }
            Push-Location $dir
            try { & git add -A 2>$null } finally { Pop-Location }
            # Sem .deepseek/reviews: qualquer exigencia de review resulta em BLOCK. Assim o teste
            # mede a POLITICA, e nao a validade do marcador.
            return $dir
        }

        function Invoke-Hook {
            param([string]$RepoDir)
            $cmd = 'cd "' + $RepoDir + '" && git com' + 'mit -m x'
            $payload = @{ tool_name = "Bash"; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            $payload | & pwsh -NoProfile -File $script:hookPs1 *>$null
            return $LASTEXITCODE
        }
    }

    AfterAll {
        foreach ($d in $script:tempDirs) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue }
    }

    It "1. diff so de texto (.md) NAO exige review" {
        # Caso mais comum do kit: commit de verbete, changelog, README. Nenhum dos achados
        # materiais medidos ate hoje veio de um diff assim.
        $repo = New-RepoSemReview -Arquivos @("doc.md", "conhecimento/resolver/verbete.md")
        Invoke-Hook -RepoDir $repo | Should -Be 0 -Because "texto puro nao carrega logica pra revisar"
    }

    It "2. diff com codigo EXIGE review" {
        $repo = New-RepoSemReview -Arquivos @("script.ps1")
        Invoke-Hook -RepoDir $repo | Should -Be 2 -Because "logica e onde os dois achados materiais apareceram"
    }

    It "3. UM arquivo de codigo no meio de varios .md ja exige review do commit inteiro" {
        # Nao existe commit meio revisado: o gate e por commit, nao por arquivo.
        $repo = New-RepoSemReview -Arquivos @("a.md", "b.md", "c.md", "lib/util.py")
        Invoke-Hook -RepoDir $repo | Should -Be 2 -Because "o commit e a unidade; um arquivo de risco contamina o conjunto"
    }

    It "4. extensao DESCONHECIDA exige review (lista fechada, nao lista de perigosos)" {
        # O teste que fixa a direcao da regra. Com lista de "perigosos", .tf passaria calado --
        # e a proxima tecnologia adotada nasceria fora da guarda, que e como esta classe ja
        # mordeu este kit duas vezes.
        $repo = New-RepoSemReview -Arquivos @("infra/main.tf")
        Invoke-Hook -RepoDir $repo | Should -Be 2 -Because "o desconhecido tem que cair no lado seguro"
    }

    It "5. arquivo sem extensao nenhuma exige review" {
        # Dockerfile, Makefile, hooks do git: sem extensao e frequentemente onde mora o risco.
        $repo = New-RepoSemReview -Arquivos @("Dockerfile")
        Invoke-Hook -RepoDir $repo | Should -Be 2 -Because "ausencia de extensao nao e sinal de inocuidade"
    }
}
