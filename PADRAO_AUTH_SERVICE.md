---
tipo: spec executivo oficial (cross-projeto)
audiência: tech leads de cada projeto Percus + revisores de PR no auth-service
quando-usar: ao integrar qualquer projeto Percus com `auth-service`, ou ao revisar PR que toca contrato cross-produto
leitura: 8 min
status: vigente desde 2026-05-15 — substitui `PADRAO_AUTH_CROSS_PROJETO.md` (V1, em `.archive/`). Em v6.11.0 absorveu também `AUTH_SERVICE_PATTERNS_LEARNED_2026-05-15.md` (já refletido em Seção I) e `REVIEW_AUTH_INTEGRATION_2026-05-15.md` (review de momento — git history preserva). Em v6.16.0 absorve o **Padrão Auth Percus v2** (5 pilares, supplement 2026-05-30) como direção canônica vigente — ver **Seção L** (cada pilar com status de rollout real; nem tudo em prod).
docs-relacionados: `docs/contracts/error-codes.md`, `docs/contracts/redirect-reasons.md`, `docs/contracts/MIGRATION_V1_TO_V2.md`, `checklists/CHECKLIST_AUDIENCE_NOVA.md`, `infra/approved-evolution-instances.yaml`, `auth-service/docs/superpowers/specs/2026-05-30-padrao-auth-percus-design.md` (read-only, cross-repo), `auth-service/docs/proposals/2026-05-30-painel-identity-migration.md` (read-only, cross-repo)
---

# PADRÃO DE INTEGRAÇÃO COM AUTH-SERVICE (ESTÚDIO PERCUS)

**Resumo em 1 frase:** Todo projeto Percus que tem login usa o `auth-service` (`https://auth.huboperacional.com.br`) como provedor único de identidade; consume via lib `percus-auth` v0.2.0+; segue contratos congelados de error/redirect/audience documentados aqui.

V2 absorve aprendizados de 5 sessões em prod do Plexco Tasks + 4 Critical do conselho cross-perspectiva (Security + API Design + SRE/Ops) de 2026-05-15.

---

## Sumário

- **Seção A** — Regra cross-projeto (5 linhas)
- **Seção B** — Contracts congelados de endpoints
  - B.1 `POST /internal/identities`
  - B.2 `POST /otp/request` e `POST /otp/validate` — error contract
  - B.3 SSO cross-product e resolução de `org_id`
  - B.4 Regra de identidade (padrão único)
  - B.5 `POST /internal/whatsapp/check`
  - B.6 Sessão durável — `#rt=` e `/otp/refresh` obrigatórios (consumer-side)
- **Seção C** — Auth service-to-service (per-consumer secrets)
- **Seção D** — Registro de audience (PR + CODEOWNERS)
- **Seção E** — Compose secrets e Docker patterns
- **Seção F** — Deploy oficial
- **Seção G** — Login UX e método cravado (OTP vs Magic-link 24h)
- **Seção H** — Reason canônicos (`?reason=`)
- **Seção I** — Lições do Plexco incorporadas
- **Seção J** — Checklist de adoção projeto novo
- **Seção K** — Anti-padrões proibidos
- **Seção L** — Padrão Auth Percus v2 (5 pilares + status de rollout)
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

**B.1.v2 — signup required `name + phone + email` (Pilar 1, em janela):** o Padrão Auth Percus v2 (Seção L) torna **`name + phone + email` obrigatórios** no signup. Como é *breaking* sobre o contract V1 congelado acima, entra como endpoint paralelo **`POST /internal/identities/v2`** (os 3 required; ausência → `invalid_payload` com `fields[]`), com o V1 (optional, AND-match) válido por **≥60d** + announcement, e **major bump da lib `percus-auth`** (≥v1.0.0). **Status de rollout:** ✅ em prod desde 2026-06-08 (`deploy-1780934677`) — janela de 60d em curso. Projetos novos usam `/v2`; existentes migram na janela.

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
| `/otp/request` | `dispatched` | 202 | — | **Sempre 202** — envio em background (early-202, desde 2026-06-11). Inclui destino sem conta (anti-enumeração) + cooldown 60s/(audience,canal,destino). Falha de provider **não volta síncrono**. |
| `/otp/request` | `rate_limited` | 429 | breaker+1s | 5/destination/h ou 20/IP/min |
| `/otp/request` | `invalid_audience` | 422 | — | Audience desconhecida (E1 strict) |
| `/otp/request` | `audience_not_allowed` | 403 | — | Audience existe mas chamador não pode usar |
| `/internal/identities` | `identity_conflict` | 409 | — | Match parcial com divergência |
| `/auth/magic/consume` | `magic_consumed` | 401 | — | Single-use já usado |
| `/auth/magic/consume` | `magic_expired` | 401 | — | TTL estourou (24h email / 10min whatsapp) |
| `/auth/magic/consume` | `magic_context_mismatch` | 401 | — | Device fingerprint divergente (IP/16 ou UA hash) |

