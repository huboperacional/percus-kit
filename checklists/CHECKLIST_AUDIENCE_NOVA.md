---
tipo: checklist passo-a-passo
audiência: tech lead de projeto novo registrando audience no auth-service
quando-usar: ao adicionar `meu-produto` ao auth-service pela primeira vez
leitura: 4 min
referência: PADRAO_AUTH_SERVICE Seção D
---

# Checklist — registrar audience nova no auth-service

## Pré-requisitos

- [ ] Slug do produto definido (regex `^[a-z][a-z0-9-]+$`, max 32, kebab-case, sem sufixo de ambiente)
- [ ] Decisão de canal: WhatsApp + email? só email? só WhatsApp?
- [ ] Se WhatsApp: instance Evolution definida — **própria** (vai pra `infra/approved-evolution-instances.yaml`) ou **compartilhada** (`Auth_Todos`)?
- [ ] Se WhatsApp+SMTP custom: API keys já em Docker Secret no host VPS? (auth-service team confirma)

> ⚠️ **`Auth_Todos` NÃO é audience.** É nome de instance Evolution compartilhada. Audience usa kebab-case.

---

## Passos

### 1. Decidir provider de WhatsApp

| Caso | Provider | Config |
|---|---|---|
| Volume <100 OTP/dia + sem requisito de isolamento | `evolution_shared` | `{"instance_name": "Auth_Todos"}` |
| Volume >100 OTP/dia OU compliance LGPD exige isolamento | `evolution_self` | `{"api_key": "...", "instance_name": "<próprio>"}` |
| Tenant enterprise (futuro Fase 4+) | `cloud_api` | (TBD) |

### 2. Se for `evolution_self`: adicionar instance à allowlist

Editar `infra/approved-evolution-instances.yaml` no `percus-kit`:

```yaml
instances:
  - name: Auth_Todos
    purpose: OTP transacional compartilhado Percus
    audiences: [familia, painel, paid-media]
  - name: Plexco
    purpose: OTP transacional Plexco Tasks
    audiences: [plexco-tasks]
  - name: <NOVO_NOME>            # adicionar aqui
    purpose: <descrição>
    audiences: [<seu-slug>]
```

PR no `huboperacional/percus-kit` — 1 approval auth-team.

### 3. Migration Alembic no auth-service

Criar `services/api/alembic/versions/NNN_<slug>_audience.py`:

```python
"""<slug> audience

Revision ID: NNN
Revises: <prev_id>
"""
from alembic import op
import sqlalchemy as sa

revision = "NNN_<slug>_audience"
down_revision = "<prev_id>"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.execute("""
        INSERT INTO auth.audiences (
            audience, display_name,
            whatsapp_provider, whatsapp_config,
            email_provider, email_config,
            magic_ttl_email_seconds, magic_ttl_whatsapp_seconds,
            otp_ttl_seconds, otp_max_attempts
        ) VALUES (
            '<slug>',
            '<Display Name pt-BR>',
            'evolution_shared',
            '{"instance_name": "Auth_Todos"}'::jsonb,
            'smtp',
            '{}'::jsonb,
            86400,    -- 24h email magic
            600,      -- 10min whatsapp magic
            300,      -- 5min OTP
            5         -- max attempts
        )
    """)

def downgrade() -> None:
    op.execute("DELETE FROM auth.audiences WHERE audience = '<slug>'")
```

> ⚠️ **API key NUNCA hardcoded na migration.** Se `evolution_self`, deixar `whatsapp_config` mínimo (sem `api_key`) e setar via `UPDATE` em runbook separado lendo de Docker Secret na VPS.

### 4. Abrir PR no `huboperacional/auth-service`

- [ ] Branch nomeado `audience/<slug>` ou `feat/audience-<slug>`
- [ ] Título: `feat(audience): register <slug>`
- [ ] Descrição inclui:
  - Produto e propósito
  - Volume estimado de OTP/dia
  - Decisão de provider + justificativa
  - Confirmação de quem é o tech-lead responsável
- [ ] CODEOWNERS auto-atribui:
  - `@auth-service-team` sempre
  - `@security-team` se PR muda `whatsapp_config`, `email_provider` ou `whatsapp_provider`
- [ ] Mínimo **2 approvals** (1 deve ser security se tocar config sensível)
- [ ] Status check `audience-config-lint` verde (valida `instance_name` em allowlist)

### 5. Após merge

```bash
# Auth-service team faz deploy:
ssh vps "auth-service-deploy"

# Aguardar 1 min pra propagação (Redis pub/sub + cache TTL 60s):
sleep 60

# Smoke do projeto novo:
curl -s -X POST https://auth.huboperacional.com.br/otp/request \
  -H 'Content-Type: application/json' \
  -d '{"channel":"whatsapp","destination":"+5567XXXXXXXXX","audience":"<seu-slug>"}' \
  -w "\nHTTP %{http_code}\n"
# Esperado: HTTP 202 (não 422 audience desconhecida)
```

### 6. Pedir secret per-consumer (Sessão 5+ do plano)

Se o produto vai consumir `/internal/identities` ou `/internal/resolve-org`:

- [ ] Pedir secret per-consumer ao auth-service team: `internal_key_<slug>`
- [ ] Confirmar que Docker Secret externo está montado no compose do consumer
- [ ] Smoke: `curl -X POST /internal/identities -H 'X-Internal-Auth: <secret>' -d '...'` → 201

---

## Override `evolution_self` pós-criação

Se a audience começou com `evolution_shared` mas precisa migrar pra instance própria:

PR no `auth-service` com migration:

```python
def upgrade() -> None:
    op.execute("""
        UPDATE auth.audiences
        SET whatsapp_provider = 'evolution_self',
            whatsapp_config = jsonb_build_object(
                'instance_name', '<novo>'
                -- api_key setado em runbook separado via Docker Secret
            )
        WHERE audience = '<slug>'
    """)
```

**Mesmas regras de CODEOWNERS + 2 approvals + security review.**

Runbook pra setar `api_key` (separado da migration):
```sql
-- Executar via psql na VPS com PG super-user
-- Substitui placeholder pelo conteúdo de /run/secrets/evolution_api_key_<slug>
UPDATE auth.audiences
SET whatsapp_config = whatsapp_config || jsonb_build_object('api_key', :api_key)
WHERE audience = '<slug>';
```

---

## FAQ rápido

**P: Posso usar SQL direto em prod ao invés de PR?**
R: **Não**. PR é mandatório (perde audit trail + provoca drift staging/prod). V2 cravou.

**P: Quanto tempo demora pra audience nova ser reconhecida?**
R: <60s após deploy (Redis pub/sub + cache TTL 60s).

**P: Posso ter audience `meu-produto-staging`?**
R: **Não**. Audience é ambiente-agnostic. Ambientes separam por DB (staging tem outro auth-service).

**P: Posso reusar audience entre 2 produtos?**
R: **Não**. 1 audience = 1 produto. Identity multi-org acontece DENTRO de uma audience via `auth.memberships`.

**P: Como ver as audiences atuais?**
R: `SELECT audience, display_name, whatsapp_provider, whatsapp_config->>'instance_name' AS instance FROM auth.audiences ORDER BY audience;`

---

**Mantenedor:** auth-service team.
**Última atualização:** 2026-05-15.
