#requires -Version 5.1
# Tests: a validade da review passou a ser CONTEUDO (hash do diff), nao TEMPO (2026-08-19).
#
# Por que a janela de 5 min media a coisa errada, medido nesta maquina:
#   - consertar um finding e rodar a suite (184 s) estourava a janela e forcava re-review do
#     MESMO diff -- ~90 s e ~$0,01 gastos revisando o que ja tinha sido revisado;
#   - e no sentido inverso ela era permissiva: dentro dos 5 min dava pra editar tudo e commitar
#     com o aval de uma review que nunca viu aquele codigo.
# Tempo nao e proxy de "isto foi revisado". Hash e.
#
# O marcador por hash NAO substitui o latest.jsonl: ele vem ANTES, e o caminho antigo
# (latest.jsonl + 5 min) continua como fallback porque o plugin instalado fica versoes atras em
# dezenas de projetos. Estes testes cobrem os dois caminhos e a precedencia entre eles.

Describe "pre-commit-check.ps1 — validade por hash do diff" {
    BeforeAll {
        $script:hookPs1  = Join-Path $PSScriptRoot ".." "hooks" "pre-commit-check.ps1"
        $script:tempDirs = New-Object System.Collections.ArrayList

        # O hash tem de sair do ARQUIVO escrito por `git diff --output=`, nunca da saida
        # capturada pelo shell: o PowerShell decodifica a saida do processo com o encoding do
        # console, e um diff com acento produzia hash diferente do bash pro MESMO diff
        # (24b54443f4ed vs b5a3110dfee7, medido 2026-08-19). O teste replica a rota do arquivo
        # de proposito -- se alguem "simplificar" o hook pra capturar a saida, este helper
        # deixa de casar e o teste cai.
        function Get-DiffHash {
            param([string]$RepoDir)
            $tmp = [IO.Path]::GetTempFileName()
            try {
                Push-Location $RepoDir
                try { & git diff HEAD --output=$tmp 2>$null | Out-Null } finally { Pop-Location }
                $sha = [System.Security.Cryptography.SHA256]::Create()
                $fs = [IO.File]::OpenRead($tmp)
                try { return ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-','').ToLower().Substring(0,12) }
                finally { $fs.Dispose() }
            } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }

        # Repo com 1 commit e uma alteracao pendente, pra `git diff HEAD` nao ser vazio.
        # O arquivo e .ps1 e NAO .txt de proposito: a politica de risco (6.41.0) dispensa
        # review de diff so-texto, entao uma fixture .txt sairia com exit 0 antes de chegar na
        # logica de hash -- e os testes passariam/falhariam por um motivo que nao e o que eles
        # afirmam medir. Achado quando as duas mudancas se encontraram na suite.
        function New-RepoComDiff {
            param([double]$IdadeLatestMin = 60, [switch]$SemMarcadorHash)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("percus-hash-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [void]$script:tempDirs.Add($dir)
            Push-Location $dir
            try {
                & git init -q . 2>$null
                & git config user.email "t@t.t" 2>$null
                & git config user.name "t" 2>$null
                Set-Content -Path (Join-Path $dir "a.ps1") -Value "original" -Encoding utf8
                & git add a.ps1 2>$null
                & git commit -q -m "base" --no-verify 2>$null
                # alteracao pendente: acento de proposito, que e o que expunha a divergencia
                # de encoding entre os runtimes
                Set-Content -Path (Join-Path $dir "a.ps1") -Value "alterado com acentuacao" -Encoding utf8
            } finally { Pop-Location }

            $rev = Join-Path $dir ".deepseek\reviews"
            New-Item -ItemType Directory -Path $rev -Force | Out-Null
            $latest = Join-Path $rev "latest.jsonl"
            [IO.File]::WriteAllText($latest, '{"findings":"Sem findings criticos."}', (New-Object System.Text.UTF8Encoding($false)))
            (Get-Item $latest).LastWriteTime = (Get-Date).AddMinutes(-$IdadeLatestMin)

            if (-not $SemMarcadorHash) {
                $h = Get-DiffHash -RepoDir $dir
                $alvo = Join-Path $rev "d-$h.jsonl"
                Copy-Item -Path $latest -Destination $alvo -Force
                (Get-Item $alvo).LastWriteTime = (Get-Date)
            }
            return $dir
        }

        function Invoke-Hook {
            param([string]$RepoDir)
            # 'commit' quebrado em duas partes pra este arquivo de teste nao disparar o proprio
            # hook de pre-commit quando alguem o grepa ou o abre num comando.
            $cmd = 'cd "' + $RepoDir + '" && git com' + 'mit -m x'
            $payload = @{ tool_name = "Bash"; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            # Mesma forma do irmao pre-commit-path-resolution.tests.ps1: pipe direto pro pwsh.
            # A primeira versao deste helper usava `cmd /c "type ... | ..."` e nao PARSEAVA no
            # PS 5.1 -- pego pelo ps51-compat.tests.ps1, nao por leitura.
            $payload | & pwsh -NoProfile -File $script:hookPs1 *>$null
            return $LASTEXITCODE
        }
    }

    AfterAll {
        foreach ($d in $script:tempDirs) {
            Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
        }
    }

    It "1. marcador do hash LIBERA mesmo com latest.jsonl muito alem dos 5 min" {
        # Este e o caso que a janela de tempo tratava errado: nada mudou no codigo desde a
        # review, mas o relogio andou (suite de 184 s, conserto de finding, bump de versao).
        $repo = New-RepoComDiff -IdadeLatestMin 60
        Invoke-Hook -RepoDir $repo | Should -Be 0 -Because "o diff revisado e exatamente o diff atual; o relogio e irrelevante"
    }

    It "2. sem marcador do hash, cai no caminho antigo e BLOQUEIA pelo tempo" {
        $repo = New-RepoComDiff -IdadeLatestMin 60 -SemMarcadorHash
        Invoke-Hook -RepoDir $repo | Should -Be 2 -Because "sem prova de que ESTE diff foi revisado, a regra de 5 min volta a valer"
    }

    It "3. diff MUDA depois da review -> hash nao casa mais -> BLOQUEIA" {
        # O lado permissivo da janela de tempo: antes, editar dentro dos 5 min passava batido.
        # latest.jsonl envelhecido de proposito: com ele fresco, o FALLBACK de 5 min liberaria e
        # mascararia o resultado do hash -- o teste passaria sem provar nada sobre o mecanismo
        # que ele diz testar.
        $repo = New-RepoComDiff -IdadeLatestMin 60
        Set-Content -Path (Join-Path $repo "a.ps1") -Value "editado DEPOIS da review" -Encoding utf8
        Invoke-Hook -RepoDir $repo | Should -Be 2 -Because "codigo alterado depois da review nao esta revisado, mesmo dentro da janela"
    }

    It '4. git add NAO invalida a review' {
        # Por isso o hash e de `git diff HEAD` e nao de `git diff --cached`: o fluxo natural e
        # editar -> revisar -> stage -> commitar. Hash do staged mudaria no `git add` e mandaria
        # revisar de novo o mesmo conteudo -- o retrabalho que este mecanismo veio matar.
        $repo = New-RepoComDiff -IdadeLatestMin 60
        Push-Location $repo
        try { & git add a.ps1 2>$null } finally { Pop-Location }
        Invoke-Hook -RepoDir $repo | Should -Be 0 -Because "stage nao muda o conteudo, so onde ele esta"
    }

    It "5. marcador de hash vencido (>24h) nao vale" {
        # As 24 h nao sao "frescor" -- o hash ja garante o conteudo. Sao o teto que impede o
        # diretorio de crescer sem fim, que foi o incidente de 2026-07-20 (hook pendurado
        # ~148 s enumerando milhares de marcadores).
        $repo = New-RepoComDiff -IdadeLatestMin 60
        Get-ChildItem (Join-Path $repo ".deepseek\reviews") -Filter "d-*.jsonl" | ForEach-Object {
            $_.LastWriteTime = (Get-Date).AddHours(-25)
        }
        Invoke-Hook -RepoDir $repo | Should -Be 2 -Because "marcador vencido cai no fallback, que bloqueia pelo tempo"
    }
}
