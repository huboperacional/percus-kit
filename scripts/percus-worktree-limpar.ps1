#requires -Version 5.1
<#
.SYNOPSIS
  Diagnostico e unlock seguro de worktrees git (ponto 30 do plano de Fase 2).
.DESCRIPTION
  Sem -Destravar: lista uma linha por worktree com caminho, branch, motivo da trava (se houver)
  e status do pid encontrado no texto da trava.

  Com -Destravar <nome-ou-caminho>: so' faz `git worktree unlock` quando a trava contem "pid N"
  E o processo N nao existe mais (sessao encerrada). Em qualquer outro caso (pid vivo, trava sem
  pid, worktree nao travado ou nao encontrado) recusa e NUNCA mata processo -- o script so'
  le estado de processo, nunca o altera.

  ASCII puro no source, mesma disciplina dos scripts irmaos deste kit
  (autorizar-acao-externa.ps1, renomear-kit-local.ps1).
.PARAMETER Repo
  Repositorio git a inspecionar. Default: diretorio atual. Todo comando git usa `-C <Repo>`
  explicito -- o script nunca muda o cwd da sessao.
.PARAMETER Destravar
  Nome (leaf do caminho) ou caminho completo do worktree a tentar destravar.
#>
[CmdletBinding()]
param(
    [string]$Repo = (Get-Location).Path,
    [string]$Destravar
)

# Sem "Stop": chamadas nativas git (`worktree list`/`unlock`) escrevem avisos no stderr no
# caminho normal (ex.: CRLF/autocrlf). Com "Stop", o `2>&1` abaixo fundiria esse stderr como
# erro terminante e abortaria o script por excecao ANTES de checar $LASTEXITCODE, mascarando
# o exit code contratado (ver regras-de-ambiente.md: "Sem $ErrorActionPreference='Stop': git
# escreve em stderr no caminho normal"). Falha real e' detectada via $LASTEXITCODE, nao via
# excecao -- por isso os `Write-Error` abaixo tambem usam -ErrorAction Continue, senao eles
# proprios abortariam antes do `exit` explicito.
$ErrorActionPreference = "Continue"

function ConvertTo-WorktreeRecords {
    param([string[]]$Linhas)

    $registros = New-Object System.Collections.ArrayList
    $atual = $null

    foreach ($linha in $Linhas) {
        if ([string]::IsNullOrWhiteSpace($linha)) {
            if ($null -ne $atual) {
                [void]$registros.Add($atual)
                $atual = $null
            }
            continue
        }

        if ($linha -like "worktree *") {
            if ($null -ne $atual) { [void]$registros.Add($atual) }
            $atual = [pscustomobject]@{
                Caminho = $linha.Substring("worktree ".Length)
                Branch  = "detached"
                Locked  = $false
                Motivo  = ""
            }
            continue
        }

        if ($null -eq $atual) { continue }

        if ($linha -like "branch *") {
            $ref = $linha.Substring("branch ".Length)
            if ($ref -like "refs/heads/*") { $ref = $ref.Substring("refs/heads/".Length) }
            $atual.Branch = $ref
        }
        elseif ($linha -eq "detached") {
            $atual.Branch = "detached"
        }
        elseif ($linha -eq "locked") {
            $atual.Locked = $true
            $atual.Motivo = ""
        }
        elseif ($linha -like "locked *") {
            $atual.Locked = $true
            $atual.Motivo = $linha.Substring("locked ".Length)
        }
    }
    if ($null -ne $atual) { [void]$registros.Add($atual) }

    return $registros
}

function Get-PidDaTrava {
    param([string]$Motivo)

    if ([string]::IsNullOrEmpty($Motivo)) { return $null }
    $m = [regex]::Match($Motivo, "pid\s+(\d+)", "IgnoreCase")
    if (-not $m.Success) { return $null }
    return [int]$m.Groups[1].Value
}

function Test-PidVivo {
    param([int]$ProcessId)

    $proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    return ($null -ne $proc)
}

function Format-StatusPid {
    param([string]$Motivo)

    $pidTrava = Get-PidDaTrava -Motivo $Motivo
    if ($null -eq $pidTrava) { return "sem-pid" }
    if (Test-PidVivo -ProcessId $pidTrava) { return "pid $pidTrava vivo" }
    return "pid $pidTrava morto"
}

$saidaGit = & git -C $Repo worktree list --porcelain 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error -ErrorAction Continue "git worktree list falhou em '$Repo': $saidaGit"
    exit 1
}

$registros = ConvertTo-WorktreeRecords -Linhas $saidaGit

if (-not $Destravar) {
    foreach ($r in $registros) {
        $motivoTexto = "nenhuma"
        if ($r.Locked) {
            $motivoTexto = $r.Motivo
            if ([string]::IsNullOrEmpty($motivoTexto)) { $motivoTexto = "sem motivo" }
        }
        $statusPid = Format-StatusPid -Motivo $r.Motivo
        "$($r.Caminho) | $($r.Branch) | trava: $motivoTexto | $statusPid"
    }
    exit 0
}

$alvo = $null
foreach ($r in $registros) {
    $leaf = Split-Path -Path $r.Caminho -Leaf
    if ($leaf -eq $Destravar -or $r.Caminho -eq $Destravar) {
        $alvo = $r
        break
    }
}

if ($null -eq $alvo) {
    "nao encontrado: $Destravar"
    exit 2
}

if (-not $alvo.Locked) {
    "destravado"
    exit 0
}

$pidTrava = Get-PidDaTrava -Motivo $alvo.Motivo
if ($null -eq $pidTrava) {
    "recusado: sem pid (nao e seguro destravar automaticamente)"
    exit 3
}

if (Test-PidVivo -ProcessId $pidTrava) {
    "recusado: pid $pidTrava vivo (encerre a sessao antes)"
    exit 3
}

& git -C $Repo worktree unlock $alvo.Caminho | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error -ErrorAction Continue "git worktree unlock falhou para '$($alvo.Caminho)'"
    exit 1
}

"destravado"
exit 0
