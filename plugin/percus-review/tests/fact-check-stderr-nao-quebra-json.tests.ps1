#requires -Version 5.1
# Fase 5: o fact-check falhava com "Unexpected character ... line 1, position 1" quando
# fact-check.ps1/.sh escrevia QUALQUER linha em stderr antes do JSON (ex.: WARN de fallback
# de effort do cross-claude.ps1). Causa: percus-review-auto.ps1 chamava fact-check.ps1 com
# `2>&1` e $ErrorActionPreference='Stop' (herdado do topo do script) transformava a linha de
# stderr em erro terminante ANTES do ConvertFrom-Json rodar -- o -ErrorAction SilentlyContinue
# do ConvertFrom-Json nao protegia, porque o erro acontecia na enumeracao do array capturado,
# nao dentro do cmdlet. Reproduzido isolado (fora deste teste, ver relatorio da Fase 5):
#   $fcOut = & pwsh -File <script-que-escreve-1-linha-em-stderr-e-depois-JSON> 2>&1
#   $fcOut | ConvertFrom-Json -ErrorAction SilentlyContinue
#   -> lanca "Unexpected character encountered while parsing value: c. Path '', line 1, position 1."
# (a letra 'c' e a 2a posicao da linha de stderr "[cross-claude] ...", nao do JSON).
#
# Este teste roda o wrapper REAL (percus-review-auto.ps1/.sh) contra um fact-check.* FALSO que
# escreve uma linha de diagnostico em stderr (como cross-claude.ps1 faz de verdade) e depois
# devolve JSON valido -- sem gastar API. Antes do fix: o review final saia SEM aplicar o
# fact-check (fallback silencioso pro output original, sem "NAO rodou" visivel). Depois do fix:
# o review final deve refletir o filtered_output do fact-check (prova de que o JSON foi
# parseado) e nenhuma linha "fact-check NAO rodou" deve aparecer nesse caso feliz.
#
# Um segundo caso cobre fact-check.* falhando de verdade (exit != 0): o wrapper deve emitir a
# linha "fact-check NAO rodou: <motivo>" em stderr (requisito de visibilidade da Fase 5) em vez
# de seguir calado.

BeforeDiscovery {
    $script:casosStderr = @('ps1', 'sh')
}

