#requires -Version 5.1
<#
.SYNOPSIS
  Cria um worktree isolado para uma sessao trabalhar sem disputar a arvore com as outras.

.DESCRIPTION
  O percus-kit e usado como PERCUS_CANON_DIR por dezenas de projetos, e varias sessoes escrevem
  nele ao mesmo tempo. Medido em 2026-08-19, numa unica sessao: 14 verbetes untracked de terceiros
  apareceram na arvore, os dois INDICE.md foram regenerados por outra sessao no meio do trabalho, e
  outra sessao empurrou os commits desta antes que ela decidisse empurrar.

  A 6.41.0 resolveu os sintomas que davam pra resolver sem mexer no fluxo:
    - o gate parou de enumerar untracked, entao rascunho alheio nao barra mais commit;
    - o marcador de review virou hash do diff, entao a review de outra sessao nao satisfaz nem
      invalida a minha.

  O que sobra e o trabalho ORFAO: arquivo que aparece na arvore, ninguem adota, e fica pra tras em
  todo push. Isso o worktree resolve de raiz -- cada sessao tem sua propria arvore.

  ESTE SCRIPT NAO MUDA O FLUXO PADRAO. Ele existe pra quem quiser isolar uma sessao especifica.
  Trocar o modo como o operador abre sessao e decisao dele, nao do agente.

.PARAMETER Nome
  Nome da sessao. Vira o nome da branch e o sufixo do diretorio.

.PARAMETER Base
  Ref de origem. Default: origin/main (nao 'main' local, que pode estar atras).

.EXAMPLE
  pwsh -File scripts/nova-sessao-worktree.ps1 -Nome conserto-telemetria
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Nome,
    [string]$Base = "origin/main"
)
$ErrorActionPreference = "Stop"

$slug = ($Nome -replace '[^a-zA-Z0-9-]', '-').Trim('-').ToLower()
if (-not $slug) { throw "Nome invalido: '$Nome'" }

$raiz = (& git rev-parse --show-toplevel 2>$null)
if (-not $raiz) { throw "Nao estou dentro de um repositorio git." }
$raiz = $raiz.Trim()
$pai  = Split-Path -Parent $raiz
$nomeRepo = Split-Path -Leaf $raiz
$destino = Join-Path $pai "$nomeRepo-wt-$slug"

if (Test-Path $destino) { throw "Ja existe: $destino" }

# fetch antes: sem ele, -Base origin/main pode apontar pra um commit velho e o worktree nasce
# desatualizado -- o oposto do isolamento que se quer.
& git fetch origin --quiet 2>$null | Out-Null

Write-Host "[worktree] criando $destino a partir de $Base..."
& git worktree add -b "sessao/$slug" "$destino" "$Base"
if ($LASTEXITCODE -ne 0) { throw "git worktree add falhou." }

# O gate de commit e um git hook por-repo, e worktree NAO herda .git/hooks do principal --
# ele tem o proprio diretorio de hooks. Sem reinstalar, a sessao isolada commitaria SEM GATE, o
# que troca um problema de concorrencia por um buraco de enforcement.
$instalador = Join-Path $raiz "v2/gates/instalar-gates.sh"
if (Test-Path $instalador) {
    Write-Host "[worktree] reinstalando o gate no worktree (worktree nao herda hooks)..."
    Push-Location $destino
    try {
        $bash = (Get-Command bash -ErrorAction SilentlyContinue)
        $exe = if ($bash) { $bash.Source } else { Join-Path $env:ProgramFiles "Git/bin/bash.exe" }
        & $exe $instalador
    } finally { Pop-Location }
} else {
    Write-Host "[worktree] AVISO: $instalador nao encontrado -- instale o gate a mao antes de commitar."
}

Write-Host ""
Write-Host "[worktree] pronto:"
Write-Host "  cd `"$destino`""
Write-Host ""
Write-Host "  Ao terminar:  git worktree remove `"$destino`""
Write-Host "  No Windows, se houver junction de node_modules, remova a junction ANTES --"
Write-Host "  `git worktree remove` segue junction e apaga o alvo."
