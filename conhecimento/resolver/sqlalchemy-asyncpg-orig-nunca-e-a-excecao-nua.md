## SQLAlchemy+asyncpg: `isinstance(e.orig, UniqueViolationError)` NUNCA bate — checar `sqlstate` {#sqlalchemy-asyncpg-orig-nunca-e-a-excecao-nua}

tags: sqlalchemy, asyncpg, postgres, integrityerror, unique violation, foreign key violation, dbapi, dialect, exception wrapping, 500 em vez de 409, sqlstate

**Sintoma:** um `try/except IntegrityError` que deveria distinguir violação de `UNIQUE` (esperado,
vira 409) de qualquer outra `IntegrityError` (inesperado, deveria propagar) nunca entra no ramo
esperado — o código sempre cai no `raise` genérico e o cliente recebe **500** onde deveria
receber **409**. Isso apesar de o código checar exatamente `isinstance(e.orig, UniqueViolationError)`,
que "parece" certo e passa despercebido em teste unitário que constrói `IntegrityError(msg, None,
UniqueViolationError())` diretamente — o mock não replica o wrapping real do dialect, então o
teste valida a checagem contra um cenário que nunca acontece em produção.

**Causa raiz:** o dialect `asyncpg` do SQLAlchemy (`sqlalchemy/dialects/postgresql/asyncpg.py`,
`_asyncpg_error_translate`) mapeia **toda a hierarquia** `IntegrityConstraintViolationError`
(que inclui `UniqueViolationError`, `ForeignKeyViolationError`, `CheckViolationError`, `NotNullViolationError`)
pra **UMA SÓ classe genérica** (`AsyncAdapt_asyncpg_dbapi.IntegrityError`) — não há mapeamento
específico por subtipo. O construtor é:

```python
translated_error = exception_mapping[super_]("%s: %s" % (type(error), error))
translated_error.pgcode = translated_error.sqlstate = getattr(error, "sqlstate", None)
raise translated_error from error
```

Ou seja: `e.orig` (o que o SQLAlchemy expõe pro caller) **nunca** é a exceção nua do asyncpg — nem
por `isinstance`, nem por `type(e.orig).__name__` (que é sempre literalmente `"IntegrityError"`,
não importa se a violação de verdade era unique/FK/check). O mesmo problema existe pro padrão
"belt-and-suspenders" `isinstance(cause, X) or "X" in type(cause).__name__` — o segundo ramo
também nunca bate, pela mesma razão.

**Solução:** o dialect **preserva** o `sqlstate` original antes de embrulhar (linha citada acima).
Códigos SQLSTATE são padrão SQL, não mudam por versão do driver:

```python
except IntegrityError as e:
    if getattr(e.orig, "sqlstate", None) == "23505":   # unique_violation
        raise AlreadyExistsError(...) from e
    if getattr(e.orig, "sqlstate", None) == "23503":   # foreign_key_violation
        raise CascadeBlockedError(...) from e
    raise
```

Mais simples e mais robusto que perseguir `e.orig.__cause__` (que também funciona — o dialect faz
`raise translated_error from error`, então a exceção real do asyncpg sobrevive em `__cause__` —
mas exige checar `isinstance` num nível a mais) ou casar texto na mensagem. Tabela de códigos:
`23505` unique · `23503` foreign_key · `23502` not_null · `23514` check.

**Teste que pega de verdade:** o mock do `.orig` tem que replicar o wrapping — uma classe genérica
com `.sqlstate` setado, não a exceção do asyncpg direta:

```python
def _wrapped_dbapi_error(real_exc):
    wrapped = Exception(f"{type(real_exc)}: {real_exc}")
    wrapped.sqlstate = real_exc.sqlstate   # asyncpg seta isso na classe, mesmo sem ir a rede
    return wrapped

session.flush.side_effect = IntegrityError("dup", None, _wrapped_dbapi_error(UniqueViolationError("msg")))
```

**Como foi encontrado:** `[5-T]` em produção (não teste mockado) — 2º voto na mesma votação devolveu
500 em vez do 409 esperado pela constraint `UNIQUE(poll_id, investor_id)`. O teste unitário
existente passava porque construía o mock errado.

**Ref:** Micro Investors, Fase 2 (votação interna), migration `00046_voting.sql`, 2026-08-14.
