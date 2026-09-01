## `create_all(tables=X)` emite FK de X mesmo com alvo fora de X {#create-all-com-tables-emite-fk-para-fora-do-recorte}

`tags: sqlalchemy, create_all, tables=, foreign key, UndefinedTableError, postgres, sqlite, recorte de schema, teste de integração, DDL, metadata`

**Contexto:** teste de integração monta um RECORTE do schema (não o banco inteiro) via
`Base.metadata.create_all(bind, tables=[Base.metadata.tables[n] for n in NOMES])`, pra provar
alguma coisa específica (ex.: aceitação de DDL de FK composta) sem montar o domínio inteiro.
Passa isolado, passa em SQLite, **falha contra Postgres real** com
`UndefinedTableError: relation "X" does not exist` — e o "X" muda a cada vez que alguém adiciona
uma coluna nova em QUALQUER tabela do recorte.

**Causa raiz:** `create_all(tables=X)` só CONTROLA quais `CREATE TABLE` são emitidos — não filtra
as FKs que essas tabelas carregam. Se uma tabela do recorte tem uma coluna com
`ForeignKey("tabela_de_fora.id")`, o `CREATE TABLE` da primeira inclui a cláusula
`REFERENCES tabela_de_fora (...)` de qualquer jeito, e o banco recusa porque o alvo não existe
no schema (que só tem as tabelas do recorte). SQLite não pega isso: não valida alvo de FK no
`CREATE TABLE`, só no `INSERT`/`UPDATE` com `PRAGMA foreign_keys=ON` — é a mesma classe de
"SQLite mente", só que na direção do DDL, não do dado.

**Por que é fácil esconder um segundo (ou terceiro) caso:** `create_all` aborta na PRIMEIRA
falha. Se duas tabelas do recorte têm FK saindo pra fora, só a primeira aparece no erro — a
segunda fica invisível até a primeira ser corrigida, e o padrão "descobri um problema, corrigi,
tomei outro erro parecido" tende a ser lido como "ainda não terminei de corrigir", quando na
verdade é o segundo bug diferente que a primeira falha mascarava.

**Diagnóstico:**
1. Não adivinhe pelo nome da tabela no erro — **compile o DDL de verdade** e confira TODAS as
   `REFERENCES` do recorte inteiro, não só da tabela que apareceu no traceback:
   ```python
   from sqlalchemy.schema import CreateTable
   from sqlalchemy.dialects import postgresql
   for t in tabelas_do_recorte:
       print(CreateTable(t).compile(dialect=postgresql.dialect()))
   ```
2. Rode isso ANTES de gastar uma janela de container/Postgres real — é 100% offline e pega o
   mesmo defeito que o banco real pegaria, sem custo de infra nem rede.

**Fix:** clonar as tabelas do recorte numa `MetaData()` isolada (nunca mutar `Base.metadata`
compartilhada — outros testes no mesmo processo dependem dela inteira) e podar toda FK cujo alvo
não esteja no próprio recorte:
```python
from sqlalchemy import MetaData, ForeignKeyConstraint

def tabela_alvo(fk):
    # target_fullname é string pura ("tabela.coluna") — NÃO use fk.column,
    # que resolve contra a metadata e levanta NoReferencedTableError pra
    # todo alvo fora do recorte (exatamente o caso que se quer tratar).
    return fk.target_fullname.split(".")[0]

def recorte_sem_fks_externas(nomes):
    nomes_incluidos = set(nomes)
    meta_isolada = MetaData()
    clones = [Base.metadata.tables[n].to_metadata(meta_isolada) for n in nomes]
    for clone in clones:
        for coluna in clone.columns:
            mantidas = {fk for fk in coluna.foreign_keys if tabela_alvo(fk) in nomes_incluidos}
            coluna.foreign_keys.clear()
            coluna.foreign_keys.update(mantidas)  # não reatribua o set — mute em lugar
        removidas = {c for c in clone.constraints if isinstance(c, ForeignKeyConstraint)
                    and any(tabela_alvo(fk) not in nomes_incluidos for fk in c.elements)}
        for c in removidas:
            clone.constraints.discard(c)
    return clones
```

