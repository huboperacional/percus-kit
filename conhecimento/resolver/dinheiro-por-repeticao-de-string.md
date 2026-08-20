## `"100" * 3` é dinheiro por repetição de string — a mesma expressão vira aritmética ou concatenação conforme o tipo que chegou {#dinheiro-por-repeticao-de-string}

tags: dinheiro, campo nao tipado, json do modelo, llm emite string, repeticao de string, ordem de grandeza, valor 333667x, ancora de valor, coercao numerica, tool schema violado, silencioso

**Sintoma.** Um lançamento nasce com valor absurdo — `R$ 100.100.100,00` no lugar de `R$ 300,00` — e
**nada** no log denuncia. Sem exceção, sem warning. O valor passa por toda a validação a jusante
porque, formalmente, é um número válido.

**Causa.** O campo chegou como **string** onde o código esperava número, e a expressão que deriva o
total é uma multiplicação:

```python
valor = valorParcela * totalParcelas   # 100 * 3   -> 300      (aritmética)
                                       # "100" * 3 -> "100100100"  (repetição)
```

Em Python o mesmo operador faz coisas diferentes conforme o tipo do operando esquerdo. Com `int`, é
produto. Com `str`, é repetição — e o resultado ainda **parece** um número quando vira `Decimal`.

**De onde vem a string.** No caso medido, de um LLM: a tool declarava `"type": "integer"` e
`"type": "number"`, e o modelo emitiu `"3"` e `"100"` como string mesmo assim. Vale para qualquer
fronteira não tipada — JSON de webhook, CSV, query string, campo de formulário.

**Por que a guarda existente não pega.** A âncora de valor deste projeto pergunta *"o TEXTO tem
número rastreável?"* — e `"3x de 100"` tem. Ela nunca perguntou se a **conta bate**. Guarda de
rastreabilidade não é guarda de aritmética, e confundir as duas deixa a porta aberta.

**O irmão barulhento é o que engana.** A mesma falta de coerção produz, no outro campo,
`"3" > 1` → `TypeError` → extração inteira perdida. Esse dá erro e é catalogado. O silencioso mora ao
lado, não dá erro nenhum, e **mexe em dinheiro** — quem cataloga só o barulhento conserta metade.

**Conserto.**

1. **Coaja num ponto só**, logo depois do `json.loads`, e **escreva de volta no dict** — não só nas
   variáveis locais. Costuma haver mais de um leitor do mesmo dict (no caso medido, três; o terceiro
   fazia `dados["valor"] > 0` e quebrava sozinho).
2. **Valide a FORMA antes de converter.** `float()` aceita coisas que você não quer: `float("1.000")`
   devolve `1.0` sem levantar nada, e em pt-BR isso é mil — erro de 1000x na direção oposta. Só
   dígitos com no máximo um separador decimal de 1-2 casas é conversão segura; forma ambígua é
   **ilegível**, nunca chute. Ver [[parser-de-dinheiro-assume-locale]].
3. **Leniência só no campo ACESSÓRIO.** Contagem de parcela torta pode virar ausente e o lançamento
   sobrevive. O campo que carrega **dinheiro**, não: sem valor legível não há lançamento, e deixar
   seguir produz um resultado vazio contado como sucesso.
4. **Não deixe negativo passar** se o domínio não tem sinal — o sinal costuma vir do `tipo`
   (despesa/receita), e a coerção abre essa porta sem querer.

**Teste que morde.** Asserte o **valor**, não o sucesso: `resultado.valor == 300`. Um teste que só
verifica "não levantou exceção" fica verde com os cem milhões.
