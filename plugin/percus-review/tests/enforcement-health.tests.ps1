#requires -Version 5.1
# Prova o health check nas DUAS direcoes.
#
# So a direcao negativa ("quebrei e ele gritou") nao distingue "detectou" de "nunca rodou" -- e
# esse foi o risco n.1 que o pre-mortem levantou sobre este plano: um detector de silencio que
# nunca foi ouvido fazendo barulho e indistinguivel de silencio. Por isso todo It aqui afere
# tambem que a ASSINATURA saiu, e nao so o veredito.

Describe "enforcement-health -- diz se o enforcement esta ligado e de onde vem o codigo" {

    BeforeAll {
        $script:hooksDir = Join-Path $PSScriptRoot ".." "hooks"
        $script:ps1  = Join-Path $script:hooksDir "enforcement-health.ps1"
        $script:cmd  = Join-Path $script:hooksDir "enforcement-health.cmd"
        $script:temps = New-Object System.Collections.ArrayList

        # Invoca o hook controlando o ambiente. PERCUS_CANON_DIR NUNCA e herdada de quem roda a
        # suite: a maquina do operador sempre tem ela setada, e o teste do caminho "sem kit"
        # mediria outra coisa.
        function Invoke-Health {
            param([string]$CanonDir, [string]$ConfigDir)
            $antesCanon  = $env:PERCUS_CANON_DIR
            $antesConfig = $env:CLAUDE_CONFIG_DIR
            try {
                if ($CanonDir) { $env:PERCUS_CANON_DIR = $CanonDir }
                else { Remove-Item env:PERCUS_CANON_DIR -ErrorAction SilentlyContinue }
                if ($ConfigDir) { $env:CLAUDE_CONFIG_DIR = $ConfigDir }
                $saida = (& pwsh -NoProfile -File $script:ps1 2>&1 | Out-String)
                return [pscustomobject]@{ Saida = $saida; Exit = $LASTEXITCODE }
            } finally {
                if ($null -ne $antesCanon)  { $env:PERCUS_CANON_DIR = $antesCanon }  else { Remove-Item env:PERCUS_CANON_DIR -ErrorAction SilentlyContinue }
                if ($null -ne $antesConfig) { $env:CLAUDE_CONFIG_DIR = $antesConfig } else { Remove-Item env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
            }
        }

        # Monta um "instalado" falso declarando a versao que o kit tem AGORA. Sem isto, o teste
        # positivo depende do estado real da maquina -- e ele quebrou de verdade no minuto em que
        # o kit foi pra 6.34.0 com a 6.33.0 ainda instalada. O health check estava CERTO; o teste
        # e que assumia um mundo limpo em vez de construir um. Teste que depende de estado externo
        # falha por motivo que nao e o dele.
        function New-ConfigFalso {
            param([string]$Versao)
            $raiz = Join-Path ([IO.Path]::GetTempPath()) ("cfg-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
            New-Item -ItemType Directory -Path (Join-Path $raiz "plugins") -Force | Out-Null
            $j = @{ version = 2; plugins = @{ "percus-review@percus-tools" = @(@{ version = $Versao; scope = "user" }) } }
            $j | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $raiz "plugins\installed_plugins.json") -Encoding utf8
            [void]$script:temps.Add($raiz)
            return $raiz
        }
    }

    AfterAll { foreach ($d in $script:temps) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue } }

    It "DIRECAO POSITIVA: com tudo certo, ele FALA -- assinatura presente e veredito ok" {
        # A metade que o pre-mortem apontou como faltando. Health check que so fala em caso de
        # erro nao pode ser distinguido de health check que nao rodou.
        $kit = (Resolve-Path (Join-Path $script:hooksDir ".." ".." "..")).Path
        $verKit = (Get-Content (Join-Path $script:hooksDir ".." "plugin.json") -Raw | ConvertFrom-Json).version
        $r = Invoke-Health -CanonDir $kit -ConfigDir (New-ConfigFalso -Versao $verKit)
        $r.Saida | Should -Match '\[percus:health\]' -Because "sem assinatura nao ha como contar que ele rodou"
        $r.Saida | Should -Match 'enforcement ok'
        $r.Saida | Should -Match 'vindo do kit'
        $r.Saida | Should -Match ([regex]::Escape($verKit))
    }

    It "DIRECAO NEGATIVA: versao instalada diferente da do kit e denunciada" {
        # Este caso apareceu sozinho durante a implementacao: o kit foi pra 6.34.0 com a 6.33.0
        # ainda instalada, e o health check acusou antes de qualquer teste pedir. Registrado como
        # It proprio porque e o sintoma de "mudanca de REGISTRO ainda nao vale nesta maquina" --
        # que e diferente de "codigo desatualizado", e o operador precisa saber qual dos dois e.
        $kit = (Resolve-Path (Join-Path $script:hooksDir ".." ".." "..")).Path
        $r = Invoke-Health -CanonDir $kit -ConfigDir (New-ConfigFalso -Versao "0.0.1-nao-existe")
        $r.Saida | Should -Match 'ATENCAO'
        $r.Saida | Should -Match 'versao instalada'
        $r.Saida | Should -Match 'REGISTRO'
        $r.Exit  | Should -Be 0
    }

    It "NUNCA bloqueia -- exit 0 em qualquer cenario: <Rotulo>" -ForEach @(
        @{ Rotulo = "tudo certo";        Canon = "USAR-KIT" }
        @{ Rotulo = "sem PERCUS_CANON_DIR"; Canon = "" }
        @{ Rotulo = "canon apontando pro vazio"; Canon = "USAR-VAZIO" }
    ) {
        # Contrato duro: observador, nunca guarda. E o unico hook capaz de deixar a maquina
        # inutilizavel logo na abertura da sessao, e trocar ausencia silenciosa por sessao
        # trancada seria trocar um problema por outro pior.
        $c = switch ($Canon) {
            "USAR-KIT"   { (Resolve-Path (Join-Path $script:hooksDir ".." ".." "..")).Path }
            "USAR-VAZIO" {
                $v = Join-Path ([IO.Path]::GetTempPath()) ("vazio-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
                New-Item -ItemType Directory -Path $v -Force | Out-Null
                [void]$script:temps.Add($v); $v
            }
            default { "" }
        }
        (Invoke-Health -CanonDir $c).Exit | Should -Be 0 -Because "health check que tranca a sessao e pior que o problema que ele detecta"
    }

    It "DIRECAO NEGATIVA: sem PERCUS_CANON_DIR, denuncia que o codigo vem do CACHE" {
        # O buraco que o trampolim abriu e nao consegue anunciar sozinho: saida de hook que sai 0
        # e invisivel (item 10 da medicao), entao o aviso tem que morar aqui.
        $r = Invoke-Health -CanonDir ""
        $r.Saida | Should -Match '\[percus:health\]'
        $r.Saida | Should -Match 'ATENCAO'
        $r.Saida | Should -Match 'vem do CACHE'
        $r.Saida | Should -Match 'nao esta setada'
    }

    It "DIRECAO NEGATIVA: canon apontando pra arvore SEM os hooks tambem denuncia" {
        # Variavel setada nao e o mesmo que variavel correta. Sem este caso, um PERCUS_CANON_DIR
        # apontando pro lugar errado passaria por 'ok' so por existir.
        $v = Join-Path ([IO.Path]::GetTempPath()) ("vazio-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $v -Force | Out-Null
        [void]$script:temps.Add($v)
        $r = Invoke-Health -CanonDir $v
        $r.Saida | Should -Match 'vem do CACHE'
        $r.Saida | Should -Match 'nao tem os hooks'
    }

    It "o wrapper e a forma OBSERVADOR e roda o hook de ponta a ponta" {
        # Prova pelo caminho real (.cmd -> powershell -> .ps1), nao so invocando o .ps1 direto.
        $saida = (& cmd.exe /c "`"$script:cmd`"" 2>&1 | Out-String)
        $LASTEXITCODE | Should -Be 0
        $saida | Should -Match '\[percus:health\]'
    }

    It "ate a falha do PROPRIO health check e dita em voz alta" {
        # O pior estado possivel e o health check morrer calado: parece que esta tudo bem porque
        # ninguem falou nada. Provado por mutacao -- manifesto ausente e o unico insumo sem o
        # qual ele nao consegue concluir nada.
        $conteudo = Get-Content $script:ps1 -Raw
        $conteudo | Should -Match 'o proprio health check falhou' -Because "o catch precisa falar, nao engolir"
        $conteudo | Should -Match 'manifesto nao encontrado'      -Because "insumo ausente e NAO-VERIFICADO, nao 'ok'"

        # E a prova comportamental: sem manifesto, ele avisa em vez de dizer que esta tudo bem.
        $isolado = Join-Path ([IO.Path]::GetTempPath()) ("health-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $isolado -Force | Out-Null
        [void]$script:temps.Add($isolado)
        Copy-Item $script:ps1 (Join-Path $isolado "enforcement-health.ps1")
        $saida = (& pwsh -NoProfile -File (Join-Path $isolado "enforcement-health.ps1") 2>&1 | Out-String)
        $LASTEXITCODE | Should -Be 0
        $saida | Should -Match 'NAO consegui verificar' -Because "sem manifesto ele nao pode concluir que esta ok"
        $saida | Should -Not -Match 'enforcement ok'
    }
}
