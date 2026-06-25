#requires -Version 5.1
<#
.SYNOPSIS
  Council orchestrator: roda DeepSeek + Llama em paralelo (PowerShell jobs), agrega resultados.

.DESCRIPTION
  Le prompt via -PromptFile (path) ou stdin. Dispara providers em paralelo.
  Para Cross-Claude (Sonnet subagent), emite marker `__PERCUS_NEEDS_CROSS_CLAUDE__`
  em stderr — agente principal deve dispatchear subagent e re-invocar com -CrossClaudeFile.

  Output: JSON em stdout com array de respostas + sintese sugerida (heuristic).
  Log: .deepseek/council-log/<timestamp>.jsonl

  F2 — Code Context Injection: quando -CodeContextDir eh passado, ou quando o prompt
  contem blocos ```file:path```, os arquivos sao lidos e injetados no system prompt.
  Providers devem validar claims antes de opinar (anti-alucinacao).

.PARAMETER PromptFile
  Path do arquivo com prompt user. Se omitido, le stdin.

.PARAMETER SystemPrompt
  System prompt comum a todos providers.

.PARAMETER Providers
  Comma-separated: "deepseek,groq-llama" (default) OU "deepseek,groq-llama,cross-claude".

.PARAMETER CrossClaudeFile
  Path pra arquivo com resposta do subagent Cross-Claude (pre-coletada pelo agente).
  Se passar, orquestrator inclui no agregado sem emitir marker.

.PARAMETER Mode
  "consult" (default), "pre-mortem", "review". Afeta system prompt sugerido.

.PARAMETER CodeContextDir
  [F2] Pasta com arquivos de codigo curados (*.py, *.ts, *.tsx, *.js, *.go, *.rs, *.ps1, *.sh, *.md).
  Quando presente, arquivos sao injetados no system prompt pra validacao de claims.
  Limite: 8 arquivos, 2000 tokens por arquivo (MaxTokensPerFile). Se CodeContextDir passado,
  blocks ```file:path``` no prompt sao ignorados (Caminho A precede Caminho B).

.PARAMETER MaxTokensPerFile
  [F2] Limite de tokens por arquivo de codigo injetado (default: 2000).

.EXAMPLE
  echo "Devo renomear users.name?" | .\council-orchestrator.ps1
  .\council-orchestrator.ps1 -PromptFile q.txt -Providers "deepseek,groq-llama,cross-claude"
  .\council-orchestrator.ps1 -PromptFile q.txt -CodeContextDir ./src/services -Mode review
#>
[CmdletBinding()]
param(
    [string]$PromptFile,
    [string]$SystemPrompt,
    [string]$Providers = "deepseek,groq-llama",
    [string]$CrossClaudeFile,
    [ValidateSet("consult","pre-mortem","review","analyze")]
    [string]$Mode = "consult"
    ,[int]$MaxInputTokens = 8000
    ,[string]$DeepSeekModel = "deepseek-chat"
    ,[string]$GroqModel     = "llama-3.3-70b-versatile"
    ,[AllowEmptyString()]
    [ValidateSet("claude-haiku-4-5","claude-sonnet-4-6","claude-opus-4-7","")]
    [string]$CrossClaudeModel = ""
    # F2 — code context injection
    ,[string]$CodeContextDir = ""
    ,[int]$MaxTokensPerFile  = 2000
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Load .env (best-effort, antes de checar ANTHROPIC_API_KEY pra direct cross-claude)
$_envPath = Join-Path (Get-Location) '.env'
if (Test-Path $_envPath) {
    Get-Content $_envPath | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$' -and $_ -notmatch '^\s*#') {
            $name = $matches[1]; $val = $matches[2] -replace '^["'']|["'']$', ''
            if (-not (Get-Item -Path "env:$name" -ErrorAction SilentlyContinue)) {
                Set-Item -Path "env:$name" -Value $val
            }
        }
    }
}

function Measure-Tokens([string]$text) {
    if (-not $text) { return 0 }
    # Heuristica conservadora: 1 token ~ 3.5 chars (overestima leve, evita undertruncate)
    return [int]([Math]::Ceiling($text.Length / 3.5))
}

