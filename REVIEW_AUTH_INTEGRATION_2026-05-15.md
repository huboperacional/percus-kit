---
tipo: pedido de revisão cross-time
origem: Plexco Tasks (sessão 35 — 2026-05-14/15)
audiência: tech lead do auth-service
status: aguardando revisão e geração de DOC OFICIAL
leitura: 4 min
referência: ${env:PERCUS_CANON_DIR}\PADRAO_AUTH_CROSS_PROJETO.md
---

# Revisão de integração com auth-service (origem Plexco Tasks)

## Por que este documento existe

Plexco Tasks deployou em prod (sessão 35 de 2026-05-14/15) o conjunto de mudanças necessárias pra começar a **Etapa 2 do Strangler Fig** (backfill de `identity_id` 100%, lookups primários por identity, invite via lookup-or-create idempotente).

Antes de codar a Etapa 2 do nosso lado, **precisamos do seu sinal verde** sobre **5 decisões operacionais** que tomamos no auth-service em prod. E pedimos que, com base nesta revisão, você gere o **documento oficial cross-projeto** que vou levar pros outros times (Coach, Painel, Família, Paid Midia, projetos novos) pra padronizar.

---

## O que está em prod no auth-service hoje (sessão 35 close)

| Componente | Estado |
|---|---|
| Repo `huboperacional/auth-service` (GitHub, privado) | ✅ Criado, `main` pushed (era só local até hoje). |
| `/opt/auth-service` na VPS 161.97.129.138 | ✅ Convertido em git working tree (era rsync one-shot). Deploy key read-only `auth_service_deploy`. SSH alias `github.com-auth-service`. |
| Imagem `percus/auth-service:deploy-1778843855` | ✅ Rebuilded com migs `006` + `007` + módulo `identity/` + audiences E1 strict enforcement. Container healthy. |
| Migração `007_identities_origin` aplicada no DB `percus_auth_v1` | ✅ Coluna `origin TEXT` em `auth.identities` (rastreia qual produto criou cada identidade). |
| Endpoint `POST /internal/identities` | ✅ Vivo. Lookup-or-create idempotente. Auth via header `X-Internal-Auth`. |
| Hardening de audiences E1 em `/otp/*`, `/magic`, `/sso` | ✅ Endpoints rejeitam audience desconhecida com 422 (TDD, 5 testes verdes). |
| Secret `internal_key` (32 bytes hex random) | ✅ Docker Secret externo, montado em `/run/secrets/internal_key`. **Pydantic `BaseSettings` com `secrets_dir="/run/secrets"` auto-lê via field `internal_key: str`** — zero código novo. |
| Script `/usr/local/bin/auth-service-deploy` | ✅ Espelha `plexco-deploy` v3: `git pull main` + build com tag única `deploy-$(date +%s)` + `docker service update --force` + smoke `/health`+`/internal/identities`. |
| `deploy/docker-compose.stack.yml` no host VPS | ⚠️ `git update-index --skip-worktree` — host tem secrets hardcoded (DATABASE_URL, REDIS_URL, 2 EVOLUTION_API_KEY) que **não estão no repo**. Refactor pra Docker Secrets é durable separada (item #4 abaixo). |

Smoke E2E validado em prod:
- `POST /internal/identities` sem header → `401 invalid internal auth` ✓
- `POST /internal/identities` com `X-Internal-Auth` correto + `{email, origin: "plexco_v2"}` → `201` + retorna `identity_id` UUID novo ✓
- Wrong key → `401` (constant-time compare via `hmac.compare_digest`) ✓

---

## 5 decisões que pedimos sua revisão

### 1. Contract de `POST /internal/identities` está estável pra outros projetos consumirem?

**Como usamos hoje (do nosso lado, Plexco Tasks):**
```
POST https://auth.huboperacional.com.br/internal/identities
Headers:
  Content-Type: application/json
  X-Internal-Auth: <conteúdo do Docker Secret internal_key>
Body:
  { "email": "...", "phone": "+55...", "display_name": "...", "origin": "plexco_v2" }
Resposta 201 (created) OU 200 (already existed):
  { "id": "<uuid>", "email": "...", "phone": "...", "display_name": "...", "origin": "...", "created": true|false }
```

**Perguntas:**
- (a) Esse contract está congelado pra V1 ou ainda pode mudar? Se pode mudar, qual o critério (semver no repo? canal de aviso?).
- (b) O campo `origin` é livre (`plexco_v2`, `coach`, `painel-afiliados`, etc.) ou você quer enum controlado no auth-service?
- (c) Idempotência: lookup-or-create é por `(email)` OU `(phone)` OU `(email AND phone)`? O que acontece se mandamos `{email: A, phone: B}` e existe `{email: A, phone: C}` no DB?
- (d) Body validation: `email` é obrigatório? `phone` é obrigatório? Os dois são obrigatórios? Hoje no nosso teste de smoke só passamos `email + origin` e funcionou (201), então parece que phone é opcional — confirma?

### 2. `INTERNAL_KEY` como Docker Secret (`internal_key`) é o pattern correto pra service-to-service?

**Atual:**
- Docker Secret `internal_key` na VPS (criado com `openssl rand -hex 32`).
- Auth-service monta em `/run/secrets/internal_key`. Pydantic auto-lê via `BaseSettings.secrets_dir`.
- Plexco backend (Etapa 2) vai precisar do **mesmo secret** montado pra mandar o header.

**Perguntas:**
- (a) Você prefere esse pattern (shared secret simétrico) OU quer evoluir pra **mTLS** (cliente service apresenta cert) ou **JWT internal** (consumidor pede `/internal/token` com client_secret e usa o JWT como Bearer)?
- (b) **Rotação** de `internal_key`: hoje é 32B hex, sem expiração. Qual SLA pra rotacionar (anual? on-incident?)? Quem fica responsável por avisar consumidores quando trocar?
- (c) Multi-consumidor: Plexco Coach + Painel + Família + Paid Midia + novos podem TODOS usar a mesma `internal_key`, ou cada um deve ter chave própria (`{produto}_internal_key`)?
- (d) Audit: chamadas pra `/internal/*` ficam logadas em alguma tabela do auth-service ou só nos logs do container?

### 3. Audiences E1 strict enforcement — como projetos novos pedem audience?

**Mudança recente (commit `9412b4c` na sessão paralela):** `/otp/*`, `/magic`, `/sso` agora rejeitam audience desconhecida com 422.

**Perguntas:**
- (a) Fluxo de **registro de audience nova**: hoje é via SQL INSERT manual em `auth.audiences`? Ou via endpoint `/admin/audiences`? Ou PR no repo do auth-service? Qual canônico pros projetos novos seguirem?
- (b) Cache: setting `audience_cache_ttl_seconds=60` + Redis pub/sub invalidation. Os projetos consumidores precisam saber disso? Risco de "audience cadastrada agora mas demora até 60s pra propagar".
- (c) Audience naming convention: hoje temos `plexco-tasks`, `painel`, `familia`, `paid-media`, `plexco-coach`. Existe regra (kebab-case, max-length, sufixo `-prod` vs `-staging`)?

### 4. Compose com secrets hardcoded — quem assume cleanup?

**Estado atual:** o `/opt/auth-service/deploy/docker-compose.stack.yml` na VPS tem **DATABASE_URL com senha em plain text + REDIS_URL com senha + 2 EVOLUTION_API_KEY**. Não vai pro repo (skip-worktree). O template em `origin/main` está limpo (usa `${VAR:?must be set}`).

**Perguntas:**
- (a) Plano oficial: migrar os 4 valores pra Docker Secrets adicionais (`postgres_password`, `redis_password`, `evolution_auth_api_key`, `evolution_api_key`) + ajustar `app/core/config.py` se necessário? Pydantic já lê de `/run/secrets/*` então pode ser zero código novo.
- (b) Quem faz: time do auth-service ou Plexco Tasks (vc me empresta o pattern, eu refactoro e mando PR)?
- (c) Janela de execução: durante deploy normal (sem downtime se feito via `--secret-add`) ou janela de manutenção formal?

### 5. Deploy via `git pull` (mirror do plexco-deploy) — quer adotar como padrão?

**Atual:** `auth-service-deploy` em `/usr/local/bin/` na VPS faz `git pull origin main` + build + rollout + smoke. Espelha o `plexco-deploy` v3.

**Perguntas:**
- (a) Quer documentar isso no `SETUP.md` do auth-service e remover/depreciar o fluxo antigo (rsync)?
- (b) Migrations continuam manuais (alembic env.py exige `psycopg2`, não tá baked na imagem). Quer que a próxima feature de auth-service inclua um `psycopg2` opcional pra rodar `alembic upgrade head` dentro do container, OU mantém manual?
- (c) Eu posso commitar o script `auth-service-deploy` em algum lugar do repo (tipo `deploy/scripts/`) pra preservar e versionar?

---

## O que pedimos como output da sua revisão

Por favor, **revise os 5 itens acima** e responda em **um único arquivo Markdown**:

**`PADRAO_AUTH_SERVICE_INTEGRATION_V2.md`** — sucessor do `PADRAO_AUTH_CROSS_PROJETO.md` atual, agora cobrindo:

1. **Contract congelado** de `POST /internal/identities` (request/response schemas com tipos exatos e códigos de status documentados).
2. **Pattern oficial de auth service-to-service** (decisão final entre shared secret / mTLS / JWT internal + protocolo de rotação + escopo de chave por produto).
3. **Receita de registro de audience** (passo-a-passo: SQL direto? endpoint? PR? naming convention).
4. **Plano de cleanup do compose secrets** (lista de Docker Secrets adicionais + cronograma).
5. **Deploy oficial pós-sessão-35** (git pull adotado, SETUP.md atualizado, script versionado).

Esse doc oficial vai pra: Plexco Tasks (Etapa 2), Plexco Coach (Etapa 3), Painel (Etapa 4), Família (anti-scope mas referência), Paid Midia (referência), e qualquer projeto novo.

---

## Suporte / Discordância

Se discordar de alguma decisão que já tomamos em prod, listamos abaixo o que ainda é reversível com baixo custo nesta janela:

| Decisão | Custo de reverter | Janela |
|---|---|---|
| Pattern shared secret `internal_key` | Baixo — só `docker secret rm internal_key` + adotar outro pattern. Sem código novo do nosso lado. | Esta semana |
| `origin` como TEXT livre | Médio — vira ENUM exige migration + update das chamadas existentes. | Esta semana |
| `audiences` strict enforcement já em prod | Alto — desabilitar precisa code change + rebuild + rollout. Mas pode ser feito via env var se tiver kill switch (não vi). | Mantém ligado por padrão |
| Git pull deploy | Baixo — script é só conveniência, podemos reverter pra rsync ou outro fluxo. | Esta semana |

---

## Quem fez essa entrega (origem)

- **Repo:** `D:\Claud Automations\Plexco Tasks\` (master @ commit `70f5c5f`)
- **Operador:** sessão Claude (Opus 4.7) + user `trafego@percus.com.br`
- **Data:** 2026-05-14 → 2026-05-15 (sessão 35)
- **Documentos relacionados:**
  - `D:\Claud Automations\OWNERSHIP.md` — quadro de ownership cross-projeto
  - `${env:PERCUS_CANON_DIR}\PADRAO_AUTH_CROSS_PROJETO.md` — padrão vigente (será substituído pelo V2)
  - `D:\Claud Automations\Plexco Tasks\docs\next-session.md` — handoff sessão 35 close (visão Plexco)
  - `D:\Claud Automations\.claude-home\plans\agora-parece-queu-o-ancient-cloud.md` — plano operacional Strangler Fig

---

**Próximo passo do nosso lado:** assim que recebermos o `PADRAO_AUTH_SERVICE_INTEGRATION_V2.md`, abrimos sessão fresca pra **Etapa 2 Plexco Tasks** (backfill `identity_id` + lookups por identity_id+org + invite via lookup-or-create).
