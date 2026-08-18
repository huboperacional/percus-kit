## `ORDER BY created_at` não ordena um lote: `now()` é hora da TRANSAÇÃO {#created-at-nao-ordena-lote}

`tags: postgres, now(), current_timestamp, server_default, created_at, ordenacao, lote, batch, flake, transaction time, statement_timestamp, clock_timestamp`

**Sintoma:** N linhas criadas juntas (um lote, um fan-out, um import) saem na ordem certa quando
você testa, e um dia saem trocadas — sem ninguém ter mexido na query.

**Causa raiz:** `created_at` com `server_default=func.now()` grava `now()` do Postgres, que é
**hora do início da TRANSAÇÃO**, não do statement. Todas as N linhas do mesmo commit recebem o
**timestamp idêntico**. `ORDER BY created_at` então não desempata nada e o Postgres devolve a
ordem física do heap — que para poucas linhas num seq scan coincide com a de inserção, até deixar
de coincidir. Colunas de posição costumam nascer 0 em todas e não ajudam.

Medido em produção: 9 tarefas de um mesmo fan-out, `count(DISTINCT created_at) = 1`. E mais
revelador — a chamada de transcrição rodou **3 segundos depois** do timestamp que ficou gravado,
porque a transação já estava aberta.

**Solução:** ordene pelo que o **produtor** emitiu, não pelo que o banco carimbou. No teste, leia
os ids da lista que o próprio código montou (o retorno, o `side_effects`, o log) e resolva as
linhas nessa ordem. Se a ordem precisa sobreviver no banco, grave uma coluna de sequência
explícita — não confie em tempo. (`statement_timestamp()`/`clock_timestamp()` avançam dentro da
transação, mas ainda são tempo: continuam podendo empatar.)

**Ref:** Plexco Tasks s154 (2026-07-28), `test_wa_decomposicao.py` — três asserções de ordem
passavam por sorte; viraram `_tarefas_da_leva(db, result)`, que lê os ids do `side_effect`.
