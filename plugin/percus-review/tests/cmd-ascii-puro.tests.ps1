#requires -Version 5.1
# Prova que todo wrapper .cmd do kit e ASCII PURO -- e que os dispatchers rodam de verdade.
#
# CLASSE NOVA, irma das outras duas e diferente das duas:
#
#   ps51-compat        -> o .ps1 FONTE sem BOM nao PARSEIA no 5.1.     Conserto: BOM no .ps1.
#   hooks-leitura-utf8 -> o .md/.json LIDO decodifica errado no 5.1.   Conserto: -Encoding UTF8.
#   esta aqui          -> o .cmd com byte nao-ASCII quebra o cmd.exe.  Conserto: .cmd so ASCII.
#
# O cmd.exe le arquivo de lote por DESLOCAMENTO DE BYTE e reposiciona a cada comando. Um
# caractere multi-byte faz o contador de bytes e o de caracteres divergirem, e a partir dai
# ele reposiciona no lugar errado: o inicio das linhas some.
#
# MEDIDO em 2026-09-13, no `percus-dispatch-post.cmd`: um unico `⚠️` (U+26A0 U+FE0F = 6 bytes
# para 2 caracteres, diferenca de 4) fazia o cmd comer exatamente 4 caracteres do inicio das
# linhas -- `setlocal` virava `ocal`, `REM Dispatcher` virava `Dispatcher` -- e o dispatcher
# saia com **exit 255 em toda tool call**. Removido o emoji, exit 0 e stderr limpo. Era o
# unico .cmd do kit com byte nao-ASCII, e era o unico quebrado.
#
# Por que passou despercebido: sob codepage UTF-8 (65001, o do Git Bash) byte e caractere
# coincidem e NAO ha deriva. O defeito so aparece na codepage OEM, que e a que o Claude Code
# usa de verdade no Windows PT-BR. Rodar o .cmd "na mao" pelo terminal errado da verde.

Describe "wrapper .cmd e ASCII puro" {

    BeforeAll {
        $script:kitRoot  = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:hooksDir = Join-Path (Split-Path $PSScriptRoot -Parent) "hooks"
    }

    It "nenhum .cmd do kit tem byte fora de ASCII" {
        $arqs = @(Get-ChildItem $script:kitRoot -Recurse -Filter *.cmd -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' })

        # Anti-vacuidade: varredura vazia satisfaria o Should -BeNullOrEmpty guardando nada.
        $arqs.Count | Should -BeGreaterThan 10 -Because "o kit tem 15+ wrappers .cmd; varredura curta e varredura quebrada"

        $achados = @()
        foreach ($a in $arqs) {
            $bytes = [IO.File]::ReadAllBytes($a.FullName)
            $maus = @()
            for ($i = 0; $i -lt $bytes.Length; $i++) {
                if ($bytes[$i] -ge 128) { $maus += $i }
            }
            if ($maus.Count -gt 0) {
                $achados += ("{0} -- {1} byte(s) fora de ASCII, 1o no offset {2}" -f
                    $a.FullName.Replace($script:kitRoot + '\', ''), $maus.Count, $maus[0])
            }
        }

        $achados | Should -BeNullOrEmpty -Because "cmd.exe le lote por offset de byte; multi-byte desalinha e come o inicio das linhas"
    }

    Context "os dois dispatchers rodam de verdade pelo caminho de producao" {

        # Prova COMPORTAMENTAL, nao so estatica: invoca como o Claude Code invoca --
        # `cmd.exe /c "<caminho absoluto>"` com stdin redirecionado. Com o emoji no lugar,
        # isto dava exit 255; a guarda estatica acima e barata, esta aqui e a que prova.
        # PERCUS_HOOKS_DISABLED=1 faz o dispatcher sair cedo, sem rodar check nenhum:
        # exercita o PARSE do lote sem efeito colateral.
        BeforeAll {
            function Invoke-CmdDireto {
                param([string]$Caminho)
                $tmp = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N').Substring(0,8))
                New-Item -ItemType Directory -Path $tmp -Force | Out-Null
                $in  = Join-Path $tmp "in";  $out = Join-Path $tmp "out"; $err = Join-Path $tmp "err"
                [IO.File]::WriteAllText($in,
                    '{"hook_event_name":"PostToolUse","tool_name":"Read","session_id":"teste-ascii"}',
                    (New-Object Text.UTF8Encoding($false)))
                $antes = [Environment]::GetEnvironmentVariable('PERCUS_HOOKS_DISABLED')
                [Environment]::SetEnvironmentVariable('PERCUS_HOOKS_DISABLED', '1')
                try {
                    $p = Start-Process -FilePath $env:ComSpec -ArgumentList @('/c', "`"$Caminho`"") `
                        -RedirectStandardInput $in -RedirectStandardError $err `
                        -RedirectStandardOutput $out -NoNewWindow -Wait -PassThru
                    [pscustomobject]@{
                        ExitCode = $p.ExitCode
                        Stderr   = [IO.File]::ReadAllText($err)
                    }
                } finally {
                    [Environment]::SetEnvironmentVariable('PERCUS_HOOKS_DISABLED', $antes)
                    try { [IO.Directory]::Delete($tmp, $true) } catch { }
                }
            }
        }

        It "percus-dispatch-post.cmd sai 0 e sem ruido no stderr" {
            $r = Invoke-CmdDireto -Caminho (Join-Path $script:hooksDir "percus-dispatch-post.cmd")
            $r.Stderr.Trim() | Should -BeNullOrEmpty -Because "lote desalinhado vomita 'nao e reconhecido' linha a linha"
            $r.ExitCode | Should -Be 0
        }

        It "percus-dispatch-pre.cmd sai 0 e sem ruido no stderr" {
            $r = Invoke-CmdDireto -Caminho (Join-Path $script:hooksDir "percus-dispatch-pre.cmd")
            $r.Stderr.Trim() | Should -BeNullOrEmpty
            $r.ExitCode | Should -Be 0
        }
    }
}
