---
tipo: spec executivo oficial (cross-projeto)
audiência: tech leads de cada projeto Percus + revisores de PR no auth-service
quando-usar: ao integrar qualquer projeto Percus com `auth-service`, ou ao revisar PR que toca contrato cross-produto
leitura: 8 min
status: vigente desde 2026-05-15 — substitui `PADRAO_AUTH_CROSS_PROJETO.md` (V1, agora em `.archive/`)
plano-operacional: `D:\Claud Automations\.claude-home\plans\bora-resolver-o-que-fancy-hopper.md`
docs-relacionados: `docs/contracts/error-codes.md`, `docs/contracts/redirect-reasons.md`, `docs/contracts/MIGRATION_V1_TO_V2.md`, `checklists/CHECKLIST_AUDIENCE_NOVA.md`, `infra/approved-evolution-instances.yaml`
---

# PADRÃO DE INTEGRAÇÃO COM AUTH-SERVICE — V2 (ESTÚDIO PERCUS)

**Resumo em 1 frase:** Todo projeto Percus que tem login usa o `auth-service` (`https://auth.huboperacional.com.br`) como provedor único de identidade; consume via lib `percus-auth` v0.2.0+; segue contratos congelados de error/redirect/audience documentados aqui.

V2 absorve aprendizados de 5 sessões em prod do Plexco Tasks + 4 Critical do conselho cross-perspectiva (Security + API Design + SRE/Ops) de 2026-05-15.

---

## Sumário

- **Seção A** — Regra cross-projeto (5 linhas)
- **Seção B** — Contracts congelados de endpoints
  - B.1 `POST /internal/identities`
  - B.2 `POST /otp/request` e `POST /otp/validate` — error contract
  - B.3 SSO cross-product e resolução de `org_id`
- **Seção C** — Auth service-to-service (per-consumer secrets)
- **Seção D** — Registro de audience (PR + CODEOWNERS)
- **Seção E** — Compose secrets e Docker patterns
- **Seção F** — Deploy oficial
- **Seção G** — Login UX e método cravado (OTP vs Magic-link 24h)
- **Seção H** — Reason canônicos (`?reason=`)
- **Seção I** — Lições do Plexco incorporadas
- **Seção J** — Checklist de adoção projeto novo
- **Seção K** — Anti-padrões proibidos
- **FAQ** — perguntas comuns

---

## Seção A — Regra cross-projeto (5 linhas)

1. **Quem cria identidade:** só o `auth-service`.
2. **Quem cria pessoa comercial** (CPF, pix, comissão, tier): só o `Painel Gestão e Afiliados`.
3. **Cada produto** (Plexco Tasks, Coach, Familia, Paid Midia, etc.): guarda **profile local** + role + dados de domínio. Linka identidade via `identity_id UUID`.
4. **Nunca `UNIQUE(email)` global** em tabela local — sempre `UNIQUE(organization_id, email)` parcial.
5. **Multi-org de fábrica:** mesma pessoa pode ser membro de N organizações no mesmo produto — `identity_id` une cross-org, `users.email` repete entre orgs.

---

## Seção B — Contracts congelados de endpoints

### B.1 — `POST /internal/identities`

Endpoint **idempotente** lookup-or-create de identidade. Consumido por backends Percus para vincular invitações/signups a uma identity canônica.

**Authorization:** header `X-Internal-Auth: <secret>` (ver Seção C — pattern shared-secret per-consumer).

**Request:**
```http
POST /internal/identities HTTP/1.1
Host: auth.huboperacional.com.br
X-Internal-Auth: <internal_key_<consumer>>
Content-Type: application/json

{
  "email": "ana@exemplo.com",     // str | null (E.164 lowercased; opcional se phone vier)
  "phone": "+5567933009440",      // str | null (E.164 com `+`; opcional se email vier)
  "display_name": "Ana Silva",    // str | null (max 200)
  "origin_context": "invitation:42" // opcional — sub-contexto do produto chamador
}
```

**Regra de idempotência (V2, revisada):**
- Quando **email AND phone** chegam: lookup por match **exato** dos dois.
- Quando só um chega: lookup pelo campo presente.
- **Conflito (email match + phone divergente OU vice-versa)** → resposta **409**, nunca silent first-match. Vetor de hijack fechado.

