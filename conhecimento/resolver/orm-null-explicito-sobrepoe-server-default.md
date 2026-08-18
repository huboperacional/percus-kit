## ORM manda `NULL` explícito por cima do `DEFAULT now()` do Postgres quando o atributo Python nunca é tocado {#orm-null-explicito-sobrepoe-server-default}

tags: sqlalchemy, orm, not null violation, server_default, default now, timestamp, created_at, insert explicit null

**Sintoma:** uma coluna `TIMESTAMPTZ NOT NULL DEFAULT now()` no schema, nunca setada
explicitamente no código Python que constrói o objeto ORM, estoura `NotNullViolationError` no
INSERT — mesmo o schema tendo um default perfeitamente válido. Confunde porque a expectativa
comum é "se eu não setar, o banco preenche" (comportamento real de **algumas** combinações de
SQLAlchemy/dialect/versão, não de todas — não assuma).

**Causa raiz:** o `DEFAULT now()` do Postgres só entra em jogo quando a coluna **não aparece** na
lista de colunas do `INSERT`. Se o SQLAlchemy decide incluir a coluna no INSERT com valor `NULL`
(o comportamento observado aqui, em vez de omitir a coluna e deixar o server default assumir), a
constraint `NOT NULL` estoura antes do default ter qualquer chance de agir — não é um conflito
entre "dois defaults", é a ausência total de um valor client-side vencendo por ordem de operação.

**Solução — dupla camada, não confie só numa:**

1. **Call-site:** setar o valor explicitamente no momento da construção do objeto:
   ```python
   poll = VotePoll(..., created_at=datetime.now(timezone.utc))
   ```
2. **Estrutural (não deixe pra disciplina de quem escreve o próximo call site):** `default=` no
   próprio `mapped_column` — o SQLAlchemy aplica isso automaticamente pra QUALQUER instância que
   não setar o campo, do mesmo jeito que já faz para PKs `default=uuid4`:
   ```python
   def _utcnow() -> datetime:
       return datetime.now(timezone.utc)

   created_at: Mapped[datetime | None] = mapped_column(
       TIMESTAMP(timezone=True), nullable=True, default=_utcnow
   )
   ```
   Sem a camada 2, o bug volta na próxima vez que alguém criar o objeto sem lembrar da camada 1.

**Como foi encontrado:** `[5-T]` em produção — `POST /voting/` (criar poll) devolveu 500 real,
`created_at` chegando `NULL` no INSERT apesar de `NOT NULL DEFAULT now()` no schema. Teste
unitário mockado não pegaria (mock de `session.add`/`session.commit` não executa SQL de verdade).

**Ref:** Micro Investors, Fase 2 (votação interna), 2026-08-14.