Describe "percus-review-auto -- fact-check com stderr misturado nao quebra o JSON" {
    BeforeAll {
        . (Join-Path $PSScriptRoot '_resolver-bash.ps1')
        . (Join-Path $PSScriptRoot '_plugin-review-falso.ps1')
        $kit = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') '..')).Path
        $kit = Split-Path $kit -Parent
        $script:wrapPs1 = Join-Path (Join-Path $kit 'scripts') 'percus-review-auto.ps1'
        $script:wrapSh  = ConvertTo-CaminhoBash (Join-Path (Join-Path $kit 'scripts') 'percus-review-auto.sh')
        $script:bash = Get-BashGit
        $script:u8 = New-Object System.Text.UTF8Encoding($false)
        $script:u8bom = New-Object System.Text.UTF8Encoding($true)
        $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-fc-stderr-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null

        # fact-check.ps1/.sh falso: emite 1 linha de diagnostico em stderr (como
        # cross-claude.ps1/_cross-claude-body.ps1 faz de verdade via [Console]::Error.WriteLine
        # quando o modelo nao aceita o effort pedido) e devolve JSON valido em stdout.
        # -FindingsFile chega mas nao importa pro fake.
        function Escrever-FactCheckFalsoOk {
            param([string]$Pasta)
            $linhasPs1 = @(
                'param([string]$FindingsFile)'
                "[Console]::Error.WriteLine('[cross-claude] claude-haiku-4-5 nao aceita output_config.effort -- omitindo.')"
                "@{ findings_total=1; findings_confirmed=1; findings_infundado=0; findings_parcial=0; findings_unverified=0; filtered_output='FACT-CHECK-OK-MARKER'; audit=@() } | ConvertTo-Json -Compress"
                'exit 0'
            )
            [IO.File]::WriteAllText((Join-Path $Pasta 'fact-check.ps1'), (($linhasPs1 -join "`n") + "`n"), $script:u8bom)
            $jsonLine = '{"findings_total":1,"findings_confirmed":1,"findings_infundado":0,"findings_parcial":0,"findings_unverified":0,"filtered_output":"FACT-CHECK-OK-MARKER","audit":[]}'
            $linhasSh = @(
                '#!/usr/bin/env bash'
                'cat >/dev/null'
                "echo '[cross-claude] claude-haiku-4-5 nao aceita output_config.effort -- omitindo.' >&2"
                "echo '$jsonLine'"
                'exit 0'
            )
            [IO.File]::WriteAllText((Join-Path $Pasta 'fact-check.sh'), (($linhasSh -join "`n") + "`n"), $script:u8)
        }

        # fact-check.ps1/.sh falso: falha de verdade (exit 1, sem JSON valido em stdout).
        function Escrever-FactCheckFalsoFalha {
            param([string]$Pasta)
            $linhasPs1 = @(
                'param([string]$FindingsFile)'
                "[Console]::Error.WriteLine('[fact-check] falha simulada de teste')"
                'exit 1'
            )
            [IO.File]::WriteAllText((Join-Path $Pasta 'fact-check.ps1'), (($linhasPs1 -join "`n") + "`n"), $script:u8bom)
            $linhasSh = @(
                '#!/usr/bin/env bash'
                'cat >/dev/null'
                "echo '[fact-check] falha simulada de teste' >&2"
                'exit 1'
            )
            [IO.File]::WriteAllText((Join-Path $Pasta 'fact-check.sh'), (($linhasSh -join "`n") + "`n"), $script:u8)
        }

        function Invoke-WrapperComFactCheck {
            param([ValidateSet('ps1', 'sh')][string]$Rt, $Plugin)
            $cwd = Join-Path $script:tmpBase ("w-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Force -Path $cwd | Out-Null
            $router = '{"decision":"deepseek","sensitive":false,"from_deepseek":false,"files_count":1,"warnings":[]}'
            $cfg = $Plugin.Cfg
            if ($Rt -eq 'sh') { $cfg = ConvertTo-CaminhoBash $cfg }
            $antigos = Set-EnvTemporario @{ CLAUDE_CONFIG_DIR = $cfg; FAKE_ROUTER_JSON = $router; FAKE_DS_EXIT = "0" }
            $out = Join-Path $script:tmpBase ("out-" + [Guid]::NewGuid().ToString('N') + '.txt')
            $err = Join-Path $script:tmpBase ("err-" + [Guid]::NewGuid().ToString('N') + '.txt')
            Push-Location $cwd
            try {
                if ($Rt -eq 'ps1') { $null = & pwsh -NoProfile -File $script:wrapPs1 1> $out 2> $err }
                else { $null = & $script:bash -c ("cd '" + (ConvertTo-CaminhoBash $cwd) + "' && bash '" + $script:wrapSh + "'") 1> $out 2> $err }
                $code = $LASTEXITCODE
            } finally { Pop-Location; Restore-EnvTemporario $antigos }
            $saida = if (Test-Path $out) { [IO.File]::ReadAllText($out, $script:u8) } else { '' }
            $texto = if (Test-Path $err) { [IO.File]::ReadAllText($err, $script:u8) } else { '' }
            return [pscustomobject]@{ Code = $code; Out = $saida; Err = $texto }
        }
    }

    AfterAll {
        Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
    }

    It "<Rt>: fact-check com 1 linha de stderr antes do JSON ainda aplica o filtered_output" -ForEach @(
        foreach ($rt in $script:casosStderr) { @{ Rt = $rt } }
    ) {
        $pl = New-PluginFalso -TmpBase $script:tmpBase
        Escrever-FactCheckFalsoOk -Pasta $pl.Scripts
        $r = Invoke-WrapperComFactCheck -Rt $Rt -Plugin $pl
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Out | Should -Match 'FACT-CHECK-OK-MARKER' -Because "o JSON do fact-check (com stderr misturado na chamada) tem de ser parseado e o filtered_output aplicado. stdout=[$($r.Out)] stderr=[$($r.Err)]"
        $r.Err | Should -Not -Match 'fact-check NAO rodou' -Because "caso feliz: fact-check rodou e parseou, nao pode acusar falha. stderr: $($r.Err)"
    }

    It "<Rt>: fact-check falhando de verdade emite 'fact-check NAO rodou' em vez de ficar calado" -ForEach @(
        foreach ($rt in $script:casosStderr) { @{ Rt = $rt } }
    ) {
        $pl = New-PluginFalso -TmpBase $script:tmpBase
        Escrever-FactCheckFalsoFalha -Pasta $pl.Scripts
        $r = Invoke-WrapperComFactCheck -Rt $Rt -Plugin $pl
        $r.Code | Should -Be 0 -Because $r.Err
        $r.Err | Should -Match 'fact-check NAO rodou' -Because "falha do fact-check tem de ficar visivel na saida do wrapper. stderr: $($r.Err)"
        $r.Out | Should -Match 'Sem findings criticos' -Because "sem fact-check valido, o wrapper deve devolver o output original do reviewer (do deepseek-review falso). stdout: $($r.Out)"
    }
}