> **Removidos (early-202, 2026-06-11):** `whatsapp_circuit_open 503`, `whatsapp_transient 503`, `whatsapp_permanent 502` — não existem mais. `/otp/request` responde `202` imediato em todos os casos de envio; falha de provider não volta síncrona. UX que dependia desses erros deve oferecer canal alternativo **proativamente** ("não recebeu? tente e-mail") em vez de reagir a erro síncrono.

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

### B.4 — Regra de identidade (padrão único)

**Decisão canônica (2026-06-12):** `iid` é **atalho**, NUNCA requisito. O token traz `iid` **só quando a identidade já está provisionada** (login é lookup-only — quem provisiona é o signup via `POST /internal/identities[/v2]`).

**Regra dura: NUNCA quebre um user legítimo autenticado por falta de `iid`.** Padrão único vigente:

> **Fallback-pro-`sub` (Tasks-style, recomendado):** quando `iid` ausente no token, resolver por `sub` (`canal:handle` → email/phone); user inexistente local → **401** (não 404). Mais resiliente a drift/race entre signup e login. **Este é o padrão esperado em C2 do `auth-consumer`.**

**Coach = exceção documentada (nominal):** exige `iid`, MAS garante provisionamento de todo user + backfill de legados (invariante `iid` presente). Converte pro fallback quando conveniente; vira defesa em profundidade. **Não é um segundo caminho aberto para novos projetos.**

**Resolver contra a coluna CANÔNICA:** ao buscar user por `iid`, case contra a coluna de identidade canônica do produto (ex.: `tasks_identity_id`), **nunca** contra um id per-org (`user_id`) — senão 404a todo user mesmo COM `iid` válido, mascarado por smoke numa conta onde os dois ids coincidem por coincidência.

---

### B.5 — `POST /internal/whatsapp/check`

**Quando usar:** signup ou alteração de número — pré-flight para orientar o user se o número tem WhatsApp antes do 1º OTP. Com o contrato early-202 (Seção B.2), `/otp/request` não devolve mais erro síncrono de provider; sem esse check, o user descobre que o número não tem WhatsApp só quando não recebe o código.

**Authorization:** `X-Internal-Auth: <consumer secret>` (per-consumer, Seção C). **NUNCA expor publicamente** (oracle de enumeração de números).

**Request/Response:**
```http
POST /internal/whatsapp/check HTTP/1.1
X-Internal-Auth: <internal_key_<consumer>>
Content-Type: application/json

{ "phone": "+5567933009440" }
```

```json
{ "phone": "+5567933009440", "has_whatsapp": true }
```

| `has_whatsapp` | Significado |
|---|---|
| `true` | Número ativo no WhatsApp |
| `false` | Número não registrado no WhatsApp |
| `null` | Provider indisponível — **fail-open: NUNCA bloqueie o cadastro por `null`** |

**Rate limit:** 120/h por consumer (não por destino). **Status:** ✅ em prod (`[2-E]`).

---

### B.6 — Sessão durável — `#rt=` e `/otp/refresh` obrigatórios (consumer-side)

> **Gap confirmado (2026-06-16, Plexco Coach):** o bridge lia só `#at=` do fragmento e ignorava
> `#rt=` → usuários precisavam refazer OTP a cada expiração do access token (~15 min).

**Regra:** ao consumir o fragmento `#at=<JWT>&rt=<refresh>` (magic-link OU redirect pós-OTP
validate), o frontend **DEVE** ler e persistir **ambos**:

- `at` = access token JWT EdDSA (validade 15 min) — Bearer em todas as chamadas API.
- `rt` = refresh token opaco (validade 30 d, rotation RFC 6749 §10.4) — **obrigatório** para
  renovar o `at` sem forçar novo OTP. **Sem `#rt=`, sessão dura só o TTL do access token.**

**Refresh canônico:**
```
POST /otp/refresh { "refresh_token": rt, "audience": AUDIENCE }
→ { access_token, refresh_token, expires_in, refresh_expires_in }
```

Rotation single-use: o `rt` usado é **invalidado**. Serialize no cliente — 2 requests
concorrentes com o mesmo `rt` invalidam toda a família (anti-theft RFC 6749 §10.4).

