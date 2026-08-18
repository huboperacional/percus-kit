#requires -Version 5.1
# Hook PreToolUse Percus -- guarda de CAMINHO (nao de comando).
#
# Recusa escrita direta nos monolitos de conhecimento e aponta a caixa de entrada.
# R23 manda escrever um arquivo por verbete em conhecimento/entrada/<area>/<slug>.md; o
# monolito e escrito UMA vez, pelo mesclador, no checkpoint.
#
# Por que ele existe: a regra estava escrita em TRES lugares (01_REGRAS_INEGOCIAVEIS.md R23,
# skill consult-knowledge, entrada/LEIA-ME.md) e enforcada em NENHUM -- os 12 hooks
# registrados casavam Bash|PowerShell ou ExitPlanMode, nunca Edit/Write. Medido em
# 2026-08-18: 14 verbetes entraram por esse caminho sem ancora, sem tags: e fora do indice;
# 11 estavam commitados havia semanas e o gate nao via nenhum.
#
# NAO ramifica por tool_name: Edit e Write trazem o alvo no MESMO campo (tool_input.file_path).
# Mesma licao do teste de guarda de comando -- ramificar por nome da tool cria hook que o
# matcher entrega e o script descarta em silencio.
#
# Falha graceful: qualquer erro -> exit 0 (nao bloqueia injustamente).

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    if ($env:PERCUS_HOOKS_DISABLED -eq "1") { exit 0 }
    if ($env:PERCUS_SKIP_KNOWLEDGE_GUARD -eq "1") { exit 0 }

    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin -or $stdin.Trim() -eq '') { exit 0 }

    $inputObj = $stdin | ConvertFrom-Json -ErrorAction Stop
    $alvo = $inputObj.tool_input.file_path
    if (-not $alvo) { exit 0 }

    # Normaliza a barra ANTES de casar: o agente manda caminho absoluto do Windows na maioria
    # das chamadas reais, e um padrao so com '/' seria guarda que nunca dispara no uso real.
    $normalizado = ($alvo -replace '\\', '/')

    # Ancorado no FIM: 'conhecimento/COMO_RESOLVER.md' casa em relativo e em absoluto, e nao
    # casa em conhecimento/entrada/... -- que e exatamente para onde o guard manda ir.
    if ($normalizado -notmatch '(?i)conhecimento/COMO_(RESOLVER|FAZER)\.md$') { exit 0 }

    $monolito = if ($normalizado -match '(?i)COMO_FAZER\.md$') { "COMO_FAZER.md" } else { "COMO_RESOLVER.md" }
    $area     = if ($monolito -eq "COMO_FAZER.md") { "fazer" } else { "resolver" }

    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("[percus:hook knowledge-write] BLOCK (R23):")
    [Console]::Error.WriteLine("  Alvo: $alvo")
    [Console]::Error.WriteLine("  Razao: o monolito de conhecimento nao se edita direto.")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  Escreva UM ARQUIVO POR VERBETE na caixa de entrada:")
    [Console]::Error.WriteLine("    conhecimento/entrada/$area/<slug>.md")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  O nome do arquivo E o slug da ancora ('## Titulo {#slug}').")
    [Console]::Error.WriteLine("  O mesclador anexa no $monolito e insere a linha de indice sozinho,")
    [Console]::Error.WriteLine("  num ato so, no checkpoint (scripts/mesclar-conhecimento.ps1).")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  Por que: o monolito tem centenas de verbetes num arquivo so e o git")
    [Console]::Error.WriteLine("  resolve conflito em ARQUIVO -- duas sessoes escrevendo licoes sobre")
    [Console]::Error.WriteLine("  assuntos diferentes colidem assim mesmo. Arquivo separado = colisao zero.")
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  Escape (edicao estrutural legitima, ex. consertar ancoras em lote):")
    [Console]::Error.WriteLine("    PERCUS_SKIP_KNOWLEDGE_GUARD=1")
    [Console]::Error.WriteLine("")
    exit 2
} catch {
    # Falha graceful -- nao bloqueia injustamente
    [Console]::Error.WriteLine("[percus:hook knowledge-write] erro interno (skip): $($_.Exception.Message)")
    exit 0
}
