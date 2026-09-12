#requires -Version 5.1
# Hook PreToolUse:Bash|PowerShell Percus -- gate [S] mecanico. WARN-ONLY: exit 0 sempre.
#
# Avisa quando um `git commit` leva uma spec (docs/superpowers/specs/*.md) que o conselho nunca
# analisou.
#
# Por que existe: o canon manda, em TRES lugares -- 01_REGRAS_INEGOCIAVEIS.md:316,
# v2/CONSTITUICAO.md:35 e v2/loops/spec.md -- que o agente rode `spec-analyze` sozinho ao finalizar
# uma spec, "sem pedir permissao". A promessa IRMA da mesma frase ("ao finalizar um plano ->
# council-pre-mortem") tem hook desde sempre (pre-plan-exit); a da spec nao tinha nenhum. Metade do
# par ficou dependendo de alguem lembrar -- e em 2026-09-12 o proprio agente escreveu, commitou e
# apresentou uma spec sem rodar o analyze. So o operador perguntando revelou. CONSTITUICAO Sec. 6:
# regra que depende de alguem lembrar ja falhou.
#
# WARN-ONLY de proposito: a frota tem specs antigas sem analyze, e bloqueio que dispara em massa no
# primeiro dia vira escape declarado -- foi o que o teto do CONTEXT.md ensinou. Promover a bloqueio
# e decisao separada, depois de medir quanto a frota reclama.
#
# Escape: PERCUS_SKIP_SPEC_ANALYZE=1. Falha graciosa: qualquer erro -> exit 0.

. "$PSScriptRoot\_helpers.ps1"

# O que identifica o MESMO documento entre versoes: o titulo (primeira linha `# ...`). O que
# identifica a MESMA versao: o texto todo, normalizado. A distincao importa porque "analisei a v1 e
# commitei a v2" pede acao diferente de "nunca analisei" -- dizer so "sem analyze" mandaria o agente
# rodar do zero sem saber que ja houve um.
function Get-SpecAssinatura {
    param([string]$Texto)
    if (-not $Texto) { return $null }
    $titulo = ($Texto -split "`n" | Where-Object { $_ -match '^\s*#\s+\S' } | Select-Object -First 1)
    if ($titulo) { $titulo = $titulo.Trim() }
    # Normaliza CRLF/LF e espacos: o log grava o prompt como o orchestrator o recebeu, e uma
    # diferenca de quebra de linha nao e uma diferenca de conteudo.
    $norm = ($Texto -replace "`r`n", "`n").Trim()
    $norm = [regex]::Replace($norm, '[ \t]+', ' ')
    return [pscustomobject]@{ Titulo = $titulo; Normalizado = $norm }
}

$prevEnc = [Console]::OutputEncoding
try {
    # A saida de `git show` passa pelo decodificador do console; sem UTF-8 aqui, um travessao na
    # spec volta corrompido e o texto NUNCA casa com o prompt do log (que e lido como UTF-8).
    # O hook ficaria avisando "sem analyze" em toda spec com acento -- ruido que faz desligar o
    # hook. Mesmo cuidado do crud-evidence-warn.
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin) { exit 0 }
    if ($env:PERCUS_SKIP_SPEC_ANALYZE) { exit 0 }

    try { $payload = $stdin | ConvertFrom-Json } catch { exit 0 }
    $command = "$($payload.tool_input.command)"
    if (-not $command) { exit 0 }
    if ($command -notmatch '\bgit\b[^|;&]*\bcommit\b') { exit 0 }

    $projectRoot = Resolve-PercusProjectRoot -Command $command
    if (-not $projectRoot) { exit 0 }

    $staged = @(Get-PercusStagedFiles -ProjectRoot $projectRoot)
    $specs = @($staged | Where-Object { $_ -match '(^|/)docs/superpowers/specs/[^/]+\.md$' })
    if ($specs.Count -eq 0) { exit 0 }

    # Le so os logs de analyze, do mais recente pro mais antigo, e para no primeiro que casa.
    # Teto de 50: a pasta cresce por sessao e ler tudo a cada commit pagaria o historico inteiro.
    $logDir = Join-Path $projectRoot ".deepseek\council-log"
    $logs = @()
    if (Test-Path -LiteralPath $logDir) {
        $logs = @(Get-ChildItem -LiteralPath $logDir -Filter "*-analyze.jsonl" -File -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 50)
    }

    $semAnalyze = New-Object System.Collections.Generic.List[string]
    $desatualizadas = New-Object System.Collections.Generic.List[string]

    foreach ($spec in $specs) {
        # O conteudo que importa e o STAGED (o que o commit leva), nao o do disco.
        $texto = (& git -C $projectRoot show ":$spec" 2>$null) -join "`n"
        if (-not $texto) { continue }
        $assin = Get-SpecAssinatura $texto
        if (-not $assin) { continue }

        $coberta = $false
        $viuTitulo = $false
        foreach ($log in $logs) {
            # JSONL: o sufixo promete UM objeto por linha. Hoje o orchestrator grava um so, mas
            # ConvertFrom-Json no arquivo inteiro devolve $null se algum dia gravar dois -- e o
            # hook passaria a dizer "nenhum analyze" em spec ANALISADA, falso negativo silencioso.
            # O .sh le linha a linha pelo MESMO motivo: `jq -r .prompt arquivo` com dois objetos
            # emite os dois prompts colados, que o normalizar cola em um so e nunca casa.
            $linhasLog = [System.IO.File]::ReadAllLines($log.FullName)
            foreach ($linhaLog in $linhasLog) {
                if (-not $linhaLog -or -not $linhaLog.Trim()) { continue }
                $prompt = $null
                try { $prompt = ($linhaLog | ConvertFrom-Json).prompt } catch { $prompt = $null }
                if (-not $prompt) { continue }
                $pa = Get-SpecAssinatura $prompt
                if (-not $pa) { continue }
                if ($pa.Normalizado -eq $assin.Normalizado) { $coberta = $true; break }
                if ($assin.Titulo -and $pa.Titulo -eq $assin.Titulo) { $viuTitulo = $true }
            }
            if ($coberta) { break }
        }

        if ($coberta) { continue }
        if ($viuTitulo) { [void]$desatualizadas.Add($spec) } else { [void]$semAnalyze.Add($spec) }
    }

    if ($semAnalyze.Count -eq 0 -and $desatualizadas.Count -eq 0) { exit 0 }

    $e = [Console]::Error
    $e.WriteLine("[percus:hook spec-analyze] AVISO (nao bloqueia): spec indo pro commit sem analyze do conselho.")
    foreach ($s in $semAnalyze) {
        $e.WriteLine("  - $s -- nenhum analyze encontrado em .deepseek/council-log/")
    }
    foreach ($s in $desatualizadas) {
        $e.WriteLine("  - $s -- ha analyze desta spec, mas o texto mudou desde entao (versao anterior)")
    }
    $e.WriteLine("O canon manda rodar sozinho, sem pedir permissao (01_REGRAS_INEGOCIAVEIS.md R9, v2/loops/spec.md):")
    $e.WriteLine("  skill percus-review:spec-analyze  --  ou council-orchestrator.ps1 -Mode analyze -Providers 'deepseek,groq-llama,cross-claude'")
    $e.WriteLine("Veredito AJUSTAR/BLOQUEADA: corrija antes de a feature virar [0]. Escape: PERCUS_SKIP_SPEC_ANALYZE=1")
    exit 0
} catch {
    exit 0
} finally {
    [Console]::OutputEncoding = $prevEnc
}
