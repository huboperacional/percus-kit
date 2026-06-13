---
tipo: guia hands-on (consumer-side)
audiência: devs integrando um produto Percus ao auth-service central
quando-usar: ao implementar login em produto novo OU ao corrigir integração existente
complementa: PADRAO_AUTH_SERVICE.md (contratos, regras, anti-padrões — leia PRIMEIRO)
fonte-canônica: auth-service/docs/CONSUMER_QUICKSTART.md (read-only, cross-repo)
leitura: 6 min
---

# Consumir o auth-service Percus — guia hands-on

> **Pré-requisito:** leia `PADRAO_AUTH_SERVICE.md` antes. Este doc cobre **só o código e o
> wiring** — os contratos, a regra de identidade (B.4), o endpoint `/internal/whatsapp/check`
> (B.5), os error codes e os anti-padrões estão lá. Este doc não os repete.

---

## 0. O que o auth-service entrega

- **OTP combinado (A2):** `POST /otp/request` manda **código 6 dígitos + magic-link** na
  mesma mensagem WhatsApp/email. Responde **`202` imediato** — envio em background (early-202).
- **JWT EdDSA** (Ed25519), access 15 min + refresh opaco 30 d com rotation.
- **Magic-link** com anti-preview-bot (`/w#<code>`, interstitial). Cai no `default_redirect_uri`
  do produto com token no fragmento (`#at=<JWT>&rt=<refresh>`).
- **Branding automático:** mensagens usam `audience.display_name`; nada a fazer no consumidor.

---

## 1. Onboarding da audience (1x por produto, lado auth-service)

PR no auth-service repo com migration Alembic adicionando row em `auth.audiences`:

| Campo | Exemplo |
|---|---|
| `audience` | `meu-produto` (kebab-case) |
| `display_name` | `Meu Produto` |
| `default_redirect_uri` | `https://app.meuproduto.com.br/open` |
| `origins` | `['https://app.meuproduto.com.br']` |

Sem `default_redirect_uri` → combinado dorme (só código). Ver `PADRAO_AUTH_SERVICE.md` Seção D
+ `checklists/CHECKLIST_AUDIENCE_NOVA.md` para o fluxo de PR completo.

---

## 2. Backend — client de referência

Config (`config.py`):
```python
AUTH_SERVICE_URL = "https://auth.huboperacional.com.br"
AUTH_SERVICE_AUDIENCE = "<seu-slug>"
# /run/secrets/internal_key — provisionado pelo auth-service team via Docker Secret
```

### 2.1 — Login (OTP combinado, early-202)

```python
# POST /otp/request — sempre 202, envio em background
await http.post(f"{AUTH_SERVICE_URL}/otp/request", json={
    "channel": "whatsapp",     # ou "email"
    "destination": phone,      # E.164 com + (normalize_phone() antes)
    "audience": AUDIENCE,
})
# Resposta 202: não há desfecho síncrono de erro de provider.
# Se canal alternativo for necessário, ofereça PROATIVAMENTE na UX
# ("não recebeu? tente e-mail") — nunca espere 502/503 (não existem mais).

# POST /otp/validate — valida o código
result = await http.post(f"{AUTH_SERVICE_URL}/otp/validate", json={
    "channel": "whatsapp",
    "destination": phone,
    "code": otp_code,
    "audience": AUDIENCE,
})
# result: {access_token, refresh_token, expires_in, refresh_expires_in}
```

### 2.2 — Validação JWT (local via JWKS, sem RTT)

```python
from percus_auth import PercusAuthVerifier

# Singleton — JWKS buscado 1x e cacheado
verifier = PercusAuthVerifier(AUTH_SERVICE_URL, audience=AUDIENCE)

# deps.py
async def get_current_user(token: str = Depends(bearer)) -> UserLocal:
    claims = verifier.verify(token)   # EdDSA local, sem rede no hot path
    return await resolve_user_local(claims)
```

