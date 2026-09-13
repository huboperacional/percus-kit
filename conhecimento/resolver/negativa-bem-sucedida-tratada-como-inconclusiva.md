## Negativa bem-sucedida tratada como inconclusiva — o `catch` vazio e o `if` que não casa desembocam no mesmo lugar {#negativa-bem-sucedida-tratada-como-inconclusiva}

`tags: gate, fallback, controle de fluxo, catch vazio, falha graceful, degradacao, R11, pre-commit-check, hash de diff, falso verde, buraco calado, diagnostico`

**Sintoma:** um gate tem exatamente a verificação certa, ela roda, responde *"não"* — e o gate libera
assim mesmo. Ninguém percebe, porque o caminho degradado responde "ok" com a mesma cara do caminho
bom.

**A forma, e ela cabe em cinco linhas:**

```powershell
try {
    $resposta = medir-de-verdade
    if ($resposta) { exit 0 }      # cobre -> libera
} catch { }                        # nao consegui medir
# ...cai no criterio fraco (relogio, heuristica, default permissivo)
```

O `catch` vazio e o `if` que não casa **desembocam no mesmo ponto**. O código não distingue
**"não consegui perguntar"** de **"perguntei e a resposta é não"**, e trata as duas como
inconclusivas. Mas a segunda **não é** inconclusiva: é uma medição bem-sucedida — e é exatamente o
sinal que o gate foi construído para capturar. O sistema descarta o seu melhor dado em favor do pior.

**O caso medido (2026-09-12, `pre-commit-check.ps1` do gate da R11).** O hook faz a coisa certa:
calcula `sha256(git diff HEAD)` e procura `.deepseek/reviews/d-<hash>.jsonl`; se acha, o review
cobre exatamente aquele código e libera **sem olhar o relógio**. O comentário no próprio arquivo
declara o princípio: *"Tempo nunca foi proxy de 'isto foi revisado'"*.

Quando o marcador **não** existe — isto é, quando o gate **prova** que nenhum review cobriu este
diff — ele cai no critério antigo: *existe algum review com menos de 5 minutos?* Em árvore
compartilhada isso passa com o review de **outra janela, sobre outro diff**. Medido: o
`latest.jsonl` continha `scope: "INDICE.md (1 linha)"` enquanto uma janela se preparava para
commitar **845 linhas**.

**Por que a intenção era boa e o resultado não.** O comentário diz *"Falha graceful: qualquer erro
aqui cai no caminho antigo"* — e para **erro** isso está certo: se o hash não pôde ser computado,
não dá para concluir nada. O defeito é que `Test-Path` devolvendo `$false` **não é erro**. A
degradação graciosa foi escrita para a indisponibilidade da medição e acabou cobrindo também o
resultado dela.

**Discriminante:** procure todo ponto onde um **caminho de erro** e um **resultado negativo**
compartilham destino. Perguntas que revelam:

- *"Se a verificação rodar e responder NÃO, o que acontece?"* Se a resposta for a mesma de *"se a
  verificação explodir"*, você tem o buraco.
- *"Qual o valor de `$ok` depois do `catch`?"* Se for indistinguível de "verificou e deu negativo",
  o `catch` está engolindo informação, não erro.

**Conserto:** separe os três estados — **cobriu**, **não cobriu**, **não consegui verificar** — e dê
destino diferente a cada um. É a mesma forma de três estados do `spec-analyze-check` (sem analyze /
analyze de versão anterior / coberta). Na prática:

```powershell
$medido = $false
try { $resposta = medir-de-verdade; $medido = $true } catch { }
if ($medido -and $resposta)      { exit 0 }   # cobriu
elseif ($medido)                 { bloqueia-ou-avisa-dizendo-o-porque }
else                             { fallback fraco, que agora e so pra erro }
```

**Armadilha do conserto — não faça o óbvio sem olhar a granularidade.** No caso da R11, "se mediu e
deu negativo, bloqueia" **trava a árvore compartilhada**: `git diff HEAD` é da árvore inteira, então
qualquer janela editando qualquer arquivo invalida a review de todo mundo, e o desfecho previsível é
o escape virar rotina (a lição do teto do `CONTEXT.md`). O problema, quando isso acontece, não é o
fallback existir — é a **pergunta ser de granularidade errada**: perguntava-se sobre a árvore
quando o que importa é *o que este commit leva*. Corrigir o destino da negativa sem corrigir a
pergunta troca um falso verde por um falso vermelho.

**Nota de método:** o diagnóstico que circulou primeiro era *"o gate só olha o relógio, nunca
pergunta se o review cobre o código"* — descrição correta do **efeito** e errada da **causa**, que
levaria a reimplementar um mecanismo que já existe e funciona. Antes de consertar um gate que
"não verifica", leia se ele verifica e **o que ele faz com a resposta**.

Ver [[paridade-testada-no-caso-facil-nao-e-paridade]] (o que você não exercitou, você não verificou)
e [[retrato-de-arvore-compartilhada-vence-em-minutos]].