**Origin é DERIVADO do secret (V2):** o auth-service mapeia o `X-Internal-Auth` → `consumer_id` (ex: `plexco-tasks`) e grava `origin = <consumer_id>` ou `origin = <consumer_id>:<origin_context>` se vier sub-contexto. **Payload não pode mandar `origin` arbitrário** — fecha vetor de impersonation cross-produto.

Validação adicional:
- `origin` (derivado): max 64, CHECK `^[a-z][a-z0-9-]*(:[a-z0-9-]+)?$` enforçado no schema.
- `email` OR `phone` obrigatório (pelo menos um).

**Responses:**

```http
# Sucesso — match exato OU criação
HTTP/1.1 200 OK            # já existia
X-Identity-Match: exact

{ "id": "<uuid>", "email": "...", "phone": "...", "display_name": "...",
  "origin": "plexco-tasks:invitation:42", "created": false }

HTTP/1.1 201 Created       # criada agora
X-Identity-Match: exact

{ ..., "created": true }

# Conflito — email match mas phone divergente (V2 novo)
HTTP/1.1 409 Conflict

{
  "error_code": "identity_conflict",
  "detail": "Identity matches existing record but provided fields diverge",
  "conflicts": ["phone"],
  "existing_id": "<uuid>"
}

# Auth
HTTP/1.1 401 Unauthorized
{ "error_code": "invalid_internal_auth", "detail": "..." }

# Validação
HTTP/1.1 422 Unprocessable Entity
{ "error_code": "invalid_payload", "detail": "...", "fields": [...] }
```

**`PATCH /me`** (self-update, com JWT do user, NÃO internal):
- Cobre `display_name`, `phone` (com re-verify via OTP), `email` (com re-verify via magic).
- `PATCH /internal/identities/{id}` admin-only é **fora V1** — sem ETA.

**Estabilidade do contract:** V1 **congelado**. Mudanças exigem `/internal/identities/v2` em paralelo + 60d window + announcement via Slack `#auth-service` e email pra tech-leads.

---

### B.2 — `POST /otp/request` e `POST /otp/validate` — error contract

Contrato unificado de erros + status codes para todos os endpoints de auth do auth-service.

**Política de evolução do enum** (V2): enum `error_code` é **open/extensible**. Clientes DEVEM tratar valor desconhecido como `unknown` (default case). Adicionar novo value = **minor bump** lib `percus-auth`. Renomear/remover = **major bump** + 60d window.

**Shape do response:**
```http
HTTP/1.1 422 Unprocessable Entity
Retry-After: 0
Content-Type: application/json

{
  "error_code": "otp_wrong",
  "detail": "Invalid code",
  "retry_after_seconds": 0
}
```

**Regras invioláveis:**
- `detail` é **constante por `error_code`** — zero interpolação de input do user. PII nunca aparece em `detail`. Enforcement: AST test `tests/contracts/test_no_pii_in_detail.py` no CI do auth-service.
- `Retry-After` é **mandatório** em todo response `429` e `503` (RFC 6585 §4).
- Latência **constante** nos paths de `/otp/validate` (~150ms) via `asyncio.sleep` adaptativo — fecha timing side-channel.

**Registry completo dos error_codes V1:** ver [docs/contracts/error-codes.md](docs/contracts/error-codes.md).

**Resumo (cheat sheet):**

| Endpoint | error_code | HTTP | Retry-After | Quando |
|---|---|---|---|---|
| `/otp/validate` | `otp_wrong` | 422 | `0` | Dígito errado, ainda tem tentativa |
| `/otp/validate` | `otp_expired` | 422 | `300` | TTL estourou ou nunca existiu |
| `/otp/validate` | `otp_locked` | 429 | breaker remaining | 5+ erradas — counter persiste no `(destination, audience)` mesmo se novo `/request` chegar |
| `/otp/request` | `dispatched` | 202 | — | **Sempre 202** mesmo se destination não existe (silent drop anti-enumeration) |
| `/otp/request` | `rate_limited` | 429 | breaker+1s | 5/destination/h ou 20/IP/min |
| `/otp/request` | `invalid_audience` | 422 | — | Audience desconhecida (E1 strict) |
| `/otp/request` | `audience_not_allowed` | 403 | — | Audience existe mas chamador não pode usar |
| `/otp/request` | `whatsapp_circuit_open` | 503 | breaker remaining | Evolution breaker aberto |
| `/otp/request` | `whatsapp_transient` | 503 | `5` | Evolution timeout/5xx |
| `/otp/request` | `whatsapp_permanent` | 502 | — | Número inválido — sugira outro canal |
| `/internal/identities` | `identity_conflict` | 409 | — | Match parcial com divergência |
| `/auth/magic/consume` | `magic_consumed` | 401 | — | Single-use já usado |
| `/auth/magic/consume` | `magic_expired` | 401 | — | TTL estourou (24h email / 10min whatsapp) |
| `/auth/magic/consume` | `magic_context_mismatch` | 401 | — | Device fingerprint divergente (IP/16 ou UA hash) |

