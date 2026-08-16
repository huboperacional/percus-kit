#requires -Version 5.1
<#
.SYNOPSIS
  Mescla a caixa de entrada de conhecimento (um verbete por arquivo) nos monolitos.

.DESCRIPTION
  COMO_RESOLVER.md tem centenas de verbetes num arquivo so, e toda sessao de todo projeto
  escreve nele. O git resolve conflito em ARQUIVO: duas sessoes escrevendo licoes sobre
  assuntos diferentes colidem assim mesmo. Medido em 2026-08-16 -- um commit levaria junto o
  rascunho inacabado de outra sessao, e o gate barrou o commit legitimo.

  A caixa desfaz isso: cada sessao escreve conhecimento/entrada/<area>/<slug>.md. Arquivos
  diferentes, colisao zero. Este script junta tudo no monolito num ato so, no checkpoint.

    conhecimento/entrada/resolver/<slug>.md  ->  conhecimento/COMO_RESOLVER.md
    conhecimento/entrada/fazer/<slug>.md     ->  conhecimento/COMO_FAZER.md

  REGRA CENTRAL -- se o monolito de destino ja esta modificado na arvore (outra sessao
  mexendo), este script NAO mescla: ele ADIA, e as entradas ficam na caixa pro proximo
  checkpoint. Adiar so e aceitavel porque a caixa e duravel; sem ela, adiar significava
  perder o verbete ou travar o commit. Adiar NAO e erro e sai com codigo 0.

  Entrada invalida tambem fica na caixa (descartar perderia o verbete), mas o script sai
  com codigo != 0 pra denunciar. Uma entrada podre NAO retem as saudaveis.

.PARAMETER Raiz
  Raiz do canon. Default: $env:PERCUS_CANON_DIR, ou a pasta acima de scripts/.

.EXAMPLE
  .\scripts\mesclar-conhecimento.ps1
#>
[CmdletBinding()]
param(
    [string]$Raiz = ""
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $Raiz) { $Raiz = $env:PERCUS_CANON_DIR }
if (-not $Raiz) { $Raiz = Split-Path $PSScriptRoot -Parent }
if (-not (Test-Path $Raiz)) {
    [Console]::Error.WriteLine("[mesclar-conhecimento] raiz nao encontrada: $Raiz")
    exit 2
}

$areas = @(
    @{ Nome = "resolver"; Destino = "COMO_RESOLVER.md" }
    @{ Nome = "fazer";    Destino = "COMO_FAZER.md" }
)

$conhecimentoDir = Join-Path $Raiz "conhecimento"
$houveErro   = $false
$mesclados   = 0
$adiados     = 0

# Le preservando a "BOM-ness" original: os .md do canon sao UTF-8 SEM BOM, e gravar com BOM
# quebraria parser alheio e sujaria o diff. Ver #get-content-sem-encoding-mojibake-51 --
# a leitura NUNCA fica no default do runtime.
function Read-Texto([string]$Caminho) {
    return [IO.File]::ReadAllText($Caminho, [Text.Encoding]::UTF8)
}
function Write-Texto([string]$Caminho, [string]$Texto, [bool]$ComBom) {
    $enc = New-Object System.Text.UTF8Encoding($ComBom)
    [IO.File]::WriteAllText($Caminho, $Texto, $enc)
}
function Test-TemBom([string]$Caminho) {
    $b = [IO.File]::ReadAllBytes($Caminho)
    return ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
}

# Preserva a quebra de linha DO ARQUIVO em vez de assumir CRLF: o COMO_RESOLVER.md e CRLF e
# normalizar produziria diff de 12 mil linhas, mas hardcodar CRLF faria o mesmo estrago ao
# contrario num arquivo LF. Quem manda e o arquivo.
function Get-Eol([string]$Texto) {
    $crlf = ([regex]::Matches($Texto, "`r`n")).Count
    $lf   = ([regex]::Matches($Texto, "(?<!`r)`n")).Count
    if ($lf -gt $crlf) { return "`n" }
    return "`r`n"
}

