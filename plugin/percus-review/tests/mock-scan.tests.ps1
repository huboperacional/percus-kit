#requires -Version 5.1
# Regressao do hook mock-scan (R3).
# Foco principal: falso-positivo em palavras acentuadas que contem "todo" como
# substring (ex: portugues "metodo" -> "me'todo'") — causado por (a) decode OEM
# do output do git mojibakando o "e" acentuado em 2 bytes nao-word, criando uma
# word-boundary falsa, e (b) match case-insensitive de TODO/FIXME/XXX/HACK.

Describe "mock-scan hook — falso-positivo em palavras acentuadas + markers reais" {
    BeforeAll {
        $script:hook = Join-Path $PSScriptRoot ".." "hooks" "mock-scan-pre-commit.ps1"

        function New-StagedRepo {
            param([string]$FileName, [string]$Content)
            $repo = Join-Path ([IO.Path]::GetTempPath()) "mockscan-test-$(Get-Random)"
            New-Item -ItemType Directory -Force -Path $repo | Out-Null
            & git -C $repo init -q
            & git -C $repo config user.email "t@t.t"
            & git -C $repo config user.name "t"
            # Escreve em UTF-8 (sem BOM) — replica como arquivos reais sao salvos
            $path = Join-Path $repo $FileName
            [System.IO.File]::WriteAllText($path, $Content, (New-Object System.Text.UTF8Encoding($false)))
            & git -C $repo add $FileName
            return $repo
        }

        function Invoke-MockScan {
            param([string]$Repo)
            $cmd = "cd `"$Repo`" && git commit -m teste"
            $stdin = @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            $stdin | & pwsh -NoProfile -File $script:hook *>$null
            return $LASTEXITCODE
        }
    }

    Context "Regressao — palavra acentuada com 'todo' embutido NAO bloqueia" {
        It "1. aria-label PT com 'Metodo' acentuado nao dispara TODO (incidente Frente B v6.8)" {
            $repo = New-StagedRepo -FileName "method-toggle.tsx" -Content @'
export function MethodToggle() {
  return <div role="radiogroup" aria-label="Método de login" />;
}
'@
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0 -Because "'Método' (PT) contem 'todo' mas NAO e um TODO marker"
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }

        It "2. identificador camelCase 'metodoTodo' nao dispara" {
            $repo = New-StagedRepo -FileName "x.ts" -Content 'const metodoTodoListado = 1;'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }

        It "3. 'hackathon' (contem 'hack' minusculo) nao dispara" {
            $repo = New-StagedRepo -FileName "x.ts" -Content 'const hackathonScore = 10;'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }
    }

    Context "TODO saiu do gate (decisao de 2026-08-17)" {
        # Assercao INVERTIDA de proposito, em vez de teste apagado: assim a
        # decisao vira executavel e uma reversao silenciosa quebra o CI em vez de
        # passar despercebida.
        It "4. comentario '// TODO: ...' NAO bloqueia mais" {
            $repo = New-StagedRepo -FileName "x.ts" -Content 'const a = 1; // TODO: corrigir isso'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0 -Because "a R3 escrita trata de dado falso mentindo pro usuario (banner MODO DEMO, toast 'salvo localmente'); ela nao pede marcador nenhum. A checagem era o hook mais estrito que a propria regra, e colidiu 3x com portugues. TODO esquecido fica coberto pelo R11, que le o diff inteiro."
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }

        It "4b. portugues com TODO em caixa alta nao bloqueia (incidente 2026-08-17)" {
            $repo = New-StagedRepo -FileName "x.ts" -Content @'
// Ligar isso faria cada imagem e TODO chunk de JS queimar uma invocacao.
export const x = 1;
'@
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0 -Because "'TODO' aqui e a palavra portuguesa 'todo', nao um marcador; barrou commit legitimo 2x numa sessao"
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }

        It "4c. 'hardcoded' dentro de palavra maior nao bloqueia (fronteira, indicacao do conselho)" {
            $repo = New-StagedRepo -FileName "x.ts" -Content 'const nonHardcodedValue = 1;'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0 -Because "sem \b, 'hardcoded' casava dentro de qualquer identificador ou palavra"
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Markers reais continuam sendo bloqueados" {

        It "5. comentario 'FIXME ' real bloqueia" {
            $repo = New-StagedRepo -FileName "x.py" -Content '# FIXME esta logica esta errada'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 2
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Arquivo limpo nao bloqueia" {
        It "6. codigo sem markers nem mocks passa" {
            $repo = New-StagedRepo -FileName "x.ts" -Content 'export const soma = (a: number, b: number) => a + b;'
            try {
                Invoke-MockScan -Repo $repo | Should -Be 0
            } finally {
                Remove-Item -Recurse -Force $repo -ErrorAction SilentlyContinue
            }
        }
    }
}

# T10 (2026-09-15): escape MOCK-OK: em QUALQUER -m e nas primeiras 64 KB do arquivo de -F.
# Tabela UNICA executada contra as tres pernas (.ps1 sob pwsh, .ps1 sob powershell.exe, .sh
# sob Git Bash): paridade e requisito de seguranca -- uma perna que libera onde a outra
# bloqueia e defeito. Todo repo tem `FIXME ` staged, entao "sem escape" = exit 2.
BeforeDiscovery {
    # Fase 3 T7 (2026-09-15): corte de tempo recomendado pela revisao (loteF-T10-fix-review.md,
    # Rodada 2, item 5). Medido: sem LC_ALL, o bash do hook ja roda em locale C (host desta
    # maquina nao define LANG/LC_*), entao a perna "sh-gitbash-LC_ALL=C" cheia duplicava a
    # "sh-gitbash" padrao nos 31 casos. Ela SAI como perna inteira; sobra so 1 caso de controle
    # explicito sob LC_ALL=C mais abaixo (o corte UTF-8 do -F, onde o Importante 1 apareceu).
    # A perna "sh-gitbash-LC_ALL=C.UTF-8" fica, mas roda so os casos com LocaleSensivel = $true
    # (nao-ASCII, corte de 64 KB do comando/-F, BOM) -- os unicos onde locale muda o resultado.
    # Toda perna .ps1 e a sh-gitbash padrao continuam rodando os 31 casos inteiros.
    # R11 (risco 2): a "sh-gitbash" padrao roda sob QUALQUER locale que o host tiver (C aqui,
    # mas C.UTF-8 ou outro num CI que defina LANG) -- e ela roda a tabela INTEIRA, entao um host
    # com locale UTF-8 por padrao ja teria os casos LocaleSensivel exercitados sob UTF-8 nessa
    # perna. O locale C fica coberto pelo caso de controle explicito, independente do host.
    # Ou seja: host-nativo (qualquer locale) + C explicito + C.UTF-8 explicito = os 3 estados
    # continuam cobertos, so nao mais como 5 pernas completas.
    $script:camadas = @(
        @{ Camada = 'ps1-pwsh' },
        @{ Camada = 'ps1-powershell.exe' },
        @{ Camada = 'sh-gitbash' },
        @{ Camada = 'sh-gitbash-LC_ALL=C.UTF-8'; Locale = 'C.UTF-8' }
    )
    $okMsg = "fix: x`n`nMOCK-OK: motivo`n"
    $script:casos = @(
        @{ Nome = "-m '..' -m 'MOCK-OK: ..' (2o -m, aspas simples)"; ArgsCommit = "-m 'fix: x' -m 'MOCK-OK: falso positivo'"; Esperado = 0 },
        @{ Nome = '-m ".." -m "MOCK-OK: .." (2o -m, aspas duplas)'; ArgsCommit = '-m "a" -m "MOCK-OK: b"'; Esperado = 0 },
        @{ Nome = '-F msg.txt com MOCK-OK na linha 3'; ArgsCommit = '-F msg.txt'; Arquivos = @{ 'msg.txt' = $okMsg }; Esperado = 0 },
        @{ Nome = '-F naoexiste.txt bloqueia'; ArgsCommit = '-F naoexiste.txt'; Esperado = 2 },
        @{ Nome = '-F - (stdin) bloqueia'; ArgsCommit = '-F -'; Esperado = 2 },
        @{ Nome = '-F "a b.txt" (aspas e espaco)'; ArgsCommit = '-F "a b.txt"'; Arquivos = @{ 'a b.txt' = $okMsg }; Esperado = 0 },
        @{ Nome = '--file=msg.txt'; ArgsCommit = '--file=msg.txt'; Arquivos = @{ 'msg.txt' = $okMsg }; Esperado = 0 },
        @{ Nome = '--file msg.txt'; ArgsCommit = '--file msg.txt'; Arquivos = @{ 'msg.txt' = $okMsg }; Esperado = 0 },
        @{ Nome = '-F msg.txt sem MOCK-OK bloqueia'; ArgsCommit = '-F msg.txt'; Arquivos = @{ 'msg.txt' = "fix: x`n`ncorpo`n" }; Esperado = 2 },
        @{ Nome = '-F com MOCK-OK depois de 64 KB bloqueia'; ArgsCommit = '-F grande.txt'; Grande = $true; Esperado = 2 },
        @{ Nome = '-F apontando diretorio bloqueia'; ArgsCommit = '-F pasta'; Pasta = $true; Esperado = 2 },
        @{ Nome = '-F ilegivel (travado sem compartilhamento) bloqueia'; ArgsCommit = '-F travado.txt'; Arquivos = @{ 'travado.txt' = $okMsg }; Travar = 'travado.txt'; Esperado = 2 },
        @{ Nome = "-m 'mock-ok: ..' minusculo passa nas duas"; ArgsCommit = "-m 'mock-ok: minusculo'"; Esperado = 0 },
        @{ Nome = "-m 'XMOCK-OK: ..' sem fronteira bloqueia nas duas"; ArgsCommit = "-m 'XMOCK-OK: colado'"; Esperado = 2 },
        @{ Nome = '-F "x"-F msg.txt (sem espaco antes do 2o -F) bloqueia nas duas'; ArgsCommit = '-F "x"-F msg.txt'; Arquivos = @{ 'msg.txt' = $okMsg }; Esperado = 2 },
        @{ Nome = 'sem escape bloqueia';ArgsCommit = "-m 'fix: sem escape'"; Esperado = 2 },
        # Revisao da T10 (Importante 1): a busca olha so os primeiros 64 KB do comando e no
        # maximo 64 ocorrencias por regex. Cada limite tem o caso que bloqueia e o controle
        # logo abaixo dele que passa -- senao o vermelho poderia vir de outra coisa.
        @{ Nome = 'MOCK-OK so depois dos 64 KB do comando bloqueia'; ArgsCommit = "-m '" + ('a' * 66000) + "' -m 'MOCK-OK: tarde demais'"; Esperado = 2; LocaleSensivel = $true },
        @{ Nome = 'controle: comando de 60 KB com MOCK-OK no fim passa'; ArgsCommit = "-m '" + ('a' * 60000) + "' -m 'MOCK-OK: dentro'"; Esperado = 0; LocaleSensivel = $true },
        @{ Nome = '65a ocorrencia de -m com MOCK-OK bloqueia (limite 64)'; ArgsCommit = ("-m 'a' " * 64) + "-m 'MOCK-OK: 65a'"; Esperado = 2 },
        @{ Nome = 'controle: 64a ocorrencia de -m com MOCK-OK passa'; ArgsCommit = ("-m 'a' " * 63) + "-m 'MOCK-OK: 64a'"; Esperado = 0 },
        @{ Nome = '65o -F com MOCK-OK bloqueia (limite 64)'; ArgsCommit = ('-F nao.txt ' * 64) + '-F msg.txt'; Arquivos = @{ 'msg.txt' = $okMsg }; Esperado = 2 },
        @{ Nome = 'controle: 64o -F com MOCK-OK passa'; ArgsCommit = ('-F nao.txt ' * 63) + '-F msg.txt'; Arquivos = @{ 'msg.txt' = $okMsg }; Esperado = 0 },
        # `-F msg.txt` cortado pela janela vira `-F msg`; o arquivo `msg` existe com MOCK-OK.
        @{ Nome = '-F partido no corte dos 64 KB nao le o prefixo do caminho'; CorteF = $true; Arquivos = @{ 'msg' = $okMsg }; Esperado = 2; LocaleSensivel = $true },
        # Menor 2: nao-ASCII colado antes do MOCK-OK conta como letra nas duas pernas.
        @{ Nome = '-F com acento colado (eMOCK-OK:) bloqueia nas duas'; ArgsCommit = '-F msg.txt'; Arquivos = @{ 'msg.txt' = "fix: x`n`n" + [char]0x00E9 + "MOCK-OK: colado`n" }; Esperado = 2; LocaleSensivel = $true },
        @{ Nome = '-F com travessao colado bloqueia nas duas'; ArgsCommit = '-F msg.txt'; Arquivos = @{ 'msg.txt' = "fix: x`n`n" + [char]0x2014 + "MOCK-OK: colado`n" }; Esperado = 2; LocaleSensivel = $true },
        @{ Nome = "-m com acento colado (eMOCK-OK:) bloqueia nas duas"; ArgsCommit = "-m '" + [char]0x00E9 + "MOCK-OK: colado'"; Esperado = 2; LocaleSensivel = $true },
        # Re-revisao (Importante 1). O arquivo `msg` (prefixo do caminho) existe com MOCK-OK;
        # `msgé.txt` nao existe. (a) corte dos 64 KB no MEIO do `é` (python em UTF-8: C3 dentro,
        # A9 fora); (b) sem corte, python em cp1252 (o `é` vira o byte E9 sozinho).
        @{ Nome = '-F msg(e-acento).txt com corte de 64 KB no meio do acento bloqueia'; CorteAcento = $true; Arquivos = @{ 'msg' = $okMsg }; EnvCaso = @{ PYTHONUTF8 = '1' }; Esperado = 2; LocaleSensivel = $true },
        @{ Nome = '-F msg(e-acento).txt curto com python em cp1252 bloqueia'; ArgsCommit = '-F msg' + [char]0x00E9 + '.txt'; Arquivos = @{ 'msg' = $okMsg }; EnvCaso = @{ PYTHONUTF8 = $null }; Esperado = 2; LocaleSensivel = $true },
        @{ Nome = 'controle: -F msg(e-acento).txt existente com MOCK-OK passa'; ArgsCommit = '-F msg' + [char]0x00E9 + '.txt'; Arquivos = @{ ('msg' + [char]0x00E9 + '.txt') = $okMsg }; Esperado = 0; LocaleSensivel = $true },
        # Menor BOM:`Out-File -Encoding UTF8` do PS 5.1 grava BOM; ele nao pode esconder o MOCK-OK da 1a linha.
        @{ Nome = '-F com BOM UTF-8 e MOCK-OK na 1a linha passa'; ArgsCommit = '-F bom.txt'; ArquivosBom = @{ 'bom.txt' = "MOCK-OK: gravado com BOM`n`nfix: x`n" }; Esperado = 0; LocaleSensivel = $true }
    )
}

Describe "mock-scan T10 -- MOCK-OK em qualquer -m e no arquivo de -F (<Camada>)" -ForEach $script:camadas {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $hooks = Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks'
        $script:hookPs1 = Join-Path $hooks 'mock-scan-pre-commit.ps1'
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ('mockscan-t10-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        # O .sh do checkout chega com CRLF (autocrlf); a copia sem CR simula a instalacao.
        $shDir = Join-Path $script:tmpBase 'hooks-sh'
        New-Item -ItemType Directory -Force -Path $shDir | Out-Null
        Copy-SemCR (Join-Path $hooks 'mock-scan-pre-commit.sh') (Join-Path $shDir 'mock-scan-pre-commit.sh')
        Copy-SemCR (Join-Path $hooks '_helpers.sh') (Join-Path $shDir '_helpers.sh')
        $script:hookSh = ConvertTo-CaminhoBash (Join-Path $shDir 'mock-scan-pre-commit.sh')
        $script:bash = Get-BashGit

        function New-RepoT10 {
            param([hashtable]$Caso)
            $repo = Join-Path $script:tmpBase ('r-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Force -Path $repo | Out-Null
            & git -C $repo init -q 2>$null
            [IO.File]::WriteAllText((Join-Path $repo 'x.py'), "# FIXME logica errada`n", $script:u8)
            & git -C $repo add x.py 2>$null
            if ($Caso.Arquivos) {
                foreach ($k in $Caso.Arquivos.Keys) { [IO.File]::WriteAllText((Join-Path $repo $k), $Caso.Arquivos[$k], $script:u8) }
            }
            if ($Caso.ArquivosBom) {
                $u8bom = New-Object System.Text.UTF8Encoding($true)
                foreach ($k in $Caso.ArquivosBom.Keys) { [IO.File]::WriteAllText((Join-Path $repo $k), $Caso.ArquivosBom[$k], $u8bom) }
            }
            if ($Caso.Grande) {
                [IO.File]::WriteAllText((Join-Path $repo 'grande.txt'), ('a' * 65536) + "`nMOCK-OK: tarde demais`n", $script:u8)
            }
            if ($Caso.Pasta) { New-Item -ItemType Directory -Force -Path (Join-Path $repo 'pasta') | Out-Null }
            return $repo
        }

        function Get-PrefixoT10 {
            param([string]$Repo)
            return 'cd "' + (ConvertTo-CaminhoBash $Repo) + '" && git ' + ('com' + 'mit') + ' '
        }

        function Invoke-HookT10 {
            param([string]$Camada, [string]$Repo, [string]$ArgsCommit, [string]$Locale, [hashtable]$EnvCaso)
            # Mesmo stdin nas tres pernas. Raiz vem do `cd` do comando; o processo do hook
            # NAO roda dentro do repo, entao caminho relativo so acerta pelo resolvedor.
            $cmd = (Get-PrefixoT10 $Repo) + $ArgsCommit
            $stdin = @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            # Nao-ASCII vai como \uXXXX: o stdin do processo filho nao depende do $OutputEncoding do host.
            $stdin = [regex]::Replace($stdin, '[^\x00-\x7F]', [Text.RegularExpressions.MatchEvaluator] { param($c) '\u{0:x4}' -f [int][char]$c.Value })
            $err = Join-Path $script:tmpBase ('err-' + [Guid]::NewGuid().ToString('N') + '.txt')
            $envs = @{ PERCUS_HOOKS_DISABLED = $null; PERCUS_SKIP_MOCK_SCAN = $null; LC_ALL = $null; PYTHONUTF8 = $null; PYTHONIOENCODING = $null }
            if ($Locale) { $envs['LC_ALL'] = $Locale }
            if ($EnvCaso) { foreach ($k in $EnvCaso.Keys) { $envs[$k] = $EnvCaso[$k] } }
            $antigos = Set-EnvTemporario $envs
            try {
                if ($Camada -like 'sh-gitbash*') {
                    # timeout 30 do Git Bash (revisao T10, Importante 2): regressao de laco no
                    # .sh vira VERMELHO com exit 124 em vez de travar o Pester.
                    $stdin | & $script:bash -c 'timeout 30 bash "$1"' _ $script:hookSh 2>$err | Out-Null
                } elseif ($Camada -eq 'ps1-powershell.exe') {
                    $stdin | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:hookPs1 2>$err | Out-Null
                } else {
                    $stdin | & pwsh -NoProfile -File $script:hookPs1 2>$err | Out-Null
                }
                $code = $LASTEXITCODE
            } finally { Restore-EnvTemporario $antigos }
            $texto = ''
            if (Test-Path -LiteralPath $err) { $texto = [IO.File]::ReadAllText($err) }
            if ($Camada -like 'sh-gitbash*' -and $code -eq 124) { $texto = 'HOOK TRAVOU: o .sh passou dos 30 s (timeout, exit 124). ' + $texto }
            return [pscustomobject]@{ Code = $code; Err = $texto }
        }
    }

    AfterAll {
        if ($script:tmpBase -and [IO.Directory]::Exists($script:tmpBase)) {
            try { [IO.Directory]::Delete($script:tmpBase, $true) } catch { }
        }
    }

    It "tem o runtime da perna" {
        if ($Camada -like 'sh-gitbash*') { $script:bash | Should -Not -BeNullOrEmpty -Because 'Git Bash e a perna .sh; sem ele a paridade nao foi medida' }
    }

    # Fase 3 T7: a perna C.UTF-8 so roda os casos marcados LocaleSensivel (locale e o unico
    # motivo dela existir); as demais pernas (ps1-pwsh, ps1-powershell.exe, sh-gitbash padrao)
    # rodam a tabela inteira -- contrato "todo caso roda em pelo menos pwsh + sh padrao".
    It "<Nome> -> exit <Esperado>" -ForEach $(
        if ($Camada -eq 'sh-gitbash-LC_ALL=C.UTF-8') { $script:casos | Where-Object { $_.LocaleSensivel } }
        else { $script:casos }
    ) {
        $repo = New-RepoT10 -Caso $_
        $trava = $null
        try {
            if ($Travar) {
                $trava = [IO.File]::Open((Join-Path $repo $Travar), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            }
            $argsC = $ArgsCommit
            if ($CorteF) {
                # Janela de 65536 termina logo depois de `-F msg`; o comando inteiro diz `-F msg.txt`.
                $cabeca = (Get-PrefixoT10 $repo) + "-m '"
                $cauda = "' -F msg"
                $argsC = "-m '" + ('a' * (65536 - $cabeca.Length - $cauda.Length)) + "' -F msg.txt"
                ((Get-PrefixoT10 $repo) + $argsC).Substring(0, 65536).EndsWith(' -F msg') | Should -BeTrue -Because 'o corte tem de cair logo depois de -F msg'
            }
            if ($CorteAcento) {
                # `-F msg` termina no byte 65535; o 1o byte do `é` (C3 em UTF-8) e o 65536o.
                $cabeca = (Get-PrefixoT10 $repo) + "-m '"
                $cauda = "' -F msg"
                $argsC = "-m '" + ('a' * (65535 - $cabeca.Length - $cauda.Length)) + "' -F msg" + [char]0x00E9 + '.txt'
                $bytes = [Text.Encoding]::UTF8.GetBytes((Get-PrefixoT10 $repo) + $argsC)
                ($bytes[65534] -eq 0x67 -and $bytes[65535] -eq 0xC3 -and $bytes[65536] -eq 0xA9) | Should -BeTrue -Because 'o corte de 64 KB tem de cair no meio do e-acento'
            }
            $r = Invoke-HookT10 -Camada $Camada -Repo $repo -ArgsCommit $argsC -Locale $Locale -EnvCaso $EnvCaso
        } finally {
            if ($trava) { $trava.Dispose() }
        }
        $r.Code | Should -Not -Be 124 -Because "HOOK TRAVOU na perna ${Camada}: $($r.Err)"
        $r.Code | Should -Be $Esperado -Because "perna $Camada, stderr: $($r.Err)"
        if ($Esperado -eq 2) {
            $r.Err | Should -Match 'mock/placeholder' -Because 'sem escape o bloqueio e o do scan, com a mensagem atual'
        }
    }
}

# Fase 3 T7: controle explicito sob LC_ALL=C, recomendacao da revisao (loteF-T10-fix-review.md,
# Rodada 2, item 5-a). A perna "sh-gitbash-LC_ALL=C" saiu como camada inteira porque duplicava a
# "sh-gitbash" padrao nos 31 casos (o host desta maquina ja roda o bash do hook em locale C sem
# LC_ALL definido). Este caso unico prova que o locale C explicito continua dando o resultado
# certo no caso onde o Importante 1 apareceu (corte de 64 KB no meio do "e" acentuado do -F).
Describe "mock-scan T10 -- controle explicito LC_ALL=C (corte UTF-8 do -F)" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $hooks = Join-Path (Split-Path $PSScriptRoot -Parent) 'hooks'
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ('mockscan-t10c-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
        $shDir = Join-Path $script:tmpBase 'hooks-sh'
        New-Item -ItemType Directory -Force -Path $shDir | Out-Null
        Copy-SemCR (Join-Path $hooks 'mock-scan-pre-commit.sh') (Join-Path $shDir 'mock-scan-pre-commit.sh')
        Copy-SemCR (Join-Path $hooks '_helpers.sh') (Join-Path $shDir '_helpers.sh')
        $script:hookSh = ConvertTo-CaminhoBash (Join-Path $shDir 'mock-scan-pre-commit.sh')
        $script:bash = Get-BashGit
    }

    AfterAll {
        if ($script:tmpBase -and [IO.Directory]::Exists($script:tmpBase)) {
            try { [IO.Directory]::Delete($script:tmpBase, $true) } catch { }
        }
    }

    It "tem o runtime da perna" {
        $script:bash | Should -Not -BeNullOrEmpty -Because 'Git Bash e a perna .sh; sem ele o controle nao foi medido'
    }

    It "-F msg(e-acento).txt com corte de 64 KB no meio do acento bloqueia sob LC_ALL=C" {
        if (-not $script:bash) { Set-ItResult -Skipped -Because 'Git Bash ausente; sem ele o controle nao roda'; return }
        # Mesmo caso da tabela principal (CorteAcento), reproduzido aqui porque variavel de
        # BeforeDiscovery nao sobrevive a fase de Run do Pester -- os dados vem inline.
        # R11: PYTHONUTF8=1 replicado do caso original -- e o que forca o python3 do Git Bash a
        # imprimir o "e" acentuado em UTF-8 (C3 A9); sem isso o python3 pode usar cp1252 (E9
        # sozinho) e o controle deixaria de exercitar o cenario de corte que ele diz reproduzir.
        $repo = Join-Path $script:tmpBase ('r-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $repo | Out-Null
        & git -C $repo init -q 2>$null
        [IO.File]::WriteAllText((Join-Path $repo 'x.py'), "# FIXME logica errada`n", $script:u8)
        & git -C $repo add x.py 2>$null
        [IO.File]::WriteAllText((Join-Path $repo 'msg'), ("fix: x`n`nMOCK-OK: motivo`n"), $script:u8)

        # Revisao R11: o padding e calculado em BYTES (nao em .Length de caracteres), porque o
        # caminho do repo temporario (Guid + prefixo do host) pode conter caractere nao-ASCII
        # em algumas maquinas -- .Length em char desalinharia o corte de 64 KB em BYTES.
        $prefixo = ('cd "' + (ConvertTo-CaminhoBash $repo) + '" && git ' + ('com' + 'mit') + ' ')
        $cabecaBytes = [Text.Encoding]::UTF8.GetByteCount($prefixo + "-m '")
        $caudaBytes = [Text.Encoding]::UTF8.GetByteCount("' -F msg")
        $argsC = "-m '" + ('a' * (65535 - $cabecaBytes - $caudaBytes)) + "' -F msg" + [char]0x00E9 + '.txt'
        $cmd = $prefixo + $argsC
        $bytes = [Text.Encoding]::UTF8.GetBytes($cmd)
        ($bytes[65534] -eq 0x67 -and $bytes[65535] -eq 0xC3 -and $bytes[65536] -eq 0xA9) | Should -BeTrue -Because 'o corte de 64 KB tem de cair no meio do e-acento'

        $stdin = @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
        $stdin = [regex]::Replace($stdin, '[^\x00-\x7F]', [Text.RegularExpressions.MatchEvaluator] { param($c) '\u{0:x4}' -f [int][char]$c.Value })
        $err = Join-Path $script:tmpBase ('err-' + [Guid]::NewGuid().ToString('N') + '.txt')
        $antigoLc = $env:LC_ALL
        $antigoPy = $env:PYTHONUTF8
        $env:LC_ALL = 'C'
        $env:PYTHONUTF8 = '1'
        try {
            $stdin | & $script:bash -c 'timeout 30 bash "$1"' _ $script:hookSh 2>$err | Out-Null
            $code = $LASTEXITCODE
        } finally { $env:LC_ALL = $antigoLc; $env:PYTHONUTF8 = $antigoPy }
        $texto = ''
        if (Test-Path -LiteralPath $err) { $texto = [IO.File]::ReadAllText($err) }
        $code | Should -Not -Be 124 -Because "HOOK TRAVOU no controle LC_ALL=C: $texto"
        $code | Should -Be 2 -Because "controle LC_ALL=C, stderr: $texto"
        $texto | Should -Match 'mock/placeholder' -Because 'sem escape o bloqueio e o do scan, com a mensagem atual'
    }
}
