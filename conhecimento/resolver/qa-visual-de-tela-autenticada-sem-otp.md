## QA visual de tela autenticada sem OTP real (dashboard com login por telefone/magic-link) {#qa-visual-de-tela-autenticada-sem-otp}

`tags: QA visual, screenshot, tela autenticada, OTP, magic-link, JWT, dependency_overrides, FastAPI, ASGITransport, container de producao`

**Sintoma:** precisa validar visualmente (screenshot real, não leitura de CSS) uma tela do painel
que exige login (OTP WhatsApp / JWT de auth-service externo), e não há como receber o OTP
programaticamente nem forjar o JWT (chave de assinatura vive num serviço externo).

**Solução:** o próprio FastAPI permite `app.dependency_overrides[requireAuth] = lambda: {...sessão
fake...}` — mesmo padrão que os testes de rota já usam (`tests/dashboard/test_xss_conversation_list.py`).
Rodar dentro do container de produção (mesmo banco, dado real, sem precisar de DB local):
1. Override da dependência de auth, request via `httpx.AsyncClient(transport=ASGITransport(app=...))`
   contra a rota de página inteira (não só o endpoint JSON) — devolve o HTML final igual ao usuário
   veria.
2. Salvar o HTML + baixar (`docker cp`) só as pastas `static/css`, `static/js`, `static/img`
   referenciadas (nunca a pasta `static/` inteira — pode ter dezenas de MB de upload de tenant que
   não tem nada a ver com a tela).
3. Servir localmente (`python -m http.server` na pasta que espelha os paths absolutos `/admin/...`
   do HTML) e apontar Playwright/Chrome DevTools MCP pra lá.

**Armadilha**: a sessão fake precisa de um `role` que EXISTA no mapa de abilities do RBAC (`super_admin`
faz bypass de tudo; qualquer outro precisa bater um `ROLE_ABILITIES` real — `"owner"` não existe nesse
projeto, o role de dono é `"tenant_admin"`) — usar um role inventado quebra com 403 `"missing ability"`
sem dizer o motivo real (parece erro de tenant, é erro de nome de role).

**Trade-off:** o HTML capturado é um snapshot; qualquer chamada HTMX/fetch subsequente (buscar lista
de conversas, etc.) vai falhar se a sessão fake não tiver CSRF token real — serve pra validar LAYOUT/CSS
estático, não pra testar interação viva. Pra isso, ainda é preciso login real.

**Ref:** tiatendo, sessão 2026-08-07 (validação da rota `/conversations` durante reskin visual).
