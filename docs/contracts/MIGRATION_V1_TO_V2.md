---
tipo: guia de migração cross-repo
audiência: tech leads de cada projeto Percus + revisores
quando-usar: ao migrar referências de `PADRAO_AUTH_CROSS_PROJETO.md` (V1) → `PADRAO_AUTH_SERVICE.md` (V2)
status: vigente
referência: PADRAO_AUTH_SERVICE (V2 doc principal)
---

# Migração V1 → V2 — guia operacional

## Resumo

V1 (`PADRAO_AUTH_CROSS_PROJETO.md`) foi substituído por V2 (`PADRAO_AUTH_SERVICE.md`) em 2026-05-15. V1 está arquivado em `.archive/PADRAO_AUTH_CROSS_PROJETO.md`.

Este guia lista o que mudou + como atualizar referências cross-repo.

---

## O que mudou de V1 pra V2

| Tópico | V1 (até 2026-05-14) | V2 (a partir de 2026-05-15) |
|---|---|---|
| Tamanho | 1 página | 8 min de leitura, ~13 seções |
| Internal auth | `INTERNAL_KEY` global compartilhado | **Per-consumer secrets** (`internal_key_plexco`, etc) + `origin` derivado do secret |
| Idempotência `/internal/identities` | "first match wins" silent | AND lookup + **409 `identity_conflict`** com `conflicts[]` em mismatch |
| OTP error responses | 401 genérico + `detail` substring | `error_code` enumerado + status corretos (422/403/429) + `Retry-After` mandatory |
| SSO cross-product `org_id` | Não documentado | Endpoint stateless `GET /internal/resolve-org?iid=&aud=` |
| Audience registration | SQL direto OU PR (ambíguo) | **PR obrigatório** + CODEOWNERS + 2 approvals + security review pra `whatsapp_config` |
| Login method default | Não cravado (ambos suportados) | WA→OTP 5min · Email→Magic 24h · Admin→OTP+TOTP · Convite→Magic 24h |
| Magic-link TTL | `magic_ttl_seconds` único por audience | Split: `magic_ttl_email_seconds` (24h) + `magic_ttl_whatsapp_seconds` (10min) |
| Magic-link hardening | Não documentado | 128-bit CSPRNG · `GETDEL` atomic · `invalidated_at` · device fingerprint mandatory |
| Audit per-call `/internal/*` | Não existe | `auth.internal_call_log` (migration 009) — retenção 30d |
| Rotação de secrets | Anual | **Trimestral** + canary token |
| Reason `?reason=` | Sem registry | Registry V1 com 10 valores + validação server-side |
| Deploy | rsync | `git pull` + alembic-head guardrail |
| Doctrine PR sensibilidade | Cross-Claude review | Cross-Claude **+ lint estática `lint_audit_dispatch.py`** |
| Lib `percus-auth` | v0.1.0 (JWT validation) | v0.2.0 (+ `normalize_phone` + `ErrorCode` enum + `parse_subject` + Python/Node paridade) |
| Phone canonical | "E.164 normalizado" (vago) | **E.164 COM `+`** explícito + `phonenumbers`/`libphonenumber-js` (sem regex caseiro) |

---

## Como atualizar referências cross-repo

### Passo 1 — `grep` cross-repo

Rodar em cada repo Percus pra achar refs V1:

```bash
# Em cada repo (auth-service, Plexco Tasks, Coach, Familia, Painel, Paid Midia):
grep -r -l -i "PADRAO_AUTH_CROSS_PROJETO" . --include="*.md" --include="*.py" --include="*.ts" --include="*.tsx" --include="*.yaml" --include="*.yml" 2>/dev/null
```

### Passo 2 — substituir refs

**Antes:**
- `PADRAO_AUTH_CROSS_PROJETO.md`
- "padrão auth cross-projeto"
- "ver _Novo_Projeto/PADRAO_AUTH..."

**Depois:**
- `PADRAO_AUTH_SERVICE.md`
- "padrão auth service integration V2"
- "ver _Novo_Projeto/PADRAO_AUTH_SERVICE.md (V2, 2026-05-15)"

