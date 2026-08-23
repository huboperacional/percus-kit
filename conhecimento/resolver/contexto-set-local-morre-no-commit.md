## Contexto de RLS é `SET LOCAL` e morre no commit — o que vier depois lê banco vazio {#contexto-set-local-morre-no-commit}

`tags: RLS, row level security, SET LOCAL, set_config, multi-tenant, postgres, sqlalchemy, async, commit, session.refresh, PendingRollbackError, InvalidRequestError, 503, fail-closed, FastAPI Depends, sqlite nao tem RLS`

**Contexto:** API async (FastAPI + SQLAlchemy) com isolamento por Row-Level Security. Uma dependência
aplica o contexto de tenant no começo da requisição (`SELECT set_config('app.empresa_id', $1, true)`),
e a política de cada tabela lê esse valor. Rotas que escreviam funcionavam nos testes e **devolviam
5xx em produção — com o dado já gravado**.

**Causa raiz:** o terceiro argumento de `set_config` é `true`, ou seja **`LOCAL`: o valor vive na
transação corrente**. Isso não é estilo, é obrigatório — com contexto de sessão o valor sobrevive à
requisição dentro do pool de conexões e vaza para a próxima, que pode ser de outro tenant.

A consequência é que **o primeiro `commit()` de um handler encerra a transação e mata o contexto**.
Tudo que tocar a sessão depois roda numa transação nova, sem contexto, onde a política *fail-closed*
não libera linha nenhuma:

- `await session.refresh(obj)` depois do commit → o SELECT não acha a linha → `InvalidRequestError`
- um segundo `UPDATE` depois do commit → 0 linhas casadas → o flush falha → sessão em *pending
  rollback* → **`PendingRollbackError`** no próximo toque
- uma **`Depends` que commita** → envenena todo handler abaixo dela, inclusive os que ainda não
  existem

**O modo de falha é o pior possível: a escrita acontece e a resposta é 5xx.** O usuário lê "tente
novamente", tenta, e recebe 409 de um registro que ele não sabe que criou.

**Armadilha dentro da armadilha:** o `except` que deveria tratar o commit falho pode ser ele próprio
o que estoura. Um `logger.error("...", id=str(obj.id))` **toca o objeto ORM** numa sessão em pending
rollback e levanta antes de logar e antes do `rollback()`. O sintoma é a **ausência** da linha de log
que provaria o caminho — foi isso que denunciou o caso real.

**Por que a suíte não pega:** **SQLite não tem RLS.** Sem política, consultar depois do commit
funciona, e o teste fica verde **por ausência de mecanismo**, não por acerto. No caso real, quatro
sítios conviveram com 808 testes verdes, e o comentário correto já existia em três arquivos do
próprio repositório.

**Diagnóstico:**
1. No log do servidor, procure `errorType` junto do 5xx. `InvalidRequestError` e
   `PendingRollbackError` (subclasse do primeiro) apontam para cá.
2. Confirme que o dado **foi gravado** apesar do erro — repetir a chamada devolvendo 409/conflito é
   a assinatura.
3. Leia o handler procurando **qualquer** uso da sessão depois do primeiro `commit()`.
4. Ao inspecionar o banco por fora para conferir, **aplique o contexto antes de consultar** — senão
   você vê zero linhas e conclui que o dado não existe. Ver [[contagem-zero-sob-rls-force-nao-e-fato]].

**Correção:** monte a resposta **antes** do commit, com os valores já em mãos.

```python
resposta = Resposta.deModelo(obj)   # le o ORM com contexto vivo
await session.commit()              # a partir daqui nao ha contexto
return resposta
```

Se precisar mesmo do banco depois de commitar, **reaplique o contexto explicitamente** na transação
nova, imediatamente antes do write, e capture em variáveis simples tudo que o tratamento de erro for
usar — nunca leia atributo de ORM dentro de um `except` de flush falho.

**Guarda que impede a reincidência:** comentário não bastou (existia em três arquivos e quatro rotas
fizeram o contrário). O que funciona é uma **guarda estática de AST**, na suíte padrão, sem banco:
percorre os statements de cada função e reprova qualquer `session.<verbo>()` depois de um
`await session.commit()` — inclusive dentro de `try`/`except`, que é onde os casos difíceis moram — e
trata à parte a função usada em `Depends(...)` que commita, porque nela o estrago acontece na função
seguinte. Exceções deliberadas vão numa lista declarada, com o motivo escrito.

⚠️ **A guarda precisa provar que enxerga**: guarde amostras fixas do código defeituoso real e teste
que ela acusa cada uma; e teste também que ela **aprova o padrão correto** — guarda que reprova o
jeito certo é desligada na semana seguinte. Ver [[largura-de-varchar-derivada-de-enum-nao-nativo]].
