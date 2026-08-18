## O `autogenerate` do Alembic não vê `CHECK`, RLS nem `REVOKE` — e o `alembic check` fica verde assim mesmo {#alembic-autogenerate-nao-ve-check-rls-revoke}

tags: alembic, autogenerate, migration incompleta, alembic check, CHECK constraint, row level security, RLS na migration, REVOKE, baseline, include_object, include_name, use_alter, schema drift, migration nao reflete o modelo

**Contexto:** o modelo está certo, os testes leem o `Base.metadata` e passam, e a migration foi
gerada por `alembic revision --autogenerate`. Parece fechado.

Não está. O autogenerate **compara** metadata com banco por um conjunto de regras que deixa de
fora justamente o que costuma carregar regra de negócio:

- **`CHECK` constraint em tabela que já existe.** Num baseline, onde toda tabela é nova, o
  `op.create_table` renderiza a definição inteira e os `CHECK` entram. Numa migration seguinte,
  acrescentar ou mudar um `CHECK` **não gera nada**.
- **Política de RLS, `FORCE`, `GRANT`/`REVOKE`.** Não existem para o Alembic. São DDL escrito à
  mão dentro do arquivo, e somem sem aviso se alguém regenerar a migration.
- **FK com `use_alter=True`** (dependência circular entre tabelas). Ela aparece **declarada**
  dentro do `op.create_table` e **não é criada** — o Alembic ignora `use_alter` ali. Precisa de
  `op.create_foreign_key` depois das tabelas e `op.drop_constraint` antes dos drops.

**A parte que engana:** `alembic check` **não** cobre esse buraco. Ele compara pelas mesmas
regras do autogenerate, então é cego exatamente para o que o autogenerate não vê. Um `check`
verde significa "nada que o autogenerate saiba comparar divergiu", não "o banco tem o que o
modelo declara". Ele ainda vale a pena — foi ele que pegou as FKs `use_alter` ausentes —, mas
como rede secundária, nunca como garantia.

**Solução — verificação em dois níveis:**

*Nível barato, na suíte padrão, sem banco nenhum.* `alembic upgrade head --sql` roda em modo
offline e emite o DDL como texto sem abrir conexão. Compare esse texto com o que as declarações
do projeto prometem. Três detalhes decidem se funciona:

- Capture com **`cfg.output_buffer`**, não `cfg.stdout` — com `stdout` o buffer volta VAZIO e o
  DDL sai no terminal. Um teste escrito assim procura ausência numa string vazia e passa sempre.
  Ponha uma asserção de "emitiu alguma coisa" antes das outras.
- **Force a URL do dialeto de produção** por variável de ambiente. O modo offline nunca conecta,
  mas escolhe o dialeto pela URL — e se a suíte roda em SQLite, você confere o DDL errado.
- **Asserte contra `head`**, o encadeamento inteiro, e não contra o arquivo do baseline. Assim o
  teste continua correto quando a migration seguinte mudar a declaração.

*Nível caro, marcador de infra externa.* Construa o banco com `alembic upgrade head` em vez de
`create_all` e rode sondas de **comportamento** contra ele: o INSERT que deve ser recusado, a
política que deve esconder a linha, o `UPDATE` que o `REVOKE` deve derrubar. Comparar estrutura
pega menos que exercitar comportamento.

**A armadilha dentro da solução:** um teste que confere só o **nome** da constraint passa com a
constraint esvaziada. FK que mantém `fk_titulo_categoria_empresa` e perde a coluna de tenant
reabre o vazamento inteiro, e a string do nome continua no SQL. `CHECK` que mantém o nome e vira
`CHECK (true)` idem. **Asserte nome + conteúdo** — colunas da FK na ordem, expressão do `CHECK`
normalizada por espaço em branco.

E ao **falsificar** o teste, mude o que a regressão real mudaria: renomear a constraint prova
pouco, porque o caso perigoso preserva o nome.

**Dois vizinhos que mordem no mesmo terreno:**

- **Filtrar o autogenerate é `include_object`, não `include_name`.** Os dois existem e nenhum
  levanta erro, então a troca é silenciosa. `include_name` filtra nomes vindos da **reflexão do
  banco**; `include_object` filtra objeto do **metadata**, que é de onde vem "tabela nova a
  criar". Com o errado, a migration nasce com o domínio inteiro que você queria excluir.
- **Modelo que não é importado pelo `__init__.py` do pacote é invisível.** O `env.py` faz
  `import app.models` e nada mais; um modelo que só carrega por import transitório aparece na
  suíte (que importa mais coisa) e some do autogenerate. Trave com um teste em **subprocesso** —
  dentro da suíte o metadata já está poluído e a comparação não teria sentido.

**Ref:** Empresa Milionária, baseline da Fase A, 2026-08-13. Entrada irmã:
`#fk-nao-passa-por-rls-multitenant`. Vale para qualquer projeto Percus com Alembic — e vale
mais ainda onde `CHECK` carrega regra de negócio (sinal de estorno, saldo não-negativo), porque
lá o silêncio do autogenerate é o silêncio da regra.
