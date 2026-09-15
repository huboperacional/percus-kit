#requires -Version 5.1
# FR-009..014 / SC-006. Em 2026-09-14 o controlador calculou o hash a mao e escreveu d-<hash>.jsonl
# sozinho para registrar a review de um subagente: nao havia jeito suportado. Aqui o comando roda
# de verdade nos dois runtimes, e o fluxo termina no hook liberando pelo hash.

BeforeDiscovery {
    $script:runtimes = @(@{ Rt = 'ps1' }, @{ Rt = 'sh' })
}

Describe "registrar-review -- registro da review Cross-Claude" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        $plugin = Split-Path $PSScriptRoot -Parent
        $script:regPs1 = Join-Path (Join-Path $plugin 'scripts') 'registrar-review.ps1'
        $script:regSh  = ConvertTo-CaminhoBash (Join-Path (Join-Path $plugin 'scripts') 'registrar-review.sh')
        $script:hookPs1 = Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.ps1'
        $script:hookSh  = ConvertTo-CaminhoBash (Join-Path (Join-Path $plugin 'hooks') 'pre-commit-check.sh')
        $script:bash = Get-BashGit
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-reg-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $script:acento = 'acentua' + [char]0x00E7 + [char]0x00E3 + 'o'

        function New-RepoReg {
            param([switch]$SemCommit, [switch]$SemDiff)
            $dir = Join-Path $script:tmpBase ("r-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path (Join-Path $dir 'sub') | Out-Null
            Push-Location $dir
            try {
                & git init -q . 2>$null; & git config user.email t@t.t 2>$null; & git config user.name t 2>$null
                [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), "original`n", $script:u8)
                & git add a.ps1 2>$null
                if (-not $SemCommit) { & git @(('com' + 'mit'), '-q', '-m', 'base', '--no-verify') 2>$null }
                if (-not $SemDiff) { [IO.File]::WriteAllText((Join-Path $dir 'a.ps1'), ("alterado com " + $script:acento + "`nsegunda linha`n"), $script:u8) }
            } finally { Pop-Location }
            return $dir
        }

        function Get-DiffHash {
            param([string]$RepoDir)
            $tmp = [IO.Path]::GetTempFileName()
            try {
                Push-Location $RepoDir
                try { & git diff HEAD --output=$tmp 2>$null | Out-Null } finally { Pop-Location }
                $b = [IO.File]::ReadAllBytes($tmp)
                $sha = [System.Security.Cryptography.SHA256]::Create()
                return [pscustomobject]@{
                    Hash   = ([BitConverter]::ToString($sha.ComputeHash($b)) -replace '-','').ToLower().Substring(0,12)
                    Linhas = @($b | Where-Object { $_ -eq 10 }).Count
                }
            } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }

        function New-Findings {
            param([string]$Texto = "Sem findings criticos.`n", [byte[]]$Bytes)
            $f = Join-Path $script:tmpBase ("f-" + [Guid]::NewGuid().ToString('N') + '.txt')
            if ($PSBoundParameters.ContainsKey('Bytes')) { [IO.File]::WriteAllBytes($f, $Bytes) }
            else { [IO.File]::WriteAllText($f, $Texto, $script:u8) }
            return $f
        }

        function Invoke-Registro {
            param([string]$Rt, [string]$Repo, [string]$Arquivo, [string]$Canal = 'cross-claude', [string]$Modelo = '', [string]$Cwd = '', [string]$BashExe = '', [hashtable]$Env = @{})
            if (-not $Cwd) { $Cwd = $Repo }
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $antigos = Set-EnvTemporario $Env
            Push-Location $Cwd
            try {
                if ($Rt -eq 'ps1') {
                    $a = @('-NoProfile', '-File', $script:regPs1, '-Arquivo', $Arquivo, '-Canal', $Canal)
                    if ($Modelo) { $a += @('-Modelo', $Modelo) }
                    $out = & pwsh @a 2>$err
                } else {
                    $b = $script:bash; if ($BashExe) { $b = $BashExe }
                    $cmd = "cd '" + (ConvertTo-CaminhoBash $Cwd) + "' && bash '" + $script:regSh + "' --arquivo '" + (ConvertTo-CaminhoBash $Arquivo) + "' --canal '" + $Canal + "'"
                    if ($Modelo) { $cmd += " --modelo '" + $Modelo + "'" }
                    $out = & $b -c $cmd 2>$err
                }
                $code = $LASTEXITCODE
            } finally { Pop-Location; Restore-EnvTemporario $antigos }
            $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            $rev = Join-Path (Join-Path $Repo '.deepseek') 'reviews'
            $arqs = @()
            if (Test-Path $rev) { $arqs = @(Get-ChildItem $rev -File | ForEach-Object { $_.Name }) }
            return [pscustomobject]@{ Code = $code; Err = $texto; Out = (@($out) -join "`n").Trim(); Rev = $rev; Arquivos = $arqs }
        }
    }

    AfterAll {
        Get-ChildItem $script:tmpBase -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { try { $_.Attributes = 'Normal' } catch { } }
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    Context "recusas: exit 2, nada gravado" {
        It "<Rt>: <Caso>" -ForEach @(
            foreach ($rt in @('ps1', 'sh')) {
                @{ Rt = $rt; Caso = 'arquivo ausente';         Motivo = 'arquivo de findings ausente' }
                @{ Rt = $rt; Caso = 'vazio';                   Motivo = 'findings vazio ou so espaco' }
                @{ Rt = $rt; Caso = 'so espaco';               Motivo = 'findings vazio ou so espaco' }
                @{ Rt = $rt; Caso = 'objeto deferred';         Motivo = 'placeholder' }
                @{ Rt = $rt; Caso = 'objeto placeholder';      Motivo = 'placeholder' }
                @{ Rt = $rt; Caso = 'texto com marcador';      Motivo = '__PERCUS_NEEDS_CROSS_CLAUDE__' }
                @{ Rt = $rt; Caso = 'canal vazio';             Motivo = 'canal vazio' }
                @{ Rt = $rt; Caso = 'repo sem commit';         Motivo = 'rio sem commit' }
                @{ Rt = $rt; Caso = 'diff vazio';              Motivo = 'git diff HEAD vazio' }
                @{ Rt = $rt; Caso = 'acima de 256 KB';         Motivo = 'acima do teto (256 KB)' }
            }
        ) {
            $repo = New-RepoReg -SemCommit:($Caso -eq 'repo sem commit') -SemDiff:($Caso -eq 'diff vazio')
            $canal = 'cross-claude'
            switch ($Caso) {
                'arquivo ausente'    { $f = Join-Path $script:tmpBase 'nao-existe.txt' }
                'vazio'              { $f = New-Findings -Bytes ([byte[]]@()) }
                'so espaco'          { $f = New-Findings -Texto "  `n`t `r`n" }
                'objeto deferred'    { $f = New-Findings -Texto '{"deferred":true,"reason":"x","decision":"dual"}' }
                'objeto placeholder' { $f = New-Findings -Texto '{"placeholder":true,"note":"x"}' }
                'texto com marcador' { $f = New-Findings -Texto "__PERCUS_NEEDS_CROSS_CLAUDE__: rota solo`n" }
                'canal vazio'        { $f = New-Findings; $canal = ' ' }
                'acima de 256 KB'    { $f = New-Findings -Texto ('a' * 262145) }
                default              { $f = New-Findings }
            }
            $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo $f -Canal $canal
            $r.Code | Should -Be 2 -Because $r.Err
            $r.Err  | Should -Match ([regex]::Escape($Motivo))
            @($r.Arquivos).Count | Should -Be 0 -Because "nada gravado: $($r.Arquivos -join ', ')"
        }
    }

    It "<Rt>: texto livre que so MENCIONA deferred e aceito" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $f = New-Findings -Texto ("[SEV: risco] o placeholder grava `"deferred`": true e isso e ok`n")
        (Invoke-Registro -Rt $Rt -Repo $repo -Arquivo $f).Code | Should -Be 0
    }

    It "<Rt>: sucesso grava d-<hash> e latest com o contrato, telemetria e a linha de saida" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $esperado = Get-DiffHash $repo
        $texto = "[SEV: bug] Arquivo: a.ps1:1 -- " + $script:acento + "`n"
        $f = New-Findings -Texto $texto
        $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo $f -Modelo 'claude-sonnet-5'
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Out | Should -Match ('^hash=' + $esperado.Hash + ' latest=\S.*latest\.jsonl d=\S.*d-' + $esperado.Hash + '\.jsonl$')
        foreach ($nome in @('latest.jsonl', "d-$($esperado.Hash).jsonl")) {
            $j = [IO.File]::ReadAllText((Join-Path $r.Rev $nome), $script:u8) | ConvertFrom-Json
            $j.canal      | Should -Be 'cross-claude'
            $j.base       | Should -Be ''
            $j.model      | Should -Be 'claude-sonnet-5'
            $j.usage      | Should -BeNullOrEmpty
            $j.findings   | Should -BeExactly $texto
            $j.diff_lines | Should -Be $esperado.Linhas
            "$($j.timestamp)" | Should -Not -BeNullOrEmpty
        }
        $spend = Get-ChildItem (Join-Path (Join-Path $repo '.deepseek') 'spend') -Filter '*.jsonl'
        @($spend).Count | Should -Be 1
        $s = [IO.File]::ReadAllLines($spend[0].FullName, $script:u8)[0] | ConvertFrom-Json
        $s.tool | Should -Be 'registrar-review'
        $s.provider | Should -Be 'cross-claude'
        $s.model | Should -Be 'claude-sonnet-5'
        $s.diff_lines | Should -Be $esperado.Linhas
        @($r.Arquivos | Where-Object { $_ -like '*.tmp' }).Count | Should -Be 0
    }

    It "<Rt>: sem -Modelo grava model null; findings com BOM sai sem BOM" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $f = New-Findings -Bytes ([byte[]](@(0xEF, 0xBB, 0xBF) + $script:u8.GetBytes("ok`n")))
        $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo $f
        $r.Code | Should -Be 0 -Because $r.Err
        $j = [IO.File]::ReadAllText((Join-Path $r.Rev 'latest.jsonl'), $script:u8) | ConvertFrom-Json
        $j.model | Should -BeNullOrEmpty
        $j.findings | Should -BeExactly "ok`n"
    }

    It "<Rt>: chamado de subdiretorio grava na raiz com o hash da raiz" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo (New-Findings) -Cwd (Join-Path $repo 'sub')
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Arquivos | Should -Contain ("d-" + (Get-DiffHash $repo).Hash + ".jsonl")
        Test-Path (Join-Path (Join-Path $repo 'sub') '.deepseek') | Should -BeFalse
    }

    It "<Rt>: falha ao gravar latest.jsonl -> exit 3 e o d-<hash> desta chamada e removido" -ForEach $script:runtimes {
        $repo = New-RepoReg
        $rev = Join-Path (Join-Path $repo '.deepseek') 'reviews'
        New-Item -ItemType Directory -Force -Path (Join-Path $rev 'latest.jsonl') | Out-Null
        $r = Invoke-Registro -Rt $Rt -Repo $repo -Arquivo (New-Findings)
        $r.Code | Should -Be 3 -Because $r.Err
        @(Get-ChildItem $rev -File -Filter 'd-*').Count | Should -Be 0
        @(Get-ChildItem $rev -File -Filter '*.tmp').Count | Should -Be 0
    }

    It "<Rt>: telemetria que falha nao muda o exit" -ForEach $script:runtimes {
        $repo = New-RepoReg
        New-Item -ItemType Directory -Force -Path (Join-Path $repo '.deepseek') | Out-Null
        [IO.File]::WriteAllText((Join-Path (Join-Path $repo '.deepseek') 'spend'), 'arquivo no lugar do diretorio', $script:u8)
        (Invoke-Registro -Rt $Rt -Repo $repo -Arquivo (New-Findings)).Code | Should -Be 0
    }

    It "sh sem jq: exit 1 com mensagem explicita e nenhum JSON gravado (FR-014)" {
        $semJq = Join-Path (Join-Path (Join-Path $env:ProgramFiles 'Git') 'usr') 'bin'
        $bashSemJq = Join-Path $semJq 'bash.exe'
        $vazio = Join-Path $script:tmpBase 'home-vazio'
        New-Item -ItemType Directory -Force -Path $vazio | Out-Null
        $repo = New-RepoReg
        # A pre-condicao e aferida no MESMO ambiente do cenario abaixo.
        $antigos = Set-EnvTemporario @{ PATH = $semJq; HOME = $vazio }
        try { $pre = & $bashSemJq -c 'command -v jq || echo SEM-JQ' 2>&1 | Out-String } finally { Restore-EnvTemporario $antigos }
        $pre | Should -Match 'SEM-JQ' -Because "sem isso o teste mede o caminho normal"
        $r = Invoke-Registro -Rt 'sh' -Repo $repo -Arquivo (New-Findings) -BashExe $bashSemJq -Env @{ PATH = $semJq; HOME = $vazio }
        $r.Code | Should -Be 1 -Because $r.Err
        $r.Err | Should -Match 'jq'
        @($r.Arquivos).Count | Should -Be 0
    }

    It "concorrencia: dois registros simultaneos nunca deixam marcador parcial ou intercalado" {
        $repo = New-RepoReg
        $fa = New-Findings -Texto ("A" * 50000)
        $fb = New-Findings -Texto ("B" * 50000)
        for ($i = 0; $i -lt 3; $i++) {
            $pa = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile', '-File', ('"' + $script:regPs1 + '"'), '-Arquivo', ('"' + $fa + '"'), '-Canal', 'cross-claude', '-Repo', ('"' + $repo + '"')) -PassThru -WindowStyle Hidden
            $pb = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @('-NoProfile', '-File', ('"' + $script:regPs1 + '"'), '-Arquivo', ('"' + $fb + '"'), '-Canal', 'cross-claude', '-Repo', ('"' + $repo + '"')) -PassThru -WindowStyle Hidden
            $pa.WaitForExit(); $pb.WaitForExit()
            @($pa.ExitCode, $pb.ExitCode) | ForEach-Object { $_ | Should -BeIn @(0, 3) }
            $rev = Join-Path (Join-Path $repo '.deepseek') 'reviews'
            foreach ($m in @(Get-ChildItem $rev -File -Filter '*.jsonl')) {
                $j = [IO.File]::ReadAllText($m.FullName, $script:u8) | ConvertFrom-Json
                $j.findings | Should -BeIn @(("A" * 50000), ("B" * 50000))
            }
            @(Get-ChildItem $rev -File -Filter '*.tmp').Count | Should -Be 0
        }
    }

    It "SC-006: hash identico entre .ps1 e .sh num diff com acentos" {
        $repo = New-RepoReg
        $f = New-Findings
        $a = Invoke-Registro -Rt 'ps1' -Repo $repo -Arquivo $f
        $b = Invoke-Registro -Rt 'sh' -Repo $repo -Arquivo $f
        $a.Code | Should -Be 0 -Because $a.Err
        $b.Code | Should -Be 0 -Because $b.Err
        ($a.Out -replace '^hash=([0-9a-f]{12}) .*$', '$1') | Should -BeExactly ($b.Out -replace '^hash=([0-9a-f]{12}) .*$', '$1')
        ($a.Out -replace '^hash=([0-9a-f]{12}) .*$', '$1') | Should -BeExactly (Get-DiffHash $repo).Hash
    }

    It "SC-006: registro Cross-Claude + latest.jsonl com 60 min -> o hook <Camada> libera pelo hash" -ForEach @(@{ Camada = 'ps1' }, @{ Camada = 'sh' }) {
        $repo = New-RepoReg
        Push-Location $repo
        try { & git add a.ps1 2>$null } finally { Pop-Location }
        $r = Invoke-Registro -Rt 'ps1' -Repo $repo -Arquivo (New-Findings -Texto "[SEV: risco] revisado pelo subagente`n")
        $r.Code | Should -Be 0 -Because $r.Err
        (Get-Item (Join-Path $r.Rev 'latest.jsonl')).LastWriteTime = (Get-Date).AddMinutes(-60)
        $payload = @{ tool_name = 'Bash'; tool_input = @{ command = ('cd "' + (ConvertTo-CaminhoBash $repo) + '" && git com' + 'mit -m x') } } | ConvertTo-Json -Compress
        if ($Camada -eq 'ps1') { $payload | & pwsh -NoProfile -File $script:hookPs1 *>$null }
        else { $payload | & $script:bash $script:hookSh *>$null }
        $LASTEXITCODE | Should -Be 0 -Because "a review registrada cobre exatamente este diff; o relogio e irrelevante"
    }

    It "powershell.exe (Windows PowerShell 5.1): sucesso grava d-<hash> e latest, hash igual ao Get-DiffHash" {
        if (-not (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"
            return
        }
        $repo = New-RepoReg
        $esperado = Get-DiffHash $repo
        $texto = "[SEV: bug] revisado via Windows PowerShell 5.1`n"
        $f = New-Findings -Texto $texto
        $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
        Push-Location $repo
        try {
            $out = & powershell.exe -NoProfile -File $script:regPs1 -Arquivo $f -Canal 'cross-claude' -Modelo 'claude-sonnet-5' 2>$err
            $code = $LASTEXITCODE
        } finally { Pop-Location }
        $texto2 = ''; if (Test-Path $err) { $texto2 = [IO.File]::ReadAllText($err, $script:u8) }
        $code | Should -Be 0 -Because $texto2
        $outStr = (@($out) -join "`n").Trim()
        $outStr | Should -Match ('^hash=' + $esperado.Hash + ' latest=\S.*latest\.jsonl d=\S.*d-' + $esperado.Hash + '\.jsonl$')
        $rev = Join-Path (Join-Path $repo '.deepseek') 'reviews'
        foreach ($nome in @('latest.jsonl', "d-$($esperado.Hash).jsonl")) {
            $j = [IO.File]::ReadAllText((Join-Path $rev $nome), $script:u8) | ConvertFrom-Json
            $j.canal      | Should -Be 'cross-claude'
            $j.model      | Should -Be 'claude-sonnet-5'
            $j.findings   | Should -BeExactly $texto
            $j.diff_lines | Should -Be $esperado.Linhas
        }
    }
}
