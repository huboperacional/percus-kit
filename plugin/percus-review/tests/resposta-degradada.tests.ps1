#requires -Version 5.1
# Prova que resposta vazia e resposta cortada NAO se chamam "ok".
#
# Bug medido em 2026-07-31, no pre-mortem do plano 2. Os tres providers gravavam status="ok"
# sempre que a chamada HTTP dava certo, sem nunca olhar o conteudo. Numa mesma rodada:
#
#   DeepSeek      completion=1024, reasoning=1024, content=""            -> reportado "ok"
#   Cross-Claude  completion=1024, content cortado no meio de uma frase  -> reportado "ok"
#
# Das tres pernas do conselho, uma nao respondeu e outra respondeu pela metade, e o orquestrador
# devolveu as duas como sucesso. E a mesma classe de bug do resto deste plano: a coisa nao
# aconteceu e ninguem soube.
#
# Os numeros usados aqui sao os REAIS das duas falhas, copiados do log, e nao valores inventados
# que confirmariam o que eu quero.

Describe "Get-StatusResposta -- resposta vazia e cortada tem nome proprio" {

    BeforeAll {
        . (Join-Path $PSScriptRoot ".." "providers" "_resposta.ps1")

        # usage real da perna DeepSeek que voltou vazia
        $script:usoVazio = [pscustomobject]@{
            completion_tokens = 1024
            completion_tokens_details = [pscustomobject]@{ reasoning_tokens = 1024 }
        }
        # usage real da rodada de consult que FUNCIONOU (611 completion, 498 reasoning, 113 de resposta)
        $script:usoBom = [pscustomobject]@{
            completion_tokens = 611
            completion_tokens_details = [pscustomobject]@{ reasoning_tokens = 498 }
        }
    }

    It "resposta com texto e finish_reason=stop e 'ok'" {
        $r = Get-StatusResposta -Conteudo "Opcao A. Porque elimina o canal fragil." -FinishReason "stop" -Usage $script:usoBom
        $r.Status | Should -BeExactly "ok"
        $r.Aviso  | Should -BeNullOrEmpty
    }

    It "conteudo VAZIO nunca e 'ok' -- <Rotulo>" -ForEach @(
        @{ Rotulo = "string vazia";    Texto = "" }
        @{ Rotulo = "so espaco";       Texto = "   " }
        @{ Rotulo = "so quebra";       Texto = "`n`n" }
        @{ Rotulo = "nulo";            Texto = $null }
    ) {
        $r = Get-StatusResposta -Conteudo $Texto -FinishReason "stop" -Usage $script:usoVazio
        $r.Status | Should -BeExactly "empty" -Because "resposta vazia nao e resposta"
        $r.Aviso  | Should -Not -BeNullOrEmpty
    }

    It "com reasoning gasto, o aviso NOMEIA a causa em vez de so dizer 'vazio'" {
        # O aviso e o que faz alguem consertar a coisa certa. "vazio" manda procurar erro de API;
        # "gastou o teto raciocinando" manda subir o teto, que e o conserto de verdade.
        $r = Get-StatusResposta -Conteudo "" -FinishReason "stop" -Usage $script:usoVazio
        $r.Aviso | Should -Match "RACIOCINANDO|MaxTokens"
        $r.Aviso | Should -Match "1024"
    }

    It "finish_reason=length e 'truncated', mesmo com conteudo presente" {
        # O caso do Cross-Claude: veio texto, e ainda assim a resposta esta incompleta. Se isto
        # contasse como "ok", a conclusao que o modelo nao chegou a escrever passaria por ausencia
        # de conclusao -- e ninguem saberia que faltou pedaco.
        $r = Get-StatusResposta -Conteudo "risco 3: o trampolim assume PERCUS_CANON_DIR setado e fal" -FinishReason "length" -Usage $script:usoVazio
        $r.Status | Should -BeExactly "truncated"
        $r.Aviso  | Should -Match "CORTADA|MaxTokens"
    }

    It "finish_reason e comparado com caixa exata" {
        # -ceq de proposito: "Length" nao e "length". Comparacao frouxa aqui classificaria
        # truncado como ok, que e o falso verde mais caro dos dois.
        $r = Get-StatusResposta -Conteudo "texto" -FinishReason "Length" -Usage $script:usoBom
        $r.Status | Should -BeExactly "ok" -Because "so o valor exato da API conta; qualquer outro e tratado como resposta normal"
    }
}

Describe "os tres providers usam o classificador, e nenhum grava 'ok' na mao" {

    BeforeAll { $script:provDir = Join-Path $PSScriptRoot ".." "providers" }

    It "<Prov> chama Get-StatusResposta e nao hardcoda status=ok" -ForEach @(
        @{ Prov = "deepseek.ps1" }
        @{ Prov = "groq-llama.ps1" }
        @{ Prov = "cross-claude.ps1" }
    ) {
        # Piso contra correcao pela metade: consertar dois dos tres providers deixaria a suite
        # verde e uma perna do conselho ainda mentindo. Foi exatamente assim que tres guardas
        # ficaram mortas em 2026-07-30.
        $texto = Get-Content (Join-Path $script:provDir $Prov) -Raw
        $texto | Should -Match 'Get-StatusResposta' -Because "$Prov precisa classificar a propria resposta"
        $texto | Should -Match '_resposta\.ps1'     -Because "$Prov precisa carregar o classificador compartilhado"

        $vivas = @(Get-Content (Join-Path $script:provDir $Prov) | Where-Object { -not "$_".TrimStart().StartsWith('#') })
        @($vivas | Where-Object { $_ -match 'status\s*=\s*"ok"' }) |
            Should -BeNullOrEmpty -Because "$Prov nao pode declarar sucesso sem olhar o conteudo"
    }

    It "o teto de tokens sobe acima de 1024 nos tres -- 1024 foi o numero que quebrou" {
        # Nao e crendice com o numero: em modelo que pensa os reasoning_tokens contam DENTRO de
        # completion_tokens (medido no deepseek-v4-pro), entao 1024 deixa um prompt dificil sem
        # orcamento pra resposta. O teto certo depende do modelo, mas nenhum dos tres pode
        # continuar em 1024.
        foreach ($p in @("deepseek.ps1","groq-llama.ps1","cross-claude.ps1")) {
            $t = Get-Content (Join-Path $script:provDir $p) -Raw
            if ($t -match '\[int\]\$MaxTokens\s*=\s*(\d+)') {
                [int]$matches[1] | Should -BeGreaterThan 1024 -Because "$p ainda esta no teto que produziu resposta vazia"
            } else {
                throw "$p nao declara MaxTokens -- nao-verificado, nao 'ok'"
            }
        }
    }
}
