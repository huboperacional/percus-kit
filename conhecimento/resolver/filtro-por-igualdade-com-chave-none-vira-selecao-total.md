## Filtro `campo == chave` cujo contrato é EXCLUIR vira SELEÇÃO TOTAL quando a chave buscada é `None` {#filtro-por-igualdade-com-chave-none-vira-selecao-total}

`tags: python, None, null, filtro, comparacao por igualdade, sentinela, contrato invertido, coluna nullable, falso agrupamento, docstring que mente, defeito de produto, mensagem enganosa, controle positivo, R23`

**Sintoma:** uma função de filtro documenta que "item sem X fica FORA", e faz exatamente isso o
tempo todo — até que alguém a chame **buscando por X ausente**. Aí ela devolve, num grupo só,
precisamente os itens que ela existia para excluir. Nada estoura: o resultado é uma lista
plausível, e o defeito aparece longe dali, com outro nome.

**A causa:** `None` no domínio não é dado, é **sentinela** — "este item não tem X". Quando a
chave buscada também é `None`, `item.x == chave` vira `None == None` → `True`. O filtro deixa de
particionar e passa a agrupar. A linha parece certa na leitura porque **está** certa para todo
valor real; ela só se inverte no valor que ninguém escreve caso de teste para.

```python
# contrato declarado no docstring: "item sem recurso fica FORA da fila"
return sorted(e for e in etapas
              if e.recursoId == recursoId and e.inicioPrevisto is not None)

# chamada com recursoId=None -> devolve TODAS as etapas sem recurso, de donos diferentes,
# como se fossem uma fila só, disputando um recurso que não existe
```

**Como o defeito se disfarça:** o sintoma visível costuma ser uma **mensagem que afirma o que não
há**. No caso medido (Empresa Milionária, 2026-09-12), a etapa sem recurso nenhum recebia o
conflito *"recurso sem jornada cadastrada"* — frase que pressupõe um recurso. Quem for consertar
"a mensagem" conserta o sintoma e deixa o agrupamento falso de pé. O mesmo item aparecia em dois
lugares da tela ao mesmo tempo, cada um com uma explicação diferente, e **foi isso que denunciou**
— nenhum teste olhava para lá.

**Correção:** teste a ausência **antes** da igualdade, na própria função que promete excluir:

```python
if e.recursoId is not None and e.recursoId == chave
```

Faça no **sumidouro** (a função que declara o contrato), não só no chamador: assim toda porta de
entrada fica coberta, inclusive as que ainda não existem. No caso medido havia duas portas — o
gatilho sem recurso e um caminho de cascata que escolhia o item sem exigir a chave.

**Como provar, e o que não vale como prova:**

1. Meça a função **direto**, fora do fluxo: com a chave `None` ela tem de devolver vazio. Medir
   pelo comportamento de ponta prova menos e demora mais.
2. Ponha **controle positivo ao lado**: com a chave real, o grupo certo ainda é montado. Sem ele,
   um `return []` incondicional deixa a asserção verde — ver
   [[controle-positivo-que-nao-atravessa-o-ponto-fragil]].
3. Se você também adicionar a guarda no chamador, passam a existir **duas guardas para o mesmo
   defeito** e o teste de ponta fica verde sabotando qualquer uma delas. Sabote uma de cada vez e
   escreva no teste qual guarda ele realmente prende —
   [[duas-guardas-que-se-cobrem-mutuamente-passam-verdes-sobre-codigo-quebrado]].

**Onde mais isto mora:** qualquer `get(chave)`, `dict[chave]`, `filter(campo == chave)` ou índice
sobre coluna **nullable**. Em SQL a armadilha é espelhada e de sinal contrário — lá `x = NULL`
nunca casa, e é a asserção que deixa de disparar em vez do filtro que passa a casar tudo:
[[assercao-de-teste-com-comparacao-nula-nao-dispara]]. Guardar as duas juntas ajuda: a mesma
sentinela produz falso-positivo numa linguagem e falso-negativo na outra.
