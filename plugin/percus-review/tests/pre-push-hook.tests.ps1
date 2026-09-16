#requires -Version 5.1
# Fase 5 (2026-09-16) -- R20 camada 2: hook git nativo pre-push exige autorizacao em TODO push.
# A camada 1 (external-action-guard) casa o comando por TEXTO; a revisao de seguranca achou 20+
# grafias de push que passam por ela. Aqui cada grafia roda de verdade contra um remoto LOCAL
# (git init --bare) e o criterio e o que importa: o remoto nao muda e nenhuma auditoria nasce.
# Nenhum remoto de rede em lugar nenhum deste arquivo.

BeforeDiscovery {
    # Cwd: 'trab' = dentro do clone; 'base' = fora dele (forma precisa achar o repo pelo -C).
    # {TRAB} = caminho do clone (com espaco), {TRABESC} = com espaco escapado, {REMOTO} = bare.
    $script:formas = @(
        @{ Forma = 'git push origin main'; Cwd = 'trab' }
        @{ Forma = 'git "push" origin main'; Cwd = 'trab' }
        @{ Forma = "git 'push' origin main"; Cwd = 'trab' }
        @{ Forma = 'git pu"sh" origin main'; Cwd = 'trab' }
        @{ Forma = 'git p\ush origin main'; Cwd = 'trab' }
        @{ Forma = 'git${IFS}push origin main'; Cwd = 'trab' }
        @{ Forma = 'x=push; git $x origin main'; Cwd = 'trab' }
        @{ Forma = "git \`n push origin main"; Cwd = 'trab' }
        @{ Forma = 'git -c alias.x=push x origin main'; Cwd = 'trab' }
        @{ Forma = 'git config alias.pp push && git pp origin main'; Cwd = 'trab' }
        @{ Forma = 'git 2>/dev/null push origin main'; Cwd = 'trab'; SemMsg = $true }
        @{ Forma = 'git -c user.name="a b" push origin main'; Cwd = 'trab' }
        @{ Forma = 'git --attr-source HEAD push origin main'; Cwd = 'trab' }
        @{ Forma = 'env git push origin main'; Cwd = 'trab' }
        @{ Forma = 'command git push origin main'; Cwd = 'trab' }
        @{ Forma = 'git -C "{TRAB}" push origin main'; Cwd = 'base' }
        @{ Forma = 'git -C {TRABESC} push origin main'; Cwd = 'base' }
        @{ Forma = 'git -C "{TRAB}"/. push origin main'; Cwd = 'base' }
        @{ Forma = 'git -C "{TRAB}" >/dev/null push origin main'; Cwd = 'base' }
        @{ Forma = 'bash -c "git push origin main"'; Cwd = 'trab' }
        @{ Forma = 'bash -c "git -C \"{TRAB}\" push origin main"'; Cwd = 'base' }
        @{ Forma = 'sh -c ''git "push" origin main'''; Cwd = 'trab' }
        @{ Forma = 'git push --force origin main'; Cwd = 'trab' }
        @{ Forma = 'git push origin HEAD:refs/heads/outra'; Cwd = 'trab' }
        @{ Forma = 'git push --all origin'; Cwd = 'trab' }
        @{ Forma = 'git push --tags origin'; Cwd = 'trab' }
        @{ Forma = 'git push --mirror origin'; Cwd = 'trab' }
        @{ Forma = 'git push "{REMOTO}" main'; Cwd = 'trab' }
        @{ Forma = 'git -c remote.origin.pushurl="{REMOTO}" push origin main'; Cwd = 'trab' }
        @{ Forma = 'PERCUS_EXTERNAL_OVERRIDE=1 PERCUS_HOOKS_DISABLED=1 git push origin main'; Cwd = 'trab' }
    )
    $script:invalidas = @(
        @{ Caso = 'expirada (3601 s)';          Json = '{"id":"a","motivo":"m","autorizado_em":"x","timestamp_unix":{AGORA-3601}}' }
        @{ Caso = 'limite exato (3600 s)';      Json = '{"id":"a","motivo":"m","autorizado_em":"x","timestamp_unix":{AGORA-3600}}' }
        @{ Caso = 'no futuro (300 s)';          Json = '{"id":"a","motivo":"m","autorizado_em":"x","timestamp_unix":{AGORA+300}}' }
        @{ Caso = 'JSON corrompido';            Json = '{"id":"a","motivo":"m","timestamp_unix":{AGORA-10}' }
        @{ Caso = 'arquivo vazio';              Json = '' }
        @{ Caso = 'timestamp string';           Json = '{"id":"a","motivo":"m","timestamp_unix":"{AGORA-10}"}' }
        @{ Caso = 'timestamp fracionario';      Json = '{"id":"a","motivo":"m","timestamp_unix":{AGORA-10}.5}' }
        @{ Caso = 'timestamp negativo';         Json = '{"id":"a","motivo":"m","timestamp_unix":-5}' }
        @{ Caso = 'sem timestamp';              Json = '{"id":"a","motivo":"m"}' }
        @{ Caso = 'sem id';                     Json = '{"motivo":"m","timestamp_unix":{AGORA-10}}' }
        @{ Caso = 'motivo vazio';               Json = '{"id":"a","motivo":"  ","timestamp_unix":{AGORA-10}}' }
        @{ Caso = 'chave duplicada';            Json = '{"id":"a","motivo":"m","timestamp_unix":1,"timestamp_unix":{AGORA-10}}' }
        @{ Caso = 'raiz array';                 Json = '[{"id":"a","motivo":"m","timestamp_unix":{AGORA-10}}]' }
        @{ Caso = 'lixo depois do objeto';      Json = '{"id":"a","motivo":"m","timestamp_unix":{AGORA-10}} x' }
        @{ Caso = 'caminho e diretorio';        Json = '<DIR>' }
    )
}

