## Teste que nunca falhou embarca fóssil: o red importa mais que o green {#red-nunca-visto-embarca-fossil}

`tags: tdd, red green, teste nunca falhou, fixture fossil, guard de banco, dbSafety, skip silencioso, teste escrito depois, pg efemero, banco de teste, suite verde mentirosa`

**Sintoma:** a suíte passa localmente, o teste novo "está verde", e ao rodar contra banco real ele quebra em coisas bobas — nome de campo, coluna de ordenação, tipo de exceção.

**Causa raiz:** um guard de segurança (tipo `dbSafety`) **pula** os testes de banco quando não há banco de teste configurado. O teste novo nunca rodou — nem vermelho, nem verde. Ele foi escrito contra o *contrato imaginado* da função, e cada divergência do contrato real virou um fóssil embutido: `sale["order_id"]` quando o retorno tem `id`, `ORDER BY created_at` quando a coluna é `transitioned_at`, `pytest.raises(Exception)` onde o código lança um tipo específico.

**Solução:**
1. **Ver a falha vermelha é o passo, não a formalidade.** Teste que passou de primeira ou não testa nada, ou o comportamento já existia — pare e descubra qual dos dois.
2. Se o guard pula, **declare em voz alta** que o vermelho não foi visto e que o `[5-T]` depende do gate real. Não converta "não rodou" em "passou".
3. Rode o recorte da feature no **gate real** (pg efêmero, CI) antes de marcar entregue — é lá que os fósseis aparecem, em lote e baratos.
4. Vale também pro caminho inverso: **teste verde pode estar guardando bug**. Um teste chamado `..._still_requires` documentava como correta a regra que o operador reportou como defeito.

**Ref:** tiatendo, 2026-07-20 — 8 testes de anulação escritos sem red; o pg efêmero achou **3 fósseis** neles. Commit `356aec3`.
