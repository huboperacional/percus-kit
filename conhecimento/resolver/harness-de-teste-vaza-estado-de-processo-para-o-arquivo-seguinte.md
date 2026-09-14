## Harness de teste vaza estado de PROCESSO para o arquivo seguinte: `$null` que cria variável vazia e `AfterAll` duplicado que some calado {#harness-de-teste-vaza-estado-de-processo-para-o-arquivo-seguinte}

`tags: teste, pester, isolamento, estado de processo, variavel de ambiente, SetEnvironmentVariable, NullString, null vira string vazia, HOME, HOME vazio, lancador, git bash, jq, command not found, 127, AfterAll, BeforeAll, bloco duplicado, rodar-suite, balde, ordem dos arquivos, passa isolado falha na suite, verde num runner vermelho no outro, codepage, 65001, OutputEncoding, pwsh, alias diff`

**Sintoma:** o teste passa rodado sozinho, passa com o arquivo dele inteiro, e falha na suíte. A falha
segue o **balde** do `rodar-suite`, não o arquivo: só cai quando um outro arquivo específico roda antes,
no mesmo processo. E pode depender do runner — o mesmo commit verde pelo Git Bash e vermelho por um
pwsh aberto de outro jeito.

**Caso medido (2026-09-13, 6.53.0, antes do push):** suíte **711/721** rodada pelo PowerShell; na véspera,
**721/721** pelo Git Bash. As 2 falhas eram os testes ponta a ponta do `cross-claude.sh`
(`faixa-regras-derivada` e `regras-do-canon-injetadas`) com corpo HTTP **vazio**: o wrapper nem chegou ao
POST. Cada hipótese fácil caiu por medição, não por argumento:

| Hipótese | Por que caiu |
|---|---|
| pwsh sem `bash` no PATH | os dois arquivos isolados passam **nos dois** ambientes (33/33) |
| carga ou timeout | porta 0 (sem colisão), espera de 60 s, e a falha repetiu com a máquina ociosa |
| lançamento oculto do `rodar-suite` | reproduzido com `-WindowStyle Hidden -NonInteractive`: 33/33 |

O que era: os dois arquivos estavam nos **dois únicos baldes** que também tinham um teste de paridade
`.sh` rodando antes. A bisseção [paridade → vítima] reproduziu. Uma sonda que roda o wrapper **guardando a
saída** em vez de `Out-Null` mostrou `jq: command not found`, exit 127, e um diff do ambiente do processo
entre um arquivo e o seguinte mostrou `HOME : <ausente> -> ""`.

**Faceta 1 — no pwsh, `SetEnvironmentVariable(k, $null)` NÃO remove: cria `k` vazia.** O binder do
PowerShell converte `$null` em `""` num parâmetro `string`. Medido:

| Restaurar com | Variável depois |
|---|---|
| `$null` guardado numa hashtable | presente, `len=0` |
| `$null` literal | presente, `len=0` |
| `[NullString]::Value` | ausente |
| `Remove-Item Env:\k` | ausente |

O harness fazia o "salva e devolve" que parece à prova de vazamento: `$antigos[$k] =
GetEnvironmentVariable($k)` antes e `SetEnvironmentVariable($k, $antigos[$k])` no `finally`. Para variável
que **existia**, funciona. Para a que **não existia**, deixa uma vazia. Pelo Git Bash o `HOME` sempre
existe e nada vaza — daí o 721/721. Num pwsh sem `HOME`, o cenário "sem jq" (que troca `HOME`) deixava
`HOME=""`; o lançador `Git\bin\bash.exe` parava de pôr `%HOME%\bin` no PATH (item 3 de
[[teste-de-hook-no-windows-mede-o-ambiente-do-runner-e-nao-o-do-harness]]), o `jq` sumia, e o
`cross-claude.sh` do **arquivo seguinte** saía 127. Separado por experimento: com `HOME` ausente e as
`PERCUS_*` vazias o `jq` aparece; com `HOME=""`, não.

**Faceta 2 — com dois `AfterAll` no mesmo bloco, o Pester 5 (5.7.1) roda só o último.** O primeiro some
calado: sem erro, sem aviso, suíte verde. Em `regras-do-canon-injetadas.tests.ps1` o que devolvia a
codepage era o primeiro, e o console ficava em **65001** para os arquivos seguintes do balde — que
passavam a rodar na codepage do terminal do agente, e não na do harness. É a faceta 5 do verbete vizinho
voltando pela porta de trás.

**Por que o Pester não protege:** ele isola **escopo de script** por arquivo. Variável de ambiente,
`[Console]::OutputEncoding` e cwd são do **processo**, e cada balde do `rodar-suite` roda vários arquivos
em sequência num pwsh só.

**Conserto:**
- Restaurar com helper que distingue ausência — `Restore-EnvDoProcesso` em
  `plugin/percus-review/tests/_dispatch-paridade.ps1`: `[NullString]::Value` quando o valor antigo é
  `$null`, o valor quando não é.
- Um `AfterAll` por bloco, com tudo dentro.

**Guardas:**
- `dispatch-paridade-harness.tests.ps1` mede **presença** (`GetEnvironmentVariables().Contains`), não valor:
  `""` e `$null` passam os dois em `BeNullOrEmpty`, e a diferença entre eles é o defeito. O caso do `HOME`
  remove a variável antes, então mede igual em qualquer runner.
- `pester-blocos-unicos.tests.ps1` varre por AST todos os `*.tests.ps1` atrás de `BeforeAll`, `AfterAll`,
  `BeforeEach` ou `AfterEach` repetido no mesmo nível, com autoteste do detector.

**Não consertado, declarado:** o `Invoke-Runtime` ainda **zera** as variáveis da base com `$null` durante
a chamada. O dispatcher vê `PERCUS_CANON_DIR=""`, e não ausente como o comentário do harness diz
("apagado"). Para os checks de hoje dá no mesmo (`if ($env:X)`, `[ -n "$X" ]`) e não vaza depois da
chamada; vira diferença se algum check passar a distinguir vazio de ausente.

**Discriminante:** passa isolado e falha na suíte? Antes de desconfiar do teste que falha, **liste o que
rodou antes dele no mesmo processo** e tire um diff do estado do processo (env, cwd, codepage) entre um
arquivo e o seguinte. Cuidado com o instrumento: uma função chamada `Diff` perde para o alias `diff` →
`Compare-Object`, devolve vazio, e o vazio parece "nada mudou".

**Relacionado:** [[paridade-testada-no-caso-facil-nao-e-paridade]] · [[fix-commit-sem-re-rodar-suite]].
