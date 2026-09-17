## `Enum(native_enum=False)` não emite CHECK e o ORM não valida string crua — o banco aceita qualquer valor na coluna de estado {#enum-nao-nativo-sem-check-aceita-qualquer-string}

`tags: sqlalchemy, alembic, enum, native_enum, validate_strings, CHECK, CheckConstraint, VARCHAR, status invalido, backstop, autogenerate, migration, R11, R23`

**Sintoma:** a tabela tem `CHECK` para valor positivo e nome preenchido, e o time trata o banco como
a última defesa. A coluna de **estado** (`status`, `tipo`) é um `Enum` do SQLAlchemy — e aceita
`'pausada'`, `'transferencia'` ou qualquer string que caiba no VARCHAR. Nenhum teste acusa, porque
todo teste escreve pelo membro do enum.

**Reprodução real** (Empresa Milionária, Task 1 da Meta PJ, 2026-09-13): o modelo passou pelo
autor e pela rodada 1 do revisor DeepSeek; o revisor cross-claude gerou o DDL offline e viu
`status VARCHAR(40) NOT NULL` sem constraint. Dois testes escritos para provar: os dois deram
`DID NOT RAISE`.

**Causa raiz — duas omissões que se somam:**

1. `Enum(X, native_enum=False)` emite **só o VARCHAR**. O `CHECK` automático existe atrás de
   `create_constraint=True`, que é `False` por default (medido no SQLAlchemy 2.0.35 instalado,
   junto com `validate_strings=False`).
2. O `Enum` do ORM **não barra string crua**: com `validate_strings=False` (default), um valor que
   não é membro atravessa o bind e chega ao banco. `MetaPJ(status="pausada")` grava no `flush`.

E o `autogenerate` do Alembic **não detecta CHECK** — migration regenerada nasce sem ele mesmo que o
modelo o declare.

**Conserto:** `CheckConstraint` escrito à mão, nomeado, no modelo **e** copiado na migration.

```python
__table_args__ = (
    CheckConstraint("status IN ('ativa', 'concluida', 'arquivada')",
                    name="ck_meta_pj_status_valido"),
)
```

```python
sa.CheckConstraint("status IN ('ativa', 'concluida', 'arquivada')", name='ck_meta_pj_status_valido'),
```

Por que não `native_enum=True`: cria um tipo do PostgreSQL, e acrescentar membro vira
`ALTER TYPE ... ADD VALUE`, que não roda dentro de transação em versões antigas e não se desfaz no
downgrade. Por que não só `validate_strings=True`: protege a escrita pelo ORM e nada mais — SQL cru,
script de backfill e integração que escreve direto continuam passando.

**Teste que pega:** passe a string crua pelo próprio ORM (o `validate_strings=False` é o que deixa o
teste chegar ao banco) e case o **nome** da constraint, não só a classe da exceção.

```python
dbSession.add(MetaPJ(empresaId=e.id, nome="Reserva", valorAlvo=Decimal("10"), status="pausada"))
with pytest.raises(IntegrityError, match="ck_meta_pj_status_valido"):
    await dbSession.flush()
```

O SQLite nomeia CHECK na mensagem (e aceita `IN (...)` e `length(trim(...))` dentro dele), então o
teste roda na suíte local sem Postgres.

📌 **Varra as irmãs.** Se uma tabela nasceu sem, as que ela copiou também nasceram — no caso real,
`orcados_pj.tipo`/`marca` tinham a mesma lacuna.

**Relacionados:** [largura-de-varchar-derivada-de-enum-nao-nativo](largura-de-varchar-derivada-de-enum-nao-nativo.md)
(a mesma coluna, pelo lado da largura), [sqlalchemy-enum-grava-name](sqlalchemy-enum-grava-name.md)
(sem `values_callable`, o `CHECK` com os valores canônicos recusaria o que o ORM grava).
