# Migration Kit — adoção de `percus-auth` em `{slug_projeto}`

> Substitua `{placeholders}` ao copiar pra um projeto consumidor.
> Apague esta linha de instrução depois.

## O que este kit entrega

Um caminho concreto pra `{slug_projeto}` parar de fazer auth próprio (legacy/mock/Supabase/GoTrue/sidecar) e passar a consumir o **auth-service Percus** via lib `percus-auth`. Validação JWT 100% local em cada projeto, zero RTT por request autenticado, single source of truth pra identidade/OTP/magic-link/refresh/SSO.

Pré-requisitos (verificar antes de começar):
- [ ] auth-service v1+ rodando em `https://auth.huboperacional.com.br`
- [ ] `GET /health` retorna `200 {"status":"ok"}` do projeto consumidor
- [ ] `GET /.well-known/jwks.json` retorna OKP/Ed25519 (lê-se via `curl`)
- [ ] Projeto tem Postgres compartilhado da VPS (ou DB próprio onde lazy upsert vai gravar)
- [ ] Projeto tem Redis compartilhado (namespace `{slug_projeto}:*`)
- [ ] Domínio do projeto está no apex compartilhado (`huboperacional.com.br` ou `ads4pros.com`) **ou** vai usar redirect-fragment SSO (R16)

---

## Step 0 — Audience: default vs própria

Cada projeto Percus consome auth como uma **audience** registrada em `auth.audiences`. Decidir agora:

### Opção A — Usar audience default Percus

Use quando:
- Projeto interno do estúdio sem requisitos especiais de delivery WhatsApp
- Volume baixo (<500 OTPs/dia)
- Sem necessidade de templates customizados ou número dedicado

Configuração:
```bash
# .env
PERCUS_AUTH_AUDIENCE={slug_projeto_existente_no_seed}
# audiences seeded: painel, familia, paid-media, plexco-coach, plexco-tasks
```

Sem ação adicional no auth-service. A audience já existe.

### Opção B — Criar audience própria

Use quando:
- Projeto precisa de Evolution instance dedicada (volume alto, SLA)
- Compliance exige número WhatsApp separado
- Vai migrar pra Cloud API em breve (critérios da Seção 2.4 do INFRA)

Operação no auth-service (admin com TOTP step-up):
```bash
# 1. Login admin + step-up TOTP
ADMIN_AT=$(curl -s -X POST https://auth.huboperacional.com.br/admin/totp/verify \
  -H "Content-Type: application/json" \
  -d '{"subject":"admin@percus","totp_code":"<6 digit code>"}' \
  | jq -r .access_token)

# 2. Criar audience
curl -X POST https://auth.huboperacional.com.br/admin/audiences \
  -H "Authorization: Bearer $ADMIN_AT" \
  -H "Content-Type: application/json" \
  -d '{
    "slug": "{slug_projeto}",
    "name": "{Nome Legivel}",
    "whatsapp_provider": "evolution",
    "whatsapp_config": {
      "instance": "{instancia_dedicada_ou_Auth_Todos}",
      "number": "+55{ddd}{numero}"
    }
  }'
```

Configuração no projeto:
```bash
# .env
PERCUS_AUTH_AUDIENCE={slug_projeto}
```

---

## Step 1 — Backend: instalar lib + middleware

### Python (FastAPI default Percus)

```bash
# requirements.txt ou pyproject.toml
pip install https://auth.huboperacional.com.br/dist/percus_auth-0.1.0-py3-none-any.whl
```

```python
# services/api/app/core/auth.py
from percus_auth import PercusAuth

percus = PercusAuth(
    jwks_url="https://auth.huboperacional.com.br/.well-known/jwks.json",
    issuer="https://auth.huboperacional.com.br",
    audience="{slug_projeto}",  # ou env var
)
```

```python
# services/api/app/main.py
from fastapi import Depends
from percus_auth.fastapi import bearer_auth
from app.core.auth import percus

@app.get("/me")
async def me(claims = Depends(bearer_auth(percus))):
    return {"sub": claims.sub, "roles": claims.roles}
```

### Node (Express ou Next.js)

```bash
npm install https://auth.huboperacional.com.br/dist/percus-auth-0.4.0.tgz
```

```ts
// src/lib/auth.ts
import { PercusAuth } from "@percus/auth"

export const percus = new PercusAuth({
  jwksUrl: "https://auth.huboperacional.com.br/.well-known/jwks.json",
  issuer: "https://auth.huboperacional.com.br",
  audience: "{slug_projeto}",
})
```

```ts
// Express middleware
import { bearerAuth } from "@percus/auth/express"
import { percus } from "./lib/auth"

app.get("/me", bearerAuth(percus), (req, res) => {
  res.json({ sub: req.percus.sub, roles: req.percus.roles })
})
```

```ts
// Next.js (App Router) API route
import { validateBearerFromRequest } from "@percus/auth/next"
import { percus } from "@/lib/auth"

export async function GET(request: Request) {
  const claims = await validateBearerFromRequest(percus, request)
  if (!claims) return new Response("unauthorized", { status: 401 })
  return Response.json({ sub: claims.sub, roles: claims.roles })
}
```

---

## Step 2 — Frontend: fluxo de login

### Fluxo OTP direto (mais simples — projeto no mesmo apex que auth-service)

