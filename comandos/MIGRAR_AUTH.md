---
tipo: comando-pronto
quando-usar: projeto Percus com auth legado (Supabase/GoTrue/NextAuth/senha pura/OAuth-only) precisa migrar pro padrão OTP+JWT
escopo: SÓ auth — não mexe em outros módulos
leitura: 12 min
ultima-atualizacao: 2026-05-05
---

# Migrar Auth de um projeto existente para o Padrão Percus

> ⚠️ **Estado deste documento (atualizado 2026-06-13):** o **auth-service Percus v1 está em produção**. **V5 abaixo é o caminho padrão** para projetos novos ou migrações — consumir o auth-service centralizado diretamente (lib `percus-auth`, JWT EdDSA via JWKS local, endpoints `/otp/request` early-202 + `/otp/validate`). As variantes **V1-V4 são ponte histórica** — descrevem migração pro estado Transição (sidecar FastAPI próprio com OTP+JWT HS256, schema `otp.codes`). Use V1-V4 apenas se houver impedimento técnico comprovado para consumir o auth-service central. As referências a Evolution/GoWA nas variantes V1-V4 são de infra — transparentes pro consumidor (o auth-service central entrega o canal; a migração evo→gowa é infra-side).
>
> **Escopo deste documento:** **só auth.** Não toca outros módulos do backend, não reescreve frontend além da tela de login, não muda banco de dados além das tabelas de auth/OTP. Se você precisa migrar mais coisa (ex: substituir PostgREST por endpoints FastAPI, trocar `@supabase/supabase-js` por fetch tipado), use docs separados quando existirem ou faça em outra rodada.
>
> **Como aplicar:** cole este arquivo no chat do projeto a migrar. O agente faz auditoria primeiro (não toca código), reporta, espera aprovação, executa.

---

## 0. Princípio operacional

**Não execute nada deste documento sem antes completar a Seção 1 (auditoria) e ter aprovação explícita do usuário no escopo.** Mudar auth quebra login — quebrar login quebra produto. Ciclo deve ser: audita → reporta → aprova → executa em pequenos commits → valida `[5-T]` → próximo.

---

## 1. Auditoria inicial (não toca código)

Responda as 10 perguntas abaixo lendo o código do projeto. **Resultado:** classificação do projeto em uma das 4 variantes da Seção 4.

### 1.1. Estado atual

| # | Pergunta | Como descobrir |
|---|---|---|
| 1 | Qual sistema de auth roda hoje? | `grep -ri "auth\|login\|jwt\|session" --include="*.py" --include="*.ts" --include="*.tsx" -l` + ler `package.json`/`requirements.txt` |
| 2 | Tem GoTrue/Supabase Auth? | Procurar imports `@supabase/*` ou container `gotrue-*` no docker-compose |
| 3 | Tem usuários reais cadastrados? Quantos? | `SELECT count(*) FROM auth.users` (ou tabela equivalente) |
| 4 | Qual identifier primário dos usuários? | email-only / phone-only / email+phone / username |
| 5 | Já usa Postgres? | `docker ps`, `.env` com `DATABASE_URL` |
| 6 | Já usa Redis? Com namespace? | `docker ps`, `.env` com `REDIS_URL`; grep por chave `:` em código |
| 7 | Backend é Python/FastAPI? Outro? | Ler `main.py`/`server.ts`/equivalente |
| 8 | Frontend chama auth como? | `grep -ri "signIn\|signUp\|login\|otp" frontend/src` |
| 9 | Usuários conseguem trocar de número/email? | Procurar feature de "atualizar perfil" |
| 10 | Tem multi-tenant? Qual claim? | Procurar `tenant_id` no schema e nos JWTs |

### 1.2. Pré-requisitos

Marque ✅ ou ❌:

- [ ] Postgres acessível (qualquer versão ≥ 13).
- [ ] Redis acessível.
- [ ] Evolution API key disponível e instância ativa (default Percus: `Robo de Notificações`).
- [ ] JWT secret pronto para gerar (`python -c "import secrets; print(secrets.token_urlsafe(64))"`).
- [ ] Backend é Python+FastAPI **ou** o time aceita adicionar um microserviço FastAPI side-car só pra auth.

**Se faltar qualquer item: pare, instale/configure o que falta antes de prosseguir. Não tente contornar.**

### 1.3. Reporte ao usuário

Antes de tocar em código, gere um reporte curto neste formato:

