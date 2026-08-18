## Seed que morre no meio deixa N de M passos e RETORNA SUCESSO, e a contagem de linhas denuncia onde parou {#seed-parcial-parece-sucesso-conte-as-linhas}

tags: seed, bootstrap, provisionamento, RLS, estado parcial, falha silenciosa, multi-tenant, 404, papel, permissao, producao, idempotencia

**Sintoma:** produto no ar, banco "semeado", e **toda** rota do dominio responde 404 para o usuario — sem erro em log nenhum, sem excecao, com a tela abrindo normalmente e dizendo "nao encontrado" em tudo.

**Contexto medido (2026-08-16):** um script de seed com 10 passos (grupo, empresa, familia, usuario, contexto de RLS do usuario, contexto da empresa, papel, papel de grupo, lookups) tinha sido dado como executado, com relato de "21 registros criados". O banco de producao tinha **4 linhas**.

**Como o diagnostico fechou, e e o metodo que vale:** conte as linhas por tabela e **case a contagem contra a ORDEM dos passos do script**.

```sql
select 'grupos' t, count(*) from grupos
union all select 'empresas', count(*) from empresas
union all select 'usuarios', count(*) from usuarios
union all select 'papeis_empresa', count(*) from papeis_empresa
union all select 'categorias', count(*) from categorias;
```

Resultado: 1, 1, 1, **0**, **0**. Os passos 1 a 4 existiam e o 6 a 10 nao. Isso aponta o ponto de parada **exato** — o passo 5 — sem precisar de log nenhum. O passo 5 era `aplicarContextoDoUsuario`, e a tabela de papeis tem RLS isolada por usuario: sem contexto, a politica nega a escrita.

**Por que passou despercebido:** a suite roda em SQLite, que **nao tem RLS**, entao o caminho certo e o errado ficam os dois verdes. E o relato de "21 criados" era de outro banco (o de teste).

**Solucao, em duas frentes:**

1. **Diagnostico:** ao investigar "404 em tudo" ou "produto semeado que nao funciona", conte as linhas por tabela e compare com a ordem do script. A primeira tabela zerada e o passo que falhou.
2. **Prevencao:** provisionamento e **transacao unica** — tudo ou nada. Se o script nao pode ser atomico, ele tem que **falhar em voz alta** e relatar contagem por tabela **e o banco em que escreveu**, porque "rodou no banco de teste" e indistinguivel de "rodou em producao" quando so se olha o exit code.

⚠️ **O caso irmao e pior porque nao estoura:** sem contexto de RLS, o `SELECT` de idempotencia nao **enxerga** o que a rodada anterior criou — entao a segunda execucao recria tudo em silencio, e voce tem duplicata em vez de erro.

**Ref:** Empresa Milionaria, 2026-08-16 — `scripts/seed_piloto.py`, banco `empresa_milionaria_v1`.