```ts
// 1. Solicitar OTP
const requestRes = await fetch("https://auth.huboperacional.com.br/otp/request", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  credentials: "include",
  body: JSON.stringify({
    channel: "whatsapp",
    destination: phoneE164,
    audience: "{slug_projeto}",
  }),
})

// 2. Validar código + receber JWT (cookie httpOnly setado automaticamente)
const validateRes = await fetch("https://auth.huboperacional.com.br/otp/validate", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  credentials: "include",
  body: JSON.stringify({
    channel: "whatsapp",
    destination: phoneE164,
    code: userInputCode,
    audience: "{slug_projeto}",
  }),
})
const { access_token, refresh_token } = await validateRes.json()
```

### Fluxo SSO redirect-fragment (cross-domain, R16)

Quando `{slug_projeto}` está em apex diferente de `huboperacional.com.br`:

```ts
// 1. Redireciona pro auth-service
window.location.href =
  `https://auth.huboperacional.com.br/sso?return_url=${encodeURIComponent(window.location.href)}&audience={slug_projeto}`

// 2. Após login, auth-service redireciona de volta com #at=<jwt> no fragment
// Na página de retorno:
const params = new URLSearchParams(window.location.hash.slice(1))
const accessToken = params.get("at")
if (accessToken) {
  // Salvar em memória (NÃO localStorage) ou cookie httpOnly via endpoint dedicado
  history.replaceState(null, "", window.location.pathname)  // limpa hash
}
```

### Fluxo magic-link (first-login, convite, reset)

```ts
// Backend emite (com Bearer admin):
const issueRes = await fetch("https://auth.huboperacional.com.br/auth/magic/issue", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${adminAt}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    email: "user@example.com",
    purpose: "first_login",
    redirect_uri: "https://{slug_projeto}.huboperacional.com.br/welcome",
    ttl_seconds: 172800,  // 48h
  }),
})
const { url } = await issueRes.json()
// Envia url via email/WhatsApp pro usuário

// Quando usuário clica em url, vai pra:
//   https://auth.huboperacional.com.br/w/<code>
// auth-service valida e 302 redireciona com #at=<jwt> no fragment.
```

---

## Step 3 — Smoke E2E (R1 — ciclo CRUD)

```bash
# 1. Pedir OTP no número de teste
curl -X POST https://auth.huboperacional.com.br/otp/request \
  -H "Content-Type: application/json" \
  -d '{"channel":"whatsapp","destination":"+55{ddd}{numero}","audience":"{slug_projeto}"}'

# 2. Receber código no WhatsApp do número de teste

# 3. Validar
curl -X POST https://auth.huboperacional.com.br/otp/validate \
  -H "Content-Type: application/json" \
  -d '{"channel":"whatsapp","destination":"+55{ddd}{numero}","code":"<6 digits>","audience":"{slug_projeto}"}'

# 4. Pegar access_token e bater num endpoint protegido do projeto
curl https://{slug_projeto}.huboperacional.com.br/me \
  -H "Authorization: Bearer <access_token>"
# Deve retornar 200 com { sub, roles }
```

---

## Step 4 — Migração de auth legado (se aplicável)

Se `{slug_projeto}` já tem auth próprio (Supabase/GoTrue/sidecar/senha), seguir `${env:PERCUS_CANON_DIR}/comandos/MIGRAR_AUTH.md` antes de adotar este kit.

Variantes V1-V4 cobrem cenários comuns. **V5** (legado → estado Final auth-service direto) sairá quando auth-service v1 publicar oficialmente.

---

## Critério de "feito" (R1)

- [ ] `GET /me` no projeto retorna 200 com claims do JWT validado localmente (sem RTT pro auth-service)
- [ ] Refresh do token funciona via `POST /token/refresh` no auth-service
- [ ] Logout (revoke) funciona via `POST /token/revoke`
- [ ] Smoke E2E completo: OTP request → WhatsApp recebido → validate → JWT → `/me` no projeto → refresh → revoke
- [ ] PLANO.md do projeto atualizado: `[5-T]` na feature "auth via percus-auth"
- [ ] HANDOFF.md atualizado refletindo migração
- [ ] Auth legado removido ou em janela de cutover documentada

---

## Decisões arquiteturais documentadas neste projeto

(Preencher conforme decisões forem tomadas durante adoção. Exemplos:)

- {Decisão 1: ex. "Audience própria criada porque volume esperado >1k OTPs/dia"}
- {Decisão 2: ex. "Cookie httpOnly em `.huboperacional.com.br` — mesmo apex que auth-service, não precisa redirect-fragment"}
- {Decisão 3: ex. "Login flow é OTP direto, sem magic-link na primeira fase — magic-link entra na Fase 2 pra convite de usuários novos"}

---

## Referências

- Plano original aprovado: `D:/Claud Automations/.claude-home/plans/analise-para-validar-generic-garden.md`
- Canon Percus: `${env:PERCUS_CANON_DIR}/01_REGRAS_INEGOCIAVEIS.md` R7 + R14-R18
- Stack/auth: `${env:PERCUS_CANON_DIR}/02_INFRA_E_STACK_PERCUS.md` Seção 2
- Lib Python: `https://auth.huboperacional.com.br/dist/percus_auth-<ver>-py3-none-any.whl`
- Lib Node: `https://auth.huboperacional.com.br/dist/percus-auth-<ver>.tgz`
- Runbooks operacionais (rotação de chave, SSO patterns, JWKS resilience): `services/api/docs/runbooks/` no repo `auth-service`
- Migration kit de referência (Família Milionária): `D:/Claud Automations/auth-service/migration-kits/familia-milionaria/`
