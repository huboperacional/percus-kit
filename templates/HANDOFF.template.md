# Handoff — {Nome do Projeto}

_Atualizado em: {YYYY-MM-DD} às {HH:MM}_
_Sessão: {breve título da sessão atual}_

---

## Estado atual

- **Funcionando END-TO-END (ciclo CRUD testado nesta sessão):**
  - {feature 1}
  - {feature 2}

- **UI pronta mas sem ciclo testado (`[4-C]`):**
  - {feature 3}

- **Backend parcial (`[2-E]` ou `[3-H]`):**
  - {feature 4}

- **Quebrado / regressão detectada:**
  - {item, ou "nenhum"}

- **Último passo concluído:**
  {descrição literal e específica}

- **Próximo passo imediato:**
  {comando exato ou ação específica — sem ambiguidade}

---

## Status de Features

> Fonte da verdade: `docs/PLANO.md`. Se divergir daqui, corrija este handoff.
> Tags: `[0]` planejado · `[1-S]` schema · `[2-E]` endpoint · `[3-H]` hook · `[4-C]` componente · `[5-T]` ✅ ciclo testado
> Marcações (acumulam, ortogonais à tag):
> - `🎨` draft aprovado (v0.dev/shadcn) · `🎨?` precisa draft antes de `[1-S]`
> - `🤖` implementado via DeepSeek (R13) · `✓` revisor cross-provider aprovou no marco (R11)

| Frente | Feature | Status | Próxima etapa |
|--------|---------|--------|---------------|
| {Frente 1} | {Feature A} | `[5-T]` ✓ ✅ | — (marco aprovado) |
| {Frente 1} | {Feature B} | `[4-C]` 🤖 | Testar ciclo CRUD com F5 (impl. via DeepSeek) |
| {Frente 2} | {Feature C} | `[2-E]` 🎨 | Criar hook + componente |
| {Frente 2} | {Feature D} | `[0]` 🎨? | Bloqueada — gerar via v0.dev (tela) ou shadcn add (componente) |
| {Frente 3} | {Feature E} | `[0]` | Não iniciada |

---

## Credenciais e arquivos externos

| Arquivo / Var | Status | Onde obter se faltar |
|---|---|---|
| `credentials.json` | ✅ presente / ❌ faltando | GCP Console → APIs & Services → Credentials |
| `token.json` | ✅ presente / ❌ faltando | Rodar `execution/generate_oauth_token.py` |
| `OPENAI_API_KEY` | ✅ no `.env` / ❌ | platform.openai.com |
| `EVOLUTION_API_KEY` | ✅ no `.env` / ❌ | Painel Evolution na VPS |
| `JWT_SECRET` (estado Transição — sidecar HS256) | ✅ no `.env` / ❌ / N/A se Final | Gerar: `python -c "import secrets; print(secrets.token_urlsafe(64))"` |
| `AUTH_SERVICE_JWKS_URL` (estado Final — consumir auth-service) | ✅ no `.env` / ❌ / N/A se Transição | URL JWKS pública do auth-service Percus (ex.: `https://auth.percus.internal/.well-known/jwks.json`) |

---

## Infraestrutura provisionada

- **DB PostgreSQL:** `{nome_do_banco}` no container `postgres_postgres` (VPS)
- **Redis namespace:** `{slug_projeto}:*` no container `redis_redis` (VPS)
- **Stack Portainer:** `{nome_da_stack}`
- **Domínio:** `{subdominio}.{dominio}` → DNS only no Cloudflare? ✅ / ❌
- **Backend rodando em (dev local):** `{url ou porta}`
- **Frontend rodando em (dev local):** `{url ou porta}`

---

## Decisões arquiteturais tomadas nesta sessão

- {decisão 1 + motivo}
- {decisão 2 + motivo}

---

## Problemas conhecidos / workarounds ativos

- **{Problema 1}** → {Workaround em uso, e quando seria correto resolver de verdade}
- **{Problema 2}** → {...}

---

## Comandos para verificar estado real (rode ao retomar)

```bash
# Testar conexão VPS (se aplicável)
python -c "from execution.ssh_runner import run_remote; print(run_remote('echo ok'))"

# Listar endpoints existentes no backend
grep -rn "router\.\(get\|post\|put\|delete\|patch\)" services/api/app --include="*.py"

# Verificar arquivos ainda usando mock-data
grep -rln "mock-data\|mockData\|MOCK_\|fakeData" web/src --include="*.ts" --include="*.tsx"

# Status do banco (se DB local)
psql -d {slug_projeto}_v1 -c "\dt"

# Rodar migrations pendentes
cd services/api && alembic upgrade head
```

---

## Cobranças para a próxima sessão (cole no chat se eu esquecer)

- "Faz vertical: criar X, F5, editar, F5, deletar, F5 — tudo persistindo."
- "Lista o que ainda é mock no `mock-audit.md`."
- "Conecta essa tela ao backend antes de criar qualquer coisa nova."
- "Não commite até ter testado o ciclo CRUD."
- "Atualiza HANDOFF e PLANO antes de fechar."

---

> ⚠️ Status desatualizado neste handoff é mentira documentada. Se você marcou `[5-T]` aqui sem rodar o ciclo CRUD nesta sessão, corrija agora.
