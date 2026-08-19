#requires -Version 5.1
# O _registry.json e DESCRICAO, nao configuracao: nenhum script o le em runtime. Quem decide
# HTTP-vs-marcador e o council-orchestrator (Test-Path do wrapper + ANTHROPIC_API_KEY).
#
# Por isso ele pode mentir sem que nada quebre -- e mentiu. Ate 6.41.0 declarava o cross-claude
# como "type: agent-marker" com wrapper null, e um verbete de diagnostico concluiu, partindo
# dessa linha, que o provider "nao deveria ser chamado por HTTP". A premissa era falsa e a
# investigacao inteira saiu torta.
#
# Este arquivo existe para que a proxima divergencia falhe AQUI e nao dentro de um diagnostico.
# Foi a condicao que o conselho poe em cima da decisao B (2026-08-19, 2/3): registry honesto SO
# vale acompanhado de teste que o force a acompanhar o codigo. A perna dissidente (DeepSeek)
# queria apagar o arquivo -- "arquivo morto e pior que ausente"; o teste e o que o mantem vivo.
#
# Nenhum teste aqui chama API: todos leem fonte e o proprio registry.

Describe "_registry.json descreve o que o orquestrador realmente faz" {

    BeforeAll {
        $script:raiz     = Split-Path $PSScriptRoot -Parent
        $script:provDir  = Join-Path $script:raiz "providers"
        $script:registry = Get-Content (Join-Path $script:provDir "_registry.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $script:orchPs1  = Get-Content (Join-Path $script:raiz "scripts/council-orchestrator.ps1") -Raw
        $script:orchSh   = Get-Content (Join-Path $script:raiz "scripts/council-orchestrator.sh")  -Raw
    }

    It "o registry tem providers (anti-vacuidade)" {
        # Sem isto, um registry vazio ou com chave renomeada faria todo -ForEach abaixo rodar
        # zero vez e o arquivo inteiro passaria verde sem aferir nada.
        @($script:registry.providers).Count | Should -BeGreaterThan 2
    }

    It "todo wrapper declarado existe no disco" {
        foreach ($p in $script:registry.providers) {
            foreach ($campo in @("wrapper_ps1", "wrapper_sh")) {
                $rel = $p.$campo
                if ($rel) {
                    $abs = Join-Path $script:raiz $rel
                    Test-Path $abs | Should -Be $true -Because "$($p.id).$campo aponta para $rel"
                }
            }
        }
    }

    It "provider que o orquestrador chama por HTTP nao pode estar declarado agent-marker" {
        # A regressao exata de 2026-08-19. O orquestrador monta o caminho direto por Test-Path
        # do wrapper; se ha essa linha para o provider, o registry nao pode dizer que ele e
        # so-marcador.
        # Varre os DOIS orquestradores. Olhar so o .ps1 deixaria o .sh ganhar um dispatch HTTP
        # sozinho com o registry ainda dizendo agent-marker -- teste verde, mentira de volta.
        foreach ($p in $script:registry.providers) {
            foreach ($orq in @(
                @{ Src = $script:orchPs1; Ext = 'ps1'; Nome = 'council-orchestrator.ps1' }
                @{ Src = $script:orchSh;  Ext = 'sh';  Nome = 'council-orchestrator.sh'  }
            )) {
                if ($orq.Src -match [regex]::Escape("$($p.id).$($orq.Ext)")) {
                    $p.type | Should -Not -Be "agent-marker" -Because "$($p.id) tem dispatch HTTP direto no $($orq.Nome)"
                }
            }
        }
    }

    It "provider com type http* declara os dois wrappers" {
        foreach ($p in $script:registry.providers | Where-Object { $_.type -like "http*" }) {
            $p.wrapper_ps1 | Should -Not -BeNullOrEmpty -Because "$($p.id) e type=$($p.type)"
            $p.wrapper_sh  | Should -Not -BeNullOrEmpty -Because "$($p.id) e type=$($p.type)"
        }
    }

    It "marker declarado e o mesmo que os dois orquestradores emitem" {
        foreach ($p in $script:registry.providers | Where-Object { $_.marker }) {
            $script:orchPs1 | Should -Match ([regex]::Escape($p.marker)) -Because "marker de $($p.id) no .ps1"
            $script:orchSh  | Should -Match ([regex]::Escape($p.marker)) -Because "marker de $($p.id) no .sh"
        }
    }

    It "type hibrido explica por que existe (senao vira prosa de novo)" {
        foreach ($p in $script:registry.providers | Where-Object { $_.type -eq "http-or-marker" }) {
            $p._nota_type | Should -Not -BeNullOrEmpty
            $p._nota_type | Should -Match "cache_control" -Because "o motivo do caminho direto e o prompt caching; sem ele alguem 'simplifica' e perde a economia"
        }
    }
}