```
AUDITORIA DE AUTH — <nome do projeto>
====================================
Sistema atual:        [ex: Supabase Auth + GoTrue self-hosted]
Usuários cadastrados: [ex: 47, todos com email; 12 com phone]
Backend:              [ex: FastAPI 0.110]
Frontend:             [ex: Vite + React 18 + @supabase/auth-helpers-react]
Redis:                [✅ rodando, sem namespace por projeto]
Evolution:            [✅ key disponível]

VARIANTE APLICÁVEL: <V1|V2|V3|V4> (ver Seção 4)

ESCOPO PROPOSTO:
- [item 1: ex: substituir GoTrue container por módulo auth/ no FastAPI]
- [item 2: ex: criar tabelas otp.codes + otp.rate_limits]
- [item 3: ex: migrar 47 usuários sem perda de id (email permanece único)]
- [item 4: ex: substituir LoginPage do frontend por OtpLoginPage]
- [item 5: ex: gerar magic links de first-login pros 47 usuários e enviar]

FORA DE ESCOPO:
- [ex: não vou trocar @supabase/supabase-js — frontend continua chamando PostgREST até decisão posterior]
- [ex: não vou mexer no schema de tenants]

ESTIMATIVA: ~Xd
RISCOS PRINCIPAIS: [...]

Aguardo aprovação pra prosseguir.
```

---

## 2. Decisão de escopo

Pergunte ao usuário antes de executar. Os defaults abaixo são os do padrão Percus — só desvie com justificativa.

1. **Estratégia de cutover.**
   - **Default (V1, V2, equipes pequenas até ~20 usuários ativos):** big-bang com magic link de first-login. Login antigo desligado de uma vez, magic link enviado pra todos os usuários ativos via WhatsApp/email. Limpo, sem coexistência, blast radius proporcional ao número de usuários.
   - **Janela de coexistência (V3 e equipes >20 usuários ativos):** mantém auth antigo funcional, OTP novo em paralelo, descomissiona o velho após N dias com adoção comprovada (>80% dos ativos logados via novo fluxo). Mais cauteloso, mais código vivo simultaneamente.
   - **Senha como fallback permanente:** OTP é primário, senha bcrypt fica como segundo método (segunda tab no `/login`). Útil pra perfis super-admin ou se Evolution cair. Adiciona código pra manter — só ative se houver requisito explícito.
2. **Email OTP além de WhatsApp?** Default é WhatsApp-only. Email OTP é fallback opcional quando produto exigir SLA alto. Pode entrar em release seguinte.
3. **Multi-tenant claim no JWT?** Se o projeto é single-tenant, JWT só tem `sub` + `perfil`. Multi-tenant adiciona `tenant_id`.

---

## 3. Pré-requisitos técnicos (sem isso não dá pra começar)

### 3.1. Tabelas necessárias

Crie via migration nova (Alembic se já tiver, SQL puro versionado se não):

```sql
-- Schema próprio pra OTP (separado de auth pra deixar claro o que é nosso)
CREATE SCHEMA IF NOT EXISTS otp;

CREATE TABLE IF NOT EXISTS otp.codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier  text NOT NULL,        -- email ou phone (normalizado)
  channel     text NOT NULL,        -- 'whatsapp' | 'email'
  code_hash   text NOT NULL,        -- bcrypt do código de 6 dígitos
  attempts    int  NOT NULL DEFAULT 0,
  expires_at  timestamptz NOT NULL,
  used_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_otp_codes_identifier ON otp.codes (identifier, expires_at);

CREATE TABLE IF NOT EXISTS otp.rate_limits (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier   text,                -- pode ser null se for rate limit por IP
  ip           inet,
  window_start timestamptz NOT NULL DEFAULT now(),
  count        int NOT NULL DEFAULT 1
);
CREATE INDEX idx_otp_rate_identifier ON otp.rate_limits (identifier, window_start);
CREATE INDEX idx_otp_rate_ip         ON otp.rate_limits (ip, window_start);

-- Se você ainda não tem tabela de usuários, crie:
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TABLE IF NOT EXISTS auth.users (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email             text UNIQUE,
  phone             text UNIQUE,           -- formato E.164 com + (ex: +5511999999999)
  perfil            text NOT NULL DEFAULT 'user',
  is_active         boolean NOT NULL DEFAULT true,
  first_login_at    timestamptz,
  last_sign_in_at   timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (email IS NOT NULL OR phone IS NOT NULL)
);
```

> **Já tem `auth.users` da Supabase?** Mantenha. As colunas extras (`first_login_at` se não existir) vão por `ALTER TABLE`. **Não dropar `auth.users`** — preserva foreign keys de `auth.uid()` espalhadas.

### 3.2. Redis namespaced

Confirme que todas as chaves do projeto começam com `<slug_projeto>:*`. Se ainda não tiver, **adicione antes de começar a migrar auth** — caso contrário, dois projetos no mesmo Redis vão colidir.

### 3.3. Variáveis de ambiente

Adicione ao `.env`:

