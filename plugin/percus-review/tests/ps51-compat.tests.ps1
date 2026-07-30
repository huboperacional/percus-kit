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
        $prog = @'
$raiz = $args[0]
Get-ChildItem $raiz -Recurse -Include *.ps1 -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\\.git\\' } |
  ForEach-Object {
    $erros = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$erros)
    if ($erros -and $erros.Count -gt 0) {
      "{0} ({1} erro(s)) -- 1o: {2}" -f $_.FullName.Replace($raiz + '\', ''), $erros.Count, $erros[0].Message
    }
  }
'@
        # O proprio programa auxiliar vai COM BOM: ele tambem seria lido como ANSI pelo 5.1.
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("ps51-" + [Guid]::NewGuid().ToString("N").Substring(0,8) + ".ps1")
        [IO.File]::WriteAllText($tmp, $prog, (New-Object System.Text.UTF8Encoding($true)))
        try {
            $falhas = & $script:ps51.Source -NoProfile -ExecutionPolicy Bypass -File $tmp $script:kitRoot 2>&1
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }

        @($falhas) | Should -BeNullOrEmpty -Because "arquivo que nao parseia no 5.1 e hook que morre calado:`n$(($falhas | Out-String))"
    }
}
