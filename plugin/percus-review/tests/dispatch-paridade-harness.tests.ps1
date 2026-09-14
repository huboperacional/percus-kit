# Contrato do harness de paridade (_dispatch-paridade.ps1): rodar um runtime NAO pode deixar o
# processo diferente de como estava. O Pester isola escopo de script por arquivo, mas NAO isola
# variavel de ambiente -- o que um arquivo deixa, o arquivo seguinte do mesmo balde do rodar-suite
# herda.
#
# Medido 2026-09-13: no pwsh, [Environment]::SetEnvironmentVariable(k, $null) CRIA k vazia (o
# binder converte $null em "" num parametro string); so [NullString]::Value remove. O harness
# restaurava assim as variaveis que estavam ausentes, e HOME ausente virava HOME="". Com HOME vazio
# o lancador Git\bin\bash.exe nao poe %HOME%\bin no PATH, o jq some, e o cross-claude.sh do
# arquivo SEGUINTE saia 127 sem fazer o POST. Resultado: 2 falhas na suite rodada de um pwsh sem
# HOME, zero pelo Git Bash (que ja entrega HOME) -- o mesmo commit, verde ou vermelho pelo runner.

BeforeAll {
    . (Join-Path $PSScriptRoot '_dispatch-paridade.ps1')

    # Presenca, e nao valor: "" e $null passam os dois em BeNullOrEmpty, e a diferenca entre eles
    # e exatamente o defeito.
    function Test-EnvPresente([string]$Nome) { [Environment]::GetEnvironmentVariables().Contains($Nome) }
    function Remove-EnvDeVerdade([string]$Nome) { [Environment]::SetEnvironmentVariable($Nome, [NullString]::Value) }
    function Restore-EnvDeVerdade([string]$Nome, $Valor) {
        if ($null -eq $Valor) { Remove-EnvDeVerdade $Nome } else { [Environment]::SetEnvironmentVariable($Nome, [string]$Valor) }
    }
    function New-NomeEnv { 'PERCUS_TESTE_HARNESS_' + [Guid]::NewGuid().ToString('N').Substring(0, 8) }
}

AfterAll { Remove-FixturesParidade }

Describe "o harness de paridade nao vaza estado de processo" {

    It "pre-condicao: o jeito de remover usado aqui deixa a variavel AUSENTE" {
        # Anti-vacuidade: se Remove-EnvDeVerdade so esvaziasse, os testes abaixo afeririam nada.
        $k = New-NomeEnv
        [Environment]::SetEnvironmentVariable($k, 'x')
        Remove-EnvDeVerdade $k
        Test-EnvPresente $k | Should -BeFalse
    }

    It "Invoke-BashComando nao cria variavel que estava ausente" {
        if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
        $k = New-NomeEnv
        try {
            Invoke-BashComando -Bash $script:bash -Comando 'true' -Env @{ $k = 'valor-do-cenario' } | Out-Null
            Test-EnvPresente $k | Should -BeFalse -Because "restaurar uma variavel ausente com `$null a cria vazia"
        } finally { Remove-EnvDeVerdade $k }
    }

    It "Invoke-Runtime nao cria variavel que estava ausente -- nem da base, nem do -Env" {
        $base = 'PERCUS_DISPATCH_DEBUG'
        $k = New-NomeEnv
        $originalBase = [Environment]::GetEnvironmentVariable($base)
        Remove-EnvDeVerdade $base
        try {
            $dir = New-Fixture -Evento pre
            $payload = @{ tool_name = 'Bash'; tool_input = @{ command = 'echo ola' }; cwd = 'C:\pasta-neutra' } | ConvertTo-Json -Compress
            Invoke-Runtime -Runtime cmd -Evento pre -Dir $dir -Payload $payload -Env @{ $k = 'valor-do-cenario' } | Out-Null
            Test-EnvPresente $base | Should -BeFalse -Because "$base e da base do harness e estava ausente"
            Test-EnvPresente $k | Should -BeFalse -Because "$k veio do -Env e estava ausente"
        } finally {
            Remove-EnvDeVerdade $k
            Restore-EnvDeVerdade $base $originalBase
        }
    }

    It "variavel que EXISTIA volta com o valor de antes" {
        # Guarda do conserto: remover tudo no finally tambem passaria nos testes de ausencia acima.
        if (-not $script:bash) { Set-ItResult -Skipped -Because "bash nao existe nesta maquina"; return }
        $k = New-NomeEnv
        [Environment]::SetEnvironmentVariable($k, 'original')
        try {
            Invoke-BashComando -Bash $script:bash -Comando 'true' -Env @{ $k = 'do-cenario' } | Out-Null
            [Environment]::GetEnvironmentVariable($k) | Should -BeExactly 'original'
        } finally { Remove-EnvDeVerdade $k }
    }

    It "o caso do incidente: HOME ausente continua ausente depois do cenario sem jq" {
        # Get-EnvSemJq e quem troca HOME. O teste tira HOME antes, entao independe do runner: mede o
        # mesmo pelo Git Bash (que entrega HOME) e por um pwsh que nao entrega.
        $semJq = Get-EnvSemJq
        if (-not (Test-Path -LiteralPath $semJq.Bash)) { Set-ItResult -Skipped -Because "Git\usr\bin\bash.exe nao existe nesta maquina"; return }
        $originalHome = [Environment]::GetEnvironmentVariable('HOME')
        Remove-EnvDeVerdade 'HOME'
        try {
            Invoke-BashComando -Bash $semJq.Bash -Comando 'true' -Env $semJq.Env | Out-Null
            Test-EnvPresente 'HOME' | Should -BeFalse -Because "HOME vazio tira o bin do HOME do PATH do lancador do Git, e o jq some para o arquivo seguinte"
        } finally { Restore-EnvDeVerdade 'HOME' $originalHome }
    }
}
