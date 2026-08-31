## `FORCE ROW LEVEL SECURITY` quebra o `pg_dump` do próprio dono — e o backup lógico morre calado {#force-rls-quebra-o-pg-dump-do-proprio-dono}

`tags: postgres, rls, force row level security, pg_dump, backup, disaster recovery, multi-tenant, isolamento, R23`

**Sintoma:** `pg_dump` com a credencial da aplicação falha no meio, numa tabela qualquer:

```
pg_dump: error: query failed: ERROR:  query would be affected by row-level security policy for table "baixas"
HINT:  To disable the policy for the table's owner, use ALTER TABLE NO FORCE ROW LEVEL SECURITY.
pg_dump: detail: Query was: COPY public.baixas (...) TO stdout;
```

O schema sai inteiro; o **dado** não sai. E como quase ninguém testa restauração, isso costuma
aparecer no pior dia possível.

**Causa raiz:** `ENABLE ROW LEVEL SECURITY` não se aplica ao dono da tabela — `FORCE` aplica, e é
justamente por isso que projetos multi-tenant sérios usam `FORCE` (sem ele, o papel da aplicação,
que normalmente é dono das tabelas, ignora a política e o isolamento é decorativo). A consequência
não intencional: `pg_dump` roda `COPY ... TO stdout` **como aquele papel**, a política se aplica, e
o Postgres se recusa a exportar um recorte silenciosamente parcial. Ele erra em vez de mentir — o
que é a decisão certa dele, e péssima notícia para quem achava que tinha backup.

**Por que passa despercebido:** o backup "funciona" enquanto ninguém liga `FORCE`; o dia em que a
camada de isolamento é endurecida, o job de dump quebra numa tabela específica, e o alerta (se
houver) diz "erro no backup", não "seu backup nunca mais teve dado".

**Soluções, em ordem de preferência:**

1. **Papel dedicado de backup com `BYPASSRLS`.** É o desenho correto: um papel que só lê, com
   `BYPASSRLS`, usado exclusivamente pelo dump. Não afrouxa nada para a aplicação.
2. **Dump físico** (`pg_basebackup`, snapshot de volume, PITR): opera abaixo do nível da política e
   não é afetado. Costuma já existir na infra e ninguém lembra que existe.
3. **Superusuário para o job de dump** — funciona, mas troca um problema por outro.
4. ❌ **Nunca** `ALTER TABLE ... NO FORCE ROW LEVEL SECURITY` para destravar o dump. Isso desliga
   exatamente a garantia que o `FORCE` existe para dar, e costuma ser feito "temporariamente".

**Consequência prática para teste de migration:** clonar produção com a credencial da aplicação
**não é possível** enquanto valer o `FORCE`. Dá para clonar o **schema** (`--schema-only` passa: DDL
não é afetado por política) e exercer a cadeia de migrations sobre ele — mas isso **não** cobre as
falhas que dependem de dado (`SET NOT NULL` sobre linha existente, índice único colidindo com
duplicata, conversão de tipo). Declare esse limite em voz alta em vez de deixar o verde sugerir
cobertura que não existe; quando não der para clonar o dado, verifique as operações sensíveis por
análise (a coluna é nova e nullable? a tabela tem uma linha só?) e diga qual foi qual.

**Como descobrir antes do dia ruim:** rode o dump completo **e restaure num banco descartável**
como parte do checklist de infra. Dump que termina com erro no meio ainda deixa arquivo em disco —
tamanho de arquivo não é prova de backup.

Relacionado: [[rls-sem-contexto-devolve-banco-vazio]],
[[suite-e-producao-montam-schemas-diferentes]].
