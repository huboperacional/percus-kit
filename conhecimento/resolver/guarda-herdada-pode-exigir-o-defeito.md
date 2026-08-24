## A guarda herdada pode EXIGIR o defeito {#guarda-herdada-pode-exigir-o-defeito}

`tags: testes, guardas, fork, heranca, verde falso, literal, classe vs lista`

**Classe:** testes / fork de produto
**Medido em:** 2026-08-24, Empresa Milionária — **três vezes no mesmo dia**, em três áreas
diferentes

**O padrão**

Um teste que existe para impedir um defeito passa, com o tempo, a **afirmá-lo**. Não por
sabotagem: por herança, ou por ter sido escrito a partir do estado atual em vez do requisito.

Quando isso acontece, o defeito fica com **proteção dupla**: ele está no código *e* há um teste
verde jurando que assim é o certo. Quem o corrigir quebra a suíte e, na dúvida, desfaz o conserto.

**As três formas, todas reais**

**1. O fork trouxe o valor do produto de origem.**

```python
assert "19,90" in facts or "167,16" in facts   # a tabela de precos do OUTRO produto
```

O `PRODUCT_FACTS` anunciava o preço da Família Milionária, e a guarda **exigia** que ele
estivesse lá. O conserto foi comparar com a fonte da verdade (`app/core/planos.py`), não com um
literal.

**2. O teste foi escrito a partir da tela, não do requisito.**

```js
expect(texto).toContain('Anthropic')
expect(texto).toContain('contratado, ainda não ativado')
```

Escrito no mesmo dia, em boa fé, para travar um texto legal recém-corrigido. Quando o operador
respondeu que **não havia contrato com aquele fornecedor**, a guarda passou a exigir uma
afirmação falsa num documento contratual publicado.

**3. A guarda lista os casos conhecidos em vez da classe.**

```python
JOBS_DE_PESSOA_FISICA = {"recorrencias_pf", "alerta_de_orcamento"}
```

Dois nomes, porque foram os dois que alguém viu falhar. Havia **quatro** jobs quebrados — e os
dois que faltavam só falhariam no dia 1 do mês e em 15 de dezembro. Guarda que depende de o
defeito já ter acontecido chega sempre atrasada.

**Por que passa despercebido**

O teste é **verde**. Ninguém audita teste verde. E as três formas acima produzem um verde que
parece cobertura: há uma asserção, ela é específica, ela roda.

Pior: o comentário costuma estar certo. *"Trava o preço que o bot anuncia"* descreve a intenção
com precisão — e a asserção abaixo faz o contrário.

**Como pegar**

**Pergunte da asserção, não do teste:** *se o produto estivesse correto, esta linha passaria?*

- Literal de valor de negócio (preço, nome, percentual) numa asserção é suspeito. Compare com a
  **fonte da verdade**, para que os dois andem juntos quando a decisão mudar.
- Lista de nomes é suspeita. Pergunte qual é a **classe** e se dá para derivá-la (do metadata, da
  migration, do registro de rotas). Se a classe não for derivável, a lista precisa de um teste
  irmão que reprove quando ela ficar desatualizada.
- `toContain` de texto de produto é suspeito depois de qualquer decisão de conteúdo — o texto
  muda por decisão de negócio, e o teste não fica sabendo.

**Ao corrigir um defeito, procure o teste que o protege.** Se a suíte ficar vermelha por causa da
correção, a pergunta não é *"como conserto o teste"*, é *"este teste estava afirmando o defeito?"*.

**O caso especial que vale nomear**

Quando a guarda é invertida (passa a **proibir** o que exigia), escreva no próprio teste o que ela
exigia antes e por quê. Sem isso, alguém restaura a asserção antiga daqui a três meses achando que
está consertando uma regressão.

**Relacionados**

- [[a-sabotagem-prova-o-que-voce-imaginou]] — sabotagem não pega isto: o teste está verde e a
  sabotagem o deixaria vermelho, que é o resultado "esperado"
- [[comentario-sobre-a-regra-desliga-a-regra]]
- [[alargar-matcher-de-guarda-troca-miss-por-alvo-errado]]