**O auth-service sempre inclui `rt` no fragmento** quando há `default_redirect_uri` configurada.
A responsabilidade de lê-lo é do consumer (bridge frontend). Ver `CONSUMIR_AUTH_SERVICE.md` §3.

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

> **⚠️ Atualização Pilar 1 (v2 — Seção L): emissão combinada.** O v1 cravou OTP e magic **exclusivos por canal** (tabela abaixo). O **Pilar 1** do Padrão Auth Percus v2 **supersede**: `POST /otp/request` passa a emitir **código OTP E magic-link juntos, na mesma mensagem**, sem opt-in. Os **TTLs por canal abaixo permanecem inalterados** (muda só que os dois saem juntos); as mitigações do magic-link 24h seguem **intactas**. **Status:** 🔶 Sprint A — até o deploy, o comportamento vigente em prod ainda é o exclusivo da tabela; **projetos novos já codam para o par combinado.**

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

Boilerplate em `_Novo_Projeto/templates/login-ui/` (referência copy-paste atual). **Pilar 3 (v2 — Seção L)** promove esses componentes à lib versionada **`@percus/auth-ui`** (`<LoginForm/>`/`<SignupForm/>`/`<CountrySelector/>`/`<PhoneInput/>`, branding data-driven via `getTenantConfig()`); reference = 9 arquivos do Plexco Tasks (cross-repo, read-only). **Status:** ⬜ Sprint C — lib **ainda não publicada**; até lá, `templates/login-ui/` é a referência. **Gate visual** (claude.ai/design) antes de codar o componente novo.

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
| OTP via e-mail como canal **primário** | Magic-link é o primário no e-mail; com Pilar 1 (v2) o par OTP+magic é emitido junto, preferência de canal mantida (Seção G/L). |
| Magic-link via WhatsApp como canal **primário** | OTP é o primário no WhatsApp; Pilar 1 (v2) emite o par junto (Seção G/L). |
| INSERT direto em `auth.audiences` em prod | PR no auth-service repo (Seção D). |
| Hardcode de phone normalize com regex `\D` | `from percus_auth import normalize_phone`. |
| Mandar `origin` arbitrário no `/internal/identities` | `origin` vem derivado do secret. Use `origin_context` pra sub-contexto. |
| `internal_key` global compartilhado entre todos consumers | Per-consumer secret obrigatório (Seção C). |
| UUIDv4 como magic-link code | `secrets.token_urlsafe(32)` (128-bit entropy). |
| Device fingerprint opcional no magic 24h | Mandatory bind a IP/16 + UA hash (Seção G). |
| `iid` ausente → 404 user legítimo | Fallback-pro-`sub` (B.4): quando `iid` não vem no token, resolver por `sub` (`canal:handle`). User inexistente → **401**, nunca 404. |
| Resolver user por id per-org (`user_id`) no lookup por `iid` | Case contra a coluna canônica da identidade (ex.: `tasks_identity_id`), nunca um id per-org. Id per-org coincide em alguns casos e mascara o bug. (B.4) |
| Bridge frontend que lê só `#at=` e ignora `#rt=` do fragmento | Leia **ambos** — sem `#rt=` a sessão dura só o TTL do access token (~15 min). Serialize o refresh (`POST /otp/refresh`). Ver B.6. |

---

## Seção L — Padrão Auth Percus v2 (5 pilares + status de rollout)

> **⚠️ Leia primeiro — vigente como direção, não como fato consumado.** Em 2026-05-30 o time do auth-service cravou (pós conselho 3/3) o **Padrão Auth Percus v2**: 5 pilares que **todo projeto Percus DEVE seguir**. Mas **nem tudo está em produção** — cada pilar carrega seu **status de rollout real**. Onde um pilar é *breaking* sobre contrato congelado (Seções B/G), ele entra com **versão paralela + janela ≥60d**, nunca flip silencioso. As Seções A–K acima seguem o **baseline vigente em prod**; esta seção é a camada v2 por cima.

**Spec consolidada (read-only, cross-repo):** `auth-service/docs/superpowers/specs/2026-05-30-padrao-auth-percus-design.md`.

### Tabela-mestra de rollout

