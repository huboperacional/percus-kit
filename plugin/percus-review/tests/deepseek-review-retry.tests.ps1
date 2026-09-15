#requires -Version 5.1
# FR-001..006 / SC-003..005 no deepseek-review.ps1. Medido 2026-09-14: sem timeout nem retry, 3
# falhas + 1 travamento de 4 min numa tarde; 2xx sem choices morria em "Cannot index into a null
# array" e descartava o corpo. Aqui o script roda INTEIRO contra um servidor falso local.

Describe "deepseek-review.ps1 -- timeout, retry e provedor indisponivel" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        . (Join-Path $PSScriptRoot '_servidor-http-falso.ps1')
        $script:cliente = Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts') 'deepseek-review.ps1'
        $script:chave = 'sk-teste-FALSA-0123456789abcdef'
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-dsr-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $script:ok = '{"choices":[{"message":{"content":"Sem findings criticos."},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1}}'
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
            # -Executavel parametrizado (2026-09-14, fix round 1): a suite inteira roda sob pwsh
            # (.NET Core). O runtime real dos hooks e Windows PowerShell 5.1 (.NET Framework), onde
            # HttpClient carrega e embrulha timeout de forma diferente -- um cliente que so foi
            # exercitado em pwsh pode quebrar SILENCIOSAMENTE no runtime que todo projeto usa.
            param([string]$Repo, [string]$Url, [string[]]$ArgsExtra = @(), [hashtable]$Env = @{}, [string]$Executavel = 'pwsh')
            $envTotal = @{ DEEPSEEK_API_KEY = $script:chave; PERCUS_DEEPSEEK_TIMEOUT_S = $null; PERCUS_DEEPSEEK_BACKOFF_S = $null }
            foreach ($k in $Env.Keys) { $envTotal[$k] = $Env[$k] }
            $antigos = Set-EnvTemporario $envTotal
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $sw = [Diagnostics.Stopwatch]::StartNew()
            Push-Location $Repo
            try {
                $out = & $Executavel -NoProfile -File $script:cliente -Endpoint $Url @ArgsExtra 2>$err
                $code = $LASTEXITCODE
            } finally { Pop-Location; $sw.Stop(); Restore-EnvTemporario $antigos }
            $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            $rev = Join-Path (Join-Path $Repo '.deepseek') 'reviews'
            $marcadores = @()
            if (Test-Path $rev) { $marcadores = @(Get-ChildItem $rev -Filter '*.jsonl' | ForEach-Object { $_.Name }) }
            return [pscustomobject]@{ Code = $code; Err = $texto; Out = ($out -join "`n"); Segundos = $sw.Elapsed.TotalSeconds; Marcadores = $marcadores; Rev = $rev }
        }

        function Invoke-ComRoteiro {
            param([object[]]$Roteiro, [string[]]$ArgsExtra = @('-TimeoutSec', '2', '-BackoffSec', '1'), [hashtable]$Env = @{}, [switch]$SemCommit, [string]$Executavel = 'pwsh')
            $srv = Start-ServidorFalso -Roteiro $Roteiro
            try {
                $repo = New-RepoCliente -SemCommit:$SemCommit
                $r = Invoke-Cliente -Repo $repo -Url $srv.Url -ArgsExtra $ArgsExtra -Env $Env -Executavel $Executavel
                $r | Add-Member -NotePropertyName Requisicoes -NotePropertyValue (Get-ContagemServidorFalso $srv)
                return $r
            } finally { Stop-ServidorFalso $srv }
        }

        # Resolvido uma vez no BeforeAll do Describe: $null se a maquina nao tiver Windows
        # PowerShell 5.1 instalado (fora do padrao em Windows 10/11, mas possivel).
        $script:ps51 = (Get-Command 'powershell.exe' -ErrorAction SilentlyContinue).Source
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
    }

    It "SC-003: 2xx sem choices (5 KB com a chave) nas 2 tentativas -> 2000 caracteres mascarados, exit 4" {
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
    }

    It "5xx e depois 401: para no 401 com exit 1" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Status 502 -Corpo '{}'), (New-RespostaFalsa -Status 401 -Corpo '{}'))
        $r.Code | Should -Be 1 -Because $r.Err
        $r.Requisicoes | Should -Be 2
    }

    It "SC-005: servidor que nunca responde, timeout 2 s, backoff 1 s -> exit 4 em ate 6 s alem de uma chamada normal" {
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
        @{ Nome = 'parametro > env';  ArgsCaso = @('-TimeoutSec', '2', '-BackoffSec', '1'); Env = @{ PERCUS_DEEPSEEK_TIMEOUT_S = '7'; PERCUS_DEEPSEEK_BACKOFF_S = '3' }; Esperado = 'timeout=2s backoff=1s' }
        @{ Nome = 'env invalida';     ArgsCaso = @();                                   Env = @{ PERCUS_DEEPSEEK_TIMEOUT_S = 'abc' };                            Esperado = 'timeout=180s backoff=5s' }
    ) {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -ArgsExtra $ArgsCaso -Env $Env
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Err | Should -Match ([regex]::Escape("[deepseek-review] $Esperado"))
        if ($Nome -eq 'env invalida') { $r.Err | Should -Match "WARN: PERCUS_DEEPSEEK_TIMEOUT_S='abc' invalido" }
    }

    It "-TimeoutSec 0: exit 2 sem chamar a API" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -ArgsExtra @('-TimeoutSec', '0')
        $r.Code | Should -Be 2
        $r.Requisicoes | Should -Be 0
    }

    It "emenda FR-011: repo sem commit (diff HEAD vazio) grava latest.jsonl mas NUNCA d-e3b0c44298fc.jsonl" {
        $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -SemCommit
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Marcadores | Should -Contain 'latest.jsonl'
        @($r.Marcadores | Where-Object { $_ -like 'd-*' }).Count | Should -Be 0
    }

    # Fix round 1 (2026-09-14, achado da review R11 do controlador): a matriz inteira acima roda
    # sob pwsh (.NET Core). O runtime real dos hooks e Windows PowerShell 5.1 (.NET Framework),
    # onde HttpClient carrega e embrulha timeout de forma diferente. Nao repete a matriz inteira
    # aqui -- subconjunto minimo que prova que as strings do CONTRATO saem identicas nos dois
    # runtimes: sucesso, retry por timeout (2 conexoes), 4xx fatal (1 conexao) e mascara da chave.
    Context "mesmo contrato sob Windows PowerShell 5.1 (powershell.exe)" {
        It "200 com choices: 1 requisicao, exit 0 (5.1)" {
            if (-not $script:ps51) { Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"; return }
            $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:ok)) -Executavel $script:ps51
            $r.Code | Should -Be 0 -Because $r.Err
            $r.Requisicoes | Should -Be 1
        }

        It "1a falha por timeout, 2a responde: exit 0, exatamente 2 requisicoes (5.1)" {
            if (-not $script:ps51) { Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"; return }
            $roteiro = @(@{ status = 200; corpo = ''; pendurar = $true }, (New-RespostaFalsa -Corpo $script:ok))
            $r = Invoke-ComRoteiro -Roteiro $roteiro -Executavel $script:ps51
            $r.Code | Should -Be 0 -Because $r.Err
            $r.Requisicoes | Should -Be 2
            $r.Err | Should -Match ([regex]::Escape("tentativa 1 falhou: ") + '.*' + [regex]::Escape('timeout de 2s'))
            $r.Err | Should -Match 'Nova tentativa em 1s\.'
        }

        It "HTTP 401: exatamente 1 requisicao, exit 1, sem retry (5.1)" {
            if (-not $script:ps51) { Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"; return }
            $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Status 401 -Corpo ('{"error":"chave ' + $script:chave + '"}'))) -Executavel $script:ps51
            $r.Code | Should -Be 1 -Because $r.Err
            $r.Requisicoes | Should -Be 1
            $r.Err | Should -Match "HTTP 401 -- nao recuperavel"
            $r.Err.Contains($script:chave) | Should -BeFalse
        }

        It "SC-003: mascara a chave no corpo despejado antes de cortar em 2000 chars (5.1)" {
            if (-not $script:ps51) { Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"; return }
            $r = Invoke-ComRoteiro -Roteiro @((New-RespostaFalsa -Corpo $script:semChoices5k)) -Executavel $script:ps51
            $trecho = $script:semChoices5k.Replace($script:chave, '***').Substring(0, 2000)
            $r.Code | Should -Be 4 -Because $r.Err
            $r.Requisicoes | Should -Be 2
            $r.Err.Contains($trecho) | Should -BeTrue -Because "stderr tem de mostrar exatamente os primeiros 2000 caracteres, tambem em 5.1"
            $r.Err.Contains($script:chave) | Should -BeFalse
        }
    }
}
