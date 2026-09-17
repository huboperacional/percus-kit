## Teste que acha o item por `next(...)` ou `dict[...]` fica vermelho antes da asserção quando o item some, e a sabotagem parece provada {#teste-que-acha-item-por-next-fica-vermelho-antes-da-assercao}

`tags: pytest, teste, sabotagem, StopIteration, KeyError, next, asserção, controle, aviso, lista de avisos, python`

**Sintoma:** a sabotagem "tira o aviso" fica vermelha e parece provar o teste. O vermelho, porém, é `StopIteration` ou
`KeyError` na linha `aviso = next(a for a in avisos if a.codigo == X)` (ou `avisos[X]`), **antes** de qualquer `assert`.
O teste nunca chegou a conferir o conteúdo do aviso: uma versão que devolvesse o aviso com o código certo e o texto ou os
valores errados passaria. Medido em 2026-09-17 (Empresa Milionária, leitura de NFS-e, Task 6): três sabotagens do plano
ficaram vermelhas só desse jeito.

**Causa raiz:** o `next` sem valor padrão e o índice de dicionário **são** uma asserção de presença, só que implícita e
sem mensagem. Contar esse vermelho como prova confunde "o item existe" com "o item está certo". É a mesma classe de erro
de "vermelho antes da asserção": quem fica vermelho é a navegação até o dado, não a regra.

**Solução:**

1. Afirme a presença de forma explícita antes de buscar: `assert X in {a.codigo for a in avisos}`, e só depois
   `aviso = next(...)` e as asserções do conteúdo.
2. Ou use `next(..., None)` / `.get(X)` e compare com `is not None` numa asserção própria.
3. Para provar o conteúdo, sabote o **conteúdo** (texto, valor, lista) sem tirar o item: o vermelho tem de cair na
   asserção do conteúdo.
4. No relatório de sabotagem, conte `StopIteration`/`KeyError`/`IndexError` como vermelho **antes** da asserção, e diga
   qual asserção ainda não foi derrubada.
