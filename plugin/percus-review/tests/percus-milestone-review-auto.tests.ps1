#requires -Version 5.1
# F-e: percus-milestone-review-auto.* usava um motivo fixo ("DeepSeek falhou ...
# provavel outage") sem causa por codigo de saida e sem nunca oferecer a linha do
# registrar-review. Este teste roda o wrapper real de marco contra um plugin
# percus-review falso (mesma fabrica de percus-review-auto-registro.tests.ps1) e um
# repositorio git temporario de verdade, pra controlar "arvore com diff" x "arvore
# limpa" (git diff HEAD --quiet).

BeforeDiscovery {
    $script:casosMilestone = @(
        @{ DsExit = 4; ArvoreLimpa = $false; Motivo = 'retry';  EsperaRegistrar = $true  }
        @{ DsExit = 3; ArvoreLimpa = $true;  Motivo = 'exit3';  EsperaRegistrar = $false }
        @{ DsExit = 1; ArvoreLimpa = $false; Motivo = 'exit1';  EsperaRegistrar = $true  }
        @{ DsExit = 0; ArvoreLimpa = $false; Motivo = '';       EsperaRegistrar = $true  }
    )
}

Describe "percus-milestone-review-auto -- causa por codigo e linha do registrar" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        . (Join-Path $PSScriptRoot '_plugin-review-falso.ps1')
        $kit = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
        $kit = Split-Path $kit -Parent
        $script:wrapPs1 = Join-Path (Join-Path $kit 'scripts') 'percus-milestone-review-auto.ps1'
        $script:wrapSh  = ConvertTo-CaminhoBash (Join-Path (Join-Path $kit 'scripts') 'percus-milestone-review-auto.sh')
        $script:bash = Get-BashGit
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-marco-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $script:textoRetry = 'provedor indispon' + [char]0x00ED + 'vel ap' + [char]0x00F3 + 's retry'
        $script:textoRespostaInutil = 'resposta inutiliz' + [char]0x00E1 + 'vel do DeepSeek'
        $script:textoNaoRecuperavel = 'erro n' + [char]0x00E3 + 'o recuper' + [char]0x00E1 + 'vel do DeepSeek'

        function New-RepoGitMarco {
            $dir = Join-Path $script:tmpBase ("repo-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $bashDir = ConvertTo-CaminhoBash $dir
            & $script:bash -c ("cd '$bashDir' && git init -q -b main && git config user.email t@t.com && git config user.name teste") | Out-Null
            [IO.File]::WriteAllText((Join-Path $dir 'a.txt'), "linha1`n", $script:u8)
            & $script:bash -c ("cd '$bashDir' && git add a.txt && git " + ('com' + 'mit') + " -q -m inicial") | Out-Null
            return $dir
        }

        function Invoke-WrapperMarco {
            param([ValidateSet('ps1', 'sh')][string]$Rt, $Plugin, [int]$DsExit, [bool]$ArvoreLimpa)
            $repo = New-RepoGitMarco
            if (-not $ArvoreLimpa) {
                [IO.File]::WriteAllText((Join-Path $repo 'a.txt'), "linha1`nlinha2`n", $script:u8)
            }
            $cfg = $Plugin.Cfg
            if ($Rt -eq 'sh') { $cfg = ConvertTo-CaminhoBash $cfg }
            $antigos = Set-EnvTemporario @{ CLAUDE_CONFIG_DIR = $cfg; FAKE_DS_EXIT = "$DsExit" }
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            Push-Location $repo
            try {
                if ($Rt -eq 'ps1') { $null = & pwsh -NoProfile -File $script:wrapPs1 -Base 'base-fake' 2>$err }
                else { $null = & $script:bash -c ("cd '" + (ConvertTo-CaminhoBash $repo) + "' && bash '" + $script:wrapSh + "' --base base-fake") 2>$err }
                $code = $LASTEXITCODE
            } finally { Pop-Location; Restore-EnvTemporario $antigos }
            $texto = ''; if (Test-Path $err) { $texto = [IO.File]::ReadAllText($err, $script:u8) }
            $latest = Join-Path (Join-Path (Join-Path $repo '.deepseek') 'reviews') 'latest.jsonl'
            $ph = $null
            if (Test-Path $latest) { $ph = [IO.File]::ReadAllText($latest, $script:u8).TrimStart([char]0xFEFF) | ConvertFrom-Json }
            $marcas = @($texto -split "`r?`n" | Where-Object { $_ -like '__PERCUS_NEEDS_CROSS_CLAUDE__*' })
            return [pscustomobject]@{ Code = $code; Err = $texto; Placeholder = $ph; Marcas = $marcas }
        }
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "<Rt> | deepseek exit <DsExit> | arvore limpa=<ArvoreLimpa>" -ForEach @(
        foreach ($c in $script:casosMilestone) { foreach ($rt in @('ps1', 'sh')) { $x = $c.Clone(); $x.Rt = $rt; $x } }
    ) {
        $pl = New-PluginFalso -TmpBase $script:tmpBase
        $r = Invoke-WrapperMarco -Rt $Rt -Plugin $pl -DsExit $DsExit -ArvoreLimpa $ArvoreLimpa
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Marcas.Count | Should -BeGreaterThan 0 -Because "marco e sempre dual, sempre pede o subagente. stderr: $($r.Err)"

        if ($DsExit -ne 0) {
            $r.Placeholder | Should -Not -BeNullOrEmpty
            $r.Placeholder.deferred | Should -BeTrue
            if ($Motivo -eq 'retry') { $r.Placeholder.reason | Should -Match ([regex]::Escape($script:textoRetry)) }
            if ($Motivo -eq 'exit3') { $r.Placeholder.reason | Should -Match ([regex]::Escape($script:textoRespostaInutil)) }
            if ($Motivo -eq 'exit1') {
                $r.Placeholder.reason | Should -Match ([regex]::Escape($script:textoNaoRecuperavel))
                $r.Placeholder.reason | Should -Match '\(exit 1\)'
            }
            $r.Placeholder.reason | Should -Not -Match 'outage'
        } else {
            $r.Placeholder | Should -BeNullOrEmpty
        }

        if ($EsperaRegistrar) {
            foreach ($m in $r.Marcas) { $m | Should -Match 'registrar-review' }
        } else {
            foreach ($m in $r.Marcas) {
                $m | Should -Not -Match 'registrar-review'
                $m | Should -Match ([regex]::Escape('Marco sem diff pendente'))
            }
        }
    }
}