⚠️ **Se um teste-irmão deriva um conjunto "esperadas" do metadata ORIGINAL** (ex.: "toda FK
composta declarada tem que existir no banco"), aplique o MESMO filtro na derivação — senão ele
exige uma FK que a poda removeu de propósito, e o teste fica inconsistente consigo mesmo
(comparando o que o modelo quer contra um recorte que nunca foi criado).

⚠️ **Gotcha à parte, achado tentando "melhorar" a poda — e CORRIGIDO abaixo, primeira versão
estava incompleta:** `Table.foreign_keys` (agregado no nível da TABELA, diferente de
`Column.foreign_keys`) é uma coleção **própria, populada quando cada coluna é anexada** — mutar
`coluna.foreign_keys` depois não a atualiza. A hipótese original aqui era que isso só afetava um
TESTE ingênuo que inspeciona `tabela.foreign_keys` pra verificar a poda, e que compilar o DDL
(`CreateTable(...).compile()`) seria "mais confiável" por não usar essa coleção. **Isso é
verdade só pela metade**, e a metade que faltava é a que importa: `CreateTable(...).compile()`
de fato não usa `Table.foreign_keys`, mas `create_all(tables=X)` de VÁRIAS tabelas passa por
`sort_tables_and_constraints` (o ordenador de dependência), que lê `Table.foreign_key_constraints`
— e essa propriedade É derivada de `Table.foreign_keys`, não de `table.constraints`. Ou seja: a
poda ficava incompleta EXATAMENTE do jeito que este verbete tinha acabado de alertar contra, e o
teste "mais confiável" (DDL de uma tabela por vez) nunca exercitava o código que expõe isso —
só `create_all` real, de múltiplas tabelas, contra Postgres de verdade. Fix completo e o porquê
detalhado: [#sqlalchemy-table-foreign-keys-sobrevive-a-poda-de-coluna](sqlalchemy-table-foreign-keys-sobrevive-a-poda-de-coluna.md).

**Declare no docstring o que a poda TIRA do alcance do teste** — dentro do recorte podado, as
FKs removidas deixam de ser exercidas contra o banco real por aquele teste específico. Um teste
de isolamento-por-tenant que passa verde não prova que TODAS as FKs do modelo são aceitas pelo
dialeto — só as que sobraram no recorte. Sem essa nota, "suite verde" vira leitura errada de
cobertura.

⚠️ **A frase abaixo ("100% offline, Postgres só pra confirmar") não se sustentou — deixada aqui
tachada, não apagada, porque o erro de confiança é o ponto que vale registrar.** O offline achou
e corrigiu ESTE bug (o das `REFERENCES` soltas no DDL). O fix aplicado só com base nisso ainda
derrubava os mesmos 8 testes contra Postgres real — por causa do SEGUNDO bug linkado acima, que
o offline não tinha como pegar. "Diagnosticado 100% offline" só ficou provado depois de rodar
contra banco de verdade, não antes. Duas sessões (a que escreveu este verbete e a que confirmou
contra Postgres) mediram coisas diferentes e é por isso que as duas conclusões pareciam certas
ao mesmo tempo.

**Ref:** Empresa Milionária, `tests/pj/test_isolamento_fk_postgres.py` — 8 erros idênticos
(`UndefinedTableError: relation "usuarios" does not exist`) causados por UMA de TRÊS FKs saindo
do recorte por desenho (`pessoas.tecnico_aprovado_por_id → usuarios`,
`titulos.pedido_id → pedidos`, `movimentos.liquidacao_id → liquidacoes`), nenhuma existindo
quando a lista do recorte foi escrita.