function Limit-Prompt([string]$text, [int]$maxTok) {
    $tok = Measure-Tokens $text
    if ($tok -le $maxTok) { return @{ text = $text; truncated = $false; original_tokens = $tok } }
    # Preservar 1000 tokens iniciais (~3500 chars) + resto final
    $headChars = 3500
    $tailChars = [int](($maxTok - 1000) * 3.5)
    if ($tailChars -lt 1000) { $tailChars = 1000 }
    if ($text.Length -le $headChars + $tailChars) { return @{ text = $text; truncated = $false; original_tokens = $tok } }
    $head = $text.Substring(0, $headChars)
    $tail = $text.Substring($text.Length - $tailChars)
    $cut = $tok - $maxTok
    $newText = "$head`n`n[...TRUNCATED ~$cut tokens...]`n`n$tail"
    return @{ text = $newText; truncated = $true; original_tokens = $tok }
}

# ---------------------------------------------------------------------------
# F2 — Get-CodeContext: lê arquivos de codigo e retorna hashtable path->content
# Caminho A: -CodeContextDir (pasta curada, precede B)
# Caminho B: parser de blocks ```file:path``` no prompt
# Limite: MaxTokensPerFile tokens/arquivo, 8 arquivos total
# ---------------------------------------------------------------------------
function Get-CodeContext {
    param(
        [string]$ContextDir,
        [string]$PromptText,
        [int]$MaxTokPerFile,
        [string]$CWD
    )
    $result = [ordered]@{}
    $FileBlockPattern = '```file:([^\s`]+)'
    $maxFiles = 8
    $extensions = @('*.py','*.ts','*.tsx','*.js','*.go','*.rs','*.ps1','*.sh','*.md')

    if ($ContextDir -and (Test-Path $ContextDir)) {
        # Caminho A: pasta curada
        $files = @()
        foreach ($ext in $extensions) {
            $files += Get-ChildItem -Path $ContextDir -Filter $ext -File -ErrorAction SilentlyContinue
        }
        if ($files.Count -gt $maxFiles) {
            [Console]::Error.WriteLine("[council-orchestrator][F2] AVISO: CodeContextDir tem $($files.Count) arquivos; usando primeiros $maxFiles.")
            $files = $files | Select-Object -First $maxFiles
        }
        foreach ($f in $files) {
            $raw = Get-Content $f.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if (-not $raw) { continue }
            $truncResult = Limit-Prompt $raw $MaxTokPerFile
            if ($truncResult.truncated) {
                [Console]::Error.WriteLine("[council-orchestrator][F2] AVISO: arquivo '$($f.Name)' truncado de $($truncResult.original_tokens) -> ~$MaxTokPerFile tokens.")
            }
            $result[$f.Name] = $truncResult.text
        }
    } elseif ($PromptText) {
        # Caminho B: parse ```file:path``` blocks no prompt
        $matches2 = [regex]::Matches($PromptText, $FileBlockPattern)
        $seen = @{}
        foreach ($m in $matches2) {
            if ($result.Count -ge $maxFiles) {
                [Console]::Error.WriteLine("[council-orchestrator][F2] AVISO: limite de $maxFiles arquivos via file_block atingido; ignorando restantes.")
                break
            }
            $filePath = $m.Groups[1].Value.Trim()
            if ($seen[$filePath]) { continue }
            $seen[$filePath] = $true
            # Resolver path relativo ao CWD
            $resolved = if ([System.IO.Path]::IsPathRooted($filePath)) { $filePath } else { Join-Path $CWD $filePath }
            if (-not (Test-Path $resolved)) {
                [Console]::Error.WriteLine("[council-orchestrator][F2] AVISO: arquivo referenciado no prompt nao encontrado: $resolved")
                continue
            }
            $raw = Get-Content $resolved -Raw -Encoding utf8 -ErrorAction SilentlyContinue
            if (-not $raw) { continue }
            $truncResult = Limit-Prompt $raw $MaxTokPerFile
            if ($truncResult.truncated) {
                [Console]::Error.WriteLine("[council-orchestrator][F2] AVISO: arquivo '$filePath' truncado de $($truncResult.original_tokens) -> ~$MaxTokPerFile tokens.")
            }
            $result[$filePath] = $truncResult.text
        }
    }
    return $result
}

