---
name: cookie-audit
description: Use when reviewing or modifying any code that sets HTTP cookies (auth-service, login flows, session middleware, set_cookie/SetCookie calls). Verifies R7 cookie subset — httpOnly + Secure + SameSite=lax — across auth-related files.
---

# Percus — Cookie Audit (R7)

Scanner manual de configuracao de cookies em pasta auth. Quando codigo seta cookie de sessao/JWT/refresh, **todos** os flags abaixo devem estar presentes:

| Flag | Valor obrigatorio | Por que |
|---|---|---|
| `httpOnly` | `True` / `true` | Bloqueia leitura via JS (defesa contra XSS exfil de session) |
| `Secure` | `True` / `true` | Cookie so vai via HTTPS (defesa contra MITM em redes hostis) |
| `SameSite` | `'lax'` (ou `'strict'`) | Bloqueia CSRF cross-site. `lax` permite navegacao top-level; `strict` so mesmo site |
| `domain` | `.<root>.<tld>` (se SSO) | SSO multi-subdomain so com domain pai. Senao omitir |
| `max_age` ou `expires` | declarado | Sem isso vira session cookie (some ao fechar browser). Depende do caso |

## Quando rodar

- Antes de commitar mudancas em arquivos sob `**/auth/`, `**/auth_service/`, `**/middleware/`, `**/api/login*.py`, `**/routes/auth*`.
- Antes de fechar marco que tocou login/logout/refresh flow.
- Como auditoria periodica em projeto que ja tem auth deployado.

## Fluxo

### 1. Listar chamadas que setam cookie

**FastAPI / Starlette:**
```bash
grep -rn "set_cookie" execution/ services/ app/ 2>/dev/null | grep -v test_
```

**Flask:**
```bash
grep -rn "set_cookie\|make_response" execution/ 2>/dev/null
```

**Next.js / TS:**
```bash
grep -rn "cookies()\|setCookie\|res.cookie" app/ services/ 2>/dev/null | grep -v test
```

### 2. Para cada chamada, checar os 3 flags obrigatorios

Exemplo CORRETO (FastAPI):
```python
response.set_cookie(
    key="session",
    value=token,
    httponly=True,
    secure=True,
    samesite="lax",
    domain=".huboperacional.com.br",  # SSO multi-subdomain
    max_age=60 * 60 * 24 * 7,
)
```

Exemplo INCORRETO (faltam flags):
```python
response.set_cookie("session", token)  # httponly default False, secure False
```

### 3. Reportar achados

Formato:
```
[cookie-audit] <slug-projeto>
  ✓ <N> chamadas conformes
  ⚠ <file>:<linha> -> faltam: [httponly, secure, samesite] :: <snippet>
  ⚠ ...
```

Se nenhum achado: `[cookie-audit] OK — N chamadas auditadas, todas conformes`.

## Falsos positivos comuns

- **Cookies de tracking / consent banner** — geralmente nao precisam de httpOnly (precisam ser lidos via JS). Tag com `# cookie-audit: skip motivo=consent-banner` na linha acima.
- **Cookies de teste** em arquivos `tests/` ou `test_*.py` — ignorar (skill nao escaneia esses por default).
- **Cookies de framework** (NextAuth `__Secure-next-auth.session-token`) — vetado por R7 inteiro; cookie-audit nao se aplica.

## Anti-padroes

- Setar `httponly` mas esquecer `secure` → cookie vai por HTTP em dev e leak em man-in-the-middle.
- Usar `SameSite=none` sem motivo justificado em ADR → quebra defesa CSRF.
- `domain` apontando pra `huboperacional.com.br` sem o ponto na frente — cookie nao compartilha entre subdomains.
- Cookie de auth com `max_age` muito alto (>30 dias) sem rotation → roubo de session vira persistente.

## Referencias

- Canon: `_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md` R7 (cookies subset).
- Padrao SSO: `_Novo_Projeto/02_INFRA_E_STACK_PERCUS.md` secao "Auth multi-domain".
- Implementacao referencia: `auth-service/services/api/app/routers/login.py` (usar como template).

## Auto-trigger

Nao auto-disparado. Skill manual. Invoque quando:
- Sessao tocou `**/auth/`, `**/middleware/auth*`, login/logout/refresh.
- Pre-commit em PR de auth-service.
- Auditoria mensal de seguranca (rodar em todos os projetos).
