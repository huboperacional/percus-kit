---
tipo: spec executivo (1 página)
audiência: tech leads de cada projeto do estúdio Percus
quando-usar: ao escolher como autenticar usuários num projeto Percus (novo ou existente)
leitura: 3 min
referência-profunda: D:\Claud Automations\OWNERSHIP.md + checklists/CHECKLIST_AUTH_NOVO_PROJETO.md
status: vigente desde 2026-05-14 (sessão 33 do Plexco Tasks)
---

# PADRÃO DE AUTH CROSS-PROJETO — ESTÚDIO PERCUS

**Resumo em 1 frase:** Todo projeto Percus que tem login usa o **auth-service** (OAuth Percus) como provedor único de identidade; pessoa comercial (afiliado/colaborador) vive só no **Painel Gestão e Afiliados**; cada produto guarda apenas profile/role local linkados via `identity_id`.

---

## A regra (5 linhas)

1. **Quem cria identidade:** só o `auth-service` (`https://auth.huboperacional.com.br`).
2. **Quem cria pessoa comercial** (CPF, pix, comissão, tier): só o `Painel Gestão e Afiliados`.
3. **Cada produto** (Plexco Tasks, Plexco Coach, Familia, Paid Midia, novo projeto): só guarda **profile local** + role + dados de domínio. Linka identidade via `identity_id UUID`.
4. **Nunca `UNIQUE(email)` global** em tabela local — sempre `UNIQUE(organization_id, email)` ou drop.
5. **Multi-org de fábrica:** mesma pessoa pode ser membro de N organizações no mesmo produto — `identity_id` une cross-org, `users.email` repete entre orgs.

---

## Como integrar (3 passos)

### 1. Registre uma `audience` no auth-service

Slug do seu produto (ex.: `meu-produto`). Audiences vigentes hoje:
`painel`, `familia`, `paid-media`, `plexco-coach`, `plexco-tasks`.

### 2. Valide JWT localmente via lib `percus-auth`

JWT EdDSA emitido pelo auth-service. JWKS público em `/.well-known/jwks.json`. Sem RTT por request — validação local via key cacheada.

```python
# Python (FastAPI) — exemplo real em Plexco Tasks/backend/app/api/deps.py
from percus_auth import PercusAuth

_validator = PercusAuth(
    jwks_url="https://auth.huboperacional.com.br/.well-known/jwks.json",
    issuer="https://auth.huboperacional.com.br",
    audience="meu-produto",
)
claims = await _validator.validate_async(token)
# claims.sub = "channel:handle" (ex: "whatsapp:+5567...", "email:foo@bar")
# claims.raw["iid"] = identity_id UUID (quando emitido)
```

Node/TS: lib equivalente em `https://auth.huboperacional.com.br/dist/percus-auth-<ver>.tgz`.

### 3. Tabela de users — schema obrigatório

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL,
    identity_id UUID,                                -- FK lógica pra auth.identities.id
    email TEXT,
    phone TEXT,
    -- ...campos do seu domínio (role, profile, etc.)
);

CREATE UNIQUE INDEX uq_users_org_email ON users (organization_id, LOWER(email)) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX uq_users_org_phone ON users (organization_id, phone)        WHERE phone IS NOT NULL;
CREATE UNIQUE INDEX uq_users_identity   ON users (identity_id)                  WHERE identity_id IS NOT NULL;
```

---

## Fluxo de convite (quando você adiciona pessoa a uma org no seu produto)

```
1. Recebeu pedido { email, phone, target_org_id, role }
2. POST auth-service /internal/identities { email, phone, origin: "meu-produto:invitation:<id>" }
   → idempotente: se existe, retorna o existente; senão cria. Em ambos os casos: identity_id.
