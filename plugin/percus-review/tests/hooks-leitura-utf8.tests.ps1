#requires -Version 5.1
# Prova que hook LE arquivo de dados com UTF-8 explicito.
#
# Classe DIFERENTE da do ps51-compat, e por isso ela sobreviveu a todas as guardas:
#
#   ps51-compat  -> o .ps1 FONTE sem BOM nao PARSEIA no 5.1.        Conserto: BOM no .ps1.
#   esta aqui    -> o .md/.json LIDO decodifica errado no 5.1.      Conserto: -Encoding UTF8.
#
# No PowerShell 5.1 o default de Get-Content e ANSI (Windows-1252); no pwsh 7 e UTF-8. Um
# arquivo de dados UTF-8 SEM BOM -- que e o certo para markdown e obrigatorio para JSON --
# entao chega diferente nos dois runtimes. Medido em 2026-08-16 lendo CANON_VERSION.md:
#
#   pwsh 7 : "# Canon Percus - versao atual"       (correto)
#   PS 5.1 : "# Canon Percus a€" versAo atual"     (mojibake)
#
# Consequencia real: o regex do canon-version-check.ps1 tem [aa] e [oo] para casar "versao
# canonica", nao casava sob 5.1, e o hook saia com "skip" e **exit 0**. Guarda morta
# respondendo verde -- a mesma familia do incidente de 2026-07-30, com outra causa.
#
# E NAO da pra consertar botando BOM nos dados: markdown nao usa, e JSON com BOM quebra
# parser alheio. Quem le e que tem de declarar o encoding.

Describe "hook le arquivo de dados com UTF-8 explicito" {

    BeforeAll {
        $script:hooksDir = Join-Path (Split-Path $PSScriptRoot -Parent) "hooks"
        $script:kitRoot  = (Resolve-Path (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "..")).Path
        $script:ps51     = Get-Command powershell.exe -ErrorAction SilentlyContinue
    }

    It "canon-version-check.ps1 extrai a versao rodando sob PowerShell 5.1 de verdade" {
        if (-not $script:ps51) {
            Set-ItResult -Skipped -Because "powershell.exe (5.1) nao existe nesta maquina; sem ele o .cmd do hook tambem nao roda"
            return
        }

        $hook = Join-Path $script:hooksDir "canon-version-check.ps1"
        # PERCUS_CANON_DIR explicito: sem ele o hook pula por OUTRO motivo e o teste afere nada.
        $saida = & $script:ps51.Source -NoProfile -ExecutionPolicy Bypass -Command `
            "`$env:PERCUS_CANON_DIR = '$($script:kitRoot)'; & '$hook'" 2>&1 | Out-String

        # Anti-vacuidade: o hook AVISA sobre divergencia por desenho (canon_version dos
        # system-prompt-*.md e data, CANON_VERSION.md e semver -- diverge sempre, de proposito).
        # Sem esta linha, um hook que nao rodasse deixaria o teste verde por saida vazia.
        $saida | Should -Match 'canon atual=' -Because "o hook tem que chegar a comparar as versoes"

        $saida | Should -Not -Match 'nao foi possivel extrair' `
            -Because "sob 5.1 o Get-Content sem -Encoding devolve mojibake e o regex acentuado nao casa"
    }

    It "todo Get-Content de hook declara -Encoding UTF8 (nao basta declarar QUALQUER encoding)" {
        # Hooks rodam sob powershell.exe 5.1 SEMPRE (todo .cmd em hooks/ invoca powershell.exe,
        # nunca pwsh). Entao aqui o default ANSI nao e hipotese: e o que acontece.
        $arqs = @(Get-ChildItem $script:hooksDir -Filter *.ps1 -File -ErrorAction SilentlyContinue)
        $arqs.Count | Should -BeGreaterThan 3 -Because "hooks/ tem varios .ps1; varredura curta e varredura quebrada"

        $achados = @()
        $vistos  = 0
        foreach ($a in $arqs) {
            $texto = [IO.File]::ReadAllText($a.FullName)
            $texto = [regex]::Replace($texto, "`` *\r?\n[^\S\r\n]*", ' ')   # junta continuacao de linha
            $texto = [regex]::Replace($texto, '(?s)<#.*?#>', '')            # comentario de bloco
            $texto = [regex]::Replace($texto, '(?m)#.*$', '')               # comentario de linha
            foreach ($m in [regex]::Matches($texto, '(?m)Get-Content[^\r\n]*')) {
                $vistos++
                # Exige o VALOR, nao so a presenca do parametro: no PS 5.1 `-Encoding Default`
                # E o Windows-1252 que causou o mojibake, e `-Encoding ASCII` e pior ainda.
                # Aceitar "tem -Encoding" deixaria a regressao voltar declarando o bug por
                # extenso -- apontado pelo R11 revisando esta propria versao (2026-08-16).
                if ($m.Value -notmatch '(?i)-Encoding\s+UTF8') {
                    $achados += "$($a.Name): $($m.Value.Trim())"
                }
            }
        }

        # Piso: se o strip comesse tudo, nao haveria Get-Content nenhum e o teste passaria vazio.
        $vistos | Should -BeGreaterThan 0 -Because "os hooks leem arquivo; zero Get-Content e varredura quebrada"
        @($achados) | Should -BeNullOrEmpty -Because "no 5.1 o default e ANSI e o conteudo acentuado chega corrompido:`n$($achados -join "`n")"
    }
}