```bash
JWT_SECRET=<gerar com python -c "import secrets; print(secrets.token_urlsafe(64))">
JWT_ALGORITHM=HS256
JWT_EXPIRATION_DAYS=7
COOKIE_DOMAIN=<seu.dominio.com>     # mesmo do frontend, pra cookie httpOnly compartilhado

EVOLUTION_API_URL=https://evo.huboperacional.com.br
EVOLUTION_API_KEY=<solicitar à equipe>
EVOLUTION_INSTANCE=Robo de Notificações

REDIS_URL=redis://...
REDIS_PREFIX=<slug_projeto>
```

Em produção, esses valores vão como Docker secrets, não `.env`.

> ⚠ **JWT_SECRET é dedicado, nunca reaproveitar.** Não use o mesmo valor de outros secrets do projeto (`NEXTAUTH_SECRET` legacy, secrets de tokens públicos de relatório, secret de assinatura de webhook, etc.). Cada um tem seu próprio valor. Razões: rotação independente, blast radius menor, separação semântica clara. Ver `02_INFRA_E_STACK_PERCUS.md` Seção 2.2.

---

## 4. Variantes do procedimento

A migração tem 4 variantes dependendo do estado atual. Identifique a sua na auditoria:

### Variante V1 — Greenfield (sem auth nenhum)

**Estado atual:** projeto novo ou sem login implementado.
**Esforço:** ~1-2d.

1. Crie pré-requisitos (Seção 3).
2. Copie módulo `auth/` do Financas NEW (Seção 5.1) — auth embutida no FastAPI principal (forma A do `02_INFRA_E_STACK_PERCUS.md` Seção 2.4).
3. Crie tela de login OTP no frontend (Seção 5.3).
4. Teste `[5-T]` (Seção 6).

**Pular toda Seção 7 (migração de usuários) — não tem o que migrar.** Também pula Seção 5.5 (sidecar) — V1 não tem backend legacy, então auth é módulo embutido no FastAPI principal.

### Variante V2 — Auth próprio simples (senha, magic-link sem WhatsApp)

**Estado atual:** projeto tem `auth.users` ou equivalente, login funciona mas não usa WhatsApp.
**Esforço:** ~2-3d.

**Cutover default: big-bang com magic link first-login** (mesmo de V1 com usuários reais). Coexistência só se equipe >20 ativos ou produto crítico em produção; nesse caso seguir V3 abaixo.

1. Pré-requisitos (Seção 3).
2. Copie módulo `auth/` do Financas NEW (Seção 5.1) ou suba sidecar (Seção 5.5).
3. Adicione coluna `phone` em `auth.users` se não tiver. Aplique constraint UNIQUE. Confirme que todos os usuários ativos têm phone preenchido — se faltarem, normalize manualmente antes do cutover.
4. Implemente endpoints OTP + first-login (Seção 5.2).
5. Substitua tela de login do frontend (Seção 5.3) e middleware/guards.
6. Gere e envie magic links pros usuários ativos (Seção 7).
7. Cutover: desligar rotas de senha do auth antigo, manter coluna `password_hash` por uma release pra rollback rápido. Limpeza final em commit separado após validação.

**Coexistência (alternativa, equipes grandes):** mesmo passo 1-5, mas em vez de big-bang: deixar tab "senha" (legacy) ao lado de "WhatsApp" (default) na tela de login; quando >80% dos ativos logaram via OTP novo, agende cutover removendo a tab antiga.

### Variante V3 — Supabase Auth/GoTrue

**Estado atual:** projeto usa GoTrue self-hosted ou Supabase Cloud Auth.
**Esforço:** ~3-5d.

1. Pré-requisitos (Seção 3).
2. **Auditar `auth.users` da Supabase** — exportar lista de `id`, `email`, `phone`, `raw_user_meta_data` pra um CSV. Cada usuário existente vai precisar de magic link de first-login.
3. Copie módulo `auth/` do Financas NEW.
4. **Mantenha o schema `auth.users`** — só adicione colunas que faltem (ex: `first_login_at`).
5. **Desligue o container GoTrue** (não delete; deixe parado pra rollback). Frontend ainda chama `https://...supabase...` mas vai falhar — por isso o passo seguinte é importante.
6. Substitua `lib/supabase.ts` no frontend por wrapper que chama o FastAPI novo nas rotas de auth (`/auth/otp/request`, `/auth/otp/verify`, `/auth/me`, `/auth/logout`). Outras chamadas (`supabase.from('...').select()`) ainda podem ir pro PostgREST se o resto do sistema não foi migrado — escopo deste doc é só auth.
7. Gere magic links pros usuários existentes (Seção 7).
8. Cutover: trocar tela de login pra OTP, enviar magic links em batch.
9. Após N dias com >90% dos usuários ativos logados via novo fluxo, descomissione GoTrue.

### Variante V5 — Consumir auth-service centralizado (padrão atual)

**Quando usar:** todo projeto novo OU projeto existente que puder migrar. **Este é o caminho preferencial.** V1-V4 só se houver impedimento técnico comprovado para consumir o auth-service central.

