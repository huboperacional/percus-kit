## "Erro de conexão" no front que é, na verdade, um 500 do backend {#erro-de-conexao-e-500-sem-cors}

`tags: cors, fastapi, starlette, 500, fetch, failed to fetch, network error, erro de conexao, unhandled exception, asyncpg, UndefinedColumnError, middleware`

**Contexto:** login (OTP) do painel mostrava "Erro de conexão. Verifique sua internet" com código válido, mas só nesse caminho. `curl` do endpoint com payload dummy dava 401 **com** headers CORS (normal). A tela mentia: não era rede.

**Causa raiz:** o `catch` de um `fetch` cross-origin dispara "Erro de conexão" quando o browser **bloqueia a resposta por falta de CORS** — não só em rede caída. No FastAPI/Starlette, `HTTPException` tratada volta pelo `ExceptionMiddleware` → passa pelo `CORSMiddleware` → **ganha** os headers CORS (fetch lê o status). Mas uma **exceção não-tratada** sobe até o `ServerErrorMiddleware` (o mais externo, acima do CORS) → 500 **sem** headers CORS → o browser rejeita como erro de rede → `fetch` **lança** → cai no `catch`. No caso real: `asyncpg.UndefinedColumnError` (coluna faltando após migration não-aplicada) só no caminho de código válido.

**Solução:** (1) diagnóstico — se o front diz "erro de conexão" mas o endpoint responde via `curl`, cheque o **status + headers CORS** da resposta real do fluxo que falha (dummy vs válido divergem quando o crash é depois da validação). 500-sem-`Access-Control-Allow-Origin` = crash não-tratado. (2) fix na raiz (a exceção). (3) defesa: envolver o trecho arriscado e converter em `HTTPException` (que ganha CORS) pra o erro chegar legível no front, nunca como "erro de conexão".

**Ref:** Painel Gestão admin login B3 (2026-07-14); `execution/api/adminAuth/adminVerifier.py` + `migration008`.
