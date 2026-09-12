## Hook que sai na primeira linha não é grátis: ~420 ms cada, e a cadeia multiplica {#cadeia-de-hooks-cobra-420ms-por-hook-mesmo-em-no-op}

`tags: hook, performance, powershell, cmd, dispatcher, PreToolUse, PostToolUse, hooks.json, latencia, orcamento de hooks, context-budget-guard, spawn de processo`

**Sintoma:** ninguém reclama, e é esse o problema. A sessão fica "meio lenta" e a explicação natural
é o modelo, a rede, o tamanho do contexto. Não é: é a cadeia de hooks cobrando pedágio em **todo**
comando.

**A causa é estrutural, não um hook mal escrito.** Cada hook Percus é um `.cmd` que faz
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File x.ps1`. O custo é o **startup do Windows
PowerShell 5.1**, e ele é pago antes de a primeira linha do `.ps1` rodar. Um hook que faz
`if ($command -notmatch 'git.*commit') { exit 0 }` na linha 1 custa exatamente o mesmo que um que
faz trabalho de verdade.

**Medido em 2026-09-12** (todos os hooks em no-op, isto é, no caminho em que "não fazem nada"):

| O que | Custo |
|---|---|
| 1 hook saindo na primeira linha | **~420 ms** |
| cadeia `PreToolUse:Bash\|PowerShell`, 8 hooks empilhados | **3 357 ms em TODO comando Bash**, inclusive `echo ola` |
| `context-budget-guard` em `PostToolUse` com matcher `""` | **477 ms por tool call** — `Read`, `Grep`, `Edit`, tudo |

Uma sessão de 200 tool calls paga ~95 s só no último. E o matcher vazio é o detalhe que engana: ele
parece "cadeia de 1, barata" e é o caminho mais quente que existe.

**O fato que torna o conserto barato — e que não é óbvio:** `exit` dentro de um `.ps1` chamado com
`&` a partir de outro `.ps1` **não mata o chamador**, e `$LASTEXITCODE` chega intacto. Provado:

```powershell
# filho.ps1:  Write-Host "rodou"; exit 7
# pai.ps1:
& "$PSScriptRoot\filho.ps1"
Write-Host "pai sobreviveu, LASTEXITCODE=$LASTEXITCODE"   # -> 7
```

Logo um **dispatcher** roda N hooks no mesmo processo **sem reescrever o fluxo de controle de
nenhum** — não precisa converter `exit` em `return`, não quebra os testes que invocam hook isolado.
O único obstáculo é stdin, que só pode ser lido uma vez (todo hook faz `[Console]::In.ReadToEnd()`):
o dispatcher grava o payload num arquivo e cada hook passa a ler `PERCUS_HOOK_STDIN_FILE` se setado,
senão `Console.In`. Uma linha por hook.

**Triagem antes de subir PowerShell.** `cmd.exe` custa ~40 ms contra os ~420 ms do PowerShell, e sabe
fazer `findstr`. Um `.cmd` que despeja stdin num temp (`more > %TMPF%`) e roda **um**
`findstr /L /G:gatilhos.txt` com a **união** dos gatilhos de todos os checks decide em ~61 ms se vale
subir. Medido: **3 357 ms → 61 ms** no caminho comum.

**Cuidado que decide se isso vira conserto ou buraco novo:** a triagem em `cmd.exe` tem que ser uma
**sobre-aproximação** — ela só pode responder *"ninguém poderia disparar"*, nunca *"qual check
roda"*. Se ela virar a fonte de verdade do roteamento, um gatilho esquecido na união suprime um hook
**sem ninguém notar** — a mesma classe de
[[categoria-nova-esquecida-em-lista-de-enumeracao]], enforcement que enumera e deixa buraco calado. A decisão
precisa de qual check roda fica na camada PowerShell, onde é testável, e a suíte prova duas coisas:
que o gatilho de cada check **alcança** o check, e que o conjunto de gatilhos de cada check está
**contido** na união.

**Discriminante — quando isto te morde:** você está prestes a adicionar um hook a uma cadeia que já
tem outros. Antes de escrever, **conte quantos já estão no matcher e multiplique por 420 ms**. O
"orçamento de hooks" de [[regra-declarada-automatica-sem-hook-e-decoracao]] — gate que dispara em
massa vira escape declarado — tem uma segunda metade que era invisível: mesmo o hook que **nunca**
dispara custa, e custa na frota inteira, em todo comando.

**Como medir na sua máquina:**

```powershell
$payload = '{"tool_input":{"command":"echo ola"}}'
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$payload | & "$hooks\algum-hook.cmd" 2>&1 | Out-Null
$sw.Stop(); "$($sw.ElapsedMilliseconds) ms"
```

Rode com um comando que **não** case o gatilho do hook — é o caminho que a frota paga o dia todo, e
é o que ninguém pensa em medir.
