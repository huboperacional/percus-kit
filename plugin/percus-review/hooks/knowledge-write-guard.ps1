#requires -Version 5.1
# Hook PreToolUse Percus -- guarda de CAMINHO (nao de comando).
#
# Recusa escrita em dois alvos da base de conhecimento, por motivos diferentes:
#
#   1. conhecimento/COMO_*.md (os dois monolitos) -- APOSENTADOS na 6.38.0. A forma glob aqui
#      e de proposito: o bloco 2c do gate barra quem escreve o caminho completo, e um comentario
#      nao pode ser a excecao que fura a propria regra que o arquivo enforca.
#      Recriar um deles ressuscita o objeto que causava colisao entre sessoes e
#      custava ~13k tokens de indice em toda consulta. Nao e "arquivo velho": e um formato
#      que foi medido e abandonado.
#
#   2. conhecimento/<area>/INDICE.md -- GERADO por scripts/gerar-indice-conhecimento.ps1.
#      Editar a mao produz indice divergente do conteudo, que foi exatamente o defeito que
#      deixou 14 verbetes invisiveis por semanas (medido 2026-08-18).
#
# O que ele NAO barra, e de proposito: escrever conhecimento/<area>/<slug>.md. Esse e o
# caminho abencoado -- um arquivo por verbete, sem merge, sem espera, sem colisao.
#
# Por que existe: a regra estava escrita em TRES lugares (R23, skill consult-knowledge,
# LEIA-ME da area) e enforcada em NENHUM -- os hooks registrados casavam Bash|PowerShell ou
# ExitPlanMode, nunca Edit/Write. Enforcement ENUMERA tools: toda tool nova nasce fora da
# guarda ate alguem somar.
#
# NAO ramifica por tool_name: Edit e Write trazem o alvo no MESMO campo (tool_input.file_path).
#
# LIMITE DECLARADO -- o matcher cobre Edit e Write, e NAO cobre Bash/PowerShell. Escrita por
# redirecionamento, tee, Set-Content ou heredoc contra os mesmos alvos passa por aqui sem ser
# vista; a rede nesse caso e o gate de commit (blocos 2c e 2d), que chega quando o conteudo ja
# esta no disco. Isso e escolha de escopo do operador, nao esquecimento -- mas esta escrito
# porque a classe "enforcement enumera tools, e a tool N+1 nasce fora da guarda" ja mordeu duas
# vezes neste kit (matcher so-Bash em 2026-07-31, ausencia de Edit/Write em 2026-08-18). Ver
# conhecimento/resolver/regra-escrita-em-n-lugares-e-enforcada-em-nenhum.md.
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

    # As MESMAS 4 areas que _AREAS_CONHECIMENTO declara no percus-gate.sh e que o gerador de
    # indice cobre. Cobrir so 'conhecimento/' deixava passar a edicao a mao de
    # referencia/conhecimento/<area>/INDICE.md -- e o comentario deste arquivo ja prometia "as
    # mesmas areas" sem cumprir, que e a mesma classe de promessa vazia que o R11 pegou no
    # comentario de portabilidade do awk (2026-08-18).
    $ehMonolito = $normalizado -match '(?i)(^|/)(referencia/)?conhecimento/COMO_(RESOLVER|FAZER)\.md$'
    $ehIndice   = $normalizado -match '(?i)(^|/)(referencia/)?conhecimento/(resolver|fazer)/INDICE\.md$'

    if (-not ($ehMonolito -or $ehIndice)) { exit 0 }

    [Console]::Error.WriteLine("")
    if ($ehMonolito) {
        $area = if ($normalizado -match '(?i)COMO_FAZER\.md$') { "fazer" } else { "resolver" }
        [Console]::Error.WriteLine("[percus:hook knowledge-write] BLOCK (R23):")
        [Console]::Error.WriteLine("  Alvo: $alvo")
        [Console]::Error.WriteLine("  Razao: esse monolito foi APOSENTADO na 6.38.0. Recria-lo ressuscita")
        [Console]::Error.WriteLine("         a colisao entre sessoes e o custo de indice por consulta.")
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine("  A base agora e UM ARQUIVO POR VERBETE:")
        [Console]::Error.WriteLine("    conhecimento/$area/<slug>.md")
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine("  O nome do arquivo E o slug da ancora ('## Titulo {#slug}').")
        [Console]::Error.WriteLine("  Escreva direto: nao ha merge, nao ha caixa de entrada, nao ha espera.")
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine("  Para achar por classe de sintoma:")
        [Console]::Error.WriteLine("    grep -l ""tags:.*<termo>"" conhecimento/$area/*.md")
    } else {
        [Console]::Error.WriteLine("[percus:hook knowledge-write] BLOCK (R23):")
        [Console]::Error.WriteLine("  Alvo: $alvo")
        [Console]::Error.WriteLine("  Razao: INDICE.md e GERADO. Editar a mao produz indice divergente do")
        [Console]::Error.WriteLine("         conteudo -- foi assim que 14 verbetes ficaram invisiveis.")
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine("  Regenere depois de escrever o verbete:")
        [Console]::Error.WriteLine("    pwsh -File scripts/gerar-indice-conhecimento.ps1")
    }
    [Console]::Error.WriteLine("")
    [Console]::Error.WriteLine("  Escape (edicao estrutural legitima, ex. migracao em lote):")
    [Console]::Error.WriteLine("    PERCUS_SKIP_KNOWLEDGE_GUARD=1")
    [Console]::Error.WriteLine("")
    exit 2
} catch {
    # Falha graceful -- nao bloqueia injustamente
    [Console]::Error.WriteLine("[percus:hook knowledge-write] erro interno (skip): $($_.Exception.Message)")
    exit 0
}