# As validacoes abaixo tem de enxergar o arquivo como o percus-gate.sh (bloco 3c) enxerga.
# Gate e mesclador discordando sobre o que e valido e pior que os dois errarem juntos: o
# commit passa no gate e o checkpoint quebra depois (achado do R11, 2026-08-16).
function Get-TitulosForaDeFence([string[]]$Linhas) {
    $achados = @(); $fence = $false
    foreach ($l in $Linhas) {
        if ($l -match '^```') { $fence = -not $fence; continue }
        if ($fence) { continue }
        $m = [regex]::Match($l, '^##[ \t]+(?<titulo>.+?)[ \t]*\{#(?<slug>[^}]+)\}[ \t]*\r?$')
        if ($m.Success) {
            $achados += [pscustomobject]@{ Titulo = $m.Groups['titulo'].Value.Trim(); Slug = $m.Groups['slug'].Value.Trim() }
        }
    }
    return $achados
}

# Ancora ja existente = SO o que esta em linha de TITULO, fora de fence. Duas armadilhas que
# o R11 pegou nesta versao: (1) exemplo '{#slug}' dentro de ``` bloqueava entrada legitima;
# (2) mencao inline em prosa ("a ancora e escrita como {#slug}") tambem -- e a base de
# conhecimento fala de si mesma o tempo todo.
function Get-SlugsExistentes([string]$Texto) {
    return @(Get-TitulosForaDeFence ([regex]::Split($Texto, "`r`n|`n")) | ForEach-Object { $_.Slug })
}

# Espelha o awk do bloco 3 do gate, inclusive a ordem: fence, blockquote, titulo, contador.
# Linha de blockquote NAO incrementa a janela -- sem isso o gate acusava "sem tags:" um
# verbete que TEM tags, barrando commit legitimo (o proprio gate documenta o caso).
function Test-TemTags([string[]]$Linhas) {
    $fence = $false; $emVerbete = $false; $c = 0
    foreach ($l in $Linhas) {
        if ($l -match '^```') { $fence = -not $fence; continue }
        if ($fence) { continue }
        if ($l -match '^[ \t]*>') { continue }
        if ($l -match '^##[ \t]+.*\{#') { $emVerbete = $true; $c = 0; continue }
        if ($emVerbete) {
            $c++
            if ($l -match '^`?tags:') { return $true }
            if ($c -ge 4) { return $false }
        }
    }
    return $false
}

# "modificado na arvore" = o git ve diferenca (staged ou nao). Se o git nao responder --
# nao e repo, git ausente, permissao -- tratamos como NAO-VERIFICAVEL e adiamos. Num
# mesclador que reescreve a base de conhecimento inteira, desconhecido conta como ocupado.
function Test-DestinoOcupado([string]$RaizRepo, [string]$RelPath) {
    try {
        $saida = & git -C $RaizRepo status --porcelain -- $RelPath 2>$null
        if ($LASTEXITCODE -ne 0) { return $true }
        return (-not [string]::IsNullOrWhiteSpace(($saida | Out-String)))
    } catch {
        return $true
    }
}

