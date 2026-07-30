#requires -Version 5.1
# Prova que todo .ps1 do kit PARSEIA sob Windows PowerShell 5.1 -- que e o runtime real
# dos hooks: todo .cmd em hooks/ invoca powershell.exe, nunca pwsh 7. A suite roda em
# pwsh 7, que le UTF-8 por default, entao ela e cega pra esta classe por construcao.
# Foi assim que 16 arquivos, incluindo 3 guardas de PreToolUse, quebraram sem ninguem ver.

Describe "todo .ps1 do kit parseia sob Windows PowerShell 5.1" {
    BeforeAll {
        $script:kitRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." ".." "..")).Path
        $script:ps51    = Get-Command powershell.exe -ErrorAction SilentlyContinue
    }

    It "nenhum .ps1 do kit tem erro de parse no 5.1" {
        if (-not $script:ps51) {
            Set-ItResult -Skipped -Because "powershell.exe (5.1) nao existe nesta maquina; sem ele os .cmd tambem nao rodam, entao o hook e irrelevante aqui"
            return
        }

        # Parse SEM executar. Rodar os .ps1 pra descobrir se parseiam dispararia hook de
        # verdade (git, rede, escrita em .deepseek/) como efeito colateral de um teste.
        # node_modules fica FORA: sao shims de terceiros (esbuild, rollup, vite), gitignorados
        # e regenerados por npm install -- o unico "conserto" possivel seria editar node_modules.
        # A ultima linha e VISTOS=n: sem ela, varredura vazia (arquivo movido, erro de ACL
        # engolido pelo -ErrorAction) satisfaz o Should -BeNullOrEmpty e o teste fica verde
        # guardando nada -- a mesma classe de falso-verde que este arquivo existe pra impedir.
        $prog = @'
$raiz = $args[0]
$arqs = @(Get-ChildItem $raiz -Recurse -Include *.ps1 -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' })
foreach ($a in $arqs) {
  $erros = $null
  $null = [System.Management.Automation.Language.Parser]::ParseFile($a.FullName, [ref]$null, [ref]$erros)
  if ($erros -and $erros.Count -gt 0) {
    "{0}:{1} ({2} erro(s)) -- 1o: {3}" -f $a.FullName.Replace($raiz + '\', ''), $erros[0].Extent.StartLineNumber, $erros.Count, $erros[0].Message
  }
}
"VISTOS={0}" -f $arqs.Count
'@
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("ps51-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".ps1")
        try {
            # O proprio programa auxiliar vai COM BOM: ele tambem seria lido como ANSI pelo 5.1.
            [IO.File]::WriteAllText($tmp, $prog, (New-Object System.Text.UTF8Encoding($true)))
            $saida = & $script:ps51.Source -NoProfile -ExecutionPolicy Bypass -File $tmp $script:kitRoot 2>&1
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }

        $vistos = 0
        $falhas = @()
        foreach ($linha in @($saida)) {
            $t = "$linha"
            if ($t -match '^VISTOS=(\d+)$') { $vistos = [int]$Matches[1] }
            elseif ($t.Trim() -ne '')      { $falhas += $t }
        }

        $vistos | Should -BeGreaterThan 40 -Because "varredura vazia passaria calada, que e o defeito que este teste existe pra impedir"

        @($falhas) | Should -BeNullOrEmpty -Because "arquivo que nao parseia no 5.1 e hook que morre calado. Causa desta classe: .ps1 sem BOM lido como ANSI pelo 5.1 -- grave como UTF-8 COM BOM.`n$($falhas -join "`n")"
    }

    It "nenhum .ps1 do kit tem caractere nao-ASCII sem BOM (a armadilha que nao quebra o parse)" {
        # Parse-only so pega mojibake que quebra sintaxe. Acento dentro de string que
        # continua sintaticamente valido passa verde e o hook imprime lixo. Este It fecha
        # essa metade: se tem byte > 0x7F, tem que ter BOM.
        $sem = Get-ChildItem $script:kitRoot -Recurse -Include *.ps1 -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' } |
            Where-Object {
                $b = [IO.File]::ReadAllBytes($_.FullName)
                $temNaoAscii = $false
                foreach ($x in $b) { if ($x -gt 0x7F) { $temNaoAscii = $true; break } }
                $comBom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
                $temNaoAscii -and -not $comBom
            } | ForEach-Object { $_.FullName.Replace($script:kitRoot + '\', '') }

        @($sem) | Should -BeNullOrEmpty -Because "sem BOM, o 5.1 le como ANSI: acento vira lixo na saida do hook, e um em dash dentro de string quebra o arquivo inteiro:`n$($sem -join "`n")"
    }
}
