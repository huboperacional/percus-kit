## `fileConfig` do Alembic desliga os loggers da aplicação e o teste de "nada vazou no log" passa vazio em lote {#alembic-fileconfig-desliga-loggers-e-teste-de-log-passa-vazio}

`tags: alembic, env.py, fileConfig, dictConfig, disable_existing_loggers, logger.disabled, caplog, pytest, controle positivo, teste de log, vazamento, segredo, isolamento de suíte, R23`

**Sintoma:** um teste com `caplog` que afirma "o segredo não aparece no log" passa sozinho e falha em lote — ou, pior, passa
nos dois, vazio. O controle positivo (logar o sentinela de propósito e ver que o `caplog` pega) só aparece vermelho em lote.

**Causa:** o `alembic/env.py` gerado pelo `alembic init` chama `fileConfig(config.config_file_name)`, cujo padrão é
`disable_existing_loggers=True`. Um teste que roda a migration **no mesmo processo** da suíte (`command.upgrade(cfg, "head",
sql=True)` para renderizar offline, por exemplo) marca `disabled=True` em todo logger já criado — os `logging.getLogger(__name__)`
dos módulos da aplicação, importados pela coleta. Dali em diante esses loggers não emitem nada, e `caplog.set_level(DEBUG)`
não os religa (`set_level` mexe em nível, não em `disabled`).

**Caso concreto, medido em 16/09/2026 (Empresa Milionária, guarda do documento, Tasks 10–12):** em lote com
`test_modelo_guarda_documento.py`, `logging.getLogger("app.casos_uso.conexao_drive").disabled == True`; o controle positivo de
`test_code_e_verificador_nao_vazam_em_log_nem_resposta` ficou vermelho (`'CODIGO…' in ''`). Um segundo teste usava como
controle `logging.getLogger("controle.positivo")` — logger **novo**, nunca desligado — e por isso passaria vazio em lote.

**Conserto:** fixture (não `autouse`) que religa só durante o teste os loggers desligados:

```python
@pytest.fixture
def loggersReligadosAposFileConfig(monkeypatch):
    for logger in list(logging.root.manager.loggerDict.values()):
        if isinstance(logger, logging.Logger) and logger.disabled:
            monkeypatch.setattr(logger, "disabled", False)
```

E o controle positivo emite pelo **logger do módulo sob teste** (`modulo.logger`, não um nome literal nem um logger novo).
Sabotagem que prova o controle: `logger.setLevel(logging.CRITICAL)` no módulo → o controle fica vermelho. (Sabotar com
`logger.disabled = True` não prova nada: a fixture religa.)

**Produção:** não sofre se a migration roda em processo separado do servidor (`alembic upgrade head` antes do `uvicorn`).
Sofre se a aplicação rodar a migration programaticamente no startup — aí todo log da aplicação some. Alternativa na origem:
`fileConfig(..., disable_existing_loggers=False)` no `env.py`.
