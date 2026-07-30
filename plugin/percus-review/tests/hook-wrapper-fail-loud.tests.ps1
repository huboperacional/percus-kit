#requires -Version 5.1
# O .cmd e a fronteira entre o harness e a guarda: o harness so le zero/nao-zero. Se o
# wrapper traduz "o script nem rodou" em zero, guarda quebrada responde "aprovado" -- foi
# o que aconteceu em 2026-07-30 com 3 guardas de PreToolUse.
#
# O .ps1 e sintetico de proposito, e o .cmd e o REAL: o artefato sob teste e o wrapper.
# O par copiado roda sozinho porque o .cmd resolve o script por %~dp0.

Describe "wrapper .cmd nao engole falha do .ps1" {
    BeforeAll {
        $script:kitRoot  = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:hooksDir = Join-Path $script:kitRoot "plugin\percus-review\hooks"
        $script:temps    = New-Object System.Collections.ArrayList

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

    It "com .ps1 que nao PARSEIA, o wrapper sai NAO-ZERO" {
        # Gatilho real deste defeito: em dash DENTRO de string, arquivo SEM BOM. Sem BOM o
        # 5.1 le ANSI, o ultimo byte do em dash vira aspa curva e fecha a string cedo.
        # Nao uso chave desbalanceada nem lixo aleatorio: precisa ser falha de PARSE.
        # Falha de EXECUCAO o wrapper antigo ja propagava certo, entao o teste passaria
        # pelo motivo errado e nao provaria nada sobre o amplificador.
        #
        # O corpo sadio faz 'exit 0' de proposito: se um dia a corrupcao parar de corromper,
        # o script roda, sai 0, e o teste FALHA. A direcao da falha e segura -- nunca vira
        # falso verde.
        $conteudo = "Write-Host 'este script NAO deveria ter rodado'`nWrite-Host `"x " + [char]0x2014 + " y`"`nexit 0"
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 $conteudo -ComBom $false

        Invoke-Wrapper -Cmd $cmd | Should -Not -Be 0 -Because "guarda que nao roda nao pode responder 'aprovado' pro harness"
    }

    It "com .ps1 sadio que bloqueia, o wrapper propaga o codigo (exit 2)" {
        # A outra metade da prova: consertar o engolimento nao pode custar a semantica.
        $cmd = New-ParDeTeste -Nome "external-action-guard" -ConteudoPs1 "Write-Host 'bloqueando'`nexit 2" -ComBom $true
        Invoke-Wrapper -Cmd $cmd | Should -Be 2
    }

    It "com .ps1 ausente, o wrapper sai NAO-ZERO" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("wrap-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Copy-Item (Join-Path $script:hooksDir "external-action-guard.cmd") (Join-Path $dir "external-action-guard.cmd")
        [void]$script:temps.Add($dir)
        # de proposito: nenhum .ps1 ao lado
        Invoke-Wrapper -Cmd (Join-Path $dir "external-action-guard.cmd") | Should -Not -Be 0
    }
}
