## `CONSTRAINT TRIGGER` combinada com `WHEN` misturando `OLD`/`NEW` é sintaxe inválida no Postgres {#postgres-constraint-trigger-when-old-new-por-evento}

`tags: postgres, plpgsql, constraint trigger, deferrable, WHEN, OLD, NEW, INSERT OR UPDATE OR DELETE`

**Sintoma:** escrever uma única `CREATE CONSTRAINT TRIGGER ... AFTER INSERT OR UPDATE OR DELETE
ON tabela ... WHEN (NEW.coluna IS NOT NULL OR OLD.coluna IS NOT NULL) EXECUTE FUNCTION ...` —
pensando em cobrir os três eventos com a mesma trigger, checando `NEW` (existe em INSERT/UPDATE)
e `OLD` (existe em UPDATE/DELETE) na mesma cláusula `WHEN` — falha ao aplicar.

**Por que:** o Postgres valida a cláusula `WHEN` **por evento**, mesmo quando a trigger é
declarada combinando `INSERT OR UPDATE OR DELETE`. Numa trigger de `INSERT`, a variável `OLD` não
existe (não há linha anterior); numa trigger de `DELETE`, `NEW` não existe (não há linha nova). O
Postgres recusa a `WHEN` que referencia a variável errada pro evento, mesmo que a MESMA
`CREATE TRIGGER` também cubra um evento em que aquela variável seria válida.

**Fix:** declare **uma `CONSTRAINT TRIGGER` separada por evento**, cada uma só com a variável que
aquele evento de fato tem:

```sql
CREATE CONSTRAINT TRIGGER trg_x_ins
AFTER INSERT ON tabela
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
WHEN (NEW.coluna IS NOT NULL)
EXECUTE FUNCTION fn_x();

CREATE CONSTRAINT TRIGGER trg_x_upd
AFTER UPDATE OF coluna ON tabela
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
WHEN (NEW.coluna IS NOT NULL OR OLD.coluna IS NOT NULL)
EXECUTE FUNCTION fn_x();

CREATE CONSTRAINT TRIGGER trg_x_del
AFTER DELETE ON tabela
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
WHEN (OLD.coluna IS NOT NULL)
EXECUTE FUNCTION fn_x();
```

A trigger de `UPDATE` é a única que legitimamente usa os dois (`NEW` e `OLD` coexistem numa
atualização) — `INSERT` só tem `NEW`, `DELETE` só tem `OLD`.

**Como pegar isto ANTES de aplicar em banco real:** sem Postgres local disponível, confira a
sintaxe contra a documentação oficial (`https://www.postgresql.org/docs/17/sql-createtrigger.html`)
antes da primeira tentativa de `CREATE TRIGGER` — é um erro que só apareceria na hora de aplicar,
e aplicar direto contra produção sem essa checagem prévia custaria uma tentativa falha em banco
sensível.

**Ref:** Empresa Milionária, migration `a8ad43d2efd4` (trigger `DEFERRABLE INITIALLY DEFERRED` da
invariante soma-zero da Liquidação Fase 1, 2026-08-28) — versão original combinada com `WHEN`
misto foi escrita, e a checagem contra a doc oficial (antes de qualquer `ssh`/aplicação real)
achou o defeito e evitou a tentativa falha contra `empresa_milionaria_test`.
