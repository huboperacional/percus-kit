## Preciso verificar que uma página admin/dashboard renderiza, mas o MCP de browser caiu / precisa login {#render-smoke-in-container}

`tags: render smoke container docker admin dashboard browser login template`

tags: render smoke, dashboard, admin page, browser mcp down, playwright, chrome-devtools, sem login, verificar tela, FastAPI, Jinja, TemplateResponse, super_admin, monkeypatch estado

**Contexto:** precisa provar que uma página admin (FastAPI + HTMX + Jinja) renderiza sem erro e contém os elementos esperados, mas (a) o MCP de browser (chrome-devtools/playwright) desconectou na sessão, ou (b) a página exige login/OTP que não dá pra completar headless.

**Causa raiz:** o handler da rota é uma função async normal; o `Depends(requireAuth)` só injeta a `session`. Chamando o handler DIRETO você pula o auth e não precisa de cookie/OTP nem de browser.

**Solução (render smoke in-container, sem browser):**
1. Script Python rodado NO container de prod (`docker cp` + `docker exec python` + `rm`), processo SEPARADO do uvicorn (não afeta o server vivo).
2. Monta um `starlette.requests.Request` mínimo: `Request({"type":"http","method":"GET","path":"/admin/x","raw_path":b"/admin/x","query_string":b"","root_path":"","headers":[(b"host",b"dominio")],"scheme":"https","server":("dominio",443),"client":("127.0.0.1",0),"state":{}})`.
3. Chama `await rotas.handler(request=req, session={"role":"super_admin","tenantId":"<t>"})` — o handler roda `buildPageContext`+render de verdade; `resp.body.decode()` tem o HTML. Assert por marcadores (`'Faturamento' in body`, `'data-tab="x"' in body`, status 200).
4. **Forçar um ESTADO condicional do template** (ex.: caixa fechado, feature-flag off) sem mutar dado real: monkeypatch do data-provider no próprio processo do smoke — ex. `rotas.svc.getRegisterView = lambda tid: {"open": False, ...}`. Só afeta o script, não o server. Renderiza os dois estados e checa cada um.

**Gotchas:** (a) precisa de `session` com `role`/`tenantId` que o `resolveTenantId` da app aceite (super_admin resolve por `?tenant_id`>cookie>session.tenantId); (b) rota com query params (`request.query_params.getlist(...)`) exige `query_string` no scope (use `b""`); (c) para tela que só aparece com um pré-requisito (caixa aberto), OU semeia o pré-requisito OU monkeypatcha o provider como no passo 4; (d) NÃO é substituto de eyeball de pixel — valida render/estrutura/dados, não CSS visual (deixar o eyeball pro operador).

**Ref:** tiatendo F4 "Fechamento do dia" — render smoke de `/admin/caixa`, `/admin/orders`, `/admin/fechamento` (2026-07-15); `project-f4-fechamento-do-dia-2026-07-15`.
