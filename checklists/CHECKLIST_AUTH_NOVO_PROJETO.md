---
tipo: checklist
quando-usar: ao iniciar projeto novo OU ao adicionar auth a projeto existente
prevalecido-por: [CLAUDE.md do projeto atual, OWNERSHIP.md]
leitura: 5 min
referência-primária: D:\Claud Automations\OWNERSHIP.md
---

# Checklist — Auth no Projeto Novo

Receita prática pra um projeto novo (ou em greenfield) consumir o auth-service Percus sem reinventar identidade. Cada item é gate verificável.

> **Antes de tudo, leia** `D:\Claud Automations\OWNERSHIP.md` — define quem cria identidade vs quem só referencia. Este checklist é a aplicação prática daquele documento.

---

## 1. Vai ter login? → registre audience no auth-service

Toda app que aceita JWT do auth-service precisa de uma `audience` registrada. Audience identifica o produto consumidor (validação JWT confere `aud` claim).

**Como:**

- Audience curta, slug-style: `meu-produto` (não `meu_produto`, não `MeuProduto`).
- Registrar via `POST /audiences` (admin) ou seed migration no auth-service.
- Audiences já registradas (2026-05-14): `painel`, `familia`, `paid-media`, `plexco-coach`, `plexco-tasks`.

**Gate:** `curl https://auth.huboperacional.com.br/.well-known/audiences` (ou equivalente) retorna seu slug.

**Não tem login?** Pule pra item 4 (você ainda pode referenciar identidades, só não emite JWT).

---

## 2. Vai consumir JWT? → use lib `percus-auth`

Validação JWT é local em cada projeto via JWKS cacheado (R7). Não chame o auth-service a cada request.

**Como (backend Python — FastAPI):**

```python
# pip install <url-do-whl-self-hosted>
# https://auth.huboperacional.com.br/dist/percus_auth-<ver>-py3-none-any.whl

from percus_auth import verify_jwt

claims = verify_jwt(
    token,
    audience="meu-produto",
    issuer="https://auth.huboperacional.com.br",
)
# claims = { "sub": "<identity_id>", "org": "<org_id>", "iid": "<identity_id>", ... }
```

**Como (frontend / backend Node):**

```bash
# npm install <url-do-tgz-self-hosted>
# https://auth.huboperacional.com.br/dist/percus-auth-<ver>.tgz
```

**Referência real:** `D:\Claud Automations\Plexco Tasks\backend\app\api\deps.py` (linhas 84-101) mostra extração de claims, lookup de user por `identity_id`, fallback por email/phone com warning durante transição.

**Gate:** request com Bearer válido emitido pelo auth-service → backend extrai `sub` sem ir na rede.

---

## 3. Vai ter users? → tabela com `identity_id`, sem UNIQUE global

Sua tabela local de users/profiles **referencia** a identidade canônica do auth-service. **Não** tem credencial própria.

**Schema canônico:**

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    identity_id UUID,  -- FK lógica pra auth.identities.id (DB separado; integridade na app)
    email TEXT,
    phone TEXT,
    -- ...campos do seu domínio (role, profile, etc.)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unicidade DENTRO da org (mesmo email pode estar em outra org — multi-org legítimo)
CREATE UNIQUE INDEX uq_users_org_email ON users (organization_id, LOWER(email)) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX uq_users_org_phone ON users (organization_id, phone)       WHERE phone IS NOT NULL;

