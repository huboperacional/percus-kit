#requires -Version 5.1
<#
.SYNOPSIS
  Mede no canon qual e a ultima regra (R<N>) e monta a faixa citada ao revisor.

.DESCRIPTION
  Existe porque a faixa estava LITERAL em 36 lugares, em TRES tetos que discordavam entre si
  (13 no deepseek-review, 19 no council/consult/review, 23 no analyze), com o canon em 25.
  O revisor recebia um teto velho e respondia que as regras acima dele "nao existem", com a
  confianca de quem cita documentacao. Verbete:
  conhecimento/resolver/revisor-cita-faixa-de-regras-fixa-no-prompt-e-reprova-regra-valida.md

  Trocar o literal pelo teto de hoje nao seria conserto: so reiniciaria o relogio ate a
  proxima regra, e reabriria os 36 sitios. Aqui o numero e MEDIDO a cada execucao.

  DUAS RESPOSTAS DIFERENTES, DE PROPOSITO. "medi e deu 25" e "nao consegui medir" nao podem
  desembocar no mesmo lugar -- e essa fusao que produz gate que passa calado (a mesma classe
  de docs/superpowers/specs/2026-09-12-r11-gate-negativa-bem-sucedida-design.md). Quando nao
  da pra medir, a faixa NAO e chutada: o prompt diz que a faixa faltou e aponta a fonte.
#>

function Get-PercusCanonDir {
    <#
      Ordem: -CanonDir explicito > $env:PERCUS_CANON_DIR > sobe a arvore procurando o canon.
      O explicito vence ABSOLUTAMENTE (nao cai pros outros se estiver vazio de canon): quem
      passa o diretorio esta perguntando sobre AQUELE canon, e responder sobre outro seria
      medir a coisa errada em silencio.
    #>
    param([string]$CanonDir)

    if ($CanonDir) { return $CanonDir }
    if ($env:PERCUS_CANON_DIR) { return $env:PERCUS_CANON_DIR }

    $dir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    for ($i = 0; $i -lt 8 -and $dir; $i++) {
        if (Test-Path (Join-Path $dir "01_REGRAS_INEGOCIAVEIS.md")) { return $dir }
        $pai = Split-Path $dir -Parent
        if ($pai -eq $dir) { break }
        $dir = $pai
    }
    return $null
}

function Get-PercusCanonMaxRule {
    <#
      Devolve [int] o maior N de "^## R<N>." em 01_REGRAS_INEGOCIAVEIS.md.
      Devolve 0 quando NAO CONSEGUIU MEDIR -- 0 nao e um teto, e a ausencia de medida.

      Ancorado em "^##" de proposito: o canon cita "R23" dentro do corpo de outras regras
      dezenas de vezes, e contar citacao em vez de cabecalho e exatamente o erro que este
      arquivo existe pra nao repetir (a 1a versao do verbete viu "R23" no corpo e concluiu
      que o teto era 23; era 25).

      Nao assume ordem: o canon de hoje declara R13 DEPOIS de R19. Por isso maximo, nao
      ultimo -- "o ultimo que eu vi" ja errou por dois uma vez.
    #>
    [OutputType([int])]
    param([string]$CanonDir)

    $dir = Get-PercusCanonDir -CanonDir $CanonDir
    if (-not $dir) { return 0 }

    $arq = Join-Path $dir "01_REGRAS_INEGOCIAVEIS.md"
    if (-not (Test-Path $arq)) { return 0 }

    try {
        # [IO.File]::ReadAllText decodifica UTF-8 nos dois runtimes. Get-Content sem
        # -Encoding leria ANSI sob PS 5.1 -- a classe de hooks-leitura-utf8.tests.ps1.
        $texto = [IO.File]::ReadAllText($arq)
    } catch {
        return 0
    }

    $ns = [regex]::Matches($texto, '(?m)^##\s+R(\d+)\.') |
        ForEach-Object { [int]$_.Groups[1].Value }
    if (-not $ns) { return 0 }

    return ([int](($ns | Measure-Object -Maximum).Maximum))
}

function Get-PercusRegrasDoCanon {
    <#
      Lista das regras do canon, uma por linha, no formato "R<N> — <titulo>".
      Devolve a frase degradada quando NAO conseguiu ler -- nunca uma lista inventada.

      Existe porque os system-prompt-*.md carregavam uma COPIA INLINE das 19 primeiras
      regras, escrita a mao numa numeracao anterior a renumeracao do canon: 7 das 19 traziam
      o texto errado debaixo do numero certo (R1, R2, R4, R6, R8, R9, R12). E pior que a
      faixa curta -- aquela tornava a regra invisivel, esta faz o revisor avaliar com
      conviccao contra uma definicao que nao existe mais. Verbete:
      conhecimento/resolver/system-prompt-do-revisor-tem-copia-do-canon-com-texto-de-regra-errado.md

      ORDENA por numero, nao pela ordem do arquivo: o canon declara R13 DEPOIS de R19.
    #>
    [OutputType([string])]
    param([string]$CanonDir)

    $degradado = "(nao foi possivel ler as regras do canon -- consulte 01_REGRAS_INEGOCIAVEIS.md)"

    $dir = Get-PercusCanonDir -CanonDir $CanonDir
    if (-not $dir) { return $degradado }
    $arq = Join-Path $dir "01_REGRAS_INEGOCIAVEIS.md"
    if (-not (Test-Path $arq)) { return $degradado }

    try {
        $texto = [IO.File]::ReadAllText($arq)
    } catch {
        return $degradado
    }

    # `\s*$` no fim tambem come o \r de arquivo CRLF -- sem isso o par .sh diverge.
    $ms = [regex]::Matches($texto, '(?m)^##\s+R(\d+)\.\s*(.+?)\s*$')
    if ($ms.Count -eq 0) { return $degradado }

    $linhas = $ms |
        Sort-Object { [int]$_.Groups[1].Value } |
        ForEach-Object { "R$($_.Groups[1].Value) — $($_.Groups[2].Value)" }

    return ($linhas -join "`n")
}

function Get-PercusFaixaRegras {
    <#
      Trecho pronto pra embutir no prompt do revisor.
        mediu     -> a faixa "R1-" ate o teto medido (hoje 25)
        nao mediu -> "faixa nao medida -- consulte 01_REGRAS_INEGOCIAVEIS.md"

      O ramo degradado NAO cita faixa nenhuma: inventar teto sem ter lido o canon e o defeito
      original vestido de fallback. Ele tambem nao fica mudo -- diz que faltou, pra quem le a
      resposta do revisor saber que aquele review rodou sem o teto.
    #>
    [OutputType([string])]
    param([string]$CanonDir)

    $max = Get-PercusCanonMaxRule -CanonDir $CanonDir
    if ($max -le 0) { return "faixa nao medida -- consulte 01_REGRAS_INEGOCIAVEIS.md" }
    return "R1-R$max"
}
