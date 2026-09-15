## `gemini-ler-longo.ps1`: leitor de documento longo via `agy` (Gemini headless), com citacao de linha {#gemini-agy-leitor-de-documento-longo}

`tags: agy, Gemini, Antigravity, leitor de documento longo, ponto 20, stream-json, ProcessStartInfo, BOM, deadlock de pipe, PS 5.1, citacao de linha`

**Quando:** ler um PLANO ou documento grande demais para o contexto do implementador (455 KB-1,1 MB)
sem colar o texto inteiro, com prova de qual linha sustenta cada afirmacao. Script:
`scripts/gemini-ler-longo.ps1`. Teste: `plugin/percus-review/tests/gemini-ler-longo.tests.ps1`.

### Invocacao medida do `agy`

Resolucao do executavel (nessa ordem): `$env:AGY_EXE` -> `Get-Command agy` no PATH -> `-AgyExe`
explicito. **Sem fallback de caminho pessoal no script** (o R11 pegou isso 2 rodadas seguidas):
nesta sessao de medicao, o executavel ficou em
`C:\Users\Criativo66\AppData\Local\Microsoft\WinGet\Links\agy.exe` (symlink do pacote
`Google.AntigravityCLI`) — isso e' so um exemplo de onde o WinGet costuma instalar, nao um caminho
valido em outro host Percus ou em CI. Configure `$env:AGY_EXE` por maquina. `ProcessStartInfo` com `WorkingDirectory` numa pasta temporaria vazia sob
`%TEMP%` (prefixo `agy-ler-`), apagada no `finally`. Argumentos: `--model <modelo> --sandbox
--disable-slash-commands --input-format stream-json --output-format stream-json --print-timeout
<N>m -p=` (o `-p=` vazio vai colado e por ultimo). Stdin: uma linha `{"event":"user","message":
{"role":"user","content":"<texto>"}}`, depois fecha. Stdout ndjson: `init`, varios `step_update`, um
`result` final com `status`, `response`, `usage`, `duration_seconds`.

Medido no passo 0 desta tarefa (`gemini-3.8-flash-low`, 3 linhas numeradas): `event:result` +
`status:SUCCESS` na primeira tentativa, ~1,9s, 17.411 tokens totais. `/usage` (nao gasta cota):
`agy -p '/usage'` devolve texto tabulado nao documentado, ex.: `Gemini Models\tWeekly Limit
Remaining\t73%\t<data ISO>`.

### O que o script faz

Numera cada linha de cada documento com o numero ORIGINAL do arquivo (`<nome>:L<n>| <texto>`,
preservado entre fatias). Fatia em `<= MaxLinhas` (default 1500), cortando de preferencia num
titulo `## ` fora de cerca de codigo, buscado numa janela de `[inicio+0,8*MaxLinhas,
inicio+1,2*MaxLinhas-1]` — um titulo real perto do fim pode empurrar o corte ate 20% alem do teto
para nao partir uma secao ao meio; sem titulo na janela, corte duro em `MaxLinhas`. Prompt fixo
antes da pergunta exige citacao `[<nome>:L<a>-L<b>]`; sem citacao, a fatia nao escreve nada. Saida
`.md` (cabecalho com custo/cota) + `.json` paralelo (`citacoes_total`, `citacoes_fora_da_fatia`,
`fatias_falhas`). Exits: 0 = todas as fatias com `result` SUCCESS e resposta nao vazia; 2 = uso
invalido; 3 = alguma fatia vazia/sem `result`/`escalate_admin`; 4 = `agy` ausente ou nao iniciou.

### Armadilhas medidas nesta sessao

- **`ProcessStartInfo.ArgumentList` e' `$null` no .NET Framework do Windows PowerShell 5.1**
  ("Nao e' possivel chamar um metodo em uma expressao de valor nulo" ao dar `.Add()`). So existe de
  verdade em .NET Core/5+ (pwsh). A correcao e' montar a string `.Arguments` a mao, com a regra de
  quoting do Win32 `CommandLineToArgvW` (aspas dobradas escapadas com barra invertida, barras antes
  de aspas dobradas) — ver `ConvertTo-ArgumentoCmd`/`New-LinhaArgumentos` no script.
- **Nao nomeie um parametro de funcao `$args`:** colide com a variavel automatica `$args` do
  PowerShell e a funcao devolve string vazia silenciosamente — sem erro, sem aviso. O sintoma foi um
  `powershell.exe` filho abrindo sessao **interativa** (banner "Windows PowerShell / Copyright...")
  em vez de rodar `-File`, porque `.Arguments` ficou vazio.