**Esforço:** ~1-2d (sem infra própria de auth).

**O que muda vs V1-V4:** você **não** implementa OTP, não gera JWT, não roda sidecar. O auth-service central entrega tudo. Sua responsabilidade é chamar os endpoints e validar o JWT localmente.

#### V5.1 — Registrar audience (1x por produto)

PR no auth-service repo com migration Alembic adicionando row em `auth.audiences` (`slug`, `display_name`, `default_redirect_uri`, `origins`). Ver `PADRAO_AUTH_SERVICE.md` Seção D + `checklists/CHECKLIST_AUDIENCE_NOVA.md`.

#### V5.2 — Per-consumer secret

Solicitar ao auth-service team o `internal_key_<consumer>` Docker Secret (para chamar `/internal/*`). Configurar via Pydantic `secrets_dir` (`/run/secrets/internal_key`).

#### V5.3 — Backend — login + JWT local

```python
# Login: POST /otp/request (early-202 — responde 202 imediato, envio em background)
# Sempre 202; ofereça canal alternativo proativamente ("não recebeu? tente e-mail")
await auth_client.post("/otp/request", json={
    "channel": "whatsapp", "destination": phone, "audience": AUDIENCE
})

# Validate: POST /otp/validate
result = await auth_client.post("/otp/validate", json={
    "channel": "whatsapp", "destination": phone, "code": code, "audience": AUDIENCE
})
# result: {access_token, refresh_token, expires_in, refresh_expires_in}
```

Validação JWT local via lib `percus-auth` (singleton — JWKS cacheado, sem RTT no hot path):

```python
from percus_auth import PercusAuthVerifier
verifier = PercusAuthVerifier(AUTH_SERVICE_URL, audience=AUDIENCE)

async def get_current_user(token: str = Depends(bearer)) -> UserLocal:
    claims = verifier.verify(token)  # valida EdDSA localmente
    return await resolve_user_local(claims)
```

#### V5.4 — Regra de identidade (padrão único)

```python
async def resolve_user_local(claims: dict) -> UserLocal:
    iid = claims.get("iid")
    sub = claims["sub"]  # "canal:handle"

    if iid:
        # Case contra a coluna CANÔNICA do produto, nunca id per-org
        user = await db.get_user_by_identity_id(iid)
        if user:
            return user
    # Fallback pro sub — resiliente a drift/race entre signup e login
    channel, handle = sub.split(":", 1)
    user = await db.get_user_by_handle(channel, handle)
    if not user:
        raise HTTPException(401)  # NUNCA 404 para user legítimo
    return user
```

#### V5.5 — Signup: provisionar identidade canônica

```python
# Antes do 1º login: provisionar via /internal/identities/v2
result = await auth_client.post(
    "/internal/identities/v2",
    headers={"X-Internal-Auth": INTERNAL_KEY},
    json={"email": email, "phone": phone, "display_name": name}
)
identity_id = result["id"]
```

#### V5.6 — Frontend — bridge `#at=`

```ts
// Rota /open: consome o token do fragmento após OTP ou magic-link
const hash = location.hash.replace(/^#/, '')
const frag = new URLSearchParams(hash)
const accessToken = frag.get('at')
const refreshToken = frag.get('rt')
history.replaceState(null, '', location.pathname + location.search)
// persistir tokens + redirecionar pro app
```

#### V5.7 — Pré-requisitos

- [ ] Auth-service em prod: `https://auth.huboperacional.com.br` ✅
- [ ] Audience registrada (PR no auth-service repo)
- [ ] `internal_key_<consumer>` provisionado pelo auth-service team
- [ ] `percus-auth` no `requirements.txt`

#### V5.8 — Verificação `[5-T]` adaptada

- [ ] **T1:** `POST /otp/request` → `202`.
- [ ] **T2:** código + link chegam no WhatsApp em <30s (envio em background — provider gerenciado pelo auth-service central).
- [ ] **T3:** `POST /otp/validate` → `{access_token, refresh_token}`. Decodar: claims `sub`, `aud`, `iid` (se provisionado).
- [ ] **T4:** `GET /me` com `Authorization: Bearer <jwt>` → user. Sem token: 401.
- [ ] **T5:** ciclo completo login → dashboard → logout → login de novo.

---

### Variante V4 — OAuth-only (Google/etc., sem usuários por phone)

**Estado atual:** todos os logins via Google OAuth. Usuários têm email mas raramente phone.
**Esforço:** ~3-4d.

1. Pré-requisitos (Seção 3).
2. Decisão: OTP Percus **substitui** OAuth ou **convive** com OAuth?
   - **Convive (recomendado):** OAuth Google fica como botão alternativo. OTP WhatsApp fica como primário pra usuários sem conta Google ou que preferem.
   - **Substitui:** mais drástico, requer todos os usuários atuais re-cadastrarem WhatsApp.
