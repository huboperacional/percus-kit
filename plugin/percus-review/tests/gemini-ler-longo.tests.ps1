#requires -Version 5.1
# Prova COMPORTAMENTAL do gemini-ler-longo.ps1 (ponto 20): roda o script de verdade contra um
# `agy` FALSO (agy-falso.ps1, processo real via powershell.exe -File) e afere stdin gravado,
# fatiamento, exit code e os campos do .json de saida. O caso "vivo" (PERCUS_TESTE_AGY_VIVO) fala
# com o agy de verdade e fica pulado por padrao -- e o unico caso que gasta cota.

Describe "gemini-ler-longo.ps1 — leitor de documento longo via agy" {
    BeforeAll {
        # Join-Path so aceita Path+ChildPath no PS 5.1 (sem -AdditionalChildPath variadico do PS7+).
        $script:kitRoot   = (Resolve-Path (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "..")).Path
        $script:script    = Join-Path $script:kitRoot "scripts\gemini-ler-longo.ps1"
        $script:fixturesDir = Join-Path $PSScriptRoot "fixtures\agy"
        $script:agyFalso  = Join-Path $script:fixturesDir "agy-falso.ps1"
        $script:temps     = New-Object System.Collections.ArrayList

        function New-PastaTemp {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ("gemini-ler-longo-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            [void]$script:temps.Add($dir)
            return $dir
        }

        function Invoke-Script {
            # Recebe uma HASHTABLE de parametros (nao array): array splatado num parametro nao
            # perde a associacao nome/valor quando algum valor tem espaco (medido nesta sessao --
            # vira bind posicional puro e estoura tipo). Hashtable splat faz o bind por nome de
            # verdade.
            param(
                [hashtable]$Params,
                [string]$Fixture = (Join-Path $script:fixturesDir 'result-ok.ndjson'),
                [string]$OutDir
            )
            if (-not $OutDir) { $OutDir = New-PastaTemp }
            $env:AGY_FALSO_FIXTURE = $Fixture
            $env:AGY_FALSO_OUTDIR = $OutDir
            $env:AGY_FALSO_USAGE_FIXTURE = Join-Path $script:fixturesDir 'usage.txt'
            try {
                & $script:script @Params 2>(Join-Path $OutDir 'stderr.txt') 1>(Join-Path $OutDir 'stdout.txt')
                return [pscustomobject]@{ ExitCode = $LASTEXITCODE; OutDir = $OutDir }
            } finally {
                Remove-Item Env:\AGY_FALSO_FIXTURE -ErrorAction SilentlyContinue
                Remove-Item Env:\AGY_FALSO_OUTDIR -ErrorAction SilentlyContinue
                Remove-Item Env:\AGY_FALSO_USAGE_FIXTURE -ErrorAction SilentlyContinue
            }
        }

        function New-DocumentoLinhas {
            param([string]$Caminho, [int]$NumLinhas, [hashtable]$LinhasEspeciais = @{})
            $linhas = for ($i = 1; $i -le $NumLinhas; $i++) {
                if ($LinhasEspeciais.ContainsKey($i)) { $LinhasEspeciais[$i] } else { "linha comum $i" }
            }
            $utf8SemBom = New-Object System.Text.UTF8Encoding($false)
            [IO.File]::WriteAllText($Caminho, ($linhas -join "`n") + "`n", $utf8SemBom)
        }
    }

    AfterAll {
        foreach ($d in $script:temps) {
            try { if (Test-Path -LiteralPath $d) { [IO.Directory]::Delete($d, $true) } } catch {}
        }
    }

    Context "documento pequeno, caracteres especiais" {
        It "grava stdin em UTF-8 sem BOM, com o nome:linha e o caractere especial intactos" {
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "doc.md"
            New-DocumentoLinhas -Caminho $doc -NumLinhas 40 -LinhasEspeciais @{ 10 = "linha com ç, ã e emoji 🎉" }
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = $doc; Pergunta = 'pergunta de teste'; Saida = $saida
                MaxLinhas = 1500; AgyExe = $script:agyFalso
            } -OutDir $tmp

            $r.ExitCode | Should -Be 0

            $stdinFiles = Get-ChildItem -LiteralPath $tmp -Filter 'stdin-*.bin'
            $stdinFiles.Count | Should -Be 1

            $bytes = [IO.File]::ReadAllBytes($stdinFiles[0].FullName)
            # Sem BOM UTF-8 (EF BB BF) no inicio.
            ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $false

            $texto = [Text.Encoding]::UTF8.GetString($bytes)
            { $texto | ConvertFrom-Json -ErrorAction Stop } | Should -Not -Throw
            $obj = $texto | ConvertFrom-Json
            $obj.event | Should -Be 'user'
            $texto | Should -Match ([regex]::Escape('doc.md:L40| '))
            $texto | Should -Match 'ç'
        }
    }

    Context "fatiamento por MaxLinhas com titulo '## '" {
        It "corta em 3 fatias respeitando os titulos nas linhas 1300 e 2900" {
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "grande.md"
            New-DocumentoLinhas -Caminho $doc -NumLinhas 3200 -LinhasEspeciais @{
                1300 = '## Secao B'
                2900 = '## Secao C'
            }
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = $doc; Pergunta = 'pergunta'; Saida = $saida; AgyExe = $script:agyFalso
            } -OutDir $tmp

            $r.ExitCode | Should -Be 0
            $json = Get-Content -LiteralPath "$saida.json" -Raw | ConvertFrom-Json
            $json.fatias | Should -Be 3

            $stdinFiles = Get-ChildItem -LiteralPath $tmp -Filter 'stdin-*.bin' | Sort-Object Name
            $stdinFiles.Count | Should -Be 3

            $t1 = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($stdinFiles[0].FullName))
            $t1 | Should -Match ([regex]::Escape('grande.md:L1|'))
            $t1 | Should -Match ([regex]::Escape('grande.md:L1299|'))
            $t1 | Should -Not -Match ([regex]::Escape('grande.md:L1300|'))

            $t2 = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($stdinFiles[1].FullName))
            $t2 | Should -Match ([regex]::Escape('grande.md:L1300|'))
            $t2 | Should -Match ([regex]::Escape('grande.md:L2899|'))
            $t2 | Should -Not -Match ([regex]::Escape('grande.md:L2900|'))

            $t3 = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($stdinFiles[2].FullName))
            $t3 | Should -Match ([regex]::Escape('grande.md:L2900|'))
            $t3 | Should -Match ([regex]::Escape('grande.md:L3200|'))
        }
    }

    Context "titulo dentro de cerca de codigo nao conta" {
        It "ignora o '## ' cercado na linha 1400 e usa o corte duro em 1500" {
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "cercado.md"
            New-DocumentoLinhas -Caminho $doc -NumLinhas 1800 -LinhasEspeciais @{
                1399 = '```'
                1400 = '## Nao e titulo, esta na cerca'
                1401 = '```'
            }
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = $doc; Pergunta = 'pergunta'; Saida = $saida; AgyExe = $script:agyFalso
            } -OutDir $tmp

            $r.ExitCode | Should -Be 0
            $stdinFiles = Get-ChildItem -LiteralPath $tmp -Filter 'stdin-*.bin' | Sort-Object Name
            $stdinFiles.Count | Should -Be 2

            $t1 = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($stdinFiles[0].FullName))
            $t1 | Should -Match ([regex]::Escape('cercado.md:L1500|'))
            $t1 | Should -Not -Match ([regex]::Escape('cercado.md:L1501|'))
        }
    }

    Context "citacao fora da fatia" {
        It "marca citacoes_fora_da_fatia=1 quando a resposta cita L9999 numa fatia L1-L40" {
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "doc.md"
            New-DocumentoLinhas -Caminho $doc -NumLinhas 40
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = $doc; Pergunta = 'pergunta'; Saida = $saida; AgyExe = $script:agyFalso
            } -OutDir $tmp -Fixture (Join-Path $script:fixturesDir 'result-ok.ndjson')

            $r.ExitCode | Should -Be 0
            $json = Get-Content -LiteralPath "$saida.json" -Raw | ConvertFrom-Json
            $json.citacoes_fora_da_fatia | Should -Be 1
        }
    }

    Context "fatia com escalate_admin no meio" {
        It "exit 3, .md com fatias 1 e 3, FALHA marcada na 2, fatias_falhas=[2]" {
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "grande.md"
            New-DocumentoLinhas -Caminho $doc -NumLinhas 3200 -LinhasEspeciais @{
                1300 = '## Secao B'
                2900 = '## Secao C'
            }
            $saida = Join-Path $tmp "saida.md"
            $outDir = New-PastaTemp

            # Costura: primeira e terceira chamada usam fixture ok; a segunda usa escalate.
            # Como o agy-falso.ps1 le UMA fixture fixa por env, rodamos com um wrapper que
            # alterna a fixture por numero de chamada (via contador de stdin-*.bin ja gravados).
            $wrapperPath = Join-Path $outDir 'agy-falso-alternado.ps1'
            # Here-string de aspas SIMPLES (sem $()-expansao): aspas duplas aninhadas dentro de um
            # here-string de aspas duplas confundem o parser do powershell.exe 5.1 (medido nesta
            # sessao: token nao reconhecido logo apos o marcador de fechamento). Substitui por
            # placeholder e .Replace() depois, que nao depende de nenhum parser de expressao.
            $wrapperTemplate = @'
$n = @(Get-ChildItem -LiteralPath $env:AGY_FALSO_OUTDIR -Filter 'stdin-*.bin' -ErrorAction SilentlyContinue).Count + 1
if ($n -eq 2) { $env:AGY_FALSO_FIXTURE = 'FIXTURE_ESCALATE_PLACEHOLDER' }
else { $env:AGY_FALSO_FIXTURE = 'FIXTURE_OK_PLACEHOLDER' }
& 'AGY_FALSO_PLACEHOLDER' @args
exit $LASTEXITCODE
'@
            $wrapperConteudo = $wrapperTemplate.
                Replace('FIXTURE_ESCALATE_PLACEHOLDER', (Join-Path $script:fixturesDir 'result-vazio-escalate.ndjson')).
                Replace('FIXTURE_OK_PLACEHOLDER', (Join-Path $script:fixturesDir 'result-ok.ndjson')).
                Replace('AGY_FALSO_PLACEHOLDER', $script:agyFalso)
            [IO.File]::WriteAllText($wrapperPath, $wrapperConteudo, (New-Object Text.UTF8Encoding($true)))

            $env:AGY_FALSO_OUTDIR = $outDir
            $env:AGY_FALSO_USAGE_FIXTURE = Join-Path $script:fixturesDir 'usage.txt'
            try {
                & $script:script -Documento $doc -Pergunta 'pergunta' -Saida $saida -AgyExe $wrapperPath `
                    2>(Join-Path $outDir 'stderr.txt') 1>(Join-Path $outDir 'stdout.txt')
                $exitCode = $LASTEXITCODE
            } finally {
                Remove-Item Env:\AGY_FALSO_OUTDIR -ErrorAction SilentlyContinue
                Remove-Item Env:\AGY_FALSO_USAGE_FIXTURE -ErrorAction SilentlyContinue
                Remove-Item Env:\AGY_FALSO_FIXTURE -ErrorAction SilentlyContinue
            }

            $exitCode | Should -Be 3
            $md = Get-Content -LiteralPath $saida -Raw
            $md | Should -Match 'Fatia 1/3'
            $md | Should -Match 'Fatia 3/3'
            $md | Should -Match 'FALHA fatia 2/3: escalate_admin'
            $json = Get-Content -LiteralPath "$saida.json" -Raw | ConvertFrom-Json
            @($json.fatias_falhas) | Should -Be @(2)
        }
    }

    Context "resposta sem citacao" {
        It "exit 3 quando a resposta nao vazia nao cita nenhuma linha (sem citacao = nao escreva)" {
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "doc.md"
            New-DocumentoLinhas -Caminho $doc -NumLinhas 10
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = $doc; Pergunta = 'pergunta'; Saida = $saida; AgyExe = $script:agyFalso
            } -OutDir $tmp -Fixture (Join-Path $script:fixturesDir 'result-ok-sem-citacao.ndjson')

            $r.ExitCode | Should -Be 3
            $json = Get-Content -LiteralPath "$saida.json" -Raw | ConvertFrom-Json
            @($json.fatias_falhas) | Should -Be @(1)
            $md = Get-Content -LiteralPath $saida -Raw
            $md | Should -Match 'FALHA fatia 1/1: sem citacao'
        }
    }

    Context "sem result" {
        It "exit 3 quando o fixture so tem init" {
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "doc.md"
            New-DocumentoLinhas -Caminho $doc -NumLinhas 10
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = $doc; Pergunta = 'pergunta'; Saida = $saida; AgyExe = $script:agyFalso
            } -OutDir $tmp -Fixture (Join-Path $script:fixturesDir 'sem-result.ndjson')

            $r.ExitCode | Should -Be 3
        }
    }

    Context "uso invalido" {
        It "-AgyExe inexistente -> exit 4" {
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "doc.md"
            New-DocumentoLinhas -Caminho $doc -NumLinhas 10
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = $doc; Pergunta = 'pergunta'; Saida = $saida; AgyExe = 'C:\nao\existe.exe'
            } -OutDir $tmp

            $r.ExitCode | Should -Be 4
        }

        It "-Documento inexistente -> exit 2" {
            $tmp = New-PastaTemp
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = 'C:\nao\existe.md'; Pergunta = 'pergunta'; Saida = $saida; AgyExe = $script:agyFalso
            } -OutDir $tmp

            $r.ExitCode | Should -Be 2
        }
    }

    Context "cwd do processo falso" {
        It "roda numa pasta sob %TEMP% com prefixo agy-ler-, apagada ao fim" {
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "doc.md"
            New-DocumentoLinhas -Caminho $doc -NumLinhas 10
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = $doc; Pergunta = 'pergunta'; Saida = $saida; AgyExe = $script:agyFalso
            } -OutDir $tmp

            $r.ExitCode | Should -Be 0
            $stdinFiles = Get-ChildItem -LiteralPath $tmp -Filter 'stdin-*.bin'
            $stdinFiles.Count | Should -Be 1
            # O init.cwd do fixture eh substituido pelo cwd real do processo do agy-falso, que
            # e' criado sob %TEMP% com prefixo "agy-ler-" e apagado no finally do script real.
            # Confere indiretamente: nenhuma pasta "agy-ler-*" remanescente sob %TEMP%.
            $restantes = Get-ChildItem -Path $env:TEMP -Directory -Filter 'agy-ler-*' -ErrorAction SilentlyContinue
            $restantes.Count | Should -Be 0
        }
    }

    Context "vivo, opt-in (gasta cota)" {
        # Sem -Skip: o valor so existe de verdade depois da fase de Discovery, e -Skip:$null vira
        # $false (roda de verdade e gasta cota sem opt-in -- medido nesta sessao). Set-ItResult
        # dentro do It roda sempre na fase Run, e' avaliado por execucao, e imprime o motivo no
        # "-MostrarPulados" do rodar-suite (o campo Because).
        It "le 30 linhas reais e cita as 3 linhas com FRUTA" {
            if (-not ($env:PERCUS_TESTE_AGY_VIVO -eq '1')) {
                Set-ItResult -Skipped -Because 'PERCUS_TESTE_AGY_VIVO=1 nao definido; pulado por padrao para nao gastar cota real do agy'
                return
            }
            $tmp = New-PastaTemp
            $doc = Join-Path $tmp "frutas.md"
            $linhas = for ($i = 1; $i -le 30; $i++) {
                if ($i -in 5, 14, 27) { "linha $i tem FRUTA: banana" } else { "linha $i sem nada de especial" }
            }
            [IO.File]::WriteAllText($doc, ($linhas -join "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
            $saida = Join-Path $tmp "saida.md"

            $r = Invoke-Script -Params @{
                Documento = $doc; Pergunta = 'liste as 3 linhas que contem FRUTA'; Saida = $saida
            } -OutDir $tmp

            $r.ExitCode | Should -Be 0
            $md = Get-Content -LiteralPath $saida -Raw
            $md | Should -Match 'L5'
            $md | Should -Match 'L14'
            $md | Should -Match 'L27'
        }
    }
}