**Status codes V2 (revisados):**
- `otp_wrong`/`otp_expired` agora **422** (precondição de payload), não 401. 401 fica pra credencial de auth inválida (JWT).
- `otp_locked` agora **429** (rate-limit semântico), não 401.
- `audience_not_allowed` = **403** (autorização ≠ payload).
- `destination_not_registered` **eliminado** — vira `dispatched 202` silent drop.

**Migration path para consumers:**
- Auth-service serve `error_code` atrás de feature flag `AUTH_ERROR_CODE_V2=true` (default false 7d em prod, dual-path).
- Response legado mantém `detail` substring matchável por **30d** após flip default.
- Path legado retorna headers `Deprecation: true` + `Sunset: <RFC 1123 date>` + `Link: <doc>; rel="deprecation"` (RFC 8594).
- Consumer migra: substitui substring-match por `switch(body.error_code)` consumindo `ErrorCode` enum exportado pela lib `percus-auth` v0.2.0.
- Auth-service mede adoção via header `User-Agent: percus-auth/<version>` (dashboard SigNoz).

---

### B.3 — SSO cross-product e resolução de `org_id`

Mesma identity pode ter orgs diferentes em produtos diferentes (ex: Ana é membro da org A em Plexco Tasks, org B em Coach). JWT NÃO carrega `org_per_aud` claim (vira chunky + exige rotação a cada mudança de membership).

**Endpoint stateless (V2):**
```http
GET /internal/resolve-org?iid=<identity_uuid>&aud=<audience_slug>
X-Internal-Auth: <secret>

# 200
{ "org_id": "<uuid>", "role": "admin", "granted_at": "2026-04-15T..." }

# 404 — não é membro nesse produto
{ "error_code": "identity_not_member", "detail": "..." }
```

Consumer cacheia (TTL 5min) pra não bater por request. Endpoint implementado em Sessão 8 do plano operacional.

---

## Seção C — Auth service-to-service (per-consumer secrets)

**Pattern V2:** Docker Secret per-consumer simétrico. Mantém simplicidade do shared-secret mas fecha blast radius.

### Setup por consumer

Cada produto consumer do `/internal/*` recebe **um secret próprio**:

| Consumer | Docker Secret | Mapeado para `consumer_id` |
|---|---|---|
| Plexco Tasks | `internal_key_plexco` | `plexco-tasks` |
| Plexco Coach | `internal_key_coach` | `coach` |
| Painel | `internal_key_painel` | `painel` |
| (futuro) | `internal_key_<slug>` | `<slug>` |

Auth-service lê todos via Pydantic `BaseSettings.secrets_dir="/run/secrets"` (zero código novo por consumer). Mapping em `app/core/internal_auth.py:CONSUMER_SECRETS = {...}`.

**Onde monta no consumer:**
```yaml
# docker-compose.yml (consumer)
services:
  backend:
    secrets:
      - source: internal_key_plexco
        target: internal_key
        # Pydantic do consumer lê `/run/secrets/internal_key` — nome neutro local
```

### `origin` é derivado do secret

Payload do consumer pode mandar `origin_context` (sub-contexto interno, ex: `invitation:42`), mas o **produto-base sempre vem do `consumer_id` resolvido pelo secret**. Vetor de impersonation cross-produto eliminado.

### Rotação trimestral + canary

