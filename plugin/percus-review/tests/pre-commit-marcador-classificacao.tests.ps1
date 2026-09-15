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
    # 'ps1-51' repete a mesma matriz do 'ps1', mas invocada sob Windows PowerShell 5.1
    # (powershell.exe) -- runtime real dos hooks em producao (revisao final, I2: a matriz so
    # exercitava pwsh 7). Skip visivel por caso quando a maquina nao tem powershell.exe.
    $script:matriz = @()
    foreach ($cam in @('ps1', 'sh', 'git', 'ps1-51')) {
        foreach ($c in $casos) {
            foreach ($onde in @('hash', 'latest')) {
                $lib = $c.LiberaLatest; if ($onde -eq 'hash') { $lib = $c.LiberaHash }
                $mot = $c.Motivo; if ($onde -eq 'latest' -and $c.Caso -eq 'placeholder') { $mot = '' }
                $script:matriz += @{ Camada = $cam; Caso = $c.Caso; Onde = $onde; Libera = $lib; Motivo = $mot }
            }
        }
    }
    # Dados para os casos parametrizados por host (FR-019 e o caso do Minor 2).
    $script:hostsFR019 = @(
        @{ Rotulo = 'ps1 (pwsh 7)'; Chave = 'pwsh' }
        @{ Rotulo = 'ps1 (powershell.exe 5.1)'; Chave = '51' }
    )
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
        $script:bloqueio = @{ ps1 = 2; sh = 2; git = 1; 'ps1-51' = 2 }
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        # Resolvido uma vez: $null se a maquina nao tiver Windows PowerShell 5.1 instalado (fora do
        # padrao em Windows 10/11, mas possivel). Casos 'ps1-51' e FR-019/Minor 2 pulam com Skip.
        $script:ps51 = (Get-Command 'powershell.exe' -ErrorAction SilentlyContinue).Source

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
                'findings-data-iso' { return $script:u8.GetBytes('{"findings":"2026-09-14T10:00:00Z"}') }
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

        # F-c (2026-09-15): diretorio com um `awk` quebrado para ir a frente do PATH. Quando o
        # programa contem o texto do classificador ('findings nao e string'), sai 0 sem imprimir
        # nada -- o classificador "nao responde"; nos demais casos delega ao awk real.
        function New-DirAwkQuebrado {
            $dir = Join-Path $script:tmpBase ("awk-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $real = (& $script:bash -c 'command -v awk' 2>$null | Select-Object -First 1).Trim()
            $corpo = "#!/bin/sh`ncase `"`$*`" in`n  *'findings nao e string'*) exit 0 ;;`nesac`nexec '" + $real + "' `"`$@`"`n"
            [IO.File]::WriteAllText((Join-Path $dir 'awk'), $corpo, $script:u8)
            return $dir
        }

        function Invoke-Camada {
            param([string]$Camada, [string]$Repo, [string]$Alternativo = '', [string]$DirPathExtra = '')
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $cmd = 'cd "' + (ConvertTo-CaminhoBash $Repo) + '" && git com' + 'mit -m x'
            $payload = @{ tool_name = 'Bash'; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            # PATH em formato Bash (/c/...): 'C:/...' partiria no ':' separador. Sem aspas duplas no
            # argumento nativo -- atribuicao em bash nao sofre word-split.
            $prefixo = ''
            if ($DirPathExtra) { $prefixo = "PATH=`$(cygpath -u '" + (ConvertTo-CaminhoBash $DirPathExtra) + "'):`$PATH; export PATH; " }
            $code = -1
            if ($Camada -eq 'ps1' -or $Camada -eq 'ps1-51') {
                $exe = 'pwsh'; if ($Camada -eq 'ps1-51') { $exe = $script:ps51 }
                $payload | & $exe -NoProfile -File $script:hookPs1 2>$err | Out-Null; $code = $LASTEXITCODE
            } elseif ($Camada -eq 'sh') {
                $alvo = $script:hookSh; if ($Alternativo) { $alvo = $Alternativo }
                if ($prefixo) {
                    $payload | & $script:bash -c ($prefixo + "exec bash '" + (ConvertTo-CaminhoBash $alvo) + "'") 2>$err | Out-Null; $code = $LASTEXITCODE
                } else {
                    $payload | & $script:bash (ConvertTo-CaminhoBash $alvo) 2>$err | Out-Null; $code = $LASTEXITCODE
                }
            } else {
                $alvo = $script:templateLF; if ($Alternativo) { $alvo = $Alternativo }
                Push-Location $Repo
                try { & $script:bash -c ($prefixo + "sh '" + (ConvertTo-CaminhoBash $alvo) + "'") 2>$err | Out-Null; $code = $LASTEXITCODE } finally { Pop-Location }
            }
            $texto = ''
            if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            return [pscustomobject]@{ Code = $code; Err = $texto }
        }
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "git hibrido | <Onde> | <Caso>: R11 que libera segue para a logica custom apos END" -ForEach @(
        @{ Onde = 'hash';   Caso = 'review';      Esperado = 7 }
        @{ Onde = 'latest'; Caso = 'review';      Esperado = 7 }
        @{ Onde = 'latest'; Caso = 'placeholder'; Esperado = 7 }
        @{ Onde = 'hash';   Caso = 'nao-json';    Esperado = 1 }
    ) {
        # 2026-09-15: liberar pelo hash fazia `exit 0` dentro do bloco Percus e o gate V2 instalado
        # depois do END nunca rodava nos projetos com hook hibrido (tiatendo, auth-service, Plexco Coach).
        $hibrido = Join-Path $script:tmpBase ("hibrido-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        $texto = [IO.File]::ReadAllText($script:templateLF, $script:u8)
        $fim = $texto.LastIndexOf('exit 0')
        $texto = $texto.Substring(0, $fim) + "echo CUSTOM-RODOU >&2`nexit 7`n"
        [IO.File]::WriteAllText($hibrido, $texto, $script:u8)
        $repo = New-RepoMarcador -Caso $Caso -Onde $Onde
        $r = Invoke-Camada -Camada 'git' -Repo $repo -Alternativo $hibrido
        $r.Code | Should -Be $Esperado -Because "stderr: $($r.Err)"
        if ($Esperado -eq 7) { $r.Err | Should -Match 'CUSTOM-RODOU' } else { $r.Err | Should -Not -Match 'CUSTOM-RODOU' }
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
        if ($Camada -eq 'ps1-51' -and -not $script:ps51) { Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"; return }
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

    It "<Rotulo>: erro interno sai 0 com WARN no STDERR (FR-019)" -ForEach $script:hostsFR019 {
        $exe = $Chave
        if ($Chave -eq '51') {
            if (-not $script:ps51) { Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"; return }
            $exe = $script:ps51
        }
        $err = Join-Path $script:tmpBase ("warn-" + [Guid]::NewGuid().ToString('N').Substring(0,6) + '.txt')
        '{isto nao e json' | & $exe -NoProfile -File $script:hookPs1 2>$err | Out-Null
        $LASTEXITCODE | Should -Be 0
        ([IO.File]::ReadAllText($err)) | Should -Match '^\[percus:hook pre-commit\] WARN:'
    }

    It "<Camada> | <Onde>: classificador que nao responde avisa e libera (F-c, paridade FR-019)" -ForEach @(
        @{ Camada = 'sh';  Onde = 'latest' }
        @{ Camada = 'git'; Onde = 'latest' }
        @{ Camada = 'sh';  Onde = 'hash' }
        @{ Camada = 'git'; Onde = 'hash' }
    ) {
        # Antes (6.56.1) a classe vazia caia no BLOCK "marcador invalido: " com motivo vazio, e no
        # caminho por hash gerava "recusado: " vazio. O .ps1 ja abria com WARN (pre-commit-check.ps1:292).
        $repo = New-RepoMarcador -Caso 'review' -Onde $Onde
        if ($Onde -eq 'hash') {
            # latest fresco: a classe vazia do hash tem de cair no caminho do latest.
            (Get-Item (Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'latest.jsonl')).LastWriteTime = Get-Date
        }
        $r = Invoke-Camada -Camada $Camada -Repo $repo -DirPathExtra (New-DirAwkQuebrado)
        $r.Code | Should -Be 0 -Because "stderr: $($r.Err)"
        if ($Camada -eq 'sh') {
            $r.Err | Should -Match '^\[percus:hook pre-commit\] WARN: hook crashed, allowing commit\. Error: classificador do marcador nao respondeu'
        } else {
            $r.Err | Should -Match ([regex]::Escape('[percus:hook pre-commit native] WARN: classificador do marcador nao respondeu, liberando commit'))
        }
        $r.Err | Should -Not -Match 'recusado'
        $r.Err | Should -Not -Match 'BLOCK'
    }

    It "<Camada>: classificador que nao responde no hash, com latest velho, bloqueia pelo TEMPO sem 'recusado' vazio (F-c)" -ForEach @(
        @{ Camada = 'sh' }, @{ Camada = 'git' }
    ) {
        $repo = New-RepoMarcador -Caso 'review' -Onde 'hash'
        $r = Invoke-Camada -Camada $Camada -Repo $repo -DirPathExtra (New-DirAwkQuebrado)
        $r.Code | Should -Be $script:bloqueio[$Camada] -Because "stderr: $($r.Err)"
        $r.Err  | Should -Match 'max 5'
        $r.Err  | Should -Not -Match 'recusado'
    }

    It "git hibrido: classificador que nao responde avisa e SEGUE para a logica custom (F-c)" {
        $hibrido = Join-Path $script:tmpBase ("hibrido-fc-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        $texto = [IO.File]::ReadAllText($script:templateLF, $script:u8)
        $fim = $texto.LastIndexOf('exit 0')
        $texto = $texto.Substring(0, $fim) + "echo CUSTOM-RODOU >&2`nexit 7`n"
        [IO.File]::WriteAllText($hibrido, $texto, $script:u8)
        $repo = New-RepoMarcador -Caso 'review' -Onde 'latest'
        $r = Invoke-Camada -Camada 'git' -Repo $repo -Alternativo $hibrido -DirPathExtra (New-DirAwkQuebrado)
        $r.Code | Should -Be 7 -Because "stderr: $($r.Err)"
        $r.Err  | Should -Match 'WARN: classificador do marcador nao respondeu'
        $r.Err  | Should -Match 'CUSTOM-RODOU'
    }

    It "fixture: o awk quebrado de fato silencia o classificador e delega o resto" {
        $dir = ConvertTo-CaminhoBash (New-DirAwkQuebrado)
        $s = & $script:bash -c ("PATH=`$(cygpath -u '" + $dir + "'):`$PATH; export PATH; printf 'delegou\n' | awk '{print}'; awk 'BEGIN{print 12345} # findings nao e string' </dev/null; echo fim") 2>&1 | Out-String
        $s | Should -Match 'delegou'
        $s | Should -Not -Match '12345'
        $s | Should -Match 'fim'
    }

    It "<Camada>: findings com cara de data ISO diverge entre hosts (Minor 2 -- comportamento atual, sem mudar o hook)" -ForEach @(
        @{ Camada = 'ps1' }
        @{ Camada = 'ps1-51' }
    ) {
        if ($Camada -eq 'ps1-51' -and -not $script:ps51) { Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"; return }
        # ConvertFrom-Json do pwsh 7 converte uma string com cara de data ISO-8601 em [DateTime];
        # Windows PowerShell 5.1 mantem a string. O hook classifica pelo TIPO de `findings`, entao o
        # mesmo marcador vira 'invalido: findings nao e string' em pwsh 7 e 'review' (libera) em 5.1.
        # Sem efeito em producao (5.1 e o runtime real) e improvavel numa review de verdade; aqui so
        # para documentar a divergencia (Minor 2 da revisao final) -- nao mexer no classificador por
        # causa disto.
        $repo = New-RepoMarcador -Caso 'findings-data-iso' -Onde 'hash'
        $r = Invoke-Camada -Camada $Camada -Repo $repo
        if ($Camada -eq 'ps1-51') {
            $r.Code | Should -Be 0 -Because "5.1 mantem findings como string (ConvertFrom-Json nao converte). stderr: $($r.Err)"
        } else {
            $r.Code | Should -Be $script:bloqueio['ps1'] -Because "pwsh 7 converte a string ISO em [DateTime] -- findings deixa de ser string. stderr: $($r.Err)"
            $r.Err | Should -Match 'findings nao e string'
        }
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
