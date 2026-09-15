#requires -Version 5.1
# Utilitarios de teste para exercitar .sh a partir do Pester. Nao e *.tests.ps1: quem precisa faz
# dot-source no BeforeAll.
# Git\bin\bash.exe PRIMEIRO: o lancador poe %HOME%\bin (onde mora o jq desta maquina) no PATH
# (medido 2026-09-13, _dispatch-paridade.ps1). O `bash` do PATH pode ser o do WSL.

function Get-BashGit {
    $c = Join-Path $env:ProgramFiles 'Git'
    $c = Join-Path $c 'bin'
    $c = Join-Path $c 'bash.exe'
    if (Test-Path -LiteralPath $c) { return $c }
    $g = Get-Command bash -ErrorAction SilentlyContinue
    if ($g) { return $g.Source }
    return $null
}

function ConvertTo-CaminhoBash {
    param([string]$Caminho)
    return $Caminho.Replace([char]92, [char]47)
}

function Copy-SemCR {
    # Simula a instalacao do hook nativo (verbete sh-do-plugin-no-cache-chega-com-crlf...): tr -d '\r'.
    param([string]$Origem, [string]$Destino)
    $b = [IO.File]::ReadAllBytes($Origem)
    $l = New-Object System.Collections.Generic.List[byte]
    foreach ($x in $b) { if ($x -ne 13) { $l.Add($x) } }
    [IO.File]::WriteAllBytes($Destino, $l.ToArray())
}

function Set-EnvTemporario {
    param([hashtable]$Env)
    $antigos = @{}
    foreach ($k in $Env.Keys) {
        $antigos[$k] = [Environment]::GetEnvironmentVariable($k)
        if ($null -eq $Env[$k]) { [Environment]::SetEnvironmentVariable($k, [NullString]::Value) }
        else { [Environment]::SetEnvironmentVariable($k, [string]$Env[$k]) }
    }
    return $antigos
}

function Restore-EnvTemporario {
    # SetEnvironmentVariable(k, $null) no pwsh cria a variavel VAZIA; so [NullString]::Value remove.
    param([hashtable]$Antigos)
    foreach ($k in $Antigos.Keys) {
        if ($null -eq $Antigos[$k]) { [Environment]::SetEnvironmentVariable($k, [NullString]::Value) }
        else { [Environment]::SetEnvironmentVariable($k, [string]$Antigos[$k]) }
    }
}
