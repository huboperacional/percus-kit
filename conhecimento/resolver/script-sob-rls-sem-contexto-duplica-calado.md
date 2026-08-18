## Script que escreve sob RLS sem declarar contexto: um caso ESTOURA, o outro duplica calado {#script-sob-rls-sem-contexto-duplica-calado}

tags: rls, row level security, postgres, seed, script operacional, idempotencia, sqlite, set_config, multi-tenant, falso verde, InsufficientPrivilegeError

**Sintoma.** Um script operacional (seed, backfill, importador) passa em toda a suíte — que roda em
SQLite — e morre na primeira execução contra o banco de verdade:

```
InsufficientPrivilegeError: new row violates row-level security policy for table "papeis_empresa"
```

E há um segundo modo, **pior porque não estoura**: o script se diz idempotente, roda duas vezes e
**duplica tudo**. Sem erro nenhum.

**Causa.** As duas são a mesma: o script nunca declarou o contexto que a política lê
(`SET LOCAL app.empresa_id` / `app.usuario_id`, via `set_config(..., true)`).

- No `INSERT`, o `WITH CHECK` recusa a linha → o erro acima. Barulhento, achado em minutos.
- No `SELECT`, o `USING` devolve **conjunto vazio**. O get-or-create pergunta "já existe?", ouve
  "não" e cria de novo. Nenhuma exceção, nenhum log, nenhuma constraint violada — porque as linhas
  da rodada anterior existem e estão apenas **invisíveis** para esta transação.

SQLite não tem RLS. Lá não há política para violar nem para filtrar, e os dois defeitos passam
verdes por **ausência de mecanismo**, não por correção.

**Ordem, quando a tabela de papéis é isolada por usuário.** Declare o **usuário antes do papel**: a
tabela que responde "de quais empresas este usuário participa" não pode ser filtrada por empresa
(seria circular no login), então ela é isolada por `usuario_id`. Consultá-la antes de declarar quem
é o usuário faz a política negar justamente a linha que decide o acesso.

```python
await aplicarContextoDoUsuario(session, usuario.id)   # 1º — libera papeis_*
await aplicarContextoDaEmpresa(session, empresa.id)   # 2º — libera as tabelas com empresa_id
```

**Diagnóstico em 1 comando** — rode o script duas vezes e conte, não confie na ausência de erro:
```
python -m scripts.seed --url "$URL_DE_TESTE" ... | tail -3   # 1a: criados=N reaproveitados=0
python -m scripts.seed --url "$URL_DE_TESTE" ... | tail -3   # 2a: criados=0 reaproveitados=N
```
Se a 2ª rodada disser `criados=N` de novo, o SELECT está cego — mesmo que nada tenha falhado.

**Correção estrutural.** Faça o script devolver **criados** e **reaproveitados** separados, e trave
os dois casos num teste com marcador `postgres`. Teste de idempotência em SQLite prova uma
propriedade diferente da que você precisa: lá o SELECT enxerga tudo.
