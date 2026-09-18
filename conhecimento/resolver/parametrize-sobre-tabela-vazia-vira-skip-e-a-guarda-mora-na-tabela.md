## `parametrize` sobre tabela vazia vira SKIP silencioso — e a guarda mora na tabela, não em cada consumidor {#parametrize-sobre-tabela-vazia-vira-skip-e-a-guarda-mora-na-tabela}

`tags: pytest, parametrize, skip, tabela de casos, lista vazia, guarda, teste que passa por vácuo, import, raise, assert, python -O, sabotagem, R23`

**Sintoma:** uma tabela ÚNICA de casos (ex.: formas válidas e inválidas de um identificador) é consumida por vários
testes com `@pytest.mark.parametrize(..., TABELA)`. Se a tabela esvaziar — edição errada, filtro que passa a excluir
tudo —, o pytest marca `SKIPPED ... got empty parameter set` e **o arquivo inteiro fica verde**. Medido em 18/09/2026
(Empresa Milionária, S5 da Task 14 da NFS-e): com a tabela vazia, um consumidor deu 50 passed e 1 skipped e outro 3
passed e 1 skipped — e o pulado era a prova de que o CHECK do banco decide igual à tabela.

**Causa:** para o pytest, parâmetro vazio é "nada a testar", não erro. Quem lê o placar vê verde.

**Solução:** uma guarda **na própria tabela**, rodando na importação, em vez de um `assert` repetido em cada consumidor:

```python
def exigirCasosDosDoisLados(casos):
    if not any(ok and t for t, ok in casos) or not any(not ok and t for t, ok in casos):
        raise ValueError("a tabela precisa de casos válidos E inválidos")

exigirCasosDosDoisLados(TABELA)
```

`raise`, não `assert` (o `python -O` descarta assert). Com um lado vazio, TODO consumidor quebra na coleta, alto.
Prove os ramos com listas sintéticas (vazia, só válidos, só inválidos, válido sem texto) e sabote a tabela real
esvaziando-a numa troca só (`= [` vira `= [] and [`): os consumidores têm de ficar vermelhos, nenhum SKIP.

**Verbetes relacionados:** `lista-vazia-como-unico-sinal-de-todos-colide-com-vazio-de-verdade.md`,
`prova-de-teste-precisa-provar-que-o-teste-existe-e-foi-coletado.md`.