### 2.3 — Resolução de identidade (regra padrão único — B.4)

```python
async def resolve_user_local(claims: dict) -> UserLocal:
    iid = claims.get("iid")    # UUID; só presente se identidade provisionada
    sub = claims["sub"]        # "canal:handle" — sempre presente

    if iid:
        # Case contra a coluna CANÔNICA (ex.: tasks_identity_id), NUNCA id per-org
        user = await db.users.get_by_identity_id(iid)
        if user:
            return user
    # Fallback pro sub — resiliente a drift/race signup→login
    channel, handle = sub.split(":", 1)
    user = await db.users.get_by_handle(channel, handle)
    if not user:
        raise HTTPException(status_code=401, detail="user not found")
    # Opcional: lazy-populate identity_id quando iid veio mas user foi achado via sub
    if iid and not user.identity_id:
        await db.users.set_identity_id(user.id, iid)
    return user
```

### 2.4 — Signup: provisionar identidade canônica

```python
# Antes do 1º login — chama /internal/identities/v2 (em prod desde 2026-06-08)
result = await http.post(
    f"{AUTH_SERVICE_URL}/internal/identities/v2",
    headers={"X-Internal-Auth": INTERNAL_KEY},
    json={"email": email, "phone": phone, "display_name": name},
)
identity_id = result["id"]   # UUID — persistir na tabela local do produto
```

### 2.5 — Pre-flight WhatsApp (signup/alteração de número, opcional)

```python
# /internal/whatsapp/check — só no signup, NUNCA público
result = await http.post(
    f"{AUTH_SERVICE_URL}/internal/whatsapp/check",
    headers={"X-Internal-Auth": INTERNAL_KEY},
    json={"phone": phone},
)
has_wa = result.get("has_whatsapp")
# True  → número tem WhatsApp → prosseguir normalmente
# False → avisar o user antes de tentar OTP ("este número não tem WhatsApp")
# None  → provider down → fail-open: NUNCA bloqueie o cadastro
```

### 2.6 — Refresh

```python
result = await http.post(f"{AUTH_SERVICE_URL}/otp/refresh", json={
    "refresh_token": rt, "audience": AUDIENCE
})
# Rotation single-use: SERIALIZE no client (2 requests concorrentes invalidam a família)
```

### 2.7 — Mapa de erro frontend (pt-BR)

```typescript
const ERROR_MAP: Record<string, string> = {
  otp_wrong:            "Código errado. Tente o último que você recebeu.",
  otp_expired:          "Código expirou. Vamos enviar outro.",
  otp_locked:           "Muitas tentativas. Aguarde alguns minutos.",
  rate_limited:         "Aguarde um pouco antes de tentar de novo.",
  invalid_audience:     "Audiência inválida — contate o suporte.",
  magic_consumed:       "Este link já foi usado. Peça um novo.",
  magic_expired:        "Este link expirou. Peça um novo.",
  magic_context_mismatch: "Por segurança, abra o link no mesmo dispositivo onde solicitou.",
  unknown:              "Erro inesperado. Tente de novo em alguns segundos.",
}
// Erros whatsapp_* (whatsapp_circuit_open, whatsapp_transient, whatsapp_permanent)
// NÃO acontecem mais via /otp/request (early-202). Não mapeie — ofereça canal
// alternativo proativamente na UX, sem esperar erro síncrono.
```

---

## 3. Frontend — bridge `#at=`

Rota fixa (ex.: `/open`) que consome o token do fragmento (magic-link ou redirect pós-OTP):

```typescript
// Ref: Plexco Tasks /frontend/src/app/open/_components/open-token-consumer.tsx
const hash = location.hash.replace(/^#/, '')
const frag = new URLSearchParams(hash)
const accessToken = frag.get('at')
const refreshToken = frag.get('rt')

// IMPORTANTE: limpar o fragmento antes de redirecionar (sem leak via Referer)
history.replaceState(null, '', location.pathname + location.search)

// Persistir tokens
localStorage.setItem(`${SLUG}_access_token`, accessToken)
if (refreshToken) localStorage.setItem(`${SLUG}_refresh_token`, refreshToken)

// Seguir pro app
location.replace(redirectPath || '/dashboard')
```

