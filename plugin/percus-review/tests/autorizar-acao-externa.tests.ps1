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

    It "grava motivo acentuado sem corromper (BOM UTF-8, le de volta com -Encoding UTF8)" {
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
        $auth = Get-Content $caminho -Raw -Encoding UTF8 | ConvertFrom-Json
        $auth.motivo | Should -Be $motivoAcentuado
    }
}