foreach ($area in $areas) {
    $caixaDir = Join-Path (Join-Path $conhecimentoDir "entrada") $area.Nome
    if (-not (Test-Path $caixaDir)) { continue }

    $entradas = @(Get-ChildItem $caixaDir -Filter *.md -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($entradas.Count -eq 0) { continue }

    $destinoPath = Join-Path $conhecimentoDir $area.Destino
    if (-not (Test-Path $destinoPath)) {
        [Console]::Error.WriteLine("[mesclar-conhecimento] destino ausente: $destinoPath")
        $houveErro = $true
        continue
    }

    $rel = "conhecimento/$($area.Destino)"
    if (Test-DestinoOcupado -RaizRepo $Raiz -RelPath $rel) {
        [Console]::Out.WriteLine("[mesclar-conhecimento] ADIA $($area.Nome): $($area.Destino) esta modificado na arvore (outra sessao mexendo).")
        [Console]::Out.WriteLine("[mesclar-conhecimento]   $($entradas.Count) entrada(s) ficam na caixa pro proximo checkpoint. Isso nao e erro.")
        $adiados += $entradas.Count
        continue
    }

    $texto  = Read-Texto $destinoPath
    $comBom = Test-TemBom $destinoPath
    $eol    = Get-Eol $texto
    $prontas = @()   # entradas validadas E ja aplicadas em $texto

    foreach ($e in $entradas) {
        $slugArquivo = [IO.Path]::GetFileNameWithoutExtension($e.Name)
        $corpo  = (Read-Texto $e.FullName).TrimEnd()
        $linhasE = [regex]::Split($corpo, "`r`n|`n")

        # --- validacao (entrada invalida FICA na caixa; descartar perderia o verbete) ---
        $fences = ([regex]::Matches($corpo, '(?m)^```')).Count
        if ($fences % 2 -ne 0) {
            [Console]::Error.WriteLine("[mesclar-conhecimento] $($e.Name): bloco de codigo aberto e nunca fechado (cega o gate dali pra frente).")
            $houveErro = $true; continue
        }

        # '##' sem ancora fechando a linha e defeito, nao subtitulo: verbete do monolito usa
        # '**Negrito:**' pra secao. Um '##' solto viraria VERBETE NOVO depois do merge, sem
        # ancora e sem tags -- e o gate seguinte barraria o arquivo inteiro. O gate ja acusava;
        # o mesclador ignorava (divergencia apontada pelo R11, 2026-08-16).
        $headingSolto = $null
        $fence = $false
        foreach ($l in $linhasE) {
            if ($l -match '^```') { $fence = -not $fence; continue }
            if ($fence) { continue }
            # '^##$' (crase pelada, sem titulo nem ancora) entra junto: nenhum dos dois lados
            # pegava, e mesclada ela vira titulo vazio no monolito, denunciado so por um gate
            # posterior e sem explicar a causa (R11, 2026-08-16).
            if (($l -match '^##[ \t]' -or $l -match '^##\s*$') -and $l -notmatch '\{#[^}]+\}[ \t]*\r?$') { $headingSolto = $l; break }
        }
        if ($headingSolto) {
            [Console]::Error.WriteLine("[mesclar-conhecimento] $($e.Name): linha '##' sem ancora {#slug} fechando a linha -- viraria verbete novo e invisivel no monolito:")
            [Console]::Error.WriteLine("[mesclar-conhecimento]   $($headingSolto.Trim())")
            $houveErro = $true; continue
        }

        $titulos = @(Get-TitulosForaDeFence $linhasE)
        if ($titulos.Count -ne 1) {
            [Console]::Error.WriteLine("[mesclar-conhecimento] $($e.Name): esperava EXATAMENTE 1 titulo '## ... {#slug}' fora de bloco de codigo, achei $($titulos.Count).")
            $houveErro = $true; continue
        }
        $titulo  = $titulos[0].Titulo
        $slugInt = $titulos[0].Slug

        if ($slugInt -cne $slugArquivo) {
            [Console]::Error.WriteLine("[mesclar-conhecimento] $($e.Name): slug interno '{#$slugInt}' diverge do nome do arquivo '$slugArquivo'.")
            [Console]::Error.WriteLine("[mesclar-conhecimento]   O nome do arquivo E o slug -- e o que torna o merge deterministico e o split futuro mecanico.")
            $houveErro = $true; continue
        }

        if (-not (Test-TemTags $linhasE)) {
            [Console]::Error.WriteLine("[mesclar-conhecimento] $($e.Name): sem linha 'tags:' na janela apos o titulo (a busca de conhecimento nao acharia).")
            $houveErro = $true; continue
        }

        if ((Get-SlugsExistentes $texto) -contains $slugInt) {
            [Console]::Error.WriteLine("[mesclar-conhecimento] $($e.Name): o slug '#$slugInt' JA existe em $($area.Destino) -- duplicata quebraria os links das duas.")
            $houveErro = $true; continue
        }

        # --- merge (em memoria; o disco so e tocado depois que TODAS foram processadas) ---
        # Indice = a PRIMEIRA sequencia contigua de linhas '- ['. Ancorar no fim dessa
        # sequencia, e nao no ultimo '- [' do arquivo, porque corpo de verbete tambem tem
        # lista com link -- ancorar no ultimo jogaria a linha de indice no meio de um verbete.
        $linhas = [regex]::Split($texto, "`r`n|`n")
        $iniIndice = -1; $fimIndice = -1
        for ($i = 0; $i -lt $linhas.Count; $i++) {
            if ($linhas[$i] -match '^- \[') {
                if ($iniIndice -lt 0) { $iniIndice = $i }
                $fimIndice = $i
            } elseif ($iniIndice -ge 0) {
                break
            }
        }
        if ($iniIndice -lt 0) {
            [Console]::Error.WriteLine("[mesclar-conhecimento] $($area.Destino): nao achei o bloco de indice ('- [...]'). Nao vou adivinhar onde inserir.")
            $houveErro = $true; continue
        }

        $novaLinha = "- [$titulo](#$slugInt)"
        # A cauda precisa de guarda: se o indice for a ULTIMA linha, o range vira
        # Count..(Count-1) e no PowerShell range decrescente conta PRA TRAS -- devolve
        # @($null, ultimo) e DUPLICA a ultima linha do indice, calado. So acontece em arquivo
        # sem quebra de linha final, que e por onde ninguem testa (R11, 2026-08-16).
        $cauda = @()
        if ($fimIndice -lt ($linhas.Count - 1)) { $cauda = @($linhas[($fimIndice + 1)..($linhas.Count - 1)]) }
        $linhas = @($linhas[0..$fimIndice]) + @($novaLinha) + $cauda
        # Se o arquivo ja termina em '---', nao acrescente outro: '---\n\n---' polui o diff e
        # desvia o foco de quem revisa (R11, 2026-08-16).
        # Olhar a ULTIMA linha, nao o arquivo: '(?m)^---$' casaria qualquer separador do meio
        # e o script nunca acrescentaria o dele.
        $textoBase   = ($linhas -join $eol).TrimEnd()
        $ultimaLinha = ([regex]::Split($textoBase, "`r`n|`n"))[-1]
        $sep = if ($ultimaLinha -match '^---[ \t]*$') { "$eol$eol" } else { "$eol$eol---$eol$eol" }
        $texto = $textoBase + $sep + ($corpo -replace "`r`n|`n", $eol) + $eol
        $prontas += [pscustomobject]@{ Arquivo = $e; Slug = $slugInt }
    }

    # Grava UMA vez, e so se algo mudou. Reescrever sem ter mesclado nada so gera ruido.
    if ($prontas.Count -gt 0) {
        try {
            Write-Texto $destinoPath $texto $comBom
        } catch {
            # A caixa e DURAVEL: se o destino nao pode ser gravado, as entradas continuam la.
            # Remover antes de gravar trocaria colisao de git por PERDA de verbete -- o unico
            # desfecho pior que o problema que a caixa existe pra resolver (R11, 2026-08-16).
            [Console]::Error.WriteLine("[mesclar-conhecimento] FALHA ao gravar $($area.Destino): $($_.Exception.Message)")
            [Console]::Error.WriteLine("[mesclar-conhecimento]   As $($prontas.Count) entrada(s) continuam na caixa. Nada foi perdido.")
            $houveErro = $true
            continue
        }
        foreach ($p in $prontas) {
            try {
                Remove-Item $p.Arquivo.FullName -Force
            } catch {
                # Gravado no monolito E ainda na caixa: o proximo checkpoint acusaria slug
                # duplicado e o operador nao teria como saber por que. Excecao crua aqui deixa
                # o estado ambiguo; a mensagem tem de dizer o que ja aconteceu e o que fazer.
                [Console]::Error.WriteLine("[mesclar-conhecimento] NAO consegui tirar $($p.Arquivo.Name) da caixa: $($_.Exception.Message)")
                [Console]::Error.WriteLine("[mesclar-conhecimento]   ATENCAO: o verbete #$($p.Slug) JA ESTA EM $($area.Destino). Apague o arquivo da caixa a mao,")
                [Console]::Error.WriteLine("[mesclar-conhecimento]   senao o proximo checkpoint vai acusar slug duplicado sem explicar a causa.")
                $houveErro = $true
                continue
            }
            $mesclados++
            [Console]::Out.WriteLine("[mesclar-conhecimento] mesclado: $($area.Nome)/$($p.Arquivo.Name) -> $($area.Destino) (#$($p.Slug))")
        }
    }
}

if ($mesclados -eq 0 -and $adiados -eq 0 -and -not $houveErro) {
    [Console]::Out.WriteLine("[mesclar-conhecimento] caixa vazia -- nada a mesclar.")
}
if ($mesclados -gt 0) {
    [Console]::Out.WriteLine("[mesclar-conhecimento] $mesclados verbete(s) mesclado(s). Revise o diff antes de commitar.")
}
if ($houveErro) {
    [Console]::Error.WriteLine("[mesclar-conhecimento] houve entrada(s) INVALIDA(s) -- elas ficaram na caixa. Corrija e rode de novo.")
    exit 1
}
exit 0
