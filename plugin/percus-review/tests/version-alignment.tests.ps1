#requires -Version 5.1
# Tests: os 4 lugares que guardam a versao do kit concordam entre si.
#
#   plugin/percus-review/plugin.json   -> versao do plugin (o que o wrapper loga)
#   .claude-plugin/marketplace.json    -> versao publicada (vira o NOME DA PASTA no install)
#   .percus-version                    -> versao adotada pelo repo
#   CANON_VERSION.md                   -> versao canonica + changelog (R25, fonte unica)
#
# A convencao ja existia ("Versoes alinhadas: ... = 6.29.0" no changelog) e ja derrapou
# pelo menos 3 vezes por depender de alguem lembrar: marketplace.json travado em 6.16.1,
# depois um patch atras em 6.26.0, e em 2026-07-27 estava 9 versoes atras (6.29.0 vs
# 6.31.1). Nada quebra na hora — mas um republish futuro nasce com o numero errado e o
# diretorio instalado passa a mentir sobre o que tem dentro.

Describe "versao do kit — os 4 arquivos concordam" {
    BeforeAll {
        # tests/ -> percus-review/ -> plugin/ -> raiz do canon
        $script:canonRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..") -ErrorAction SilentlyContinue).Path
        if (-not $script:canonRoot -or -not (Test-Path (Join-Path $script:canonRoot "CANON_VERSION.md"))) {
            if ($env:PERCUS_CANON_DIR -and (Test-Path (Join-Path $env:PERCUS_CANON_DIR "CANON_VERSION.md"))) {
                $script:canonRoot = $env:PERCUS_CANON_DIR
            } else {
                $script:canonRoot = $null
            }
        }

        $script:pluginVersion = $null
        if ($script:canonRoot) {
            $pj = Join-Path $script:canonRoot "plugin\percus-review\plugin.json"
            $script:pluginVersion = (Get-Content $pj -Raw | ConvertFrom-Json).version
        }
    }

    It "plugin.json tem versao semver" {
        if (-not $script:canonRoot) { Set-ItResult -Skipped -Because "rodando fora do repo do canon (sem CANON_VERSION.md em ..\..\.. nem em PERCUS_CANON_DIR)"; return }
        $script:pluginVersion | Should -Match '^\d+\.\d+\.\d+$'
    }

    It "marketplace.json declara a MESMA versao do plugin.json" {
        if (-not $script:canonRoot) { Set-ItResult -Skipped -Because "rodando fora do repo do canon"; return }
        $mk = Get-Content (Join-Path $script:canonRoot ".claude-plugin\marketplace.json") -Raw | ConvertFrom-Json
        $entry = @($mk.plugins) | Where-Object { $_.name -eq "percus-review" } | Select-Object -First 1
        $entry | Should -Not -BeNullOrEmpty
        $entry.version | Should -Be $script:pluginVersion -Because "esta versao vira o NOME DA PASTA no install; atrasada, o republish nasce errado"
    }

    It "as DESCRICOES comecam com a versao atual -- e o que aparece no painel de plugins" {
        # A versao passou a abrir a description porque o painel de plugins do VSCode mostra so a
        # description: sem ela, nao da pra saber qual versao esta instalada sem abrir arquivo.
        #
        # Duplicar dado e convite pra drift, e por isso este It existe: bumpar e esquecer de
        # atualizar a description vira falha VERMELHA, nao divergencia silenciosa. Sem esta
        # amarra, a melhoria viraria uma mentira no painel -- pior que nao ter numero nenhum,
        # porque numero errado parece informacao.
        #
        # O que NAO entra na description continua nao entrando: o changelog vive so no
        # CANON_VERSION.md (R25, single-source). Numero da versao nao e changelog.
        if (-not $script:canonRoot) { Set-ItResult -Skipped -Because "rodando fora do repo do canon"; return }

        $pj = Get-Content (Join-Path $script:canonRoot "plugin\percus-review\plugin.json") -Raw | ConvertFrom-Json
        $pj.description | Should -BeLike "v$($script:pluginVersion) |*" -Because "plugin.json: a description tem que abrir com a versao atual"

        $mk = Get-Content (Join-Path $script:canonRoot ".claude-plugin\marketplace.json") -Raw | ConvertFrom-Json
        $entry = @($mk.plugins) | Where-Object { $_.name -eq "percus-review" } | Select-Object -First 1
        $entry.description | Should -BeLike "v$($script:pluginVersion) |*" -Because "marketplace.json: e ESTA a description que o painel de plugins mostra"
    }

    It ".percus-version tem a MESMA versao do plugin.json" {
        if (-not $script:canonRoot) { Set-ItResult -Skipped -Because "rodando fora do repo do canon"; return }
        (Get-Content (Join-Path $script:canonRoot ".percus-version") -Raw).Trim() |
            Should -Be $script:pluginVersion
    }

    It "CANON_VERSION.md declara a MESMA versao no cabecalho" {
        if (-not $script:canonRoot) { Set-ItResult -Skipped -Because "rodando fora do repo do canon"; return }
        $canon = Get-Content (Join-Path $script:canonRoot "CANON_VERSION.md") -Raw
        $m = [regex]::Match($canon, 'Vers[^\r\n]*canônica[^\r\n]*`(\d+\.\d+\.\d+)`')
        $m.Success | Should -Be $true -Because "o cabecalho do CANON_VERSION e a fonte unica declarada (R25)"
        $m.Groups[1].Value | Should -Be $script:pluginVersion
    }

    It "CANON_VERSION.md tem entrada de changelog da versao atual (bump sem changelog e R25 violado)" {
        if (-not $script:canonRoot) { Set-ItResult -Skipped -Because "rodando fora do repo do canon"; return }
        $canon = Get-Content (Join-Path $script:canonRoot "CANON_VERSION.md") -Raw
        $canon | Should -Match ("## Changelog v" + [regex]::Escape($script:pluginVersion) + "\b")
    }
}
