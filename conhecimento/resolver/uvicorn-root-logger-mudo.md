## Log de diagnóstico "no ar" que nunca emitiu: sob uvicorn o root logger é mudo {#uvicorn-root-logger-mudo}

tags: logging, uvicorn, fastapi, root logger, lastResort, log.info sumiu, observabilidade, sonda, diagnostico, pii, mascara, httpx, ast, grep multi-linha

**Contexto:** shipamos uma sonda (`log.info` com as chaves de um payload) pra responder uma pergunta de contrato cross-product. Dois dias em prod, tráfego chegando (202 no access-log), e **zero linha da sonda**. O HANDOFF registrava "viva mas sem dado — só produz quando alguém responder", e a sessão seguinte ia esperar mais. Vale pra qualquer serviço FastAPI+uvicorn do kit.

**Causa raiz:** o uvicorn configura **só** os loggers `uvicorn`, `uvicorn.error` e `uvicorn.access`. O **root ele não toca** — fica em `WARNING` com `handlers = []`. Como todo módulo usa `logging.getLogger(__name__)` (level `NOTSET`, herda o root), **todo `log.info` da aplicação é descartado**. No projeto eram **98 chamadas** invisíveis, não só a sonda. O que engana é que o log de prod *parece* saudável: aparecem o access-log do uvicorn e os `WARNING`+ da app — mas estes últimos saem pelo `logging.lastResort` (stderr), não por handler configurado. Ou seja, "tem log" não é prova de que o SEU log existe.

**Solução:** (a) **verifique RODANDO, não lendo** — `docker exec $CID python -c "import logging,logging.config; from uvicorn.config import LOGGING_CONFIG; logging.config.dictConfig(LOGGING_CONFIG); import app.main; lg=logging.getLogger('app.x.y'); print(logging.getLevelName(lg.getEffectiveLevel()), logging.getLogger().handlers, lg.isEnabledFor(logging.INFO))"` — `WARNING [] False` denuncia; (b) um `logging_setup.setup_logging()` chamado no **import do `main`** (roda depois do `dictConfig` do uvicorn, que acontece antes de importar a app) somando handler no root, com level via env.

⚠️ **Duas armadilhas DENTRO do fix**, que precisam ser tratadas junto senão ele cria problema pior:

1. **Ligar INFO no root liga as libs junto.** O `httpx` emite `HTTP Request: GET <url>` por chamada — e se algum client manda dado pessoal em **query param** (no nosso caso telefone em `/user/info?phone=…`), o fix repõe no log exatamente o PII que a máscara tira. Trave `httpx`/`httpcore` em `max(nivel, WARNING)`. Confira também volume: `log.info` dentro de loop de worker sem guarda inunda.
2. **Varredura de PII tem que ser AST, não `grep`.** `grep` de uma linha não enxerga chamada de log quebrada em várias linhas — foi assim que 6 vazamentos (5 de e-mail) passaram batido numa varredura manual, e só apareceram ao trocar por `ast.walk` sobre as chamadas `log.*`. Vire teste, não checklist. E ao aplicar máscara em massa, **conte as ocorrências antes**: num arquivo nosso havia 5 `"phone": phone` e só 4 eram log — a 5ª era o envelope mandado a outro produto, contrato congelado. Substituição cega por string teria quebrado o consumidor calado.

**Ref:** Plexco Tasks s149 (2026-07-25); `backend/app/logging_setup.py`, `backend/app/utils/log_redact.py`, `backend/tests/test_log_sem_pii.py`; memória `reference_uvicorn_nao_configura_root_logger`. Parente de [#verificar-runtime-nao-estrutura](verificar-runtime-nao-estrutura.md) e [#red-nunca-visto-embarca-fossil](red-nunca-visto-embarca-fossil.md) — o teste da sonda passava porque logava `sorted(keys)` e teria passado com qualquer nome de chave.

---


---
