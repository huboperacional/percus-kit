#requires -Version 5.1
# Prova COMPORTAMENTAL do bump-canon.ps1: roda o script de verdade num canon
# temporario e afere os arquivos resultantes. Os 7 pontos de versao estao
# espalhados por 4 arquivos -- e exatamente por isso que fazer na mao falha.

Describe "bump-canon.ps1 — bump dos 7 pontos de versao" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:script  = Join-Path $script:kitRoot "scripts\bump-canon.ps1"
        $script:temps   = New-Object System.Collections.ArrayList

        function New-CanonFalso {
            param([string]$Versao = "6.35.0", [string]$VersaoMarketplace = "")
            if (-not $VersaoMarketplace) { $VersaoMarketplace = $Versao }
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("bump-canon-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path (Join-Path $dir "plugin\percus-review") -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $dir ".claude-plugin") -Force | Out-Null

            $utf8 = New-Object System.Text.UTF8Encoding($false)
            [IO.File]::WriteAllText((Join-Path $dir "CANON_VERSION.md"), @"
# Canon Percus — versão atual

**Versão canônica em ``huboperacional/percus-kit``:** ``$Versao``

> Nota qualquer que nao pode ser destruida pelo bump.

## Changelog v$Versao — 2026-08-07

- coisa antiga

## Changelog v6.34.1 — 2026-07-31

- coisa mais antiga
"@, $utf8)

            [IO.File]::WriteAllText((Join-Path $dir "plugin\percus-review\plugin.json"), @"
{
  "name": "percus-review",
  "version": "$Versao",
  "description": "v$Versao | Percus kit — descricao que precisa manter o resto."
}
"@, $utf8)

            [IO.File]::WriteAllText((Join-Path $dir ".claude-plugin\marketplace.json"), @"
{
  "name": "percus-tools",
  "plugins": [
    {
      "name": "percus-review",
      "description": "v$VersaoMarketplace | Review cross-provider — resto da descricao.",
      "version": "$VersaoMarketplace",
      "source": "./plugin/percus-review"
    }
  ]
}
"@, $utf8)

            [IO.File]::WriteAllText((Join-Path $dir ".percus-version"), "$Versao`n", $utf8)

            [void]$script:temps.Add($dir)
            return $dir
        }

        function Invoke-Bump {
            param([string]$Raiz, [string]$Versao, [string]$Data = "2026-08-13")
            $saida = & $script:script -Raiz $Raiz -Versao $Versao -Data $Data 2>&1 | Out-String
            return [pscustomobject]@{ Ok = $?; Saida = $saida.Trim() }
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "leva os 4 arquivos para a versao nova" {
        $raiz = New-CanonFalso
        Invoke-Bump -Raiz $raiz -Versao "6.36.0" | Out-Null

        (Get-Content (Join-Path $raiz "CANON_VERSION.md") -Raw) | Should -Match '\*\*Vers.o can.nica[^`]*`[^`]*`:\*\* `6\.36\.0`'
        (Get-Content (Join-Path $raiz "plugin\percus-review\plugin.json") -Raw | ConvertFrom-Json).version | Should -Be "6.36.0"
        (Get-Content (Join-Path $raiz ".claude-plugin\marketplace.json") -Raw | ConvertFrom-Json).plugins[0].version | Should -Be "6.36.0"
        (Get-Content (Join-Path $raiz ".percus-version") -Raw).Trim() | Should -Be "6.36.0"
    }

    It "as DESCRICOES abrem com a versao nova (e o resto do texto sobrevive)" {
        $raiz = New-CanonFalso
        Invoke-Bump -Raiz $raiz -Versao "6.36.0" | Out-Null

        $pj = Get-Content (Join-Path $raiz "plugin\percus-review\plugin.json") -Raw | ConvertFrom-Json
        $pj.description | Should -BeLike "v6.36.0 |*"
        $pj.description | Should -BeLike "*descricao que precisa manter o resto.*"

        $mp = Get-Content (Join-Path $raiz ".claude-plugin\marketplace.json") -Raw | ConvertFrom-Json
        $mp.plugins[0].description | Should -BeLike "v6.36.0 |*"
        $mp.plugins[0].description | Should -BeLike "*resto da descricao.*"
    }

    It "insere secao de changelog da versao nova ACIMA da anterior" {
        $raiz = New-CanonFalso
        Invoke-Bump -Raiz $raiz -Versao "6.36.0" | Out-Null

        $canon = Get-Content (Join-Path $raiz "CANON_VERSION.md") -Raw
        $canon | Should -Match '## Changelog v6\.36\.0 — 2026-08-13'
        $canon.IndexOf('## Changelog v6.36.0') | Should -BeLessThan $canon.IndexOf('## Changelog v6.35.0')
    }

    It "preserva o conteudo que nao e versao" {
        $raiz = New-CanonFalso
        Invoke-Bump -Raiz $raiz -Versao "6.36.0" | Out-Null

        (Get-Content (Join-Path $raiz "CANON_VERSION.md") -Raw) |
            Should -Match 'Nota qualquer que nao pode ser destruida pelo bump'
    }

    It "RECUSA versao fora do semver" {
        $raiz = New-CanonFalso
        $r = Invoke-Bump -Raiz $raiz -Versao "6.36"

        $r.Saida | Should -Match 'semver|invalida'
        (Get-Content (Join-Path $raiz ".percus-version") -Raw).Trim() | Should -Be "6.35.0" -Because "recusa nao pode ter mexido em nada"
    }

    It "RECUSA versao que nao avanca (protege contra bump pra tras)" {
        $raiz = New-CanonFalso
        $r = Invoke-Bump -Raiz $raiz -Versao "6.34.0"

        $r.Saida | Should -Match 'anterior|menor|avanc'
        (Get-Content (Join-Path $raiz ".percus-version") -Raw).Trim() | Should -Be "6.35.0"
    }

    It "RECUSA bumpar quando ja existe drift entre os arquivos" {
        # Sem isto o bump e PARCIAL e SILENCIOSO: o script troca a string da versao
        # do cabecalho, e o arquivo que ja estava divergente fica pra tras sem aviso
        # -- drift que o bump deveria eliminar, sobrevivendo ao bump.
        $raiz = New-CanonFalso -Versao "6.35.0" -VersaoMarketplace "6.34.0"
        $r = Invoke-Bump -Raiz $raiz -Versao "6.36.0"

        $r.Saida | Should -Match 'drift|diverg'
        (Get-Content (Join-Path $raiz ".percus-version") -Raw).Trim() | Should -Be "6.35.0" -Because "recusa nao pode ter mexido em nada"
        (Get-Content (Join-Path $raiz "CANON_VERSION.md") -Raw) | Should -Match '`6\.35\.0`'
    }

    It "RECUSA drift que esta so na description (o numero duplicado no painel)" {
        $raiz = New-CanonFalso -Versao "6.35.0"
        $f = Join-Path $raiz "plugin\percus-review\plugin.json"
        $txt = ([IO.File]::ReadAllText($f)) -replace '"v6\.35\.0 \| ', '"v6.34.0 | '
        [IO.File]::WriteAllText($f, $txt, (New-Object System.Text.UTF8Encoding($false)))

        $r = Invoke-Bump -Raiz $raiz -Versao "6.36.0"

        $r.Saida | Should -Match 'drift|diverg'
        (Get-Content (Join-Path $raiz ".percus-version") -Raw).Trim() | Should -Be "6.35.0"
    }

    It "RECUSA repetir a versao atual" {
        $raiz = New-CanonFalso
        $r = Invoke-Bump -Raiz $raiz -Versao "6.35.0"

        $r.Saida | Should -Match 'anterior|menor|igual|avanc'
    }
}