**Uso nas chamadas:** `Authorization: Bearer <access_token>`. Em 401, tente
`POST /otp/refresh` (single-use, serialize no client) e refaça; se falhar, mande pro login.

**Fluxo de login (2 passos do ponto de vista do usuário):**
1. `POST /otp/request` → usuário recebe **código + link** na mesma mensagem.
2. Usuário (a) digita o código → `POST /otp/validate` → tokens; ou (b) toca no link →
   interstitial do auth-service consome → 302 pro `default_redirect_uri#at=…&rt=…` →
   rota bridge persiste. Os dois caminhos chegam no mesmo lugar.

---

## 4. Erros & edge cases

- **early-202:** `/otp/request` responde `202` imediato em TODOS os casos. Falha de
  provider não é síncrona. Se a UX dependia de `502/503` de WhatsApp, ela morreu
  silenciosamente — ofereça canal alternativo proativamente na tela de request.
- **Cooldown de re-envio:** 60s por (audience, canal, destino). Mostrar countdown no UI.
- **OTP validate:** `otp_wrong` / `otp_expired` / `otp_locked` (com `retry_after_seconds`).
- **Magic expirado/consumido:** mostrar "sessão inválida, faça login de novo" — o código
  OTP segue valendo como rede de segurança.
- **Refresh single-use:** 2 requests concorrentes com o mesmo refresh → família invalidada
  (anti-theft RFC 6749 §10.4). Serialize o refresh no client.
- **Gotcha device fingerprint:** ao chamar `/auth/magic/issue` diretamente (só pra flows
  com redirect custom), propague `X-Forwarded-For` + `User-Agent` do browser real, não do
  container. O combinado via `/otp/request` não sofre disso (enforce_ua_bind=False).

---

## 5. Checklist de integração

- [ ] Audience registrada (`display_name` + `default_redirect_uri` + `origins`).
- [ ] Per-consumer `X-Internal-Auth` secret provisionado.
- [ ] Backend: `/otp/request` (login) + `/otp/validate` (verify) + `percus-auth` JWT local.
- [ ] Resolução de identidade: `iid` → fallback `sub` → 401 (nunca 404). Coluna canônica.
- [ ] Signup: `/internal/identities/v2` (ou `/v1` com flag de migração).
- [ ] Frontend: rota bridge `/open` consumindo `#at=`/`#rt=`, `history.replaceState`, Bearer + refresh serializado.
- [ ] `audience` consistente em backend + frontend.
- [ ] Erro UX: canal alternativo proativo (sem depender de 502/503 do request).
- [ ] `[5-T]` executado: request → receber código → validate → rota protegida → logout → login de novo.

---

## 6. Referências canônicas

- **Contratos, regras, anti-padrões completos:** `PADRAO_AUTH_SERVICE.md` (leia primeiro).
- **Manual completo com exemplos de prod:** `auth-service/docs/CONSUMER_QUICKSTART.md` (read-only, cross-repo).
- **Consumer de referência (em produção):** `Plexco Tasks` — `backend/app/services/auth_service_client.py`, `backend/app/api/deps.py`, `frontend/src/app/open/`, `frontend/src/lib/auth.ts`.
- **Migração de projeto com auth legado:** `comandos/MIGRAR_AUTH.md` (V5 = path atual).
- **Auditoria de integração existente:** skill `percus-review:auth-consumer`.

---

_Criado em 2026-06-13 (decisões auth 2026-06-12: E0 doc novo restrito, derivado do CONSUMER_QUICKSTART.md). Fonte cross-repo verificada in-repo em 2026-06-12._