- **Cadência:** rotação **trimestral** + emergency on-incident.
- **Canary token:** secret fake `__canary` registrado em `CONSUMER_SECRETS` — uso = alerta crítico pra on-call (sinal de vazamento).
- **Procedimento:** ver `runbooks/internal-key-rotation.md` (criar em Sessão 5).
- **Owner:** auth-service team. Aviso 14d antecedência via Slack `#auth-service` + email tech-leads.

### Audit per-call (bloqueante V2)

Tabela `auth.internal_call_log` (migration 009 — Sessão 5):
```sql
CREATE TABLE auth.internal_call_log (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    consumer_id TEXT NOT NULL,         -- derivado do secret
    route TEXT NOT NULL,                -- /internal/identities, /internal/resolve-org
    request_origin_context TEXT,        -- sub-contexto opcional do payload
    client_ip INET,
    status INT NOT NULL,
    latency_ms INT NOT NULL
);
CREATE INDEX idx_internal_call_log_created ON auth.internal_call_log (created_at DESC);
CREATE INDEX idx_internal_call_log_consumer ON auth.internal_call_log (consumer_id, created_at DESC);
```
Retenção 30d via cron cleanup (`scripts/cleanup_internal_call_log.py`).

**Alerta:** spike de calls do mesmo `consumer_id` de IPs novos OU uso de `__canary` token = page on-call.

---

## Seção D — Registro de audience

Slug de produto cravado em `auth.audiences`. Audiences vigentes hoje: `painel`, `familia`, `paid-media`, `coach`, `plexco-tasks`.

### Naming convention

- Regex: `^[a-z][a-z0-9-]+$` (kebab-case).
- Max 32 chars.
- Sem sufixos `-prod`/`-staging` — audience é ambiente-agnostic; ambientes separam por DB.

> ⚠️ **`Auth_Todos` NÃO é audience.** É nome de **Evolution WhatsApp instance**. Audience usa kebab-case sempre.

### Fluxo canônico (PR + 2 approvals + security review)

1. Projeto novo abre **PR no `huboperacional/auth-service`** com migration Alembic adicionando row em `auth.audiences`. Template em `checklists/CHECKLIST_AUDIENCE_NOVA.md`.
2. **CODEOWNERS** (config em `.github/CODEOWNERS`):
   - PRs em `services/api/alembic/versions/*audience*` → @auth-service-team + @security-team (criar grupo).
   - **2 approvals mínimos**.
   - 1 approval **deve ser de @security-team** se PR muda `whatsapp_config`, `email_provider`, `whatsapp_provider`.
   - PRs que mudam apenas naming/display = 1 approval auth-team.
3. **Status check `audience-config-lint`** (workflow `.github/workflows/audience-config-lint.yml`): valida que `whatsapp_config.instance_name` está em `infra/approved-evolution-instances.yaml`. Bloqueia merge se instance não aprovada.
4. Merge + deploy auth-service → **propagação <60s** via Redis pub/sub + AudienceCache TTL 60s.

### Override de provider per-audience

Pattern Plexco Tasks (2026-05-15): audience pode usar instance própria do Evolution em vez do `Auth_Todos` compartilhado. **Mesmo fluxo de PR** (não SQL direto em prod).

```sql
-- exemplo do que vai na migration
UPDATE auth.audiences
SET whatsapp_provider='evolution_self',
    whatsapp_config=jsonb_build_object(
      'api_key', current_setting('app.evolution_api_key_plexco'),
      'instance_name', 'Plexco'
    )
WHERE audience='plexco-tasks';
```

API key **nunca** vai hardcoded na migration — usar `current_setting('app.<var>')` injetado via Docker Secret no runtime do PG OR resolver via env no deploy. Detalhes no checklist.

### Cache

- TTL 60s + Redis pub/sub invalidation.
- Consumer pode assumir propagação <60s após merge+deploy.
- Setup novo: merge → aguardar 1min → smoke `POST /otp/request` com audience nova (esperar 202).

---

## Seção E — Compose secrets e Docker patterns

### Padrão obrigatório: Pydantic `secrets_dir`

```python
# config.py de qualquer projeto Percus
class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        secrets_dir="/run/secrets",
        case_sensitive=False,
        env_file=".env",
    )
    internal_key: str
    database_url: str
    redis_url: str
```

Filename em `/run/secrets/` = lowercase do field name. Permite mover qualquer env var sensível pra Docker Secret sem code change.

