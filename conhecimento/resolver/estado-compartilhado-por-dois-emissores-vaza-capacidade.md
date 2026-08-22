## Estado de sessão compartilhado por DOIS emissores vaza a capacidade que só um deles oferece {#estado-compartilhado-por-dois-emissores-vaza-capacidade}

`tags: estado de sessao, card, menu, capacidade escondida, FR-8.1, escrita em lote, bot, whatsapp, dois emissores, resolvedor unico, reuso de estado, falha fechada, aceitaLote, oferta implicita`

**Contexto:** dois cards diferentes abrem o **mesmo estado de sessão** e são resolvidos pelo **mesmo
resolvedor** — reuso que parece boa arquitetura e normalmente é. Só que um dos cards **imprime uma
opção extra** que o outro não imprime. Como o resolvedor é um só, a opção passa a valer nos **dois**,
inclusive naquele que nunca a ofereceu.

**O caso medido (2026-08-22):** o card de baixa de contas oferecia `todas` ("dar baixa em todas"). O
menu de desambiguação do portão de escrita abria o **mesmo** estado `confirmando_pagamento_baixa`
para tornar-se respondível por número — decisão anterior, correta e testada. Resultado não previsto:
responder `todas` ao menu do portão **baixou 3 parcelas de uma vez, R$ 300**, sem nenhuma
confirmação. Nada no card sugeria que aquilo existisse.

**Por que é pior que "capacidade escondida" comum:**

1. **É alcançável de verdade, não por adivinhação.** O próprio produto ENSINA a palavra noutro card.
   Quem aprendeu `todas` numa tela digita `todas` na outra — é transferência de aprendizado, o
   comportamento mais previsível que existe.
2. **Contorna a regra que protege o lote.** A spec exigia que lote pedido de propósito SEMPRE passasse
   por confirmação (card de "vou marcar N como pagas, confirma?"). Aqui o lote entrava por um estado
   que a regra não revisava, e aplicava direto.
3. **A lista pode ser a do caso "não sei qual você quis dizer"** — isto é, exatamente o caso em que a
   pessoa **não nomeou alvo nenhum**. `todas` ali escreve em tudo que estava em aberto.

**Por que ninguém viu antes:** os testes de cada card cobriam **o card que os emitiu**. O card A
testava que `todas` funciona (verdade); o card B testava número e nome (verdade). Nenhum teste
perguntava *"o que acontece se eu responder ao card B uma palavra que só o card A oferece?"* — a
pergunta cruzada não pertence a nenhum dos dois arquivos de teste.

**Diagnóstico (a ordem que funciona):**
1. Liste os estados de sessão com **mais de um emissor** (`grep` pelo nome do estado; se aparecer em
   dois lugares que montam card, é candidato).
2. Para cada emissor, extraia o conjunto de respostas que o card **imprime**.
3. Para o resolvedor, extraia o conjunto que ele **aceita**.
4. A diferença `aceita − imprime`, por emissor, é a capacidade vazada. Se ela ESCREVE, é incidente.

**Correção — declarar a permissão no estado, e falhar FECHADO:**

```python
# emissor que IMPRIME a opção declara que ela vale
ctx = {..., "aceitaLote": True, **estado}

# resolvedor: default False, não True
aceitaLote = bool(ctx.get("aceitaLote", False))
if textoLower in ("todas", "todos", "tudo") and not aceitaLote:
    return recusaHonesta(ctx)
```

**Por que `False` como default, e não `True`:** pendências abertas ANTES do deploy não têm a chave.
Com default `True` o buraco fica aberto na janela de transição — exatamente quando ninguém está
olhando. Com `False`, o custo é um turno a mais para quem tinha um card que oferecia o lote. Entre
errar para menos e errar para mais numa **escrita em massa**, o barato é recusar.

**Por que a flag é explícita e não derivada:** dá vontade de inferir ("se o contexto tem a chave X,
então oferece lote"). Inferência é como o buraco nasceu — a permissão estava implícita no fato de os
dois estados terem o mesmo nome. Quem IMPRIME, DECLARA.

**A copy da recusa não pode inventar uma saída.** A tentação é dizer *"para dar baixa em tudo, mande
`paguei tudo`"*. Meça antes: naquele caso o caminho de lote existia só para outro tipo de objeto e
dependia de um classificador probabilístico — ensinar a frase seria prometer o que o matcher não faz,
dentro do conserto desse mesmo defeito. A copy honesta diz o que é verdade: *"aqui é uma de cada
vez"*.

**Prova ao vivo, não só unitária.** O teste de unidade prova a regra; ele não prova que o card que
ensina a palavra e o card que a recusa convivem em produção. Um caso de smoke que responde `todas` ao
menu errado e afirma **zero escrita + a copy da recusa presente** (prova positiva na mesma rodada)
custa dois turnos e fecha o assunto.

**Ver também:** [[promessa-e-decisao-separadas]] ·
[[sonda-que-nao-e-o-matcher-mede-outra-coisa]] · [[smoke-verde-pode-nao-ter-exercitado-a-guarda]]
