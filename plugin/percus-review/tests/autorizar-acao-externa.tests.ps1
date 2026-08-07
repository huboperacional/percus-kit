#requires -Version 5.1
# Script chamado pelo AGENTE depois de confirmacao explicita do operador na conversa -- ver
# docs/superpowers/specs/2026-08-06-r20-autorizacao-lote-design.md. O teste NUNCA toca o
# .percus/ real do repo: monta pasta temp e afere o resultado.

Describe "autorizar-acao-externa.ps1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\autorizar-acao-externa.ps1"
        $script:temps   = New-Object System.Collections.ArrayList
    }
    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "cria .percus/acao-externa-autorizada.json com id, motivo e timestamp_unix recente" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("autoriza-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)

        & $script:script -Motivo "fim do dia, pode publicar" -ProjetoRoot $dir | Out-Null

        $caminho = Join-Path $dir ".percus\acao-externa-autorizada.json"
        Test-Path $caminho | Should -Be $true
        $auth = Get-Content $caminho -Raw | ConvertFrom-Json
        { [guid]::Parse($auth.id) } | Should -Not -Throw
        $auth.motivo | Should -Be "fim do dia, pode publicar"
        $agoraEpoch = [DateTimeOffset]::new((Get-Date)).ToUnixTimeSeconds()
        [math]::Abs($agoraEpoch - $auth.timestamp_unix) | Should -BeLessThan 10
    }

    It "cria a pasta .percus se ela ainda nao existir" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("autoriza-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)
        Test-Path (Join-Path $dir ".percus") | Should -Be $false

        & $script:script -Motivo "teste" -ProjetoRoot $dir | Out-Null

        Test-Path (Join-Path $dir ".percus") | Should -Be $true
    }

    It "sobrescreve autorizacao existente (reautorizar renova a janela e troca o id)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("autoriza-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)

        & $script:script -Motivo "primeira" -ProjetoRoot $dir | Out-Null
        $primeiroId = (Get-Content (Join-Path $dir ".percus\acao-externa-autorizada.json") -Raw | ConvertFrom-Json).id

        & $script:script -Motivo "segunda" -ProjetoRoot $dir | Out-Null
        $auth = Get-Content (Join-Path $dir ".percus\acao-externa-autorizada.json") -Raw | ConvertFrom-Json

        $auth.motivo | Should -Be "segunda"
        $auth.id | Should -Not -Be $primeiroId
    }

    It "-Motivo e obrigatorio" {
        { & $script:script -ProjetoRoot "C:\qualquer" -ErrorAction Stop } | Should -Throw
    }

    It "grava motivo acentuado sem corromper QUANDO lido por powershell.exe 5.1 real (runtime de producao do hook)" {
        # Achado da revisao final (DeepSeek): ler sem -Encoding NAO basta se quem le e' `pwsh`
        # (PowerShell Core) -- Core assume UTF-8 por default mesmo sem BOM, entao o teste passava
        # verde mesmo revertendo o fix do BOM. So o `powershell.exe` 5.1 REAL tem o bug (decide o
        # encoding por heuristica e cai em ANSI sem BOM) -- e essa suite roda inteira sob `pwsh`
        # (ver cabecalho de ps51-compat.tests.ps1: "a suite roda em pwsh 7, que le UTF-8 por
        # default, entao ela e cega pra esta classe por construcao"). Mesmo padrao de
        # ps51-compat.tests.ps1: dispara um helper .ps1 (com BOM, senao o helper corrompe a si
        # mesmo) via `powershell.exe` de verdade.
        $ps51 = Get-Command powershell.exe -ErrorAction SilentlyContinue
        if (-not $ps51) {
            Set-ItResult -Skipped -Because "powershell.exe (5.1) nao existe nesta maquina -- sem ele o hook .cmd tambem nao roda, entao o teste e irrelevante aqui"
            return
        }

        $dir = Join-Path ([IO.Path]::GetTempPath()) ("autoriza-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)

        # ASCII puro no source (disciplina do kit, ver renomear-kit-local.ps1): monta o texto
        # acentuado via [char] com o codepoint Unicode em vez de literal no arquivo -- este
        # proprio .tests.ps1 nao tem BOM, e um acento literal aqui reproduziria a MESMA classe
        # de bug que o fix do BOM no .json resolveu, so que no source do teste (achado
        # ps51-compat.tests.ps1, "nenhum .ps1 do kit tem caractere nao-ASCII sem BOM").
        # codepoints: c-cedilha=0x00E7  a-til=0x00E3
        $motivoAcentuado = "corre" + [char]0x00E7 + [char]0x00E3 + "o-urgente-acentuada: " +
            [char]0x00E7 + [char]0x00E3 + "o, n" + [char]0x00E3 + "o, autoriza" + [char]0x00E7 + [char]0x00E3 + "o"

        & $script:script -Motivo $motivoAcentuado -ProjetoRoot $dir | Out-Null
        $caminho = Join-Path $dir ".percus\acao-externa-autorizada.json"

        # O leitor grava o resultado em ARQUIVO, nao em stdout -- capturar stdout de um processo
        # powershell.exe separado tem a MESMA classe de risco de encoding (console/pipe), que so
        # trocaria um problema por outro. Lendo de volta em pwsh com -Encoding UTF8 explicito
        # (controlado por este arquivo, nao pelo 5.1) fecha o loop sem introduzir uma segunda
        # incognita.
        $progLeitor = @'
param($jsonPath, $outPath)
$auth = Get-Content $jsonPath -Raw | ConvertFrom-Json
[IO.File]::WriteAllText($outPath, $auth.motivo, (New-Object System.Text.UTF8Encoding($true)))
'@
        $tmpProg = Join-Path ([IO.Path]::GetTempPath()) ("ler-autoriza-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".ps1")
        $tmpOut  = Join-Path ([IO.Path]::GetTempPath()) ("motivo-lido-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".txt")
        try {
            # O helper tambem precisa de BOM -- senao o proprio helper.ps1 (que nao tem acento
            # literal, mas sera lido pelo 5.1) fica sujeito ao mesmo parser, por consistencia com
            # ps51-compat.tests.ps1.
            [IO.File]::WriteAllText($tmpProg, $progLeitor, (New-Object System.Text.UTF8Encoding($true)))
            & $ps51.Source -NoProfile -ExecutionPolicy Bypass -File $tmpProg $caminho $tmpOut | Out-Null
            $lido = Get-Content $tmpOut -Raw -Encoding UTF8
        } finally {
            Remove-Item $tmpProg,$tmpOut -Force -ErrorAction SilentlyContinue
        }

        $lido | Should -Be $motivoAcentuado -Because "powershell.exe 5.1 real e' o runtime de producao do hook -- se isto falhar, o fix do BOM regrediu"
    }
}
