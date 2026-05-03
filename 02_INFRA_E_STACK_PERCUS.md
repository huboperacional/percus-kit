---
tipo: stack-e-infra-canonica
prevalece-sobre: [comandos/*, decisões locais quando não justificadas]
prevalecido-por: [01_REGRAS_INEGOCIAVEIS, CLAUDE.md do projeto]
quando-usar: ao iniciar projeto novo OU ao tomar decisão técnica em projeto existente
leitura: 12 min (consulta por seção, não leitura linear)
ultima-atualizacao: 2026-04-25
---

# 02 — Infraestrutura e Stack Padrão Percus

> **Single source of truth** da stack técnica + infra de todos os projetos Percus.
> Cobre: backend, frontend, auth, banco, redis, VPS, Traefik, DNS, secrets, deploy.
> Cada seção tem **decisão + como executar + vetado**.

---

## 0. Princípios não-negociáveis

1. **Isolamento total entre projetos.** Nenhuma biblioteca compartilhada entre repositórios. Conexão entre projetos só via API HTTP autenticada (nunca import direto). Cada projeto é dono do próprio código.
2. **Zero Supabase em projetos novos.** GoTrue, PostgREST, `@supabase/supabase-js` e Supabase Cloud estão **vetados**. Projetos legados têm rota de migração (Seção 11).
3. **FastAPI everywhere no backend.** Todo backend novo é Python 3.11+ com FastAPI. Sem exceção.
4. **Frontend escolhido por perfil de produto.** Vite+React 19 pra dashboards/apps internos; Next.js 15 só quando SEO/SSR for crítico.
5. **Auth próprio, não delegado.** Cada projeto emite seus próprios JWT. Nunca depende de servidor de auth de terceiros.
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
- Express/Fastify (Node) pra backend novo.
- Sequelize/Prisma (use SQLAlchemy 2.x async ou asyncpg).

---

## 2. Auth — OTP WhatsApp + JWT próprio

### 2.1. Métodos

| Método | Status | Quando usar |
|---|---|---|
| **OTP via WhatsApp** | **Primário** | Default em todo projeto; 6 dígitos, TTL 10 min |
| **OTP via email** | Opcional | Fallback obrigatório quando produto exige SLA alto |
| **Senha** | Opcional | Só se produto pedir explicitamente |
| **Magic link** | Caso especial | Onboarding/convite, single-use |
| OAuth (Google/etc.) | Caso especial | Integrações com Google APIs no perfil |

### 2.2. Detalhes obrigatórios

- **JWT próprio** assinado pelo backend (HS256 default; RS256 se múltiplos consumidores). Expiração default **7 dias**. Claims: `sub`, `tenant_id` (se multi-tenant), `perfil`, `iat`, `exp`.
- **JWT_SECRET dedicado e isolado.** Variável `JWT_SECRET` no `.env` é exclusiva da auth. **Nunca reaproveitar** secrets de outros domínios (ex: `NEXTAUTH_SECRET` legacy, secrets de tokens públicos, secrets de webhook). Razões: (a) rotação independente sem cascata; (b) blast radius menor se vazar; (c) separação semântica clara. Gerar com `python -c "import secrets; print(secrets.token_urlsafe(64))"`.
- **Cookie de sessão nomeado por projeto:** `{slug_projeto}_session` (ex: `paid_media_session`, `micro_investors_session`). Evita colisão entre subdomínios irmãos do mesmo apex.
- **OTP guardado em Redis** com TTL de 10 min, máx **5 tentativas** por código antes de invalidar, **idempotência de 60s** contra duplo-clique.
- **11 templates anti-bot rotativos** pra mensagem de OTP (texto variado, com/sem emoji, código em posições diferentes). Evita Meta marcar padrão como bot.
- **Anti-bot behavior** no envio Evolution: presence=composing → 2-3s wait → presence=paused → 0.5-1.5s wait → sendText.
- **Rate limiting** no endpoint de request: 3 OTPs por número/hora, 10 por IP/hora.
- **Health check do Evolution**: ping a cada 60s. Se down, frontend esconde botão "WhatsApp" automaticamente.
- **Token JWT no client:** cookie `httpOnly` (preferido) ou em memória + refresh. **Nunca localStorage pra token.**

### 2.3. Referência canônica (read-only)

`D:\Claud Automations\Claude Financas NEW\familia-api\app\modules\auth\service.py`

Esse arquivo é a implementação de referência. Ao iniciar projeto novo:
1. **Leia** (não importe).
2. **Adapte** ao schema do projeto (tabelas de usuário podem ter nome/colunas diferentes).
3. **Copie** as primitivas estáveis: 11 templates de OTP, fluxo de presence/typing, idempotência de 60s, rate limit, anti-bot.
4. Se descobrir bug ou melhoria, conserta no projeto atual e **opcionalmente** propaga via PR pro Financas NEW.

### 2.4. Padrão de deploy do módulo auth

**A) Backend unificado (default em greenfield):** auth vive em `services/api/app/modules/auth/`. Mesmo container, mesma porta, mesma imagem.

**B) Sidecar dedicado (default em legado migrando):** quando backend principal não é FastAPI (ex: Next.js API routes, Express), criar container separado `services/auth/` em FastAPI exclusivo pra auth. Roteia via Traefik por path prefix:

```yaml
deploy:
  labels:
    - traefik.enable=true
    - traefik.http.routers.{slug}-auth.rule=Host(`{dominio}`) && PathPrefix(`/api/auth/`)
    - traefik.http.routers.{slug}-auth.priority=100   # acima do web pra capturar /api/auth antes
    - traefik.http.routers.{slug}-auth.tls.certresolver=letsencryptresolver
    - traefik.http.services.{slug}-auth.loadbalancer.server.port=8000
```

Mesmo cookie domain entre web e auth permite cookie httpOnly compartilhado. Sidecar não precisa de CORS (mesma origem). Banco e Redis compartilhados — único `DATABASE_URL` + `REDIS_URL`, prefixo Redis `{slug}:auth:*`.

**Quando NÃO usar sidecar:** se o backend principal já é FastAPI, embute auth como módulo (forma A).

### 2.5. Migração de auth legado

Se o projeto tem auth diferente (Supabase/GoTrue/NextAuth/senha pura), **não improvise** — siga `comandos/MIGRAR_AUTH.md` que tem 4 variantes (V1-V4) cobrindo cada cenário.

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
  - **2026-04-25** — Fusão de `INICIO_2_STACK_PADRAO_PERCUS.md` + `INICIO_3_RUNBOOK_VPS.md` em arquivo único. Eliminada redundância. Estrutura agora é decisão + como executar + vetado por seção.
  - **2026-04-25** — Veta GoTrue/PostgREST. Pin de FastAPI no backend e Vite/Next no frontend.
  - **2026-04-24** — Promovidos pra padrão nativo: (a) `JWT_SECRET` dedicado; (b) cookie de sessão nomeado `{slug_projeto}_session`; (c) padrão sidecar FastAPI com Traefik PathPrefix.
