#requires -Version 5.1
<#
.SYNOPSIS
  Gera o INDICE.md de cada area da base de conhecimento, a partir dos arquivos de verbete.

.DESCRIPTION
  Sucessor do mesclar-conhecimento.ps1. Desde a 6.38.0 a base e um-arquivo-por-verbete
  (conhecimento/<area>/<slug>.md) e NAO ha mais monolito nem caixa de entrada: a sessao
  escreve o arquivo direto, e nao existe passo de merge que possa adiar, colidir ou
  engolir trabalho alheio.

  O que sobrou de "mesclar" foi so a parte util: manter um indice legivel em dia. E ele e
  GERADO -- editar a mao devolveria a divergencia entre indice e conteudo que produziu 14
  verbetes invisiveis (medido 2026-08-18).

  O indice NAO e o caminho primario de consulta. Buscar por classe de sintoma agora e:

      grep -l "tags:.*<termo>" conhecimento/resolver/*.md

  que devolve NOMES DE ARQUIVO e custa o tamanho da resposta. O indice serve pra visao
  ampla ("o que existe sobre isso?"), nao pra achar um verbete especifico.

.PARAMETER Raiz
  Raiz do canon. Default: $env:PERCUS_CANON_DIR, ou a pasta acima de scripts/.

.PARAMETER Verificar
  Nao escreve: sai != 0 se algum INDICE.md estiver desatualizado. Para usar em gate/CI.

.EXAMPLE
  .\scripts\gerar-indice-conhecimento.ps1
  .\scripts\gerar-indice-conhecimento.ps1 -Verificar
#>
[CmdletBinding()]
param(
    [string]$Raiz = "",
    [switch]$Verificar
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $Raiz) { $Raiz = $env:PERCUS_CANON_DIR }
if (-not $Raiz) { $Raiz = Split-Path $PSScriptRoot -Parent }
if (-not (Test-Path $Raiz)) {
    [Console]::Error.WriteLine("[gerar-indice] raiz nao encontrada: $Raiz")
    exit 2
}

# As MESMAS areas que o bloco 2 do percus-gate.sh declara em _AREAS_CONHECIMENTO. Divergir aqui
# cria trava sem saida (apontado pelo R11, 2026-08-18): se um verbete nascesse numa area que o
# gate afere e o gerador ignora, o bloco 2d exigiria um INDICE.md sincronizado que NENHUM script
# gera -- e edita-lo a mao e barrado pelo knowledge-write-guard. Gate impossivel de satisfazer.
$areas = @(
    @{ Raiz = "conhecimento"; Nome = "resolver"; Titulo = "Como Resolver" }
    @{ Raiz = "conhecimento"; Nome = "fazer";    Titulo = "Como Fazer" }
    @{ Raiz = "referencia/conhecimento"; Nome = "resolver"; Titulo = "Como Resolver (referencia)" }
    @{ Raiz = "referencia/conhecimento"; Nome = "fazer";    Titulo = "Como Fazer (referencia)" }
)

# Le e escreve preservando UTF-8 SEM BOM e CRLF. O canon e CRLF puro; normalizar produziria
# diff gigante, e ler no default do runtime corrompe acento no PS 5.1
# (ver #get-content-sem-encoding-mojibake-51).
function Read-Texto([string]$Caminho) {
    return [IO.File]::ReadAllText($Caminho, [Text.Encoding]::UTF8)
}
function Write-Texto([string]$Caminho, [string]$Texto) {
    [IO.File]::WriteAllText($Caminho, $Texto, (New-Object System.Text.UTF8Encoding($false)))
}

# Titulo = linha '## ... {#slug}' FORA de bloco de codigo, com a ancora fechando a linha.
# Mesmo criterio do gate: gate e gerador discordando sobre o que e verbete e pior que os
# dois errarem juntos -- o gate aprovaria o que o gerador ignora, e o verbete sumiria do
# indice sem ninguem ver.
function Get-TituloDoVerbete([string]$Texto) {
    $fence = $false
    foreach ($l in [regex]::Split($Texto, "`r`n|`n")) {
        if ($l -match '^```') { $fence = -not $fence; continue }
        if ($fence) { continue }
        $m = [regex]::Match($l, '^##[ \t]+(?<titulo>.+?)[ \t]*\{#(?<slug>[^}]+)\}[ \t]*\r?$')
        if ($m.Success) {
            return [pscustomobject]@{
                Titulo = $m.Groups['titulo'].Value.Trim()
                Slug   = $m.Groups['slug'].Value.Trim()
            }
        }
    }
    return $null
}

$desatualizados = 0
$erros = 0

foreach ($area in $areas) {
    $dir = Join-Path (Join-Path $Raiz ($area.Raiz -replace "/", "\")) $area.Nome
    if (-not (Test-Path $dir)) { continue }

    $arquivos = @(Get-ChildItem $dir -Filter *.md -File |
                  Where-Object { $_.BaseName -ne "INDICE" -and $_.BaseName -ne "LEIA-ME" } |
                  Sort-Object Name)

    $linhas = New-Object System.Collections.ArrayList
    [void]$linhas.Add("# Indice - $($area.Titulo)")
    [void]$linhas.Add("")
    [void]$linhas.Add("> GERADO por scripts/gerar-indice-conhecimento.ps1. Nao edite a mao.")
    [void]$linhas.Add("> Para achar por CLASSE de sintoma, prefira:")
    [void]$linhas.Add("> ``grep -l ""tags:.*<termo>"" $($area.Raiz)/$($area.Nome)/*.md``")
    [void]$linhas.Add("")

    foreach ($a in $arquivos) {
        $t = Get-TituloDoVerbete (Read-Texto $a.FullName)
        if (-not $t) {
            [Console]::Error.WriteLine("[gerar-indice] $($a.Name): sem titulo '## ... {#slug}' -- fica FORA do indice")
            $erros++
            continue
        }
        if ($t.Slug -ne $a.BaseName) {
            [Console]::Error.WriteLine("[gerar-indice] $($a.Name): slug '$($t.Slug)' diverge do nome do arquivo")
            $erros++
            continue
        }
        # Escapar colchete do TITULO: sem isso, um titulo que comeca com "[5-T] ..." produz
        # "- [[5-T] ...](arquivo.md)" e o ']' fecha o rotulo do link cedo demais -- markdown
        # malformado, link nao-navegavel. Havia 1 caso real na base (R11, 2026-08-18).
        $rotulo = $t.Titulo -replace '\[', '\[' -replace '\]', '\]'
        [void]$linhas.Add("- [$rotulo]($($a.BaseName).md)")
    }
    [void]$linhas.Add("")

    $novo = ($linhas -join "`r`n")
    $destino = Join-Path $dir "INDICE.md"
    $atual = if (Test-Path $destino) { Read-Texto $destino } else { "" }

    if ($novo -eq $atual) {
        Write-Host "[gerar-indice] $($area.Raiz)/$($area.Nome): em dia ($($arquivos.Count) verbetes)"
    } elseif ($Verificar) {
        [Console]::Error.WriteLine("[gerar-indice] $($area.Raiz)/$($area.Nome): INDICE.md DESATUALIZADO -- rode sem -Verificar")
        $desatualizados++
    } else {
        Write-Texto $destino $novo
        Write-Host "[gerar-indice] $($area.Raiz)/$($area.Nome): INDICE.md regravado ($($arquivos.Count) verbetes)"
    }
}

if ($erros -gt 0) { exit 3 }
if ($desatualizados -gt 0) { exit 1 }
exit 0
