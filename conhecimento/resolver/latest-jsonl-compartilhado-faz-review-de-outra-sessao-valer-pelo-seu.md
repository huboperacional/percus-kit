## `latest.jsonl` é um arquivo só para todas as sessões: o review da sessão vizinha satisfaz o gate R11 do SEU commit {#latest-jsonl-compartilhado-faz-review-de-outra-sessao-valer-pelo-seu}

`tags: R11, percus-review-auto, latest.jsonl, pre-commit-check, duas sessoes, corrida, review vazio, roteador, staged, gate satisfeito por engano`

**Sintoma:** você roda o review, ele responde `Sem findings criticos`, o `pre-commit-check` deixa
commitar — e o review **não olhou o seu diff**. No caso medido ele tinha revisado *uma linha* de
`conhecimento/resolver/INDICE.md` de **outra sessão**.

### Uma hipótese que NÃO se sustentou, registrada porque quase virou verbete

A primeira versão deste verbete afirmava um segundo defeito: *"o roteador conta só o unstaged, então
trabalho staged-first cai no review barato"*. A observação que a originou foi real —

```
[percus-review-auto] decisao: deepseek (sensitive=False, from_deepseek=False, 0 arquivo(s))
```

— com 16 arquivos no index, `plugin/percus-review/hooks/` inteiro entre eles. **Mas a explicação
estava errada, e a sessão vizinha a derrubou com duas evidências.** `review-router.ps1:58` faz

```powershell
$files = @(Invoke-GitSafe diff --name-only --cached) + @(Invoke-GitSafe diff --name-only) | Sort-Object -Unique
```

e, medindo na mesma árvore poucos minutos depois, com os mesmos 16 arquivos ainda staged:

```
[router] decisão: council (sensitive=True, council=True, 16 arquivo(s))
```

Kit e cache instalado com a linha **idêntica**. O roteador conta staged e detecta pasta sensível —
a alegação era falsa.

**O `0 arquivo(s)` continua sem explicação**, e fica assim escrito. A causa mais plausível é estado
transitório do index enquanto outra sessão mexia na mesma árvore, mas **não foi reproduzido**, e
inventar um mecanismo para fechar a história seria pior que deixar o buraco declarado: viraria uma
segunda afirmação sobre o repositório que ninguém mediu. Se reaparecer, o que vale medir é
`git diff --name-only --cached` no mesmo instante da chamada.

**A lição que sobra é sobre método, não sobre o roteador:** uma observação real (`0 arquivo(s)`) mais
uma explicação plausível (`conta só unstaged`) quase viraram um verbete que mandaria todo leitor
futuro para o lado errado. O que separou as duas foi alguém ler a linha 58.

### O defeito que É real: `latest.jsonl` é um arquivo só, e vence quem escreveu por último

`.deepseek/reviews/latest.jsonl` não tem escopo de sessão. Duas sessões no mesmo repo escrevem no
mesmo caminho, e o `pre-commit-check` (R11) só pergunta **"existe review com menos de 5 min?"** —
nunca **"esse review olhou o que eu estou commitando?"**.

Resultado medido: a sessão vizinha revisou 1 linha de índice, gravou o `latest.jsonl`, e o gate
teria liberado um commit de **846 linhas de dispatcher de hooks** como se estivesse coberto.

**O gate mede a IDADE do review, não o ESCOPO dele** — e idade é exatamente a propriedade que o
review de outra pessoa também tem.

**Discriminante:** o artefato de review guarda um campo `scope`. Antes de confiar que o R11 está
satisfeito, leia-o:

```powershell
(Get-Content .deepseek/reviews/latest.jsonl -Raw | ConvertFrom-Json).scope
```

Se o `scope` não descreve o **seu** diff, o gate está verde por acidente. Sintoma que denuncia de
longe: `diff_lines` de um dígito num commit grande.

**Contorno enquanto não houver conserto:** peça o review direto da perna que lê o repositório
(subagente Cross-Claude sobre `git diff --cached`) em vez de confiar no wrapper, e confira o `scope`
do artefato antes de commitar.

**Consertos plausíveis, em ordem de custo:** (a) `latest.jsonl` virar `latest-<pid ou id de sessão>.jsonl`, e o gate procurar o da sessão
corrente; (b) o gate comparar o `scope` gravado com o que está staged, e recusar review cujo escopo
não cobre o commit — que é o único dos dois que fecha o buraco em vez de estreitá-lo.

Mesma família de [[review-auto-grava-relativo-ao-cwd]]: ali o artefato era gravado no
lugar errado, aqui é gravado no lugar certo pela sessão errada. Nos dois casos o gate lê um arquivo
que **existe** e conclui, disso, que o trabalho **foi feito** — a distância entre presença e
conteúdo que [[auditoria-de-enforcement-por-numero-citado-conta-gate-que-nao-existe]] descreve numa
camada acima.

### O irmão maior: `INDICE.md` não é commitável por uma sessão só

Descoberto na mesma sessão, e é a razão de este verbete ter demorado a entrar no repo.

`conhecimento/resolver/INDICE.md` é **gerado a partir do disco inteiro**, e a suíte tem uma trava —
*"o INDICE do canon de verdade está EM DIA"* — que exige que o arquivo commitado seja **idêntico**
ao que o gerador produz. Com duas sessões trabalhando na mesma árvore, isso vira um impasse:

| o que você faz | o que acontece |
|---|---|
| regenera e commita | o índice referencia verbetes **untracked** de terceiros → índice quebrado em clone limpo |
| poda as linhas alheias | a trava "EM DIA" reprova, porque o gerador incluiria aquelas linhas |
| não mexe no índice e commita só o seu verbete | o gate de conhecimento barra: *"verbete AUSENTE do INDICE"* |

Não há terceira opção: **o índice só pode ser commitado por quem tem a árvore inteira**. Nenhuma das
travas está errada — cada uma protege um defeito real. O que falta é elas saberem que a árvore pode
ter dono compartilhado.

**Contorno:** verbete escrito com a árvore compartilhada **espera**. Commite o resto do trabalho,
deixe o `.md` em disco, e feche o par verbete+índice quando o disco estiver limpo de verbete alheio.
É lento e é correto — commitar trabalho de terceiro junto, ou afrouxar a trava, sai bem mais caro.

**E não há quem "destrave" por você.** Esta base de conhecimento mora numa árvore que TODO projeto
escreve, então os verbetes soltos costumam ser de uma terceira janela que nem sabe do impasse.
Pedir a alguém que commite os arquivos dele para você poder commitar o seu apenas transfere o
problema: agora ELE assina verbete de terceiro.

**Sinal de que você está neste caso:** `git diff --numstat` no índice mostra **mais linhas do que
verbetes que você escreveu**.
