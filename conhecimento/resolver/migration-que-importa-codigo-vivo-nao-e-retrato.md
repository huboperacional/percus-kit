## Migration que importa código da aplicação não é retrato — e o teste fica verde sobre história falsa {#migration-que-importa-codigo-vivo-nao-e-retrato}

`tags: alembic, migration, ddl, rls, retrato, acoplamento, import, deploy, UndefinedTableError, ast, guarda, falso verde, schema, create_all`

**Contexto:** é tentador escrever `from app.core.x import helperDeDdl` dentro de uma migration e
chamar o helper — evita copiar 80 linhas de DDL e "mantém uma fonte da verdade". É exatamente o
erro. Migration é **retrato de um ponto da história**; código do app é **vivo** e muda embaixo
dela. A promessa de uma migration é reconstruir o banco que existiu; um `import` a quebra.

**As duas formas, e a segunda é a que engana:**

1. **Aguda — o helper percorre uma lista global.** `sqlAplicarTudo()` iterava
   `TABELAS_COM_TENANT`, a tupla do código de hoje. Uma migration de meses atrás passou a emitir
   `ALTER TABLE <tabela criada 4 migrations depois> ENABLE ROW LEVEL SECURITY` →
   `UndefinedTableError`, e **todo deploy futuro morre**, não só o da vez.
2. **Latente — o helper recebe a tabela por argumento.** `sqlHabilitarRls("titulos")` nunca sai
   de ordem, então nada quebra. Mas se a expressão da política mudar, a migration antiga passa a
   emitir a política **nova, retroativamente**. O `upgrade head` reconstrói um banco cujo estado
   intermediário nunca existiu, e ninguém percebe.

**Por que a suíte não pega, e este é o ponto:**

- A suíte monta o schema por `Base.metadata.create_all()` — todas as tabelas de uma vez. A
  **ordem da cadeia de migration nunca é exercida**. Verde na suíte não diz nada sobre a cadeia.
- O teste que compara "o DDL da migration bate com o que o módulo declara" fica verde nas DUAS
  formas, porque compara com o código de **hoje**: os dois lados mudam juntos.
- DDL bruto por `op.execute` é invisível ao `metadata`, então nenhum teste de modelo o vê.

**Caso medido (Empresa Milionária, 2026-08-28/29):** duas migrations com a forma aguda
bloquearam o deploy; três outras carregavam a forma latente e ninguém tinha notado.

**Conserto:** DDL **literal** dentro da migration. Para não escrever à mão, chame o helper num
shell com a lista congelada daquele ponto e cole a saída. Prove que congelou fiel gerando
`alembic upgrade head --sql` antes e depois e tirando o diff (normalize o `;`): o diff tem de ser
**vazio**, ou conter só o que você queria remover.

**Guardas — as duas, porque uma não cobre a outra:**

```python
# CAUSA: nenhum import de app em alembic/versions/. Use AST, não grep:
# import dentro de função, import com parênteses em várias linhas e
# `import app.models as m` são invisíveis para varredura de linha.
for no in ast.walk(ast.parse(caminho.read_text(encoding="utf-8"))):
    if isinstance(no, ast.ImportFrom) and no.level == 0 and no.module:
        assert not no.module.startswith("app")
```

```python
# CONSEQUENCIA: leia `upgrade head --sql` EM ORDEM (offline, não abre conexão,
# milissegundos) e exija que toda tabela citada fora do CREATE TABLE já exista.
```

A da causa sozinha não pega migration que já esteja errada; a da consequência sozinha deixa
passar um `sqlAplicarTudo()` novo colocado **no fim da cadeia** — ali todas as tabelas existem,
e ele só quebra quando a próxima nascer, longe de quem o causou.

**Editar migration já aplicada:** só é seguro se o texto congelado for **byte a byte** o que o
helper emitia quando aquela revisão rodou — revisão aplicada não reroda, então divergência não
se corrige sozinha. Confira por AST contra o commit que introduziu cada função; se o helper
mudou no meio, a saída correta é **migration nova** reaplicando, nunca edição retroativa.

**E prove contra Postgres de verdade.** Offline prova a ORDEM, não a validade do SQL, e o
caminho do deploy não é o do banco vazio: produção aplica o **delta** sobre tabelas com dado.
`SET NOT NULL` sem default, `CREATE UNIQUE INDEX` que colide com duplicata já gravada e
`ALTER COLUMN TYPE` que não converte um valor real passam lisos em tabela vazia. Clone o schema,
fixe o `alembic_version` no ponto de produção e aplique só o delta com `ON_ERROR_STOP=1`.
Ver [tenant novo, cadeia de migrations quebrada](tenant-novo-cadeia-migrations-quebrada.md).
