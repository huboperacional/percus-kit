# Upgrade pra Fase 7 (canon v6.7→v6.8)

> Sucessor de `UPGRADE_PARA_FASE6.md`. Use este se o projeto está em v6.7.x ou anterior e quer migrar pra v6.8.0+.

## Pré-requisitos

- Projeto consumidor do canon Percus (tem `.percus-version` ou referencia `01_REGRAS_INEGOCIAVEIS.md`)
- Working tree limpa (todos os fixes pendentes commitados antes de migrar)

## Passos

### 1. Bump canon refs

- Atualizar `.percus-version` pra `6.8.0`
- Se houver plugin instalado (`percus-review`), bump pra versão compatível

### 2. Migrar audience naming (se aplicar — R7)

Audiências legadas com underscore (`plexco_tickets`, `plexco_tasks`) precisam ser renomeadas para kebab-case.

- [ ] Grep no projeto: `grep -rE "['\"](plexco|familia|painel|paid)_[a-z]+['\"]" --include="*.{ts,tsx,py,env,yaml,yml}"`
- [ ] Para cada match: substituir underscore por hífen (`plexco_tickets` → `plexco-tickets`)
- [ ] Coordenar com a migration Alembic no auth-service (Frente E — operador admin roda primeiro a SQL rename)
- [ ] Janela `alias_slugs` aceita ambos por 7 dias; depois remove

### 3. Bump lib percus-auth

- Next.js: `npm install percus-auth@^0.4.0`
- FastAPI: `pip install "percus-auth>=0.4.0"`

Mudanças relevantes:
- v0.3.0: `phone_handle_for_db_lookup()` — **obrigatório** em qualquer `WHERE phone = sub_handle`
- v0.4.0: `getTenantConfig()` + `useTenant` hook + `TenantProvider`

### 4. Migrar login UI (opcional na 1ª passada)

Se o projeto tem login custom:

- Comparar com `_Novo_Projeto/templates/login-ui/` — identificar drift
- Se o login custom tem bug, está hardcoded com product name, ou não usa tenant detection, **substituir pelo template**:

```pwsh
pwsh "$env:PERCUS_CANON_DIR/tools/scaffold-percus-project.ps1" -ProjectPath "$PWD" -AudienceFallback <slug> -Force
```

(`-Force` sobrescreve componentes antigos. Backup antes via git branch.)

### 5. Tenant config no auth-service

- [ ] PUT branding via UI (`/admin/audiences/{slug}/branding`) — preencher `product_name`, `logo_url`, `palette`, `copy`, `support_contact_url`
- [ ] Adicionar todos os `origins` no `auth.audiences.origins` (prod, staging, preview)

### 6. Smoke E2E pós-upgrade

- [ ] `npm test` ou `pytest` → all green
- [ ] `npm run build` → sem erro de tipo
- [ ] Abrir `/login` → renderiza com tenant config carregado (não fallback)
- [ ] Fluxo completo OTP → validate → `/me`
- [ ] Cookie `percus_session` com flags httpOnly+Secure+SameSite=Lax

### 7. Marcar upgrade no HANDOFF

Se o projeto usa `HANDOFF.md` (R2), adicionar entry:

```
## v6.7→v6.8 — 2026-05-20
- [x] Audiência renomeada de plexco_tickets → plexco-tickets
- [x] Lib percus-auth bump 0.3.x → 0.4.0
- [x] Login UI migrado pra template canon (componentes em src/components/auth/)
- [x] Branding registrado no auth-service
- [x] Smoke E2E ok
```

## Refs

- Spec da v6.8: [_Novo_Projeto/docs/superpowers/specs/2026-05-19-sprint-v6.8-auth-canonization-design.md](../docs/superpowers/specs/2026-05-19-sprint-v6.8-auth-canonization-design.md)
- Changelog: [_Novo_Projeto/CANON_VERSION.md](../CANON_VERSION.md)
- Templates: [_Novo_Projeto/templates/login-ui/README.md](../templates/login-ui/README.md)
