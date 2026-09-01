## `Table.foreign_keys` é uma terceira coleção — podar só `Column.foreign_keys` não basta pra `create_all` de várias tabelas {#sqlalchemy-table-foreign-keys-sobrevive-a-poda-de-coluna}

`tags: sqlalchemy, foreign_keys, create_all, sort_tables_and_constraints, to_metadata, subset de tabelas, NoReferencedTableError`

**Contexto:** Empresa Milionária, 31/08/2026 (SQLAlchemy 2.0.35). Teste clona um SUBCONJUNTO de
tabelas de `Base.metadata` (via `.to_metadata(metadataIsolada)`) e precisa remover, de cada
tabela clonada, toda FK cujo alvo esteja FORA do subconjunto — senão `create_all(tables=X)` tenta
criar uma FK apontando pra uma tabela que não existe no banco de teste.

**A poda óbvia (e insuficiente):**
```python
for coluna in tabela.columns:
    mantidas = {fk for fk in coluna.foreign_keys if alvo(fk) in nomesIncluidos}
    coluna.foreign_keys.clear()
    coluna.foreign_keys.update(mantidas)
# + descartar ForeignKeyConstraint de table.constraints cujo alvo está fora
```
Isso corrige a compilação de DDL de **uma tabela por vez** (`CreateTable(t).compile()`) — o teste
que só chama isso passa, e passa pelo motivo ERRADO: `CreateTable` de uma tabela isolada nunca
aciona o código que realmente quebra.

**A causa real, achada só contra `create_all()` de VÁRIAS tabelas:** `Table` mantém `self.foreign_keys`
como um `set` PRÓPRIO, populado quando cada `Column` é anexada à tabela (`Table.__init__` faz
`self.foreign_keys = set()`, e cada `Column._set_parent` acrescenta a ele) — **separado** de
`Column.foreign_keys` e de `Table.constraints`. `Table.foreign_key_constraints` (propriedade usada
por `create_all` pra decidir a ordem entre tabelas) é computada A PARTIR de `Table.foreign_keys`,
não de `Table.constraints`:

```python
# sqlalchemy/sql/schema.py
@property
def foreign_key_constraints(self):
    return {fkc.constraint for fkc in self.foreign_keys if fkc.constraint is not None}
```

E `sort_tables_and_constraints` (`sqlalchemy/sql/ddl.py`, o ordenador de dependência que
`create_all(tables=X)` usa quando X tem mais de uma tabela) itera `table.foreign_key_constraints`
— ou seja, lê `Table.foreign_keys`, que a poda acima NUNCA tocou. A tabela clonada "lembra" da FK
removida, e o `create_all` real levanta `NoReferencedTableError` na hora de ORDENAR as tabelas,
antes até de emitir SQL.

**Por que o teste unitário mascarava isso:** `CreateTable(tabela).compile()` (compilar o DDL de
UMA tabela) não passa por `sort_tables_and_constraints` — esse ordenador só existe pra decidir em
que SEQUÊNCIA criar VÁRIAS tabelas relacionadas. Um teste que valida a poda compilando tabela por
tabela nunca exercita o código que a suíte real (`create_all` de um subconjunto de N tabelas)
efetivamente usa.

**Fix — reconstruir `Table.foreign_keys` como a união do que sobrou em cada coluna, depois de
podar as colunas:**
```python
clone.foreign_keys.clear()
clone.foreign_keys.update(
    fk for coluna in clone.columns for fk in coluna.foreign_keys
)
```

**Teste de regressão que exercita o caminho real** (sem precisar de banco nenhum — chama o MESMO
ordenador que `create_all` chama):
```python
from sqlalchemy.sql.ddl import sort_tables_and_constraints
tabelas = recorteSemFksExternas(...)
list(sort_tables_and_constraints(tabelas))  # NoReferencedTableError sem o fix, silencioso com ele
```
Alternativa mais fiel ainda, se quiser exercitar `create_all` de verdade sem tocar banco:
`create_all(engine, checkfirst=False)` contra uma engine `create_mock_engine` (captura o DDL sem
executar) — pega também uma QUARTA coleção que ninguém previu, se o SQLAlchemy vier a ter uma.

**Princípio geral:** quando um objeto expõe a MESMA informação (aqui, "quais FKs esta tabela tem")
por mais de um caminho de leitura, um teste que só exercita UM caminho pode ficar verde enquanto
outro caminho — o que o código de produção realmente usa — está quebrado. Testar "o dado está
certo" não é o mesmo que testar "o caminho que o código real percorre está certo".

**Ref:** sessão Empresa Milionária, 31/08/2026 (commit `cde748b`, `tests/pj/preparo_schema.py` +
`tests/pj/test_preparo_schema.py::test_recorte_sem_fks_externas_sobrevive_ao_ordenador_de_dependencias`).
