## Teste que lê o catálogo do banco mede o que a FIXTURE aplicou, não o que a migration deixou {#teste-de-catalogo-mede-a-fixture-nao-a-migration}

`tags: postgres, rls, force, revoke, migration, alembic, fixture, information_schema, pg_class, catalogo, sabotagem, controle positivo, falso verde, R23`

**Sintoma:** um teste consulta `information_schema.role_table_grants` (ou `pg_class`, `pg_policies`) para provar que
o `REVOKE`, o `ENABLE`/`FORCE ROW LEVEL SECURITY` ou a policy está aplicado. Para provar que a asserção
discrimina, sabota-se **o banco** — por exemplo `GRANT UPDATE, DELETE ON <tabela> TO <papel>` — e o teste
**passa verde com a proteção removida**.

A leitura natural é a pior possível: *"a asserção não discrimina, o teste é falso"*. Medido em 18/09/2026
(Empresa Milionária, janela R20 da Task 23 da V2.3), a conclusão certa era outra.

**Causa:** a fixture da suíte **reaplica o DDL a partir do código** (ali, `sqlAplicarTudo` lendo
`app/core/rls.py`) ao montar o banco de teste. O `GRANT` foi desfeito pela própria fixture antes de a asserção
rodar. O que o teste lê é o estado que a **fixture** acabou de escrever — nunca o que a **migration** deixou.

Três leituras na mesma execução separam as duas hipóteses, e nenhuma outra coisa separa:

```
A_antes_do_teste=2   →   1 passed   →   B_depois_do_teste=0
```

O privilégio sumiu **sozinho**. Se a asserção fosse frouxa, `B` continuaria 2.

**Consequência, que é o ponto:** o teste **discrimina** mudança na fonte do DDL (tirar a tabela da lista
`TABELAS_SO_ANEXO` deixa-o vermelho, e essa é a sabotagem correta), mas **não veria uma migration que
esquecesse o `REVOKE`**. Ele não cobre o caminho `migration → catálogo`, que é justamente o que vale em
produção. Mesma classe de *pré-condição que mede DADO não cobre o caminho de escrita*: aqui o teste mede o
catálogo e não o caminho que o produz.

**Solução:**
- Para provar a **migration**, use banco **virgem**, `alembic upgrade head` e leia o catálogo **sem pytest no
  caminho** — a suíte não serve de instrumento. Medição que fechou o caso:
  `REVOKE <tabela_so_anexo> = 0 grants` **com controle positivo** numa tabela que *não* é só-de-anexo
  (esperados `UPDATE` e `DELETE`). Sem o controle, "zero linhas" não distingue *REVOKE aplicado* de *consulta
  que não acha nada para ninguém*.
- Ao sabotar um teste de catálogo, sabote **a fonte do DDL**, nunca o estado do banco: o estado é reescrito pela
  fixture antes da asserção, e a sabotagem vira falso verde — provando o contrário do que se queria.
- E meça o estado **depois** da execução, não só antes: é `B_depois` que revela a reaplicação.

**Relacionado:** `force-rls-nao-so-enable`, `superuser-ignora-rls-mesmo-com-force`,
`suite-e-producao-montam-schemas-diferentes`, `assercao-escrita-nao-e-assercao-que-discrimina`,
`prova-de-teste-precisa-provar-que-o-teste-existe-e-foi-coletado`.
