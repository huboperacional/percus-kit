## Teste que forja o NOME da classe de exceção passa com o código quebrado {#teste-forja-nome-da-classe-de-excecao}

`tags: excecao, asyncpg, SQLAlchemy, dialect, IntegrityError, sqlstate, 23505, 23503, isinstance, nome de classe, teste verde inutil`

**Classe de sintoma:** um `except`/`catch` que discrimina tipo de erro nunca dispara em produção,
mas o teste dele está verde há meses.

**O mecanismo (asyncpg + SQLAlchemy, mas a classe é geral):** o dialect embrulha toda violação de
integridade numa única classe DBAPI genérica. Logo `isinstance(cause, ForeignKeyViolationError)` e
`"ForeignKeyViolation" in type(cause).__name__` **nunca** batem. O que o dialect preserva é o
`sqlstate` (`23505` unique, `23503` FK).

**Por que o teste não pegou:** ele fabricava uma classe com `__name__ = "ForeignKeyViolationError"`,
imitando o nome que a produção nunca emite. O teste validava um caminho de código que a realidade
não exercita — e por isso ficava verde por cima do bug.

**O sinal para procurar:** quando você conserta um `except` e o teste dele **começa a falhar**, o
teste estava errado, não o conserto. Investigue o fake antes de "consertar" o teste.

**Regra geral:** um mock deve imitar o que a **camada real entrega**, não o que a documentação da
biblioteca de baixo nível descreve. Entre as duas há um tradutor (dialect, driver, SDK) que muda a
forma do objeto.

**Ref:** Micro Investors, 2026-08-18, `deletion_requests/service.py`. Mesmo bug já corrigido no
módulo de votação em 2026-08-14 pelo `sqlstate`, e o comentário de lá registrava este como pendente.
Relacionado: `mock-responde-a-pergunta-errada`.
