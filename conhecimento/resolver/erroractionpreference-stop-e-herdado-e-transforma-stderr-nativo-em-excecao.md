## `$ErrorActionPreference='Stop'` é herdado pelo script chamado com `&` — e transforma stderr de comando NATIVO em exceção, mesmo com `2>$null` {#erroractionpreference-stop-e-herdado-e-transforma-stderr-nativo-em-excecao}

`tags: powershell, ErrorActionPreference, Stop, comando nativo, git, LASTEXITCODE, dispatcher, hook, enforcement silencioso, PSNativeCommandUseErrorActionPreference, chamar script com &`

**Sintoma:** um script que funcionava sozinho passa a **sair 0 onde antes bloqueava**, e o único
rastro é uma mensagem do próprio script dizendo algo como *"hook crashed, allowing commit"*. Nada
mudou nele. O que mudou foi **quem o chamou**.

**Causa.** `$ErrorActionPreference` é uma variável de **escopo herdado**. Um script chamado com `&`
a partir de outro roda com a preferência do chamador. E no Windows PowerShell 5.1 (e no PS 7 com
`$PSNativeCommandUseErrorActionPreference`, que é `$true` por default), `Stop` faz **comando nativo
que escreve em stderr virar erro TERMINANTE** — inclusive com `2>$null` na linha.

O padrão que quebra é o mais comum que existe em script de automação:

```powershell
& git ls-files --error-unmatch .env 2>$null
if ($LASTEXITCODE -eq 0) { ... }     # nunca chega aqui sob Stop
```

Sob `Stop`, o `git` que reclama lança, o `catch` do próprio script engole e ele sai 0 — e quem
chamou **nem vê exceção**, porque ela foi tratada lá dentro.

**O caso medido (2026-09-12).** Um dispatcher passou a rodar 8 hooks de enforcement no mesmo
processo, com `& $script`. O dispatcher tinha `$ErrorActionPreference='Stop'` no topo — hábito bom,
e aqui foi o defeito. A/B com o **mesmo payload**, um `commit` apontando para um diretório
inexistente:

| quem chama | resultado |
|---|---|
| wrapper `.cmd` de antes (EAP default `Continue`) | `exit 2` — **BLOCK** |
| dispatcher (EAP `Stop` herdado) | `exit 0` — *"hook crashed, allowing commit"* |

Oito guardas de enforcement passaram a deixar passar, **em silêncio**, por uma linha no chamador.

**Conserto:** rebaixar a preferência **em volta da chamada**, e restaurar depois:

```powershell
$eapAnterior = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try   { & $script; $ec = $LASTEXITCODE }
finally { $ErrorActionPreference = $eapAnterior }
```

Não é "desligar a segurança": é **rodar o código chamado no runtime em que ele foi escrito**. Quem
foi escrito assumindo `Continue` tem de receber `Continue`.

**Irmão que aparece junto:** `$LASTEXITCODE` **não é zerado** entre chamadas. Um script que retorna
sem `exit` deixa intacto o código do anterior, e o chamador atribui a ele um veredito que não foi
dele. `$global:LASTEXITCODE = 0` antes de cada `&`.

**Discriminante:** você passou a chamar, **do mesmo processo**, código que antes rodava em processo
próprio? Então três coisas herdadas mudam por baixo e nenhuma delas aparece no diff do código
chamado: `$ErrorActionPreference`, `$LASTEXITCODE` e `[Console]::In`. A pergunta que resolve é
*"em que runtime este script foi escrito?"* — e não *"o que ele faz?"*.

**Como este foi pego:** review cross-provider, que **reproduziu A/B** em vez de apontar o risco. A
suíte estava verde com o bug: todos os testes rodavam contra um repositório válido, onde o `git` não
tem por que reclamar. Ver [[caso-ancora-da-ausencia-passa-por-merito-do-bug]] — o teste passava por
um motivo diferente do que ele afirmava medir.
