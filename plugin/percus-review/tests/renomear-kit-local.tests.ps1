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

        # Variavel de ambiente de usuario descartavel. Escreve/apaga direto no HKCU de
        # proposito: [Environment]::SetEnvironmentVariable dispara WM_SETTINGCHANGE e
        # custa ~7s por chamada, e (medido em 2026-07-30) passar $null NAO remove a
        # chave -- deixa valor vazio sujando o registro do usuario. O script de verdade
        # continua usando a API .NET; aqui e so cenario.
        function New-VarTeste {
            param([string]$Valor)
            $nome = "PERCUS_TESTE_" + [Guid]::NewGuid().ToString("N").Substring(0,8)
            New-ItemProperty -Path "HKCU:\Environment" -Name $nome -Value $Valor -PropertyType String -Force | Out-Null
            return $nome
        }
        function Remove-VarTeste {
            param([string]$Nome)
            Remove-ItemProperty -Path "HKCU:\Environment" -Name $Nome -ErrorAction SilentlyContinue
        }

        # Projeto irmao da pasta do kit, com o path do kit hardcodado num hook -- e a
        # forma real medida nos 4 projetos desta maquina.
        function New-Vizinho {
            param([string]$Base, [string]$Nome, [string]$PathKit)
            $dir = Join-Path $Base "$Nome\.claude"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $f = Join-Path $dir "settings.local.json"
            $conteudo = @{ permissions = @{ allow = @(
                ('Bash(pwsh -File "' + ($PathKit -replace '\\','/') + '/scripts/percus-review-auto.ps1")')
            ) } } | ConvertTo-Json -Depth 10
            [IO.File]::WriteAllText($f, $conteudo, (New-Object System.Text.UTF8Encoding($false)))
            return $f
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

    It "NAO deixa o -NomeNovo ser interpretado como substituicao de regex" {
        # '$&' na string de substituicao do [regex]::Replace significa "a match inteira".
        # Com o nome novo entrando cru, 'percus$&kit' viraria 'percus_Novo_Projetokit'
        # dentro do settings -- path corrompido em silencio. '$' e '&' sao caracteres
        # legais em nome de pasta no Windows, entao isso e alcancavel.
        $c = New-Cenario
        $nome = 'percus$&kit'
        & $script:script -KitAtual $c.Antigo -NomeNovo $nome -SettingsPath $c.Settings
        $depois = Get-Content $c.Settings -Raw -Encoding UTF8
        $depois | Should -Match ([regex]::Escape($nome))
        $depois | Should -Not -Match '_Novo_Projeto'
        Test-Path (Join-Path $c.Base $nome) | Should -Be $true
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

    # --- variaveis de ambiente de USUARIO --------------------------------------------
    # Medido em 2026-07-30: nesta maquina os ponteiros do kit sao DUAS env var de usuario
    # (HKCU) e nenhuma esta no settings.json -- PERCUS_CANON_DIR (a pasta) e
    # PERCUS_CANON_V2_DIR (pasta\v2). Consertar so o settings deixaria toda sessao nova
    # apontando pro caminho morto. O script so mexe em segmento que E a pasta renomeada
    # ou esta DENTRO dela, entao as variaveis reais da maquina (que apontam pra outro
    # caminho) nunca entram em jogo -- e os testes usam nome descartavel como 2a tranca.
    It "conserta TODAS as variaveis de usuario que apontam pra pasta renomeada, inclusive as que apontam pra DENTRO dela" {
        $c   = New-Cenario
        $vA  = New-VarTeste -Valor $c.Antigo
        # Forma com barra normal, apontando pra subpasta: e o caso do PERCUS_CANON_V2_DIR.
        $vB  = New-VarTeste -Valor (($c.Antigo -replace '\\','/') + "/v2")
        try {
            & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
            [Environment]::GetEnvironmentVariable($vA, 'User') | Should -Be $c.Novo
            [Environment]::GetEnvironmentVariable($vB, 'User') |
                Should -Be (($c.Novo -replace '\\','/') + "/v2") -Because "so o nome da pasta muda; a subpasta e a forma do path (barra) tem que sobreviver"
        } finally { Remove-VarTeste $vA; Remove-VarTeste $vB }
    }

    It "NAO mexe em variavel de usuario que aponta pra OUTRA pasta" {
        $c = New-Cenario
        $outra = Join-Path $c.Base "_Novo_Projeto_de_outra_maquina"
        $var = New-VarTeste -Valor $outra
        try {
            & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
            [Environment]::GetEnvironmentVariable($var, 'User') | Should -Be $outra -Because "cita o nome antigo mas nao e a pasta renomeada -- reescrever seria estragar a config de outra coisa"
        } finally { Remove-VarTeste $var }
    }

    It "em variavel com LISTA, troca so o segmento do kit e preserva os outros" {
        $c = New-Cenario
        $lista = "C:\Windows;" + (Join-Path $c.Antigo "scripts") + ";C:\OutroLugar"
        $var = New-VarTeste -Valor $lista
        try {
            & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
            [Environment]::GetEnvironmentVariable($var, 'User') |
                Should -Be ("C:\Windows;" + (Join-Path $c.Novo "scripts") + ";C:\OutroLugar") -Because "estragar o PATH da maquina por causa de um segmento seria pior que o bug original"
        } finally { Remove-VarTeste $var }
    }

    It "rollback devolve TAMBEM a variavel de ambiente ao valor antigo" {
        $c = New-Cenario
        $var = New-VarTeste -Valor $c.Antigo
        Set-ItemProperty -Path $c.Settings -Name IsReadOnly -Value $true
        try {
            $erro = $null
            try { & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings } catch { $erro = $_.Exception.Message }
            [Environment]::GetEnvironmentVariable($var, 'User') | Should -Be $c.Antigo -Because "a pasta voltou ao nome antigo, a variavel tem que voltar com ela"
            $erro | Should -Match ([regex]::Escape($var)) -Because "o operador precisa saber que a variavel foi desfeita, nao deduzir"
            Test-Path $c.Antigo | Should -Be $true
        } finally {
            Remove-VarTeste $var
            Set-ItemProperty -Path $c.Settings -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
        }
    }

    # --- settings de projetos vizinhos -----------------------------------------------
    # Medido em 2026-07-30: 4 projetos irmaos da pasta do kit hardcodam o path dele nos
    # proprios .claude/settings*.json (11 ocorrencias, todas hook de review). Depois do
    # rename, apontariam pro nada.
    It "conserta os settings de projetos vizinhos que hardcodam o path do kit" {
        $c = New-Cenario
        $vf = New-Vizinho -Base $c.Base -Nome "a-vizinho" -PathKit $c.Antigo
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        $depois = Get-Content $vf -Raw -Encoding UTF8
        $depois | Should -Match 'percus-kit'
        $depois | Should -Not -Match '_Novo_Projeto'
        { $depois | ConvertFrom-Json } | Should -Not -Throw
    }

    It "NAO mexe em arquivo DENTRO da pasta do kit (e versionado; sujaria o git status)" {
        $c = New-Cenario
        New-Item -ItemType Directory -Path (Join-Path $c.Antigo ".claude") -Force | Out-Null
        $doKit = Join-Path $c.Antigo ".claude\settings.json"
        [IO.File]::WriteAllText($doKit, ('{ "x": "' + ($c.Antigo -replace '\\','/') + '/scripts/y.ps1" }'), (New-Object System.Text.UTF8Encoding($false)))
        & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings
        (Get-Content (Join-Path $c.Novo ".claude\settings.json") -Raw -Encoding UTF8) |
            Should -Match '_Novo_Projeto' -Because "o gate do Task 6 cuida do que esta dentro do kit; o script mexendo ai geraria diff no repo"
    }

    It "rollback restaura o settings de vizinho que JA tinha sido reescrito" {
        # 'a-vizinho' e reescrito com sucesso; 'z-vizinho' estoura no backup (ACL). O
        # rollback tem que devolver a-vizinho, o settings principal e o nome da pasta.
        $c  = New-Cenario
        $va = New-Vizinho -Base $c.Base -Nome "a-vizinho" -PathKit $c.Antigo
        $vz = New-Vizinho -Base $c.Base -Nome "z-vizinho" -PathKit $c.Antigo
        $dirZ = Split-Path $vz -Parent

        $acl  = Get-Acl $dirZ
        $eu   = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $nega = New-Object Security.AccessControl.FileSystemAccessRule($eu, "CreateFiles", "Deny")
        $acl.AddAccessRule($nega); Set-Acl -Path $dirZ -AclObject $acl
        try {
            $erro = $null
            try { & $script:script -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings } catch { $erro = $_.Exception.Message }
            $erro | Should -Match 'ROLLBACK OK'
            (Get-Content $va -Raw -Encoding UTF8) | Should -Match '_Novo_Projeto' -Because "vizinho ja reescrito tem que voltar do backup"
            (Get-Content $va -Raw -Encoding UTF8) | Should -Not -Match 'percus-kit'
            (Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json).env.PERCUS_CANON_DIR | Should -Be $c.Antigo
            Test-Path $c.Antigo | Should -Be $true
            Test-Path $c.Novo   | Should -Be $false
        } finally {
            $a2 = Get-Acl $dirZ; $a2.RemoveAccessRule($nega) | Out-Null; Set-Acl -Path $dirZ -AclObject $a2
        }
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
            $erro | Should -Match 'restaurad' -Because "a escrita pode ter saido parcial, entao o rollback tem que devolver o arquivo do backup -- nao so avisar"
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

    # --- compatibilidade com Windows PowerShell 5.1 -----------------------------------
    # Este e o unico script do kit que o OPERADOR roda a mao, e o terminal padrao do
    # Windows e o 5.1 -- que le .ps1 sem BOM como ANSI. Em 2026-07-30 o script quebrou na
    # mao do operador com 7 erros de parse: um em dash (U+2014) num comentario virava
    # aspa curva em ANSI, e o PowerShell aceita aspa curva como delimitador de string.
    # A suite roda em pwsh 7, entao nada disso aparecia aqui. Por isso este teste invoca
    # o powershell.exe DE VERDADE em vez de conferir a lista de caracteres: inspecao de
    # bytes provaria uma causa, e o que precisa ser provado e que o artefato roda.
    It "roda sob Windows PowerShell 5.1 (o terminal do operador), nao so em pwsh 7" {
        $ps51 = Get-Command powershell.exe -ErrorAction SilentlyContinue
        if (-not $ps51) { Set-ItResult -Skipped -Because "powershell.exe (5.1) nao existe nesta maquina" ; return }

        $c = New-Cenario
        $saida = & $ps51.Source -NoProfile -ExecutionPolicy Bypass -File $script:script `
                    -KitAtual $c.Antigo -NomeNovo "percus-kit" -SettingsPath $c.Settings 2>&1
        $texto = ($saida | Out-String)

        # 'ParserError' e o nome do enum de CategoryInfo, igual em qualquer idioma de
        # Windows. Nao afiro a frase do erro: ela e traduzida, e o teste passaria a
        # depender do idioma da maquina.
        $texto | Should -Not -Match 'ParserError' -Because "erro de parse no 5.1 e o que quebrou na mao do operador: $texto"
        $LASTEXITCODE | Should -Be 0 -Because $texto
        Test-Path $c.Novo   | Should -Be $true  -Because "nao basta parsear: tem que renomear. Saida: $texto"
        Test-Path $c.Antigo | Should -Be $false
        (Get-Content $c.Settings -Raw -Encoding UTF8 | ConvertFrom-Json).env.PERCUS_CANON_DIR | Should -Be $c.Novo
    }

    It "recusa -KitAtual sem pasta pai, com mensagem util" {
        { & $script:script -KitAtual "D:" -NomeNovo "percus-kit" -SettingsPath "$env:TEMP\nao-existe-$([Guid]::NewGuid().ToString('N')).json" } |
            Should -Throw -ExpectedMessage "*pasta pai*"
    }
}
