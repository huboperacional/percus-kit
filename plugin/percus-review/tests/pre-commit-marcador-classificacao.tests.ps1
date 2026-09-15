#requires -Version 5.1
# FR-015..019 / SC-001: o hook passa a LER o marcador e so libera por conteudo de review.
# Antes (2026-09-14) placeholder, arquivo vazio ou lixo em d-<hash>.jsonl liberavam igual a review
# real -- o hook so olhava existencia e mtime. Tres camadas, mesma matriz, mesmo resultado.

BeforeDiscovery {
    $casos = @(
        @{ Caso = 'review';         LiberaHash = $true;  LiberaLatest = $true;  Motivo = '' }
        @{ Caso = 'placeholder';    LiberaHash = $false; LiberaLatest = $true;  Motivo = 'placeholder nao libera por hash' }
        @{ Caso = 'findings-vazio'; LiberaHash = $false; LiberaLatest = $false; Motivo = 'findings vazio' }
        @{ Caso = 'so-espaco';      LiberaHash = $false; LiberaLatest = $false; Motivo = 'findings vazio' }
        @{ Caso = 'nao-string';     LiberaHash = $false; LiberaLatest = $false; Motivo = 'findings nao e string' }
        @{ Caso = 'raiz-array';     LiberaHash = $false; LiberaLatest = $false; Motivo = 'raiz nao e objeto' }
        @{ Caso = 'vazio';          LiberaHash = $false; LiberaLatest = $false; Motivo = 'vazio' }
        @{ Caso = 'nao-json';       LiberaHash = $false; LiberaLatest = $false; Motivo = 'nao e JSON' }
        @{ Caso = 'acima-teto';     LiberaHash = $false; LiberaLatest = $false; Motivo = 'acima do teto (256 KB)' }
        @{ Caso = 'bom';            LiberaHash = $true;  LiberaLatest = $true;  Motivo = '' }
    )
    $script:matriz = @()
    foreach ($cam in @('ps1', 'sh', 'git')) {
        foreach ($c in $casos) {
            foreach ($onde in @('hash', 'latest')) {
                $lib = $c.LiberaLatest; if ($onde -eq 'hash') { $lib = $c.LiberaHash }
                $mot = $c.Motivo; if ($onde -eq 'latest' -and $c.Caso -eq 'placeholder') { $mot = '' }
                $script:matriz += @{ Camada = $cam; Caso = $c.Caso; Onde = $onde; Libera = $lib; Motivo = $mot }
            }
        }
    }
}

