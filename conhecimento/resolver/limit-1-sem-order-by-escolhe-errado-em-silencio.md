## `LIMIT 1` sem `ORDER BY` escolhe errado em silêncio — e o teste por resultado pode não pegar {#limit-1-sem-order-by-escolhe-errado-em-silencio}

`tags: sql, sqlalchemy, order_by, limit, nao-deterministico, sqlite, postgresql, teste-estrutural, teste-por-resultado, migration, backfill, empresa-milionaria`

**Contexto:** duas ocorrências no mesmo projeto, no mesmo dia (Empresa Milionária, Bloco 2 do
plano "Zerar a Fase B", 08-09/09/2026) — uma achada pelo review, outra pelo review cross-Claude
numa migration escrita para consertar a primeira.

**O padrão do defeito:** uma consulta resolve "o registro relacionado" de um `usuario`/`familia`
via `SELECT ... WHERE ... LIMIT 1`, sem `ORDER BY`. Quando existe **exatamente um** candidato, o
código está certo — e é esse o caso que todo teste escrito no caminho feliz exercita. Quando
existem **dois ou mais** (usuário com papel em dois grupos; família com dois usuários que
resolveram grupos diferentes), o `LIMIT 1` devolve **qual deles o plano de execução decidir**, e
isso não é uma regra do domínio — é ordem física de armazenamento, ordem de um índice, ou
qualquer coisa que o otimizador escolher naquele dia. Um valor ERRADO nasce, sem erro, sem aviso,
gravado como se fosse a resposta certa.

**Por que dói mais aqui que num `LIMIT 1` qualquer:** os dois casos reais eram sobre atribuir um
`Grupo` (tenant, FR-025) a um usuário/família — o tipo de dado que, uma vez errado, fica
gravado como fato e alimenta cota, cobrança e isolamento a partir dali.

**O achado que generaliza — testar por RESULTADO pode não discriminar:**

A primeira tentativa de escrever um teste de regressão construía dois candidatos com UUIDs
manuais (um "inserido primeiro", um com "o menor id"), esperando que sem `ORDER BY` o resultado
seguisse a ordem de inserção. **O teste passou mesmo sem o `ORDER BY` no código** — porque o
SQLite, para aquela consulta específica (`JOIN` sobre a chave primária de uma tabela pequena),
escolheu um plano que devolvia os registros na ordem do índice da PK, que por acaso coincidia com
a ordem "certa" que o teste esperava. Um teste que mede o RESULTADO de uma consulta sem `ORDER BY`
está medindo o plano de execução do motor **daquele dia**, não uma garantia do código.

**A correção — teste ESTRUTURAL, não de resultado:**

O jeito que realmente discrimina é interceptar a consulta e conferir a CLÁUSULA SQL emitida, não o
resultado dela:

```python
capturadas = []
executarOriginal = dbSession.execute

async def espiao(statement, *args, **kwargs):
    capturadas.append(statement)
    return await executarOriginal(statement, *args, **kwargs)

monkeypatch.setattr(dbSession, "execute", espiao)
# ... exercita o código ...

sql = str(capturadas_da_consulta_certa)
assert "ORDER BY" in sql.upper()
```

Isso é imune ao plano de execução: não importa o que o SQLite decidir fazer com a consulta, o que
se está conferindo é se o `.order_by(...)` foi de fato encadeado na construção do `Select`.

**Na migration (backfill em produção), o problema tem uma segunda camada:** não basta
`ORDER BY` — é preciso decidir o que fazer quando há AMBIGUIDADE real (dois candidatos legítimos e
diferentes), porque ali não existe "o candidato certo" para ordenar. A correção lá foi resolver em
duas fases (por unidade menor, depois por unidade maior) e só gravar quando as duas concordam;
ambiguidade real vira aviso operacional (`RAISE NOTICE`), nunca escolha arbitrária.

**Regra prática:**

1. Todo `LIMIT 1` sem `ORDER BY` é suspeito — pergunte "o que acontece se houver dois candidatos
   legítimos?", mesmo que o domínio hoje só permita um.
2. Se a resposta é "nunca deveria haver dois", confira se isso é imposto por uma `UNIQUE
   CONSTRAINT` de verdade — `UniqueConstraint(a, b)` não impede múltiplos `b` diferentes para o
   mesmo `a`.
3. O teste de regressão de "isto tem `ORDER BY`" precisa inspecionar a consulta construída, não
   confiar no resultado — sobretudo em SQLite, cujo comportamento sem `ORDER BY` costuma parecer
   mais determinístico do que a especificação garante.