### Passo 3 — refatorar substring-match em error responses

Consumers que fazem `if 'invalid otp' in detail` precisam migrar pra `body.error_code` (V2 oficial). Janela de 30d após flip default da feature flag `AUTH_ERROR_CODE_V2` (Sessão 3 do plano operacional).

Substituir:
```python
# V1 (legacy, deprecated)
if 'invalid otp' in response.json()['detail'].lower():
    show_wrong_code_error()
elif 'expired' in response.json()['detail'].lower():
    show_expired_error()
```

Por:
```python
# V2
from percus_auth import ErrorCode  # lib >= 0.2.0
match response.json()['error_code']:
    case ErrorCode.OTP_WRONG.value:
        show_wrong_code_error()
    case ErrorCode.OTP_EXPIRED.value:
        show_expired_error()
    case _:
        show_unknown_error()
```

### Passo 4 — adotar `bearer_auth_with_phone_lookup`

Consumers que tinham `normalize_phone()` local (ex: Plexco Tasks `app/utils/phone.py`, Familia-api `app/modules/auth/service.py:25`) migram pra lib:

```python
# V1 (local)
def normalize_phone(raw):
    return re.sub(r'\D', '', raw)
user = db.query(User).filter(User.phone == normalize_phone(handle)).first()

# V2 (lib v0.2.0+)
from percus_auth import bearer_auth_with_phone_lookup
@router.get("/me", dependencies=[Depends(bearer_auth_with_phone_lookup(user_lookup_fn))])
```

Ver plano da lib: `auth-service/docs/superpowers/plans/2026-05-14-cross-percus-phone-normalization-and-login-ux.md`.

### Passo 5 — solicitar `consumer_id` + secret per-consumer (Sessão 5)

Consumers de `/internal/*` recebem secret próprio em vez de compartilhar `internal_key` global.

Plexco Tasks (já consumidor) é primeiro candidato — Sessão 5 do plano migra de `internal_key` → `internal_key_plexco` com Docker Secret renomeado + auth-service mapeia consumer_id.

Coach/Painel (futuro): pedir secret próprio ao auth-service team antes do primeiro deploy.

---

## Janelas e prazos

| Janela | Item | Início | Fim |
|---|---|---|---|
| 7d feature flag dual-path | Backend serve `error_code` E `detail` substring | Sessão 3 deploy | Sessão 3 + 7d |
| 30d substring-match deprecation | Consumer mantém fallback substring | Sessão 3 flip default | +30d → remover |
| 60d window contract V1 | Mudanças breaking exigem versão paralela | sempre | — |
| 90d monitor pwd antigo | Sessão 5 monitor passivo das credentials leaked | Sessão 5 deploy | +90d |

---

## Bloqueadores comuns

- **"Não tenho secret per-consumer ainda"** → enquanto Sessão 5 não rodar, consumer continua com `internal_key` global. Não é blocker pra V2 doc; é blocker pro hardening de Seção C.
- **"Lib v0.2.0 ainda não saiu"** → consumers podem ler V2 e preparar migração de schema/copy; código novo espera Sessão 2 do plano.
- **"Frontend ainda usa substring-match"** → tem 30d (Sessão 3+7d+30) pra migrar. Adoção medida via dashboard SigNoz por User-Agent.

---

## Checklist por repo

Cada repo precisa:

- [ ] Refs `PADRAO_AUTH_CROSS_PROJETO` substituídas por `PADRAO_AUTH_SERVICE`.
- [ ] README/CLAUDE.md/AGENTS.md mencionam V2 explicitamente.
- [ ] CI tem `User-Agent: <product-name>/<lib-version>` no client HTTP do auth-service (telemetria de adoção).
- [ ] Migration de phone canonical (E.164 com `+`) se for outlier (Plexco Tasks é).
- [ ] Switch `error_code` substituindo substring-match no frontend.
- [ ] `bearer_auth_with_phone_lookup` substituindo deps locais (quando lib v0.2.0 sair).

---

**Mantenedor:** auth-service team + tech-leads de cada repo.
**Última atualização:** 2026-05-15.
