## Limpeza de fixture sob RLS não apaga nada — e o erro estoura no INSERT seguinte, culpando o lugar errado {#delete-sob-rls-nao-apaga-erro-no-insert}

tags: duplicate key violates unique constraint pkey, fixture postgres RLS, DELETE nao apaga,
row level security FORCE, teste passa isolado falha em sequencia, preparo de teste multi-tenant

**Sintoma:** num arquivo de teste contra PostgreSQL com RLS, os primeiros testes passam e os
seguintes morrem **no preparo**, com `duplicate key value violates unique constraint "<t>_pkey"`.
O INSERT acusado é o mesmo que funcionou no primeiro teste. Rodar o teste isolado passa.

**Causa raiz:** a fixture limpa com `DELETE FROM <tabela>` **antes** de declarar o contexto de
tenant. Com `FORCE ROW LEVEL SECURITY`, a política não torna nenhuma linha visível — e `DELETE`
sem linha visível **afeta 0 linhas e retorna com sucesso**. Não há erro, não há aviso: a limpeza
simplesmente não aconteceu. O primeiro teste passa porque o banco estava vazio; o segundo tenta
inserir a mesma PK e estoura.

A mensagem aponta para o **INSERT**, que está correto. O defeito é o DELETE silencioso, três
linhas acima.

**Solução:** toda limpeza de tabela com política vai **dentro do contexto**, e na ordem das FKs:

```python
for empresa in (EMPRESA_A, EMPRESA_B):
    await definirEmpresaDaTransacao(s, empresa)   # <- primeiro o contexto
    await s.execute(text("DELETE FROM titulos"))          # filho
    await s.execute(text("DELETE FROM recorrencias_pj"))  # pai do filho
    await s.execute(text("DELETE FROM pessoas"))          # avô
    await s.commit()
```

Lembre que o contexto é `SET LOCAL`: ele **morre no commit**, então cada bloco transacional
precisa redeclará-lo.

**Alternativa mais grossa, quando serve:** zerar o schema inteiro entre módulos
(`DROP SCHEMA public CASCADE`), que não depende de política nenhuma — é o que o preparo de
schema do Percus faz. `DELETE` seletivo só vale a pena quando recriar o schema é caro.

**Parente próximo:** a mesma cegueira em leitura produz o oposto — resposta **vazia** confundida
com sucesso. Por isso a prova de que o contexto chegou é sempre o **caso positivo** (o dado da
própria empresa aparecendo), nunca "o vizinho não apareceu".

**Ref:** Empresa Milionária, Fase B Task 6, 2026-08-14.