# ---------------------------------------------------------------------------
# F2 — Build-EnrichedSystemPrompt: prefixa system prompt com contexto de codigo
# e instrucao anti-alucinacao quando code_context presente
# ---------------------------------------------------------------------------
function Build-EnrichedSystemPrompt {
    param(
        [string]$BaseSystemPrompt,
        [hashtable]$CodeContext
    )
    if (-not $CodeContext -or $CodeContext.Count -eq 0) {
        return $BaseSystemPrompt
    }

    $codeBlock = ""
    foreach ($path in $CodeContext.Keys) {
        $codeBlock += "$path`n---`n$($CodeContext[$path])`n`n"
    }

    $enriched = @"
=== CONTEXTO DE CODIGO (referenciado no prompt) ===

$codeBlock
=== INSTRUCAO ANTI-ALUCINACAO ===

Voce esta consultando sobre uma decisao. O prompt do operador inclui claims
tecnicos sobre o codigo acima. ANTES de opinar, VALIDE se claims refletem
o codigo real apresentado. Se algum claim e factualmente errado, reporte como
INVALIDA_PREMISSA em vez de opinar sobre a alternativa.

=== TIPOS DE RESPOSTA OBRIGATORIOS ===

Comece sua resposta com UMA das tags:
- ``premise_validity: ok`` -- claims do prompt sao consistentes com codigo
- ``premise_validity: invalid`` -- pelo menos 1 claim e factualmente errado (cite qual)
- ``premise_validity: unverified`` -- nao consegui ler/validar (lib externa, ambiguous)

Apos a tag, sua opiniao normal segue.

=== INSTRUCAO ORIGINAL ===

$BaseSystemPrompt
"@
    return $enriched
}

# ---------------------------------------------------------------------------
# F2 — Get-PremiseValidity: extrai premise_validity da primeira linha nao-vazia do content
# Retorna "ok", "invalid", "unverified", ou "" (ausente/nao-aplicavel)
# ---------------------------------------------------------------------------
function Get-PremiseValidity([string]$content) {
    if (-not $content) { return "" }
    # Procurar nas primeiras 5 linhas (providers podem ter whitespace antes)
    $lines = $content -split "`n" | Select-Object -First 10
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '(?i)premise_validity\s*:\s*(ok|invalid|unverified)') {
            return $matches[1].ToLower()
        }
    }
    return ""
}

# ---------------------------------------------------------------------------
# F2 — Get-PremiseValidityConsensus: agrega premise_validity de todas responses
# Regra: >=1 invalid -> "invalid"; >=1 unverified (sem invalid) -> "unverified"; else "ok"
# Se nenhum provider retornou tag -> "unverified" (seguro por default)
# ---------------------------------------------------------------------------
function Get-PremiseValidityConsensus([array]$responses) {
    $hasInvalid    = $false
    $hasUnverified = $false
    $hasOk         = $false
    $anyTag        = $false
    foreach ($r in $responses) {
        $pv = $r.premise_validity
        if ($pv -eq "invalid")    { $hasInvalid = $true; $anyTag = $true }
        elseif ($pv -eq "unverified") { $hasUnverified = $true; $anyTag = $true }
        elseif ($pv -eq "ok")     { $hasOk = $true; $anyTag = $true }
    }
    if (-not $anyTag) { return "unverified" }
    if ($hasInvalid)    { return "invalid" }
    if ($hasUnverified) { return "unverified" }
    return "ok"
}

$pluginRoot = Split-Path $PSScriptRoot -Parent  # .../percus-review/
$providersDir = Join-Path $pluginRoot "providers"

# Vetor D (v6.14.0): funcoes do tie-breaker Llama (dot-source, sem main body)
$tieBreakerLib = Join-Path $PSScriptRoot "council-tiebreaker.ps1"
if (Test-Path $tieBreakerLib) { . $tieBreakerLib }
$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

# Read prompt
if ($PromptFile) {
    if (-not (Test-Path $PromptFile)) {
        [Console]::Error.WriteLine("[council-orchestrator] PromptFile nao encontrado: $PromptFile")
        exit 1
    }
    $userPrompt = Get-Content $PromptFile -Raw
} else {
    $userPrompt = [Console]::In.ReadToEnd()
}
if (-not $userPrompt -or $userPrompt.Trim().Length -eq 0) {
    [Console]::Error.WriteLine("[council-orchestrator] prompt vazio.")
    exit 1
}