| Pilar | Regra (projetos DEVEM) | Status real (2026-05-30) | Breaking / janela |
|---|---|---|---|
| **P1** Magic+OTP combinado | `/otp/request` emite código **e** magic na mesma msg (sem opt-in); signup coleta **`name+phone+email`** | 🔶 Sprint A — A2 (combinado early-202) ✅ prod 2026-06-07 (`deploy-1781205331`); `/v2` ✅ prod 2026-06-08 (`deploy-1780934677`); janela 60d em curso; P5 telemetria pendente | SIM → `/internal/identities/v2`, ≥60d, major bump `percus-auth` |
| **P2** Painel vira consumer | Painel descontinua OTP+HS256 próprio, persiste `identity_id`, ativa `internal_key_painel` | 🔶 Sprint B — B0+B1 ✅ feitos 2026-06-12 (consumer `painel` ativo, backfill 17/17); B2 (login consumer + dual-verifier) em andamento | dual-verifier **3-4 semanas** (Painel) — ver L.2 |
| **P3** Lib `@percus/auth-ui` | Componentes React versionados; branding data-driven via `getTenantConfig()`; divergir = versão velha no audit | ⬜ Sprint C — lib **não publicada**; `templates/login-ui/` é a referência até lá | n/a (gate visual antes de codar) |
| **P4** Enforcement 2 camadas | Contract tests CI (owner = time auth-service) + catálogo vivo no Painel (`catalog-info.yaml` + skill `percus-review:catalog-publish`) | ⬜ Sprint D — **não implementado** | smoke E2E cross-product **removido do escopo** |
| **P5** Telemetria OTel | Counters + latências de magic/otp/signup/identity → SigNoz | ⬜ Sprint A base — **SigNoz não subiu** | n/a |

**Legenda:** ✅ em prod · 🔶 em rollout/janela · ⬜ planejado.

### L.1 — Pilar 1: Magic+OTP combinado + signup `name+phone+email`
`/otp/request` emite OTP **e** magic-link juntos, na mesma mensagem (sem opt-in). TTLs por canal **inalterados** (Seção G). Signup obrigatório coleta `name+phone+email` → contract `/internal/identities/v2` (ver **B.1.v2**), breaking, ≥60d, major bump `percus-auth`. **Status:** 🔶 Sprint A — A2 (combinado, early-202) ✅ prod 2026-06-07 (`deploy-1781205331`); `/internal/identities/v2` ✅ prod 2026-06-08 (`deploy-1780934677`); P5 (telemetria) pendente.

### L.2 — Pilar 2: Painel vira consumer do auth-service
**Status:** 🔶 Sprint B em andamento. **B0** (consumer `painel` ativo) + **B1** (backfill `affiliates.identity_id` rodado+validado 2026-06-12, 17/17 afiliados) ✅ feitos. Bloqueador original (script de migração `old_user_id→identity_id`) **concluído** (`auth-service/docs/proposals/2026-05-30-painel-identity-migration.md`). Próximo: **B2** = login consumer + dual-verifier 3-4 semanas (específico do Painel pelo volume de afiliados). Alvo final: descontinuar auth próprio (OTP+HS256 em `execution/api/authOtp/`), chamar `/internal/identities`, persistir `identity_id`, ativar `internal_key_painel` (já provisionado).

### L.3 — Pilar 3: lib `@percus/auth-ui`
Componentes React versionados (`<LoginForm/>`, `<SignupForm/>`, `<CountrySelector/>`, `<PhoneInput/>`), branding por-tenant data-driven via `getTenantConfig()`. Cada projeto importa; divergir = versão velha aparece no audit do catálogo (P4). Reference canônica = 9 arquivos do Plexco Tasks (cross-repo, read-only). **Gate visual** (claude.ai/design) antes de codar o componente novo. **Status:** ⬜ Sprint C — lib **não publicada**; até lá `templates/login-ui/` é a referência.

### L.4 — Pilar 4: enforcement em 2 camadas
(1) **Contract tests em CI** (owner = time auth-service) — falha bloqueia PR. (2) **Catálogo vivo no Painel** — `catalog-info.yaml` declara versões, Painel mostra drift, via skill `percus-review:catalog-publish` (ver `05_FEATURE_TRACKING.md`). **Smoke E2E cross-product diário foi removido do escopo** (decisão operador 2026-05-30; reabrir só se drift escapar pra prod). **Status:** ⬜ Sprint D.

### L.5 — Pilar 5: telemetria OTel cross-product
Métricas mínimas (counters + latências): `auth.magic.issued/delivered/consumed`, `auth.otp.requested/validated/failed`, `auth.signup`, `auth.identity.linked`; latências de `/otp/request`, `/otp/validate`, `/auth/magic/consume`. Exporter → SigNoz. Absorve a audit-chain do sprint hardening cancelado, redesenhada como "audit trail via OTel exporter". **Status:** ⬜ Sprint A base — SigNoz **não subiu**. (Cruza R14 em `01_REGRAS_INEGOCIAVEIS.md`.)

### Sequência de rollout (~10-12 semanas)

