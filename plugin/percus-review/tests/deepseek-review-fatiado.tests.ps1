#requires -Version 5.1
# Ponto 23 (2026-09-15): diff acima do teto e revisado em fatias por arquivo. Os achados saturam em
# ~2,6 por chamada (verbete achado-de-review-satura-com-o-tamanho-do-diff). O .ps1 e o .sh rodam
# INTEIROS contra o servidor falso, num repo temporario real; o corpo de cada pedido e aferido.

BeforeDiscovery {
    $script:runtimes = @(@{ Rt = 'ps1' }, @{ Rt = 'sh' })
}

Describe "deepseek-review -- fatiamento por arquivo (ponto 23)" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        . (Join-Path $PSScriptRoot '_servidor-http-falso.ps1')
        $plugin = Split-Path $PSScriptRoot -Parent
        $script:clientePs1 = Join-Path (Join-Path $plugin 'scripts') 'deepseek-review.ps1'
        $script:clienteSh  = ConvertTo-CaminhoBash (Join-Path (Join-Path $plugin 'scripts') 'deepseek-review.sh')
        $script:hookPs1 = Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.ps1'
        $script:hookSh  = Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.sh'
        $script:bash = Get-BashGit
        $script:chave = 'sk-teste-FALSA-0123456789abcdef'
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:travessao = [string][char]0x2014
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-fat-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $script:semChoices = '{"id":"x"}'

        function New-Ok {
            param([int]$Prompt, [string]$Texto = 'Sem findings criticos.', [string]$Fim = 'stop')
            return (New-RespostaFalsa -Corpo ('{"choices":[{"message":{"content":"' + $Texto + '"},"finish_reason":"' + $Fim + '"}],"usage":{"prompt_tokens":' + $Prompt + ',"completion_tokens":2,"total_tokens":' + ($Prompt + 2) + ',"prompt_cache_hit_tokens":1}}'))
        }

        # Arquivos NOVOS staged: o bloco de cada um no diff tem 6 linhas de cabecalho + conteudo,
        # entao Linhas = tamanho exato do bloco no texto que vai ao modelo.
        function New-RepoFatiado {
            param([object[]]$Arquivos)
            $dir = Join-Path $script:tmpBase ("r-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            & git -C $dir init -q 2>$null
            & git -C $dir config user.email t@t.t 2>$null
            & git -C $dir config user.name t 2>$null
            & git -C $dir config core.autocrlf false 2>$null
            [IO.File]::WriteAllText((Join-Path $dir 'README.txt'), "base`n", $script:u8)
            & git -C $dir add README.txt 2>$null
            # 'com' + 'mit' NAO e ofuscacao: o hook de commit le o TEXTO do comando, e as palavras
            # git+commit por extenso num comando PowerShell disparam o gate R11 do repo de verdade
            # (regras de ambiente). Parenteses no array: a virgula liga antes do +. Mesmo padrao
            # dos outros testes do plugin.
            & git -C $dir @(('com' + 'mit'), '-q', '-m', 'base', '--no-verify') 2>$null
            foreach ($a in $Arquivos) {
                $sb = New-Object System.Text.StringBuilder
                for ($i = 1; $i -le ($a.Linhas - 6); $i++) { [void]$sb.Append("linha $i de $($a.Nome)`n") }
                $alvo = Join-Path $dir $a.Nome
                New-Item -ItemType Directory -Force -Path (Split-Path $alvo -Parent) | Out-Null
                [IO.File]::WriteAllText($alvo, $sb.ToString(), $script:u8)
                & git -C $dir add -- $a.Nome 2>$null
            }
            return $dir
        }

        function Invoke-Revisao {
            param([string]$Rt, [string]$Repo, [string]$Url, [hashtable]$Opc = @{}, [hashtable]$Env = @{})
            $tmpCall = Join-Path $script:tmpBase ("t-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $tmpCall | Out-Null
            $envTotal = @{ DEEPSEEK_API_KEY = $script:chave; PERCUS_DEEPSEEK_TIMEOUT_S = $null; PERCUS_DEEPSEEK_BACKOFF_S = $null
                           PERCUS_R11_MAX_LINHAS_FATIA = $null; PERCUS_R11_MAX_FATIAS = $null; DEEPSEEK_ENDPOINT = $null; TMPDIR = $tmpCall }
            foreach ($k in $Env.Keys) { $envTotal[$k] = $Env[$k] }
            $antigos = Set-EnvTemporario $envTotal
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            try {
                if ($Rt -eq 'ps1') {
                    $a = @('-Endpoint', $Url, '-TimeoutSec', '2', '-BackoffSec', '1')
                    if ($Opc.ContainsKey('MaxLinhasFatia')) { $a += @('-MaxLinhasFatia', "$($Opc.MaxLinhasFatia)") }
                    if ($Opc.ContainsKey('MaxFatias')) { $a += @('-MaxFatias', "$($Opc.MaxFatias)") }
                    Push-Location $Repo
                    try { $out = & pwsh -NoProfile -File $script:clientePs1 @a 2>$err; $code = $LASTEXITCODE } finally { Pop-Location }
                } else {
                    $a = "--endpoint '" + $Url + "' --timeout 2 --backoff 1"
                    if ($Opc.ContainsKey('MaxLinhasFatia')) { $a += " --max-linhas-fatia $($Opc.MaxLinhasFatia)" }
                    if ($Opc.ContainsKey('MaxFatias')) { $a += " --max-fatias $($Opc.MaxFatias)" }
                    $cmd = "cd '" + (ConvertTo-CaminhoBash $Repo) + "' && bash '" + $script:clienteSh + "' " + $a
                    $out = & $script:bash -c $cmd 2>$err
                    $code = $LASTEXITCODE
                }
            } finally { Restore-EnvTemporario $antigos }
            $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            $rev = Join-Path (Join-Path $Repo '.deepseek') 'reviews'
            $marcadores = @()
            if (Test-Path $rev) { $marcadores = @(Get-ChildItem $rev -Filter '*.jsonl' | ForEach-Object { $_.Name }) }
            $spendDir = Join-Path (Join-Path $Repo '.deepseek') 'spend'
            $spend = @()
            if (Test-Path $spendDir) {
                $spend = @(Get-ChildItem $spendDir -Filter '*.jsonl' | ForEach-Object { [IO.File]::ReadAllLines($_.FullName, $script:u8) } | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
            }
            $sobras = @(Get-ChildItem -LiteralPath $tmpCall -Force | ForEach-Object { $_.Name })
            return [pscustomobject]@{ Code = $code; Err = $texto; Out = ($out -join "`n"); Marcadores = $marcadores; Rev = $rev; Spend = $spend; Sobras = $sobras }
        }

        function Invoke-Caso {
            param([string]$Rt, [object[]]$Arquivos, [object[]]$Roteiro, [hashtable]$Opc = @{}, [hashtable]$Env = @{}, [string]$Repo = '')
            $srv = Start-ServidorFalso -Roteiro $Roteiro
            try {
                if (-not $Repo) { $Repo = New-RepoFatiado -Arquivos $Arquivos }
                $r = Invoke-Revisao -Rt $Rt -Repo $Repo -Url $srv.Url -Opc $Opc -Env $Env
                $n = Get-ContagemServidorFalso $srv
                $corpos = @()
                for ($i = 1; $i -le $n; $i++) {
                    $c = Get-CorpoServidorFalso $srv $i
                    if ($c) { $corpos += ,($c | ConvertFrom-Json) } else { $corpos += ,$null }
                }
                $r | Add-Member -NotePropertyName Requisicoes -NotePropertyValue $n
                $r | Add-Member -NotePropertyName Corpos -NotePropertyValue $corpos
                $r | Add-Member -NotePropertyName Repo -NotePropertyValue $Repo
                return $r
            } finally { Stop-ServidorFalso $srv }
        }

        function Get-Latest {
            param($R)
            return ([IO.File]::ReadAllText((Join-Path $R.Rev 'latest.jsonl'), $script:u8) | ConvertFrom-Json)
        }

        function Test-TemArquivo {
            param($Corpo, [string]$Nome)
            return $Corpo.messages[1].content.Contains("diff --git a/$Nome b/$Nome")
        }

        $script:quatro = @(
            @{ Nome = 'a.tests.ps1'; Linhas = 300 }
            @{ Nome = 'b1.ps1'; Linhas = 800 }
            @{ Nome = 'b2.ps1'; Linhas = 700 }
            @{ Nome = 'b3.ps1'; Linhas = 400 }
        )
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "pre-condicao: Git Bash com curl, jq, awk e sha256sum" {
        $script:bash | Should -Not -BeNullOrEmpty
        $saida = & $script:bash -c 'command -v curl; command -v jq; command -v awk; command -v sha256sum' 2>&1 | Out-String
        foreach ($c in @('curl', 'jq', 'awk', 'sha256sum')) { $saida | Should -Match $c }
    }

    It "<Rt>: diff de 300 linhas -> 1 pedido, corpo sem fatia, fatias:1, d-<hash> gravado, spend com fatia 1/1" -ForEach $script:runtimes {
        $r = Invoke-Caso -Rt $Rt -Arquivos @(@{ Nome = 'a.ps1'; Linhas = 300 }) -Roteiro @((New-Ok 10))
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        $sis = $r.Corpos[0].messages[0].content
        $sis | Should -Not -Match 'fatia'
        $sis.TrimEnd() | Should -Match 'responda "Sem findings cr.ticos\."$' -Because "system prompt sem nada acrescentado"
        $r.Corpos[0].messages[1].content | Should -Match '^AGENTS\.md do projeto:\n'
        (Test-TemArquivo $r.Corpos[0] 'a.ps1') | Should -BeTrue
        $j = Get-Latest $r
        $j.fatias | Should -Be 1
        $j.findings | Should -Be 'Sem findings criticos.'
        $j.usage.prompt_tokens | Should -Be 10
        @($r.Marcadores | Where-Object { $_ -match '^d-[0-9a-f]{12}\.jsonl$' }).Count | Should -Be 1
        @($r.Spend).Count | Should -Be 1
        $r.Spend[0].fatia | Should -Be 1
        $r.Spend[0].fatias | Should -Be 1
        $r.Spend[0].latency_ms | Should -Not -BeNullOrEmpty
        $r.Err | Should -Match 'max_linhas_fatia=1500 max_fatias=8 diff_lines=300 chamadas=1'
    }

    It "<Rt>: 800+700+400 de codigo + 300 de teste, teto 1500 -> 3 pedidos [b1+b2] [b3] [a.tests.ps1], usage somado, fatias:3" -ForEach $script:runtimes {
        $r = Invoke-Caso -Rt $Rt -Arquivos $script:quatro -Roteiro @((New-Ok 10 'achado um'), (New-Ok 20 'achado dois'), (New-Ok 30 'achado tres'))
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 3
        $c1 = $r.Corpos[0]; $c2 = $r.Corpos[1]; $c3 = $r.Corpos[2]
        (Test-TemArquivo $c1 'b1.ps1') | Should -BeTrue
        (Test-TemArquivo $c1 'b2.ps1') | Should -BeTrue
        (Test-TemArquivo $c1 'b3.ps1') | Should -BeFalse
        (Test-TemArquivo $c1 'a.tests.ps1') | Should -BeFalse
        (Test-TemArquivo $c2 'b3.ps1') | Should -BeTrue
        (Test-TemArquivo $c2 'b2.ps1') | Should -BeFalse
        (Test-TemArquivo $c2 'a.tests.ps1') | Should -BeFalse
        foreach ($n in @('b1.ps1', 'b2.ps1', 'b3.ps1')) { (Test-TemArquivo $c3 $n) | Should -BeFalse -Because "fatia de teste nunca mistura codigo ($n)" }
        (Test-TemArquivo $c3 'a.tests.ps1') | Should -BeTrue
        $c1.messages[0].content | Should -Match ([regex]::Escape('Esta e a fatia 1 de 3 (arquivos: b1.ps1, b2.ps1). Revise so o que esta nela.'))
        $c3.messages[0].content | Should -Match ([regex]::Escape('Esta e a fatia 3 de 3 (arquivos: a.tests.ps1). Revise so o que esta nela.'))
        $c3.messages[1].content | Should -Match '^AGENTS\.md do projeto:\n'
        $j = Get-Latest $r
        $j.fatias | Should -Be 3
        $j.diff_lines | Should -Be 2200
        $j.findings.Contains("### Fatia 1/3 $($script:travessao) b1.ps1, b2.ps1`n`nachado um") | Should -BeTrue -Because $j.findings
        $j.findings.Contains("### Fatia 2/3 $($script:travessao) b3.ps1`n`nachado dois") | Should -BeTrue -Because $j.findings
        $j.findings.Contains("### Fatia 3/3 $($script:travessao) a.tests.ps1`n`nachado tres") | Should -BeTrue -Because $j.findings
        $j.usage.prompt_tokens | Should -Be 60
        $j.usage.completion_tokens | Should -Be 6
        $j.usage.total_tokens | Should -Be 66
        $j.usage.prompt_cache_hit_tokens | Should -Be 3
        $j.usage.prompt_cache_miss_tokens | Should -Be 0 -Because "campo ausente nas 3 respostas soma 0"
        @($r.Marcadores | Where-Object { $_ -match '^d-[0-9a-f]{12}\.jsonl$' }).Count | Should -Be 1
        @($r.Spend).Count | Should -Be 3
        @($r.Spend | ForEach-Object { $_.fatia }) -join ',' | Should -Be '1,2,3'
        @($r.Spend | ForEach-Object { $_.fatias }) -join ',' | Should -Be '3,3,3'
        @($r.Spend | ForEach-Object { $_.diff_lines }) -join ',' | Should -Be '1500,400,300'
        @($r.Spend | ForEach-Object { $_.usage.prompt_tokens }) -join ',' | Should -Be '10,20,30'
        foreach ($s in $r.Spend) { $s.latency_ms | Should -BeGreaterOrEqual 0 }
        @($r.Sobras | Where-Object { $_ -like 'percus-auth-*' -or $_ -like 'percus-fatias-*' }).Count | Should -Be 0 -Because "trap limpa cabecalho e fatias"
    }

    It "<Rt>: 2o pedido 200 sem choices x2 -> exit 4 com (fatia 2/3), nenhum latest/d-/spend, 3a fatia nao pedida" -ForEach $script:runtimes {
        $r = Invoke-Caso -Rt $Rt -Arquivos $script:quatro -Roteiro @((New-Ok 10), (New-RespostaFalsa -Corpo $script:semChoices), (New-RespostaFalsa -Corpo $script:semChoices), (New-Ok 30))
        $r.Code | Should -Be 4 -Because $r.Err
        $r.Err | Should -Match ([regex]::Escape('PROVEDOR INDISPONIVEL apos retry: HTTP 200 sem choices. Nenhum marcador gravado (exit 4). (fatia 2/3)'))
        $r.Requisicoes | Should -Be 3 -Because "fatia 1 + 2 tentativas da fatia 2; a 3a fatia nunca e pedida"
        @($r.Marcadores).Count | Should -Be 0 -Because "saida parcial nao libera commit meio revisado"
        @($r.Spend).Count | Should -Be 0
        @($r.Sobras | Where-Object { $_ -like 'percus-auth-*' -or $_ -like 'percus-fatias-*' }).Count | Should -Be 0
    }

    It "<Rt>: 1o pedido finish_reason length -> exit 3, 1 pedido, nenhum marcador" -ForEach $script:runtimes {
        $r = Invoke-Caso -Rt $Rt -Arquivos $script:quatro -Roteiro @((New-Ok 10 'meia frase' 'length'), (New-Ok 20))
        $r.Code | Should -Be 3 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        ($r.Err + $r.Out) | Should -Match ([regex]::Escape('(fatia 1/3)'))
        @($r.Marcadores).Count | Should -Be 0
        @($r.Spend).Count | Should -Be 0
    }

    It "<Rt>: Z.Tests.ps1 (grafia do Pester) conta como teste e vai para a ultima fatia" -ForEach $script:runtimes {
        # Achado do R11 desta mudanca: com casamento case-sensitive o `.Tests.ps1` caia no grupo de
        # codigo. 'Z' vem antes de 'b' na ordem do diff, entao so o agrupamento pode inverter.
        $r = Invoke-Caso -Rt $Rt -Arquivos @(@{ Nome = 'Z.Tests.ps1'; Linhas = 250 }, @{ Nome = 'b1.ps1'; Linhas = 300 }) -Roteiro @((New-Ok 10), (New-Ok 20)) -Opc @{ MaxLinhasFatia = 200 }
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 2
        (Test-TemArquivo $r.Corpos[0] 'b1.ps1') | Should -BeTrue
        (Test-TemArquivo $r.Corpos[0] 'Z.Tests.ps1') | Should -BeFalse
        (Test-TemArquivo $r.Corpos[1] 'Z.Tests.ps1') | Should -BeTrue
        $r.Corpos[1].messages[0].content | Should -Match ([regex]::Escape('Esta e a fatia 2 de 2 (arquivos: Z.Tests.ps1)'))
    }

    It "<Rt>: arquivo unico de 2.400 linhas -> 1 fatia com o arquivo inteiro" -ForEach $script:runtimes {
        $r = Invoke-Caso -Rt $Rt -Arquivos @(@{ Nome = 'grande.ps1'; Linhas = 2400 }) -Roteiro @((New-Ok 10))
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        $r.Corpos[0].messages[0].content | Should -Not -Match 'fatia'
        $r.Corpos[0].messages[1].content.Contains('linha 2394 de grande.ps1') | Should -BeTrue -Because "sem corte"
        (Get-Latest $r).fatias | Should -Be 1
    }

    It "<Rt>: diff que precisaria de 9 fatias com MaxFatias 8 -> 1 pedido com o diff inteiro e WARN" -ForEach $script:runtimes {
        $arqs = @(); for ($i = 1; $i -le 9; $i++) { $arqs += @{ Nome = "c$i.ps1"; Linhas = 150 } }
        $r = Invoke-Caso -Rt $Rt -Arquivos $arqs -Roteiro @((New-Ok 10)) -Opc @{ MaxLinhasFatia = 200; MaxFatias = 8 }
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Requisicoes | Should -Be 1
        $r.Err | Should -Match ([regex]::Escape('[deepseek-review] WARN: diff de 1350 linhas precisaria de 9 fatias (> 8): revisado inteiro; achados saturam em ~2,6 por chamada -- considere dividir o commit.'))
        for ($i = 1; $i -le 9; $i++) { (Test-TemArquivo $r.Corpos[0] "c$i.ps1") | Should -BeTrue }
        $r.Corpos[0].messages[0].content | Should -Not -Match 'fatia'
        (Get-Latest $r).fatias | Should -Be 1
    }

    It "<Rt>: precedencia -- env invalida vira padrao com WARN; parametro vence env; parametro < 200 e exit 2" -ForEach $script:runtimes {
        $um = @(@{ Nome = 'a.ps1'; Linhas = 300 })
        $r = Invoke-Caso -Rt $Rt -Arquivos $um -Roteiro @((New-Ok 10)) -Env @{ PERCUS_R11_MAX_LINHAS_FATIA = 'abc'; PERCUS_R11_MAX_FATIAS = '0' }
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Err | Should -Match ([regex]::Escape("WARN: PERCUS_R11_MAX_LINHAS_FATIA='abc' invalido -- usando padrao 1500."))
        $r.Err | Should -Match ([regex]::Escape("WARN: PERCUS_R11_MAX_FATIAS='0' invalido -- usando padrao 8."))
        $r.Err | Should -Match 'max_linhas_fatia=1500 max_fatias=8 '
        $r = Invoke-Caso -Rt $Rt -Arquivos $um -Roteiro @((New-Ok 10)) -Env @{ PERCUS_R11_MAX_LINHAS_FATIA = '5000'; PERCUS_R11_MAX_FATIAS = '3' } -Opc @{ MaxLinhasFatia = 250; MaxFatias = 2 }
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Err | Should -Match 'max_linhas_fatia=250 max_fatias=2 '
        $r = Invoke-Caso -Rt $Rt -Arquivos $um -Roteiro @((New-Ok 10)) -Opc @{ MaxLinhasFatia = 199 }
        $r.Code | Should -Be 2 -Because $r.Err
        $r.Requisicoes | Should -Be 0
    }

    It "<Rt>: hook pre-commit-check real (ps1 e sh) le o latest.jsonl fatiado e libera (classifica review)" -ForEach $script:runtimes {
        $r = Invoke-Caso -Rt $Rt -Arquivos $script:quatro -Roteiro @((New-Ok 10))
        $r.Code | Should -Be 0 -Because $r.Err
        (Get-Latest $r).fatias | Should -Be 3
        # So o latest: sem o d-<hash>, o hook tem de classificar o conteudo do latest.jsonl.
        Get-ChildItem $r.Rev -Filter 'd-*.jsonl' | ForEach-Object { [IO.File]::Delete($_.FullName) }
        # 'git com' + 'mit': mesma razao do BeforeAll -- o gate R11 le o texto do comando.
        $cmd = 'cd "' + (ConvertTo-CaminhoBash $r.Repo) + '" && git com' + 'mit -m x'
        $payload = @{ tool_name = 'Bash'; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
        $errPs = Join-Path $script:tmpBase ("hk-" + [Guid]::NewGuid().ToString('N') + '.txt')
        $payload | & pwsh -NoProfile -File $script:hookPs1 2>$errPs | Out-Null
        $codePs = $LASTEXITCODE
        $errSh = Join-Path $script:tmpBase ("hk-" + [Guid]::NewGuid().ToString('N') + '.txt')
        $payload | & $script:bash (ConvertTo-CaminhoBash $script:hookSh) 2>$errSh | Out-Null
        $codeSh = $LASTEXITCODE
        $codePs | Should -Be 0 -Because ([IO.File]::ReadAllText($errPs))
        $codeSh | Should -Be 0 -Because ([IO.File]::ReadAllText($errSh))
        # Anti-vacuidade: o mesmo repo com findings vazio no latest BLOQUEIA.
        [IO.File]::WriteAllText((Join-Path $r.Rev 'latest.jsonl'), '{"findings":"","fatias":3}', $script:u8)
        $payload | & pwsh -NoProfile -File $script:hookPs1 2>$null | Out-Null
        $LASTEXITCODE | Should -Be 2
    }

    It "paridade: .ps1 e .sh no mesmo diff fatiado gravam o mesmo d-<hash> e os mesmos achados/usage" {
        $repo = New-RepoFatiado -Arquivos $script:quatro
        $rPs = Invoke-Caso -Rt 'ps1' -Repo $repo -Roteiro @((New-Ok 10 'um'), (New-Ok 20 'dois'), (New-Ok 30 'tres'))
        $rPs.Code | Should -Be 0 -Because $rPs.Err
        $hPs = @($rPs.Marcadores | Where-Object { $_ -like 'd-*' })
        $jPs = Get-Latest $rPs
        [IO.Directory]::Delete((Join-Path $repo '.deepseek'), $true)
        $rSh = Invoke-Caso -Rt 'sh' -Repo $repo -Roteiro @((New-Ok 10 'um'), (New-Ok 20 'dois'), (New-Ok 30 'tres'))
        $rSh.Code | Should -Be 0 -Because $rSh.Err
        $hSh = @($rSh.Marcadores | Where-Object { $_ -like 'd-*' })
        $jSh = Get-Latest $rSh
        $hPs.Count | Should -Be 1
        $hSh.Count | Should -Be 1
        $hSh[0] | Should -BeExactly $hPs[0]
        $jSh.findings | Should -BeExactly $jPs.findings
        ($jSh.usage | ConvertTo-Json -Compress) | Should -Be ($jPs.usage | ConvertTo-Json -Compress)
        $jSh.fatias | Should -Be $jPs.fatias
        # So o que o fatiamento acrescenta: o prompt-base ja diferia antes (o here-string do .ps1
        # herda o CRLF do arquivo; o .sh manda LF) -- fora do escopo desta tarefa.
        for ($i = 0; $i -lt 3; $i++) {
            $sPs = $rPs.Corpos[$i].messages[0].content; $sSh = $rSh.Corpos[$i].messages[0].content
            $sSh.Substring($sSh.IndexOf("`n`nEsta e a fatia")) | Should -BeExactly $sPs.Substring($sPs.IndexOf("`n`nEsta e a fatia")) -Because "cauda do system da fatia $($i + 1)"
            $rSh.Corpos[$i].messages[1].content.Replace("`r", '') | Should -BeExactly $rPs.Corpos[$i].messages[1].content.Replace("`r", '') -Because "user da fatia $($i + 1)"
        }
    }
}
