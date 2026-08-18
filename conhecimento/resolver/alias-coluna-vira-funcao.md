## `alias.coluna` vira `funcao(alias)` e o erro mente sobre a causa {#alias-coluna-vira-funcao}

`tags: postgres, group by, notacao funcional, coluna inexistente, count, must appear in the GROUP BY clause, erro que mente, information_schema, sql`

**Sintoma:** um `SELECT` trivial, sem nenhum agregado à vista, falha com
`column "t.id" must appear in the GROUP BY clause or be used in an aggregate function`.

```sql
-- isto parece uma consulta comum e não é
SELECT t.id, t.name, c.signal, c.count, c.checked_at
FROM crm_signal_state c JOIN tenants t ON t.id = c.tenant_id
```

**A causa:** o Postgres trata `alias.nome` e `nome(alias)` como **equivalentes** (notação funcional).
Quando `count` **não existe** como coluna de `c`, o parser não desiste — ele resolve `c.count` como
`count(c)`, que é o **agregado**. A consulta passa a ter um agregado, e o Postgres reclama, com toda
a razão, que `t.id` não está no `GROUP BY`.

**Por que isso engana:** o erro aponta para `t.id`, que está perfeito, e não menciona `c.count`, que é
o culpado. Ninguém procura nome de coluna inexistente quando o erro fala de `GROUP BY` — o instinto é
mexer no agrupamento, e mexer no agrupamento faz a consulta rodar devolvendo outra coisa.

- **A regra:** erro de `GROUP BY` em consulta que não tem agregado ⇒ **suspeite de nome de coluna que
  colide com função** (`count`, `min`, `max`, `sum`, `avg`, `length`, `abs`, `left`, `right`,
  `upper`, `lower`, `now`...). Confira a coluna **no catálogo** antes de tocar no agrupamento.
- **Como confirmar em um passo:**
  `SELECT column_name FROM information_schema.columns WHERE table_name = '<tabela>'`.
  Se o nome não estiver lá, era isto.
- **Prevenção barata:** ao explorar tabela desconhecida, comece por `SELECT *` e leia as colunas de
  verdade, em vez de escrever a lista de memória. Foi assim que o caso real apareceu: a coluna
  chamava-se `measured_count`, não `count`.
- **Vale além do Postgres:** a mesma notação funcional existe em qualquer engine que a suporte. O que
  não varia é a lição — **a mensagem de erro do banco aponta onde ele tropeçou, não onde você errou.**
