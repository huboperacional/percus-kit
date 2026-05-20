#requires -Version 5.1
# Helpers compartilhados pelos hooks Percus. Source via dot-sourcing:
#   . "$PSScriptRoot\_helpers.ps1"

function Resolve-PercusProjectRoot {
    <#
    .SYNOPSIS
        Resolve o root do projeto-alvo de um comando bash.
    .DESCRIPTION
        Quando agente roda `cd "C:\path\projeto" && git commit ...`, o hook fira
        com CWD = agente, nao = projeto. Esta funcao parseia `cd <path>` do
        comando pra retornar o root correto. Fallback: CWD atual.
    .PARAMETER Command
        String do tool_input.command (campo do hook PreToolUse:Bash).
    #>
    param([string]$Command)

    if ($Command) {
        if ($Command -match 'cd\s+"([^"]+)"') { return $matches[1] }
        if ($Command -match "cd\s+'([^']+)'") { return $matches[1] }
        if ($Command -match 'cd\s+(\S+?)(?:\s|$|&&|;)') {
            $candidate = $matches[1].TrimEnd('"',"'")
            if (Test-Path $candidate -PathType Container) { return $candidate }
        }
    }
    return (Get-Location).Path
}

function Get-PercusStagedFiles {
    <#
    .SYNOPSIS
        Retorna lista de arquivos staged no projeto, opcionalmente filtrados por extensao.
    .PARAMETER ProjectRoot
        Path do projeto (use Resolve-PercusProjectRoot).
    .PARAMETER Extensions
        Array de extensoes (com ponto). Ex: @('.py','.ts','.tsx')
    #>
    param(
        [string]$ProjectRoot,
        [string[]]$Extensions = @()
    )

    if (-not (Test-Path (Join-Path $ProjectRoot ".git"))) { return @() }

    $files = & git -C $ProjectRoot diff --cached --name-only --diff-filter=ACMR 2>$null
    if (-not $files) { return @() }

    if ($Extensions.Count -eq 0) { return $files }
    return $files | Where-Object {
        $ext = [System.IO.Path]::GetExtension($_).ToLower()
        $Extensions -contains $ext
    }
}

function Get-PercusStagedContent {
    <#
    .SYNOPSIS
        Retorna conteudo staged (versao no index) de um arquivo.
    .NOTES
        Forca decode UTF-8 do output do git. Sem isso, PowerShell decodifica
        a saida nativa com a codepage OEM (cp850/cp437), mojibakando chars
        acentuados — ex: "e" de "metodo" vira 2 bytes nao-word, criando uma
        word-boundary falsa que faz \btodo\b casar dentro de "metodo".
    #>
    param(
        [string]$ProjectRoot,
        [string]$RelPath
    )
    $prevEnc = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        return (& git -C $ProjectRoot show ":${RelPath}" 2>$null) -join "`n"
    } finally {
        [Console]::OutputEncoding = $prevEnc
    }
}

function Write-PercusBlock {
    <#
    .SYNOPSIS
        Escreve mensagem de bloqueio padronizada no stderr e retorna exit code 2.
    #>
    param([string]$HookName, [string[]]$Lines)
    [Console]::Error.WriteLine("[percus:hook $HookName] BLOCK:")
    foreach ($line in $Lines) {
        [Console]::Error.WriteLine("  $line")
    }
}
