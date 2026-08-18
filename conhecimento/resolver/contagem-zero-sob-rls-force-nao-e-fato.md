## Contagem zero sob `FORCE ROW LEVEL SECURITY` não é fato — e a mesma query mente em uma tabela e acerta na vizinha {#contagem-zero-sob-rls-force-nao-e-fato}

`tags: postgres, RLS, row level security, FORCE RLS, current_setting, app.tenant_id, contagem falsa, medicao, falso negativo, pg_class, relforcerowsecurity, multi-tenant`

**Sintoma:** você mede o banco para responder "o cliente já usou o produto?" e recebe `0`. Conclui que ninguém usou, e a decisão seguinte (não publicar depoimento, cancelar piloto, refazer seed) sai desse zero.

**Causa raiz:** a tabela tem RLS com política por `current_setting('app.<discriminante>')`. Sem esse `SET` na sessão, a política não casa nada e o `count(*)` devolve **0 com sucesso** — sem erro, sem aviso. E `FORCE RLS` faz o **dono da tabela obedecer também**, então o truque de "conectar como owner" não salva.

🔑 **O que torna isso especialmente traiçoeiro é que o RLS costuma estar em ALGUMAS tabelas e não em todas.** Medido em 2026-08-18: `empresas` e `usuarios` estavam sem RLS — logo `1 empresa, 1 usuário` era fato — enquanto `titulos` e `movimentos` estavam com RLS **e** `FORCE`. A mesma bateria de `count(*)` produziu, na mesma conexão, **dois números confiáveis e dois inventados**, e nada na saída distinguia um do outro.

**Solução — nesta ordem, sempre:**
1. **Antes de acreditar em qualquer contagem**, pergunte ao catálogo quais tabelas filtram:
   ```sql
   SELECT relname, relrowsecurity AS rls, relforcerowsecurity AS force_rls
   FROM pg_class WHERE relname IN ('a','b','c');
   ```
2. Para as que filtram, leia a política e descubra o nome exato do setting:
   ```sql
   SELECT tablename, policyname, qual FROM pg_policies WHERE tablename = 'titulos';
   ```
3. Meça **com o contexto definido**, na mesma sessão:
   ```sql
   SET app.empresa_id = '<uuid>'; SELECT count(*) FROM titulos;
   ```
4. Ao relatar, **diga de qual tabela o número veio e se ela tem RLS**. "0 títulos" e "0 títulos medido com `app.empresa_id` definido" são afirmações diferentes.

⚠️ **O harness de vazamento não pega isto, e a razão é estrutural:** ele procura dado de OUTRO tenant aparecendo onde não devia — falso-positivo. Uma rota (ou query) que não devolve nada é, para esse critério, perfeitamente segura. Este defeito é o outro sentido: falso-negativo, não viu o que devia. Cobrir só um lado é o padrão, e é por isso que este erro sobrevive a suíte verde.

⚠️ **`pg_dump -U <owner>` também falha sob `FORCE RLS`** — o dump vira tabela vazia sem reclamar. Dump precisa de role com `BYPASSRLS` ou superuser.

Relacionado: [guarda-morta-entrypoint](guarda-morta-entrypoint.md), [comentario-afirma-garantia-que-o-codigo-nao-entrega](comentario-afirma-garantia-que-o-codigo-nao-entrega.md).