3. Se "convive": adicione módulo `auth/otp/` ao backend FastAPI sem mexer no `auth/oauth/` existente. Tela de login ganha 2 tabs.
4. Se "substitui": siga procedimento Variante V3 com adaptação (em vez de magic link, primeira tela após OAuth pede pra cadastrar WhatsApp).

---

## 5. Procedimento canônico (núcleo, comum a todas as variantes)

### 5.1. Backend — copiar e adaptar o módulo auth do Financas NEW

**Referência canônica (read-only):**
```
D:\Claud Automations\Claude Financas NEW\familia-api\app\modules\auth\service.py
D:\Claud Automations\Claude Financas NEW\familia-api\app\modules\auth\router.py
D:\Claud Automations\Claude Financas NEW\familia-api\app\core\security.py
```

**Procedimento:**

1. Crie diretório `<projeto>/services/api/app/modules/auth/` (ou equivalente na sua estrutura).
2. Copie os arquivos de referência. **Adapte:**
   - Nome do model de usuário (`Usuario` → `User` ou o que for).
   - Tabelas alvo (se schema for diferente).
   - Claims do JWT (adicione `tenant_id` se multi-tenant).
   - Templates dos 11 OTP — pode ajustar tom/marca, mas mantenha **11 variações** com mistura de emoji/sem-emoji/posições diferentes do código. Não bote menos de 11 (Meta marca padrão).
3. Adicione o router em `app/main.py`:
   ```python
   from app.modules.auth.router import router as auth_router
   app.include_router(auth_router, prefix="/auth", tags=["auth"])
   ```
4. Crie dependency `get_current_user`:
   ```python
   # app/modules/auth/deps.py
   async def get_current_user(token: str = Depends(oauth2_scheme), session: AsyncSession = Depends(get_session)) -> User:
       # decoda JWT, busca user, valida is_active
   ```
5. Use `Depends(get_current_user)` nos routers que precisam de auth.

### 5.2. Endpoints expostos (contrato pro frontend)

| Método | Path | Body | Resposta |
|---|---|---|---|
| POST | `/auth/otp/request` | `{phone: "+55...", channel: "whatsapp"}` | `{message, expires_in_seconds}` |
| POST | `/auth/otp/verify` | `{phone: "+55...", code: "123456"}` | `{access_token, token_type, user: {...}}` + Set-Cookie httpOnly |
| GET | `/auth/me` | (Bearer token ou cookie) | `{id, email, phone, perfil, ...}` |
| POST | `/auth/logout` | (Bearer token ou cookie) | `{message: "ok"}` + Clear-Cookie |
| POST | `/auth/first-login/validate` | `{token: "..."}` | `{user: {...}, can_set_phone: true}` (se aplicável, ver Variante V3) |
| POST | `/auth/first-login/complete` | `{token, phone}` | dispara fluxo OTP normal |

### 5.3. Frontend — tela de login

1. Crie componente `OtpLoginPage.tsx` (substitui `LoginPage.tsx` atual). Estrutura:
   - **Etapa 1:** input de telefone (E.164, máscara), botão "Enviar código".
   - **Etapa 2 (após sucesso):** input de 6 dígitos, botão "Entrar". Mostrar tempo restante (10min) e botão "reenviar" (desabilitado por 60s pra honrar idempotência).
2. Crie `lib/auth.ts` (ou adicione à `lib/api.ts` se já existe):
   ```ts
   export const authApi = {
     requestOtp: (phone: string) =>
       fetch(`${BASE}/auth/otp/request`, {
         method: 'POST',
         headers: { 'Content-Type': 'application/json' },
         body: JSON.stringify({ phone, channel: 'whatsapp' }),
         credentials: 'include',
       }).then(handleResponse),
     verifyOtp: (phone: string, code: string) => /* ... */,
     me: () => /* ... */,
     logout: () => /* ... */,
   }
   ```
3. Atualize `authStore.ts` (Zustand ou equivalente) pra refletir estados: `idle | requesting | sent | verifying | authenticated | error`.
4. **Token storage:** se backend setou cookie httpOnly, frontend não precisa fazer nada. Se backend retorna token no body (modo SPA), guarde em memória + refresh — **nunca localStorage**.

### 5.4. Anti-bot na entrega WhatsApp

Implementar exatamente como Financas NEW:

1. **Templates rotativos** (11 variações).
2. **Presence simulation:** antes do `sendText`, manda `presence=composing` → wait 2-3s → `presence=paused` → wait 0.5-1.5s → `sendText`.
3. **Idempotência:** chave Redis `<slug>:short:otp:idempotency:<phone>` com TTL 60s. Se request duplicado chega, retorna sucesso sem reenviar.
4. **Rate limit:** 3 OTPs/hora/número, 10/hora/IP. Excedeu → HTTP 429.