### Auth-service hoje migra 4 valores

Sessão 5 do plano operacional:
- `postgres_password` (era `DATABASE_URL` hardcoded)
- `redis_password` (era `REDIS_URL` hardcoded)
- `evolution_auth_api_key`
- `evolution_api_key`

Pré-check: `replicas: 2+` no compose Swarm pra garantir zero-downtime no `docker service update --secret-add`.

### Source-of-truth declarativa de CORS (roadmap)

Plexco Tasks tem `infra/domains.yaml` + `scripts/cors-sync.py` que gera config.py e `.env.example` + smoke pluga no fim de cada deploy (`scripts/cors-smoke.sh` testa 18 origins × endpoints).

**Auth-service vai replicar** — agendado pra Sessão 7 (data alvo 2026-06-15).

---

## Seção F — Deploy oficial

### Git pull deploy (substitui rsync)

Script `auth-service-deploy` em `/usr/local/bin/` (symlink relativo pra `auth-service/deploy/scripts/auth-service-deploy.sh` no clone):

```bash
#!/usr/bin/env bash
set -euo pipefail
cd /opt/auth-service
git pull origin main
TAG="deploy-$(date +%s)"
docker build -t "percus/auth-service:$TAG" services/api/

# Guardrail: alembic head check
LOCAL_HEAD=$(docker run --rm --network host \
  -e DATABASE_URL="$DATABASE_URL" \
  "percus/auth-service:$TAG" \
  python -m alembic heads 2>&1 | head -1)
DB_HEAD=$(docker run --rm --network host \
  -e DATABASE_URL="$DATABASE_URL" \
  "percus/auth-service:$TAG" \
  python -m alembic current 2>&1 | head -1)

if [[ "$LOCAL_HEAD" != "$DB_HEAD" ]] && [[ "${1:-}" != "--skip-migration-check" ]]; then
  echo "ERROR: alembic head divergence. Run migrations or use --skip-migration-check." >&2
  exit 1
fi

docker service update --image "percus/auth-service:$TAG" --force auth_service_api
sleep 5
curl -fsS https://auth.huboperacional.com.br/health || (echo "smoke FAILED"; exit 1)
echo "deploy $TAG OK"
```

### Migrations

**Manual com guardrail.** Script aborta se DB head divergir do código. Override explícito com `--skip-migration-check`.

### SETUP.md

`auth-service/SETUP.md` documenta o fluxo completo (Sessão 6 do plano operacional).

---

## Seção G — Login UX e método cravado

### Análise comparativa cravada: OTP 5min vs Magic-link 24h

Após conselho cross-perspectiva (Security + UX/SRE):

| Canal | Método | TTL | Justificativa |
|---|---|---|---|
| **WhatsApp** | OTP 6-dígitos | 5min | Preview-bot WA queima magic single-use ANTES do user clicar. Vishing BR em link é vetor real. Brasileiro tem muscle-memory de 6 dígitos (PIX/banco). Completion ~92-96%. |
| **E-mail** | Magic-link | 24h | E-mail é async — user pode abrir 4h depois. 5min OTP em e-mail é fricção real (spam, push delay). Clients NÃO preview-fetcham link agressivo (Gmail/Outlook abandonaram esse antipadrão ~2015). Cobre RH-manda-22h/user-abre-7h. |
| **Admin / Painel** | OTP + TOTP step-up | 5min | Política de risco — admin é alvo de phishing alto-valor. Magic nunca para admin. |
| **Convite / primeiro login** | Magic-link | 24h | Convite chega em horário aleatório. 5min OTP perde a janela. Magic 24h é industry-standard (Slack, Notion, Linear). |

**Por que TTL 24h e não 1h ou 7d?**
- <1h: cobre ~70% dos casos mas perde "RH manda 23h, user abre 7h" — caso real Familia.
- 24h: cobre 95%+ sem virar token de longa duração (OWASP "ephemeral" threshold = 24h).
- 7d: vira sessão disfarçada — se vaza em backup/screenshot, atacante tem 1 semana. Inaceitável.

### Mitigações obrigatórias pro magic-link 24h

**Não-negociáveis** (Security council cravou):