# Default system prompts per mode
if (-not $SystemPrompt) {
    $SystemPrompt = switch ($Mode) {
        "consult"    { "Voce e consultor cross-provider Percus. Responda em <=150 palavras: 1) sua escolha/posicao, 2) razao principal, 3) maior risco da alternativa. Sem floreio." }
        "pre-mortem" { "Voce e consultor de pre-mortem Percus. Leia o plano e responda: SE este plano falhar em 30 dias, por que? Liste exatamente 3 motivos concretos em ordem de probabilidade decrescente, com 1 frase cada." }
        "review"     { "Voce e revisor cross-provider Percus (R11). Aponte bugs, regressoes, violacoes R1-R19, mocks escondidos, JWT em localStorage, imports vetados. Se nada relevante: 'Sem findings criticos'." }
        "analyze"    { "Voce e um dos 3 membros do conselho Percus fazendo ANALYZE de uma spec de feature (estilo /analyze do spec-kit): detecte defeitos da spec, nao opine sobre merito. Passes: (1) todo FR testavel e todo SC mensuravel? (2) termo vago/ambiguo? (3) terminologia consistente? (4) edge case sem FR? (5) viola constituicao R1-R23 ou 02_INFRA (CRITICAL)? (6) assumption/dependencia nao declarada? (7) vazamento WHAT->HOW (stack/tabela/endpoint na spec = MEDIUM). Output: 1 linha por finding no formato 'SEVERIDADE ref - defeito concreto - correcao em 1 frase'; severidade CRITICAL|HIGH|MEDIUM|LOW. Termine com 'VEREDITO: PRONTA' (zero critical/high), 'VEREDITO: AJUSTAR (N high)' ou 'VEREDITO: BLOQUEADA (N critical)'. Sem floreio." }
    }
}

# F2 — Load code context (Caminho A: CodeContextDir; Caminho B: file_block parser)
$codeContext = Get-CodeContext -ContextDir $CodeContextDir -PromptText $userPrompt -MaxTokPerFile $MaxTokensPerFile -CWD (Get-Location).Path
$hasCodeContext = ($codeContext.Count -gt 0)
if ($hasCodeContext) {
    [Console]::Error.WriteLine("[council-orchestrator][F2] $($codeContext.Count) arquivo(s) de codigo injetados no system prompt.")
    $SystemPrompt = Build-EnrichedSystemPrompt -BaseSystemPrompt $SystemPrompt -CodeContext $codeContext
}

# F.2 Automatic router: choose Cross-Claude model by mode (unless overridden)
if (-not $CrossClaudeModel) {
    $CrossClaudeModel = switch ($Mode) {
        "consult"    { "claude-haiku-4-5" }
        "review"     { "claude-sonnet-4-6" }
        "pre-mortem" { "claude-opus-4-7" }
        "analyze"    { "claude-sonnet-4-6" }
        default      { "claude-sonnet-4-6" }
    }
}

# Parse providers list
$wanted = $Providers.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }

# Detect if direct wrapper can be used for cross-claude (avoids marker, enables cache_control)
$crossClaudeWrapper = Join-Path $providersDir "cross-claude.ps1"
$useDirectClaude = ($wanted -contains "cross-claude") -and (Test-Path $crossClaudeWrapper) -and $env:ANTHROPIC_API_KEY -and (-not $CrossClaudeFile)

# Separate cross-claude (handled differently unless direct wrapper available)
if ($useDirectClaude) {
    $asyncProviders = $wanted | Where-Object { $_ }  # inclui cross-claude no dispatch normal
    $wantsCrossClaude = $false  # ja vai pelo dispatch normal — NAO emitir marker
} else {
    $asyncProviders = $wanted | Where-Object { $_ -ne "cross-claude" }
    $wantsCrossClaude = $wanted -contains "cross-claude"
}

