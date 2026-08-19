## Tenant provisionado não é tenant usável {#tenant-provisionado-nao-e-tenant-usavel}

tags: multi-tenant, postgres, matview, [5-T], provisionamento, empty-state

**Sintoma.** Um tenant está marcado LIVE há semanas. Infra verde: stack de pé, isolamento provado
nas duas direções, credencial cruzada dá `permission denied`. Ninguém consegue usar. Ou a tela abre
bonita, com todos os números zerados, e ninguém desconfia.

**O que o `[5-T]` de isolamento realmente provou.** Que os bancos não se enxergam. Nenhum daqueles
testes toca o caminho que um humano usa. No Micro Investors (2026-08-19), exercitar o primeiro login
do tenant `tiatendo` achou três defeitos que conviveram meses com o selo de LIVE:

1. **Banco sem uma linha em `users`.** JWT válido do auth-service + `User` inexistente = **401**, se
   o backend não auto-provisiona (o nosso não: `core/deps.py` resolve `sub` → `users` e falha
   fechado, o que está certo). Sintoma enganoso: o auth autentica com sucesso, o log dele fica
   limpo, e a culpa parece ser "de algum motivo" do lado do produto.

2. **Matviews criadas e NUNCA populadas.** `SELECT` numa matview nunca refrescada **não devolve zero
   linhas — ela estoura**: `ObjectNotInPrerequisiteStateError: materialized view "..." has not been
   populated`. E aqui está a parte cruel: **tenant vazio e API quebrada desenham a MESMA tela.** O
   empty-state do frontend mostra `$0` e "Nenhuma empresa cadastrada", que é exatamente o correto
   para um tenant novo. Só console e rede separam os dois.

3. **A função canônica de refresh não faz o primeiro populate.** `fn_refresh_financials()` usa
   `REFRESH MATERIALIZED VIEW CONCURRENTLY`, e o Postgres recusa: `CONCURRENTLY cannot be used when
   the materialized view is not populated`. Ovo e galinha — a função é inútil justamente no tenant
   novo. O primeiro `REFRESH` tem que ser **sem** `CONCURRENTLY`, na ordem de dependência
   (`_mv_*_base` antes de quem lê dele); depois disso ela funciona.

**Checklist de tenant novo, além do isolamento.**

```sql
SELECT count(*) FROM users;            -- 0 = ninguém loga, ponto final
SELECT count(*) FROM user_roles;
SELECT matviewname, ispopulated        -- ispopulated=f = 500 na primeira tela
  FROM pg_matviews WHERE schemaname='public';
```

- Primeiro populate sem `CONCURRENTLY`, respeitando dependência; só então a função canônica.
- **Exercite um login real pela UI.** Isolamento provado ≠ produto usável.
- Ao abrir a tela, leia **console e rede**, não o desenho. Screenshot de tela zerada é
  indistinguível de screenshot de tela quebrada — foi assim que o 500 passou despercebido.

**Generalização.** Todo caminho que só um perfil de usuário percorre é um caminho não testado até
que esse perfil exista de verdade. No mesmo dia e no mesmo projeto, uma view de investidor migrada
havia semanas nunca tinha renderizado, porque **nenhum investidor tinha `user_id`** — e a suíte de
82 testes E2E jamais pegaria, já que todos rodam como operador.
