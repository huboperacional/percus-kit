---
tipo: resumo de padronizações + pedido de revisão
origem: Plexco Tasks (sessões 33, 34, 35, 36 — 2026-05-13 a 2026-05-15)
destino: time auth-service
status: padronizações já em uso pelo Plexco Tasks; aguardando avaliação se vale levar pro core do auth-service
leitura: 5 min
---

# Padronizações Plexco Tasks ↔ auth-service — pra você avaliar

Nas últimas 5 sessões, o consumer Plexco Tasks teve que resolver vários problemas de UX, normalização e integração com o auth-service. Quero compartilhar **o que padronizamos no nosso lado** + **5 perguntas/pedidos pro auth-service** considerar incorporar ou ajustar.

A ideia: alinhar consumer ↔ provider pra que **todo projeto Percus novo siga o mesmo padrão sem ter que descobrir do zero**.

---

## Parte 1 — Padronizações que adotamos no Plexco Tasks

### 1. Normalização canônica de telefone (Plexco backend)

**Decisão:** todo `users.phone` no banco do produto fica como **só dígitos, sem `+`, sem espaços, sem formatação**. Ex: `5567933009440`.

**Função canônica** (`app/utils/phone.py`):
```python
def normalize_phone(raw: str | None) -> str | None:
    """Retorna só dígitos. None se < 10 dígitos."""
    if not raw: return None
    digits = re.sub(r"\D", "", raw)
    return digits if len(digits) >= 10 else None
```

**Aplicação:**
- `users.phone` write paths (signup, invite redeem, edit) — sempre normaliza ANTES de salvar
- Lookup por phone (JWT sub `whatsapp:+5567...`) — normaliza ANTES do filter (`User.phone == normalize_phone(handle)`)
- Migration 040 fez backfill de phones legados (4 formatos diferentes → 1 canônico)

**Por que importa pro auth-service:** o auth-service emite JWT com `sub: "whatsapp:+5567..."` (formato E.164 com `+`). Consumer precisa lembrar de normalizar antes de bater no DB local. Documentação ajudaria.

### 2. Login UX — tela de OTP padronizada

Stack Plexco Tasks:
- Next.js 15 App Router + shadcn/ui
- 2 steps visuais: `request` (escolher canal + destino) → `otp` (digitar 6 dígitos)
- 2 canais lado-a-lado: WhatsApp (default) + E-mail
- Validações inline + estado `notFound` separado de erro genérico
- Pré-fill via query string: `?channel=email&dest=foo@bar.com` (usado por redirecionamento de signup redeemed)

**Estado de erro `notFound`** (auth-service retorna 404 quando OTP destination não existe):
- Frontend mostra UI dedicada com "Não encontramos esse número/email" + sugestão "tente o outro canal" + link "falar com administrador"
- Crítico pra UX: 404 genérico não educa o user

### 3. friendlyError translation pattern

Quando o fetch falha (network, CORS, 500, etc), traduzir erro técnico em mensagem amigável **antes** de mostrar no toast.

```typescript
function friendlyInviteError(raw: string): string {
  const lower = raw.toLowerCase()
  if (lower.includes('failed to fetch')) return 'Erro de conexão com o servidor. Verifique sua internet ou tente em alguns segundos.'
  if (lower.includes('whatsapp')) return 'Esse número não tem WhatsApp ativo.'
  if (lower.includes('already exists')) return 'Esse email/número já tem conta.'
  // ... etc
  return 'Erro desconhecido. Tente de novo.'
}
```

Aplicado em: invitations modal, login error display, signup redeem error.

**Por que isso é cross-projeto:** todo consumer do auth-service vai ter "Failed to fetch" quando der CORS/network. Faz sentido padronizar mensagens.

### 4. Banner `?reason=session_invalid` na login page

Quando o user é deslogado por sessão inválida, redirect pra `/login?reason=session_invalid` mostra banner contextual amber: "Sua sessão expirou ou foi invalidada. Entre de novo." em vez de jogar o user na tela em branco sem contexto.

