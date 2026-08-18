## `Enum(native_enum=False)` do SQLAlchemy grava o NAME do membro, não o `.value` {#sqlalchemy-enum-grava-name}

tags: sqlalchemy, Enum, native_enum, values_callable, enum grava maiusculo, WHERE nao retorna linha, psql query vazia, str enum, alembic, VARCHAR, ORM esconde, python enum name vs value

**Contexto:** você declara `class Situacao(str, enum.Enum): APROVADO = "aprovado"` e mapeia com
`mapped_column(Enum(Situacao, native_enum=False))`. Tudo passa nos testes — porque o ORM traduz
na ida e na volta. Aí alguém roda `SELECT ... WHERE situacao = 'aprovado'` no psql e recebe
**zero linhas**, com o dado correto no banco.

**Causa raiz:** por padrão o SQLAlchemy persiste o **nome** do membro (`"APROVADO"`), não o
`.value` (`"aprovado"`). Herdar de `str` **não muda isso**. O defeito é invisível pela suíte:
todo teste que lê pelo ORM recebe o enum de volta corretamente.

**Onde dói:** query manual/psql, dump para o contador, integração que lê a tabela direto,
filtro escrito em SQL cru, e migration que cria CHECK com os valores canônicos.

**Solução:**

```python
tipo: Mapped[TipoTitulo] = mapped_column(
    Enum(TipoTitulo, native_enum=False,
         values_callable=lambda e: [m.value for m in e]),
    nullable=False,
)
```

**Teste que pega (o único que pega):** leia com **SQL cru**, não pelo ORM.

```python
bruto = (await session.execute(text("SELECT situacao FROM titulos"))).all()
assert ("aprovado",) in [tuple(l) for l in bruto]
```

⚠️ Não filtre por `WHERE id = :i` num teste SQLite com PK UUID: o dialeto serializa o UUID
**sem hífens** e o `str(uuid)` não casa. Selecione a tabela e procure a tupla.

**Armadilha de retrofit:** se já existe dado gravado com o NAME, acrescentar `values_callable`
**não migra nada** — precisa de `UPDATE` na migration. Corrigir antes do baseline sai de graça;
depois, não.

**Ref:** Empresa Milionária, Fase A Task 7, 2026-08-12. Achado pelo revisor cross-provider (R11)
em código rascunhado por DeepSeek e já revisado por Opus — os dois deixaram passar. Dois modelos
anteriores (`papel.py`, `conta_financeira.py`) já tinham sido commitados com o mesmo defeito e
foram corrigidos junto.
