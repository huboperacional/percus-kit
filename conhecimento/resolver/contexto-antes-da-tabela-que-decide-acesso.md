## A tabela que decide o acesso também tem RLS: consultar o papel antes de declarar o usuário nega o próprio login {#contexto-antes-da-tabela-que-decide-acesso}

tags: RLS, row level security, multi-tenant, papeis, autorizacao, 404 em tudo, SET LOCAL, ordem do contexto, politica circular, sqlite nao pega, bug so em producao

**Sintoma:** com a RLS ligada, **todo** endpoint do domínio responde 404 / "não encontrado",
inclusive para usuário que tem acesso. A suíte inteira está verde.

**Causa:** a dependência que autoriza consulta a tabela de vínculo (`papeis`, `memberships`,
`acessos`) **antes** de declarar o contexto. Só que essa tabela também tem política — e ela não
pode ser isolada pelo tenant, porque é ela que responde *de qual tenant o usuário é*: isolá-la
assim seria circular no login. Então ela é isolada pelo **usuário**.

Resultado: sem o contexto de usuário declarado, a política nega a linha que decide o acesso. O
vínculo "não existe", a dependência recusa, e o produto inteiro fica inacessível — falhando
fechado, que é seguro e completamente inútil.

**Por que a suíte não pega:** se ela roda em SQLite, não há política nenhuma, a consulta acha o
vínculo e todos os testes de endpoint passam. O defeito nasce e vive invisível até o primeiro
banco real.

**Solução — a ordem é load-bearing, e por isso as duas coisas não podem ser uma função só:**

```python
await aplicarContextoDoUsuario(session, usuario.id)      # ANTES da consulta
papel = await buscarPapel(session, usuario.id, tenantId)
if papel is None:
    raise HTTPException(404, ...)
await aplicarContextoDoTenant(session, tenantId)         # DEPOIS de o papel existir
```

Um helper único que aplique os dois de uma vez **não tem como estar certo**: chamado cedo,
declara tenant que ainda não foi autorizado; chamado tarde, a consulta do papel já falhou.

**Como travar em SQLite, onde o mecanismo não existe:** espione as duas chamadas e asserte a
**sequência**, não a presença — `assert chamadas == [("usuario", ...), ("tenant", ...)]`. Um
teste que só conte chamadas fica verde com a ordem invertida, que é exatamente o defeito.

**Como isso foi achado, e a lição maior:** por um harness que roda os endpoints contra o banco
REAL, com a política ligada, pelo caminho HTTP. Nenhuma quantidade de teste em SQLite acharia —
e a prova de que o contexto chega não é o caso negativo (o vizinho não aparece), é o
**positivo**: a listagem devolver o dado da própria empresa. Com a política negando tudo, o
negativo passa e a resposta vem vazia, que é o modo de falhar mais fácil de confundir com
sucesso.

**Ref:** Empresa Milionária, Task 13 da Fase A, 2026-08-13. Entradas irmãs:
`#refresh-apos-commit-perde-contexto-rls`, `#rls-sem-force-dono-ignora-politica`.
