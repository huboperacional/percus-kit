## A função que você vai construir pode já existir no formato do dado {#a-funcao-pode-ja-existir-no-formato-do-dado}

`tags: modelagem, feature nao construida, formato de dado, mapa, indice reverso, escopo, medir antes de construir, decisao escrita, apresentacao vs funcao`

**Contexto:** operador pede uma capacidade que o produto "não tem". O caminho reflexo é abrir frente
de modelagem — campo novo no tipo, leitor novo, tela nova, migração. Antes disso, pergunte uma coisa
barata: **o formato em que o dado já é guardado permite o que ele pediu?**

**Caso medido (2026-08-24, Paid Media).** O pedido: várias grafias (`FUN`, `FUNDO`) apontando para
um rótulo só, em vez de duas linhas soltas. Existia até o mecanismo certo com o nome certo —
`apelidos` — mas **no outro modelo** (eixos), e o tipo compartilhado dizia **por escrito** que
apelido não pertencia ao vocabulário, com justificativa boa. Estava tudo pronto para virar uma
frente de dias: mudar o tipo, mudar o resolvedor que decide a leitura de 25 clientes, reabrir uma
decisão datada.

Antes de escrever qualquer coisa, li o adaptador:

```
vocabEntriesToDict:  dict[e.value] = e.label      // mapa VALOR -> rotulo
dictToVocabEntries:  Object.entries(dict).map(...)  // volta preservando cada chave
```

O vocabulário é **um mapa indexado pelo valor**, e não havia **índice reverso por rótulo** em lugar
nenhum do repositório. ⇒ dois valores diferentes **sempre** puderam apontar para o mesmo rótulo, e
o parser lia os dois. A capacidade existia desde sempre; faltava alguém cadastrar a segunda chave.

**Resultado:** 13 grafias cadastradas em duas gravações de tela, **zero linha de código, zero
deploy** — e a frente que ia custar dias virou item de apresentação (juntar N linhas num cartão),
fora do caminho crítico.

**A separação que destrava:** quase todo pedido desses tem duas metades, e elas têm custos
diferentes em ordens de grandeza.
- **Função** — *"as duas grafias precisam ser lidas"*. Costuma depender só do formato do dado.
- **Apresentação** — *"as duas precisam aparecer na mesma linha"*. Essa sim exige modelo novo.

Quem trata as duas como uma coisa só paga o preço da segunda para entregar a primeira. Separe,
entregue a função hoje, e deixe a apresentação virar decisão própria — com o operador sabendo que
já está funcionando.

**O achado de brinde:** ao medir para decidir, contei quantos nomes reais cada grafia lê. As
grafias **cadastradas** (`FUNDO`, `MEIO`) liam **ZERO**; as que estavam na fila de "não
reconhecido" (`FUN`, 14 nomes) eram as que os nomes de verdade usavam. Vocabulário cadastrado não é
prova de vocabulário usado — **conte as ocorrências antes de tratar a lista como verdade.**

**Como aplicar**
1. Antes de abrir frente de modelagem, **leia o adaptador/serializador** do dado — a estrutura
   concreta, não o tipo declarado. Procure especificamente: é mapa ou lista? indexado por quê?
   existe índice reverso que colidiria?
2. Se a função já couber, entregue por **dado** e diga ao operador o que ficou de fora.
3. Meça as **ocorrências reais** de cada entrada da lista. Entrada com zero uso é sinal de que a
   lista descreve a intenção de alguém, não o mundo.
4. Uma decisão escrita ("isto de propósito não existe aqui") **não precisa ser reaberta** para
   entregar a função — só para entregar a apresentação. Não pague esse custo sem precisar.
