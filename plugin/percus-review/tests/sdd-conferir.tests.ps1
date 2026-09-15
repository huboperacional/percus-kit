#requires -Version 5.1
# Ponto 14: sdd-conferir.ps1 junta em uma chamada as 7 conferencias de fim de tarefa SDD que hoje
# sao manuais. Uma linha por checagem: "OK|FALHA|AVISO <nome>[: <detalhe>]"; ultima linha RESUMO.
# Repositorio temporario real por caso -- sem git mockado.

BeforeAll {
    $script:pluginDir = Split-Path $PSScriptRoot -Parent
    $script:repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
    $script:targetScript = Join-Path (Join-Path $script:repoRoot 'scripts') 'sdd-conferir.ps1'
    $script:tmpBase = Join-Path ([IO.Path]::GetTempPath()) ("percus-sdd-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $script:tmpBase | Out-Null
    $script:u8 = New-Object System.Text.UTF8Encoding($false)
    $script:ps51 = (Get-Command 'powershell.exe' -ErrorAction SilentlyContinue).Source

    function Invoke-Sdd {
        param([string]$RepoDir, [string]$BaseRev, [string]$HeadRev = 'HEAD', [switch]$Pwsh51, [switch]$SemBase)
        $exe = 'pwsh'
        if ($Pwsh51) { $exe = $script:ps51 }
        $argsSdd = @('-NoProfile', '-File', $script:targetScript, '-Head', $HeadRev, '-Repo', $RepoDir)
        if (-not $SemBase) { $argsSdd = @('-NoProfile', '-File', $script:targetScript, '-Base', $BaseRev, '-Head', $HeadRev, '-Repo', $RepoDir) }
        $saida = & $exe @argsSdd 2>&1
        return [pscustomobject]@{ Code = $LASTEXITCODE; Linhas = @($saida | ForEach-Object { [string]$_ }) }
    }

    function Get-HashCommitFixture {
        param([string]$RepoDir, [string]$Sha)
        $tmp = [IO.Path]::GetTempFileName()
        try {
            & git -C $RepoDir diff "${Sha}^" $Sha --output=$tmp 2>$null | Out-Null
            $bytes = [IO.File]::ReadAllBytes($tmp)
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            try {
                return ([BitConverter]::ToString($sha256.ComputeHash($bytes)) -replace '-', '').ToLower().Substring(0, 12)
            } finally { $sha256.Dispose() }
        } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }

    function Invoke-CommitFixture {
        param([string]$RepoDir, [string]$Subject, [string]$Trailer = '', [switch]$AssuntoVazio)
        Push-Location $RepoDir
        try {
            $cmdArgs = @(('com' + 'mit'), '-q', '--no-verify')
            if ($AssuntoVazio) {
                $cmdArgs += @('--allow-empty-message', '-m', '')
            } elseif ($Trailer) {
                $cmdArgs += @('-m', $Subject, '-m', $Trailer)
            } else {
                $cmdArgs += @('-m', $Subject)
            }
            & git @cmdArgs 2>$null | Out-Null
        } finally { Pop-Location }
        return (& git -C $RepoDir rev-parse HEAD 2>$null).Trim()
    }

    # Repo com um commit base (fora do intervalo) + git configurado sem CRLF automatico
    # (armadilha: core.autocrlf do repo de teste tem que ser false, senao a checagem sh-lf mente).
    function New-RepoBase {
        $dir = Join-Path $script:tmpBase ("r-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Push-Location $dir
        try {
            & git init -q . 2>$null
            & git config user.email 't@t.t' 2>$null
            & git config user.name 't' 2>$null
            & git config core.autocrlf false 2>$null
            # .deepseek/ e gitignorado no kit real (percus-kit/.gitignore:6): sem isso, o marcador
            # gravado por Set-Marcador aparece como nao-rastreado e derruba a checagem arvore-limpa.
            [IO.File]::WriteAllText((Join-Path $dir '.gitignore'), ".deepseek/`n", $script:u8)
            [IO.File]::WriteAllBytes((Join-Path $dir 'raiz.txt'), $script:u8.GetBytes("raiz`n"))
            & git add raiz.txt .gitignore 2>$null
        } finally { Pop-Location }
        $baseSha = Invoke-CommitFixture -RepoDir $dir -Subject 'base'
        return [pscustomobject]@{ Dir = $dir; BaseSha = $baseSha }
    }

    # Commit "sob teste": a.sh (ASCII, LF por padrao) + b.ps1 (com caractere acentuado, BOM por padrao).
    function Add-CommitTeste {
        param(
            [string]$Dir,
            [switch]$ShCrlf,
            [switch]$Ps1SemBom,
            [switch]$SemTrailer,
            [switch]$AssuntoVazio,
            [switch]$SemArquivos
        )
        if (-not $SemArquivos) {
            $quebra = "`n"; if ($ShCrlf) { $quebra = "`r`n" }
            $conteudoSh = "#!/bin/sh${quebra}echo hi${quebra}"
            [IO.File]::WriteAllBytes((Join-Path $Dir 'a.sh'), $script:u8.GetBytes($conteudoSh))

            $conteudoPs1 = $script:u8.GetBytes("# arquivo com acentuacao: " + [char]0x00E7 + "`n")
            if (-not $Ps1SemBom) { $conteudoPs1 = [byte[]](@(0xEF, 0xBB, 0xBF) + $conteudoPs1) }
            [IO.File]::WriteAllBytes((Join-Path $Dir 'b.ps1'), $conteudoPs1)

            Push-Location $Dir
            try { & git add a.sh b.ps1 2>$null | Out-Null } finally { Pop-Location }
        }
        $trailer = 'Co-Authored-By: Teste <t@t.t>'
        if ($SemTrailer) { $trailer = '' }
        return Invoke-CommitFixture -RepoDir $Dir -Subject 'algo' -Trailer $trailer -AssuntoVazio:$AssuntoVazio
    }

    function Set-Marcador {
        param([string]$Dir, [string]$Sha)
        $hash = Get-HashCommitFixture -RepoDir $Dir -Sha $Sha
        $reviewDir = Join-Path (Join-Path $Dir '.deepseek') 'reviews'
        New-Item -ItemType Directory -Force -Path $reviewDir | Out-Null
        [IO.File]::WriteAllText((Join-Path $reviewDir "d-$hash.jsonl"), '{"findings":"ok"}', $script:u8)
    }
}

AfterAll {
    Remove-Item -Recurse -Force $script:tmpBase -ErrorAction SilentlyContinue
}

Describe "sdd-conferir -- uma chamada, uma linha por checagem" {

    It "commit valido (ASCII/LF, BOM, trailer, marcador gravado): 7 OK, exit 0" {
        $r = New-RepoBase
        $sha = Add-CommitTeste -Dir $r.Dir
        Set-Marcador -Dir $r.Dir -Sha $sha
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha
        $res.Code | Should -Be 0 -Because ($res.Linhas -join "`n")
        @($res.Linhas | Where-Object { $_ -match '^OK ' }).Count | Should -Be 7
        $res.Linhas[-1] | Should -Be 'RESUMO ok=7 falha=0 aviso=0'
    }

    It "a.sh com CRLF: FALHA sh-lf, exit 1" {
        $r = New-RepoBase
        $sha = Add-CommitTeste -Dir $r.Dir -ShCrlf
        Set-Marcador -Dir $r.Dir -Sha $sha
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha
        $res.Code | Should -Be 1 -Because ($res.Linhas -join "`n")
        $res.Linhas | Should -Contain 'FALHA sh-lf: a.sh'
    }

    It "b.ps1 com acentuacao sem BOM: FALHA ps1-bom, exit 1" {
        $r = New-RepoBase
        $sha = Add-CommitTeste -Dir $r.Dir -Ps1SemBom
        Set-Marcador -Dir $r.Dir -Sha $sha
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha
        $res.Code | Should -Be 1 -Because ($res.Linhas -join "`n")
        $res.Linhas | Should -Contain 'FALHA ps1-bom: b.ps1'
    }

    It "arquivo nao rastreado na arvore: FALHA arvore-limpa, exit 1" {
        $r = New-RepoBase
        $sha = Add-CommitTeste -Dir $r.Dir
        Set-Marcador -Dir $r.Dir -Sha $sha
        [IO.File]::WriteAllText((Join-Path $r.Dir 'solto.txt'), 'x', $script:u8)
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha
        $res.Code | Should -Be 1 -Because ($res.Linhas -join "`n")
        @($res.Linhas | Where-Object { $_ -match '^FALHA arvore-limpa' }).Count | Should -BeGreaterThan 0 -Because ($res.Linhas -join "`n")
    }

    It "commit de codigo sem marcador: AVISO r11-marcador, exit 0 (nunca FALHA)" {
        $r = New-RepoBase
        $sha = Add-CommitTeste -Dir $r.Dir
        # sem Set-Marcador: nenhum d-<hash>.jsonl gravado
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha
        $res.Code | Should -Be 0 -Because ($res.Linhas -join "`n")
        $curto = (& git -C $r.Dir rev-parse --short $sha 2>$null).Trim()
        $res.Linhas | Should -Contain "AVISO r11-marcador: $curto"
    }

    It "commit que so toca .md fica isento do r11-marcador (extensao de texto)" {
        $r = New-RepoBase
        [IO.File]::WriteAllText((Join-Path $r.Dir 'doc.md'), "doc`n", $script:u8)
        Push-Location $r.Dir
        try { & git add doc.md 2>$null | Out-Null } finally { Pop-Location }
        Invoke-CommitFixture -RepoDir $r.Dir -Subject 'doc' -Trailer 'Co-Authored-By: Teste <t@t.t>' | Out-Null
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha
        $res.Code | Should -Be 0 -Because ($res.Linhas -join "`n")
        $res.Linhas | Should -Contain 'OK r11-marcador'
    }

    It "assunto de commit vazio: FALHA commit-mensagem, exit 1" {
        $r = New-RepoBase
        $sha = Add-CommitTeste -Dir $r.Dir -AssuntoVazio
        Set-Marcador -Dir $r.Dir -Sha $sha
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha
        $res.Code | Should -Be 1 -Because ($res.Linhas -join "`n")
        $curto = (& git -C $r.Dir rev-parse --short $sha 2>$null).Trim()
        $res.Linhas | Should -Contain "FALHA commit-mensagem: $curto"
    }

    It "commit sem trailer Co-Authored-By: AVISO commit-mensagem, exit 0" {
        $r = New-RepoBase
        $sha = Add-CommitTeste -Dir $r.Dir -SemTrailer
        Set-Marcador -Dir $r.Dir -Sha $sha
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha
        $res.Code | Should -Be 0 -Because ($res.Linhas -join "`n")
        $curto = (& git -C $r.Dir rev-parse --short $sha 2>$null).Trim()
        $res.Linhas | Should -Contain "AVISO commit-mensagem: $curto"
    }

    It "trailer Co-Authored-By apos descricao multilinha: OK commit-mensagem (nao falso AVISO)" {
        # Regressao (achado R11): %b multilinha castado para [string] junta tudo com espaco e
        # apaga os \n de que '(?m)^Co-Authored-By:' depende -- um trailer que nao e a primeira
        # linha do corpo virava falso AVISO.
        $r = New-RepoBase
        [IO.File]::WriteAllBytes((Join-Path $r.Dir 'a.sh'), $script:u8.GetBytes("#!/bin/sh`necho hi`n"))
        $conteudoPs1 = [byte[]](@(0xEF, 0xBB, 0xBF) + $script:u8.GetBytes("# ok`n"))
        [IO.File]::WriteAllBytes((Join-Path $r.Dir 'b.ps1'), $conteudoPs1)
        Push-Location $r.Dir
        try { & git add a.sh b.ps1 2>$null | Out-Null } finally { Pop-Location }
        $corpo = "descricao com`nmais de uma linha antes do trailer`n`nCo-Authored-By: Teste <t@t.t>"
        $sha = Invoke-CommitFixture -RepoDir $r.Dir -Subject 'algo' -Trailer $corpo
        Set-Marcador -Dir $r.Dir -Sha $sha
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha
        $res.Code | Should -Be 0 -Because ($res.Linhas -join "`n")
        $res.Linhas | Should -Contain 'OK commit-mensagem'
    }

    It "-Base inexistente: exit 2, sem linha de checagem" {
        $r = New-RepoBase
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev 'naoexiste'
        $res.Code | Should -Be 2
        $res.Linhas | Should -Not -Match '^(OK|FALHA|AVISO) '
    }

    It "-Repo que nao e um repositorio git: exit 2" {
        $dirSolto = Join-Path $script:tmpBase ("naogit-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $dirSolto | Out-Null
        $res = Invoke-Sdd -RepoDir $dirSolto -BaseRev 'HEAD'
        $res.Code | Should -Be 2
    }

    It "sem -Base: exit 2 com mensagem de uso" {
        $r = New-RepoBase
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev '' -SemBase
        $res.Code | Should -Be 2
        $res.Linhas | Should -Match 'uso:'
    }

    It "sob powershell.exe (5.1): mesmo veredito do caso base" {
        if (-not $script:ps51) { Set-ItResult -Skipped -Because "powershell.exe nao encontrado nesta maquina"; return }
        $r = New-RepoBase
        $sha = Add-CommitTeste -Dir $r.Dir
        Set-Marcador -Dir $r.Dir -Sha $sha
        $res = Invoke-Sdd -RepoDir $r.Dir -BaseRev $r.BaseSha -Pwsh51
        $res.Code | Should -Be 0 -Because ($res.Linhas -join "`n")
        $res.Linhas[-1] | Should -Be 'RESUMO ok=7 falha=0 aviso=0'
    }
}
