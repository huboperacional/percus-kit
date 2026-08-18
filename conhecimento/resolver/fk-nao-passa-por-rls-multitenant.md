## Multi-tenant: a checagem de FOREIGN KEY do PostgreSQL NÃO passa pela RLS — a FK simples deixa o filho apontar para pai de outro tenant {#fk-nao-passa-por-rls-multitenant}

tags: multi-tenant, RLS, row level security, foreign key cruza tenant, isolamento, vazamento entre empresas, tenant_id, empresa_id, FK composta, UNIQUE (id, tenant_id), postgres, referential integrity bypassa policy

**Contexto:** você fez o dever de casa do isolamento — mixin de `tenant_id` obrigatório em toda
tabela, RLS ligada no PostgreSQL com política por `current_setting`, e um harness que varre os
endpoints procurando vazamento. Parece fechado.

Não está. Nada impede gravar um filho com `tenant_id` do tenant **A** e uma FK apontando para um
pai do tenant **B**:

```sql
INSERT INTO movimentos (empresa_id, conta_id, ...)
VALUES ('empresa-A', 'conta-que-e-da-empresa-B', ...);   -- passa
```

**Causa raiz:** no PostgreSQL a verificação de integridade referencial roda **com privilégio de
sistema** e é explicitamente **isenta das políticas de RLS** (senão uma FK apontando para linha
invisível quebraria a integridade do banco). Ou seja: a política que esconde a linha do tenant B
do `SELECT` **não** impede a FK de aceitá-la. A RLS protege leitura; ela não valida a
*coerência* entre a FK e o `tenant_id` da própria linha.

**Por que os outros controles também não pegam:**

- **Harness de vazamento por endpoint:** varre resposta de API. Isto é escrita direta no banco,
  atrás da camada que ele observa.
- **Mixin de `tenant_id`:** garante que a coluna existe e está preenchida — nunca que ela é
  **coerente** com o pai apontado.
- **Teste de suíte em SQLite:** não tem RLS nenhuma, então nem simula o cenário.

**Onde dói:** relatório consolidado de grupo somando conta de outra empresa; extrato de conta
que mostra movimento que não é dela; e o pior caso, o dado cruzado que só aparece meses depois,
já com retenção fiscal em cima e sem como saber qual lado está certo.

**Solução — FK composta, resolvida pelo banco, sem trigger e sem código de aplicação:**

```sql
-- 1) na tabela-pai, a UNIQUE redundante que habilita a referência composta
ALTER TABLE contas_financeiras ADD CONSTRAINT uq_conta_id_empresa UNIQUE (id, empresa_id);

-- 2) no filho, a FK passa a carregar o tenant junto
ALTER TABLE movimentos ADD CONSTRAINT fk_movimento_conta
  FOREIGN KEY (conta_id, empresa_id) REFERENCES contas_financeiras (id, empresa_id);
```

A combinação impossível passa a ser recusada pelo próprio banco. Custo: uma UNIQUE a mais por
tabela-pai (que em geral já é coberta pelo índice da PK) e a coluna de tenant na FK do filho.

**Teste que pega:** insira o filho com `tenant_id` de A e FK para pai de B e espere
`IntegrityError`.

> ⚠️ **Correção de 2026-08-13, por medição.** Esta entrada dizia que o teste "tem que rodar
> contra Postgres real — em SQLite não prova nada". **Está errado, e o erro custa caro:**
> empurra o teste para o marcador de infra externa, que quase nunca roda, e guarda que não roda
> é guarda que não existe. Medido: o **SQLite com `PRAGMA foreign_keys=ON` aplica FK composta e
> `RESTRICT` igual ao PostgreSQL** — o teste de *comportamento* cabe na suíte padrão. A
> confusão vinha de misturar com RLS: aquela sim não existe em SQLite.
>
> O que **só** o Postgres prova é outra coisa: que o dialeto de produção **aceita o DDL**.
> SQLite é permissivo com definição de constraint. Guarde para o teste `postgres` a FK composta
> **auto-referencial** (tabela que é pai e filha de si mesma) e a `UNIQUE` redundante com a PK
> — e confira as constraints **por nome** em `pg_constraint`, porque um `create_all` sem erro
> prova só que nada estourou, não que a FK nasceu.

**Três armadilhas na implementação, todas medidas:**

1. **Tire a FK simples da coluna ao compor** — mas saiba o motivo certo. Em SQLAlchemy, manter
   `ForeignKey(...)` no `mapped_column` além do `ForeignKeyConstraint` cria duas FKs na mesma
   coluna. **Isso NÃO reabre o vazamento** (medido: constraints de FK são conjuntivas, as duas
   têm que passar, e a composta continua recusando o cruzamento) — cuidado com a intuição
   contrária, que é fácil de escrever e passa em review. O que a simples faz é ser redundante,
   cobrar uma checagem por INSERT, e **mentir para quem lê**: o modelo passa a dizer que a
   referência é só por id, e a próxima pessoa conclui que a coerência de tenant não está no
   banco. É daí que o furo volta — quem vê duas FKs para a mesma coisa remove uma, e remover a
   composta reabre tudo em silêncio.
2. **`ON DELETE SET NULL` numa FK composta anula o `tenant_id` junto.** O PostgreSQL gera
   `SET "categoria_id" = NULL, "empresa_id" = NULL`; como `tenant_id` é NOT NULL, o DELETE
   falha com violação de NOT NULL — um `RESTRICT` disfarçado, com erro que não explica nada.
   O PostgreSQL 15+ tem `ON DELETE SET NULL (coluna)` para resolver, mas o **SQLAlchemy
   (medido na 2.0.35) recusa emitir**: `validate_sql_phrase` valida `ondelete` contra
   `^(?:RESTRICT|CASCADE|SET NULL|NO ACTION|SET DEFAULT)$` e estoura `CompileError`. Na
   prática, FK composta e `SET NULL` não convivem sem hook de compilação — o que costuma ser
   sinal de que o `SET NULL` é que estava errado.
3. **Nem toda FK cross-tenant é bug.** Se a relação é cross-tenant *por requisito* (par
   espelhado entre duas empresas do mesmo grupo, por exemplo), compor por `tenant_id` mata a
   feature. Aí o discriminante certo é o nível **acima** (`grupo_id`), desnormalizado no filho
   e travado contra divergência por uma segunda FK `(tenant_id, grupo_id)` para a tabela de
   tenant. Escreva a exceção num registro declarado, com teste de cobertura que derrube a
   suíte quando alguém "consertar" a exceção de volta para o padrão.

**Quando decidir:** antes do baseline da migration. Depois que a tabela tem dado com retenção
fiscal, virar FK simples em composta é migration com backfill e janela de inconsistência.
Antes, é uma linha a mais no modelo.

**Ref:** Empresa Milionária, Fase A Task 8, 2026-08-12 (achado pelo revisor cross-provider R11
sobre `Movimento`; o mesmo buraco estava em `Titulo` já commitado). Implementado — e esta
entrada corrigida — em 2026-08-13, ADR-0008: 9 FKs, das quais 1 compõe por grupo. Vale para
qualquer projeto Percus com o gatilho "é (ou pode virar) multi-tenant" marcado.