Describe "pre-push nativo -- R20 camada 2" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        $plugin = Split-Path $PSScriptRoot -Parent
        $kit = Split-Path (Split-Path $plugin -Parent) -Parent
        $script:template  = Join-Path (Join-Path $plugin 'git-hooks') 'pre-push.template.sh'
        $script:instalador = Join-Path (Join-Path $plugin 'git-hooks') 'instalar-pre-push.sh'
        $script:autorizar = Join-Path (Join-Path $kit 'scripts') 'autorizar-acao-externa.ps1'
        $script:bash = Get-BashGit
        $script:ps51 = (Get-Command 'powershell.exe' -ErrorAction SilentlyContinue).Source
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:u8bom = New-Object System.Text.UTF8Encoding($true)
        $script:cm = 'com' + 'mit'
        # Espaco no caminho de proposito: e a forma que quebra parser de texto.
        $script:raiz = Join-Path ([IO.Path]::GetTempPath()) ("percus pp " + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $script:raiz | Out-Null

        function Invoke-G {
            param([string]$Dir, [string[]]$GitArgs)
            $saida = & git -C $Dir @GitArgs 2>&1 | Out-String
            return @{ Exit = $LASTEXITCODE; Saida = $saida }
        }

        function Invoke-Sh {
            # Script em arquivo (LF, sem BOM) em vez de `bash -c`: nenhuma camada de quoting do
            # PowerShell entre o texto da forma e o bash.
            param([string]$Dir, [string]$Corpo, [string[]]$ShArgs = @(), [string]$Stdin = $null)
            $arq = Join-Path $script:raiz ("s-" + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.sh')
            $texto = 'cd "' + (ConvertTo-CaminhoBash $Dir) + '" || exit 99' + "`n" + $Corpo.Replace("`r", '') + "`n"
            [IO.File]::WriteAllText($arq, $texto, $script:u8)
            if ($null -ne $Stdin) {
                $saida = $Stdin | & $script:bash $arq @ShArgs 2>&1 | Out-String
            } else {
                $saida = & $script:bash $arq @ShArgs 2>&1 | Out-String
            }
            return @{ Exit = $LASTEXITCODE; Saida = $saida }
        }

        function Get-RefsRemoto {
            param([string]$Remoto)
            return (& git -C $Remoto for-each-ref '--format=%(refname) %(objectname)' 2>$null | Out-String)
        }

        function Add-Commit {
            param([string]$Trab)
            [IO.File]::WriteAllText((Join-Path $Trab ([Guid]::NewGuid().ToString('N') + '.txt')), 'x', $script:u8)
            $null = Invoke-G $Trab @('add', '-A')
            $null = Invoke-G $Trab @($script:cm, '-q', '-m', 'c')
            return ((& git -C $Trab rev-parse HEAD) | Out-String).Trim()
        }

        function New-Cenario {
            param([string]$Nome, [switch]$SemHook)
            $dir = Join-Path $script:raiz $Nome
            $remoto = Join-Path $dir 'remoto.git'
            $trab = Join-Path $dir 'trab'
            New-Item -ItemType Directory -Force -Path $trab | Out-Null
            $null = & git init -q --bare -b main $remoto 2>&1
            $null = & git init -q -b main $trab 2>&1
            foreach ($kv in @(@('user.name', 'pp'), @('user.email', 'pp@exemplo.invalid'), @('commit.gpgsign', 'false'),
                              @('core.autocrlf', 'false'), @('core.hooksPath', (ConvertTo-CaminhoBash (Join-Path (Join-Path $trab '.git') 'hooks'))))) {
                $null = Invoke-G $trab @('config', '--local', $kv[0], $kv[1])
            }
            $null = Invoke-G $trab @('remote', 'add', 'origin', (ConvertTo-CaminhoBash $remoto))
            $null = Add-Commit $trab
            $null = Invoke-G $trab @('push', '-q', 'origin', 'main')
            $null = Invoke-G $trab @('tag', 'v-pp')
            if (-not $SemHook) {
                $r = Invoke-Sh $trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')
                if ($r.Exit -ne 0) { throw "instalador falhou: $($r.Saida)" }
            }
            return @{ Dir = $dir; Remoto = $remoto; Trab = $trab }
        }

        function Set-Auth {
            param([string]$Trab, [string]$Json)
            $pd = Join-Path $Trab '.percus'
            New-Item -ItemType Directory -Force -Path $pd | Out-Null
            $alvo = Join-Path $pd 'acao-externa-autorizada.json'
            if ($Json -eq '<DIR>') { New-Item -ItemType Directory -Force -Path $alvo | Out-Null; return }
            $agora = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $t = $Json
            foreach ($m in [regex]::Matches($Json, '\{AGORA([+-])(\d+)\}')) {
                $v = $agora - [long]$m.Groups[2].Value
                if ($m.Groups[1].Value -eq '+') { $v = $agora + [long]$m.Groups[2].Value }
                $t = $t.Replace($m.Value, [string]$v)
            }
            [IO.File]::WriteAllText($alvo, $t, $script:u8bom)
        }

        function Clear-Percus {
            param([string]$Trab)
            $pd = Join-Path $Trab '.percus'
            if (Test-Path -LiteralPath $pd) { Remove-Item -LiteralPath $pd -Recurse -Force }
        }

        function Get-LinhasAuditoria {
            param([string]$Trab)
            $log = Join-Path (Join-Path $Trab '.percus') 'autorizacoes-usadas.jsonl'
            if (-not (Test-Path -LiteralPath $log -PathType Leaf)) { return ,@() }
            $a = @([IO.File]::ReadAllText($log, $script:u8) -split "`r`n" | Where-Object { $_ -ne '' })
            return ,$a
        }

        function Expand-Forma {
            param([string]$Forma, [hashtable]$C)
            $tb = ConvertTo-CaminhoBash $C.Trab
            return $Forma.Replace('{TRABESC}', $tb.Replace(' ', '\ ')).Replace('{TRAB}', $tb).Replace('{REMOTO}', (ConvertTo-CaminhoBash $C.Remoto))
        }
    }

    AfterAll {
        if ($script:raiz -and (Test-Path -LiteralPath $script:raiz)) {
            Remove-Item -LiteralPath $script:raiz -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "sem autorizacao: toda grafia de push bloqueia (o remoto nao muda)" {
        BeforeAll {
            $script:cSem = New-Cenario 'sem-auth'
            $null = Add-Commit $script:cSem.Trab
            $null = Invoke-G $script:cSem.Trab @('tag', 'v-pp-2')
        }

        It "<Forma>" -ForEach $script:formas {
            $antes = Get-RefsRemoto $script:cSem.Remoto
            $dir = $script:cSem.Trab
            if ($Cwd -eq 'base') { $dir = $script:cSem.Dir }
            $r = Invoke-Sh $dir (Expand-Forma $Forma $script:cSem)
            $r.Exit | Should -Not -Be 0 -Because $r.Saida
            # stderr redirecionado pela propria forma: a mensagem some, o bloqueio nao.
            if (-not $SemMsg) { $r.Saida | Should -Match 'pre-push native\] BLOCK \(R20\)' }
            Get-RefsRemoto $script:cSem.Remoto | Should -Be $antes
            (Get-LinhasAuditoria $script:cSem.Trab).Count | Should -Be 0
        }

        It "PowerShell direto (& git -C ... push)" {
            $antes = Get-RefsRemoto $script:cSem.Remoto
            $r = Invoke-G $script:cSem.Trab @('push', 'origin', 'main')
            $r.Exit | Should -Not -Be 0
            $r.Saida | Should -Match 'BLOCK \(R20\)'
            Get-RefsRemoto $script:cSem.Remoto | Should -Be $antes
        }

        It "powershell.exe 5.1 -Command git push" {
            if (-not $script:ps51) { Set-ItResult -Skipped -Because 'sem powershell.exe'; return }
            $antes = Get-RefsRemoto $script:cSem.Remoto
            $cmd = "git -C '" + $script:cSem.Trab + "' push origin main; exit `$LASTEXITCODE"
            $saida = & $script:ps51 -NoProfile -Command $cmd 2>&1 | Out-String
            $LASTEXITCODE | Should -Not -Be 0 -Because $saida
            Get-RefsRemoto $script:cSem.Remoto | Should -Be $antes
        }
    }

    Context "autorizacao invalida bloqueia" {
        BeforeAll {
            $script:cInv = New-Cenario 'invalida'
            $null = Add-Commit $script:cInv.Trab
        }
        BeforeEach { Clear-Percus $script:cInv.Trab }

        It "<Caso>" -ForEach $script:invalidas {
            Set-Auth $script:cInv.Trab $Json
            $antes = Get-RefsRemoto $script:cInv.Remoto
            $r = Invoke-G $script:cInv.Trab @('push', 'origin', 'main')
            $r.Exit | Should -Not -Be 0 -Because $r.Saida
            $r.Saida | Should -Match 'BLOCK \(R20\)'
            Get-RefsRemoto $script:cInv.Remoto | Should -Be $antes
            (Get-LinhasAuditoria $script:cInv.Trab).Count | Should -Be 0
        }
    }

    Context "autorizacao valida libera e audita" {
        BeforeAll { $script:cOk = New-Cenario 'valida' }
        BeforeEach { Clear-Percus $script:cOk.Trab }

        It "autorizacao criada por autorizar-acao-externa.ps1 sob powershell.exe 5.1 libera e grava 1 linha com remoto e refs" {
            if (-not $script:ps51) { Set-ItResult -Skipped -Because 'sem powershell.exe'; return }
            $velho = ((& git -C $script:cOk.Remoto rev-parse refs/heads/main) | Out-String).Trim()
            $novo = Add-Commit $script:cOk.Trab
            $saidaAuth = & $script:ps51 -NoProfile -ExecutionPolicy Bypass -File $script:autorizar -Motivo 'teste pre-push' -ProjetoRoot $script:cOk.Trab 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0 -Because $saidaAuth
            $auth = [IO.File]::ReadAllText((Join-Path (Join-Path $script:cOk.Trab '.percus') 'acao-externa-autorizada.json'), $script:u8) | ConvertFrom-Json

            $r = Invoke-G $script:cOk.Trab @('push', 'origin', 'main')
            $r.Exit | Should -Be 0 -Because $r.Saida
            ((& git -C $script:cOk.Remoto rev-parse refs/heads/main) | Out-String).Trim() | Should -Be $novo

            $linhas = Get-LinhasAuditoria $script:cOk.Trab
            $linhas.Count | Should -Be 1
            $l = $linhas[0] | ConvertFrom-Json
            $l.origem | Should -Be 'pre-push'
            $l.id | Should -Be $auth.id
            $l.motivo | Should -Be 'teste pre-push'
            $l.remoto | Should -Be 'origin'
            $l.url | Should -Be (ConvertTo-CaminhoBash $script:cOk.Remoto)
            @($l.refs).Count | Should -Be 1
            $l.refs[0].local_ref | Should -Be 'refs/heads/main'
            $l.refs[0].local_sha | Should -Be $novo
            $l.refs[0].remote_ref | Should -Be 'refs/heads/main'
            $l.refs[0].remote_sha | Should -Be $velho
            $bytes = [IO.File]::ReadAllBytes((Join-Path (Join-Path $script:cOk.Trab '.percus') 'autorizacoes-usadas.jsonl'))
            $bytes[$bytes.Length - 2] | Should -Be 13
            $bytes[$bytes.Length - 1] | Should -Be 10
        }

        It "grafia ofuscada com autorizacao tambem passa pelo hook e audita (independe do texto)" {
            Set-Auth $script:cOk.Trab '{"id":"ofusc","motivo":"m","timestamp_unix":{AGORA-5}}'
            $novo = Add-Commit $script:cOk.Trab
            $r = Invoke-Sh $script:cOk.Trab 'git -c alias.x=push x origin main'
            $r.Exit | Should -Be 0 -Because $r.Saida
            ((& git -C $script:cOk.Remoto rev-parse refs/heads/main) | Out-String).Trim() | Should -Be $novo
            $linhas = Get-LinhasAuditoria $script:cOk.Trab
            $linhas.Count | Should -Be 1
            ($linhas[0] | ConvertFrom-Json).id | Should -Be 'ofusc'
        }

        It "motivo acentuado (UTF-8 com BOM) sai intacto na auditoria; dois pushes = duas linhas" {
            $mot = 'autoriza' + [char]0x00E7 + [char]0x00E3 + 'o "citada" \ barra'
            $json = '{"id":"acento","motivo":' + (ConvertTo-Json $mot -Compress) + ',"timestamp_unix":{AGORA-5}}'
            Set-Auth $script:cOk.Trab $json
            $null = Add-Commit $script:cOk.Trab
            (Invoke-G $script:cOk.Trab @('push', 'origin', 'main')).Exit | Should -Be 0
            $null = Add-Commit $script:cOk.Trab
            (Invoke-G $script:cOk.Trab @('push', 'origin', 'main')).Exit | Should -Be 0
            $linhas = Get-LinhasAuditoria $script:cOk.Trab
            $linhas.Count | Should -Be 2
            ($linhas[0] | ConvertFrom-Json).motivo | Should -Be $mot
        }

        It "credencial na URL do remoto sai mascarada na auditoria" {
            Set-Auth $script:cOk.Trab '{"id":"url","motivo":"m","timestamp_unix":{AGORA-5}}'
            $hook = ConvertTo-CaminhoBash (Join-Path (Join-Path (Join-Path $script:cOk.Trab '.git') 'hooks') 'pre-push')
            $stdin = "refs/heads/main 1111111111111111111111111111111111111111 refs/heads/main 0000000000000000000000000000000000000000`n"
            $r = Invoke-Sh $script:cOk.Trab ('sh "' + $hook + '" "$@"') @('origin', 'https://ghp_SEGREDO123@github.com/o/r.git') $stdin
            $r.Exit | Should -Be 0 -Because $r.Saida
            $linhas = Get-LinhasAuditoria $script:cOk.Trab
            $linhas.Count | Should -Be 1
            $linhas[0] | Should -Not -Match 'SEGREDO'
            ($linhas[0] | ConvertFrom-Json).url | Should -Be 'https://***@github.com/o/r.git'
        }

        It "falha ao gravar a auditoria bloqueia o push (auditoria e parte do contrato)" {
            Set-Auth $script:cOk.Trab '{"id":"semlog","motivo":"m","timestamp_unix":{AGORA-5}}'
            New-Item -ItemType Directory -Force -Path (Join-Path (Join-Path $script:cOk.Trab '.percus') 'autorizacoes-usadas.jsonl') | Out-Null
            $null = Add-Commit $script:cOk.Trab
            $antes = Get-RefsRemoto $script:cOk.Remoto
            $r = Invoke-G $script:cOk.Trab @('push', 'origin', 'main')
            $r.Exit | Should -Not -Be 0
            $r.Saida | Should -Match 'nao consegui gravar a auditoria'
            Get-RefsRemoto $script:cOk.Remoto | Should -Be $antes
        }
    }

    Context "instalador (core.hooksPath, .bak, hibrido, re-run)" {
        It "NOVO instala o template sem CR; re-run nao muda nada nem cria .bak" {
            $c = New-Cenario 'inst-novo'
            $alvo = Join-Path (Join-Path (Join-Path $c.Trab '.git') 'hooks') 'pre-push'
            $esperado = [IO.File]::ReadAllText($script:template).Replace("`r", '')
            [IO.File]::ReadAllText($alvo) | Should -Be $esperado
            $r = Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')
            $r.Exit | Should -Be 0
            $r.Saida | Should -Match 'ja atualizado'
            Test-Path -LiteralPath ($alvo + '.bak') | Should -BeFalse
        }

        It "HIBRIDO preserva o custom (roda depois, ve stdin e args); .bak = original; sem autorizacao o custom nem roda" {
            $c = New-Cenario 'inst-hibrido' -SemHook
            $alvo = Join-Path (Join-Path (Join-Path $c.Trab '.git') 'hooks') 'pre-push'
            # `$NAO_DEFINIDA` sem default: o custom nao pode herdar o `set -u` do bloco Percus.
            $custom = "#!/bin/sh`nwhile read a b c d; do echo `"CUSTOM-VIU `$c`" >&2; done`necho `"CUSTOM-ARGS `$1`$NAO_DEFINIDA`" >&2`nexit 0`n"
            [IO.File]::WriteAllText($alvo, $custom, $script:u8)
            $r = Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')
            $r.Exit | Should -Be 0 -Because $r.Saida
            $r.Saida | Should -Match 'modo HIBRIDO'
            [IO.File]::ReadAllText($alvo + '.bak') | Should -Be $custom
            $novo = [IO.File]::ReadAllText($alvo)
            $novo | Should -Match '^#!/bin/sh\n# === PERCUS-MERGED-HOOK BEGIN ==='
            $novo.EndsWith("END ===`n" + $custom.Substring("#!/bin/sh`n".Length)) | Should -BeTrue

            $null = Add-Commit $c.Trab
            $antes = Get-RefsRemoto $c.Remoto
            $s = Invoke-G $c.Trab @('push', 'origin', 'main')
            $s.Exit | Should -Not -Be 0
            $s.Saida | Should -Not -Match 'CUSTOM-'
            Get-RefsRemoto $c.Remoto | Should -Be $antes

            Set-Auth $c.Trab '{"id":"h","motivo":"m","timestamp_unix":{AGORA-5}}'
            $s = Invoke-G $c.Trab @('push', 'origin', 'main')
            $s.Exit | Should -Be 0 -Because $s.Saida
            $s.Saida | Should -Match 'CUSTOM-VIU refs/heads/main'
            $s.Saida | Should -Match 'CUSTOM-ARGS origin'
        }

        It "custom que bloqueia continua bloqueando mesmo com autorizacao valida" {
            $c = New-Cenario 'inst-custom-bloqueia' -SemHook
            $alvo = Join-Path (Join-Path (Join-Path $c.Trab '.git') 'hooks') 'pre-push'
            [IO.File]::WriteAllText($alvo, "#!/bin/sh`necho CUSTOM-NAO >&2`nexit 1`n", $script:u8)
            (Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')).Exit | Should -Be 0
            Set-Auth $c.Trab '{"id":"h","motivo":"m","timestamp_unix":{AGORA-5}}'
            $null = Add-Commit $c.Trab
            $s = Invoke-G $c.Trab @('push', 'origin', 'main')
            $s.Exit | Should -Not -Be 0
            $s.Saida | Should -Match 'CUSTOM-NAO'
        }

        It "HIBRIDO com custom salvo em CRLF: o corpo preservado sai sem CR e o custom roda" {
            $c = New-Cenario 'inst-hibrido-crlf' -SemHook
            $alvo = Join-Path (Join-Path (Join-Path $c.Trab '.git') 'hooks') 'pre-push'
            $custom = "#!/bin/sh`r`nif true; then`r`n  echo CUSTOM-CRLF-OK >&2`r`nfi`r`nexit 0`r`n"
            [IO.File]::WriteAllText($alvo, $custom, $script:u8)
            (Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')).Exit | Should -Be 0
            [IO.File]::ReadAllText($alvo).Contains("`r") | Should -BeFalse
            [IO.File]::ReadAllText($alvo + '.bak') | Should -Be $custom
            Set-Auth $c.Trab '{"id":"h","motivo":"m","timestamp_unix":{AGORA-5}}'
            $null = Add-Commit $c.Trab
            $s = Invoke-G $c.Trab @('push', 'origin', 'main')
            $s.Exit | Should -Be 0 -Because $s.Saida
            $s.Saida | Should -Match 'CUSTOM-CRLF-OK'
        }

        It "GERIDO troca so o bloco Percus, preserva sufixo custom e guarda .bak do anterior" {
            $c = New-Cenario 'inst-gerido' -SemHook
            $alvo = Join-Path (Join-Path (Join-Path $c.Trab '.git') 'hooks') 'pre-push'
            $velho = "#!/bin/sh`n# === PERCUS-MERGED-HOOK BEGIN ===`necho BLOCO-VELHO`n# === PERCUS-MERGED-HOOK END ===`necho SUFIXO-CUSTOM >&2`nexit 0`n"
            [IO.File]::WriteAllText($alvo, $velho, $script:u8)
            $r = Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')
            $r.Exit | Should -Be 0 -Because $r.Saida
            $r.Saida | Should -Match 'modo GERIDO'
            [IO.File]::ReadAllText($alvo + '.bak') | Should -Be $velho
            $novo = [IO.File]::ReadAllText($alvo)
            $novo | Should -Not -Match 'BLOCO-VELHO'
            $novo | Should -Match 'percus-review pre-push hook'
            $novo.EndsWith("END ===`necho SUFIXO-CUSTOM >&2`nexit 0`n") | Should -BeTrue
            # segundo backup nao sobrescreve o primeiro
            [IO.File]::WriteAllText($alvo, $velho, $script:u8)
            $null = Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')
            [IO.File]::ReadAllText($alvo + '.bak') | Should -Be $velho
            @(Get-ChildItem -LiteralPath (Split-Path $alvo) | Where-Object { $_.Name -match '^pre-push\.bak\.\d+$' }).Count | Should -Be 1
        }

        It "RECUSA hook custom em outra linguagem (exit 3, nada muda, sem .bak)" {
            $c = New-Cenario 'inst-python' -SemHook
            $alvo = Join-Path (Join-Path (Join-Path $c.Trab '.git') 'hooks') 'pre-push'
            $py = "#!/usr/bin/env python3`nimport sys`nsys.exit(0)`n"
            [IO.File]::WriteAllText($alvo, $py, $script:u8)
            $r = Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')
            $r.Exit | Should -Be 3
            [IO.File]::ReadAllText($alvo) | Should -Be $py
            Test-Path -LiteralPath ($alvo + '.bak') | Should -BeFalse
        }

        It "respeita core.hooksPath relativo (.githooks) e o push passa a bloquear" {
            $c = New-Cenario 'inst-hookspath' -SemHook
            $null = Invoke-G $c.Trab @('config', '--local', 'core.hooksPath', '.githooks')
            $r = Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')
            $r.Exit | Should -Be 0 -Because $r.Saida
            Test-Path -LiteralPath (Join-Path (Join-Path $c.Trab '.githooks') 'pre-push') | Should -BeTrue
            $null = Add-Commit $c.Trab
            $s = Invoke-G $c.Trab @('push', 'origin', 'main')
            $s.Exit | Should -Not -Be 0
            $s.Saida | Should -Match 'BLOCK \(R20\)'
        }

        It "template com CRLF (cache do plugin) instala sem CR" {
            $c = New-Cenario 'inst-crlf' -SemHook
            $pasta = Join-Path $c.Dir 'plugin-crlf'
            New-Item -ItemType Directory -Force -Path $pasta | Out-Null
            foreach ($f in @($script:template, $script:instalador)) {
                $t = [IO.File]::ReadAllText($f).Replace("`r", '').Replace("`n", "`r`n")
                if ($f -eq $script:instalador) { $t = $t.Replace("`r", '') }
                [IO.File]::WriteAllText((Join-Path $pasta (Split-Path $f -Leaf)), $t, $script:u8)
            }
            $r = Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash (Join-Path $pasta 'instalar-pre-push.sh')) + '" .')
            $r.Exit | Should -Be 0 -Because $r.Saida
            [IO.File]::ReadAllText((Join-Path (Join-Path (Join-Path $c.Trab '.git') 'hooks') 'pre-push')).Contains("`r") | Should -BeFalse
        }
    }

    Context "rodada 2 C1 -- raiz da autorizacao vem do repo publicado, nao da work tree" {
        BeforeAll {
            $script:cRaiz = New-Cenario 'c1-raiz'
            # 'outro' repo com autorizacao valida propria; 'forja' = pasta qualquer com JSON forjado.
            $script:c1Outro = Join-Path $script:cRaiz.Dir 'outro'
            $null = & git init -q -b main $script:c1Outro 2>&1
            $script:c1Forja = Join-Path $script:cRaiz.Dir 'forja'
            New-Item -ItemType Directory -Force -Path $script:c1Forja | Out-Null
        }
        BeforeEach {
            Clear-Percus $script:cRaiz.Trab
            Set-Auth $script:c1Outro '{"id":"do-outro","motivo":"m","timestamp_unix":{AGORA-5}}'
            $pd = Join-Path $script:c1Forja '.percus'; New-Item -ItemType Directory -Force -Path $pd | Out-Null
            [IO.File]::WriteAllText((Join-Path $pd 'acao-externa-autorizada.json'),
                ('{"id":"forjada","motivo":"m","timestamp_unix":' + ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 5) + '}'), $script:u8bom)
        }

        It "<Rot> bloqueia (repo publicado sem .percus proprio)" -ForEach @(
            @{ Rot = 'GIT_WORK_TREE=<outro>';  Cmd = 'GIT_WORK_TREE="{OUTRO}" git -C "{TRAB}" push origin main' }
            @{ Rot = '--work-tree=<forja>';    Cmd = 'git -C "{TRAB}" --work-tree="{FORJA}" push origin main' }
            @{ Rot = '-c core.worktree';       Cmd = 'git -C "{TRAB}" -c core.worktree="{FORJA}" push origin main' }
            @{ Rot = '--git-dir de cwd=forja'; Cmd = 'cd "{FORJA}" && git --git-dir="{TRAB}/.git" push origin main' }
            @{ Rot = 'GIT_DIR+GIT_WORK_TREE';  Cmd = 'cd "{FORJA}" && GIT_DIR="{TRAB}/.git" GIT_WORK_TREE="{FORJA}" git push origin main' }
        ) {
            $tb = ConvertTo-CaminhoBash $script:cRaiz.Trab
            $corpo = $Cmd.Replace('{TRAB}', $tb).Replace('{OUTRO}', (ConvertTo-CaminhoBash $script:c1Outro)).Replace('{FORJA}', (ConvertTo-CaminhoBash $script:c1Forja))
            $antes = Get-RefsRemoto $script:cRaiz.Remoto
            $null = Add-Commit $script:cRaiz.Trab
            $r = Invoke-Sh $script:cRaiz.Dir $corpo
            $r.Exit | Should -Not -Be 0 -Because $r.Saida
            Get-RefsRemoto $script:cRaiz.Remoto | Should -Be $antes
            (Get-LinhasAuditoria $script:cRaiz.Trab).Count | Should -Be 0
            (Get-LinhasAuditoria $script:c1Outro).Count | Should -Be 0
        }

        It "GIT_DIR apontando forja com hook e .percus valido nao publica (raiz vem do cwd)" {
            # Repo sintetico completo: hook instalado, .percus valido, origin -> o remoto-alvo.
            $forja = Join-Path $script:cRaiz.Dir 'forja'
            $null = & git init -q -b main $forja 2>&1
            $null = Invoke-G $forja @('config', 'user.name', 'x'); $null = Invoke-G $forja @('config', 'user.email', 'x@x')
            $null = Invoke-G $forja @('remote', 'add', 'origin', (ConvertTo-CaminhoBash $script:cRaiz.Remoto))
            Copy-SemCR -Origem $script:template -Destino (Join-Path (Join-Path (Join-Path $forja '.git') 'hooks') 'pre-push')
            Set-Auth $forja '{"id":"forja","motivo":"m","timestamp_unix":{AGORA-5}}'
            [IO.File]::WriteAllText((Join-Path $forja 'f'), 'z', $script:u8); $null = Invoke-G $forja @('add', '-A'); $null = Invoke-G $forja @($script:cm, '-q', '-m', 'f')
            # cwd = o repo REAL (sem .percus); GIT_DIR aponta a forja.
            $antes = Get-RefsRemoto $script:cRaiz.Remoto
            $corpo = "GIT_DIR=`"" + (ConvertTo-CaminhoBash (Join-Path $forja '.git')) + "`" git push `"" + (ConvertTo-CaminhoBash $script:cRaiz.Remoto) + "`" main:main --force"
            $r = Invoke-Sh $script:cRaiz.Trab $corpo
            $r.Exit | Should -Not -Be 0 -Because $r.Saida
            $r.Saida | Should -Match 'BLOCK \(R20\)'
            Get-RefsRemoto $script:cRaiz.Remoto | Should -Be $antes
            (Get-LinhasAuditoria $forja).Count | Should -Be 0
        }
    }

    Context "rodada 2 C1 -- worktree resolve a autorizacao no checkout principal" {
        BeforeAll {
            $script:cWt = New-Cenario 'c1-wt'
            $script:cWtDir = Join-Path $script:cWt.Dir 'wt'
            $null = Invoke-G $script:cWt.Trab @('worktree', 'add', '-q', '-b', 'wtb', (ConvertTo-CaminhoBash $script:cWtDir))
            [IO.File]::AppendAllText((Join-Path (Join-Path (Join-Path $script:cWt.Trab '.git') 'info') 'exclude'), ".percus/`n", $script:u8)
        }
        BeforeEach { Clear-Percus $script:cWt.Trab; Clear-Percus $script:cWtDir }

        It "auth no principal libera o push do worktree e audita NO principal" {
            Set-Auth $script:cWt.Trab '{"id":"principal","motivo":"m","timestamp_unix":{AGORA-5}}'
            $novo = Add-Commit $script:cWtDir
            $r = Invoke-G $script:cWtDir @('push', 'origin', 'wtb')
            $r.Exit | Should -Be 0 -Because $r.Saida
            (Get-LinhasAuditoria $script:cWt.Trab).Count | Should -Be 1
            (Get-LinhasAuditoria $script:cWtDir).Count | Should -Be 0
            ($script:cWt.Trab | ForEach-Object { (Get-LinhasAuditoria $_)[0] } | ConvertFrom-Json).id | Should -Be 'principal'
        }

        It "auth so no worktree NAO libera (o principal manda) e a mensagem aponta o .percus do principal" {
            Set-Auth $script:cWtDir '{"id":"so-wt","motivo":"m","timestamp_unix":{AGORA-5}}'
            $antes = Get-RefsRemoto $script:cWt.Remoto
            $null = Add-Commit $script:cWtDir
            $r = Invoke-G $script:cWtDir @('push', 'origin', 'wtb')
            $r.Exit | Should -Not -Be 0 -Because $r.Saida
            Get-RefsRemoto $script:cWt.Remoto | Should -Be $antes
            # A mensagem imprime o caminho concreto consultado -- o do checkout PRINCIPAL, nao o worktree.
            $principalPercus = (ConvertTo-CaminhoBash (Join-Path (Join-Path $script:cWt.Trab '.percus') 'acao-externa-autorizada.json'))
            $r.Saida | Should -Match ([regex]::Escape($principalPercus))
        }
    }

    Context "rodada 2 C2 -- funcoes exportadas nao sequestram o hook" {
        BeforeAll { $script:cFn = New-Cenario 'c2-func' }
        BeforeEach { Clear-Percus $script:cFn.Trab }

        It "BASH_FUNC_date%% devolve epoch proximo do arquivo expirado -- bloqueia" {
            # date falso = fileTS+10 (parece fresco pro `_pp_idade`); sem a blindagem, passava.
            $expira = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 86400
            Set-Auth $script:cFn.Trab ('{"id":"expirada","motivo":"m","timestamp_unix":' + $expira + '}')
            $fake = $expira + 10
            $tb = ConvertTo-CaminhoBash $script:cFn.Trab
            $antes = Get-RefsRemoto $script:cFn.Remoto
            $null = Add-Commit $script:cFn.Trab
            $corpo = "env 'BASH_FUNC_date%%=() { echo " + $fake + "; }' git -C `"$tb`" push origin main"
            $r = Invoke-Sh $script:cFn.Trab $corpo
            $r.Exit | Should -Not -Be 0 -Because $r.Saida
            Get-RefsRemoto $script:cFn.Remoto | Should -Be $antes
            (Get-LinhasAuditoria $script:cFn.Trab).Count | Should -Be 0
        }

        It "BASH_FUNC_awk%% forja saida 'ok' com ts fresco (via command date) -- bloqueia" {
            # awk falso emite ok+ts calculado NO RUNTIME (command date +%s - 5), com auth expirada.
            $expira = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 86400
            Set-Auth $script:cFn.Trab ('{"id":"expirada","motivo":"m","timestamp_unix":' + $expira + '}')
            $tb = ConvertTo-CaminhoBash $script:cFn.Trab
            $antes = Get-RefsRemoto $script:cFn.Remoto
            $null = Add-Commit $script:cFn.Trab
            $corpo = "env 'BASH_FUNC_awk%%=() { printf `"ok\n%s\nfun\nm\n`" `$(( `$(command date +%s) - 5 )); }' git -C `"$tb`" push origin main"
            $r = Invoke-Sh $script:cFn.Trab $corpo
            $r.Exit | Should -Not -Be 0 -Because $r.Saida
            Get-RefsRemoto $script:cFn.Remoto | Should -Be $antes
            (Get-LinhasAuditoria $script:cFn.Trab).Count | Should -Be 0
        }

        It "BASH_FUNC_awk%% com arquivo de autorizacao VAZIO -- bloqueia" {
            $pd = Join-Path $script:cFn.Trab '.percus'; New-Item -ItemType Directory -Force -Path $pd | Out-Null
            [IO.File]::WriteAllText((Join-Path $pd 'acao-externa-autorizada.json'), '', $script:u8)
            $tb = ConvertTo-CaminhoBash $script:cFn.Trab
            $antes = Get-RefsRemoto $script:cFn.Remoto
            $null = Add-Commit $script:cFn.Trab
            $corpo = "env 'BASH_FUNC_awk%%=() { printf `"ok\n%s\nfun\nm\n`" `$(( `$(command date +%s) - 5 )); }' git -C `"$tb`" push origin main"
            $r = Invoke-Sh $script:cFn.Trab $corpo
            $r.Exit | Should -Not -Be 0 -Because $r.Saida
            Get-RefsRemoto $script:cFn.Remoto | Should -Be $antes
        }
    }

    Context "rodada 2 -- a blindagem unset -f cobre os externos usados (template e instalador)" {
        It "<Rot>: todo externo chamado esta no unset -f" -ForEach @(
            @{ Rot = 'template';   Arq = 'template';   AteEnd = $true }
            @{ Rot = 'instalador'; Arq = 'instalador'; AteEnd = $false }
        ) {
            $caminho = if ($Arq -eq 'template') { $script:template } else { $script:instalador }
            $texto = [IO.File]::ReadAllText($caminho).Replace("`r", '')
            $linhas = $texto -split "`n"
            $iUnset = ($linhas | Select-String -Pattern '^\s*unset -f ' | Select-Object -First 1).LineNumber
            $iUnset | Should -Not -BeNullOrEmpty -Because 'o script precisa blindar o ambiente com unset -f'
            $acc = ''
            for ($i = $iUnset - 1; $i -lt $linhas.Count; $i++) {
                $acc += ' ' + $linhas[$i]
                if ($linhas[$i] -match '2>/dev/null') { break }
            }
            $acc = $acc -replace 'unset -f', '' -replace '2>/dev/null.*', ''
            $cobertos = @($acc -split '\s+' | ForEach-Object { $_.Trim("'", '\', '"') } | Where-Object { $_ -ne '' })
            $catalogo = @('awk','sed','grep','tr','cat','wc','head','cut','sort','printf','echo','date',
                'git','mkdir','mv','rm','cp','read','test','[','command','sleep','ls','stat','dirname',
                'basename','chmod','cmp','mktemp','tee','sha1sum','sha256sum','find','xargs','touch')
            # Corpo executavel: do unset ate o END (template) ou ate o fim (instalador), sem comentarios.
            $fim = $linhas.Count
            if ($AteEnd) { $fim = ($linhas | Select-String -Pattern 'PERCUS-MERGED-HOOK END' | Select-Object -First 1).LineNumber }
            $corpo = @()
            for ($i = $iUnset; $i -lt $fim; $i++) {
                if ($linhas[$i] -match '^\s*#') { continue }
                $corpo += $linhas[$i]
            }
            $corpoTxt = ($corpo -join "`n")
            $faltando = @()
            foreach ($cmd in $catalogo) {
                $pat = if ($cmd -eq '[') { '(^|[\s;&|(`$])\[\s' } else { '(^|[\s;&|(`$])' + [regex]::Escape($cmd) + '(\s|$|;)' }
                if ($corpoTxt -match $pat -and $cobertos -notcontains $cmd) { $faltando += $cmd }
            }
            $faltando -join ', ' | Should -Be '' -Because 'externo usado mas fora do unset -f pode ser sequestrado por BASH_FUNC'
        }
    }

    Context "rodada 2 I2 -- instalador nao aceita hook GERIDO neutralizado" {
        It "custom com 'exit 0' ANTES do BEGIN vira HIBRIDO (bloco Percus na frente) e bloqueia" {
            $c = New-Cenario 'i2-antes' -SemHook
            $alvo = Join-Path (Join-Path (Join-Path $c.Trab '.git') 'hooks') 'pre-push'
            $mau = "#!/bin/sh`nexit 0`n# === PERCUS-MERGED-HOOK BEGIN ===`necho X`n# === PERCUS-MERGED-HOOK END ===`n"
            [IO.File]::WriteAllText($alvo, $mau, $script:u8)
            $r = Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')
            $r.Exit | Should -Be 0 -Because $r.Saida
            $r.Saida | Should -Match 'modo HIBRIDO'
            # linha 2 = BEGIN: o bloco Percus ficou na frente do 'exit 0' custom.
            [IO.File]::ReadAllText($alvo) | Should -Match '^#!/bin/sh\n# === PERCUS-MERGED-HOOK BEGIN ==='
            $antes = Get-RefsRemoto $c.Remoto
            $null = Add-Commit $c.Trab
            $s = Invoke-G $c.Trab @('push', 'origin', 'main')
            $s.Exit | Should -Not -Be 0 -Because $s.Saida
            $s.Saida | Should -Match 'BLOCK \(R20\)'
            Get-RefsRemoto $c.Remoto | Should -Be $antes
        }

        It "custom 'exit 0' + marcadores dentro de comentario NAO vira GERIDO e bloqueia" {
            $c = New-Cenario 'i2-comentario' -SemHook
            $alvo = Join-Path (Join-Path (Join-Path $c.Trab '.git') 'hooks') 'pre-push'
            $mau = "#!/bin/sh`nexit 0`n# === PERCUS-MERGED-HOOK BEGIN ===`n# === PERCUS-MERGED-HOOK END ===`n"
            [IO.File]::WriteAllText($alvo, $mau, $script:u8)
            $r = Invoke-Sh $c.Trab ('sh "' + (ConvertTo-CaminhoBash $script:instalador) + '" .')
            $r.Exit | Should -Be 0 -Because $r.Saida
            $r.Saida | Should -Match 'modo HIBRIDO'
            $antes = Get-RefsRemoto $c.Remoto
            $null = Add-Commit $c.Trab
            $s = Invoke-G $c.Trab @('push', 'origin', 'main')
            $s.Exit | Should -Not -Be 0 -Because $s.Saida
            $s.Saida | Should -Match 'BLOCK \(R20\)'
            Get-RefsRemoto $c.Remoto | Should -Be $antes
        }
    }

    Context "limites declarados: formas que o pre-push NAO ve (camada 1 tem de barrar)" {
        BeforeAll { $script:cLim = New-Cenario 'limites' }

        It "<Forma> atualiza o remoto sem autorizacao" -ForEach @(
            @{ Forma = 'git push --no-verify origin main' }
            @{ Forma = 'git -c core.hooksPath=/nao/existe push origin main' }
            @{ Forma = 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/nao/existe git push origin main' }
            @{ Forma = 'git send-pack "{REMOTO}" main' }
        ) {
            $novo = Add-Commit $script:cLim.Trab
            $r = Invoke-Sh $script:cLim.Trab (Expand-Forma $Forma $script:cLim)
            $r.Exit | Should -Be 0 -Because $r.Saida
            ((& git -C $script:cLim.Remoto rev-parse refs/heads/main) | Out-String).Trim() | Should -Be $novo
        }
    }
}
