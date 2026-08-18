## `psql -tAc` imprime o command tag junto com o RETURNING — e `INSERT 0 0` é truthy {#psql-command-tag-truthy}

`tags: psql, -tAc, command tag, INSERT 0 0, RETURNING, truthy, dedupe, guard de 24h, falso positivo`

**Contexto:** guard de deduplicação em SQL (`INSERT ... SELECT ... WHERE NOT EXISTS ... RETURNING id`)
com o resultado interpretado por código que faz `if saida:`.

**Sintoma:** o dedupe funciona **no banco** (a tabela tem 1 linha só, conferido), mas o código acha
que inseriu toda vez — então o alerta que deveria sair 1× por dia sai a cada execução.

**Causa raiz:** com `-tAc`, o psql escreve o **command tag** (`INSERT 0 1`, `INSERT 0 0`,
`UPDATE 0`) no stdout, junto com as linhas do `RETURNING`. Um INSERT suprimido devolve a string
`'INSERT 0 0'` — não-vazia, portanto **truthy**.

**Solução:** ler o número do próprio tag (`^INSERT \d+ (\d+)$`), que é o Postgres dizendo quantas
linhas gravou. Nunca decidir por "a saída veio não-vazia".

**Nota de escopo, para não virar caça-fantasma:** isso só morde quem interpreta saída de
INSERT/UPDATE. Quem roda `SELECT` com `-tA`, ou quem checa `"ERROR"`/`"(0 rows)"` em script
multi-statement, não é afetado — conferido um a um antes de registrar.

**Ref:** `D:\Claud Automations\Kommo-Disparo-WhatsApp\executionerificar_divergencia_fila.py`
(`_quantas_inseridas`). 2026-08-13.
