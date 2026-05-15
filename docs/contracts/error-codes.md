---
tipo: contract registry (versionado)
audiência: backend auth-service + consumers (libs `percus-auth` Python/Node)
versão: V1 (2026-05-15)
status: vigente
política-de-evolução: enum open/extensible — adicionar value = minor bump lib, renomear/remover = major bump + 60d window
referência: PADRAO_AUTH_SERVICE_INTEGRATION_V2 Seção B.2
---

# Registry de `error_code` — auth-service

## Contrato

**Shape do response (todos os erros do auth-service):**
```http
HTTP/1.1 <status>
Retry-After: <seconds-or-omitted>
Content-Type: application/json

{
  "error_code": "<enum_value>",
  "detail": "<constante-em-EN-por-error_code>",
  "retry_after_seconds": <int-or-omitted>
}
```

**Regras invioláveis:**
1. `detail` é **constante por `error_code`**. Zero interpolação de input do user. PII nunca aparece em `detail`. Enforcement: AST test `tests/contracts/test_no_pii_in_detail.py` no CI.
2. `Retry-After` (header HTTP) e `retry_after_seconds` (body) são **mandatórios** em todos os `429` e `503` (RFC 6585 §4).
3. Clientes DEVEM ter `default`/`_` case tratando valor desconhecido como `unknown`.
4. Status code HTTP segue RFC 9110: 422 = payload preconditions, 403 = authorization, 429 = rate-limit, 503 = service unavailable.

---

## V1 — Enum completo

### `/otp/validate`

| `error_code` | HTTP | `Retry-After` | `detail` (constante EN) | Quando |
|---|---|---|---|---|
| `otp_wrong` | 422 | `0` | `"Invalid code"` | Dígito errado; ainda tem tentativas restantes |
| `otp_expired` | 422 | `300` | `"Code expired or not issued"` | TTL estourou OU OTP nunca foi pedido (path unificado — anti-enumeration) |
| `otp_locked` | 429 | `<breaker remaining>` | `"Too many attempts"` | 5+ erradas no `(destination, audience)`. **Counter persiste mesmo se novo `/otp/request` chegar** — vetor de bypass fechado. Counter zera só após `Retry-After` expirar OU sucesso. |

### `/otp/request`

| `error_code` | HTTP | `Retry-After` | `detail` (constante EN) | Quando |
|---|---|---|---|---|
| `dispatched` | 202 | — | `"Dispatched"` | **Sempre retorna 202** mesmo se destination não existe (silent drop anti-enumeration). |
| `rate_limited` | 429 | `<breaker+1s>` | `"Rate limit reached"` | 5/destination/h ou 20/IP/min |
| `invalid_audience` | 422 | — | `"Audience not registered"` | Audience desconhecida (E1 strict) |
| `audience_not_allowed` | 403 | — | `"Audience not allowed for this caller"` | Audience existe mas chamador não pode usar |
| `whatsapp_circuit_open` | 503 | `<breaker remaining>` | `"WhatsApp temporarily unavailable"` | Evolution breaker aberto |
| `whatsapp_transient` | 503 | `5` | `"WhatsApp transient error"` | Evolution timeout/5xx |
| `whatsapp_permanent` | 502 | — | `"WhatsApp delivery failed"` | Número inválido / não tem WA |

### `/auth/magic/consume` e `GET /w/{code}`

| `error_code` | HTTP | `Retry-After` | `detail` (constante EN) | Quando |
|---|---|---|---|---|
| `magic_consumed` | 401 | — | `"Magic link already used"` | Single-use já consumido |
| `magic_expired` | 401 | — | `"Magic link expired"` | TTL estourou (default 24h email / 10min whatsapp) |
| `magic_context_mismatch` | 401 | — | `"Magic link must be opened on same device"` | Device fingerprint divergente (IP/16 ou UA hash) |
| `magic_invalidated` | 401 | — | `"Magic link invalidated"` | Logout (server-side `invalidated_at NOT NULL`) |

### `/auth/magic/issue`

