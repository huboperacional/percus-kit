#requires -Version 5.1
# O script de rename mexe no settings.json do usuario. O teste NUNCA toca o real:
# monta um par (pasta falsa + settings falso) e afere o resultado.

Describe "renomear-kit-local.ps1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\renomear-kit-local.ps1"
        $script:temps   = New-Object System.Collections.ArrayList

        function New-Cenario {
            $base = Join-Path ([IO.Path]::GetTempPath()) ("percus-ren-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path (Join-Path $base "_Novo_Projeto") -Force | Out-Null
            $settings = @{
                env = @{ PERCUS_CANON_DIR = (Join-Path $base "_Novo_Projeto") }
                permissions = @{ allow = @(
                    ('Bash(pwsh -File "' + (Join-Path $base "_Novo_Projeto") + '/scripts/percus-review-auto.ps1")')
                ) }
            } | ConvertTo-Json -Depth 10
            $sp = Join-Path $base "settings.json"
            [IO.File]::WriteAllText($sp, $settings, (New-Object System.Text.UTF8Encoding($false)))
            [void]$script:temps.Add($base)
            return [pscustomobject]@{ Base = $base; Settings = $sp; Antigo = (Join-Path $base "_Novo_Projeto"); Novo = (Join-Path $base "percus-kit") }
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "renomeia a pasta e reescreve PERCUS_CANON_DIR" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        Test-Path $c.Novo | Should -Be $true
        Test-Path $c.Antigo | Should -Be $false
        (Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json).env.PERCUS_CANON_DIR | Should -Be $c.Novo
    }

    It "reescreve tambem as entradas de permissao que hardcodam o path" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        $j = Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json
        ($j.permissions.allow -join " ") | Should -Not -Match '_Novo_Projeto'
        ($j.permissions.allow -join " ") | Should -Match 'percus-kit'
    }

    It "deixa o settings.json VALIDO (JSON quebrado derruba todos os hooks calado)" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        { Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json } | Should -Not -Throw
    }

    It "faz backup datado do settings antes de mexer" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        @(Get-ChildItem (Split-Path $c.Settings) -Filter "settings.json.bak-*").Count | Should -BeGreaterThan 0
    }

    It "NAO troca o nome no MEIO de um token maior" {
        $c = New-Cenario
        $j = Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $j.permissions.allow += 'Bash(echo backup_Novo_Projeto_old)'
        [IO.File]::WriteAllText($c.Settings, ($j | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        (Get-Content $c.Settings -Raw -Encoding UTF8) | Should -Match 'backup_Novo_Projeto_old' -Because "so path e alvo; substring dentro de token nao"
    }

    It "NAO corrompe mencao a _Novo_Projeto_V2 (o nome antigo e prefixo dela)" {
        $c = New-Cenario
        $j = Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json
        $j.permissions.allow += ('Read(' + (Join-Path $c.Base "_Novo_Projeto_V2") + '/**)')
        [IO.File]::WriteAllText($c.Settings, ($j | ConvertTo-Json -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        $depois = Get-Content $c.Settings -Raw -Encoding UTF8
        $depois | Should -Match '_Novo_Projeto_V2' -Because "a pasta avulsa nao e alvo deste rename"
        $depois | Should -Not -Match 'percus-kit_V2' -Because "prefixo trocado no meio da palavra corrompe o path"
    }

    It "e idempotente: rodar de novo com a pasta ja renomeada nao quebra nem duplica" {
        $c = New-Cenario
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        { & $script:script -KitAtual $c.Novo -NomeNovo "percus-kit" -SettingsPath $c.Settings } | Should -Not -Throw
        (Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json).env.PERCUS_CANON_DIR | Should -Be $c.Novo
    }

    It "com settings JA invalido, aborta SEM renomear a pasta" {
        $c = New-Cenario
        [IO.File]::WriteAllText($c.Settings, '{ "env": { QUEBRADO', (New-Object System.Text.UTF8Encoding($false)))
        { & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings } | Should -Throw
        Test-Path $c.Antigo | Should -Be $true  -Because "a pasta nao pode ser renomeada se o settings nem pode ser consertado depois"
        Test-Path $c.Novo   | Should -Be $false
    }

    It "falha na ESCRITA final: faz rollback e a pasta volta ao nome antigo" {
        # Somente-leitura no settings: Copy-Item (backup) passa, Get-Content passa,
        # WriteAllText estoura. Sem rollback, a pasta ficaria renomeada com
        # PERCUS_CANON_DIR apontando pro caminho morto.
        $c = New-Cenario
        Set-ItemProperty -Path $c.Settings -Name IsReadOnly -Value $true
        try {
            $erro = $null
            try { & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings } catch { $erro = $_.Exception.Message }
            $erro | Should -Match 'ROLLBACK OK'
            $erro | Should -Match 'NAO apague' -Because "se a escrita pode ter saido parcial, o backup e a unica copia boa -- mandar apagar seria armadilha"
            Test-Path $c.Antigo | Should -Be $true  -Because "o rollback tem que devolver a pasta ao nome antigo"
            Test-Path $c.Novo   | Should -Be $false
            (Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json).env.PERCUS_CANON_DIR |
                Should -Be $c.Antigo -Because "a escrita falhou, o settings tem que estar intacto"
        } finally {
            Set-ItemProperty -Path $c.Settings -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        }
    }

    It "falha no BACKUP: faz rollback e a pasta volta ao nome antigo" {
        # Nega CREATE FILES na pasta do settings (nao na pasta pai do kit, pra que a ACL
        # nao interfira no rename nem no rollback). Copy-Item do .bak estoura; leitura do
        # settings continua permitida.
        $c = New-Cenario
        $cfg = Join-Path $c.Base "cfg"
        New-Item -ItemType Directory -Path $cfg -Force | Out-Null
        Copy-Item $c.Settings (Join-Path $cfg "settings.json")
        $sp = Join-Path $cfg "settings.json"

        $acl  = Get-Acl $cfg
        $eu   = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $nega = New-Object Security.AccessControl.FileSystemAccessRule($eu, "CreateFiles", "Deny")
        $acl.AddAccessRule($nega); Set-Acl -Path $cfg -AclObject $acl
        try {
            { & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $sp } |
                Should -Throw -ExpectedMessage "*ROLLBACK OK*"
            Test-Path $c.Antigo | Should -Be $true  -Because "o rollback tem que devolver a pasta ao nome antigo"
            Test-Path $c.Novo   | Should -Be $false
        } finally {
            $a2 = Get-Acl $cfg; $a2.RemoveAccessRule($nega) | Out-Null; Set-Acl -Path $cfg -AclObject $a2
        }
    }

    It "recusa -KitAtual sem pasta pai, com mensagem util" {
        { & $script:script -KitAtual "D:" -NomeNovo "percus-kit" -SettingsPath "$env:TEMP\nao-existe-$([Guid]::NewGuid().ToString('N')).json" } |
            Should -Throw -ExpectedMessage "*pasta pai*"
    }
}
