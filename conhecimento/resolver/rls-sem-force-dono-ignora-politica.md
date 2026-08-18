## RLS ligada, política escrita, e o app continua vendo tudo: faltou `FORCE`, ou o role é superusuário {#rls-sem-force-dono-ignora-politica}

tags: RLS, row level security, FORCE ROW LEVEL SECURITY, multi-tenant, isolamento, postgres, superuser ignora rls, bypassrls, dono da tabela, current_setting, set_config, teste de rls passa mentindo

**Contexto:** você ligou `ENABLE ROW LEVEL SECURITY`, escreveu a `CREATE POLICY` com
`current_setting('app.tenant_id')`, testou — e o `SELECT` continua devolvendo as linhas de
todos os tenants. Ou pior: **o teste passa** e você acha que está isolado.

**Causa raiz — são duas, e ambas silenciosas:**

1. **O DONO da tabela ignora a política.** `ENABLE ROW LEVEL SECURITY` não vale para o owner.
   E o owner costuma ser exatamente o role da aplicação, porque foi ele que rodou a migration.
   Falta `ALTER TABLE ... FORCE ROW LEVEL SECURITY`.
2. **Superusuário ignora RLS sempre** — inclusive com `FORCE`. Não há política que o alcance.

Medido num Postgres 17, duas linhas de tenants diferentes, política ativa:

| Configuração | Linhas que o dono enxerga |
|---|---|
| Política ativa, sem `FORCE` | **2 de 2** — decoração |
| `FORCE`, sem contexto | 0 |
| `FORCE` + `set_config('app.tenant_id', ...)` | 1 |

**A armadilha do TESTE, que é a pior das duas:** o container de teste levantado com
`docker run -e POSTGRES_USER=meu_app` cria esse usuário como **superusuário**. Aí o teste de
RLS roda como superusuário, o isolamento nunca é exercido, e o resultado é verde por um motivo
que não existe em produção. Espelhe os privilégios reais:

```bash
docker run -d -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=... postgres:17
docker exec c psql -U postgres -c \
  "CREATE ROLE meu_app LOGIN PASSWORD '...' NOSUPERUSER NOBYPASSRLS NOCREATEROLE;"
docker exec c psql -U postgres -c "CREATE DATABASE app OWNER meu_app;"
```

E confira, em produção **e** no teste, antes de confiar em qualquer resultado:

```sql
SELECT usename, usesuper, usebypassrls FROM pg_user WHERE usename = current_user;
```

**`SET LOCAL` não aceita bind parameter.** `SET` é comando utilitário: o driver devolve erro de
sintaxe. Use `SELECT set_config('app.tenant_id', :id, true)` — o terceiro argumento `true` é o
equivalente de `LOCAL`, e ele **não é opcional** num pool de conexões: valor de sessão sobrevive
à requisição e vaza para a próxima, que pode ser de outro tenant.

**Ref:** Empresa Milionária, Fase A Task 12, 2026-08-12. O container de teste nasceu com o app
role superusuário na primeira tentativa; o defeito só apareceu porque a privilegiação foi
comparada com a de produção antes de escrever o teste.
