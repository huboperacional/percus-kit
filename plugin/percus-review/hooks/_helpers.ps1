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

function Find-PercusNearestConfigDir {
    <#
    .SYNOPSIS
        Acha o diretorio mais proximo (subindo a arvore a partir de um arquivo staged,
        parando em ProjectRoot) que contem um marker (arquivo ou pasta).
    .DESCRIPTION
        Resolve o caso de monorepo (tsconfig.json/.venv numa subpasta como `frontend/`
        ou `backend/`, nao na raiz) sem o hook precisar saber o layout do projeto.
        Devolvida Plexco Tasks 2026-09-04: o types-check hook so olhava a raiz, entao
        pulava em silencio (sem aviso) em qualquer monorepo. Custou 5 dias de CI vermelho
        la porque um erro de tipo que deveria ter sido barrado no commit passou batido.
    .PARAMETER ProjectRoot
        Raiz do projeto (limite superior da busca — nunca sobe alem dele).
    .PARAMETER RelativeFile
        Path do arquivo staged, relativo a ProjectRoot (como Get-PercusStagedFiles
        devolve — sempre com '/', vindo do `git diff --cached --name-only`).
    .PARAMETER Marker
        Nome do arquivo ou pasta a procurar em cada nivel (ex: 'tsconfig.json', '.venv').
    .OUTPUTS
        Path absoluto do diretorio que contem o Marker, ou $null se nao achou ate ProjectRoot.
    #>
    param(
        [string]$ProjectRoot,
        [string]$RelativeFile,
        [string]$Marker
    )
    $rootFull = (Resolve-Path $ProjectRoot).Path.TrimEnd('\', '/')
    $dir = Split-Path (Join-Path $rootFull ($RelativeFile -replace '/', '\')) -Parent
    while ($dir -and $dir.Length -ge $rootFull.Length) {
        if (Test-Path (Join-Path $dir $Marker)) { return $dir }
        if ($dir -eq $rootFull) { break }
        $dir = Split-Path $dir -Parent
    }
    return $null
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

function Get-PercusChangedLines {
    <#
    .SYNOPSIS
        Numeros de linha ADICIONADOS/MODIFICADOS (lado NOVO/staged) de um arquivo.
    .DESCRIPTION
        Achado real (Familia Milionaria, 2026-09-08): um gate de tipo/lint que roda
        sobre o ARQUIVO staged inteiro (mypy --strict, tsc) reporta TODA linha do
        arquivo -- inclusive debito legado que o commit nem tocou. Num arquivo de
        anos sem type-check (comum neste canon: "tipos encorajados", nao
        obrigatorios desde sempre), isso bloqueia qualquer commit que toque o
        arquivo, pra sempre, por erro que a mudanca nao introduziu. A trava certa
        e "nao introduza erro NOVO", nao "o arquivo inteiro tem de estar limpo" --
        mesma filosofia do R11 (revisao do DIFF, nunca do arquivo inteiro).
    .PARAMETER ProjectRoot
        Raiz do projeto.
    .PARAMETER RelPath
        Path do arquivo, relativo a ProjectRoot, com '/' (formato de
        `git diff --name-only`).
    .OUTPUTS
        HashSet[int] com os numeros de linha (no arquivo NOVO) que o diff
        adiciona ou modifica. Vazio se o arquivo for novo por inteiro tratamos
        via hunk normal (`+` conta todas as linhas do arquivo).
    #>
    param([string]$ProjectRoot, [string]$RelPath)
    $linhas = New-Object 'System.Collections.Generic.HashSet[int]'
    $diff = & git -C $ProjectRoot diff --cached --unified=0 -- $RelPath 2>$null
    if (-not $diff) { return $linhas }
    $atual = 0
    foreach ($l in $diff) {
        if ($l -match '^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@') {
            $atual = [int]$matches[1]
            continue
        }
        if ($l.StartsWith('+++') -or $l.StartsWith('---')) { continue }
        if ($l.StartsWith('+')) {
            [void]$linhas.Add($atual)
            $atual++
        }
        # linha removida ('-'): nao existe no lado NOVO, nao avanca $atual.
    }
    return $linhas
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