Convenção: query param `reason` é renderizado via map `{ session_invalid: ..., token_expired: ..., refresh_failed: ... }`.

### 5. Detect `redeemed=true` em invitations

Endpoint `GET /invitations/{token}` retorna `redeemed: invite.redeemed_at is not None`. Frontend signup detecta e renderiza variante "Sua conta já está ativa, clique aqui pra logar" com CTA pro `/login?channel=email&dest=<email>` em vez de mostrar o form de cadastro (que ia confundir o user já cadastrado).

### 6. Override de WhatsApp source por audience

**Decisão de hoje** (2026-05-15): Plexco Tasks audience usa instance própria `Plexco` no Evolution, em vez do `Auth_Todos` compartilhado. Razão: `Auth_Todos` é o canal de testes manuais do estúdio — não queremos misturar OTP transacional com teste exploratório.

SQL aplicado:
```sql
UPDATE auth.audiences
SET whatsapp_provider='evolution_self',
    whatsapp_config=jsonb_build_object('api_key', '...', 'instance_name', 'Plexco')
WHERE audience='plexco-tasks';
```

Funcionou imediatamente — auth-service já tinha essa infra implementada (`audiences/service.py:resolve_evolution_sender`). 👏 Crédito a quem fez essa abstração antes — tornou a mudança 1 SQL UPDATE em vez de refactor.

### 7. Docker Secrets via Pydantic `secrets_dir`

Tanto Plexco backend quanto auth-service usam:
```python
class Settings(BaseSettings):
    model_config = SettingsConfigDict(secrets_dir="/run/secrets", case_sensitive=False, ...)
```

Field name lowercase = filename em `/run/secrets/`. Permite mover qualquer env var sensível pra Docker Secret sem code change. Hoje migramos 4 secrets do compose do auth-service: `database_url`, `redis_url`, `evolution_auth_api_key`, `evolution_api_key`. Zero código novo.

### 8. CORS source-of-truth declarativa

Plexco Tasks tem `infra/domains.yaml` como fonte única + `scripts/cors-sync.py` que gera config.py e `.env.example` + smoke pluga no fim de cada deploy (`scripts/cors-smoke.sh` testa 18 origins × endpoints).

Pode valer a pena replicar no auth-service — hoje seu compose tem `CORS_ORIGINS_RAW` setado diretamente sem rastreabilidade.

---

## Parte 2 — 5 pedidos/perguntas pra você avaliar

### 1. Documentar formato canônico de `sub` no JWT

Hoje o claim `sub` vem como `"whatsapp:+5567933009440"` (com `+`) — formato E.164. Consumer precisa fazer `normalize_phone(handle)` antes de bater no DB local que tem dígitos puros.

**Pedido:** documentar no PADRAO_AUTH_CROSS_PROJETO.md (ou equivalente) que:
- `sub` formato = `<channel>:<canonical_handle>` onde phone é E.164 com `+`
- Consumer deve normalizar pra seu schema local
- Função utilitária de exemplo (Python: regex `\D` → `""`, min 10 dígitos)

Ou alternativa: emitir 2 claims, `sub` (E.164) e `phone_digits_only` (só dígitos), e deixar consumer escolher. Reduz erro.

### 2. Endpoint /otp/request retornar `friendly_error_code` enumerado

Hoje `404` = "destination not registered" mas o detail é texto livre. Consumer faz match por substring (frágil).

**Pedido:** retornar JSON com `{error_code: "destination_not_found" | "rate_limited" | "invalid_audience" | "evolution_unreachable" | ...}` enumerado. Consumer faz switch limpo em vez de regex em mensagens.

### 3. Status canônicos de OTP validate

Hoje 401 = "invalid otp" cobre 3 casos distintos (per `service.py:OtpValidationError`):
- `"no active otp"` (expirado ou nunca pedido)
- `"attempts exceeded"` (5+ tentativas erradas)
- `"invalid code"` (dígitos errados)

Per comentário do código: "Same error on every failure mode to avoid oracle attacks" — entendo a razão de segurança. Mas isso prejudica UX: o user que digitou errado e o user que demorou mais de 5 min veem a mesma mensagem.

