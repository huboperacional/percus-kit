#requires -Version 5.1
Describe "registrar-uso-autorizacao.ps1" {
    BeforeAll {
        $script:kitRoot     = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:scriptUsar  = Join-Path $script:kitRoot "scripts\registrar-uso-autorizacao.ps1"
        $script:scriptCriar = Join-Path $script:kitRoot "scripts\autorizar-acao-externa.ps1"
        $script:temps       = New-Object System.Collections.ArrayList
    }
    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "acrescenta uma linha em .percus/autorizacoes-usadas.jsonl com id, motivo, comando e quando" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("uso-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)
        & $script:scriptCriar -Motivo "fim do dia" -ProjetoRoot $dir | Out-Null
        $auth = Get-Content (Join-Path $dir ".percus\acao-externa-autorizada.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        & $script:scriptUsar -Comando "git push origin main" -ProjetoRoot $dir | Out-Null

        $logPath = Join-Path $dir ".percus\autorizacoes-usadas.jsonl"
        Test-Path $logPath | Should -Be $true
        $linha = Get-Content $logPath -Raw | ConvertFrom-Json
        $linha.id | Should -Be $auth.id
        $linha.motivo | Should -Be "fim do dia"
        $linha.comando | Should -Be "git push origin main"
        $linha.quando | Should -Not -BeNullOrEmpty
    }

    It "acumula multiplas linhas (append, nao sobrescreve)" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("uso-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)
        & $script:scriptCriar -Motivo "fim do dia" -ProjetoRoot $dir | Out-Null

        & $script:scriptUsar -Comando "git push origin main" -ProjetoRoot $dir | Out-Null
        & $script:scriptUsar -Comando "gh pr comment 1 --body oi" -ProjetoRoot $dir | Out-Null

        $linhas = @(Get-Content (Join-Path $dir ".percus\autorizacoes-usadas.jsonl"))
        $linhas.Count | Should -Be 2
    }

    It "lanca erro claro se nao ha autorizacao ativa" {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("uso-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        [void]$script:temps.Add($dir)

        { & $script:scriptUsar -Comando "git push origin main" -ProjetoRoot $dir -ErrorAction Stop } |
            Should -Throw -ExpectedMessage "*nenhuma autorizacao*"
    }
}
