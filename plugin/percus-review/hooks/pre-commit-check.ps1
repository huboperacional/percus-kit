#requires -Version 5.1
# Hook pre-commit Percus (Layer 1 — UX dentro do Claude Code).
# Bloqueia commit sem /percus-review:review recente quando Claude executa via Bash tool.
# Falha graceful: qualquer erro -> exit 0.
#
# IMPORTANTE: este hook tem brecha conhecida em comandos bash compostos
# (ex: `rm -rf .deepseek/reviews && git commit`) porque PreToolUse avalia o estado
# UMA vez antes do bash rodar e nao observa mudancas durante a execucao.
# Layer 2 (anti-bypass) eh `.git/hooks/pre-commit` nativo do git, instalado por
# `/percus-review:install-git-hooks` no projeto-alvo. Ver git-hooks/pre-commit.template.sh.
#
# v6.7.2 (Proposta F+G, incidente 2026-05-19): hook agora detecta o repo target
# do commit parseando `cd <dir>`, `Set-Location <dir>` e `git -C <dir>` do comando,
# e resolve `git rev-parse --show-toplevel` desse target. Cross-repo work (CWD do
# agente != repo target) passa a ser observavel.

# v6.31.1 (2026-07-27): git-bash entrega o dir como '/d/Foo/Bar' (MSYS) e Cygwin como
# '/cygdrive/d/Foo/Bar'. Passar isso pro git do WINDOWS da exit 128, o hook caia no
# fallback e ia procurar review em '\d\Foo\Bar\.deepseek\reviews' — que nunca existe.
# Efeito: bloqueava commit que TINHA review, ensinando a usar PERCUS_HOOKS_DISABLED.
function ConvertTo-WindowsPath {
    param([string]$path)
    if (-not $path) { return $path }
    if ($env:OS -ne 'Windows_NT') { return $path }   # em Unix '/d/...' e path legitimo
    if ($path -match '^/cygdrive/([a-zA-Z])/(.*)$' -or $path -match '^/([a-zA-Z])/(.*)$') {
        return ($matches[1].ToUpper() + ":\" + ($matches[2] -replace '/', '\'))
    }
    if ($path -match '^/([a-zA-Z])/?$') { return ($matches[1].ToUpper() + ":\") }
    return $path
}

function Get-CommitTargetDir {
    param([string]$cmd, [string]$fallback)

    # git -C <dir> commit  (suporta quotes simples/duplas)
    # -cmatch (case-SENSITIVE) de proposito: com -match, o '-c' de
    # `git -c commit.gpgsign=false commit` casava neste padrao e o "repo target" virava
    # 'commit.gpgsign=false'. Bug encontrado em 2026-07-27.
    if ($cmd -cmatch '\bgit\s+-C\s+(?:"([^"]+)"|''([^'']+)''|(\S+))\s+.*\bcommit\b') {
        foreach ($g in $matches[1], $matches[2], $matches[3]) { if ($g) { return $g } }
    }

    # cd <dir> && git commit  (compound bash; tambem aceita `;`)
    if ($cmd -match '\bcd\s+(?:"([^"]+)"|''([^'']+)''|(\S+))\s*(?:&&|;)') {
        foreach ($g in $matches[1], $matches[2], $matches[3]) { if ($g) { return $g } }
    }

    # Set-Location <dir>  (PowerShell)
    if ($cmd -match '\b(?:Set-Location|sl)\s+(?:"([^"]+)"|''([^'']+)''|(\S+))') {
        foreach ($g in $matches[1], $matches[2], $matches[3]) { if ($g) { return $g } }
    }

    return $fallback
}

try {
    # PowerShell -File com stdin via pipe (testes Pester) consome stdin pelo automatic
    # $input enumerator e [Console]::In.ReadToEnd() retorna vazio. Em producao via
    # Claude Code hook runtime, stdin chega via OS pipe e [Console]::In funciona.
    # Tenta ambos os caminhos pra cobrir os dois cenarios.
    $stdin = [Console]::In.ReadToEnd()
    if (-not $stdin -and $input) {
        $stdin = ($input | Out-String).Trim()
    }
    if (-not $stdin) { exit 0 }

    $parsed = $stdin | ConvertFrom-Json
    $command = $parsed.tool_input.command

    # Não-commit -> libera
    if ($command -notmatch '\bgit\s+(?:-C\s+\S+\s+)?commit\b') { exit 0 }

    # Amend sem edit (rebase) -> libera
    if ($command -match '\bgit\s+(?:-C\s+\S+\s+)?commit\s+--amend\s+--no-edit\b') { exit 0 }

    # Escape pro user (motivo declarado em voz alta)
    if ($env:PERCUS_HOOKS_DISABLED) { exit 0 }

    # Resolver repo target do commit
    $cwd = (Get-Location).Path
    $targetDir = ConvertTo-WindowsPath (Get-CommitTargetDir -cmd $command -fallback $cwd)
    $repoRoot = & git -C "$targetDir" rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $repoRoot) { $repoRoot = $targetDir }
    $repoRoot = $repoRoot.Trim()
    $reviewDir = Join-Path $repoRoot ".deepseek/reviews"

    # Diagnostic helper (Proposta G)
    function Write-BlockContext {
        param([string]$searched)
        [Console]::Error.WriteLine("  git root: $repoRoot")
        if ($cwd -ne $repoRoot) {
            [Console]::Error.WriteLine("  cwd:      $cwd")
        }
        [Console]::Error.WriteLine("  searched: $searched")
    }

    # === POLITICA DE RISCO: review por CRITERIO, nao por frequencia (2026-08-19) ===
    # Medido: 26 chamadas do conselho em modo review geraram achado em 8 (31%) -- e os 2 achados
    # materiais de uma sessao inteira vieram de diffs que mexiam em LOGICA e CONTRATO, nenhum de
    # commit trivial. Pagar 60-90 s uniformes por um beneficio concentrado e o desperdicio; o
    # porteiro fica onde ja pegou coisa.
    #
    # Conservador de proposito: a dispensa e uma LISTA FECHADA de extensoes de texto puro. Tudo
    # que nao estiver nela exige review, inclusive extensao nova. A regra "dispensa o que eu
    # reconheco como inofensivo" falha para o lado seguro; a inversa ("exige so o que eu
    # reconheco como perigoso") deixa o desconhecido passar -- que e como enforcement por
    # enumeracao ja mordeu este kit duas vezes.
    #
    # Um unico arquivo fora da lista ja exige review do commit inteiro: nao existe "meio
    # revisado".
    try {
        $dispensaveis = @('.md', '.txt', '.rst', '.adoc')
        $mudados = @(git -C $repoRoot diff HEAD --name-only 2>$null | Where-Object { $_ })
        if ($mudados.Count -gt 0) {
            $temCodigo = $false
            foreach ($m in $mudados) {
                $ext = [IO.Path]::GetExtension($m)
                if ($dispensaveis -notcontains $ext.ToLower()) { $temCodigo = $true; break }
            }
            if (-not $temCodigo) {
                # Silencio: dispensa nao e evento. Aviso a cada commit de texto viraria ruido, e
                # ruido e o que faz o operador parar de ler os avisos que importam.
                exit 0
            }
        }
    } catch { }

    if (-not (Test-Path $reviewDir)) {
        [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: nenhum /percus-review:review em .deepseek/reviews/ do repo target")
        Write-BlockContext -searched $reviewDir
        [Console]::Error.WriteLine("Rode /percus-review:review do repo target antes de commitar (R11).")
        exit 2
    }

    # === VALIDADE POR CONTEUDO, ANTES DA VALIDADE POR TEMPO (2026-08-19) ===
    # Se existe marcador para o hash do diff ATUAL, a review cobre exatamente este codigo --
    # libera sem olhar relogio. Tempo nunca foi proxy de "isto foi revisado": a janela de 5 min
    # forcava re-review do MESMO diff depois de rodar a suite (184 s) e, no sentido contrario,
    # deixava commitar codigo editado depois da review desde que dentro da janela.
    #
    # `git diff HEAD` (nao `--cached`) porque ele NAO muda no `git add` -- assim o fluxo
    # editar -> revisar -> stage -> commit nao invalida a review no meio.
    #
    # Lookup DIRETO pelo nome: O(1), sem enumerar o diretorio. E a mesma propriedade que a
    # decisao de 2026-07-20 protegia quando o dir acumulava milhares de arquivos.
    #
    # Falha graceful: qualquer erro aqui cai no caminho antigo (latest.jsonl + 5 min).
    # ⚠️ Hash do ARQUIVO escrito por `git diff --output=`, nunca da saida capturada pelo shell:
    # PowerShell decodifica a saida do processo com o encoding do console, e diff com acento
    # produz hash diferente do bash pro MESMO diff (medido 2026-08-19). Com --output= quem
    # escreve os bytes e o git, igual nos dois runtimes.
    try {
        $tmpDiff = [System.IO.Path]::GetTempFileName()
        try {
            # `-C $repoRoot` e obrigatorio: o hook roda no cwd do AGENTE, nao no repo alvo. O
            # repo alvo sai do proprio comando (`cd /d/x && git commit`, `git -C /d/x commit`) e
            # ja foi resolvido acima pro $reviewDir. Sem o -C, o hash sairia do diff do
            # diretorio errado, nunca casaria com o marcador, e a otimizacao viraria codigo
            # morto que sempre cai no fallback -- falha silenciosa. Pego por teste, nao por
            # leitura: e a mesma classe de resolucao de repo target que
            # pre-commit-path-resolution.tests.ps1 ja documentava.
            git -C $repoRoot diff HEAD --output=$tmpDiff 2>$null | Out-Null
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $fs  = [IO.File]::OpenRead($tmpDiff)
            try { $hashHex = ([BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-','').ToLower().Substring(0,12) }
            finally { $fs.Dispose() }
        } finally { Remove-Item $tmpDiff -Force -ErrorAction SilentlyContinue }
        $porHash = Join-Path $reviewDir "d-$hashHex.jsonl"
        if (Test-Path $porHash) {
            $idade = (Get-Date) - (Get-Item $porHash).LastWriteTime
            if ($idade.TotalHours -le 24) { exit 0 }
        }
    } catch { }

    # Path fixo latest.jsonl (2026-07-20) -- O(1), sem enumerar o dir inteiro.
    # Fallback ao Sort-Object so se ausente (wrapper antigo ainda em transicao).
    $latestPath = Join-Path $reviewDir 'latest.jsonl'
    if (Test-Path $latestPath) {
        $latest = Get-Item $latestPath
    } else {
        $latest = Get-ChildItem $reviewDir -Filter "*.jsonl" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if (-not $latest) {
        [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: .deepseek/reviews/ vazia no repo target")
        Write-BlockContext -searched $reviewDir
        [Console]::Error.WriteLine("Rode /percus-review:review do repo target antes de commitar (R11).")
        exit 2
    }

    $age = (Get-Date) - $latest.LastWriteTime
    if ($age.TotalMinutes -gt 5) {
        $mins = [math]::Round($age.TotalMinutes, 1)
        [Console]::Error.WriteLine("[percus:hook pre-commit] BLOCK: ultimo /percus-review:review tem $mins min (max 5).")
        Write-BlockContext -searched $reviewDir
        [Console]::Error.WriteLine("  latest:   $($latest.Name)")
        [Console]::Error.WriteLine("Rode /percus-review:review de novo antes de commitar (R11).")
        exit 2
    }

    # Review fresco -> libera
    exit 0
} catch {
    # Falha do hook nao bloqueia workflow
    Write-Host "[percus:hook pre-commit] WARN: hook crashed, allowing commit. Error: $_" -ForegroundColor DarkYellow
    exit 0
}