| Sprint | Quando | O quê |
|---|---|---|
| **0** | ✅ 2026-05-30 | Deploy `fb7943e` (magic IP-bind → UA-bind) |
| **A** | 🔶 em andamento | A2 (combinado early-202) ✅ 2026-06-07; `/v2` ✅ 2026-06-08; P5 (telemetria) pendente |
| **B** | 🔶 em andamento | B0+B1 ✅ 2026-06-12; B2 (login consumer + dual-verifier) em andamento |
| **C** | Sem 4-6 (∥ B) | P3 (lib `@percus/auth-ui`) — gate visual antes de codar |
| **D** | Sem 7-10 | P4 (enforcement 2 camadas) |

> Datas absolutas das janelas de 60d: **TBD a partir do deploy de cada `/v2`** (a definir pelo time auth-service).

### Sprint hardening anterior — encerrado
`auth-service/docs/superpowers/plans/2026-05-20-security-hardening-sprint.md` foi formalmente fechado (pós conselho 3/3, Opção B: cancelar + absorver): T1 (config multi-key) preservada; T2-T6 → hardening-phase-2 (Q2+); T7-T11 (audit chain) → **redesenhada no Pilar 5**; T12-T13 (handleFragment) → **movida pro Pilar 3**.

### Dependências cross-repo (⛔ read-only — não editar daqui)
- `auth-service/docs/superpowers/specs/2026-05-30-padrao-auth-percus-design.md` — spec consolidada dos 5 pilares.
- `auth-service/docs/proposals/2026-05-30-painel-identity-migration.md` — migração `old_user_id→identity_id` (bloqueia P2).
- `@percus/auth-ui` — lib **não publicada** (bloqueia P3); reference = 9 arquivos Plexco Tasks.
- SigNoz/OTel — containers **não deployados** (bloqueia P5).
- `D:\Claud Automations\OWNERSHIP.md` — quadro de ownership, **fora do canon**.

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
R: Sim. No WhatsApp o **canal primário é OTP**; com o Pilar 1 (v2 — Seção L) o `/otp/request` passa a emitir o **par OTP+magic** na mesma mensagem (rollout 🔶 Sprint A). Magic **como único** canal no WhatsApp segue desaconselhado (preview-bot queima single-use).

**P: O que acontece se eu mandar `origin: "painel"` no payload do `/internal/identities` mas meu secret é `internal_key_plexco`?**
R: Auth-service ignora seu payload e grava `origin=plexco-tasks`. `origin_context` é o campo pra sub-contextos (`{"origin_context": "invitation:42"}` → `origin=plexco-tasks:invitation:42`).

---

## Onde aprofundar

- **Decisão arquitetural completa** (premissas, alternativas, why-not big-bang): `D:\Claud Automations\OWNERSHIP.md`
- **Padrão Auth Percus v2 (5 pilares):** Seção L acima + spec consolidada `auth-service/docs/superpowers/specs/2026-05-30-padrao-auth-percus-design.md` (read-only, cross-repo)
- **Receita passo-a-passo projeto novo**: `checklists/CHECKLIST_AUTH_NOVO_PROJETO.md`
- **Registry de error_codes**: [docs/contracts/error-codes.md](docs/contracts/error-codes.md)
- **Registry de reasons**: [docs/contracts/redirect-reasons.md](docs/contracts/redirect-reasons.md)
- **Migração V1→V2 (cross-repo grep guide)**: [docs/contracts/MIGRATION_V1_TO_V2.md](docs/contracts/MIGRATION_V1_TO_V2.md)
- **Regra R19 (identidade canônica)**: `01_REGRAS_INEGOCIAVEIS.md`
- **Aprendizados Plexco originais (absorvidos na Seção I)**: removidos do canon em v6.11.0; ver git history se precisar (`git log --diff-filter=D -- AUTH_SERVICE_PATTERNS_LEARNED_2026-05-15.md`).
- **Review de Etapa 1 Strangler**: removido em v6.11.0 (era review de momento da sessão 35 de 2026-05-14/15; decisões já refletidas neste doc).

---

**Mantenedor:** estúdio Percus, time core. Mudanças via PR no `huboperacional/percus-kit`.
**Última atualização:** 2026-06-13 (decisões auth 2026-06-12: early-202 B.2, regra de identidade B.4, `/internal/whatsapp/check` B.5, rollout status E4; v6.16.0 — Seção L absorve o Padrão Auth Percus v2). Baseline Seções A–K: V2 cravado 2026-05-15 pós-conselho rodada 2.
**Histórico:** V1 (`PADRAO_AUTH_CROSS_PROJETO.md`) arquivado em `.archive/` — substituído por este V2.