### 5.5. Padrão sidecar FastAPI (quando backend principal não é FastAPI)

Aplicável em V2/V3/V4 quando o backend principal do projeto não é FastAPI (ex: Next.js API routes, Express, Flask antigo). Em vez de migrar todo backend, sobe FastAPI em container separado **só pra auth**, roteado via Traefik por path prefix.

**Layout do repo:**

```
projeto/
├── services/
│   ├── api/          # backend principal existente (Next/Express/etc.)
│   └── auth/         # FastAPI sidecar novo
│       ├── app/
│       │   ├── core/{config,security,evolution}.py
│       │   ├── modules/auth/{router,service,schemas,deps,templates}.py
│       │   ├── db/session.py
│       │   └── main.py
│       ├── Dockerfile
│       └── requirements.txt
└── docker-compose.swarm.yml
```

**`docker-compose.swarm.yml` (trecho do service auth):**

```yaml
services:
  auth:
    image: {slug}-auth:latest
    networks: [internal, network_swarm_public]
    environment:
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      REDIS_PREFIX: {slug}:auth
      JWT_SECRET: ${JWT_SECRET}
      JWT_ALGORITHM: HS256
      JWT_EXPIRATION_DAYS: 7
      EVO_URL: ${EVOLUTION_API_URL}
      EVO_KEY: ${EVOLUTION_API_KEY}
      EVO_INSTANCE: ${EVOLUTION_INSTANCE}
      COOKIE_DOMAIN: {dominio}
      DASHBOARD_URL: https://{dominio}
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.{slug}-auth.rule=Host(`{dominio}`) && PathPrefix(`/api/auth/`)
        - traefik.http.routers.{slug}-auth.priority=100   # acima do web pra capturar /api/auth antes
        - traefik.http.routers.{slug}-auth.tls.certresolver=letsencryptresolver
        - traefik.http.services.{slug}-auth.loadbalancer.server.port=8000
```

**Pontos importantes:**

- **`priority=100`** é crítico — sem isso o Traefik pode rotear `/api/auth/*` pro backend principal (que não tem essas rotas) e dar 404. Confirme com `curl` direto após deploy.
- **Mesmo `COOKIE_DOMAIN`** do frontend → cookie httpOnly compartilhado entre web e auth. Não precisa CORS.
- **DB e Redis compartilhados** com o backend principal — não criar instâncias dedicadas.
- **Backend principal continua intacto.** Sidecar lida só com `/api/auth/*`. Outras rotas do produto seguem no backend antigo. Não é refactor — é adendo cirúrgico.
- **Adicionar como módulo embutido no futuro:** se o backend principal for migrado pra FastAPI eventualmente, mover `services/auth/app/modules/auth/` pra dentro de `services/api/` e desligar o container sidecar. Mudança transparente pro frontend.

---

## 6. Verificação `[5-T]` — não pula nenhum passo

Antes de declarar feito, execute todos os 5 testes manualmente e marque cada um:

- [ ] **T1 — Request OTP:** chamar `POST /auth/otp/request` via `curl` ou Postman, status 200, response tem `expires_in_seconds: 600`.
- [ ] **T2 — Mensagem chega:** abrir o WhatsApp do número testado, ver mensagem com 6 dígitos chegando em <10s. Verificar que o template é um dos 11.
- [ ] **T3 — Verify retorna JWT válido:** chamar `POST /auth/otp/verify` com código correto, receber JWT. Decodar em `https://jwt.io` (ou `python -c "import jwt; print(jwt.decode(...))"`) e confirmar claims (`sub`, `exp`, `perfil`).
- [ ] **T4 — Rota protegida funciona:** chamar `GET /auth/me` com `Authorization: Bearer <jwt>`, receber dados do user. Sem token: 401.
- [ ] **T5 — Tela de login do frontend completa o ciclo:** abrir `app.com/login`, digitar phone, receber código no WhatsApp real, digitar código, ver dashboard. Logout funciona. Login de novo funciona (idempotência não bloqueia segundo login normal).

**Casos de erro a testar também:**
- [ ] Código errado: 401, contador de tentativas incrementa.
- [ ] 6 tentativas erradas: bloqueia, mensagem clara.
- [ ] Código expirado (> 10min): 401, mensagem clara.
- [ ] Rate limit: 4 requests do mesmo número em 1h → 4ª retorna 429.

---

## 7. Migração de usuários existentes (Variantes V2/V3/V4)

### 7.1. Estratégia: magic link de first-login

Ideia: cada usuário existente recebe um link único, válido por 30 dias, que valida a primeira sessão. Após o primeiro uso, o usuário usa fluxo OTP normal.

### 7.2. Geração

