## Id e nome no CAMINHO da URL vazam pelo log INFO do `httpx` — e o teste de log do módulo não vê {#id-no-caminho-da-url-vaza-pelo-log-do-httpx}

`tags: httpx, logging, pii, lgpd, google drive, id de arquivo, url, caplog, filtro de log, logging.Filter, teste de ausencia, controle positivo`

**Sintoma:** o cliente HTTP novo não loga nada além de operação, status e duração, e o teste "nenhum log contém o
segredo" passa. Mesmo assim, em produção, o id do arquivo e o nome da pasta (razão social e CNPJ) aparecem no log.

**Causa raiz:** o `httpx` emite, pelo logger próprio `httpx`, `HTTP Request: <método> <URL completa> "<status>"` em INFO
para **toda** requisição (medido em 2026-09-16, `httpx` 0.28.1). Em API REST o dado não está só na query:
`/drive/v3/files/<id>` leva o id no **caminho**, e a busca de pasta leva o nome no `q`. Se a raiz do logging está em INFO
(ex.: `logging.basicConfig(level=logging.INFO)` no boot), a linha sai. O teste que captura só o logger do módulo nunca a vê.

**Por que engana:** a revisão procura `logger.` no arquivo novo e não acha nada perigoso. E o verbete irmão
[[uvicorn-root-logger-mudo]] fala de dado pessoal em **query param** — quem lê pensa em `?phone=`, não em id no caminho.

**Como resolver:**
- **Teste de log pela raiz**, não pelo logger do módulo: `caplog.set_level(logging.DEBUG)` e varrer `caplog.records` de
  todos os nomes por sentinelas (segredo, token, nome, id), exercitando sucesso **e** falha. Com **controle positivo**: um
  `httpx.get` de verdade (sob `respx`) com o sentinela na URL tem de aparecer no `caplog` — senão o teste de ausência pode
  estar verde porque não captura nada.
- **Conserto estreito ou largo, escolha declarada.** O irmão sobe `httpx`/`httpcore` para WARNING (cala tudo). Quando o
  log das outras integrações é útil, um `logging.Filter` no logger `httpx` que descarta só as linhas cuja URL
  (`record.args` traz um `httpx.URL`) casa host e prefixo de caminho do serviço sensível. Instale **uma vez** (confira se o
  filtro já está em `logger.filters`) e teste que outro host **continua** logado.
- O `httpcore` loga em DEBUG sem a URL; sob `respx` ele nem roda, então o teste não o cobre — declare.

**Como confirmar que era isso:** uma requisição com a raiz em DEBUG e `logging.basicConfig` imprime a linha
`httpx INFO HTTP Request: ...` com o caminho inteiro.

**Ref:** Empresa Milionária, guarda do documento lido, Task 6 (2026-09-16) —
`empresa-api/app/modules/guarda_documento/cliente_http.py` (`_SemUrlDoDrive`) e
`empresa-api/tests/pj/test_cliente_drive_http.py` (três testes de log). Relacionado: [[uvicorn-root-logger-mudo]].
