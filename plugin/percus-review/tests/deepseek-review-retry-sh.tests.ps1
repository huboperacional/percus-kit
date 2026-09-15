#requires -Version 5.1
# Paridade do deepseek-review.sh com o .ps1 (FR-001..006, SC-003..005). O .sh chamava curl sem
# capturar status e sem --max-time, e o marcador nao gravava model/usage (defasado desde 2026-08-15).

Describe "deepseek-review.sh -- timeout, retry e provedor indisponivel" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        . (Join-Path $PSScriptRoot '_servidor-http-falso.ps1')
        $scripts = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts'
        $script:clienteSh  = ConvertTo-CaminhoBash (Join-Path $scripts 'deepseek-review.sh')
        $script:clientePs1 = Join-Path $scripts 'deepseek-review.ps1'
        $script:bash = Get-BashGit
        $script:chave = 'sk-teste-FALSA-0123456789abcdef'
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-dss-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $script:ok = '{"choices":[{"message":{"content":"Sem findings criticos."},"finish_reason":"stop"}],"usage":{"prompt_tokens":11,"completion_tokens":7}}'
        $script:semChoices5k = '{"eco":"' + $script:chave + '","pad":"' + ('x' * 5000) + '"}'

        function New-RepoCliente {
            param([switch]$SemCommit)
            $dir = Join-Path $script:tmpBase ("r-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Push-Location $dir
            try {
                & git init -q . 2>$null; & git config user.email t@t.t 2>$null; & git config user.name t 2>$null
                [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "original`n", $script:u8)
                & git add a.ps1 2>$null
                if (-not $SemCommit) { & git @(('com' + 'mit'), '-q', '-m', 'base', '--no-verify') 2>$null }
                [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "alterado`n", $script:u8)
                if ($SemCommit) { & git add a.ps1 2>$null }
            } finally { Pop-Location }
            return $dir
        }

        function Invoke-Cliente {
            param([string]$Repo, [string]$Url, [string[]]$ArgsExtra = @(), [hashtable]$Env = @{})
            # TMPDIR proprio por chamada: e onde o cliente cria o percus-auth-* (F-f), e o teste
            # confere que nada sobra ali depois da saida, qualquer que seja o codigo.
            $tmpCall = Join-Path $script:tmpBase ("t-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $tmpCall | Out-Null
            $envTotal = @{ DEEPSEEK_API_KEY = $script:chave; PERCUS_DEEPSEEK_TIMEOUT_S = $null; PERCUS_DEEPSEEK_BACKOFF_S = $null; DEEPSEEK_ENDPOINT = $null; TMPDIR = $tmpCall }
            foreach ($k in $Env.Keys) { $envTotal[$k] = $Env[$k] }
            $antigos = Set-EnvTemporario $envTotal
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            # Env pelo AMBIENTE do processo, nao como prefixo do -c (o bash re-parsearia as aspas).
            $cmd = "cd '" + (ConvertTo-CaminhoBash $Repo) + "' && bash '" + $script:clienteSh + "' --endpoint '" + $Url + "' " + ($ArgsExtra -join ' ')
            $sw = [Diagnostics.Stopwatch]::StartNew()
            try {
                $out = & $script:bash -c $cmd 2>$err
                $code = $LASTEXITCODE
            } finally { $sw.Stop(); Restore-EnvTemporario $antigos }
            $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            $rev = Join-Path (Join-Path $Repo '.deepseek') 'reviews'
            $marcadores = @()
            if (Test-Path $rev) { $marcadores = @(Get-ChildItem $rev -Filter '*.jsonl' | ForEach-Object { $_.Name }) }
            $sobras = @(Get-ChildItem -LiteralPath $tmpCall -Filter 'percus-auth-*' -Force | ForEach-Object { $_.Name })
            return [pscustomobject]@{ Code = $code; Err = $texto; Out = ($out -join "`n"); Segundos = $sw.Elapsed.TotalSeconds; Marcadores = $marcadores; Rev = $rev; SobrasAuth = $sobras }
        }

        function Invoke-ComRoteiro {
            param([object[]]$Roteiro, [string[]]$ArgsExtra = @('--timeout', '2', '--backoff', '1'), [hashtable]$Env = @{}, [switch]$SemCommit)
            $srv = Start-ServidorFalso -Roteiro $Roteiro
            try {
                $repo = New-RepoCliente -SemCommit:$SemCommit
                $r = Invoke-Cliente -Repo $repo -Url $srv.Url -ArgsExtra $ArgsExtra -Env $Env
                $r | Add-Member -NotePropertyName Requisicoes -NotePropertyValue (Get-ContagemServidorFalso $srv)
                $pedidos = @()
                for ($i = 1; $i -le $r.Requisicoes; $i++) { $pedidos += ,(Get-PedidoServidorFalso $srv $i) }
                $r | Add-Member -NotePropertyName Pedidos -NotePropertyValue $pedidos
                return $r
            } finally { Stop-ServidorFalso $srv }
        }
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "200 com choices: 1 requisicao, exit 0, latest.jsonl e d-<hash>.jsonl gravados" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok))
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        $r.Marcadores | Should -Contain 'latest.jsonl'
        @($r.Marcadores | Where-Object { $_ -match '^d-[0-9a-f]{12}\.jsonl$' }).Count | Should -Be 1
        $j = [IO.File]::ReadAllText((Join-Path $r.Rev 'latest.jsonl'), $script:u8) | ConvertFrom-Json
        $j.model | Should -Be 'deepseek-v4-flash'
        $j.usage.completion_tokens | Should -Be 7
        $j.findings | Should -Match 'Sem findings criticos'
        @($r.SobrasAuth).Count | Should -Be 0 -Because "F-f: o arquivo do cabecalho sai no trap (exit 0)"
    }

    It "1a falha por <Nome>, 2a responde: exit 0, 2 requisicoes, aviso de retry, tempo extra <= backoff+timeout+1s" -ForEach @(
        @{ Nome = 'HTTP 429';        Primeira = @{ status = 429; corpo = '{"error":{"message":"rate"}}'; pendurar = $false }; Causa = 'HTTP 429' }
        @{ Nome = 'HTTP 503';        Primeira = @{ status = 503; corpo = '{"error":{"message":"boom"}}'; pendurar = $false }; Causa = 'HTTP 503' }
        @{ Nome = '200 sem choices'; Primeira = @{ status = 200; corpo = '{"id":"x"}'; pendurar = $false }; Causa = 'HTTP 200 sem choices' }
        @{ Nome = '200 corpo vazio'; Primeira = @{ status = 200; corpo = ''; pendurar = $false }; Causa = 'HTTP 200 com corpo vazio' }
        @{ Nome = 'timeout';         Primeira = @{ status = 200; corpo = ''; pendurar = $true }; Causa = 'timeout de 2s' }
    ) {
        $base = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok))
        $r = Invoke-ComRoteiro -Roteiro @($Primeira, (New-RespostaFalsa -Corpo $script:ok))
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 2
        $r.Err | Should -Match ([regex]::Escape("tentativa 1 falhou: ") + '.*' + [regex]::Escape($Causa))
        $r.Err | Should -Match 'Nova tentativa em 1s\.'
        $r.Marcadores | Should -Contain 'latest.jsonl'
        ($r.Segundos - $base.Segundos) | Should -BeLessOrEqual (1 + 2 + 1) -Because "SC-004"
    }

    It "5xx nas 2 tentativas: exit 4, 2 requisicoes, nenhum marcador" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Status 500 -Corpo '{"error":"x"}'))
        $r.Code | Should -Be 4 -Because $r.Err
        $r.Requisicoes | Should -Be 2
        $r.Err | Should -Match 'PROVEDOR INDISPONIVEL apos retry: HTTP 500'
        @($r.Marcadores).Count | Should -Be 0
        @($r.SobrasAuth).Count | Should -Be 0 -Because "F-f: o arquivo do cabecalho sai no trap tambem no exit 4"
        foreach ($p in $r.Pedidos) { $p | Should -Match ('(?m)^Authorization: Bearer ' + [regex]::Escape($script:chave) + "`r$") -Because "a 2a tentativa reusa o mesmo cabecalho" }
    }

    It "SC-003: 2xx sem choices (5 KB com a chave) nas 2 tentativas -> 2000 caracteres mascarados, exit 4 no .sh" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:semChoices5k))
        $trecho = $script:semChoices5k.Replace($script:chave, '***').Substring(0, 2000)
        $r.Code | Should -Be 4 -Because $r.Err
        $r.Requisicoes | Should -Be 2
        $r.Err.Contains($trecho) | Should -BeTrue -Because "stderr tem de mostrar exatamente os primeiros 2000 caracteres"
        $r.Err.Contains($trecho + 'x') | Should -BeFalse -Because "nem um caractere a mais"
        $r.Err.Contains($script:chave) | Should -BeFalse
        $ue = [IO.File]::ReadAllText((Join-Path $r.Rev 'ultimo-erro.txt'), $script:u8)
        $ue | Should -Match '^timestamp=\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\nstatus=200\n---\n'
        $ue.Substring($ue.IndexOf("---`n") + 4) | Should -BeExactly $trecho
        @($r.Marcadores).Count | Should -Be 0
    }

    It "HTTP <Status>: exatamente 1 requisicao, exit 1, nenhum marcador" -ForEach @(@{ Status = 401 }, @{ Status = 404 }) {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Status $Status -Corpo ('{"error":"chave ' + $script:chave + '"}')))
        $r.Code | Should -Be 1 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        $r.Err | Should -Match "HTTP $Status -- nao recuperavel"
        $r.Err.Contains($script:chave) | Should -BeFalse
        @($r.Marcadores).Count | Should -Be 0
        @($r.SobrasAuth).Count | Should -Be 0 -Because "F-f: o arquivo do cabecalho sai no trap tambem no exit 1"
    }

    It "5xx e depois 401: para no 401 com exit 1" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Status 502 -Corpo '{}'), (New-RespostaFalsa -Status 401 -Corpo '{}'))
        $r.Code | Should -Be 1 -Because $r.Err
        $r.Requisicoes | Should -Be 2
    }

    It "SC-005: servidor que nunca responde, timeout 2 s, backoff 1 s -> exit 4 em ate 6 s alem de uma chamada normal no .sh" {
        $base = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok))
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Pendurar))
        $r.Code | Should -Be 4 -Because $r.Err
        $r.Requisicoes | Should -Be 2
        ($r.Segundos - $base.Segundos) | Should -BeLessOrEqual 6
        @($r.Marcadores).Count | Should -Be 0
    }

    It "choices com content vazio ou finish_reason=<Fim>: exit 3 SEM retry" -ForEach @(
        @{ Fim = 'stop';   Corpo = '{"choices":[{"message":{"content":""},"finish_reason":"stop"}]}' }
        @{ Fim = 'length'; Corpo = '{"choices":[{"message":{"content":"meia frase"},"finish_reason":"length"}]}' }
    ) {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $Corpo))
        $r.Code | Should -Be 3 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        @($r.Marcadores).Count | Should -Be 0
    }

    It "precedencia <Nome>" -ForEach @(
        @{ Nome = 'padrao';           ArgsCaso = @();                                   Env = @{};                                                              Esperado = 'timeout=180s backoff=5s' }
        @{ Nome = 'env';              ArgsCaso = @();                                   Env = @{ PERCUS_DEEPSEEK_TIMEOUT_S = '7'; PERCUS_DEEPSEEK_BACKOFF_S = '3' }; Esperado = 'timeout=7s backoff=3s' }
        @{ Nome = 'flag > env';       ArgsCaso = @('--timeout', '2', '--backoff', '1'); Env = @{ PERCUS_DEEPSEEK_TIMEOUT_S = '7'; PERCUS_DEEPSEEK_BACKOFF_S = '3' }; Esperado = 'timeout=2s backoff=1s' }
        @{ Nome = 'env invalida';     ArgsCaso = @();                                   Env = @{ PERCUS_DEEPSEEK_TIMEOUT_S = 'abc' };                            Esperado = 'timeout=180s backoff=5s' }
    ) {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -ArgsExtra $ArgsCaso -Env $Env
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Err | Should -Match ([regex]::Escape("[deepseek-review] $Esperado"))
        if ($Nome -eq 'env invalida') { $r.Err | Should -Match "WARN: PERCUS_DEEPSEEK_TIMEOUT_S='abc' invalido" }
    }

    It "--timeout 0: exit 2 sem chamar a API" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -ArgsExtra @('--timeout', '0')
        $r.Code | Should -Be 2
        $r.Requisicoes | Should -Be 0
    }

    # Fix round 1 (2026-09-14, achado da review): "08"/"09" sao digitos validos mas o bash avalia
    # -lt/-ge em contexto aritmetico, onde zero a esquerda vira octal invalido e solta "value too
    # great for base" no stderr, alem de a comparacao falhar por acidente (aceita o que devia
    # recusar, recusa o que devia aceitar). 10#$v normaliza antes de comparar/atribuir.
    It "--timeout 08: trata como 8, sem erro aritmetico do bash no stderr" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -ArgsExtra @('--timeout', '08', '--backoff', '1')
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Err | Should -Match ([regex]::Escape('[deepseek-review] timeout=8s backoff=1s'))
        $r.Err | Should -Not -Match 'value too great for base'
    }

    It "env PERCUS_DEEPSEEK_TIMEOUT_S=08: timeout=8s, sem WARN e sem erro aritmetico do bash" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -ArgsExtra @() -Env @{ PERCUS_DEEPSEEK_TIMEOUT_S = '08' }
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Err | Should -Match ([regex]::Escape('[deepseek-review] timeout=8s backoff=5s'))
        $r.Err | Should -Not -Match 'WARN: PERCUS_DEEPSEEK_TIMEOUT_S'
        $r.Err | Should -Not -Match 'value too great for base'
    }

    It "emenda FR-011: repo sem commit (diff HEAD vazio) grava latest.jsonl mas NUNCA d-e3b0c44298fc.jsonl no .sh" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -SemCommit
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Marcadores | Should -Contain 'latest.jsonl'
        @($r.Marcadores | Where-Object { $_ -like 'd-*' }).Count | Should -Be 0
    }

    It "pre-condicao: Git Bash com curl e jq" {
        $script:bash | Should -Not -BeNullOrEmpty
        $saida = & $script:bash -c 'command -v curl; command -v jq' 2>&1 | Out-String
        $saida | Should -Match 'curl'
        $saida | Should -Match 'jq'
    }

    It "corpo com acentos: o trecho de 2000 caracteres do .sh e o mesmo do .ps1" {
        # Corte por CARACTERE (spec), nao por byte: exige locale UTF-8 no substring do bash.
        $acentos = 'a' + [char]0x00E7 + [char]0x00E3 + 'o '
        $corpo = '{"pad":"' + ($acentos * 900) + '"}'
        $srv = Start-ServidorFalso -Roteiro @((New-RespostaFalsa -Corpo $corpo))
        try {
            $repoSh = New-RepoCliente
            $null = Invoke-Cliente -Repo $repoSh -Url $srv.Url -ArgsExtra @('--timeout', '2', '--backoff', '1')
            $repoPs = New-RepoCliente
            $antigos = Set-EnvTemporario @{ DEEPSEEK_API_KEY = $script:chave }
            Push-Location $repoPs
            try { & pwsh -NoProfile -File $script:clientePs1 -Endpoint $srv.Url -TimeoutSec 2 -BackoffSec 1 2>$null | Out-Null } finally { Pop-Location; Restore-EnvTemporario $antigos }
        } finally { Stop-ServidorFalso $srv }
        $esperado = $corpo.Substring(0, 2000)
        foreach ($repo in @($repoPs, $repoSh)) {
            $t = [IO.File]::ReadAllText((Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'ultimo-erro.txt'), $script:u8)
            $t.Substring($t.IndexOf("---`n") + 4) | Should -BeExactly $esperado -Because $repo
        }
    }

    # F-f (2026-09-15): a chave ia em `-H "Authorization: Bearer <chave>"`, legivel na linha de
    # comando do curl.exe por qualquer processo do usuario. Prova REAL: o curl fica pendurado no
    # servidor falso e o Pester le a CommandLine dele pelo WMI enquanto a chamada esta viva.
    It "F-f: durante a chamada pendurada nenhum curl.exe tem a chave na CommandLine; exit 4 sem sobra de percus-auth-*" {
        $srv = Start-ServidorFalso -Roteiro @((New-RespostaFalsa -Pendurar))
        $proc = $null; $vistos = @(); $code = $null; $sobras = @(); $textoErr = ''
        try {
            $repo = New-RepoCliente
            $tmpCall = Join-Path $script:tmpBase ("t-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $tmpCall | Out-Null
            $errArq = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $outArq = Join-Path $script:tmpBase ("out-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $antigos = Set-EnvTemporario @{ DEEPSEEK_API_KEY = $script:chave; PERCUS_DEEPSEEK_TIMEOUT_S = $null; PERCUS_DEEPSEEK_BACKOFF_S = $null; DEEPSEEK_ENDPOINT = $null; TMPDIR = $tmpCall }
            try {
                $cmd = "bash '" + $script:clienteSh + "' --endpoint '" + $srv.Url + "' --timeout 3 --backoff 1"
                # Aspas manuais: Start-Process junta ArgumentList com espaco sem citar.
                $proc = Start-Process -FilePath $script:bash -ArgumentList @('-c', ('"' + $cmd + '"')) -WorkingDirectory $repo -PassThru -NoNewWindow -RedirectStandardError $errArq -RedirectStandardOutput $outArq
                $null = $proc.Handle  # PS 5.1: sem pegar o handle antes, ExitCode sai vazio
                $marcaUrl = '127.0.0.1:' + $srv.Porta + '/'
                $limite = (Get-Date).AddSeconds(5)
                while ($vistos.Count -eq 0 -and (Get-Date) -lt $limite) {
                    $vistos = @(Get-CimInstance Win32_Process -Filter "Name='curl.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains($marcaUrl) } | ForEach-Object { $_.CommandLine })
                    if ($vistos.Count -eq 0) { Start-Sleep -Milliseconds 100 }
                }
                $proc.WaitForExit(30000) | Should -BeTrue -Because "3 s + 1 s + 3 s cabem folgados em 30 s"
                $code = $proc.ExitCode
                $sobras = @(Get-ChildItem -LiteralPath $tmpCall -Filter 'percus-auth-*' -Force | ForEach-Object { $_.Name })
                if (Test-Path -LiteralPath $errArq) { $textoErr = [IO.File]::ReadAllText($errArq, $script:u8) }
            } finally {
                Restore-EnvTemporario $antigos
                if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
            }
        } finally { Stop-ServidorFalso $srv }
        $vistos.Count | Should -BeGreaterThan 0 -Because "anti-vacuidade: o curl pendurado tem de ser visto pelo WMI ($textoErr)"
        foreach ($linha in $vistos) {
            $linha.Contains($script:chave) | Should -BeFalse -Because "a chave nao pode estar no argv do curl: $linha"
            $linha | Should -Match 'percus-auth-' -Because "o cabecalho vem do arquivo temporario (-H @arquivo)"
        }
        $code | Should -Be 4 -Because $textoErr
        $sobras.Count | Should -Be 0 -Because "o trap EXIT remove o arquivo do cabecalho tambem no exit 4"
    }

    It "F-f: 200 ok -> o servidor recebe 'Authorization: Bearer <chave>' uma vez, sem \r extra mesmo com a chave vinda com \r" {
        # Afere o RESULTADO no fio. Sabotagem medida em 2026-09-15: sem o strip de \r no script o
        # teste continua verde, porque o curl 8.18 apara o \r ao ler `-H @arquivo`. O strip do
        # script e defesa contra outro curl; este teste pega regressao do conjunto, nao do strip.
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -Env @{ DEEPSEEK_API_KEY = ($script:chave + "`r") }
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        $r.Pedidos[0] | Should -Match ('(?m)^Authorization: Bearer ' + [regex]::Escape($script:chave) + "`r$") -Because "a linha tem de terminar em CRLF do curl, sem \r da chave"
        [regex]::Matches($r.Pedidos[0], '(?im)^Authorization:').Count | Should -Be 1
        $r.Pedidos[0] | Should -Match '(?im)^Content-Type: application/json; charset=utf-8\r$'
        @($r.SobrasAuth).Count | Should -Be 0
    }

    It "F-f: nenhum .sh do plugin nem scripts/deepseek-impl.sh passa a chave como argumento (grep 'Bearer \$|x-api-key: \$' = 0) e todos usam -H @arquivo no trap" {
        $raiz = Split-Path $PSScriptRoot -Parent
        $kitRaiz = Split-Path (Split-Path $raiz -Parent) -Parent
        $implSh = Join-Path $kitRaiz 'scripts\deepseek-impl.sh'
        $hits = @(Get-ChildItem -LiteralPath $raiz -Recurse -Filter '*.sh' -File | Select-String -Pattern 'Bearer \$|x-api-key: \$' | ForEach-Object { $_.Path + ':' + $_.LineNumber })
        $hits += @(Get-ChildItem -LiteralPath $implSh -File | Select-String -Pattern 'Bearer \$|x-api-key: \$' | ForEach-Object { $_.Path + ':' + $_.LineNumber })
        $hits.Count | Should -Be 0 -Because ($hits -join ', ')
        foreach ($rel in @('scripts/deepseek-review.sh', 'providers/deepseek.sh', 'providers/groq-llama.sh', 'providers/cross-claude.sh')) {
            $src = [IO.File]::ReadAllText((Join-Path $raiz $rel), $script:u8)
            $src.Contains('-H "@$AUTH_FILE"') | Should -BeTrue -Because "$rel (anti-vacuidade)"
            $src | Should -Match 'percus-auth-XXXXXX' -Because $rel
            $src | Should -Match "(?m)^trap '[^']*AUTH_FILE[^']*' EXIT" -Because "$rel remove o cabecalho no trap"
        }
        $srcImpl = [IO.File]::ReadAllText($implSh, $script:u8)
        $srcImpl.Contains('-H "@$AUTH_FILE"') | Should -BeTrue -Because "scripts/deepseek-impl.sh (anti-vacuidade)"
        $srcImpl | Should -Match 'percus-auth-XXXXXX' -Because 'scripts/deepseek-impl.sh'
        $srcImpl | Should -Match "(?m)^trap '[^']*AUTH_FILE[^']*' EXIT" -Because "scripts/deepseek-impl.sh remove o cabecalho no trap"
    }
}

Describe "providers .sh -- chave fora do argv do curl (F-f)" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        . (Join-Path $PSScriptRoot '_servidor-http-falso.ps1')
        $script:provDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'providers'
        $script:bash = Get-BashGit
        $script:chave = 'sk-teste-FALSA-0123456789abcdef'
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-prv-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "<Prov>.sh: '<Cab><chave>' chega ao servidor sem \r extra, status ok, sem sobra de percus-auth-*" -ForEach @(
        @{ Prov = 'deepseek';     VarChave = 'DEEPSEEK_API_KEY';  Cab = 'Authorization: Bearer '; Corpo = '{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1}}' }
        @{ Prov = 'groq-llama';   VarChave = 'GROQ_API_KEY';      Cab = 'Authorization: Bearer '; Corpo = '{"choices":[{"message":{"content":"ok"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1}}' }
        @{ Prov = 'cross-claude'; VarChave = 'ANTHROPIC_API_KEY'; Cab = 'x-api-key: ';            Corpo = '{"model":"m","content":[{"type":"text","text":"ok"}],"usage":{"input_tokens":1,"output_tokens":1}}' }
    ) {
        $dir = Join-Path $script:tmpBase ("p-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        $tmpCall = Join-Path $dir 'tmp'
        New-Item -ItemType Directory -Force -Path $tmpCall | Out-Null
        [IO.File]::WriteAllText((Join-Path $dir 'prompt.txt'), 'pergunta de teste', $script:u8)
        $err = Join-Path $dir 'err.txt'
        $srv = Start-ServidorFalso -Roteiro @((New-RespostaFalsa -Corpo $Corpo))
        try {
            $envT = @{ TMPDIR = $tmpCall; DEEPSEEK_API_KEY = $null; GROQ_API_KEY = $null; ANTHROPIC_API_KEY = $null }
            $envT[$VarChave] = $script:chave + "`r"
            $antigos = Set-EnvTemporario $envT
            try {
                $cmd = "cd '" + (ConvertTo-CaminhoBash $dir) + "' && bash '" + (ConvertTo-CaminhoBash (Join-Path $script:provDir "$Prov.sh")) + "' --prompt-file prompt.txt --endpoint '" + $srv.Url + "'"
                $out = & $script:bash -c $cmd 2>$err
                $code = $LASTEXITCODE
            } finally { Restore-EnvTemporario $antigos }
            $pedido = Get-PedidoServidorFalso $srv 1
        } finally { Stop-ServidorFalso $srv }
        $textoErr = ''; if (Test-Path -LiteralPath $err) { $textoErr = [IO.File]::ReadAllText($err, $script:u8) }
        $code | Should -Be 0 -Because $textoErr
        (($out -join "`n") | ConvertFrom-Json).status | Should -Be 'ok' -Because ($out -join "`n")
        $pedido | Should -Match ('(?m)^' + [regex]::Escape($Cab + $script:chave) + "`r$")
        @(Get-ChildItem -LiteralPath $tmpCall -Filter 'percus-auth-*' -Force).Count | Should -Be 0
    }
}
