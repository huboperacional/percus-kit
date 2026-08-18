## Teardown de teste não consegue dropar tabela com FK auto-referencial: desligue a checagem, em AUTOCOMMIT {#drop-table-fk-auto-referencial-no-teardown}

tags: sqlite, PRAGMA foreign_keys, drop_all, teardown, FOREIGN KEY constraint failed, FK composta, auto-referencia, StaticPool, conftest, erro aparece no teste seguinte

**Sintoma:** o teardown da suíte estoura `FOREIGN KEY constraint failed` num `DROP TABLE`, e o
erro aparece no **setup do teste seguinte** — longe da causa. Some quando você roda o teste
sozinho, porque sozinho ele não deixa dado commitado para trás.

**Causa:** a tabela tem FK **auto-referencial** (linha que aponta para outra linha da mesma
tabela — contra-lançamento, hierarquia, versão anterior), e o SQLite verifica FK no DELETE
implícito do `DROP TABLE`. Com FK **composta** o caso é ainda mais fácil de disparar. Só afeta
teste que **commita**: os que trabalham em transação e dão rollback nunca deixam a linha lá.

**Solução — desligar a checagem só para derrubar as tabelas:**

```python
conexao = await ENGINE.connect()
conexao = await conexao.execution_options(isolation_level="AUTOCOMMIT")
try:
    await conexao.exec_driver_sql("PRAGMA foreign_keys=OFF")
    await conexao.run_sync(Base.metadata.drop_all)
finally:
    await conexao.exec_driver_sql("PRAGMA foreign_keys=ON")   # OBRIGATÓRIO
    await conexao.close()
```

**Dois detalhes que decidem se funciona:**

- **`AUTOCOMMIT` não é enfeite.** Dentro de uma transação o SQLite **ignora** este PRAGMA em
  silêncio — sem erro, sem aviso, e a checagem continua valendo 1. Confira lendo
  `PRAGMA foreign_keys` depois de desligar.
- **Religar é obrigatório, e merece trava.** Com `StaticPool` (o padrão para SQLite in-memory
  em teste) a conexão é **uma só** para a sessão inteira: uma FK deixada desligada não volta
  sozinha, e todo teste de integridade referencial que rodar depois passa **sem exercer
  constraint nenhuma** — verde e vazio. Ponha no setup um
  `assert (PRAGMA foreign_keys) == 1` com mensagem explicando; ele custa uma query por teste e
  derruba na hora quem esquecer.

**Ref:** Empresa Milionária, Task 15 da Fase A, 2026-08-13 — `baixas` com
`(baixa_estornada_id, empresa_id) → baixas` (contra-baixa do ADR-0007 sobre FK composta do
ADR-0008). Entrada irmã: `#preparo-de-teste-limpa-so-o-que-conhece`.
