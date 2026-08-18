## Teste chama o script no mesmo processo e "prova" silêncio: `Write-Host` e `[Console]::Error` não passam pelo `2>&1` {#teste-in-process-nao-captura-console-error}

`tags: powershell, pester, teste, 2>&1, redirecionamento, Write-Host, Console::Error, stderr, stdout, in-process, processo filho, assercao vazia, falso verde, LASTEXITCODE`

**Sintoma:** um teste afirma que o script emite certa mensagem (`Should -Match 'ADIA'`) e falha dizendo que o padrão não casou com **string vazia** — mesmo você vendo a mensagem aparecer no terminal quando roda o script na mão. Pior variante: a asserção é `Should -Not -Match`, e aí o teste passa **verde** aferindo nada.

**Causa raiz:** chamar `& .\script.ps1` de dentro do teste roda o script **no mesmo processo** do Pester, e nesse modo nem `Write-Host` nem `[Console]::Error.WriteLine` atravessam o `2>&1 | Out-String`:

- `Write-Host` escreve no **host** (stream de informação), não no stream de saída.
- `[Console]::Error.WriteLine` escreve **direto no stderr do processo**, sem passar pelo stream de erro do PowerShell — que é o único que o `2>&1` do PowerShell redireciona.

Ou seja, o `2>&1` não é inútil: ele redireciona o *error stream do PowerShell*. Quem escreve fora dele (Console, host) simplesmente não é visto. Captura vazia.

**Solução:** rode o script como **processo filho** no teste. Aí o stderr e o stdout são reais, `2>&1` captura os dois, e `$LASTEXITCODE` passa a ser o código de saída de verdade:

```powershell
$exe = if ($PSVersionTable.PSEdition -eq 'Core') { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'powershell.exe' }
$saida = & $exe -NoProfile -ExecutionPolicy Bypass -File $script -Raiz $raiz 2>&1 | Out-String
```

Bônus: processo filho é como hook, gate e checkpoint realmente invocam — o teste passa a exercitar a invocação de produção em vez de uma que só existe no teste.

⚠️ **A alternativa "troque `[Console]::Error` por `Write-Error`" conserta a captura e ESTRAGA o script:** `Write-Error` vira `ErrorRecord` com stack trace, polui a saída de hook, e em `$ErrorActionPreference = "Stop"` aborta. Para script de linha de comando, `[Console]::Error` é o certo — quem se adapta é o teste.

**Como reconhecer na hora:** asserção de mensagem falhando contra `<empty>` enquanto o comportamento observável está correto. Se o teste afere **mensagem** ou **código de saída**, ele tem de rodar processo filho.

**Ref:** percus-kit 6.36.6, 2026-08-16 — mesclador da caixa de conhecimento; a primeira versão do helper chamava in-process e 5 asserções liam string vazia.
