## Teste de "nenhum segredo em log" fica vermelho pelo log do DRIVE DE BANCO — e o `echo` de dev faz o mesmo em produção {#teste-de-segredo-em-log-pega-o-log-do-driver-de-banco}

`tags: logging, caplog, sqlalchemy, echo, aiosqlite, asyncpg, parametros do sql, segredo em log, credencial cifrada, teste de ausencia, falso vermelho, lgpd`

**Sintoma:** o teste que varre `caplog` (raiz em DEBUG) atrás do segredo acha o valor — e o código sob teste não loga nada
parecido. Pior: rodado duas vezes, o valor achado muda (é aleatório por execução), o que faz parecer flutuação.

**Causa raiz:** com a raiz em DEBUG, os loggers de **banco** registram cada comando **com os parâmetros**: o driver da suíte
(`aiosqlite`: `executing functools.partial(... 'INSERT INTO ...', (...valores...))`) e o `sqlalchemy.engine`. O valor que
"vazou" estava no `INSERT` do **cenário do próprio teste**. Medido em 2026-09-16 (Empresa Milionária, guarda do documento,
Task 9): o texto cifrado da credencial aparecia assim.

**O que isso diz sobre produção:** o SQLAlchemy põe o logger `sqlalchemy` em WARN na importação, então raiz em INFO não
liga o log de SQL. Mas `create_async_engine(..., echo=True)` liga — e é comum `echo` depender de `APP_ENV == "development"`.
Em desenvolvimento, **toda coluna gravada sai no log**, inclusive a que se quer proteger (no caso, a credencial cifrada).

**Por que engana:** o teste está certo em procurar em todos os loggers; o instinto é culpar o código sob teste ou
"desligar o teste". E um diagnóstico com `print`/`sys.__stderr__` não aparece, porque o pytest captura no nível do
descritor — use o relatório de falha (`pytest.fail(..., pytrace=False)`) para ver quem logou.

**Como resolver:**
- Separe o que o teste promete: segredo **em claro** (token, senha) não pode aparecer em logger **nenhum**, inclusive os de
  banco; valor que só é sensível com outra peça (texto cifrado sem a chave, hash) pode ser procurado só nos loggers da
  aplicação — com comentário dizendo quais loggers foram excluídos e por quê, medido.
- Mantenha o controle positivo (um `logger.debug` de propósito com o sentinela tem de aparecer no `caplog`).
- Registre o `echo` de desenvolvimento como risco conhecido: dado sensível gravado em coluna sai no log de dev.

**Como confirmar que era isso:** no relatório da falha, o nome do registro que contém o valor é `aiosqlite` ou
`sqlalchemy.engine...`, e a mensagem é um `INSERT`/`UPDATE` com a tupla de parâmetros.

Relacionado: [[id-no-caminho-da-url-vaza-pelo-log-do-httpx]] · [[uvicorn-root-logger-mudo]].