| `error_code` | HTTP | `Retry-After` | `detail` (constante EN) | Quando |
|---|---|---|---|---|
| `dispatched` | 202 | — | `"Dispatched"` | Mesmo silent-drop pattern do `/otp/request` |
| `rate_limited` | 429 | `<breaker+1s>` | `"Rate limit reached"` | 3/destination/h |
| `invalid_audience` | 422 | — | `"Audience not registered"` | |
| `audience_not_allowed` | 403 | — | `"Audience not allowed for this caller"` | |

### `/internal/identities`

| `error_code` | HTTP | `Retry-After` | `detail` (constante EN) | Quando |
|---|---|---|---|---|
| `identity_conflict` | 409 | — | `"Identity matches existing record but provided fields diverge"` | Match parcial — response inclui `conflicts: ["email"\|"phone"]` + `existing_id` |
| `invalid_internal_auth` | 401 | — | `"Invalid internal auth"` | `X-Internal-Auth` faltando ou inválido |
| `invalid_payload` | 422 | — | `"Invalid payload"` | Pydantic detail extra em `fields[]` |

### `/internal/resolve-org` (Sessão 8)

| `error_code` | HTTP | `Retry-After` | `detail` (constante EN) | Quando |
|---|---|---|---|---|
| `identity_not_member` | 404 | — | `"Identity not member of audience"` | iid existe mas não tem membership na audience pedida |

### Genéricos (qualquer endpoint)

| `error_code` | HTTP | `Retry-After` | `detail` (constante EN) | Quando |
|---|---|---|---|---|
| `unauthorized` | 401 | — | `"Authentication required"` | Bearer token ausente/inválido |
| `forbidden` | 403 | — | `"Forbidden"` | JWT válido mas claim insuficiente |
| `unknown` | (qualquer) | — | (varia) | Fallback que cliente DEVE tratar pra resilience |

---

## Política de evolução

| Mudança | Bump da lib `percus-auth` | Janela |
|---|---|---|
| Adicionar `error_code` novo | minor (0.X.Y → 0.X+1.0) | imediato |
| Documentar significado adicional pra `error_code` existente (sem mudar shape) | patch (0.X.Y → 0.X.Y+1) | imediato |
| Renomear `error_code` | **major** (0.X → 1.0) | 60d window + `Deprecation` header |
| Remover `error_code` | **major** | 60d window + `Sunset` header |
| Mudar HTTP status pra `error_code` existente | major | 60d window |
| Mudar `Retry-After` semantics | major | 60d window |

**Headers de deprecação** (RFC 8594):
```http
Deprecation: true
Sunset: Wed, 31 Dec 2026 23:59:59 GMT
Link: <https://github.com/huboperacional/percus-kit/docs/contracts/error-codes.md>; rel="deprecation"
```

---

## Como o consumer consome

### Python (lib `percus-auth` ≥ 0.2.0)

```python
from percus_auth import ErrorCode, AuthError

try:
    await client.otp_validate(destination, code)
except AuthError as e:
    match e.error_code:
        case ErrorCode.OTP_WRONG:
            ...
        case ErrorCode.OTP_EXPIRED:
            ...
        case ErrorCode.OTP_LOCKED:
            retry_after = e.retry_after_seconds
            ...
        case _:  # unknown — fallback OBRIGATÓRIO
            ...
```

### Node/TS (lib `@percus/auth` ≥ 0.2.0)

```typescript
import { ErrorCode, AuthError } from '@percus/auth'

try {
  await client.otpValidate(destination, code)
} catch (e) {
  if (e instanceof AuthError) {
    switch (e.errorCode) {
      case ErrorCode.OTP_WRONG: ...
      case ErrorCode.OTP_EXPIRED: ...
      case ErrorCode.OTP_LOCKED:
        const retryAfter = e.retryAfterSeconds
        ...
      default: // unknown
        ...
    }
  }
}
```

---

## Adicionar `error_code` novo (procedimento)

1. PR no `huboperacional/auth-service` adicionando o handler + entrada nesta tabela neste arquivo (via cópia do `percus-kit`).
2. Cross-Claude review obrigatório (audit cross-projeto auth = pasta sensível).
3. Após merge: lib `percus-auth` ganha minor bump exportando o novo value no enum + types.
4. Consumers atualizam (não-bloqueante — `default` case já trata).

---

**Mantenedor:** auth-service team.
**Última atualização:** 2026-05-15 (V1 cravado).
