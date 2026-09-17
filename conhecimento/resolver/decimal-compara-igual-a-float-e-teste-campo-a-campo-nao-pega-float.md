## `Decimal` compara igual a `float`, e o teste campo a campo não pega o valor em dinheiro que virou `float` {#decimal-compara-igual-a-float-e-teste-campo-a-campo-nao-pega-float}

`tags: python, decimal, float, dinheiro, igualdade, teste, sabotagem, dataclass, parser, valor monetário, asserção`

**Sintoma:** o leitor de uma nota fiscal devolve os valores como `Decimal`, e o teste compara campo a campo com
`Decimal("835.00")`. Para provar a regra "dinheiro nunca é `float`", sabota-se a fonte trocando `Decimal(texto)` por
`float(texto)`, e o teste **continua verde**. Medido em 2026-09-16 com Python 3.12 (Empresa Milionária, leitura de NFS-e,
Task 4).

**Causa raiz:** em Python, `Decimal("835.00") == 835.0` é `True`. A comparação entre `Decimal` e `float` converte para
comparar valores exatos, então, para número que o `float` representa sem erro, a igualdade passa. Dataclass com `==`, tupla
e `assert a == b` herdam isso. O defeito que a regra quer impedir, somar `float` e perder centavo mais adiante, não aparece
no valor lido. Aparece depois, longe do leitor.

**Solução:**

1. Afirme o **tipo** além do valor: `assert all(type(v) is Decimal for v in valores)`, ou `isinstance` com uma lista
   explícita dos campos de dinheiro. Foi essa asserção que ficou vermelha na sabotagem.
2. Prefira caso com valor que o `float` **não** representa (`0.1`, `1000.10`): `Decimal("0.1") == 0.1` é `False`, e a
   comparação por valor também morde.
3. Na sabotagem, não conclua "o teste não discrimina" sem olhar se a igualdade atravessa os tipos. Conclua "esta
   asserção não discrimina este defeito" e acrescente a que discrimina.

**Vizinho:** `decimal-serializado-como-string-typeof-number-falha.md` trata o outro lado, o JSON que serializa `Decimal`
como string.