```python
# script execution/generate_first_login_links.py
import jwt, csv
from datetime import datetime, timedelta
from sqlalchemy import select
from app.models.user import User

def gen_link(user_id, base_url, secret):
    payload = {
        "sub": str(user_id),
        "purpose": "first_login",
        "exp": datetime.utcnow() + timedelta(days=30),
    }
    token = jwt.encode(payload, secret, algorithm="HS256")
    return f"{base_url}/first-login?token={token}"

# Loop: para cada user em auth.users WHERE first_login_at IS NULL:
#   gera link, escreve em CSV (id, email, phone, link)
```

### 7.3. Envio

3 caminhos, do mais simples ao mais robusto:

1. **Manual** (até ~50 usuários): copia CSV pra Google Sheet, faz mailmerge no Gmail.
2. **Gmail App Password + script** (até ~500): script Python com `smtplib` mandando 1 email por vez com delay.
3. **Provedor transacional** (>500): Resend/SendGrid/etc.

**Sempre incluir no email:** assunto claro, instrução curta (3 frases), link grande clicável, validade do link, contato de suporte.

### 7.4. Endpoint do backend

```
POST /auth/first-login/validate
  body: {token: "..."}
  → decodifica, valida exp, valida purpose, valida user.first_login_at IS NULL
  → retorna {user, can_set_phone: bool}
  → se can_set_phone: frontend mostra form de phone

POST /auth/first-login/complete
  body: {token, phone (se aplicável)}
  → seta auth.users.phone, dispara OTP normal pro phone
  → after OTP verify successful, marca first_login_at = now()
```

### 7.5. Tela `/first-login` do frontend

- Lê token do query param.
- Chama `validate`. Se inválido/expirado: erro claro com botão "solicitar novo link".
- Mostra dados do user (read-only) + form pra confirmar/inserir phone.
- Submit chama `complete`, depois entra no fluxo OTP normal (recebe código WhatsApp).

---

## 8. Rollback — quando dar ruim

### 8.1. Cenários típicos

| Sintoma | Causa provável | Ação |
|---|---|---|
| Mensagens WhatsApp não chegam | Evolution down ou número banido | Health check Evolution; se down, ativar fallback email; se ban, trocar instância |
| 100% dos verifies retornam 401 | JWT_SECRET errado, Redis vazio, ou clock skew | Validar `.env` no container, validar Redis acessível, validar timezone do container |
| Usuários reclamam que primeiro login não funciona | Magic link expirado ou JWT_SECRET rotacionado | Regenerar links em batch, comunicar reenvio |
| Frontend mostra "logado" mas nenhuma rota protegida funciona | Cookie não tá vindo (CORS, SameSite, domain) | Inspecionar `Set-Cookie` no devtools; ajustar `cookie_domain`/`samesite` |

### 8.2. Procedimento de rollback (Variante V3 — Supabase coexistente)

Se a migração quebrou o login pra muitos usuários:

1. Religar container GoTrue (não foi deletado, só parado).
2. Reverter `lib/auth.ts` no frontend pra apontar pra GoTrue de novo (último commit antes do switch).
3. Investigar root cause antes de tentar de novo.

### 8.3. Procedimento de rollback (Variante V1/V2 — sem coexistência)

Mais difícil — sem auth velho pra voltar. Se quebrar, prepare:
- Backup do estado anterior do código (branch dedicado, não merged).
- Snapshot do banco antes da migration `otp.*`.
- Lista de telefones de suporte que sabem desbloquear contas manualmente.

**Por isso recomenda-se executar Variante V3 (com coexistência) sempre que possível.**

---

## 9. Pegadinhas conhecidas