1. **Entropy ≥128 bits CSPRNG** — `secrets.token_urlsafe(32)`. **Proibido UUIDv4** (122 bits + formato previsível).
2. **Atomic consume** — Redis `GETDEL` (≥6.2) ou Lua `EVAL`. NUNCA `GET`+`DEL` separados. Race condition fechada por construção.
3. **Token sempre em path segment** `/w/{code}` (não query param). Response do consume seta `Referrer-Policy: no-referrer`.
4. **HSTS preload** no domínio `auth.huboperacional.com.br` + `__Host-` prefix em qualquer session cookie.
5. **Logout invalida magics pendentes** — `POST /auth/logout` faz `UPDATE auth.magic_links SET invalidated_at=NOW() WHERE identity_id=? AND consumed_at IS NULL`.
6. **Consume invalida refreshes anteriores** — magic-link consume = "novo login" → rotaciona refresh family.
7. **Device fingerprint mandatory** — bind a `IP/16 + UA hash` no momento da emissão. Mismatch no consume = 401 `magic_context_mismatch`. **Trade-off de UX aceito** (user que muda 4G→WiFi entre emit e consume cai em 401 — recomendar pedir novo link).
8. **Single-use enforced em Redis + DB** (Redis hot path, DB row pra audit).
9. **Rate-limit 3 issues/destination/hora** + dashboard de spike.
10. **Audit row** em `auth.magic_links` com `issued_at`, `consumed_at`, `consumer_ip`, `consumer_ua`, `invalidated_at`, `device_fingerprint`.

### TTL por canal (split V2)

Schema `auth.audiences` ganha 2 colunas (migration 010):
- `magic_ttl_email_seconds` (default 86400 = 24h)
- `magic_ttl_whatsapp_seconds` (default 600 = 10min)

Column antiga `magic_ttl_seconds` vira deprecated, removida em migration follow-up após 30d.

### UI 6-boxes padronizada (referência Plexco Tasks)

Plexco Tasks tem template Next.js 15 + shadcn/ui de OTP em 6-boxes que é referência pra projetos novos:
- 2 steps visuais: `request` (escolher canal + destino) → `otp` (digitar 6 dígitos)
- 2 canais lado-a-lado: WhatsApp (default) + E-mail (magic em vez de OTP)
- Validações inline + estado `notFound` separado de erro genérico
- Pré-fill via query string: `?channel=email&dest=foo@bar.com`

Boilerplate em `_Novo_Projeto/templates/login-ui/` (criar em Sprint 2 da lib v0.2.0).

### friendlyError translation pattern

Backend retorna `error_code` em EN. Frontend traduz pt-BR via mapa local:

```typescript
const friendlyError: Record<ErrorCode, string> = {
  otp_wrong: 'Código errado. Tente o último que você recebeu.',
  otp_expired: 'Código expirou. Vamos enviar outro.',
  otp_locked: 'Muitas tentativas. Espere alguns minutos e peça novo código.',
  rate_limited: 'Aguarde um pouco antes de tentar de novo.',
  whatsapp_circuit_open: 'WhatsApp temporariamente indisponível. Tente e-mail.',
  // ...
  unknown: 'Erro desconhecido. Tente de novo em alguns segundos.',
}
```

Regra: backend NUNCA traduz. i18n é responsabilidade do consumer.

---

## Seção H — Reason canônicos (`?reason=`)

Quando user é redirecionado pra `/login?reason=<canonical>`, frontend mostra banner contextual.

**Registry V1 cravado:**

| reason | Quando | Mensagem sugerida pt-BR |
|---|---|---|
| `session_invalid` | Sessão expirou/invalidada server-side | "Sua sessão expirou. Entre de novo." |
| `token_expired` | Access token expirou e refresh falhou | "Sua sessão expirou. Entre de novo." |
| `refresh_failed` | Refresh token rotation falhou (família invalidada) | "Sua sessão foi encerrada por segurança. Entre de novo." |
| `audience_not_allowed` | JWT válido mas audience não tem permissão | "Você não tem acesso a este produto." |
| `logout` | User clicou logout | "Você saiu da conta." |
| `magic_consumed` | Magic-link já foi usado | "Este link já foi usado. Peça um novo." |
| `magic_expired` | Magic-link estourou TTL | "Este link expirou. Peça um novo." |
| `magic_context_mismatch` | Device fingerprint divergente | "Por segurança, abra o link no mesmo dispositivo onde solicitou." |

