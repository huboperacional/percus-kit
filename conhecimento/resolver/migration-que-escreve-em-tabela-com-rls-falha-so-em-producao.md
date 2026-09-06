## Migration que ESCREVE em tabela com RLS falha só em produção — o gate roda sobre schema vazio {#migration-que-escreve-em-tabela-com-rls-falha-so-em-producao}

`tags: migration, alembic, rls, multi-tenant, backfill, deploy, guarda, schema vazio, falso verde, postgres, evidencia`

**Sintoma.** A migration passa em tudo: suíte verde, gate `-m postgres` verde, revisão
cross-provider liberando. No primeiro `alembic upgrade head` **com dado real** ela falha —
`new row violates row-level security policy` num `INSERT`, ou um `SET NOT NULL` estourando
com *"column contains null values"* logo depois de um `UPDATE` que "rodou".

**Mecanismo, medido em 2026-09-05 (Empresa Milionária, Fatia B do intercompany).** Três elos:

1. As tabelas do domínio têm `FORCE ROW LEVEL SECURITY` com policy `USING`/`WITH CHECK` sobre
   `NULLIF(current_setting('app.empresa_id', true), '')::uuid`.
2. **O papel que roda a migration é o da aplicação.** O `deploy.sh` chama o alembic com o mesmo
   `.env`, e esse papel é `NOSUPERUSER NOBYPASSRLS` (conferido: `usesuper=false`,
   `usebypassrls=false`). Não existe credencial privilegiada para migration no projeto.
3. Sem `set_config`, `current_setting` devolve NULL, `empresa_id = NULL` nunca é TRUE:
   `INSERT` é **recusado**; `UPDATE`/`DELETE` atingem **zero linhas, sem erro**.

**Why — por que nenhum teste pega.** O gate roda `alembic upgrade head` sempre a partir de
**schema vazio**. Sem linha na tabela-fonte, o `SELECT` do backfill não devolve nada e a escrita
**nunca é exercida** — e "zero linhas afetadas" é indistinguível do caminho certo. O único
ambiente onde a escrita encontra dado é a **produção**, que é justamente o alvo de todo backfill.
Um teste Postgres pontual continuaria cego pelo mesmo motivo: é a família de
[#guarda-inalcancavel-meca-o-alcance] — o cenário não alcança a linha protegida.

**Correção.**

```sql
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT id FROM empresas LOOP          -- a tabela do TENANT, sem RLS
    PERFORM set_config('app.empresa_id', r.id::text, true);
    INSERT INTO tabela_com_rls (...) SELECT ... WHERE NOT EXISTS (...);
  END LOOP;
  PERFORM set_config('app.empresa_id', '', true);
END $$;
```

⚠️ **Itere a tabela do tenant, nunca a tabela sob RLS.** `SELECT DISTINCT empresa_id FROM
<tabela_com_rls>` **também** é filtrado: sem contexto não devolve linha, o laço não itera, e o
backfill sai silenciosamente vazio — o mesmo defeito por outra porta.

⚠️ **O reset final não é cosmético.** Se o `env.py` envolve `run_migrations()` num único
`begin_transaction()` (sem `transaction_per_migration=True`), **todas** as revisões pendentes
rodam na mesma transação, e `set_config(..., true)` vaza para a próxima — que escreveria na
empresa errada, em silêncio. Confira o `env.py` antes de chamar o reset de "higiene".

**Guarda — estática, e ela alcança o passado.** Uma varredura por AST sobre os literais passados
a `op.execute(...)`, cruzando `INSERT|UPDATE|DELETE` com a lista de tabelas com tenant, roda em
milissegundos na suíte padrão e vale para toda migration futura. No caso medido, **ela ficou
vermelha contra uma migration já commitada e aprovada por dois reviews** — o conserto pontual
teria deixado a gêmea em pé. Três detalhes que a guarda precisa acertar:

- ler **só** os argumentos de `op.execute(...)`, não todo `ast.Constant`: docstring de função e
  comentário `--` dentro do SQL citando "UPDATE x" reprovam migration de DDL puro
  ([#guarda-verde-porque-nao-mede-nada], face do texto-sobre-a-regra);
- aceitar prefixo de schema no regex (`public.tabela`), senão a captura devolve `"public"`;
- declarar o que ela **não** alcança — `op.bulk_insert` e SQL montado por f-string —, em vez de
  deixar a lacuna silenciosa.

**Consertar migration JÁ COMMITADA: a pergunta não é "já rodou?".** É **"a migration tem um passo
posterior que FALHA quando o backfill não faz efeito?"**. Com ele (ex.: `SET NOT NULL` depois do
`UPDATE`), a falha aborta a transação, a revisão **não** avança, e editar in-place reexecuta —
seguro. Se o backfill está **sozinho**, o banco registra sucesso com dado errado e o conserto
**exige revisão nova**.

**O parente em RUNTIME.** Pela aplicação, um `UPDATE` sob policy que não alcança a linha afeta
zero linhas **sem erro** — e em SQLite, que não tem policy, sabotar a guarda deixa a suíte verde.
Ali a resposta **não** é guarda estática (o contexto vem da rota, e a guarda viraria ruído até
alguém desligá-la): é conferir `rowcount != esperado` no ponto único da escrita e recusar a
operação.
