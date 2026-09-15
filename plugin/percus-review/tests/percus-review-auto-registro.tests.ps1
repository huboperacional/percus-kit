#requires -Version 5.1
# FR-007/008: com a DeepSeek fora, o wrapper pedia o subagente mas nao dizia como registrar a review
# dele. Aqui o wrapper real roda contra um plugin falso: router devolve a rota pedida, cliente sai
# com o exit pedido, e o teste le o placeholder e cada linha de marcador.

BeforeDiscovery {
    $script:casosPs1 = @(
        @{ Decisao = 'deepseek';     DsExit = 4; Placeholder = $true;  Motivo = 'retry' }
        @{ Decisao = 'deepseek';     DsExit = 1; Placeholder = $true;  Motivo = 'exit1' }
        @{ Decisao = 'dual';         DsExit = 4; Placeholder = $true;  Motivo = 'retry' }
        @{ Decisao = 'dual';         DsExit = 0; Placeholder = $false; Motivo = '' }
        @{ Decisao = 'council';      DsExit = 4; Placeholder = $true;  Motivo = 'retry' }
        @{ Decisao = 'cross-claude'; DsExit = 0; Placeholder = $true;  Motivo = '' }
    )
}

Describe "percus-review-auto -- exit 4 e instrucao de registro" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        $kit = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
        $kit = Split-Path $kit -Parent
        $script:wrapPs1 = Join-Path (Join-Path $kit 'scripts') 'percus-review-auto.ps1'
        $script:wrapSh  = ConvertTo-CaminhoBash (Join-Path (Join-Path $kit 'scripts') 'percus-review-auto.sh')
        $script:registrarKitPs1 = Join-Path (Join-Path (Join-Path (Join-Path $kit 'plugin') 'percus-review') 'scripts') 'registrar-review.ps1'
        $script:bash = Get-BashGit
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:u8bom = New-Object System.Text.UTF8Encoding($true)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-auto-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $script:textoRetry = 'provedor indispon' + [char]0x00ED + 'vel ap' + [char]0x00F3 + 's retry'

        function New-PluginFalso {
            param([switch]$SemRegistrar)
            $cfg = Join-Path $script:tmpBase ("cfg-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            $ver = $cfg
            foreach ($p in @('plugins', 'cache', 'percus-tools', 'percus-review', '9.9.9', 'scripts')) { $ver = Join-Path $ver $p }
            New-Item -ItemType Directory -Force -Path $ver | Out-Null
            [IO.File]::WriteAllText((Join-Path (Split-Path $ver -Parent) 'plugin.json'), '{"version":"9.9.9"}', $script:u8)
            [IO.File]::WriteAllText((Join-Path $ver 'review-router.ps1'), "param([switch]`$Json, [string]`$Base)`nWrite-Output `$env:FAKE_ROUTER_JSON`n", $script:u8bom)
            [IO.File]::WriteAllText((Join-Path $ver 'deepseek-review.ps1'), "param([string]`$Base)`n[Console]::Error.WriteLine('[deepseek-review] tentativa 1 falhou: HTTP 503. Nova tentativa em 1s.')`nWrite-Output 'Sem findings criticos.'`nexit ([int]`$env:FAKE_DS_EXIT)`n", $script:u8bom)
            [IO.File]::WriteAllText((Join-Path $ver 'review-router.sh'), "#!/usr/bin/env bash`nprintf '%s\n' `"`$FAKE_ROUTER_JSON`"`n", $script:u8)
            [IO.File]::WriteAllText((Join-Path $ver 'deepseek-review.sh'), "#!/usr/bin/env bash`necho '[deepseek-review] tentativa 1 falhou: HTTP 503. Nova tentativa em 1s.' >&2`necho 'Sem findings criticos.'`nexit `"`${FAKE_DS_EXIT:-0}`"`n", $script:u8)
            if (-not $SemRegistrar) {
                [IO.File]::WriteAllText((Join-Path $ver 'registrar-review.ps1'), "# falso`n", $script:u8bom)
                [IO.File]::WriteAllText((Join-Path $ver 'registrar-review.sh'), "#!/usr/bin/env bash`n", $script:u8)
            }
            return [pscustomobject]@{ Cfg = $cfg; Scripts = $ver }
        }

        function Invoke-Wrapper {
            param([ValidateSet('ps1','sh')][string]$Rt, $Plugin, [string]$Decisao, [int]$DsExit, [string]$PsHost = 'pwsh')
            $cwd = Join-Path $script:tmpBase ("w-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Force -Path $cwd | Out-Null
            $router = '{"decision":"' + $Decisao + '","sensitive":true,"from_deepseek":false,"files_count":1,"warnings":[]}'
            $cfg = $Plugin.Cfg
            if ($Rt -eq 'sh') { $cfg = ConvertTo-CaminhoBash $cfg }
            $antigos = Set-EnvTemporario @{ CLAUDE_CONFIG_DIR = $cfg; FAKE_ROUTER_JSON = $router; FAKE_DS_EXIT = "$DsExit" }
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            Push-Location $cwd
            try {
                if ($Rt -eq 'ps1') { $null = & $PsHost -NoProfile -File $script:wrapPs1 -NoFactCheck 2>$err }
                else { $null = & $script:bash -c ("cd '" + (ConvertTo-CaminhoBash $cwd) + "' && bash '" + $script:wrapSh + "' --no-fact-check") 2>$err }
                $code = $LASTEXITCODE
            } finally { Pop-Location; Restore-EnvTemporario $antigos }
            $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            $latest = Join-Path (Join-Path (Join-Path $cwd '.deepseek') 'reviews') 'latest.jsonl'
            $ph = $null
            if (Test-Path $latest) { $ph = [IO.File]::ReadAllText($latest, $script:u8).TrimStart([char]0xFEFF) | ConvertFrom-Json }
            $marcas = @($texto -split "`r?`n" | Where-Object { $_ -like '__PERCUS_NEEDS_CROSS_CLAUDE__*' })
            return [pscustomobject]@{ Code = $code; Err = $texto; Placeholder = $ph; Marcas = $marcas }
        }
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "<Rt> | decision=<Decisao> | deepseek exit <DsExit>" -ForEach @(
        foreach ($c in $script:casosPs1) { foreach ($rt in @('ps1', 'sh')) { $x = $c.Clone(); $x.Rt = $rt; $x } }
    ) {
        $pl = New-PluginFalso
        $r = Invoke-Wrapper -Rt $Rt -Plugin $pl -Decisao $Decisao -DsExit $DsExit
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Marcas.Count | Should -BeGreaterThan 0 -Because "toda rota desta tabela pede o subagente. stderr: $($r.Err)"
        $ext = $Rt
        $caminho = Join-Path $pl.Scripts ("registrar-review." + $ext)
        if ($Rt -eq 'sh') { $caminho = ConvertTo-CaminhoBash $caminho }
        $flag = '-Canal cross-claude'; if ($Rt -eq 'sh') { $flag = '--canal cross-claude' }
        $forado = 'FORA do repo'
        $viaBash = 'pwsh -NoProfile -File'; if ($Rt -eq 'sh') { $viaBash = $null }
        foreach ($m in $r.Marcas) {
            $m | Should -Match 'registrar-review'
            $m.Contains($caminho) | Should -BeTrue -Because "caminho absoluto '$caminho' ausente em: $m"
            $m.Contains($flag) | Should -BeTrue
            $m.Contains($forado) | Should -BeTrue -Because "instrucao deve dizer para gravar os findings fora do repo (senao muda o git diff HEAD): $m"
            if ($viaBash) { $m.Contains($viaBash) | Should -BeTrue -Because "instrucao ps1 deve citar a chamada via ferramenta Bash: $m" }
        }
        if ($Placeholder) {
            $r.Placeholder | Should -Not -BeNullOrEmpty
            $r.Placeholder.deferred | Should -BeTrue
            if ($Motivo -eq 'retry') { $r.Placeholder.reason | Should -Match ([regex]::Escape($script:textoRetry)) }
            if ($Motivo -eq 'exit1') { $r.Placeholder.reason | Should -Match '\(exit 1\)' }
        } else {
            $r.Placeholder | Should -BeNullOrEmpty
        }
        if ($Decisao -ne 'cross-claude') {
            $r.Err | Should -Match 'tentativa 1 falhou' -Because "o aviso de retry do cliente tem de chegar a quem roda o wrapper"
        }
    }

    It "ps1 sob powershell.exe (5.1) | decision=deepseek | deepseek exit 4" {
        $ph = Get-Command powershell.exe -ErrorAction SilentlyContinue
        if (-not $ph) {
            Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"
            return
        }
        $pl = New-PluginFalso
        $r = Invoke-Wrapper -Rt 'ps1' -Plugin $pl -Decisao 'deepseek' -DsExit 4 -PsHost 'powershell.exe'
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Marcas.Count | Should -BeGreaterThan 0 -Because "toda rota desta tabela pede o subagente. stderr: $($r.Err)"
        $caminho = Join-Path $pl.Scripts 'registrar-review.ps1'
        foreach ($m in $r.Marcas) {
            $m | Should -Match 'registrar-review'
            $m.Contains($caminho) | Should -BeTrue -Because "caminho absoluto '$caminho' ausente em: $m"
            $m.Contains('-Canal cross-claude') | Should -BeTrue
            $m.Contains('FORA do repo') | Should -BeTrue -Because "instrucao deve dizer para gravar os findings fora do repo: $m"
            $m.Contains('pwsh -NoProfile -File') | Should -BeTrue -Because "instrucao ps1 deve citar a chamada via ferramenta Bash: $m"
        }
        $r.Placeholder | Should -Not -BeNullOrEmpty
        $r.Placeholder.deferred | Should -BeTrue
        $r.Placeholder.reason | Should -Match ([regex]::Escape($script:textoRetry))
        $r.Err | Should -Match 'tentativa 1 falhou' -Because "o aviso de retry do cliente tem de chegar a quem roda o wrapper"
    }

    It "<Rt>: plugin instalado sem registrar-review -> marcador aponta a copia do kit" -ForEach @(@{ Rt = 'ps1' }, @{ Rt = 'sh' }) {
        $pl = New-PluginFalso -SemRegistrar
        $r = Invoke-Wrapper -Rt $Rt -Plugin $pl -Decisao 'cross-claude' -DsExit 0
        $esperado = $script:registrarKitPs1
        if ($Rt -eq 'sh') { $esperado = ConvertTo-CaminhoBash ([IO.Path]::ChangeExtension($script:registrarKitPs1, '.sh')) }
        $r.Marcas.Count | Should -BeGreaterThan 0
        foreach ($m in $r.Marcas) { $m.Contains($esperado) | Should -BeTrue -Because "esperado '$esperado' em: $m" }
    }
}