**Owner:** auth-service team. Projetos pedem adição via PR em `docs/contracts/redirect-reasons.md` no `auth-service` repo.

**Validação:** endpoints que constroem redirect com `reason` validam server-side; reason desconhecido = log warning + `reason=unknown` (nunca 500).

Registry completo em [docs/contracts/redirect-reasons.md](docs/contracts/redirect-reasons.md).

---

## Seção I — Lições do Plexco incorporadas

8 padronizações cross-projeto absorvidas no V2:

| # | Padronização Plexco (origem) | Status no V2 |
|---|---|---|
| 1 | `normalize_phone()` canônico (E.164 com `+`) | Lib `percus-auth` v0.2.0 exporta `normalize_phone()`. R7+ em `01_REGRAS_INEGOCIAVEIS.md` reescrita. |
| 2 | Login UX 2-steps + UI 6-boxes (Next.js + shadcn) | Documentado em Seção G. Boilerplate em `templates/login-ui/`. |
| 3 | `friendlyError` translation map | Seção G — consumer mapeia `error_code` → pt-BR. Backend nunca traduz. |
| 4 | Banner `?reason=session_invalid` na login page | Seção H — registry canônico. |
| 5 | `redeemed=true` em invitations | Contrato `/invitations/{token}` (não V1; futuro). |
| 6 | Override WhatsApp por audience | Seção D — pattern `evolution_self` + JSONB config. |
| 7 | Docker Secrets via Pydantic `secrets_dir` | Seção E — padrão oficial. |
| 8 | CORS source-of-truth declarativa | Seção E — agendado Sessão 7 (2026-06-15). |

---

## Seção J — Checklist de adoção projeto novo

1. [ ] Ler este doc + [OWNERSHIP.md](../OWNERSHIP.md).
2. [ ] Decidir: seu projeto cria identidade (signup, convite com pessoa nova) ou só referencia?
3. [ ] **Solicitar `consumer_id` + secret per-consumer** ao auth-service team (Seção C) — necessário antes de chamar `/internal/*`.
4. [ ] Registrar audience via PR (Seção D + [CHECKLIST_AUDIENCE_NOVA.md](checklists/CHECKLIST_AUDIENCE_NOVA.md)).
5. [ ] Implementar validação JWT via `percus-auth` v0.2.0+ (lib exporta `bearer_auth_with_phone_lookup` + `ErrorCode` enum + types).
6. [ ] Tabela `users` no schema obrigatório: `UNIQUE(organization_id, LOWER(email))` parcial + `UNIQUE(organization_id, phone)` parcial + `UNIQUE(identity_id)` parcial.
7. [ ] Frontend login: 2-step UI + `friendlyError` map dos `error_code` canônicos.
8. [ ] Banner contextual via `?reason=<canonical>` (Seção H).
9. [ ] Smoke E2E cross-product: login no produto X → token funciona pra `GET /me` em produto Y (mesma identity).

---

## Seção K — Anti-padrões proibidos

| ❌ Não faça | ✅ Faça em vez |
|---|---|
| `users.password_hash` + bcrypt local | Sem credencial local. Auth-service emite token via OTP/magic. |
| `UNIQUE(email)` ou `UNIQUE(phone)` globais | `UNIQUE(organization_id, email)` parcial. |
| Cadastro de afiliado local com CPF/pix | Read-only do Painel. Pessoa comercial mora lá. |
| Lookup user "por email" sem org context | Lookup por `identity_id`. Se não tem ainda, escope por org no WHERE. |
| Emitir JWT próprio com `aud=meu-produto` | Só o auth-service emite. Você só valida. |
| Coluna `auth_id` ou `gotrue_id` (legado) | `identity_id` é o nome canônico. |
| Phone sem `+` (digits-only) | E.164 COM `+`. Sempre `normalize_phone()` antes de INSERT/WHERE. |
| Substring-match em `detail` do error response | `switch(body.error_code)` com fallback `unknown`. |
| OTP via e-mail | Magic-link via e-mail (Seção G). |
| Magic-link via WhatsApp | OTP via WhatsApp (Seção G). |
| INSERT direto em `auth.audiences` em prod | PR no auth-service repo (Seção D). |
| Hardcode de phone normalize com regex `\D` | `from percus_auth import normalize_phone`. |
| Mandar `origin` arbitrário no `/internal/identities` | `origin` vem derivado do secret. Use `origin_context` pra sub-contexto. |
| `internal_key` global compartilhado entre todos consumers | Per-consumer secret obrigatório (Seção C). |
| UUIDv4 como magic-link code | `secrets.token_urlsafe(32)` (128-bit entropy). |
| Device fingerprint opcional no magic 24h | Mandatory bind a IP/16 + UA hash (Seção G). |

