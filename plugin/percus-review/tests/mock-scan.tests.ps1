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
    $script:camadas = @(
        @{ Camada = 'ps1-pwsh' },
        @{ Camada = 'ps1-powershell.exe' },
        @{ Camada = 'sh-gitbash' }
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
        @{ Nome = 'sem escape bloqueia';ArgsCommit = "-m 'fix: sem escape'"; Esperado = 2 }
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
            if ($Caso.Grande) {
                [IO.File]::WriteAllText((Join-Path $repo 'grande.txt'), ('a' * 65536) + "`nMOCK-OK: tarde demais`n", $script:u8)
            }
            if ($Caso.Pasta) { New-Item -ItemType Directory -Force -Path (Join-Path $repo 'pasta') | Out-Null }
            return $repo
        }

        function Invoke-HookT10 {
            param([string]$Camada, [string]$Repo, [string]$ArgsCommit)
            # Mesmo stdin nas tres pernas. Raiz vem do `cd` do comando; o processo do hook
            # NAO roda dentro do repo, entao caminho relativo so acerta pelo resolvedor.
            $cmd = 'cd "' + (ConvertTo-CaminhoBash $Repo) + '" && git ' + ('com' + 'mit') + ' ' + $ArgsCommit
            $stdin = @{ tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
            $err = Join-Path $script:tmpBase ('err-' + [Guid]::NewGuid().ToString('N') + '.txt')
            $antigos = Set-EnvTemporario @{ PERCUS_HOOKS_DISABLED = $null; PERCUS_SKIP_MOCK_SCAN = $null }
            try {
                switch ($Camada) {
                    'ps1-pwsh'           { $stdin | & pwsh -NoProfile -File $script:hookPs1 2>$err | Out-Null }
                    'ps1-powershell.exe' { $stdin | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:hookPs1 2>$err | Out-Null }
                    'sh-gitbash'         { $stdin | & $script:bash $script:hookSh 2>$err | Out-Null }
                }
                $code = $LASTEXITCODE
            } finally { Restore-EnvTemporario $antigos }
            $texto = ''
            if (Test-Path -LiteralPath $err) { $texto = [IO.File]::ReadAllText($err) }
            return [pscustomobject]@{ Code = $code; Err = $texto }
        }
    }

    AfterAll {
        if ($script:tmpBase -and [IO.Directory]::Exists($script:tmpBase)) {
            try { [IO.Directory]::Delete($script:tmpBase, $true) } catch { }
        }
    }

    It "tem o runtime da perna" {
        if ($Camada -eq 'sh-gitbash') { $script:bash | Should -Not -BeNullOrEmpty -Because 'Git Bash e a perna .sh; sem ele a paridade nao foi medida' }
    }

    It "<Nome> -> exit <Esperado>" -ForEach $script:casos {
        $repo = New-RepoT10 -Caso $_
        $trava = $null
        try {
            if ($Travar) {
                $trava = [IO.File]::Open((Join-Path $repo $Travar), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            }
            $r = Invoke-HookT10 -Camada $Camada -Repo $repo -ArgsCommit $ArgsCommit
        } finally {
            if ($trava) { $trava.Dispose() }
        }
        $r.Code | Should -Be $Esperado -Because "perna $Camada, stderr: $($r.Err)"
        if ($Esperado -eq 2) {
            $r.Err | Should -Match 'mock/placeholder' -Because 'sem escape o bloqueio e o do scan, com a mensagem atual'
        }
    }
}