# F.5 smart truncation conservador
$combinedForCheck = "$SystemPrompt`n$userPrompt"
$trunc = Limit-Prompt $combinedForCheck $MaxInputTokens
if ($trunc.truncated) {
    [Console]::Error.WriteLine("[council-orchestrator] AVISO: prompt truncado de $($trunc.original_tokens) -> ~$MaxInputTokens tokens.")
    # Aplicar truncation apenas ao userPrompt; SystemPrompt fica intacto (e curto)
    $userTrunc = Limit-Prompt $userPrompt ($MaxInputTokens - (Measure-Tokens $SystemPrompt))
    $userPrompt = $userTrunc.text
}

# Write prompt to temp file for jobs to read
$tmpPrompt = [System.IO.Path]::GetTempFileName()
$userPrompt | Out-File -FilePath $tmpPrompt -Encoding utf8 -NoNewline

# Dispatch async providers as PS jobs
$jobs = @{}
$start = Get-Date
foreach ($p in $asyncProviders) {
    $wrapperPath = Join-Path $providersDir "$p.ps1"
    if (-not (Test-Path $wrapperPath)) {
        [Console]::Error.WriteLine("[council-orchestrator] WARN: provider '$p' nao tem wrapper em $wrapperPath, pulando.")
        continue
    }
    # PS jobs nao herdam env vars do parent; capturar e re-set dentro do job.
    $envSnapshot = @{
        DEEPSEEK_API_KEY  = $env:DEEPSEEK_API_KEY
        GROQ_API_KEY      = $env:GROQ_API_KEY
        ANTHROPIC_API_KEY = $env:ANTHROPIC_API_KEY
    }
    $modelForProvider = switch ($p) {
        "deepseek"     { $DeepSeekModel }
        "groq-llama"   { $GroqModel }
        "cross-claude" { $CrossClaudeModel }
        default        { "" }
    }
    $jobs[$p] = Start-Job -ScriptBlock {
        param($Wrapper, $PromptF, $SysPrompt, $EnvVars, $ModelArg, $ModeArg)
        foreach ($kv in $EnvVars.GetEnumerator()) {
            if ($kv.Value) { Set-Item -Path "env:$($kv.Key)" -Value $kv.Value }
        }
        if ($Wrapper -match 'cross-claude') {
            # F.1 fix v6.6.1: pra cross-claude, passar -Mode pra carregar system-prompt-{mode}.md
            # (enriquecido com R1-R19, ativa cache Anthropic). NAO passar -SystemPrompt
            # senao wrapper detecta override via PSBoundParameters e pula o file load.
            if ($ModelArg) {
                & $Wrapper -PromptFile $PromptF -Mode $ModeArg -Model $ModelArg
            } else {
                & $Wrapper -PromptFile $PromptF -Mode $ModeArg
            }
        } else {
            if ($ModelArg) {
                & $Wrapper -PromptFile $PromptF -SystemPrompt $SysPrompt -Model $ModelArg
            } else {
                & $Wrapper -PromptFile $PromptF -SystemPrompt $SysPrompt
            }
        }
    } -ArgumentList $wrapperPath, $tmpPrompt, $SystemPrompt, $envSnapshot, $modelForProvider, $Mode
}

# Collect cross-claude (already provided OR marker)
$crossClaude = $null
if ($wantsCrossClaude) {
    if ($CrossClaudeFile -and (Test-Path $CrossClaudeFile)) {
        $crossClaude = @{
            provider   = "cross-claude"
            model      = $CrossClaudeModel
            status     = "ok"
            content    = (Get-Content $CrossClaudeFile -Raw)
            latency_ms = 0
        }
    } else {
        # Emit marker pro agente
        [Console]::Error.WriteLine("__PERCUS_NEEDS_CROSS_CLAUDE__")
        [Console]::Error.WriteLine("[council-orchestrator] dispatch Cross-Claude subagent com prompt:")
        [Console]::Error.WriteLine("---MODEL-HINT---")
        [Console]::Error.WriteLine($CrossClaudeModel)
        [Console]::Error.WriteLine("---END-MODEL-HINT---")
        [Console]::Error.WriteLine("---PROMPT---")
        [Console]::Error.WriteLine("$SystemPrompt`n`n$userPrompt")
        [Console]::Error.WriteLine("---END-PROMPT---")
        [Console]::Error.WriteLine("Salve resposta em arquivo e re-invoque orchestrator com -CrossClaudeFile <path>.")
    }
}