Describe "hook pre-commit -- classificacao do marcador nas 3 camadas" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        $plugin = Split-Path $PSScriptRoot -Parent
        $script:hookPs1  = Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.ps1'
        $script:hookSh   = Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.sh'
        $script:template = Join-Path (Join-Path $plugin 'git-hooks') 'pre-commit.template.sh'
        $script:bash = Get-BashGit
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-cls-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        # Hook git instalado = template sem CR (procedimento do verbete de CRLF).
        $script:templateLF = Join-Path $script:tmpBase 'pre-commit'
        Copy-SemCR -Origem $script:template -Destino $script:templateLF
        $script:bloqueio = @{ ps1 = 2; sh = 2; git = 1 }
        $script:u8 = New-Object System.Text.UTF8Encoding($false)

        function Get-DiffHash {
            param([string]$RepoDir)
            $tmp = [IO.Path]::GetTempFileName()
            try {
                Push-Location $RepoDir
                try { & git diff HEAD --output=$tmp 2>$null | Out-Null } finally { Pop-Location }
                $sha = [System.Security.Cryptography.SHA256]::Create()
                return ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($tmp))) -replace '-','').ToLower().Substring(0,12)
            } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }

        function Get-BytesCaso {
            param([string]$Caso)
            switch ($Caso) {
                'review'         { return $script:u8.GetBytes('{"findings":"Sem findings criticos."}') }
                'placeholder'    { return $script:u8.GetBytes('{"deferred":true,"reason":"DeepSeek falhou (exit 4)","decision":"dual","placeholder":true}') }
                'findings-vazio' { return $script:u8.GetBytes('{"findings":""}') }
                'so-espaco'      { return $script:u8.GetBytes('{"findings":"   \n\t  "}') }
                'nao-string'     { return $script:u8.GetBytes('{"findings":42}') }
                'raiz-array'     { return $script:u8.GetBytes('[{"findings":"Sem findings criticos."}]') }
                'vazio'          { return ,[byte[]]@() }
                'nao-json'       { return $script:u8.GetBytes('Sem findings criticos.') }
                'acima-teto'     { return $script:u8.GetBytes('{"findings":"' + ('a' * 262200) + '"}') }
                'bom'            { return [byte[]](@(0xEF, 0xBB, 0xBF) + $script:u8.GetBytes('{"findings":"Sem findings criticos."}')) }
            }
        }

        # Repo com a.ps1 alterado E staged: o hook git so age com algo staged, e .ps1 fura a
        # dispensa por extensao da politica de risco.
        function New-RepoMarcador {
            param([string]$Caso, [ValidateSet('hash','latest','nenhum')][string]$Onde, [switch]$SemCommit)
            $dir = Join-Path $script:tmpBase ("r-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Push-Location $dir
            try {
                & git init -q . 2>$null; & git config user.email t@t.t 2>$null; & git config user.name t 2>$null
                if (-not $SemCommit) {
                    [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "original`n", $script:u8)
                    & git add a.ps1 2>$null
                    & git @(('com' + 'mit'), '-q', '-m', 'base', '--no-verify') 2>$null
                }
                [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "alterado com acentuacao`n", $script:u8)
                & git add a.ps1 2>$null
            } finally { Pop-Location }
            $rev = Join-Path (Join-Path $dir '.deepseek') 'reviews'
            New-Item -ItemType Directory -Force -Path $rev | Out-Null
            $latest = Join-Path $rev 'latest.jsonl'
            if ($Onde -eq 'latest') {
                [IO.File]::WriteAllBytes($latest, (Get-BytesCaso $Caso))
            } else {
                [IO.File]::WriteAllBytes($latest, (Get-BytesCaso 'review'))
                (Get-Item $latest).LastWriteTime = (Get-Date).AddMinutes(-60)
            }
            if ($Onde -eq 'hash') {
                [IO.File]::WriteAllBytes((Join-Path $rev ("d-" + (Get-DiffHash $dir) + ".jsonl")), (Get-BytesCaso $Caso))
            }
            return $dir
        }

        function Invoke-Camada {
            param([string]$Camada, [string]$Repo, [string]$Alternativo = '')
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $cmd = 'cd "' + (ConvertTo-CaminhoBash $Repo) + '" && git com' + 'mit -m x'
            $payload = @{ tool_name = 'Bash'; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            $code = -1
            if ($Camada -eq 'ps1') {
                $payload | & pwsh -NoProfile -File $script:hookPs1 2>$err | Out-Null; $code = $LASTEXITCODE
            } elseif ($Camada -eq 'sh') {
                $alvo = $script:hookSh; if ($Alternativo) { $alvo = $Alternativo }
                $payload | & $script:bash (ConvertTo-CaminhoBash $alvo) 2>$err | Out-Null; $code = $LASTEXITCODE
            } else {
                $alvo = $script:templateLF; if ($Alternativo) { $alvo = $Alternativo }
                Push-Location $Repo
                try { & $script:bash -c ("sh '" + (ConvertTo-CaminhoBash $alvo) + "'") 2>$err | Out-Null; $code = $LASTEXITCODE } finally { Pop-Location }
            }
            $texto = ''
            if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            return [pscustomobject]@{ Code = $code; Err = $texto }
        }
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "pre-condicao: Git Bash com jq, sha256sum e awk" {
        # Sem jq o pre-commit-check.sh libera tudo e as linhas sh passariam por vacuidade.
        $script:bash | Should -Not -BeNullOrEmpty
        $saida = & $script:bash -c 'command -v jq; command -v sha256sum; command -v awk' 2>&1 | Out-String
        $saida | Should -Match 'jq'
        $saida | Should -Match 'sha256sum'
        $saida | Should -Match 'awk'
    }

    It "<Camada> | <Onde> | <Caso>" -ForEach $script:matriz {
        $repo = New-RepoMarcador -Caso $Caso -Onde $Onde
        $r = Invoke-Camada -Camada $Camada -Repo $repo
        if ($Libera) {
            $r.Code | Should -Be 0 -Because "deveria liberar. stderr: $($r.Err)"
        } else {
            $r.Code | Should -Be $script:bloqueio[$Camada] -Because "deveria bloquear. stderr: $($r.Err)"
            if ($Motivo) { $r.Err | Should -Match ([regex]::Escape($Motivo)) }
            if ($Onde -eq 'hash') { $r.Err | Should -Match 'd-[0-9a-f]{12}\.jsonl recusado' }
        }
        if ($Onde -eq 'latest' -and $Caso -eq 'placeholder') {
            $r.Err | Should -Match 'SEM review real'
            $log = Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'deferidos.log'
            $linhas = @([IO.File]::ReadAllLines($log, $script:u8) | Where-Object { $_.Trim() })
            $linhas.Count | Should -Be 1
            $j = $linhas[0] | ConvertFrom-Json
            $esperada = 'pretooluse'; if ($Camada -eq 'git') { $esperada = 'git-hook' }
            $j.camada    | Should -Be $esperada
            $j.decision  | Should -Be 'dual'
            $j.reason    | Should -Be 'DeepSeek falhou (exit 4)'
            $j.repo      | Should -Not -BeNullOrEmpty
            "$($j.timestamp)" | Should -Not -BeNullOrEmpty
        }
    }

    It "<Camada>: hash do diff vazio (repo sem commit) nao usa d-e3b0c44298fc.jsonl" -ForEach @(
        @{ Camada = 'ps1' }, @{ Camada = 'sh' }, @{ Camada = 'git' }
    ) {
        # Um d-e3b0c44298fc.jsonl real existe hoje em outro worktree: liberaria por 24 h qualquer
        # diff de repo sem commit (emenda FR-016).
        $repo = New-RepoMarcador -Caso 'review' -Onde 'nenhum' -SemCommit
        $rev = Join-Path (Join-Path $repo '.deepseek') 'reviews'
        [IO.File]::WriteAllText((Join-Path $rev 'd-e3b0c44298fc.jsonl'), '{"findings":"Sem findings criticos."}', $script:u8)
        $r = Invoke-Camada -Camada $Camada -Repo $repo
        $r.Code | Should -Be $script:bloqueio[$Camada] -Because "latest.jsonl tem 60 min; so o d-e3b0 liberaria. stderr: $($r.Err)"
    }

    It "<Camada>: latest.jsonl invalido e velho bloqueia pelo TEMPO, sem classificar" -ForEach @(
        @{ Camada = 'ps1' }, @{ Camada = 'sh' }, @{ Camada = 'git' }
    ) {
        $repo = New-RepoMarcador -Caso 'nao-json' -Onde 'latest'
        $latest = Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'latest.jsonl'
        (Get-Item $latest).LastWriteTime = (Get-Date).AddMinutes(-10)
        $r = Invoke-Camada -Camada $Camada -Repo $repo
        $r.Code | Should -Be $script:bloqueio[$Camada]
        $r.Err  | Should -Match 'max 5'
        $r.Err  | Should -Not -Match 'nao e JSON'
    }

    It "<Camada>: deferidos.log que nao grava nao muda a decisao" -ForEach @(
        @{ Camada = 'ps1' }, @{ Camada = 'sh' }, @{ Camada = 'git' }
    ) {
        $repo = New-RepoMarcador -Caso 'placeholder' -Onde 'latest'
        New-Item -ItemType Directory -Force -Path (Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'deferidos.log') | Out-Null
        (Invoke-Camada -Camada $Camada -Repo $repo).Code | Should -Be 0
    }

    It "ps1: erro interno sai 0 com WARN no STDERR" {
        $err = Join-Path $script:tmpBase 'warn.txt'
        '{isto nao e json' | & pwsh -NoProfile -File $script:hookPs1 2>$err | Out-Null
        $LASTEXITCODE | Should -Be 0
        ([IO.File]::ReadAllText($err)) | Should -Match '^\[percus:hook pre-commit\] WARN:'
    }

    It "o bloco awk e identico nos dois .sh" {
        $blocos = foreach ($arq in @($script:hookSh, $script:template)) {
            $t = [IO.File]::ReadAllText($arq).Replace("`r", '')
            $i = $t.IndexOf('# >>> percus-classifica-marcador')
            $f = $t.IndexOf('# <<< percus-classifica-marcador')
            $i | Should -BeGreaterThan -1 -Because "$arq sem o bloco"
            $f | Should -BeGreaterThan $i
            $t.Substring($i, $f - $i)
        }
        $blocos[0] | Should -BeExactly $blocos[1]
    }

    It "<Camada>: copia CRLF (como no cache do plugin) ainda classifica review" -ForEach @(
        @{ Camada = 'sh' }, @{ Camada = 'git' }
    ) {
        $orig = $script:hookSh; if ($Camada -eq 'git') { $orig = $script:template }
        $crlf = Join-Path $script:tmpBase ("crlf-" + $Camada + ".sh")
        $t = [IO.File]::ReadAllText($orig).Replace("`r`n", "`n").Replace("`n", "`r`n")
        [IO.File]::WriteAllText($crlf, $t, $script:u8)
        $repo = New-RepoMarcador -Caso 'review' -Onde 'latest'
        $r = Invoke-Camada -Camada $Camada -Repo $repo -Alternativo $crlf
        $r.Code | Should -Be 0 -Because "stderr: $($r.Err)"
    }
}
