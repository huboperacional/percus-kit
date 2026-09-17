## Guarda de migration que procura o CHECK no DDL acumulado aceita o texto histórico, e nenhuma guarda de coluna vê o índice {#guarda-de-migration-por-ddl-acumulado-aceita-check-historico-e-nao-ve-indice}

`tags: alembic, migration, check constraint, índice, create_index, modelo, metadata, guarda, teste, sabotagem, ddl, sqlalchemy`

**Sintoma:** o projeto tem guardas que conferem "modelo × migration": toda coluna do modelo existe na migration, e todo
`CheckConstraint` do modelo aparece no DDL das migrations. Numa migration que **altera** CHECKs existentes e cria um
índice, duas sabotagens ficaram verdes. Medido em 2026-09-17 (Empresa Milionária, NFS-e Task 9, migration
`a9c4e7d2b815`):

1. **CHECK do modelo voltado ao texto antigo** (`tipo_documento IN ('boleto')` em vez de `IN ('boleto', 'nfse')`): a
   guarda passa, porque procura o texto em todas as migrations juntas, e o texto antigo continua na migration que o
   criou (`c5f2a8d41e37`). Modelo e banco final divergem com a suíte verde.
2. **`op.create_index` removido da migration:** a suíte passa. As guardas de coluna e de CHECK não olham índice, e o
   SQLite da suíte monta o schema pelo modelo, não pela migration.

**Causa raiz:** "o texto aparece em alguma migration" não é "é o estado final da cadeia". Toda definição alterada por
migration posterior deixa o texto velho no histórico, e a busca por presença o aceita. Índice é um terceiro tipo de
objeto, e cobrir colunas e CHECKs não o cobre.

**Solução:**

1. Para CHECK alterado, compare com o **último** texto da cadeia: percorra as migrations na ordem do `down_revision` e
   guarde, por nome de constraint, a última expressão criada; o modelo tem de bater com ela.
2. Para índice, confira nome, colunas, ordem e `unique` entre `__table_args__` (`Index`) e `op.create_index` da cadeia.
   Um teste por índice novo, com a sabotagem "tirar o `create_index`" ficando vermelha.
3. Em toda migration que altera ou cria constraint ou índice, sabote **a migration** e **o modelo** separadamente: a
   guarda que só fica vermelha num dos lados cobre metade.
4. Vizinho: `indice-por-op-execute-e-invisivel-ao-metadata` (memória do projeto) trata o índice criado por SQL cru.

**Terceiro tipo que a guarda de coluna não vê: TIPO e LARGURA.** Medido em 2026-09-17 (mesmo projeto, V2.3 Task 12-M,
migration `7c1e9a3f5b20`): com `sa.String(length=30)` na migration para um modelo `String(20)`, todas as guardas ficaram
verdes. "A coluna existe na migration" só confere o **nome**; a suíte monta o schema pelo modelo, então produção fica com
a largura da migration e ninguém vê. O caminho perigoso é o inverso (migration mais estreita que o modelo): estoura em
produção com erro de banco, e passa na suíte. Conserto no mesmo molde do item 1: estado final da cadeia por coluna
(último `ADD COLUMN` ou `ALTER COLUMN ... TYPE`), comparando tipo e largura com o modelo. Antes de escrever a guarda,
meça quantas colunas do HEAD já divergem: uma guarda que nasce vermelha em coluna herdada pede lista fechada com motivo.

**Guarda escrita e medida (17/09, mesmo projeto):** 933 colunas conferidas, **0 divergências** no HEAD — a lista de
exceção nasceu vazia, e o comentário diz que ela nasce vazia *por medição*, não por esquecimento. Três detalhes que
custaram medição:

- **Corte do tipo.** A linha do DDL traz `UUID NOT NULL`, `TIMESTAMP WITH TIME ZONE DEFAULT now()`,
  `INTEGER REFERENCES ...`. Comparar a linha inteira com `coluna.type.compile(dialect=postgresql)` dá **496
  divergências falsas** em 933 colunas. Corte em `NOT NULL|NULL|DEFAULT|PRIMARY KEY|REFERENCES|UNIQUE|CONSTRAINT|CHECK|
  GENERATED|COLLATE` antes de comparar.
- **Piso de cobertura.** Leitor que pare de casar devolve `{}`, a lista de divergências vem vazia e o teste fica verde
  por medição zero. Asserte o número de colunas alcançadas (`> 900` aqui) junto com a ausência de divergência.
- **Forma do `CREATE TABLE`.** O leitor casa a forma que o Alembic emite (uma coluna por linha, `);` no início da
  linha). O controle positivo tem de usar a forma REAL: escrito com `);` indentado, ele reprova o leitor certo — foi o
  que aconteceu, e é o leitor discriminando forma, não defeito.

**Quarto e quinto tipos: `NOT NULL` e `server_default`** (medidos no mesmo projeto em 17/09, sobre as mesmas 933
colunas). Também invisíveis às guardas de nome, CHECK, índice e tipo:

- **`NOT NULL`, 2 divergências, as duas legítimas.** Coluna anulável no modelo e `NOT NULL` na migration: a suíte
  aceita o `INSERT` sem o campo e produção o recusa. Aqui as duas eram declaradas no docstring do modelo (o valor vem
  de `server_default` que lê o GUC da RLS, e o SQLite da suíte não tem `current_setting()`), então a guarda nasceu com
  **lista fechada de 2, cada entrada com o motivo colado do docstring e a migration citada** — e reprova entrada nova,
  entrada obsoleta e entrada sem motivo. Guarde **os dois sentidos**: `NOT NULL` no modelo e anulável na migration
  deixa o código ler `None` de campo que ele supõe preenchido.
- **`server_default`: guarde só a direção perigosa.** "Modelo declara e migration não" é o que quebra (a suíte grava o
  valor, produção deixa a coluna vazia) e tinha **0** casos, então a lista nasce vazia por medição e nunca mais volta a
  zero calado. A direção inversa tinha **12** e **não é defeito**: o valor existe nos dois lados, com `default=`
  (Python, aplicado pelo ORM) no modelo e `DEFAULT` (banco) na migration. A consequência real é estreita — `INSERT`
  que não passa pelo ORM pega o default do banco, que o modelo não conhece. Normalizar as 12 é decisão de padrão do
  projeto, não trabalho de guarda: declare a direção fora de escopo no arquivo, com o número e o motivo.
- **Normalize o default antes de comparar, e diga que a normalização foi medida.** Modelo e DDL escrevem a mesma
  expressão de formas diferentes (`(NULLIF(current_setting(...), ''))` × a mesma com `::uuid`): sem tirar cast e
  parêntese externo, a guarda acusa renderização.
- **Leia `ALTER COLUMN SET/DROP NOT NULL` e `SET/DROP DEFAULT`**: é como uma coluna muda depois de nascer, e um leitor
  que só veja o `CREATE` erra por omissão. ⚠️ `DROP DEFAULT` **não** tira o `NOT NULL` — a primeira versão do controle
  positivo supunha que sim, e o teste reprovou a expectativa, não o leitor.
- **Compare por função pura.** Passe `(tabela, coluna, anulável)` e `(tabela, coluna, server_default)` como dados: o
  controle positivo injeta o desvio sem tocar em modelo nem migration, e não depende de sabotar arquivo.