# Wait for jobs
$responses = @()
foreach ($name in $jobs.Keys) {
    $job = $jobs[$name]
    $jobOutput = Wait-Job -Job $job | Receive-Job
    # jobOutput pode ser JSON string OR error obj
    $jsonStr = ($jobOutput | Out-String).Trim()
    Remove-Job -Job $job -Force
    try {
        $obj = $jsonStr | ConvertFrom-Json
        # F2: parse premise_validity da content (quando code context foi injetado)
        $pv = if ($hasCodeContext) { Get-PremiseValidity ($obj.content) } else { "" }
        # Adicionar campo ao objeto (convertendo PSCustomObject pra hashtable para mutabilidade)
        $objHash = @{}
        $obj.PSObject.Properties | ForEach-Object { $objHash[$_.Name] = $_.Value }
        $objHash["premise_validity"] = $pv
        $responses += $objHash
    } catch {
        $responses += @{
            provider          = $name
            status            = "error"
            error             = "Failed to parse provider output: $jsonStr"
            latency_ms        = 0
            premise_validity  = ""
        }
    }
}
if ($crossClaude) {
    # F2: parse premise_validity do cross-claude (se code context presente)
    $ccPV = if ($hasCodeContext) { Get-PremiseValidity ($crossClaude.content) } else { "" }
    $crossClaude["premise_validity"] = $ccPV
    $responses += $crossClaude
}

Remove-Item $tmpPrompt -Force -ErrorAction SilentlyContinue

$totalLatency = [int]((Get-Date) - $start).TotalMilliseconds

# F2: calcular premise_validity_consensus
$premiseConsensus = if ($hasCodeContext) { Get-PremiseValidityConsensus $responses } else { "" }

# Vetor D (v6.14.0) — Llama tie-breaker: exatamente 2 OK, sem groq-llama entre eles,
# e premise_validity divergente. Resultado e "convergencia 2/3 informal" (operador decide).
$tieBreakerInvoked = $false
$tieBreaker = $null
if ((Get-Command Test-CouncilNeedsTieBreaker -ErrorAction SilentlyContinue) -and (Test-CouncilNeedsTieBreaker -Responses $responses)) {
    $groqWrapperTB = Join-Path $providersDir "groq-llama.ps1"
    $tb = Invoke-LlamaTieBreaker -Responses $responses -UserPrompt $userPrompt -Wrapper $groqWrapperTB -PsExe $PsExe
    if ($tb.status -eq "ok") {
        $tieBreakerInvoked = $true
        $tieBreaker = @{
            provider = "groq-llama"
            role     = "tie-breaker"
            content  = $tb.content
            note     = "convergencia 2/3 informal -- tie-breaker fraco; operador decide"
        }
        [Console]::Error.WriteLine("[council-orchestrator][Vetor D] tie-breaker Llama invocado (2 providers OK divergentes, sem groq-llama).")
    }
}

# Log to .deepseek/council-log/
$logDir = Join-Path (Get-Location) ".deepseek\council-log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "$(Get-Date -Format 'yyyyMMdd-HHmmss')-$Mode.jsonl"

$result = @{
    mode             = $Mode
    timestamp        = (Get-Date -Format 'o')
    prompt           = $userPrompt
    system_prompt    = $SystemPrompt
    providers_called = $wanted
    responses        = $responses
    total_latency_ms = $totalLatency
    cross_claude_pending = ($wantsCrossClaude -and (-not $crossClaude))
    truncated        = $trunc.truncated
    original_token_count = $trunc.original_tokens
    # F2 — code context injection metadata
    code_context_files        = @($codeContext.Keys)
    has_code_context          = $hasCodeContext
    premise_validity_consensus = $premiseConsensus
    # Vetor D (v6.14.0)
    tie_breaker_invoked       = $tieBreakerInvoked
    tie_breaker               = $tieBreaker
}

$result | ConvertTo-Json -Depth 10 | Out-File -FilePath $logFile -Encoding utf8

# Output to stdout
$result | ConvertTo-Json -Depth 10
exit 0
