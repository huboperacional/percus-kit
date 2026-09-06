## `literal()` do SQLAlchemy é `BindParameter`, não constante no SQL — prova-se compilando, não lendo {#literal-do-sqlalchemy-e-bindparameter-nao-constante-no-sql}

`tags: sqlalchemy, literal, bindparam, tuple_, keyset, paginacao, mypy, revisor alucina, medir antes de rejeitar, dialeto postgresql, R23`

**Sintoma:** para calar o mypy em paginação keyset (`tuple_(Task.updated_at, Task.id) > tuple_(dt, uid)`
acusa `arg-type` porque os stubs não aceitam valor Python cru em `tuple_`), o valor passa a ser
`literal(dt)`. Um revisor cross-provider afirma com convicção que `literal()` "embute a constante no
texto SQL, quebra o cache de plano e expõe a data ao timezone da sessão", e pede `bindparam`.

**Causa raiz:** afirmação falsa. Na documentação do SQLAlchemy, `literal(value)` "returns a literal
clause, **bound to a bind parameter**" — é exatamente o `BindParameter` que a comparação com valor cru
já criava. O que embute constante é `literal_column()` ou `literal(..., literal_execute=True)`.

**Medido em Plexco Tasks (2026-09-05, fatia 7a):** compilando as duas formas no dialeto postgresql:

```text
RAW : (tasks.updated_at, tasks.id) > (%(param_1)s, %(param_2)s::UUID)
LIT : (tasks.updated_at, tasks.id) > (%(param_1)s, %(param_2)s::UUID)
type(literal(dt)).__name__ == "BindParameter"; SQL e binds byte-identicos.
```

Dois revisores independentes (Opus e o controlador) obtiveram o mesmo resultado; o finding do
DeepSeek caiu por medição, não por argumento.

**Como aplicar:** finding de revisor sobre "o que o ORM gera" se decide com `query.compile(dialect=...)`
das duas formas, lado a lado, antes de aceitar ou rejeitar. Vinte segundos de compilação valem mais que
qualquer parágrafo de explicação.