- **`powershell.exe -File <script>` como NETO (via `ProcessStartInfo` filho de outro processo com
  stdin redirecionado) injeta um BOM UTF-8 (`EF BB BF`) no INICIO do que o script recebe via
  `[Console]::OpenStandardInput()`, mesmo que o pai tenha escrito bytes sem BOM.** Reproduzido em
  isolamento: um script trivial que so copia `stdin` para um arquivo grava `EF BB BF` antes dos
  bytes reais, tanto rodando de dentro de outro `powershell.exe` quanto de um `pwsh`. Isso e' um
  artefato do HOST `powershell.exe` (Windows PowerShell 5.1) ao ler stdin redirecionado — nao
  acontece com o `agy.exe` real (executavel nativo, sem esse host no meio). **Consequencia para o
  teste:** a costura `-AgyExe agy-falso.ps1` (usada para nao gastar cota) so serve pra afirmar
  "sem BOM" quando rodada via `pwsh` (`Invoke-Pester` normal). Sob `powershell.exe` 5.1 bruto, esse
  UM caso especifico (BOM no stdin) falha por causa do host, nao do script — os outros 8 casos
  passam normalmente sob 5.1. Se algum dia o pipeline real trocar `agy.exe` por um wrapper `.ps1` em
  producao, reveja esta armadilha antes de confiar em "sem BOM" como evidencia.
- **Deadlock de pipe:** comece a leitura assincrona de stdout/stderr (`ReadToEndAsync`) **antes** de
  escrever o stdin. Com fatia grande, `agy` pode escrever no stdout enquanto o script ainda escreve.
- **Stdin em UTF-8 sem BOM:** escreva `[System.Text.UTF8Encoding]::new($false).GetBytes($json +
  "`n")` direto em `StandardInput.BaseStream`, sem passar pelo `StreamWriter` do
  `Process.StandardInput` (ele pode ter encoding com preambulo). `StandardInputEncoding` do
  `ProcessStartInfo` nao existe no .NET Framework do PS 5.1.
- **`ConvertTo-Json` do 5.1** tem teto de ~2 MB e e' lento em string grande; a fatia fica bem abaixo
  disso. Nao use `ConvertFrom-Json` no stdout inteiro: faca parse linha a linha, so das linhas
  `"event":"result"`/`"init"`.
- **`Push-Location` nao muda o cwd do filho:** use `WorkingDirectory` do `ProcessStartInfo` e confira
  `init.cwd` do ndjson quando precisar provar isso em teste.
- **Join-Path do PS 5.1 so aceita 2 segmentos** (`Path`+`ChildPath`); `-AdditionalChildPath`
  variadico e' so do PS7+. Encadeie `Join-Path (Join-Path a b) c`.
- **Here-string de aspas duplas com aspas duplas aninhadas dentro de `$()` confunde o parser do
  `powershell.exe` 5.1** ("token nao reconhecido" logo apos o fechamento) — mesmo funcionando limpo
  no pwsh 7. Prefira here-string de aspas SIMPLES (`@'...'@`) com placeholder + `.Replace()` depois.
  A mesma sequencia de caracteres (`"@`) dentro de um **comentario** `#` tambem confundiu esse
  parser nesta sessao — evite escrever `"@` literal em comentarios de arquivos `.ps1` novos.
- **`.ps1` novo com caractere > 0x7F (acento, emoji, travessao `—`) precisa nascer com BOM UTF-8.**
  Sem BOM, o `powershell.exe` 5.1 le os bytes com a codepage errada e o parser quebra em cascata
  longe do byte real — o erro reportado nao aponta pro problema. Escreva com
  `[System.Text.UTF8Encoding]::new($true)` ou pela ferramenta Edit do harness (que preserva BOM).
- **`-Skip:$variavel` do Pester so pode depender de algo resolvido na fase de DISCOVERY**, antes de
  qualquer `BeforeAll` rodar. Uma variavel setada em `BeforeAll` ainda nao existe quando `-Skip` e'
  avaliado — vira `$null` -> `$false` -> o teste roda de verdade (neste caso, gastaria cota real do
  `agy` sem opt-in). Calcule a condicao inline no proprio `-Skip:(...)`, ou use
  `Set-ItResult -Skipped -Because '<motivo>'` dentro do `It`, que roda sempre na fase certa e mostra
  o motivo no relatorio.
- Antes de commitar fixture ndjson recortado de um transcrito real: grep por `sk-`/`Bearer`/
  `api_key`/e-mail/caminho de outro repositorio. O ndjson do piloto (2026-09-14) nao tinha nenhum,
  mas o proximo pode ter diff de outro projeto colado na resposta.

### Referencia

Brief da tarefa: `D:\Claud Automations\.claude-home\plans\2026-09-15-fase3-plano-contrato.md`
(secao 0 e T1). Achado do "como o agy foi invocado no piloto": mesmo arquivo, linhas 24-43.