**Pergunta:** vale considerar:
- Manter 401 genérico no body **mas** incluir header `Retry-After: 0` (pra digite-de-novo) vs `Retry-After: 300` (pra peça-novo-OTP)? Headers não dão oracle attack mas dão UX.
- OU adicionar `X-OTP-Status: expired|wrong|locked` opcional, documentando o trade-off?

### 4. Audience registration — fluxo oficial

Sessão paralela 2026-05-14 ligou audiences strict E1 enforcement em `/otp/*`, `/magic`, `/sso`. Hoje audiences são `painel, familia, paid-media, plexco-coach, plexco-tasks` — adicionadas via SQL direto, sem fluxo oficial.

**Pedido:** documentar canonicamente:
- Como projetos novos registram audience (SQL? endpoint? PR no auth-service repo?)
- Naming convention (kebab-case? max-length? sufixos `-prod`/`-staging`?)
- Cache TTL de audiences (vi 60s + Redis pub/sub invalidation) — consumer precisa saber pra não ser surpreendido por delay

### 5. Loop de retry no `fetchMe` precisa backoff explícito

Hoje quando o frontend chama `GET /auth/me` e auth-service não responde (CORS preflight failure, 500, etc), o React Query retry policy padrão dispara 3-16+ retries em milissegundos — vimos isso no DevTools do Plexco hoje. Cada retry é mais carga no auth-service que já está sofrendo.

**Pedido:** auth-service retornar header `Retry-After` em 5xx e mensagens de erro categoricamente "transient" (timeout, 503) vs "permanent" (401, 404). Consumer pode então diferenciar retry-with-backoff vs fail-fast.

---

## Como consumimos auth-service hoje (resumo)

| Fluxo | Endpoint | Padrão Plexco Tasks |
|---|---|---|
| Login OTP request | `POST /otp/request` | http2=True, audience=`plexco-tasks`, payload `{channel, destination, audience}` |
| Login OTP validate | `POST /otp/validate` | retorna access+refresh; salva no Zustand store (NÃO localStorage) |
| Sessão verify | `GET /auth/me` | Bearer access_token; backend Plexco que serve esse endpoint (validado JWT via lib `percus-auth`) |
| Identity creation cross-org | `POST /internal/identities` | X-Internal-Auth via Docker Secret `internal_key`; origin=`plexco_v2` |
| Magic link | `POST /internal/magic-link` | (não usado direto; via invitation flow) |

---

## Documentos relacionados

- **Padrão atual (vigente):** [PADRAO_AUTH_CROSS_PROJETO.md](./PADRAO_AUTH_CROSS_PROJETO.md)
- **Review de Etapa 1 (deployment):** [REVIEW_AUTH_INTEGRATION_2026-05-15.md](./REVIEW_AUTH_INTEGRATION_2026-05-15.md) — 5 decisões operacionais (contract /internal/identities, key rotation, audiences flow, compose cleanup, deploy via git pull)
- **Coach handoff (audience override):** [COACH_AUDIENCE_WA_OVERRIDE_2026-05-15.md](./COACH_AUDIENCE_WA_OVERRIDE_2026-05-15.md)
- **Plexco Tasks spec (audience WA override):** `Plexco Tasks/docs/superpowers/specs/2026-05-15-plexco-tasks-audience-wa-override-design.md`
- **OWNERSHIP cross-projeto:** [OWNERSHIP.md](../OWNERSHIP.md)

---

## Próximo passo do nosso lado

Nenhum bloqueio. Plexco Tasks segue normal. Quando você decidir alguma dessas 5 perguntas, abrimos sessão pra adotar do lado consumer.

Se quiser que eu prepare PR pro repo `huboperacional/auth-service` com documentação das padronizações (item 1, 4 acima) ou utilitário de phone normalize compartilhado, fala que faço.

---

**Mantenedor desta análise:** Plexco Tasks team
**Última atualização:** 2026-05-15 (sessão 36)
