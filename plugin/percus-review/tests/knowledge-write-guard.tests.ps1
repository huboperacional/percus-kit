#requires -Version 5.1
# Prova COMPORTAMENTAL do guard de escrita em conhecimento: roda o hook de verdade com
# payload de PreToolUse e afere o que ele barra.
#
# Por que este hook existe: R23 diz "nao edite o monolito direto" em TRES lugares
# (01_REGRAS_INEGOCIAVEIS.md, skill consult-knowledge, entrada/LEIA-ME.md) e nenhum hook
# conseguia ver a violacao -- os 12 registrados casavam Bash|PowerShell ou ExitPlanMode,
# nunca Edit/Write. Regra escrita em tres lugares e enforcada em nenhum. Medido em
# 2026-08-18: 14 verbetes entraram por esse caminho, 11 deles commitados havia semanas.
#
# E a MESMA classe do incidente de 2026-07-31 (matcher so "Bash", a tool PowerShell
# passava livre). Naquela vez o ponto cego mudou de andar; nao sumiu.

Describe "knowledge-write-guard.ps1 hook" {
    BeforeAll {
        $script:hookPath = Join-Path $PSScriptRoot ".." "hooks" "knowledge-write-guard.ps1"

        function Invoke-Guard {
            param([string]$Tool, [string]$Caminho, [hashtable]$Env = @{})
            $payload = @{
                tool_name  = $Tool
                tool_input = @{ file_path = $Caminho }
            } | ConvertTo-Json -Depth 5

            $antigos = @{}
            foreach ($k in $Env.Keys) {
                $antigos[$k] = [Environment]::GetEnvironmentVariable($k)
                [Environment]::SetEnvironmentVariable($k, $Env[$k])
            }
            try {
                $saida = ($payload | & pwsh -NoProfile -File $script:hookPath 2>&1) | Out-String
                return [pscustomobject]@{ Exit = $LASTEXITCODE; Saida = $saida }
            } finally {
                foreach ($k in $antigos.Keys) { [Environment]::SetEnvironmentVariable($k, $antigos[$k]) }
            }
        }
    }

    It "existe" {
        Test-Path $script:hookPath | Should -Be $true
    }

    It "PERMITE escrita em arquivo que nao e base de conhecimento" {
        $r = Invoke-Guard -Tool "Write" -Caminho "src/app/main.py"
        $r.Exit | Should -Be 0 -Because "guard que barra o repo inteiro e guard que sera desligado. Saida: $($r.Saida)"
    }

    It "BLOQUEIA Write em conhecimento/COMO_RESOLVER.md" {
        $r = Invoke-Guard -Tool "Write" -Caminho "conhecimento/COMO_RESOLVER.md"
        $r.Exit | Should -Be 2 -Because "R23: o monolito nao se edita direto. Saida: $($r.Saida)"
    }

    It "BLOQUEIA Edit em conhecimento/COMO_FAZER.md" {
        # As duas tools trazem o alvo no MESMO campo (tool_input.file_path), entao o hook nao
        # ramifica por tool_name -- mesma licao do teste de guarda de comando no manifesto.
        $r = Invoke-Guard -Tool "Edit" -Caminho "conhecimento/COMO_FAZER.md"
        $r.Exit | Should -Be 2 -Because "COMO_FAZER tem o mesmo problema de um-arquivo-N-escritores. Saida: $($r.Saida)"
    }

    It "BLOQUEIA tambem por caminho ABSOLUTO, com barra invertida do Windows" {
        # O agente quase sempre passa caminho absoluto; casar so a forma relativa seria uma
        # guarda que nunca dispara no uso real -- a ausencia silenciosa que o R20 ja pagou caro.
        $r = Invoke-Guard -Tool "Write" -Caminho "D:\Claud Automations\percus-kit\conhecimento\COMO_RESOLVER.md"
        $r.Exit | Should -Be 2 -Because "caminho absoluto e a forma COMUM, nao a excecao. Saida: $($r.Saida)"
    }

    It "PERMITE escrita no VERBETE -- e ele e o caminho abencoado, nao pode barrar" {
        $r = Invoke-Guard -Tool "Write" -Caminho "conhecimento/resolver/meu-verbete.md"
        $r.Exit | Should -Be 0 -Because "escrever conhecimento/<area>/<slug>.md e exatamente o que o guard manda fazer. Saida: $($r.Saida)"
    }

    It "PERMITE escrita no LEIA-ME da area (documentacao, nao gerado)" {
        $r = Invoke-Guard -Tool "Write" -Caminho "conhecimento/resolver/LEIA-ME.md"
        $r.Exit | Should -Be 0 -Because "LEIA-ME e documentacao escrita a mao, nao artefato gerado. Saida: $($r.Saida)"
    }

    It "a mensagem de BLOCK ENSINA o caminho certo, nao so recusa" {
        # Guard que so diz nao ensina a contornar. O texto tem de dizer para onde ir.
        $r = Invoke-Guard -Tool "Write" -Caminho "conhecimento/COMO_RESOLVER.md"
        $r.Saida | Should -Match 'conhecimento/resolver/<slug>\.md'
        $r.Saida | Should -Match 'R23'
    }

    It "emite a assinatura do manifesto no STDERR (o canario conta por ela)" {
        $r = Invoke-Guard -Tool "Write" -Caminho "conhecimento/COMO_RESOLVER.md"
        $r.Saida | Should -Match '\[percus:hook knowledge-write\]'
    }

    It "BLOQUEIA edicao a mao do INDICE.md (ele e GERADO)" {
        # Indice divergente do conteudo foi o defeito que deixou 14 verbetes invisiveis por
        # semanas. Depois da migracao o indice e artefato, e artefato editado a mao mente.
        $r = Invoke-Guard -Tool "Edit" -Caminho "conhecimento/resolver/INDICE.md"
        $r.Exit | Should -Be 2 -Because "Saida: $($r.Saida)"
        $r.Saida | Should -Match 'gerar-indice-conhecimento'
    }

    It "BLOQUEIA tambem em referencia/conhecimento/ -- as MESMAS 4 areas do gate" {
        # O comentario deste hook prometia "as mesmas areas" e cobria so 2 das 4. Editar a mao
        # referencia/conhecimento/resolver/INDICE.md passava livre, reintroduzindo a divergencia
        # indice-conteudo que a 6.38.0 existe pra matar (R11 round 6, 2026-08-18).
        $r = Invoke-Guard -Tool "Edit" -Caminho "referencia/conhecimento/resolver/INDICE.md"
        $r.Exit | Should -Be 2 -Because "Saida: $($r.Saida)"
    }

    It "BLOQUEIA recriar o monolito em referencia/conhecimento/ tambem" {
        $r = Invoke-Guard -Tool "Write" -Caminho "referencia/conhecimento/COMO_RESOLVER.md"
        $r.Exit | Should -Be 2 -Because "Saida: $($r.Saida)"
    }

    It "o escape PERCUS_SKIP_KNOWLEDGE_GUARD=1 libera" {
        $r = Invoke-Guard -Tool "Write" -Caminho "conhecimento/COMO_RESOLVER.md" -Env @{ PERCUS_SKIP_KNOWLEDGE_GUARD = "1" }
        $r.Exit | Should -Be 0 -Because "escape declarado no manifesto tem de abrir. Saida: $($r.Saida)"
    }

    It "o escape geral PERCUS_HOOKS_DISABLED=1 libera" {
        $r = Invoke-Guard -Tool "Write" -Caminho "conhecimento/COMO_RESOLVER.md" -Env @{ PERCUS_HOOKS_DISABLED = "1" }
        $r.Exit | Should -Be 0 -Because "escape geral vale pra todo hook. Saida: $($r.Saida)"
    }

    It "stdin vazio -> exit 0 (graceful, nao trava o harness)" {
        $saida = ("" | & pwsh -NoProfile -File $script:hookPath 2>&1)
        $LASTEXITCODE | Should -Be 0
    }

    It "payload sem file_path -> exit 0 (nao bloqueia o que nao entende)" {
        $payload = '{"tool_name":"Write","tool_input":{}}'
        $saida = ($payload | & pwsh -NoProfile -File $script:hookPath 2>&1)
        $LASTEXITCODE | Should -Be 0
    }
}
