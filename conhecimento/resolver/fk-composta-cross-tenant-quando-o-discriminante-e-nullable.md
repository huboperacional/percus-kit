## FK composta cross-tenant com discriminante NULLABLE — e as três armadilhas que vêm junto {#fk-composta-cross-tenant-quando-o-discriminante-e-nullable}

tags: FK composta, multi-tenant, MATCH SIMPLE, discriminante nullable, grupo_id, ponteiro mútuo, CHECK implicação, deadlock de constraint, vínculo bidirecional, controle positivo, savepoint, expiração de objeto, MissingGreenlet, SQLAlchemy

**Contexto:** FK simples entre tabelas de tenant deixa o filho apontar para pai de outro tenant
([[fk-nao-passa-por-rls-multitenant]]); a saída é a FK **composta**. Agora o ponteiro é
cross-tenant **por requisito** (um par espelhado entre duas empresas do mesmo grupo), a fronteira
passa a ser o grupo, e a tabela filha precisa de um `grupo_id` para compor.

O que trava a decisão: a tabela já existe e dezenas de lugares constroem o modelo direto. `NOT
NULL` exige backfill — que sob `FORCE RLS` pede `set_config`
([[migration-que-escreve-em-tabela-com-rls-falha-so-em-producao]]) — e alcança todos eles.

**A saída:** `MATCH SIMPLE` (default do SQL, e o único modo do SQLite) **não checa FK
multi-coluna quando qualquer coluna é NULL**. Com o discriminante NULLABLE, a linha comum fica
com os dois campos nulos e não paga nada; a checagem vale exatamente onde importa.

```sql
ALTER TABLE filhos ADD COLUMN par_id uuid NULL, ADD COLUMN grupo_id uuid NULL;
ALTER TABLE filhos ADD CONSTRAINT uq_filho_id_grupo UNIQUE (id, grupo_id);
ALTER TABLE filhos ADD CONSTRAINT fk_filho_par_grupo
    FOREIGN KEY (par_id, grupo_id) REFERENCES filhos (id, grupo_id);
```

### Armadilha 1 — o CHECK tem de ser IMPLICAÇÃO, nunca igualdade

`CHECK ((par_id IS NULL) = (grupo_id IS NULL))` parece mais forte e **torna o par impossível de
gravar**. O vínculo é **mútuo**: se B aponta para A, a linha de A precisa **já ter** o `grupo_id`
quando B nasce (FK só casa com alvo que já tem o valor) — e sob a igualdade A não pode recebê-lo
antes de ter o `par_id`, que só existe depois de B nascer. Deadlock de constraint.

O sintoma engana: com a escrita do par dentro de um `try/except` largo (comum em espelhamento
tolerante a falha), o `IntegrityError` é engolido e você vê só *"o espelho não apareceu"*.

```sql
CHECK (par_id IS NULL OR grupo_id IS NOT NULL)   -- o que funciona
```

O que precisa ser impedido é o **ponteiro sem o discriminante** — aí a FK não é checada e o
buraco volta. O discriminante sozinho é inofensivo: não aponta para nada.

🔑 A pergunta não é *"qual invariante é mais forte?"* e sim *"existe ordem de gravação que a
satisfaça?"*.

### Armadilha 2 — a ordem é exigência da FK, e o outro lado é intocável sob RLS

1. no contexto de **A**: grava só `A.grupo_id`, flush;
2. no contexto de **B**: cria B já com `par_id = A.id` e `grupo_id`;
3. **de volta em A**: grava `A.par_id = B.id`.

O passo 3 tem de acontecer **fora** do contexto de B: a policy `WITH CHECK` recusa UPDATE em
linha de outro tenant. Em SQLite, sem política, o mesmo código passa verde.

### Armadilha 3 — savepoint largo demais expira o objeto do chamador

Leitura fora de savepoint que falhe por erro de banco deixa a transação *aborted* no PostgreSQL,
e o `COMMIT` posterior falha mesmo com a exceção engolida
([[except-sem-rollback-deixa-transacao-envenenada-pra-leituras-seguintes]]). O reflexo é envolver tudo num `begin_nested()`
— e aí o rollback **expira os objetos modificados dentro dele**, com o chamador estourando
`MissingGreenlet` ao tocar um atributo depois.

O recorte: **savepoint nas leituras, não nas escritas em objeto que o chamador ainda usa.**

ℹ️ Medido no SQLAlchemy 2.0.35: sair **normalmente** de um savepoint não expira nada
(`_remove_snapshot` só expira `if not self.nested`) — o que expira é o rollback. E **entrar** num
savepoint dispara `flush()` implícito, ignorando `autoflush=False`.

### Como provar que a FK certa é que recusa — o controle positivo

`pytest.raises(IntegrityError)` sozinho **não prova qual constraint disparou**. Sob SQLite o
driver devolve `FOREIGN KEY constraint failed` **sem o nome da constraint**, então asserir a
mensagem não distingue a sua FK das outras da tabela: uma fixture alterada por descuido faria
outra disparar primeiro, e o teste seguiria verde "medindo" a sua.

A prova é **diferencial** — grave a linha idêntica à recusada, exceto pela coluna que decide:

```python
coerente = Filho(..., grupo_id=grupoB.id, par_id=linhaDeB.id)   # POSITIVO, primeiro
session.add(coerente); await session.flush()
assert coerente.id is not None

intrusa = Filho(..., grupo_id=grupoA.id, par_id=linhaDeB.id)    # só o grupo diverge
session.add(intrusa)
with pytest.raises(IntegrityError):
    await session.flush()
```

🔴 **O positivo vem ANTES.** Depois do `IntegrityError` a sessão fica inutilizável, e "limpar com
`rollback()` para testar o caso bom" desfaz a transação **inteira** — inclusive as fixtures que a
FK precisa encontrar. O positivo passa a falhar por ausência de dado, e o vermelho parece dizer
que o caso coerente foi recusado.

**O que isto não prova:** `MATCH SIMPLE` exercido em SQLite (que só implementa esse modo). No
PostgreSQL a semântica é a mesma por especificação — mas isso é leitura, não medição, e um
precedente `NOT NULL` no mesmo repositório pode significar que o caminho NULLABLE nunca rodou
contra o banco real.
