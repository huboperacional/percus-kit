## Marca de "campo a completar" não prova que o campo ficou vazio {#marca-de-campo-a-completar-nao-prova-que-o-campo-ficou-vazio}

`tags: teste, asserção, sabotagem, proposta, campo a completar, aviso, leitura de documento, pytest, regra de nunca preencher`

**Sintoma:** a regra é "este campo **nunca** sai por esta via" (ex.: o valor da nota nunca sai do texto do PDF). O teste
confere a marca `a_completar` do campo e o aviso que explica a regra, e fica verde. Uma sabotagem que PREENCHE o campo
deixa o teste **verde** do mesmo jeito. Medido em 2026-09-17 (Empresa Milionária, leitura de NFS-e, Task 11, negativa
S2neg): com `valor=Decimal("835.00")` em `propostaSemXml`, o teste do plano passou, porque a marca e o aviso continuavam
lá.

**Causa raiz:** a marca e o aviso são montados por um caminho diferente do valor do campo. O teste confere o que acompanha
a regra, não o dado que ela protege. Marca e valor podem divergir sem nenhum erro.

**Solução:**

1. Toda regra "nunca preenche" tem uma asserção **sobre o próprio campo** (`(proposta.valor, proposta.competencia) ==
   (None, None)`), além da marca e do aviso.
2. A sabotagem preenche o campo sem mexer na marca. Faça também a **negativa**: a mesma sabotagem com só a asserção nova
   retirada tem de ficar verde. É isso que mostra que a asserção antiga não discriminava.
3. Vizinhos: `assercao-de-teste-com-comparacao-nula-nao-dispara` e `sabotagem-prova-a-primeira-assercao-nao-o-teste`.