| # | Pegadinha | Sintoma | Solução |
|---|---|---|---|
| 1 | Phone sem normalizar | Verify falha porque request salvou `+55 11 9999...` e verify tenta `5511999...` | Sempre normalizar pra E.164 com `+` no início, sem espaços/parênteses, antes de qualquer query |
| 2 | Redis sem namespace | Outro projeto sobrescreve OTP do seu | Adicionar prefixo `<slug>:` antes de qualquer `redis.set/get` |
| 3 | Evolution timeout 30s | OTP demora > 30s pra chegar, request HTTP estoura timeout | `httpx.AsyncClient(timeout=15.0)`, retry 1x se timeout |
| 4 | JWT em localStorage | XSS rouba token | Cookie httpOnly (preferido) ou em memória + refresh |
| 5 | Cookie sem `Secure` em prod | Cookie não persiste entre requests | `secure=True` quando `https`; em dev local pode ser False |
| 6 | CORS bloqueando cookie | Frontend e backend em domínios diferentes, cookie não vai | Backend: `allow_credentials=True` + lista explícita de origins; cookie: `samesite="lax"` ou `"none"` (`none` exige `secure`) |
| 7 | bcrypt do código de OTP é lento | Verify demora 200ms+ por causa do hash | Aceitável; se for problema, trocar pra HMAC-SHA256 com chave secreta |
| 8 | Idempotência por 60s bloqueia reenvio legítimo | Usuário não recebeu, clica "reenviar", recebe "já enviado" | Mostrar countdown no UI; só liberar botão após 60s |
| 9 | Rate limit por número compartilhado (família) | Vários usuários no mesmo número (ex: WhatsApp Business) acabam batendo limit | Considerar rate limit por usuário em vez de por phone, ou flexibilizar pra 5/hora |
| 10 | Anti-bot insuficiente, número fica banido | Após N dias, mensagens param de chegar | Trocar instância Evolution; revisar templates; ativar fallback email obrigatoriamente |
| 11 | Reaproveitar `JWT_SECRET` de outro domínio (NEXTAUTH_SECRET, secret de tokens públicos, etc.) | Rotação de qualquer secret força reissue de TODOS os tokens; vazamento de um expõe todos | Sempre gerar `JWT_SECRET` dedicado. Cada domínio (auth, public_report, webhook) tem secret próprio. Ver `02_INFRA_E_STACK_PERCUS.md` Seção 2.2 |
| 12 | Sidecar Traefik sem `priority=100` | `/api/auth/*` cai no router do web (404) em vez de chegar ao FastAPI auth | Adicionar `traefik.http.routers.{slug}-auth.priority=100` nos labels do service auth. Validar com `curl https://dominio/api/auth/me` retornando 401 (não 404) após deploy |
| 13 | Cutover big-bang sem testar magic link em staging primeiro | Único usuário admin perde acesso e ninguém tem fallback | Sempre rodar `scripts/send_first_login_links.py` em staging antes; abrir o link manualmente; só depois aplicar em prod |

---

## 10. Critério de "feito"

A migração de auth está concluída quando:

- [ ] Auditoria executada e reporte aprovado pelo usuário.
- [ ] Pré-requisitos (Seção 3) todos ✅.
- [ ] Variante aplicada conforme Seção 4.
- [ ] Os 5 testes da Seção 6 passaram, incluindo casos de erro.
- [ ] Se aplicável (V2/V3/V4): magic links enviados e ≥ 80% dos usuários ativos completaram first-login dentro de 7 dias.
- [ ] HANDOFF.md do projeto atualizado refletindo "auth migrado pra padrão Percus em <data>".
- [ ] Auth antigo (se coexistente) descomissionado ou agendado pra descomissionar com data definida.
- [ ] Sistema de auth antigo não aparece mais em commits novos.
- [ ] Pelo menos 1 ciclo `[5-T]` (login → ação autenticada → logout → login de novo) testado com usuário real.

---

## 11. O que NÃO está coberto por este documento

Se o projeto também precisa de:

- **Substituir PostgREST por endpoints FastAPI** → use doc separado quando existir, ou abra rodada nova de brainstorming.
- **Substituir `@supabase/supabase-js` por fetch tipado** → idem.
- **Migrar dados de Supabase Cloud pra Postgres VPS** → ver caso de referência `Micro Investors/execution/migrate_v1_to_v2.py`.
- **Mudar a stack de frontend (Next ↔ Vite)** → fora de escopo.
- **Multi-tenant arquitetural** → fora de escopo deste doc; afeta auth (claim `tenant_id` no JWT) mas envolve muito mais (search_path, isolation, etc.).

Foque este doc em **só auth**. Outros docs de migração devem ser criados separadamente conforme as decisões padrão amadurecerem.

---

## 12. Referências

- **Padrão V5 (auth-service central):** `PADRAO_AUTH_SERVICE.md` + `CONSUMIR_AUTH_SERVICE.md` + `checklists/CHECKLIST_AUDIENCE_NOVA.md`.
- **Consumer Quickstart (manual completo):** `auth-service/docs/CONSUMER_QUICKSTART.md` (read-only, cross-repo).
- **Padrão infra geral:** `02_INFRA_E_STACK_PERCUS.md` (Seção 2 — Auth).
- **Implementação canônica V1-V4 (ponte histórica):** `D:\Claud Automations\Claude Financas NEW\familia-api\app\modules\auth\`.
- **Caso real de migração V3:** `D:\Claud Automations\Micro Investors\docs\superpowers\specs\2026-04-25-onda-minus-1-fastapi-pivot-design.md`.

---

_Última atualização: 2026-04-24 — promovidos pra padrão nativo: (a) cutover big-bang+magic-link como default em V1/V2 (Seção 4); (b) `JWT_SECRET` dedicado obrigatório (Seção 3.3 + pegadinha #11); (c) padrão sidecar FastAPI com Traefik PathPrefix (nova Seção 5.5); (d) pegadinhas #12 e #13. Aplicado primeiro em Paid Media Automation._
_Versão original: 2026-04-25 (criação)._
