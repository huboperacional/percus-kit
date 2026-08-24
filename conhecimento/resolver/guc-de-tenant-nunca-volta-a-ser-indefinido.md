## O GUC de tenant nunca volta a ser indefinido — vira string VAZIA, e todo `current_setting` fora da política precisa de `NULLIF` {#guc-de-tenant-nunca-volta-a-ser-indefinido}

`tags: RLS, multi-tenant, current_setting, GUC customizado, set_config, SET LOCAL, is_local, NULLIF, string vazia, 22P02, invalid input syntax for type uuid, 42501, 23502, DEFAULT de coluna, pool de conexoes, DISCARD ALL, RESET, fail-closed, PostgreSQL`

**Sintoma:** um `::uuid` sobre `current_setting('app.empresa_id', true)` funciona no teste e estoura em produção com **`22P02 invalid input syntax for type uuid: ""`**. O erro fala de *parsing*, não de tenant, e manda quem depura procurar UUID malformado no payload — que não existe.

**Causa raiz:** GUC customizado (`app.*`) não desaparece depois de usado. Na **primeira** vez que a sessão o define, o PostgreSQL o registra como placeholder; a partir daí `current_setting(nome, true)` devolve **`''`**, não `NULL`. **`RESET` e `DISCARD ALL` não desfazem** isso — devolvem ao "default" do placeholder, que é a string vazia.

🔑 **E é por isso que só aparece em produção:** o estado "conexão virgem, GUC nunca definido" existe no teste, que abre conexão nova, e **não existe num pool**, onde toda conexão já serviu outra requisição. O caminho que o teste exercita é justamente o que a produção nunca usa.

| Forma | Conexão virgem | Conexão reusada (o caso real) |
|---|---|---|
| `current_setting(g, true)::uuid` | `42501` / `NULL` | 🔴 `22P02` |
| `current_setting(g)::uuid` | `42704 undefined_object` | 🔴 `22P02` |
| ✅ `NULLIF(current_setting(g, true), '')::uuid` | `42501` | `42501` |

**Fix:** `NULLIF(current_setting(nome, true), '')::uuid` em **todo** lugar, não só na política.

**O que faz a armadilha morder mesmo em projeto que já sabe:** a equipe põe o `NULLIF` na `CREATE POLICY` — que é onde a documentação ensina — e escreve a forma ingênua no **`DEFAULT` de coluna**, num `CHECK`, numa view ou numa query da aplicação. A política fica certa e o vizinho fica errado, com a mesma expressão a dois centímetros de distância. Se você usa `current_setting` num `DEFAULT` para preencher o tenant sem tocar nos sítios de `INSERT`, é exatamente esse o caso.

**Duas coisas vizinhas que a mesma medição revelou:**

1. **Sem contexto, quem recusa o `INSERT` é a RLS, não o `NOT NULL`.** O `WITH CHECK` roda **antes** do `ExecConstraints`, então o erro é `42501 new row violates row-level security policy` e não `23502`. O `NOT NULL` continua sendo a rede de baixo — isole numa tabela sem RLS para vê-lo —, mas não conte com a mensagem dele no diagnóstico.
2. 🔴 **`is_local = true` no `set_config` é load-bearing, e é a única falha SEM erro.** Com `false`, o valor **sobrevive ao commit** e a próxima transação da mesma conexão herda o tenant anterior: linhas gravadas na empresa errada, **caladas**, sem exceção nenhuma. Toda outra falha desta família é ruidosa; esta não. Se o tenant é preenchido por `DEFAULT` em vez de à mão, o custo do engano sobe — o código de aplicação deixa de mencionar tenant, e não há onde a revisão tropeçar. Tenha teste que reprove se o `is_local` deixar de ser `true`.

**Ref:** Empresa Milionária, medido em PostgreSQL 17.6 em 2026-08-24 ao desenhar o `server_default` de tenant das tabelas do canal. Irmãos: [rls-sem-force-dono-ignora-politica](rls-sem-force-dono-ignora-politica.md) · [psql-sem-contexto-mede-rls-nao-o-dado](psql-sem-contexto-mede-rls-nao-o-dado.md) · [contagem-zero-sob-rls-force-nao-e-fato](contagem-zero-sob-rls-force-nao-e-fato.md).