3. INSERT INTO users (organization_id=target_org_id, identity_id=<retornado>, email, phone, role)
4. Manda link de ativação (email ou WhatsApp via Evolution).
```

Mesma pessoa em 2 orgs do mesmo produto = 2 rows em `users` com mesmo `identity_id`. Login funciona em ambas; org-switcher na UI escolhe contexto.

---

## Anti-padrões proibidos

| ❌ Não faça | ✅ Faça em vez |
|---|---|
| `users.password_hash` + bcrypt local | Sem credencial local. auth-service emite token via OTP/magic-link. |
| `UNIQUE(email)` ou `UNIQUE(phone)` globais | `UNIQUE(organization_id, email)` parcial. |
| Cadastro de afiliado local com CPF/pix | Read-only do Painel. Pessoa comercial mora lá. |
| Lookup user "por email" sem org context | Lookup por `identity_id`. Se não tem identity_id ainda, escope por org no WHERE. |
| Emitir JWT próprio com `aud=meu-produto` | Só o auth-service emite. Você só valida. |
| Coluna `auth_id` ou `gotrue_id` (legado) | `identity_id` é o nome canônico. |

---

## Estado atual da migração (Strangler Fig, 2026-05-14)

| Etapa | O que entrega | Status |
|---|---|---|
| 1 | Multi-org via `UNIQUE(org_id, email/phone)` em Plexco Tasks. Coluna `origin` em `auth.identities`. Endpoint `POST /internal/identities`. Coach aceita `organization_id` em lookups. | ✅ Entregue sessão 33 |
| 2 | Plexco Tasks 100% via `identity_id`. Invite com lookup-or-create. JWT com `org` claim. | Pendente |
| 3 | Plexco Coach migra pra auth-service (deixa JWT próprio). | Pendente — gatilho: Coach >100 users OU Etapa 2 ok |
| 4 | Painel emite identity ao criar afiliado. | Pendente — gatilho: Etapa 3 ok |

**Anti-scope explícito (não vai migrar retroativamente):** Familia-Milionaria (GoTrue legacy), ADS4PROS-Site, tiatendo, Paid Midia, Plexco Site. Auth-service é padrão pra projeto NOVO.

---

## Para começar (checklist 5 itens)

- [ ] **Leia** este doc + [OWNERSHIP.md](`D:\Claud Automations\OWNERSHIP.md`).
- [ ] **Decida**: seu projeto cria identidade (signup, convite com pessoa nova) ou só referencia?
- [ ] **Registre** audience do seu produto (peça no canal do estúdio ou abra PR no auth-service).
- [ ] **Implemente** validação JWT via `percus-auth` lib + tabela `users` com schema acima.
- [ ] **Valide** com smoke: usuário do seu produto também loga em outro produto Percus = SSO real (mesma identity, sessão compartilhada).

---

## Onde aprofundar

- **Decisão arquitetural completa** (premissas, alternativas avaliadas, why-not big-bang): `D:\Claud Automations\OWNERSHIP.md`
- **Receita passo-a-passo com código**: `_Novo_Projeto\checklists\CHECKLIST_AUTH_NOVO_PROJETO.md`
- **Plano operacional Strangler Fig com migrations/rollback**: `D:\Claud Automations\.claude-home\plans\agora-parece-queu-o-ancient-cloud.md`
- **Regra inegociável R19** (identidade canônica): `_Novo_Projeto\01_REGRAS_INEGOCIAVEIS.md`

---

## FAQ rápido

**P: Preciso migrar meu projeto antigo agora?**
R: Não. Auth-service é padrão pra projeto NOVO. Migração de existente só quando dor justificar (gatilhos listados acima).

**P: E se a pessoa muda de email/phone?**
R: O `identity_id` é estável — email/phone podem mudar no auth-service sem afetar os links locais. Atualização via `PATCH /me` no auth-service propaga via `GET /me`.

**P: SSO cross-produto funciona automaticamente?**
R: Hoje sim entre subdomínios do mesmo domain (cookie/token compartilhado). Cross-domain precisa magic-link explícito — ver regra R17.

**P: Como saber se identidade já existe antes de criar?**
R: `POST /internal/identities` é idempotente (lookup-or-create). Não precisa pré-check. Se existir, retorna o `identity_id` existente sem duplicar.

**P: E pessoa comercial sem login (lead, contato CRM)?**
R: Cria row local sem `identity_id`. Quando virar user, faz upgrade chamando auth-service e popula o campo.

**P: Auth-service tem rate limit?**
R: Sim — `/otp/request`: 5/destination/hora + 10/IP/64/hora. Hard limit; não burlar.

---

**Mantenedor do padrão:** estúdio Percus, time core. Mudanças via PR no `_Novo_Projeto`.
**Última atualização:** 2026-05-14 (sessão 33 — Etapa 1 do Strangler Fig entregue).
