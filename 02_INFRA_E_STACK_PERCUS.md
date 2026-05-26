---
tipo: stack-e-infra-canonica
prevalece-sobre: [comandos/*, decisões locais quando não justificadas]
prevalecido-por: [01_REGRAS_INEGOCIAVEIS, CLAUDE.md do projeto]
quando-usar: ao iniciar projeto novo OU ao tomar decisão técnica em projeto existente
leitura: 16 min (consulta por seção, não leitura linear)
ultima-atualizacao: 2026-05-06
---

# 02 — Infraestrutura e Stack Padrão Percus

> **Single source of truth** da stack técnica + infra de todos os projetos Percus.
> Cobre: backend, frontend, auth, banco, redis, VPS, Traefik, DNS, secrets, deploy.
> Cada seção tem **decisão + como executar + vetado**.

---

## 0. Princípios não-negociáveis

1. **Isolamento total entre projetos.** Nenhuma biblioteca compartilhada entre repositórios. Conexão entre projetos só via API HTTP autenticada (nunca import direto). Cada projeto é dono do próprio código.
2. **Zero Supabase em projetos novos.** GoTrue, PostgREST, `@supabase/supabase-js` e Supabase Cloud estão **vetados**. Projetos legados têm rota de migração (Seção 11).
3. **FastAPI default no backend.** Todo backend de produto novo é Python 3.11+ com FastAPI. **Exceção formal:** serviços de infraestrutura compartilhada (auth-service, queue worker, gateway) podem usar tier-1 do domínio (ex.: Go pra auth-service quando footprint mínimo for crítico) com justificativa escrita no PLANO.md. Padrão é FastAPI até prova em contrário.
4. **Frontend escolhido por perfil de produto.** Vite+React 19 pra dashboards/apps internos; Next.js 15 só quando SEO/SSR for crítico.
5. **Auth centralizado, validação local.** Auth-service Percus é a fonte única de identidade/JWT/refresh/magic-links. Cada projeto valida JWT **localmente** via lib `percus-auth` (zero RTT por request). Nunca depende de servidor de auth de terceiros (Auth0, Clerk, Supabase). Detalhes em Seção 2.
6. **Tudo no VPS Percus.** Banco, cache, API, frontend — tudo no VPS `161.97.129.138` via Docker Swarm + Traefik.

---

## 1. Backend — FastAPI canônico

### 1.1. Stack

| Componente | Escolha | Versão alvo |
|---|---|---|
| Linguagem | Python | 3.11+ |
| Framework HTTP | FastAPI | latest stable |
| Validação | Pydantic v2 | latest |
| ORM/DB driver | SQLAlchemy 2.x async ou asyncpg puro | latest |
| Migrations | Alembic | latest |
| Settings | pydantic-settings (lê `.env`) | latest |
| Logging | structlog (JSON) | latest |
| Testes | pytest + pytest-asyncio + httpx | latest |
| Background tasks | FastAPI BackgroundTasks ou ARQ (se filas) | latest |

### 1.2. Estrutura de diretórios

```
projeto/
├── services/
│   └── api/
│       ├── app/
│       │   ├── core/{config,security,utils}.py
│       │   ├── modules/
│       │   │   ├── auth/{router,service,schemas,models}.py
│       │   │   └── <dominio>/{router,service,schemas,models}.py
│       │   ├── models/              # SQLAlchemy models compartilhados
│       │   ├── db/                  # session, engine
│       │   └── main.py              # FastAPI app + routers
│       ├── alembic/
│       ├── tests/
│       ├── Dockerfile
│       ├── pyproject.toml
│       └── requirements.txt
```

### 1.3. Convenções

- **Endpoints REST explícitos** agrupados por módulo (`/auth/otp/request`, `/investors`, `/properties/{id}`).
- **OpenAPI** gerado automaticamente pelo FastAPI; frontend tipa via `openapi-typescript` ou `orval`.
- **Async em tudo que toca I/O** (DB, HTTP, fila).
- **Dependency injection nativa** do FastAPI pra session de DB, user atual, settings.
- **Raise de exceções tipadas** (`HTTPException` com detail Pydantic) — nunca string solta.

### 1.4. Vetado no backend

- Auto-API (PostgREST e similares).
- Express/Fastify (Node) pra backend de **produto** novo. (Infra-tier — auth-service, gateways — pode fugir do FastAPI sob exceção formal do Princípio 3.)
- Sequelize/Prisma (use SQLAlchemy 2.x async ou asyncpg).

---

## 2. Auth — auth-service centralizado + lib `percus-auth` local

### 2.0. Estados de adoção

A arquitetura final é **um auth-service Percus único** consumido por todos os projetos via lib local. Como auth-service v1 ainda está em build, há 3 estados possíveis pra um projeto:

| Estado | Quando | Arquitetura |
|---|---|---|
| **Final (auth-service v1+)** | Projeto greenfield iniciado após auth-service v1 publicado | Sem auth próprio. Lib `percus-auth` valida JWT local via JWKS. Login via `auth-service.percus.internal`. |
| **Transição (sidecar interino)** | Projeto greenfield iniciado antes de auth-service v1 | Sidecar FastAPI próprio (forma B na Seção 2.5) com OTP+JWT HS256, schema `otp.codes` compatível. Migra pra `percus-auth` quando v1 sair, sem refazer fluxo. |
| **Legado** | Projetos pré-Fase 5 com Supabase/GoTrue/NextAuth/senha pura | Seguem `comandos/MIGRAR_AUTH.md` (V1-V4). Migram diretamente pro estado Final quando auth-service v1 sair, ou pra Transição como ponte. |

**Cutover do estado Transição → Final** é dual-verifier rolling 7 dias (auth-service emite EdDSA, projeto valida ambos algoritmos durante janela do TTL do cookie antigo). Detalhes em runbook do auth-service.

### 2.1. Métodos suportados

| Método | Status | Quando usar |
|---|---|---|
| **OTP via WhatsApp** | **Primário** | Default em todo projeto; 6 dígitos, TTL 5-10 min |
| **OTP via email** | Fallback obrigatório | Auto-fallback após 3 falhas WhatsApp consecutivas |
| **Magic link** | Primitiva centralizada | First-login, convite, reset de phone/email — via `/auth/magic/*` do auth-service (R17) |
| **TOTP step-up** | Obrigatório pra role admin | Enrollment no primeiro login da role admin; valida em ações privilegiadas |
| **Senha** | Vetado em projetos novos | Dívida de phishing/credential-stuffing sem ganho |
| OAuth (Google/etc.) | Caso especial | Integrações com Google APIs (Drive, Calendar) no perfil — não pra login de produto |

### 2.2. Tokens — JWT EdDSA + refresh opaco em Redis

**Estado Final (auth-service v1+):**
- **Algoritmo:** JWT **EdDSA (Ed25519)** — chave pública 32 bytes, mais rápido que RSA, imune a side-channel attacks.
- **Access token:** TTL **15 minutos**, validação local via JWKS público (`/.well-known/jwks.json`, cache 1h em cada projeto).
- **Refresh token:** **opaco** (UUID/random 256 bits), salvo em Redis com TTL **30 dias**, **rotation a cada uso + family invalidation** (RFC 6749 §10.4 / OAuth 2.1).
- **Claims do access token:**
  ```json
  {
    "sub": "identity-uuid",
    "aud": "produto-slug",
    "org": "organization-slug",
    "roles": ["admin","editor"],
    "iat": ..., "exp": ...
  }
  ```
- **Rotação de chave Ed25519:** publica nova `kid` no JWKS (overlap), aguarda TTL JWKS dos consumidores (1h), começa a assinar com nova, aguarda TTL access (15min), remove kid antigo. Zero downtime.

**Estado Transição (sidecar interino):**
- HS256 com `JWT_SECRET` dedicado **por projeto** (nunca reaproveitar — bug histórico). Expiração 7 dias. Refresh ainda opaco em Redis se possível.
- Claims compatíveis com formato Final pra facilitar cutover.

**Vetado em qualquer estado:**
- Refresh token JWT stateless (sem revogação).
- HS256 com chave compartilhada cross-projetos (blast radius global).
- `localStorage` pra access ou refresh token.
- Cookie `SameSite=None` cross-site (R16).

### 2.3. Modelo de identidade — Identity → Organization → Product (3 camadas)

Multi-tenancy desde o dia 1, mesmo pra estúdio fechado. Tabelas no DB do auth-service (estado Final):

```sql
-- Pessoa física, email único cross-projetos
CREATE TABLE identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE,
    phone TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ,
    active BOOLEAN DEFAULT TRUE
);

-- Cliente: estúdio interno, empresa B2B externa, ou indivíduo B2C
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,  -- "internal" | "b2b_client" | "b2c_individual"
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'
);

-- Catálogo de produtos Percus (familia-api, plexco, paid-media, ...)
CREATE TABLE products (
    id UUID PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    active BOOLEAN DEFAULT TRUE
);

-- Quais produtos cada org tem ativos
CREATE TABLE subscriptions (
    organization_id UUID REFERENCES organizations(id),
    product_id UUID REFERENCES products(id),
    status TEXT NOT NULL,  -- "active"|"trial"|"suspended"|"cancelled"
    started_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}',
    PRIMARY KEY (organization_id, product_id)
);

-- Quem pertence a qual org com qual papel
CREATE TABLE memberships (
    identity_id UUID REFERENCES identities(id),
    organization_id UUID REFERENCES organizations(id),
    roles TEXT[] NOT NULL DEFAULT '{}',
    invited_at TIMESTAMPTZ DEFAULT NOW(),
    accepted_at TIMESTAMPTZ,
    PRIMARY KEY (identity_id, organization_id)
);
```

**O que NÃO mora no auth-service** (R7, R18):
- **Affiliations** (parent_id, tier1/tier2, comissão) — domínio comercial do Painel, não primitiva de auth.
- **Tracking attribution** (`?ref=`, last-click, UTM, cookies de marketing) — SDK `percus-tracking` separado.
- **Stripe webhooks / billing** — Painel resolve localmente sem chamar auth-service.

### 2.4. WhatsApp adapter — Evolution (default) + Cloud API oficial (per-audience)

**Estratégia híbrida:** todo projeto novo nasce em Evolution (custo zero, infra existente). Migra pra Cloud API oficial Meta quando algum critério dispara — sem refactor, só UPDATE em row de `auth.audiences`.

**Critérios pra migrar audience X pra Cloud API (basta 1):**
1. Volume sustentando >500 OTPs/dia OU >10k/mês (ban-risk Evolution vira material)
2. Receita do projeto > R$ 5k/mês (custo Cloud API insignificante vs eliminar risco)
3. Compliance B2B (audit trail Meta-validado pra healthcare/fintech/jurídico)
4. Health score do número Evolution <85% rolling 7d (flag iminente)
5. Pedido explícito do cliente

**Modelo de dados — `auth.audiences` (estado Final auth-service):**

```sql
-- Cada audience = 1 produto/projeto Percus (painel, familia, paid-media, plexco-coach, ...)
-- Audience é unidade de configuração: token aud claim, override de Evolution instance,
-- override de templates, override de delivery rules.
CREATE TABLE auth.audiences (
    slug TEXT PRIMARY KEY,                                -- "familia", "painel", ...
    name TEXT NOT NULL,
    whatsapp_provider TEXT NOT NULL DEFAULT 'evolution',  -- "evolution" | "cloud_api"
    whatsapp_config JSONB NOT NULL DEFAULT '{}',          -- evo: {instance, number}
                                                          -- cloud: {phone_number_id, token_secret_ref}
    active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
-- Admin CRUD em /admin/audiences exige step-up mfa:totp.
```

**Implementação — adapter pattern:**

```python
class WhatsAppSender(Protocol):
    def send(self, destino: str, codigo: str, audience: Audience) -> SendResult: ...
    def health_check(self) -> HealthScore: ...

class EvolutionSender(WhatsAppSender): ...   # default
class CloudAPISender(WhatsAppSender): ...    # ativado per-audience

# Resolver pega config da row da audience
audience = await audiences_repo.get(aud_claim_or_request_param)
sender = SenderRegistry.get(audience.whatsapp_provider)
sender.send(destino, codigo, audience=audience)
```

Auth-service ao mandar OTP olha `auth.audiences.whatsapp_provider` da audience alvo e dispatcha pro sender correto. Trocar provider de uma audience é UPDATE numa row, sem deploy.

**Por que audience-based (não tenant-based):** descoberta operacional durante Fase 3 do auth-service (2026-05-06). Audiences batem 1:1 com produtos Percus (painel, familia, paid-media, plexco-coach, plexco-tasks) — modelo mais alinhado com a realidade do estúdio do que "tenant" genérico. Audience também serve como `aud` claim do JWT.

### 2.5. Anti-bot WhatsApp (defesa em profundidade, ambos backends)

Necessário em ambos:
- **Evolution** (WhatsApp Web reverse-engineered): flag = ban permanente do número. Anti-bot é o que separa "número operacional 12 meses" de "número morto em 2 semanas".
- **Cloud API**: ban total improvável, mas throttle dinâmico do Meta degrada delivery se padrão for mecânico.

**9 componentes obrigatórios** (no auth-service ou no sidecar interino):

| # | Componente | Detalhe |
|---|---|---|
| 1 | Sequência humana | Evolution: presence=available → composing → delay 1.2-3s → sendText → paused. Cloud API: `typing_indicator: typing_on → delay → send → typing_off`. |
| 2 | Templates rotativos (3+ variantes) | Wording variado: "Seu código de acesso", "Seu código de verificação", "Código de login Hub". Cloud API exige approved templates. |
| 3 | Delay anti-burst | Worker single-thread por número, delay 800ms-1.5s aleatório entre envios sucessivos. |
| 4 | Number warm-up gradual | **CRÍTICO no Evolution.** Curve: 5/d D1, 20/d D2, 50/d D3, 200/d D7, full após D14. Evolution sem warm-up = ban em <14d. |
| 5 | Pool multi-número (2-3 nums) | Round-robin balanceado por health score. Tira número degradado automaticamente. |
| 6 | Time-of-day awareness | Throttle agressivo 1h-6h BR (-50% rate). Burst noturno = signal de fraude. |
| 7 | Health score por número | Rolling 24h delivered/sent. <90%: peso reduzido. <70%: quarantine 1h + alerta. |
| 8 | Auto-fallback canal | 3 falhas consecutivas WhatsApp → próxima tentativa via email automaticamente. |
| 9 | Anti-flood per-destino | Max 1 OTP **ativo** por destino simultâneo (Redis `SET NX EX`). |

**O que NÃO replicar do canon antigo:** "11 templates rotativos com sinônimos exóticos" era exagero. 3 templates approved + variação de horário/typing/delay supera isso porque Meta detecta por hash normalizado, não por string variation.

### 2.6. Rate limit canônico (R15 aplicado a auth)

- **Por destino canonicalizado:** 5 OTPs/h por email (lowercase + strip plus-tag) ou telefone (E.164).
- **Por IP /64 IPv6** (não /128): 10 OTPs/h.
- **Por código:** 5 tentativas antes de invalidar.
- **OTP ativo por destino:** 1 simultâneo (NX no Redis).
- **Implementação:** Redis `INCR + EXPIRE`, prefixo `auth:rl:{tipo}:{chave}`.

### 2.7. Cookie & SSO multi-domínio (R16 aplicado)

- **Cookie:** `httpOnly + Secure + SameSite=lax`, domínio compartilhado do apex (ex.: `.ads4pros.com` cobre `parceiros`, `gestao`, `vendas`).
- **Cross-domain (outro produto em outro apex):** redirect-fragment SSO via `auth.ads4pros.com/sso?return=...` → response inclui `#at=<jwt>` que JS lê e descarta.
- **Vetado:** `SameSite=None` cross-site (frágil em ITP/Brave 2026), token via query string (`?at=`), cookie 3rd-party.

### 2.8. Magic links — primitiva centralizada (R17)

API canônica do auth-service:
```
POST /auth/magic/issue { identity_id?|email|phone, purpose, redirect_uri, ttl_seconds }
  → { code, url: "https://auth.../w/{code}" }

GET /w/{code}
  → valida (single-use, TTL), emite JWT, 302 redirect_uri com #at=JWT

POST /auth/magic/consume { code }
  → variante programática, retorna access+refresh
```

Projetos consomem (não reimplementam). Surface crítico de bugs (replay, TTL bypass, single-use race) tem **uma** implementação.

### 2.9. Observabilidade (R14 aplicado a auth)

Auth-service emite obrigatoriamente:
- Trace OTel: `request → rate_limit_check → otp_generate → sender_dispatch → delivery_callback`
- Métricas: `whatsapp.delivery_rate` (por número, rolling 1h e 24h), `whatsapp.send_latency` p50/p95/p99, `whatsapp.number_health_score`, `whatsapp.fallback_to_email_count`, `auth.otp_failure_rate` (alerta se >X% = ataque).
- Audit trail: `auth.otp_audit_log` com hash chain (`prev_hash` cada row), arquivado pra MinIO em NDJSON+gzip após 90 dias.
- Sem PII em plain text — `destino` no log é SHA-256.

### 2.10. Padrão de deploy

**Estado Final (auth-service v1+):** projeto consome `auth-service.percus.internal` via Traefik interno. Não roda nada de auth localmente. Lib `percus-auth` no requirements.txt / package.json.

**Estado Transição (sidecar interino):**

**A) Backend unificado:** auth vive em `services/api/app/modules/auth/`. Mesmo container, mesma porta, mesma imagem.

**B) Sidecar dedicado:** quando backend principal não é FastAPI (Next.js API routes, Express), criar container separado `services/auth/` em FastAPI exclusivo. Traefik por path prefix:

```yaml
deploy:
  labels:
    - traefik.enable=true
    - traefik.http.routers.{slug}-auth.rule=Host(`{dominio}`) && PathPrefix(`/api/auth/`)
    - traefik.http.routers.{slug}-auth.priority=100
    - traefik.http.routers.{slug}-auth.tls.certresolver=letsencryptresolver
    - traefik.http.services.{slug}-auth.loadbalancer.server.port=8000
```

Cookie httpOnly compartilhado entre web e auth no mesmo apex. Banco e Redis compartilhados — único `DATABASE_URL` + `REDIS_URL`, prefixo Redis `{slug}:auth:*`.

### 2.11. Referência canônica (read-only)

`D:\Claud Automations\Claude Financas NEW\familia-api\app\modules\auth\service.py` — implementação OTP+JWT em produção.

`D:\Claud Automations\Painel Gestao e Afiliados\execution\api\authOtp\` — OTP V2 com 11 templates rotativos, rate-limit DB-based, presence simulation. Será absorvido como base do auth-service v1 (preservando schema `otp.codes`).

Ao iniciar projeto novo no estado Transição:
1. **Leia** essas referências (não importe).
2. **Adapte** ao schema do projeto.
3. **Copie** as primitivas estáveis: rate limit, anti-bot, idempotência, fluxo OTP.
4. Bug ou melhoria descoberta: conserta no projeto atual e propaga via PR pras referências.

### 2.12. Migração de auth legado

Se o projeto tem auth diferente (Supabase/GoTrue/NextAuth/senha pura), **não improvise** — siga `comandos/MIGRAR_AUTH.md` que tem 4 variantes (V1-V4) cobrindo cada cenário. Quando auth-service v1 sair, esse documento ganha variante V5 (legado → Final direto).

### 2.13. Distribuição de libs cliente — `/dist/` mount self-hosted

**Decisão:** lib `percus-auth` (Python + Node) é **self-hosted** pelo próprio auth-service via StaticFiles mount. Não usa PyPI privado, npm privado, ou registry pago.

**Como funciona:**

```python
# services/api/app/main.py
from fastapi.staticfiles import StaticFiles
from pathlib import Path

_dist_dir = Path("/app/dist")
if _dist_dir.is_dir():
    app.mount("/dist", StaticFiles(directory=str(_dist_dir)), name="dist")
```

```dockerfile
# Dockerfile populando /app/dist em build time
COPY --chown=auth:auth dist/ ./dist/
```

`dist/` contém:
- `percus_auth-<ver>-py3-none-any.whl` (wheel Python)
- `percus-auth-<ver>.tgz` (tarball npm)

**Consumidor instala direto da URL pública:**
```bash
pip install https://auth.huboperacional.com.br/dist/percus_auth-0.1.0-py3-none-any.whl

npm install https://auth.huboperacional.com.br/dist/percus-auth-0.1.0.tgz
```

**Por que esse pattern:**
- Zero dependência de PyPI privado pago (~$50-100/mês evitados)
- Zero coordenação com npm tokens / scopes privados
- Lib é versionada junto com a API que ela consome — release coordenado
- TLS Let's Encrypt do auth-service cobre integridade do download
- `pip install <url>` e `npm install <url>` são features nativas, sem custom resolver

**Aplicabilidade:** todo serviço Percus tier-1 que publica lib cliente própria pode usar mesmo pattern (`/dist/` mount + URL pública via Traefik). Validado em produção no auth-service desde 2026-05-06.

### 2.14. Webhooks de provider — stub-first

**Pattern:** quando integramos provider externo que oferece webhooks (Evolution `messages.update`, Stripe `payment_intent.*`, GitHub `push`, etc.), criar **endpoint stub primeiro** mesmo antes da business logic existir.

**Estrutura mínima:**

```python
# services/api/app/modules/webhooks/<provider>.py
from fastapi import APIRouter, Request
import structlog

router = APIRouter(prefix="/webhooks", tags=["webhooks"])
log = structlog.get_logger()

@router.post("/<provider>")
async def webhook_<provider>(request: Request) -> dict:
    payload = await request.json()
    log.info("webhook.<provider>.received",
             event=payload.get("event"),
             instance=payload.get("instance"),
             # NUNCA logar payload completo se contém PII — usar SHA-256 do destino
             payload_keys=list(payload.keys()))
    # TODO Fase X: business logic aqui (atualizar health-score, audit log, etc.)
    return {"status": "received"}
```

**Por quê stub-first:**
1. **Provider precisa de URL pra registrar** — sem endpoint, integração trava
2. **Payload real chega** assim que registrado — você descobre formato real, não documentação desatualizada
3. **Audit log começa a coletar dados** desde dia 1, mesmo sem regras consumindo
4. **Business logic é separada da disponibilidade do endpoint** — você pode adicionar consumer (worker, hash chain, alerta) sem mudar URL

**Regras:**
- Endpoint **sempre 200** se payload é JSON válido (provider re-tenta agressivo em 4xx/5xx)
- Validação de assinatura (Stripe `Stripe-Signature`, etc.) **obrigatória** quando provider oferece
- Sem PII em log — destino vira SHA-256
- TODO marker explícito apontando pra fase em que business logic entra

Validado em prod no auth-service via `POST /webhooks/evolution` desde 2026-05-06 (recebendo `messages.update` em produção sem business logic — base pra anti-bot health-score da Fase 4).

### 2.15. CORS allowlist env-driven

**Pattern:** lista de origins CORS lida de env var `<SLUG>_CORS_ALLOWED_ORIGINS` (ou `CORS_ALLOWED_ORIGINS` quando único serviço). Atualizar lista = restart do container, não rebuild.

```python
# services/api/app/core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    cors_allowed_origins: list[str] = []
    cors_allow_credentials: bool = True

    class Config:
        env_file = ".env"
        # Pydantic parse list[str] de env: separado por vírgula
```

```bash
# .env
CORS_ALLOWED_ORIGINS=https://familiamilionaria.app,https://www.familiamilionaria.app,http://localhost:3000,http://localhost:5173
```

```python
# services/api/app/main.py
from app.core.config import get_settings
_settings = get_settings()

app.add_middleware(
    CORSMiddleware,
    allow_origins=_settings.cors_allowed_origins,
    allow_credentials=_settings.cors_allow_credentials,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
    max_age=3600,
)
```

**Vetado:** lista hardcoded em código, `allow_origins=["*"]` em produção, `allow_origins=["*"]` com `allow_credentials=True` (browser bloqueia, pattern errado).

**Gate:** smoke E2E com origin permitido + origin não permitido — segundo deve receber CORS error.

### 2.16. Outbound HTTP resilience — pre-bake utilities (Fase 3.5)

**Decisão:** todo serviço tier-1 que faz outbound HTTP a provider externo (Evolution, Stripe, SMTP, JWKS de outros services, etc.) deve ter **utilities de resiliência pré-instaladas** mesmo antes de wirar no caller.

**Utilities canônicas:**

| Componente | Função | Localização sugerida |
|---|---|---|
| `CircuitBreaker` | Open/half-open/closed por endpoint, threshold de falhas, cooldown configurable | `app/core/circuit_breaker.py` |
| `LogAggregator` | Agrupa N falhas similares em 1 log line, evita log spam durante outage | `app/core/log_aggregator.py` |
| Worker knobs em `config.py` | Defaults conservadores: `worker_max_retries`, `worker_backoff_base_ms`, `worker_jitter_ms`, `worker_circuit_breaker_threshold`, `incident_alert_webhook_url`, etc. | `app/core/config.py` |
| `<service>-resilience.md` | Doc de decisão arquitetural ANTES de código (stale-while-revalidate? cold-start behavior? kid force-refetch? quando NÃO adicionar breaker custom?) | `services/api/docs/runbooks/` |

**Por que pre-bake:**
1. Utilities ficam dormindo (testadas, em git) até worker real precisar
2. Decisão arquitetural escrita ANTES evita re-discutir sob pressão durante incidente
3. Cross-project: padrões de resilience são copiáveis entre serviços tier-1
4. Drill staging fica trivial — `shutdown auth-service 5min, mede p99 com stale-while-revalidate, decide com dados se lib JWKS precisa breaker custom`

**Validado:** auth-service Fase 3.5 (2026-05-06) — `CircuitBreaker` (8 testes verde) + `LogAggregator` (9 testes verde) + 9 worker knobs + doc `jwks-resilience.md` com 7 decisões. Wire real em Fase 4 anti-bot.

**Cross-ref:** pattern original em `D:/Claud Automations/Plexco Tasks/docs/cross-project-patterns/outbound-http-resilience.md` v1.0.

---

## 3. Banco de dados

### 3.1. PostgreSQL

| Item | Valor |
|---|---|
| Versão | PostgreSQL 17 (com pgvector quando precisar embeddings) |
| Local | self-hosted no VPS, container `postgres_postgres` (ID `fa51b72244ac`) compartilhado |
| Imagem | `pgvector/pgvector:pg17` |
| Superuser | `postgres` / `BCuLDV0qCBGzxOx4Cnga5hnL` |
| Database por projeto | **um por projeto**, naming `{slug_projeto}_v{N}` (ex: `micro_investors_v2`, `familia_milionaria_v1`) |
| Role por projeto | **uma por projeto**, naming `{slug_projeto}_user`, senha forte em Docker secret |
| Migrations | Alembic (não SQL puro). Versionadas no repo, aplicadas via script Python idempotente |

**Vetado:** reutilizar database/role de outro projeto. Mesmo "só pra teste rápido".

**Como criar database novo:**
```sql
CREATE DATABASE meu_projeto_v1;
CREATE ROLE meu_projeto_user WITH LOGIN PASSWORD 'senha_forte';
GRANT ALL PRIVILEGES ON DATABASE meu_projeto_v1 TO meu_projeto_user;
\c meu_projeto_v1
GRANT ALL ON SCHEMA public TO meu_projeto_user;
```

### 3.2. Redis

| Item | Valor |
|---|---|
| Versão | Redis 7.4 |
| Local | self-hosted no VPS, container `redis_redis` compartilhado |
| Imagem | `redis:7.4-bookworm` |
| Porta | 6379 (interno ao Swarm) |
| Namespace por projeto | **prefixo obrigatório** `{slug_projeto}:*` em todas as chaves |

**Padrão de TTL por categoria:**

| Categoria | TTL | Exemplo de chave |
|---|---|---|
| Curto prazo | 5-30 min | `{slug}:short:otp:abc123` (OTP, sessões temporárias) |
| Médio prazo | 1-24h | `{slug}:mid:cache:api_xyz` (cache de queries, rate limit) |
| Longo prazo | 7-30 dias | `{slug}:long:history:user_456` (histórico, dados pré-computados) |

---

## 4. API — REST + OpenAPI

### 4.1. Princípios

- **Endpoints explícitos por módulo.** Frontend chama URLs estáveis (`/api/investors`, `/api/properties/{id}/sales`).
- **OpenAPI** gerado automaticamente pelo FastAPI. Disponível em `/docs` (Swagger) e `/openapi.json`.
- **Tipos no frontend** vêm do OpenAPI via `openapi-typescript` ou `orval` (gera client tipado em build time).
- **Versionamento:** sem prefixo `/v1` por default. Se quebra de contrato necessária, criar `/v2` específico.

### 4.2. Vetado

- **PostgREST** ou qualquer auto-API que exponha schema do banco direto.
- **GraphQL** sem necessidade explícita justificada.
- **`@supabase/supabase-js`** no frontend.

---

## 5. Frontend

### 5.1. Decisão por perfil de produto

| Perfil | Stack | Justificativa |
|---|---|---|
| **Dashboard, painel interno, app autenticado** (default) | Vite 6 + React 19 + TypeScript 5 + Tailwind 4 + shadcn/ui + TanStack Router + TanStack Query + Zustand | SPA leve, dev server rápido, sem complexidade SSR. TanStack Router type-safe end-to-end. |
| **Landing page, e-commerce, conteúdo público com SEO** | Next.js 15 (App Router) + React 19 + TypeScript 5 + Tailwind 4 + shadcn/ui | SSR + RSC + image optimization importam quando há tráfego anônimo indexado. |

Use o **default Vite** a não ser que o produto tenha tráfego público SEO-dependente.

### 5.2. Stack comum

- **Estilo:** Tailwind 4 + shadcn/ui (componentes copiados pro repo, não pacote).
- **Forms:** react-hook-form + zod.
- **Data fetching:** TanStack Query (Vite) ou React Server Components + Query (Next).
- **HTTP client:** `fetch` nativo + wrapper tipado em `lib/api.ts`, **ou** `ofetch`. Tipos vêm do OpenAPI.
- **Auth no client:** JWT em cookie httpOnly **ou** em memória + refresh. **Nunca localStorage.**
- **State leve:** Zustand. Sem Redux.
- **Testes:** Vitest + React Testing Library; Playwright pra E2E.

### 5.3. Vetado no frontend

- `@supabase/supabase-js` e `@supabase/auth-helpers-*`.
- `localStorage` pra armazenar JWT.
- Redux (use Zustand).
- CSS-in-JS runtime (use Tailwind).

### 5.4. Ferramentas de design aprovadas

| Pedido | Ferramenta default | Por quê |
|---|---|---|
| Componente isolado (button, modal, table, form) | **shadcn MCP** (skill `vercel:shadcn`) — `npx shadcn@latest add <comp>` | Já é a stack vigente (Tailwind 4 + shadcn); custo Claude quase zero |
| Tela / fluxo novo, alta fidelidade visual | **v0.dev** (Vercel) | Browser próprio, créditos próprios; gera React/Tailwind alinhado ao stack |
| Iteração sobre tela existente | Edição local + `npm run dev` | Tela real é o feedback loop |
| Diagrama / wireframe | **Excalidraw** ou **Mermaid** em markdown | Versionável, sem dependência externa |

**Vetado para produção visual:** Claude artifacts (claude.ai/design) — disponibilidade instável bloqueia trabalho. Usar apenas como rascunho descartável quando estiver up.

**Workflow detalhado:** `comandos/DESIGN_WORKFLOW.md`. Trigger e gate em `01_REGRAS_INEGOCIAVEIS.md` R10.

### 5.5. Alocação central de portas locais (R22)

Cada projeto Percus recebe um **bloco de 20 portas locais** alocado pelo Painel de Gestão (`POST /admin/projects/port-allocate` → cache em `.percus-ports.json`). Resolve colisão silenciosa quando rodar 2 projetos simultaneamente em dev. **Endpoint vivo em produção desde 2026-05-26** (`api.ads4pros.com`).

**Range global:** 3000–9999 (≈349 projetos × 20 portas — expandido em v6.10.0). Source of truth na coluna `projects.port_base` da Painel (UNIQUE parcial). Auditoria visual: `https://gestao.ads4pros.com/projetos.html` (badge `PORTS 3020·3039`).

**Concorrência:** o endpoint serializa alocações via `pg_advisory_xact_lock(4242)` + UNIQUE INDEX `uq_projects_port_base`. 2 consultas simultâneas do mesmo slug retornam o mesmo `port_base` (idempotência); slugs distintos recebem blocos diferentes garantidos pelo lock.

**Tabela canônica de offsets — bloco de 20** (alinhada com [PORT_ALLOCATION_CONSUMER_GUIDE.md](D:/Claud%20Automations/Painel%20Gestao%20e%20Afiliados/docs/PORT_ALLOCATION_CONSUMER_GUIDE.md)):

| Offset | Uso típico |
|---|---|
| `+0` | Dev server principal (Vite/Next/Fastify/uvicorn) |
| `+1` | Preview/build (`vite preview`, `next start`) — ou backend secundário em full-stack |
| `+2` | Storybook |
| `+3` | Playwright UI mode |
| `+4` | Mock server / MSW |
| `+5` | Backend FastAPI/uvicorn (full-stack) |
| `+6` | Worker (celery/rq/cron-runner) |
| `+7` | Postgres local dedicado |
| `+8` | Redis local dedicado |
| `+9` | MinIO / object storage local |
| `+10` | Mailhog / dev SMTP UI |
| `+11` | Outro daemon (Tauri sidecar, electron-builder, etc.) |
| `+12..+19` | Reserva — documente em `docs/PORTS.md` |

Convenção é **sugestão**: projetos full-stack podem remapear como precisarem. Decisão do projeto fica em `docs/PORTS.md`. O que **não** muda: **20 portas**, começa em `${PERCUS_PORT_BASE}`, nada exposto fora do bloco.

**Como configurar (uma vez por projeto):**

```bash
# 1. Aloca port_base via Painel (idempotente, endpoint vivo).
python "${PERCUS_CANON_DIR}/plugin/percus-review/scripts/port_allocate.py" \
  --slug meu-projeto --name "Meu Projeto"
# stdout: PERCUS_PORT_BASE=3140

# 2. Adiciona ao .env.example e .env do projeto.
echo "PERCUS_PORT_BASE=3140" >> .env.example

# 3. vite.config.ts (frontend Vite — strictPort OBRIGATÓRIO):
#   server: { port: Number(process.env.PERCUS_PORT_BASE), strictPort: true }
#   preview: { port: Number(process.env.PERCUS_PORT_BASE) + 1, strictPort: true }

# 4. package.json scripts (Next.js):
#   "dev": "next dev --port 3140"
#   "storybook": "storybook dev -p 3142 --no-open"

# 5. uvicorn (backend full-stack mapeado em +5):
#   uvicorn.run(app, port=int(os.environ['PERCUS_PORT_BASE']) + 5)

# 6. docker-compose.yml — expose host port:
#   ports: ["${PERCUS_PORT_BASE}:3000"]
```

`.percus-ports.json` (versionado em git) guarda o estado:

```json
{"slug": "meu-projeto", "port_base": 3140, "range_end": 3159, "unverified": false}
```

**Infra compartilhada do VPS (Postgres 5432, Redis 6379, MinIO 9000) fica fora do bloco.** Bloco do projeto cobre infra **local** dedicada — se um projeto subir Postgres local dedicado, usa `+7` (não a porta 5432 padrão, que não é controlada pelo Painel).

**Fallback offline** (exceção pós-deploy 2026-05-26): se Painel inacessível na alocação inicial, o wrapper cai em `hash(slug) % 350 → 3000 + hash*20` e marca `unverified: true`. Próxima execução com Painel online reconcilia (chance baixa de hash collision — detectada no reconcile, re-aloca slot novo).

**Manual operacional completo:** `Painel Gestao e Afiliados/docs/PORT_ALLOCATION_CONSUMER_GUIDE.md` (snapshot de alocações vigentes, troubleshooting, smoke direto via curl). **Regra:** `01_REGRAS_INEGOCIAVEIS.md` R22.

---

## 6. VPS — infraestrutura física

### 6.1. Servidor

| Item | Valor |
|---|---|
| IP | `161.97.129.138` |
| Plano | Cloud VPS 20 — 6 vCPU, 12 GB RAM, 200 GB SSD |
| Portainer | https://painel.huboperacional.com.br (Community Edition 2.33.1, user `admin`) |
| Docker | v28.5.2, Docker Swarm com 1 nó |
| Traefik | v2.11.28 — reverse proxy + SSL automático |

### 6.2. Stacks core compartilhadas

| Stack | Serviço | Acesso interno |
|-------|---------|----------------|
| traefik | Reverse proxy + SSL | :80, :443 |
| portainer | Gerenciamento Docker | painel.huboperacional.com.br |
| postgres | Banco relacional + pgvector | :5432 |
| redis | Cache, filas, memória | :6379 |
| minio | Object storage (S3-compatible) | interno |

### 6.3. Serviços de negócio disponíveis

| Stack | Descrição | Como integrar |
|-------|-----------|---------------|
| n8n | Workflows, webhooks, integrações | Criar workflows via API ou UI |
| evolution | Evolution API — WhatsApp | API REST interna. Instância padrão: `Robo de Notificações` |
| ctw / cwt | Chatwoot — atendimento multicanal (2 instâncias) | API REST ou webhooks |

### 6.4. Serviços de IA disponíveis (configurar API keys no `.env`)

| Serviço | Provider | Capacidade |
|---|---|---|
| GPT-4 / GPT-4o | OpenAI | Texto, análise, chat, function calling |
| Veo 3 | Google | Geração de vídeo |
| Imagen / Nanobanana | Google | Geração de imagem |
| Kling | Kling AI | Geração de vídeo |
| Google Drive API | Google | Armazenamento, colaboração |
| Google Cloud | GCP | Infra, Vision, Speech, etc. |

---

## 7. Acesso operacional ao VPS

### 7.1. Via SSH (Claude Code CLI — método preferido)

```python
from execution.ssh_runner import run_remote
result = run_remote("docker ps")
```

Acesso direto, sem copiar/colar. O agente lê o output textual.

### 7.2. Via Portainer API (sandbox/Cowork — quando SSH não funciona)

```javascript
const PU = 'https://painel.huboperacional.com.br';

// Helper: obter CSRF token (header é x-csrf-token, NÃO x-portainer-csrf)
window.getCSRF = async () => {
  const r = await fetch(PU + '/api/status', { credentials: 'include' });
  return r.headers.get('x-csrf-token') || '';
};

// Helper: executar comando em qualquer container
window.execCmd = async (cid, cmd) => {
  const csrf = await window.getCSRF();
  const h = { 'Content-Type': 'application/json', 'x-csrf-token': csrf };
  const c = await (await fetch(PU + '/api/endpoints/1/docker/containers/' + cid + '/exec', {
    method: 'POST', headers: h, credentials: 'include',
    body: JSON.stringify({ AttachStdout: true, AttachStderr: true, Tty: false,
      Cmd: ['sh', '-c', cmd + ' 2>&1 | base64'] })
  })).json();
  const s = await fetch(PU + '/api/endpoints/1/docker/exec/' + c.Id + '/start', {
    method: 'POST', headers: h, credentials: 'include',
    body: JSON.stringify({ Detach: false, Tty: false })
  });
  const buf = await s.arrayBuffer();
  const bytes = new Uint8Array(buf);
  let text = '';
  let i = 0;
  while (i < bytes.length) {
    if (i + 8 <= bytes.length) {
      const size = (bytes[i+4] << 24) | (bytes[i+5] << 16) | (bytes[i+6] << 8) | bytes[i+7];
      if (size > 0 && i + 8 + size <= bytes.length) {
        text += new TextDecoder().decode(bytes.slice(i + 8, i + 8 + size));
        i += 8 + size;
      } else { i++; }
    } else { break; }
  }
  return atob(text.trim());
};

// Helper: executar SQL no PostgreSQL (trocar -d para o database do SEU projeto)
window.execPg = async (sql, db = 'postgres') => {
  const e = sql.replace(/'/g, "'\\''");
  return window.execCmd('fa51b72244ac',
    "PGPASSWORD=BCuLDV0qCBGzxOx4Cnga5hnL psql -U postgres -d " + db + " -t -A -c '" + e + "'");
};
```

**Notas técnicas:**
- Header CSRF é `x-csrf-token` (NÃO `x-portainer-csrf`). Sempre buscar do `/api/status`.
- Saída do Docker exec contém headers binários de 8 bytes por frame. Helper acima já parseia.

---

## 8. Traefik — expor novo serviço com HTTPS

### 8.1. Template Docker Compose (Portainer Stack)

```yaml
version: '3.8'
services:
  meu-servico:
    image: minha-imagem:tag
    networks:
      - network_swarm_public
    deploy:
      replicas: 1
      labels:
        - traefik.enable=true
        - traefik.http.routers.MEU-ROUTER.rule=Host(`meu-sub.huboperacional.com.br`)
        - traefik.http.routers.MEU-ROUTER.entrypoints=websecure
        - traefik.http.routers.MEU-ROUTER.tls.certresolver=letsencryptresolver
        - traefik.http.services.MEU-SERVICO.loadbalancer.server.port=PORTA_INTERNA

networks:
  network_swarm_public:
    external: true
```

### 8.2. Checklist obrigatório

1. ✅ Rede: `network_swarm_public` (NÃO `traefik-public`)
2. ✅ Certresolver: `letsencryptresolver` (NÃO `letsencrypt`)
3. ✅ DNS no Cloudflare: registro A → `161.97.129.138`, modo **DNS only** (grey cloud, NUNCA proxied)
4. ✅ Verificar DNS antes: `fetch('https://dns.google/resolve?name=SUB.huboperacional.com.br&type=A')`
5. ✅ Se DNS não existe: informar Hope para criar no Cloudflare
6. ✅ Bloco `deploy:` obrigatório (Swarm mode)

### 8.3. Cloudflare DNS

- **Domínio:** `huboperacional.com.br` (interno) ou domínio próprio do produto (público).
- **Regra obrigatória:** Registros A que apontam para a VPS DEVEM estar como **"DNS only"** (grey cloud), NUNCA "Proxied" (orange cloud). Se proxied, Let's Encrypt HTTP challenge falha (erro 520).

---

## 9. Adicionar projeto novo — passo a passo

### Passo 1 — Verificar recursos
```bash
docker stats --no-stream  # VPS tem 12 GB RAM
```

### Passo 2 — Criar database novo no PostgreSQL
Ver Seção 3.1 (SQL pronto).

### Passo 3 — Configurar namespace no Redis
Prefixo único `{slug_projeto}:*` em todas as chaves (ver Seção 3.2).

### Passo 4 — Verificar/criar DNS
```javascript
fetch('https://dns.google/resolve?name=MEU-SUB.huboperacional.com.br&type=A')
  .then(r => r.json()).then(d => console.log(d.Answer));
```
Se não existe → pedir Hope para criar no Cloudflare como DNS only → `161.97.129.138`.

### Passo 5 — Deploy da stack via Portainer API
```javascript
const csrf = await window.getCSRF();
const swarmId = (await (await fetch(PU + '/api/endpoints/1/docker/swarm', {
  credentials: 'include', headers: { 'x-csrf-token': csrf }
})).json()).ID;

fetch(PU + '/api/stacks/create/swarm/string?endpointId=1', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'x-csrf-token': csrf },
  credentials: 'include',
  body: JSON.stringify({
    name: 'meu-projeto',
    stackFileContent: yamlContent,
    swarmID: swarmId,
    env: []
  })
});
```

### Passo 6 — Testar
```bash
curl -I https://meu-sub.huboperacional.com.br
docker service logs meu-projeto_servico
```

---

## 10. Operações comuns

### Atualizar stack existente
```javascript
const csrf = await window.getCSRF();
fetch(PU + '/api/stacks/STACK_ID?endpointId=1', {
  method: 'PUT',
  headers: { 'Content-Type': 'application/json', 'x-csrf-token': csrf },
  credentials: 'include',
  body: JSON.stringify({ stackFileContent: newYaml, env: [], prune: true, pullImage: false })
});
```

### Forçar restart de serviço
```javascript
const csrf = await window.getCSRF();
const services = await (await fetch(PU + '/api/endpoints/1/docker/services', {
  credentials: 'include', headers: { 'x-csrf-token': csrf }
})).json();
const svc = services.find(s => s.Spec.Name.includes('nome'));
svc.Spec.TaskTemplate.ForceUpdate = (svc.Spec.TaskTemplate.ForceUpdate || 0) + 1;
await fetch(PU + '/api/endpoints/1/docker/services/' + svc.ID + '/update?version=' + svc.Version.Index, {
  method: 'POST', headers: { 'Content-Type': 'application/json', 'x-csrf-token': csrf },
  credentials: 'include', body: JSON.stringify(svc.Spec)
});
```

---

## 11. Secrets

- **Local:** `.env` na raiz do repo, **nunca commitado**. Template em `.env.example` só com placeholders (`OPENAI_API_KEY=sk-...`).
- **Produção:** Docker secrets criados via `docker secret create`. Nunca em `docker-compose.yml` literal.
- **OAuth Google:** `credentials.json` baixado do GCP Console, `token.json` gerado na 1ª execução. Ambos no `.gitignore`.
- **Rotação:** se um secret vazar (ex: commitado por engano), rotacionar **imediatamente** no provedor e atualizar Docker secret.
- **Um secret por domínio.** `JWT_SECRET` (auth) ≠ secrets de tokens públicos (relatórios, magic links de convite, webhooks). Cada um tem seu próprio valor. Reaproveitar é antipattern — bloqueia rotação independente e amplia blast radius.
- **Roadmap:** migrar gestão de secrets pra Cloudflare (Workers Secrets / Pages env / Bindings). Decisão tomada em 2026-04-25 — atualizar quando migração acontecer.

---

## 12. Logging

- **structlog em JSON** com campos de contexto: `module`, `entity_id`, `request_id`, `tenant_id` (em multi-tenant).
- **Níveis:**
  - `DEBUG` só em dev.
  - `INFO` pra eventos de negócio (login ok, OTP enviado, distribuição calculada).
  - `WARNING` pra degradação esperada (rate limit hit, retry).
  - `ERROR` pra falhas que precisam atenção (Evolution down, DB timeout).
- **Sem dados sensíveis nos logs** (PII, senhas, tokens, valores financeiros completos — truncar/hashear).

---

## 13. Stack VETADA em projetos novos

| Vetado | Substituto canônico |
|---|---|
| Supabase Cloud | PostgreSQL self-hosted no VPS |
| Supabase self-hosted (stack completa) | Postgres + FastAPI próprio |
| **GoTrue** | Auth próprio em FastAPI (Seção 2) |
| **PostgREST** | Endpoints REST explícitos em FastAPI (Seção 4) |
| `@supabase/supabase-js` | `fetch` + wrapper tipado via OpenAPI |
| `@supabase/auth-helpers-*` | Cookie httpOnly + JWT próprio |
| Redux | Zustand |
| Express/Fastify (Node) pra backend novo | FastAPI |
| Sequelize/Prisma | SQLAlchemy 2.x async ou asyncpg |
| `localStorage` pra JWT | Cookie httpOnly ou memória + refresh |
| CSS-in-JS runtime | Tailwind |
| Refresh token JWT stateless | Refresh opaco em Redis com rotation + family invalidation |
| HS256 com chave compartilhada cross-projetos | EdDSA + JWKS público (auth-service) ou HS256 com `JWT_SECRET` dedicado por projeto (Transição) |
| `SameSite=None` cookies cross-site | Subdomain-shared cookie + redirect-fragment SSO (R16) |
| Magic-link próprio em cada projeto | `/auth/magic/*` do auth-service (R17) |
| Tracking attribution acoplado à lib de auth | SDK `percus-tracking` separado (R18) |
| Serviço tier-1 sem OTel + audit hash chain | Observabilidade obrigatória (R14) |

**Por que vetado:** evitar lock-in, garantir coerência operacional entre projetos, eliminar dependências de servidores de terceiros que duplicam responsabilidade do nosso stack.

---

## 14. Erros conhecidos e soluções

| Erro | Causa | Solução |
|------|-------|---------|
| SSL 520 Cloudflare | DNS com proxy ativo (orange cloud) | Mudar para DNS only (grey cloud) |
| Portainer CSRF "Forbidden" | Header CSRF errado | Usar `x-csrf-token` (não `x-portainer-csrf`) |
| execCmd atob error | Docker stream com headers binários | Usar arrayBuffer + parsing de frames (Seção 7.2) |
| Let's Encrypt rate-limit | Muitos certs num curto espaço | Esperar janela ou usar staging endpoint do Traefik durante debug |
| Container não acessível pelo Traefik | Falta rede `network_swarm_public` | Adicionar a rede no `networks:` do compose |
| `/api/auth/*` cai no 404 do web | Sidecar Traefik sem `priority=100` | Adicionar `traefik.http.routers.{slug}-auth.priority=100` nos labels |
| `pip install -e . --no-index` falha em Dockerfile multi-stage | Wheels do builder não trazem `setuptools`/`wheel` no `--find-links` cache | Adicionar `--no-build-isolation` e instalar `setuptools wheel` antes:<br>`RUN pip install --upgrade pip setuptools wheel && pip install --no-index --find-links /wheels --no-build-isolation -e .`<br>(Aprendizado auth-service deploy 2026-05-06.) |
| `_REPO_ROOT = parents[N]` quebra em container | Estrutura de pastas em container é mais rasa que dev local; `parents[4]` aponta pra fora do filesystem | Usar `try/except` com fallback `Path.cwd()`:<br>`try: _REPO_ROOT = Path(__file__).parents[4]; assert _REPO_ROOT.exists()`<br>`except (IndexError, AssertionError): _REPO_ROOT = Path.cwd()`<br>(Aprendizado auth-service Fase 1.) |
| Senha Redis no `.env` ≠ Docker Secret de prod | Env desincronizado entre dev local e Swarm | Manter senha como **única source of truth no Docker Secret** (`postgres_password`, `redis_password`, etc.); `.env` local lê do mesmo valor pra dev. Validar com smoke `redis-cli AUTH <secret>` em ambos antes de subir. (Aprendizado auth-service deploy 2026-05-06.) |
| `AuthlibDeprecationWarning` apontando pra `joserfc` | `authlib.jose` deprecated em favor de `joserfc` (compat até authlib 2.0.0) | TODO de manutenção: migrar `core/security.py` pra `joserfc` antes de pinning `authlib >=2.0`. Não bloqueia produção hoje. (Aprendizado auth-service Fase 1.) |
| Wrapper `percus-review-auto.ps1` falha "pwsh: command not found" | Script chama `pwsh` (PowerShell Core 7+) hardcoded; máquina tem só `powershell.exe` (Windows PS 5.1) | Wrapper detecta `pwsh` no PATH; se ausente, fallback automático pra `powershell.exe`. Corrigido nesta PR (canon-update). |

---

## 15. Projetos existentes (referência — NÃO reutilizar recursos)

| Stack | Database | Subdomínios | Notas |
|-------|----------|-------------|-------|
| postgrest-mi + gotrue-mi | `micro_investors_v2` | api-mi.*, auth-mi.* | ⚠️ **Legacy** — em rota de migração pra padrão Percus (FastAPI). Descomissionar ao fim da Onda -1. |
| betina-dashboard | — | — | — |
| familia-milionaria | próprio | — | Stack Percus padrão (FastAPI + OTP). **Referência canônica de auth.** |
| n8n | próprio | — | — |
| evolution | próprio | — | Instância compartilhada `Robo de Notificações`. |
| ctw / cwt | próprio | — | — |
| paid-media-tracking | `pmt_v1`, `pmt_test_v1` | tracking.ads4pros.com | MVP em produção. |

---

## 16. Checklist de início de projeto

1. ✅ Confirmou que vai usar a stack desta página inteira (backend + auth + DB + frontend).
2. ✅ Criou database novo no Postgres (nunca reusar).
3. ✅ Definiu prefixo Redis (`{slug_projeto}:*`).
4. ✅ Pediu DNS no Cloudflare como **DNS only**.
5. ✅ Copiou `.env.example` → `.env` e preencheu com secrets reais (locais).
6. ✅ Decidiu perfil do frontend (Vite default, Next.js só se SEO crítico).
7. ✅ Leu `01_REGRAS_INEGOCIAVEIS.md` e `checklists/CHECKLIST_INICIO_SESSAO.md`.

---

## 17. Atualizações deste documento

- Mudanças aqui afetam **todos os projetos futuros**. Discutir com o time antes de mexer.
- Cada decisão nova (ou reversão) precisa de **data + justificativa** no commit.
- Histórico:
  - **2026-05-06** — Aprendizados Fase 1-3 do auth-service em produção (`https://auth.huboperacional.com.br`, 124/124 testes verde + smoke E2E real). Atualizações: (a) Seção 2.4 reescrita — `tenants.whatsapp_provider` virou `auth.audiences` per-audience override (modelo alinhado com produtos Percus); (b) novas subseções 2.13 (`/dist/` mount self-hosted pra libs cliente), 2.14 (webhooks stub-first), 2.15 (CORS env-driven), 2.16 (outbound HTTP resilience pre-bake — Fase 3.5 pattern); (c) 5 gotchas operacionais novos na Seção 14 (Dockerfile `--no-build-isolation`, `_REPO_ROOT` fallback, senha Redis env-sync, `AuthlibDeprecationWarning`, wrapper `pwsh` fallback). R7 ganha 3 cláusulas (auth gate `sub == subject`, lazy upsert identity em `/me`, lib self-hosted via `/dist/`). R14 ganha bullet 6 (webhooks como insumo de audit). R15 ganha bullet 5 (bcrypt(10) + `FOR UPDATE` lock). Wrapper `scripts/percus-review-auto.ps1` corrigido com fallback `pwsh → powershell.exe`. Template `MIGRATION_KIT_AUTH.template.md` criado. Issue tracker: `huboperacional/percus-kit#1`.
  - **2026-05-05** — Reescrita da Seção 2 (Auth) pra refletir auth-service Percus centralizado: 3 estados de adoção (Final/Transição/Legado), JWT EdDSA + JWKS, refresh opaco com family invalidation, modelo Identity → Org → Product, adapter WhatsApp Evolution+Cloud API per-tenant, anti-bot 9 componentes, magic-link como primitiva centralizada (R17), tracking separado (R18), SSO multi-domínio (R16), observabilidade obrigatória (R14), rate limit canon (R15). Princípio 3 ganha exceção formal pra infra-tier (auth-service pode fugir do FastAPI). Princípio 5 atualizado pra "auth centralizado, validação local".
  - **2026-04-25** — Fusão de `INICIO_2_STACK_PADRAO_PERCUS.md` + `INICIO_3_RUNBOOK_VPS.md` em arquivo único. Eliminada redundância. Estrutura agora é decisão + como executar + vetado por seção.
  - **2026-04-25** — Veta GoTrue/PostgREST. Pin de FastAPI no backend e Vite/Next no frontend.
  - **2026-04-24** — Promovidos pra padrão nativo: (a) `JWT_SECRET` dedicado; (b) cookie de sessão nomeado `{slug_projeto}_session`; (c) padrão sidecar FastAPI com Traefik PathPrefix.
