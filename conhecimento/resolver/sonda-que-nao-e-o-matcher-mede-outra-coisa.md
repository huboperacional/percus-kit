## Sonda que não é o matcher mede outra coisa — e a copy nasce mentindo {#sonda-que-nao-e-o-matcher-mede-outra-coisa}

`tags: matcher, sonda, unicidade, casabilidade, copy derivada, FR-8.1, card de escolha, contencao, normalizacao, sufixo de parcela, espelho de logica, oferta condicional`

**Contexto:** um card só deve oferecer "responda com o nome" quando o nome **realmente escolhe um**.
Para decidir isso na hora de montar o card, escreve-se uma **sonda**: uma função que pergunta *"se a
pessoa digitasse este nome, ela escolheria UM?"*. Se a sonda não usar **exatamente o matcher que vai
resolver**, ela mede outra coisa — e a copy nasce prometendo o que o resolvedor recusa.

**As duas formas de errar, e as duas aconteceram (2026-08-21 e 2026-08-22):**

**(1) Sondar a dimensão errada.** A 1ª versão perguntava *"o matcher aceitaria este nome?"* —
**casabilidade**. A pergunta certa é *"este nome escolhe UM?"* — **unicidade**. Com N parcelas da
mesma compra, as descrições diferem só pelo sufixo `(n/N)`: o nome casa com **todas**, o resolvedor
não desempata, e a resposta cai no rodapé pedindo o número. O card mesmo assim dizia *"ou o nome"* — e
o nome que ele imprimia no próprio TÍTULO era justamente o que não funcionava.

**(2) Sondar com a string errada.** A versão seguinte já media unicidade, mas perguntava usando a
**descrição inteira** (`tv (1/5)`), que casa **só consigo mesma**: unicidade perfeita, resposta
errada. O usuário não digita `tv (1/5)`, digita `tv` — e o resolvedor casa por **contenção**
(`texto in rotulo`), então `tv` cabe nas cinco e devolve AMBÍGUO. O teste pegou; a leitura do código
não teria pegado.

**A regra, em uma linha:** a sonda tem de usar **a mesma normalização, o mesmo casamento e a mesma
string que o usuário digitaria** — quaisquer três diferentes já bastam para divergir.

```python
def aceitaNome(alvos) -> bool:
    rotulos = [normalizar(a.descricao) for a in alvos]
    # o que a pessoa DIGITA, não a descrição inteira
    nomes = [normalizar(semSufixoParcela(a.descricao)) for a in alvos]
    # mesmo casamento do resolvedor: contenção
    return all(nome and sum(1 for r in rotulos if nome in r) == 1 for nome in nomes)
```

**A regra de higiene que faltava:** se a sonda **espelha** a lógica do resolvedor à mão, ela vai
divergir na primeira mudança dele. Duas defesas, e as duas valem:
- **Delegar** ao matcher real sempre que der (chamar a mesma função, não reimplementar).
- Quando o espelho é inevitável, um **teste de paridade parametrizado** que afirma, nos DOIS sentidos:
  se a sonda LIBEROU, cada nome escolhe a sua linha; se ela RECUSOU, existe pelo menos um nome que
  não escolhe. Sem o segundo ramo, uma recusa gratuita passa despercebida — e recusa gratuita é
  capacidade escondida, o outro lado do mesmo defeito.

**Cenários que precisam estar no parametrize** (todos morderam de verdade): itens da mesma compra com
nome curto e com nome longo; descrições distintas; **um nome contido no outro** (`Fone` e
`Fone Retro` — nomes distintos, mas ambos casam com as duas descrições); e homônimos exatos.

**Sintoma no campo:** o card oferece o nome, a pessoa responde o nome, e volta o reprompt pedindo o
número. Ninguém abre chamado para isso — parece que "o bot não entendeu".

**Ver também:** [[alargar-matcher-de-guarda-troca-miss-por-alvo-errado]] ·
[[estado-compartilhado-por-dois-emissores-vaza-capacidade]] ·
[[trava-por-substring-morre-no-delimitador]]
