#requires -Version 5.1
# Testes do hook spec-analyze-check (v6.47.0).
#
# PreToolUse:Bash|PowerShell, WARN-ONLY (exit 0 sempre). Avisa quando um `git commit` leva uma
# spec (docs/superpowers/specs/*.md) que o conselho nunca analisou.
#
# Por que existe: o canon manda, em TRES lugares -- 01_REGRAS_INEGOCIAVEIS.md:316,
# v2/CONSTITUICAO.md:35 e v2/loops/spec.md -- que o agente rode `spec-analyze` sozinho ao
# finalizar uma spec, "sem pedir permissao". A promessa IRMA da mesma frase ("ao finalizar um
# plano -> council-pre-mortem") tem hook desde sempre: pre-plan-exit. A da spec nao tinha nenhum.
# Metade do par ficou dependendo de alguem lembrar -- e em 2026-09-12 o proprio agente escreveu,
# commitou e apresentou uma spec sem rodar o analyze. So o operador perguntando revelou.
#
# Nasce WARN-ONLY de proposito: a frota tem specs antigas sem analyze, e um bloqueio que dispara
# em massa no primeiro dia vira escape declarado -- foi o que o teto do CONTEXT.md ensinou.
#
# Tres estados, porque "nunca rodou" e "rodou numa versao anterior" pedem acoes diferentes:
#   coberto        -> silencio
#   versao antiga  -> avisa que o analyze existe mas nao cobre o texto atual
#   nenhum         -> avisa que nao houve analyze nenhum