-- Quando identity_id estiver populado, ele também é único na org
CREATE UNIQUE INDEX uq_users_org_identity ON users (organization_id, identity_id) WHERE identity_id IS NOT NULL;
```

**Anti-padrões proibidos:**

- `UNIQUE(email)` global — quebra multi-org no primeiro usuário que existe em 2 orgs (bug real, sessão 33 do Plexco Tasks).
- `UNIQUE(phone)` global — idem.
- `password_hash` na sua tabela — credencial mora no auth-service.

**Gate:** sweep do banco mostra que `users.email` e `users.phone` **não** têm constraint UNIQUE global. Apenas escopado por `organization_id`.

---

## 4. Vai ter pessoa comercial (afiliado, colaborador, parceiro)? → conecta via `Painel.affiliates.identity_id`

Pessoa comercial = pessoa que recebe comissão/pix/CPF gestão. **Mora no Painel** — não duplique cadastro.

**Padrão de integração:**

- Seu projeto **não** cria tabela `affiliates`. Se precisa rastrear afiliado, lê do Painel (API ou view materializada).
- Se a pessoa comercial também loga no seu produto: ela tem `identity_id` no auth-service, e o `Painel.affiliates.identity_id` aponta pra mesma identity. Você junta por `identity_id`.
- Cadastro de afiliado novo = chamada pra API do Painel, que internamente chama `auth-service POST /internal/identities` (Etapa 4 do Strangler Fig — ver `OWNERSHIP.md`).

**Gate:** seu projeto não tem coluna `commission_rate`, `pix_key`, `cpf` em tabela local. Se precisa exibir, vem de query/cache do Painel.

---

## 5. Convite de novo user? → lookup auth-service primeiro

Cenário: você quer adicionar uma pessoa a uma org no seu produto. Email/phone podem já existir em outro produto Percus (e portanto já têm identity).

**Fluxo correto:**

```
1. Recebeu pedido de convite: { email, phone, target_org_id, role }
2. Lookup no auth-service:
   GET /internal/identities?email=<email>   (ou ?phone=<phone>)
3. Identity existe?
   ├─ SIM → use identity_id retornado.
   │       INSERT INTO users (organization_id, identity_id, email, phone, role)
   │            VALUES (target_org_id, found_identity_id, email, phone, role);
   │       Manda email/wa "você foi adicionado à org X — clique pra entrar"
   │       (link com magic-link via auth-service /auth/magic/issue — ver R17).
   │
   └─ NÃO → cria via auth-service.
           POST /internal/identities {
               email, phone,
               origin: "meu-produto:invitation:<invitation_id>"
           }
           → recebe identity_id.
           INSERT INTO users (..., identity_id) ...
           Manda welcome com magic-link (first-login).
```

**Referência real (em construção, Etapa 2 do Strangler):** `D:\Claud Automations\Plexco Tasks\backend\app\api\v1\invitations.py`.

**Anti-padrão proibido:** criar `users` com password local + mandar email "sua senha é XYZ123". Sem auth-service, sem credencial.

**Gate:** convidar pessoa que já existe em outro produto Percus reutiliza `identity_id` (não duplica identity). Login dela funciona com a sessão atual (SSO cross-produto se subdomínio compartilhado — R16).

---

## Resumo dos gates

- [ ] Audience registrada no auth-service
- [ ] Lib `percus-auth` (Python ou Node) instalada e validando JWT local
- [ ] Tabela `users`/`profiles` com `identity_id UUID`, **sem** `UNIQUE(email)` global
- [ ] Não há tabela local de pessoa comercial — reusa Painel
- [ ] Fluxo de convite faz `lookup-or-create` no auth-service antes de inserir local

---

## Referências

- `D:\Claud Automations\OWNERSHIP.md` — quadro de ownership e árvore de decisão.
- `D:\Claud Automations\_Novo_Projeto\01_REGRAS_INEGOCIAVEIS.md` — R7 (auth padrão), R17 (magic links), R19 (identidade canônica).
- `D:\Claud Automations\Plexco Tasks\backend\app\api\deps.py` — exemplo real de validação JWT.
- `D:\Claud Automations\Plexco Tasks\backend\app\api\v1\invitations.py` — exemplo de fluxo de convite (em transição na Etapa 2 do Strangler Fig).
- `D:\Claud Automations\.claude-home\plans\agora-parece-queu-o-ancient-cloud.md` — plano Strangler Fig completo.