---

## FAQ

**P: Preciso migrar meu projeto antigo agora?**
R: Não. Auth-service é padrão pra projeto NOVO. Migração de existente só quando dor justificar (Strangler Fig em curso pra Plexco Tasks Etapa 2 e Coach Etapa 3).

**P: E se a pessoa muda de email/phone?**
R: O `identity_id` é estável. Update via `PATCH /me` (self, com JWT) com re-verify (OTP pra phone, magic pra email).

**P: SSO cross-produto funciona automaticamente?**
R: Hoje sim entre subdomínios do mesmo domain (cookie/token compartilhado). Cross-domain precisa magic-link explícito. `org_id` resolvido via `GET /internal/resolve-org` (Sessão 8 do plano).

**P: Como saber se identidade já existe antes de criar?**
R: `POST /internal/identities` é idempotente (lookup-or-create AND-match). Não precisa pré-check. Se conflito (email match + phone divergente) → 409 com `conflicts[]` — você decide o que fazer.

**P: E pessoa comercial sem login (lead, contato CRM)?**
R: Cria row local sem `identity_id`. Quando virar user, faz upgrade chamando `/internal/identities` e popula o campo.

**P: Auth-service tem rate limit?**
R: Sim. `/otp/request`: 5/destination/h + 20/IP/min. `/otp/validate`: 20/IP/min. Hard limit; não burlar.

**P: Como diferencio "código errado" de "código expirou" no frontend?**
R: V2: switch em `body.error_code` (`otp_wrong` vs `otp_expired`). V1 legacy: substring-match em `detail` (deprecated, removido em 30d após flip default).

**P: Magic-link em WhatsApp ainda funciona?**
R: Endpoint suporta tecnicamente, mas é **anti-padrão** (Seção K). Use OTP via WhatsApp.

**P: O que acontece se eu mandar `origin: "painel"` no payload do `/internal/identities` mas meu secret é `internal_key_plexco`?**
R: Auth-service ignora seu payload e grava `origin=plexco-tasks`. `origin_context` é o campo pra sub-contextos (`{"origin_context": "invitation:42"}` → `origin=plexco-tasks:invitation:42`).

---

## Onde aprofundar

- **Decisão arquitetural completa** (premissas, alternativas, why-not big-bang): `D:\Claud Automations\OWNERSHIP.md`
- **Plano operacional V2 com 8 sessões**: `D:\Claud Automations\.claude-home\plans\bora-resolver-o-que-fancy-hopper.md`
- **Receita passo-a-passo projeto novo**: `checklists/CHECKLIST_AUTH_NOVO_PROJETO.md`
- **Registry de error_codes**: [docs/contracts/error-codes.md](docs/contracts/error-codes.md)
- **Registry de reasons**: [docs/contracts/redirect-reasons.md](docs/contracts/redirect-reasons.md)
- **Migração V1→V2 (cross-repo grep guide)**: [docs/contracts/MIGRATION_V1_TO_V2.md](docs/contracts/MIGRATION_V1_TO_V2.md)
- **Regra R19 (identidade canônica)**: `01_REGRAS_INEGOCIAVEIS.md`
- **Aprendizados Plexco originais**: `AUTH_SERVICE_PATTERNS_LEARNED_2026-05-15.md`
- **Review de Etapa 1 Strangler**: `REVIEW_AUTH_INTEGRATION_2026-05-15.md`

---

**Mantenedor:** estúdio Percus, time core. Mudanças via PR no `huboperacional/percus-kit`.
**Última atualização:** 2026-05-15 (V2 cravado pós-conselho rodada 2).
**Histórico:** V1 (`PADRAO_AUTH_CROSS_PROJETO.md`) arquivado em `.archive/` — substituído por este V2.