Describe "spec-analyze-check hook (gate [S] mecanico, warn-only)" {

    BeforeAll {
        $script:hook = Join-Path $PSScriptRoot ".." "hooks" "spec-analyze-check.ps1"

        function New-RepoComSpec {
            param(
                [string]$Conteudo,
                [string]$RelPath = "docs/superpowers/specs/2026-09-12-teste-design.md",
                [switch]$SemStage
            )
            $repo = Join-Path ([IO.Path]::GetTempPath()) "specanalyze-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $repo | Out-Null
            & git -C $repo init -q
            & git -C $repo config user.email "t@t.t"
            & git -C $repo config user.name "t"
            & git -C $repo config commit.gpgsign false
            $full = Join-Path $repo $RelPath
            New-Item -ItemType Directory -Force -Path (Split-Path $full -Parent) | Out-Null
            [System.IO.File]::WriteAllText($full, $Conteudo, (New-Object System.Text.UTF8Encoding($false)))
            if (-not $SemStage) { & git -C $repo add -A }
            return $repo
        }

        # Grava um log de analyze como o orchestrator grava: .deepseek/council-log/<ts>-analyze.jsonl
        function Add-LogAnalyze {
            param([string]$Repo, [string]$PromptDaSpec, [string]$Ts = "")
            if (-not $Ts) { $Ts = (Get-Date -Format 'yyyyMMdd-HHmmss') }
            $dir = Join-Path $Repo ".deepseek\council-log"
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $doc = @{
                mode      = "analyze"
                timestamp = (Get-Date -Format 'o')
                prompt    = $PromptDaSpec
                responses = @(@{ provider = "deepseek"; status = "ok"; content = "VEREDITO: PRONTA" })
            } | ConvertTo-Json -Depth 6 -Compress
            [System.IO.File]::WriteAllText((Join-Path $dir "$Ts-analyze.jsonl"), $doc, (New-Object System.Text.UTF8Encoding($false)))
        }

        function Invoke-Guarda {
            param([string]$Repo, [string]$Comando)
            if (-not $Comando) { $Comando = "cd `"$Repo`" && git commit -m `"docs(spec): nova spec`"" }
            $stdin = @{ tool_input = @{ command = $Comando } } | ConvertTo-Json -Compress
            Push-Location $Repo
            try { $out = $stdin | & pwsh -NoProfile -File $script:hook 2>&1; $code = $LASTEXITCODE }
            finally { Pop-Location }
            return [pscustomobject]@{ Code = $code; Out = ($out -join "`n") }
        }

        $script:specTexto = @"
# Titulo da spec de teste — Design

**Data:** 2026-09-12

## Motivacao
Uma frase qualquer que identifica este documento de forma estavel.

## Verificacao
Teste.
"@
    }

    It "existe" {
        Test-Path $hook | Should -Be $true
    }

    Context "commit com spec SEM analyze nenhum: avisa" {
        It "avisa nomeando o arquivo e a regra, mas NUNCA bloqueia (exit 0)" {
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            $r = Invoke-Guarda -Repo $repo
            $r.Code | Should -Be 0 -Because "warn-only: bloquear com a frota cheia de spec antiga vira escape declarado"
            $r.Out  | Should -Match '\[percus:hook spec-analyze\]'
            $r.Out  | Should -Match '2026-09-12-teste-design\.md'
            $r.Out  | Should -Match '(?i)spec-analyze'
        }

        It "o aviso diz COMO resolver (o comando), nao so que esta errado" {
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            $r = Invoke-Guarda -Repo $repo
            $r.Out | Should -Match '(?i)percus-review:spec-analyze|council-orchestrator'
        }
    }

    Context "commit com spec JA analisada: silencio" {
        It "log de analyze com o texto atual -> nao avisa" {
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            Add-LogAnalyze -Repo $repo -PromptDaSpec $script:specTexto
            $r = Invoke-Guarda -Repo $repo
            $r.Code | Should -Be 0
            $r.Out  | Should -Not -Match 'spec-analyze'
        }
    }

    Context "analyze de versao ANTERIOR: avisa diferente" {
        It "spec editada depois do analyze -> aviso distingue 'versao antiga' de 'nunca rodou'" {
            # Analisar a v1 e commitar a v2 sem reanalisar e o caminho mais provavel de burlar o
            # gate sem querer. Dizer so "sem analyze" mandaria o agente rodar do zero sem saber
            # que ja houve um; dizer "desatualizado" e a informacao que muda o que ele faz.
            $repo = New-RepoComSpec -Conteudo ($script:specTexto + "`n`n## Secao nova acrescentada depois do analyze`nTexto novo.`n")
            Add-LogAnalyze -Repo $repo -PromptDaSpec $script:specTexto
            $r = Invoke-Guarda -Repo $repo
            $r.Code | Should -Be 0
            $r.Out  | Should -Match '(?i)desatualizad|versao anterior|mudou desde'
            $r.Out  | Should -Not -Match '(?i)nenhum analyze'
        }
    }

    Context "o que NAO deve disparar" {
        It "commit sem spec staged -> silencio" {
            $repo = New-RepoComSpec -Conteudo "print('oi')" -RelPath "src/app.py"
            $r = Invoke-Guarda -Repo $repo
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }

        It "comando que nao e git commit -> silencio" {
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            $r = Invoke-Guarda -Repo $repo -Comando "cd `"$repo`" && git status"
            $r.Out | Should -BeNullOrEmpty
        }

        It "spec no disco mas NAO staged -> silencio (o commit nao a leva)" {
            $repo = New-RepoComSpec -Conteudo $script:specTexto -SemStage
            $r = Invoke-Guarda -Repo $repo
            $r.Out | Should -BeNullOrEmpty
        }

        It "arquivo .md fora de specs/ -> silencio" {
            $repo = New-RepoComSpec -Conteudo $script:specTexto -RelPath "docs/outro.md"
            $r = Invoke-Guarda -Repo $repo
            $r.Out | Should -BeNullOrEmpty
        }
    }

    Context "escape e falha graciosa: NUNCA sai != 0" {
        It "PERCUS_SKIP_SPEC_ANALYZE=1 -> silencio" {
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            $env:PERCUS_SKIP_SPEC_ANALYZE = "1"
            try { $r = Invoke-Guarda -Repo $repo } finally { Remove-Item Env:PERCUS_SKIP_SPEC_ANALYZE -ErrorAction SilentlyContinue }
            $r.Code | Should -Be 0
            $r.Out  | Should -BeNullOrEmpty
        }

        It "stdin vazio, JSON quebrado e pasta sem git -> exit 0, sem excecao" -ForEach @(
            @{ Rotulo = "stdin vazio";  Stdin = "" }
            @{ Rotulo = "json quebrado"; Stdin = "{nao e json" }
            @{ Rotulo = "sem command";   Stdin = '{"tool_input":{}}' }
        ) {
            $tmp = Join-Path ([IO.Path]::GetTempPath()) "specanalyze-nogit-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $tmp | Out-Null
            Push-Location $tmp
            try { $out = $Stdin | & pwsh -NoProfile -File $script:hook 2>&1; $code = $LASTEXITCODE }
            finally { Pop-Location; Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
            $code | Should -Be 0
            ($out -join "`n") | Should -BeNullOrEmpty
        }
    }

    Context "paridade .sh -- provada por artefato, nao por texto" {
        # Na 6.46.0 a perna Cross-Claude pegou este mesmo erro: changelog afirmando "paridade
        # provada por execucao real" com so testes .ps1 no diff. A prova manual existiu, mas prova
        # que nao esta na suite nao sobrevive ao proximo refactor. Aqui o .sh roda de verdade, nos
        # MESMOS tres estados do .ps1.
        BeforeAll {
            $script:bash = (Get-Command bash -ErrorAction SilentlyContinue)

            # Dentro do BeforeAll de proposito: no Pester 5, funcao definida no corpo do Context
            # (fora de BeforeAll) nao existe para os It -- eles rodam noutro escopo.
            function Invoke-GuardaSh {
                param([string]$Repo)
                $sh = (Join-Path (Join-Path $PSScriptRoot "..") "hooks/spec-analyze-check.sh").Replace([char]92, [char]47)
                $payload = Join-Path $Repo "payload.json"
                # a sequencia git+commit e montada em runtime: escrita literal aqui, ela dispara o
                # pre-commit-check (R11) do proprio kit ao rodar a suite pelo terminal.
                $cmd = 'cd "' + ($Repo.Replace([char]92, [char]47)) + '" && git ' + 'commit -m x'
                @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress | Set-Content -Path $payload -Encoding utf8
                $saida = & $script:bash.Source -lc "bash '$sh' < '$($payload.Replace([char]92, [char]47))' 2>&1"
                return ($saida -join "`n")
            }
        }

        It ".sh: sem analyze -> avisa igual ao .ps1" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "sem bash nesta maquina"; return }
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            (Invoke-GuardaSh -Repo $repo) | Should -Match 'nenhum analyze encontrado'
        }

        It ".sh: com analyze do texto atual -> silencio" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "sem bash nesta maquina"; return }
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            Add-LogAnalyze -Repo $repo -PromptDaSpec $script:specTexto
            (Invoke-GuardaSh -Repo $repo) | Should -BeNullOrEmpty
        }

        It ".sh tambem le o JSONL linha a linha (jq no arquivo inteiro colava os prompts)" {
            if (-not (Get-Command bash -ErrorAction SilentlyContinue)) { Set-ItResult -Skipped -Because "sem bash"; return }
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            $dir = Join-Path $repo ".deepseek\council-log"
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $l1 = @{ mode = "analyze"; prompt = "analyze de OUTRA spec" } | ConvertTo-Json -Compress
            $l2 = @{ mode = "analyze"; prompt = $script:specTexto } | ConvertTo-Json -Compress
            [System.IO.File]::WriteAllText((Join-Path $dir "20260912-000000-analyze.jsonl"), "$l1`n$l2`n", (New-Object System.Text.UTF8Encoding($false)))
            (Invoke-GuardaSh -Repo $repo) | Should -BeNullOrEmpty -Because "a 2a linha cobre a spec; jq no arquivo inteiro emitiria os dois prompts colados"
        }

        It ".sh: analyze de versao anterior -> aviso de desatualizado" {
            if (-not $script:bash) { Set-ItResult -Skipped -Because "sem bash nesta maquina"; return }
            $repo = New-RepoComSpec -Conteudo ($script:specTexto + "`n`n## Secao nova`nTexto.`n")
            Add-LogAnalyze -Repo $repo -PromptDaSpec $script:specTexto
            $o = Invoke-GuardaSh -Repo $repo
            $o | Should -Match 'mudou desde entao'
            $o | Should -Not -Match 'nenhum analyze'
        }
    }

    Context "os dois furos de paridade que o R11 pegou (2026-09-12)" {
        It "log JSONL com MAIS DE UMA linha: o .ps1 nao pode cegar (era ConvertFrom-Json do arquivo inteiro)" {
            # O sufixo .jsonl promete um objeto POR LINHA. Lendo o arquivo inteiro, ConvertFrom-Json
            # devolve $null no PS 5.1 quando ha duas linhas -- e o hook diria "nenhum analyze" numa
            # spec ANALISADA. Falso negativo silencioso: o pior modo de falha de um gate.
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            $dir = Join-Path $repo ".deepseek\council-log"
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $l1 = @{ mode = "analyze"; prompt = "analyze de OUTRA spec qualquer" } | ConvertTo-Json -Compress
            $l2 = @{ mode = "analyze"; prompt = $script:specTexto } | ConvertTo-Json -Compress
            [System.IO.File]::WriteAllText((Join-Path $dir "20260912-000000-analyze.jsonl"), "$l1`n$l2`n", (New-Object System.Text.UTF8Encoding($false)))
            $r = Invoke-Guarda -Repo $repo
            $r.Out | Should -BeNullOrEmpty -Because "a 2a linha cobre esta spec; o hook tem que enxergar as duas"
        }

        It "cd SEM aspas no comando: o .sh resolvia o repo errado e silenciava" {
            if (-not (Get-Command bash -ErrorAction SilentlyContinue)) { Set-ItResult -Skipped -Because "sem bash"; return }
            # `cd /repo && git commit` (sem aspas) e a forma mais comum digitada a mao. O .sh so
            # casava aspas duplas, caia no cwd, e avisava sobre OUTRO repo -- ou calava.
            $repo = New-RepoComSpec -Conteudo $script:specTexto
            $sh = (Join-Path (Join-Path $PSScriptRoot "..") "hooks/spec-analyze-check.sh").Replace([char]92, [char]47)
            $payload = Join-Path $repo "p.json"
            $cmd = 'cd ' + ($repo.Replace([char]92, [char]47)) + ' && git ' + 'commit -m x'
            @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress | Set-Content -Path $payload -Encoding utf8
            $bash = (Get-Command bash).Source
            $saida = & $bash -lc "bash '$sh' < '$($payload.Replace([char]92, [char]47))' 2>&1"
            ($saida -join "`n") | Should -Match 'nenhum analyze encontrado' -Because "resolver a raiz pelo cwd faz o hook falar do repo errado"
        }
    }
}
