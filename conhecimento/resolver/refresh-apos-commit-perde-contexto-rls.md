## `refresh()` depois do `commit()` quebra sob RLS — o contexto é `SET LOCAL` e morre no commit {#refresh-apos-commit-perde-contexto-rls}

tags: RLS, row level security, SET LOCAL, set_config, session.refresh, commit, multi-tenant, contexto de tenant, endpoint cria e nao le, politica nega leitura, sqlite nao pega, teste verde em dev quebra em prod

**Contexto:** endpoint multi-tenant com RLS. A dependência aplica o contexto
(`SET LOCAL app.empresa_id`), o handler chama o caso de uso, faz `commit()` e depois
`session.refresh(objeto)` para montar a resposta. Todos os testes passam.

**O que acontece em produção:** `SET LOCAL` vale pela **transação**. O `commit()` a encerra, e
o `refresh()` seguinte abre uma transação NOVA, sem contexto. A política de RLS então nega a
leitura da linha que o próprio handler acabou de criar — e a falha é a mais confusa possível:
o dado está gravado, e o endpoint que o gravou não consegue lê-lo.

**Por que a suíte não pega:** se ela roda em SQLite, não há RLS nenhuma para negar. O código
passa dos dois jeitos, e o defeito só aparece no primeiro deploy — ou pior, na primeira vez que
duas empresas dividem o banco.

**Solução:** monte a resposta **antes** do commit, com os dados que o `flush()` já deixou no
objeto.

```python
resposta = Resposta.deObjeto(objeto)   # atributos já carregados pelo flush
await session.commit()
return resposta
```

Se precisar mesmo reler depois do commit, reaplique o contexto antes — mas prefira não
precisar: reler o que você acabou de escrever é quase sempre sinal de que a resposta foi montada
tarde demais.

**Vizinho que morde junto:** uma função que aplica o contexto só quando o dialeto é PostgreSQL
(para a suíte SQLite não estourar em `set_config`) deixa um segundo buraco — **esquecer de
chamá-la não quebra teste nenhum**. Cubra com um teste que espione a chamada, e
monkeypatche **no módulo que USA**, não no que define: quem importou o nome não vê a troca feita
na origem, e o teste passa espionando nada.

**Ref:** Empresa Milionária, Task 15 da Fase A, 2026-08-13. Achado relendo o código, não por
teste; o teste do espião entrou depois, por apontamento do review cross-provider. Entrada irmã:
`#rls-sem-force-dono-ignora-politica`.
