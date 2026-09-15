#requires -Version 5.1
# Hook pre-commit Percus mock-scan (R3).
# Bloqueia commit se staged diff contem padroes de mock/placeholder.
# Skip explicito: `MOCK-OK:` em qualquer -m ou no arquivo de -F OU `$env:PERCUS_SKIP_MOCK_SCAN=1`.
# Falha graceful: qualquer erro -> exit 0.

. "$PSScriptRoot\_helpers.ps1"

try {
    # stdin chega via OS pipe em producao (Claude Code hook runtime) -> [Console]::In.
    # Via pipe do PowerShell (testes Pester) o stdin cai no automatic $input;
    # tenta ambos os caminhos. Ver pre-commit-check.ps1 (mesmo padrao).
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin -and $input) { $stdin = ($input | Out-String).Trim() }
    if (-not $stdin) { exit 0 }

    $parsed = $stdin | ConvertFrom-Json
    $command = $parsed.tool_input.command

    if ($command -notmatch '\bgit\s+commit\b') { exit 0 }
    if ($command -match '\bgit\s+commit\s+--amend\s+--no-edit\b') { exit 0 }
    if ($env:PERCUS_HOOKS_DISABLED -or $env:PERCUS_SKIP_MOCK_SCAN) { exit 0 }

    $projectRoot = Resolve-PercusProjectRoot -Command $command

    # Escape MOCK-OK: (T10, 2026-09-15). Vale em QUALQUER -m "..."/-m '...' (todas
    # as ocorrencias, nao so a 1a) ou nas primeiras 64 KB do arquivo de
    # -F <arq> / --file=<arq> / --file <arq>. Caminho relativo resolve contra a
    # raiz do Resolve-PercusProjectRoot (o `cd <dir> &&` do comando), nunca contra
    # o cwd deste processo. `-F -` (stdin), arquivo inexistente, diretorio ou
    # ilegivel -> SEM escape: o scan segue. A leitura tem try PROPRIO: o catch
    # geral la de baixo libera o commit, e uma excecao aqui nao pode virar escape.
    # Paridade com mock-scan-pre-commit.sh e requisito de seguranca: uma perna
    # que libera onde a outra bloqueia e defeito (tests\mock-scan.tests.ps1).
    # LIMITES (custo, revisao T10): so os primeiros 65536 caracteres do comando e no
    # maximo 64 ocorrencias por regex; passou disso -> sem escape (o scan segue).
    # Hook que estoura o timeout do Claude Code deixa o commit passar SEM scan.
    # Unidade: aqui caracteres UTF-16; o .sh corta em BYTES da saida do python3.
    # Byte >= unidade UTF-16, entao o .sh nunca ve MAIS texto que esta perna: com
    # nao-ASCII perto do corte ele pode bloquear onde esta libera, nunca o contrario.
    # Fronteira: `(?i)\bMOCK-OK:` do contrato, com um ajuste de paridade com o .sh:
    # QUALQUER caractere nao-ASCII antes conta como letra (`eMOCK-OK:` com acento
    # colado bloqueia), e a caixa e so ASCII ([Kk], nao o sinal Kelvin do .NET).
    # \P{IsBasicLatin} = fora de U+0000-U+007F (fonte ASCII, sem \u literal).
    $reEscape = '(?<![\w\P{IsBasicLatin}])[Mm][Oo][Cc][Kk]-[Oo][Kk]:'
    $janela = 65536
    $maxOcorr = 64
    $cmdEsc = $command
    $cmdTruncado = $false
    if ($cmdEsc.Length -gt $janela) { $cmdEsc = $cmdEsc.Substring(0, $janela); $cmdTruncado = $true }
    $escape = $false
    foreach ($reMsg in @('-m\s+"([^"]+)"', "-m\s+'([^']+)'")) {
        $nOcorr = 0
        foreach ($m in [regex]::Matches($cmdEsc, $reMsg)) {
            if ($nOcorr -ge $maxOcorr) { break }
            $nOcorr++
            # [regex]::IsMatch e nao -match: o -match liga IgnoreCase e traria o Kelvin de volta.
            if ([regex]::IsMatch($m.Groups[1].Value, $reEscape)) { $escape = $true; break }
        }
        if ($escape) { break }
    }
    if (-not $escape) {
        $reArq = '(?:^|\s)(?:-F\s+|--file=|--file\s+)(?:"([^"]*)"|''([^'']*)''|([^\s"'';&|]+))'
        $nOcorr = 0
        foreach ($m in [regex]::Matches($cmdEsc, $reArq)) {
            if ($nOcorr -ge $maxOcorr) { break }
            $nOcorr++
            # Trecho que termina exatamente no corte da janela pode ser caminho
            # partido (`-F msg` de `-F msg.txt`): sem escape.
            if ($cmdTruncado -and ($m.Index + $m.Length) -ge $cmdEsc.Length) { continue }
            $arq = $null
            foreach ($g in 1..3) { if ($m.Groups[$g].Success) { $arq = $m.Groups[$g].Value; break } }
            if (-not $arq -or $arq -eq '-') { continue }
            try {
                if (-not [IO.Path]::IsPathRooted($arq)) { $arq = Join-Path $projectRoot $arq }
                if (-not (Test-Path -LiteralPath $arq -PathType Leaf)) { continue }
                $fs = [IO.File]::Open($arq, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                try {
                    $buf = New-Object byte[] 65536
                    $lidos = 0
                    while ($lidos -lt $buf.Length) {
                        $n = $fs.Read($buf, $lidos, $buf.Length - $lidos)
                        if ($n -le 0) { break }
                        $lidos += $n
                    }
                } finally { $fs.Dispose() }
                # Pula um BOM UTF-8 inicial (Out-File -Encoding UTF8 do PS 5.1 grava BOM):
                # o GetString devolveria U+FEFF, que conta como letra colada no MOCK-OK:.
                $ini = 0
                if ($lidos -ge 3 -and $buf[0] -eq 0xEF -and $buf[1] -eq 0xBB -and $buf[2] -eq 0xBF) { $ini = 3 }
                $texto = [Text.Encoding]::UTF8.GetString($buf, $ini, $lidos - $ini)
                if ([regex]::IsMatch($texto, $reEscape)) { $escape = $true; break }
            } catch {
                # ilegivel -> sem escape; o scan segue e decide.
                continue
            }
        }
    }
    if ($escape) { exit 0 }

    if (-not (Test-Path (Join-Path $projectRoot ".git"))) { exit 0 }

    # Scan staged code files
    $codeExts = @('.py','.ts','.tsx','.js','.jsx','.go','.rs','.java','.css','.html','.vue','.svelte','.sql')
    $files = Get-PercusStagedFiles -ProjectRoot $projectRoot -Extensions $codeExts
    if (-not $files -or $files.Count -eq 0) { exit 0 }

    # Forbidden patterns. Each one captures intent of "fake/placeholder/TODO leftover".
    $patterns = @(
        @{ Re = '\bMOCK_(?!OK\b)\w+';                    Why = 'identificador MOCK_*' },
        # TODO **nao e mais verificado aqui** -- ver o bloco logo abaixo para o
        # porque. FIXME/XXX/HACK continuam, com `[: ]`.
        # **TODO SAIU DO GATE** em 2026-08-17, e o motivo nao e ergonomia: a R3
        # escrita nao pede marcador nenhum. Ela trata de "dado falso mentindo pro
        # usuario" -- banner MODO DEMO, toast "salvo localmente", nunca so
        # "salvo". Marcador de codigo nunca esteve la. Esta checagem era o hook
        # sendo mais estrito que a regra que diz implementar, e essa estritude
        # nao pedida colidiu 3x com portugues ("Metodo", "metodoTodoListado",
        # "TODO chunk"), apertando a regex a cada vez. Conselho consultado
        # (DeepSeek + Cross-Claude, unanime): heuristica contra o idioma e
        # corrida armamentista.
        # FIXME/XXX/HACK ficam -- sao jargao de dev, nao palavras em portugues, e
        # nunca causaram incidente. Um "TODO:" esquecido segue coberto pelo R11,
        # que le o diff inteiro antes de todo commit.
        @{ Re = '\b(?-i:FIXME)\b[: ]';                    Why = 'marcador FIXME pendente' },
        @{ Re = '\b(?-i:XXX)\b[: ]';                      Why = 'marcador XXX pendente' },
        @{ Re = '\b(?-i:HACK)\b[: ]';                     Why = 'marcador HACK pendente' },
        @{ Re = '(?i)\blorem\s+ipsum\b';                  Why = 'lorem ipsum' },
        @{ Re = '(?i)\bdummy_';                           Why = 'dummy_' },
        @{ Re = '(?i)\bplaceholder_value\b';              Why = 'placeholder_value' },
        @{ Re = 'https?://localhost:\d+';                 Why = 'URL localhost:porta hardcoded' },
        @{ Re = '(?i)\bhardcoded\b';                      Why = 'comentario hardcoded' }
    )

    $findings = @()
    foreach ($f in $files) {
        $content = Get-PercusStagedContent -ProjectRoot $projectRoot -RelPath $f
        if (-not $content) { continue }
        $lineNum = 0
        foreach ($line in $content -split "`n") {
            $lineNum++
            foreach ($p in $patterns) {
                if ($line -match $p.Re) {
                    $findings += "${f}:${lineNum} -> $($p.Why) :: $($line.Trim().Substring(0,[Math]::Min(80,$line.Trim().Length)))"
                    break
                }
            }
            if ($findings.Count -ge 10) { break }
        }
        if ($findings.Count -ge 10) { break }
    }

    if ($findings.Count -eq 0) { exit 0 }

    Write-PercusBlock -HookName 'mock-scan' -Lines (@(
        "encontrados $($findings.Count)+ padrao(es) de mock/placeholder em arquivos staged (R3)."
    ) + $findings + @(
        "Remova o mock OU ponha 'MOCK-OK: <motivo>' em qualquer -m (qualquer posicao) ou no arquivo de -F (primeiras 64 KB) pra pular.",
        "Skip permanente: `$env:PERCUS_SKIP_MOCK_SCAN=1 (declarar motivo em voz alta)."
    ))
    exit 2
} catch {
    Write-Host "[percus:hook mock-scan] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
