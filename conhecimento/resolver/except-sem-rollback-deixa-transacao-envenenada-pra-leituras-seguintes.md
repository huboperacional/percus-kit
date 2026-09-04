## `except Exception` que degrada um degrau aditivo sem `rollback()` deixa a transação envenenada pras leituras seguintes {#except-sem-rollback-deixa-transacao-envenenada-pra-leituras-seguintes}

tags: sqlalchemy, asyncpg, asyncsession, rollback, pendingrollbackerror, transacao envenenada, degradacao graciosa, except exception, review adversarial, mutante python vs sql

**Sintoma:** um endpoint de relatório lê vários degraus de dado em sequência na MESMA
`AsyncSession`/transação (venda → reunião → leads → campanhas órfãs → ...). Um dos degraus é
ADITIVO — se ele falhar, o requisito é degradar SÓ aquele degrau (setar um `*Indisponivel` e
seguir), não derrubar o relatório inteiro, porque os degraus anteriores já leram com sucesso. O
código escreve exatamente esse `try/except Exception: log(...); setar_estado_degradado()` — parece
certo, os testes passam.

**Causa raiz:** o `except` captura a exceção e monta o estado degradado, mas nunca chama
`await session.rollback()`. Numa `AsyncSession` sem autocommit, se a falha for um erro **de SQL**
(não um erro Python injetado por mock/patch), o Postgres aborta a transação do lado do servidor —
e TODA chamada `execute()` seguinte na MESMA sessão levanta `PendingRollbackError` até alguém
rodar `rollback()`. Os degraus que vêm DEPOIS do `except` (nesta sessão: busca por campanha via
click id, taxas de câmbio, campanhas do cliente, totais por conta, órfãs) não têm proteção
nenhuma contra isso — o relatório inteiro cai em 500 mesmo assim, exatamente o resultado que o
`try/except` foi escrito pra evitar.

**Por que os testes não pegaram:** os dois testes que exercitam esse `except` injetam a falha via
`monkeypatch`/`AsyncMock` levantando um `RuntimeError` Python puro de uma função que nunca toca a
sessão real — então o `except` "funciona" (captura, degrada, o teste passa), mas o cenário que
importa (a sessão real fica com transação abortada) nunca é criado. Um teste que só prova "o
`except` captura" não prova "a leitura sobrevive à falha real" — são afirmações diferentes, e só
a segunda é o requisito.

**Solução:** todo `except` que existe pra degradar-e-continuar numa sessão de banco compartilhada
com leituras posteriores precisa de `await session.rollback()` como a PRIMEIRA linha do bloco,
antes de montar qualquer estado. Isso é seguro mesmo quando a falha não foi de banco (rollback
numa sessão sem transação pendente é no-op) e não quebra teste nenhum (`AsyncMock().rollback()`
também é no-op). Pra provar que o fix funciona de verdade, é preciso PELO MENOS UM teste que
injete uma falha real de SQL (ex.: `SELECT 1 FROM tabela_que_nao_existe`) contra Postgres real —
não um `RuntimeError` mockado — e confirme que os degraus seguintes ainda respondem depois. Ao
revisar um `except Exception` num pipeline de leitura sequencial na mesma sessão, sempre perguntar
"e se a EXCEÇÃO for erro de banco, não erro Python — este bloco ainda entrega a garantia que
promete?" — foi essa pergunta, feita pelo reviewer numa segunda passada adversarial, que achou o
gap aqui depois que a primeira passada (implementador + DeepSeek) já tinha aprovado o código.

**Achado relacionado, mesma classe, não corrigido no mesmo lugar (falta de tempo/escopo, não de
entendimento):** um `except Exception` irmão, no mesmo arquivo, que degrada a leitura de
"campanhas órfãs" (um degrau que roda por último no pipeline) tem o MESMO padrão sem rollback —
inofensivo hoje porque não há leitura depois dele nesta função específica, mas frágil a qualquer
refactor que adicione um degrau novo depois. Vale auditar todo `except Exception: degradar_e_
seguir()` de um arquivo assim que outro exemplar aparecer, não só corrigir um de cada vez.
