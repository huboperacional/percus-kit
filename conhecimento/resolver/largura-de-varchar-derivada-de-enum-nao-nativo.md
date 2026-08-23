## Enum não-nativo sem `length` congela o VARCHAR no maior valor da época — e o SQLite esconde {#largura-de-varchar-derivada-de-enum-nao-nativo}

`tags: sqlalchemy, alembic, enum, native_enum, VARCHAR, length, sqlite, postgres, value too long, migration, verde falso, guarda`

**Contexto:** a coluna `contas_financeiras.tipo` era `VARCHAR(8)` em produção. O enum tinha `bancaria` e `caixa`; 8 é exatamente `len("bancaria")`. Acrescentar `compensacao` (11) ao enum passaria a recusar o `INSERT` em produção — **com a suíte inteira verde**.

**Causa raiz:** `Enum(X, native_enum=False)` **sem `length=`** faz o SQLAlchemy dimensionar o `VARCHAR` pelo **maior valor do enum no momento em que a migration foi gerada**. Isso não é contrato: é acidente de dados. Acrescentar um membro mais longo muda o modelo e a suíte, e **não muda a coluna que já está no banco**.

**Três coisas ao mesmo tempo tornam o defeito invisível** — e é a combinação, não cada uma:

1. `native_enum=False` **não emite `CHECK`**. Não há constraint para divergir e acusar;
2. a suíte roda **SQLite**, que **ignora largura de VARCHAR**. O PostgreSQL não. Verde local, 500 em produção;
3. guardas de migration costumam comparar **nomes** de coluna. Tipo e comprimento passam batido.

**Fix:**

```python
# largura DECLARADA, igual em todas as colunas de enum do domínio
Enum(TipoConta, native_enum=False, length=40,
     values_callable=lambda e: [m.value for m in e])
```

E uma migration com `alter_column(..., type_=sa.String(length=40))`. **Alargar nunca perde dado** — todo valor que cabia continua cabendo, e o Postgres não reescreve a tabela quando só aumenta o limite. O **downgrade** é o perigoso, e deve falhar em vez de truncar: cortar um valor de domínio para caber num limite acidental é corromper o registro.

⚠️ **Escreva o `alter_column` à mão, coluna por coluna — não em laço sobre uma lista.** `op.alter_column(tabela, coluna, ...)` com **variáveis** esconde o DDL de quem lê: nem `git diff`, nem `grep`, nem uma guarda textual conseguem dizer o que mudou. Migration é DDL declarativo e precisa ser greppável — ela vai ser lida por alguém investigando produção às pressas.

### A guarda, e os cinco jeitos de ela nascer cega

A guarda que escrevi para isso nasceu **verde por vacuidade** — o mesmo defeito que ela existe para impedir. Cada um vale como alerta:

1. procurava `sa.String(length=N)`; o alembic autogera `sa.Enum(...)`. Não achava **nenhuma** coluna de enum e pulava todas num `continue` silencioso;
2. lia só a migration de baseline. Tabelas nascidas em migrations posteriores ficavam fora — **produção é a soma delas**;
3. parser **por linha** perdia `create_table(` com o nome na linha seguinte — e o nome pode ser uma **constante Python** (`op.create_table(TABELA, ...)`), que texto nenhum resolve sem ler o módulo;
4. `existing_type=` **termina em** `type_=`, então a regex do ALTER capturava a largura de **origem** e acusava divergência contra a própria correção. Precisa de `(?<!existing_)`;
5. varrer o arquivo inteiro deixa o `downgrade()` — que tem os mesmos `alter_column` com as larguras **antigas** — sobrescrever o `upgrade()`.

E um sexto, que era de **ordem**: arquivos lidos em ordem alfabética não estão em ordem de execução. A migration do ALTER (`a7c3...`) vinha antes da baseline (`dfe8...`), e o `create_table` sobrescrevia o ALTER. **Duas passadas** — todos os `create_table`, depois todos os `alter_column` — tornam a ordem irrelevante, que é mais forte do que acertá-la.

📌 **A mudança que fecha a classe:** o que o parser **não encontra** deve **FALHAR**, nunca ser pulado. Guarda que pula o que não entende mede o subconjunto que entendeu e reporta como se fosse o todo.

📌 **E prove vermelha por sabotagem antes de confiar:** mude a largura no ALTER e veja acusar; apague o ALTER e veja acusar. Guarda que só foi vista verde depois do próprio conserto pode estar verde pelo motivo errado.

**Ref:** Empresa Milionária, migration `a7c3e9b21f48` (2026-08-23). Ver também [guarda-de-schema-cobre-por-tipo](guarda-de-schema-cobre-por-tipo.md).
