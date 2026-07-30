#requires -Version 5.1
# O .cmd e a fronteira entre o harness e a guarda. O harness NAO le "nao-zero": ele le tres
# faixas de exit code de PreToolUse -- 0 = segue, 2 = BLOQUEIA e manda o stderr pro modelo,
# qualquer outro (1, -196608) = erro nao-bloqueante que so aparece no transcript e DEIXA A
# FERRAMENTA RODAR. Guarda que morre e sai 1 grita e libera: fail-OPEN.
#
# O canon do proprio kit manda o contrario ("FAIL-CLOSED: gate instalado que nao consegue
# rodar BLOQUEIA"). Entao o wrapper traduz qualquer nao-zero do .ps1 em 2.
#
# Fail-closed sem porta de saida e maquina trancada: com o .ps1 quebrado, o escape
# PERCUS_HOOKS_DISABLED lido DENTRO do .ps1 nunca roda. Por isso o escape esta tambem no
# .cmd, antes da invocacao -- e por isso ele tem It proprio aqui.
#
# O .ps1 e sintetico de proposito, e o .cmd e o REAL: o artefato sob teste e o wrapper.
# O par copiado roda sozinho porque o .cmd resolve o script por %~dp0.

Describe "wrapper .cmd e fail-closed" {
    BeforeAll {
        $script:kitRoot  = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:hooksDir = Join-Path $script:kitRoot "plugin\percus-review\hooks"
        $script:temps    = New-Object System.Collections.ArrayList

        # Conteudo que NAO PARSEIA no 5.1: em dash DENTRO de string, arquivo SEM BOM. Sem BOM
        # o 5.1 le ANSI, o ultimo byte do em dash vira aspa curva e fecha a string cedo.
        # Nao uso chave desbalanceada nem lixo aleatorio: precisa ser falha de PARSE. Falha de
        # EXECUCAO o wrapper ja propagava certo, entao o teste passaria pelo motivo errado.
        #
        # O corpo sadio faz 'exit 0' de proposito: se um dia a corrupcao parar de corromper,
        # o script roda, sai 0, e o teste FALHA. A direcao da falha e segura.
        # [char]0x2014 em vez do caractere literal pra este arquivo de teste nao ser ele
        # proprio uma vitima do mesmo bug de encoding que ele testa.
        $script:ps1Quebrado = "Write-Host 'este script NAO deveria ter rodado'`nWrite-Host `"x " + [char]0x2014 + " y`"`nexit 0"

        # Copia o .cmd real e planta um .ps1 sintetico com o mesmo nome ao lado dele.
        function New-ParDeTeste {
            param([string]$Nome, [string]$ConteudoPs1, [bool]$ComBom)
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("wrap-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Copy-Item (Join-Path $script:hooksDir "$Nome.cmd") (Join-Path $dir "$Nome.cmd")
            [IO.File]::WriteAllText((Join-Path $dir "$Nome.ps1"), $ConteudoPs1, (New-Object System.Text.UTF8Encoding($ComBom)))
            [void]$script:temps.Add($dir)
            return (Join-Path $dir "$Nome.cmd")
        }

        function Invoke-Wrapper {
            param([string]$Cmd)
            $null = ('{"tool_name":"Bash","tool_input":{"command":"git status"}}' | & cmd.exe /c "`"$Cmd`"" 2>&1)
            return $LASTEXITCODE
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "com .ps1 que nao PARSEIA, o wrapper sai 2 (BLOQUEIA)" {
        # Medido com -File puro: .ps1 que nao parseia devolve 1, e 1 nao bloqueia nada.
        # Exigir 2 -- e nao "nao-zero" -- e a diferenca entre gritar e barrar.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 $script:ps1Quebrado -ComBom $false

        Invoke-Wrapper -Cmd $cmd | Should -Be 2 -Because "guarda que nao roda tem que BLOQUEAR; exit 1 o harness deixa passar"
    }

    It "com .ps1 ausente, o wrapper sai 2 (BLOQUEIA)" {
        # Medido com -File puro: .ps1 ausente devolve -196608, tambem faixa nao-bloqueante.
        # Hook desinstalado pela metade e o mesmo perigo que hook quebrado.
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("wrap-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Copy-Item (Join-Path $script:hooksDir "external-action-guard.cmd") (Join-Path $dir "external-action-guard.cmd")
        [void]$script:temps.Add($dir)
        # de proposito: nenhum .ps1 ao lado
        Invoke-Wrapper -Cmd (Join-Path $dir "external-action-guard.cmd") | Should -Be 2
    }

    It "com PERCUS_HOOKS_DISABLED=1 e .ps1 QUEBRADO, o wrapper sai 0 (escape nao depende do arquivo quebrado)" {
        # Este It e o que impede fail-closed de virar maquina trancada. O escape que existia
        # so dentro do .ps1 e inutil justamente no caso em que ele importa -- o .ps1 nao roda.
        # Sem a linha do escape NO .cmd, um .ps1 corrompido tranca a maquina e a unica saida e
        # editar arquivo ou desabilitar o plugin inteiro.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 $script:ps1Quebrado -ComBom $false

        $env:PERCUS_HOOKS_DISABLED = "1"
        try {
            Invoke-Wrapper -Cmd $cmd | Should -Be 0 -Because "o escape tem que funcionar SEM depender do .ps1 que quebrou"
        } finally {
            Remove-Item env:PERCUS_HOOKS_DISABLED -ErrorAction SilentlyContinue
        }
    }

    It "com .ps1 sadio que APROVA, o wrapper sai 0" {
        # Contrapeso: sem este It, um .cmd que sempre devolvesse 2 passaria em tudo que mede
        # bloqueio. Fail-closed que bloqueia TAMBEM o caminho feliz e so uma guarda travada.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "Write-Host 'aprovado'`nexit 0" -ComBom $true
        Invoke-Wrapper -Cmd $cmd | Should -Be 0
    }

    It "com .ps1 sadio que BLOQUEIA, o wrapper propaga o bloqueio (exit 2)" {
        # A outra metade da prova: fechar o fail-open nao pode custar a semantica normal.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "Write-Host 'bloqueando'`nexit 2" -ComBom $true
        Invoke-Wrapper -Cmd $cmd | Should -Be 2
    }

    It "TODOS os 11 wrappers .cmd tem a forma fail-closed exata, nao so o testado acima" {
        # Os It anteriores provam o comportamento em UM wrapper. Sem este, a correcao poderia
        # fechar so alguns dos 11 e a suite ficaria verde -- exatamente o tipo de meia-correcao
        # que deixou 3 guardas mortas sem ninguem ver.
        #
        # Aqui e inspecao de forma, e nao comportamento, de proposito: rodar os 11 wrappers de
        # verdade dispararia hook real (git, rede, escrita) como efeito colateral de teste.
        #
        # A assercao e POSITIVA (forma exata esperada) e nao negativa (ausencia de '-Command').
        # Medido: a versao negativa era furada -- '-c' e abreviacao valida de -Command e passava
        # verde, e '-File' seguido de 'exit /b 0' engole a falha igual. So a forma inteira,
        # linha a linha e com o nome do proprio arquivo no %~dp0, fecha essas frestas.
        $cmds = @(Get-ChildItem $script:hooksDir -Filter *.cmd | Sort-Object Name)

        # Piso de contagem: sem ele, uma pasta VAZIA faz este It passar sem verificar nada --
        # e a migracao dos hooks pro settings.json (spec sec. 9) esvazia exatamente esta pasta.
        $cmds.Count | Should -Be 11 -Because "piso de contagem: It que passa vazio nao guarda nada"

        $fora = @()
        foreach ($c in $cmds) {
            $base = [IO.Path]::GetFileNameWithoutExtension($c.Name)
            $esperado = @(
                '@echo off'
                'if "%PERCUS_HOOKS_DISABLED%"=="1" exit /b 0'
                ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0' + $base + '.ps1"')
                'if %ERRORLEVEL%==0 exit /b 0'
                'exit /b 2'
            )
            $linhas = @((Get-Content $c.FullName) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

            if (($linhas -join "`n") -cne ($esperado -join "`n")) {
                $fora += ("{0}:`n--- tem ---`n{1}`n--- esperado ---`n{2}" -f $c.Name, ($linhas -join "`n"), ($esperado -join "`n"))
            }
        }

        @($fora) | Should -BeNullOrEmpty -Because "wrapper fora da forma fail-closed nao bloqueia quando a guarda morre:`n$($fora -join "`n`n")"
    }
}
