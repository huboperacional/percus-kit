---
name: port-allocate
description: Use ao criar projeto Percus novo OU ao migrar um legado para o padrão de portas locais (R22). Aloca PERCUS_PORT_BASE único (bloco de 20 portas, canon v6.10.0+) via Painel; cache local em .percus-ports.json. Fallback determinístico se Painel offline.
---

# Percus — Port Allocate

Aloca um **bloco de 20 portas locais** para o projeto (port_base, port_base+1, ..., port_base+19) consultando o Painel de Gestão como source of truth. Resolve colisões de porta em dev quando rodar múltiplos projetos Percus simultaneamente.

> **Breaking v6.10.0:** bloco passou de 10 → 20 portas; range global expandiu de 3100-4090 → 3000-9999. Projetos alocados sob v6.9.x foram re-alocados — operador re-roda esta skill em cada projeto e ajusta `.env` + configs.

## Quando usar

- **Projeto novo** (parte do scaffold `COMANDO_PROJETO_NOVO`): aloca `port_base` antes do `npm install` / primeiro `dev`.
- **Projeto legado** sendo migrado para R22: 1 vez por projeto. Depois operador ajusta vite.config / next.config / docker-compose para usar `process.env.PERCUS_PORT_BASE`.

Se o projeto já tem `.percus-ports.json` válido (`unverified: false`), o script faz short-circuit e retorna do cache — chamada subsequente é gratis.

## Pre-requisitos

- Python 3.10+ no PATH com `httpx` instalado (`pip install httpx`).
- `.env` do projeto (ou env do processo) com:
  - `PAINEL_API_URL` (default `https://api.ads4pros.com`)
  - `CATALOG_INGEST_KEY` (mesma key do skill `catalog-publish`)
- Endpoint vivo em prod desde 2026-05-26 (`ads4pros-api:fase7-20260526a`). **Fallback offline determinístico** entra automaticamente se Painel inacessível — operador é avisado via stderr e `.percus-ports.json` recebe `unverified: true` (exceção, não default).

## Fluxo

### 1. Detectar slug

Skill identifica o slug do projeto a partir de:

- `--slug <slug>` explícito, OU
- `metadata.name` do `catalog-info.yaml` na raiz, OU
- basename da pasta (lowercase + hyphens) como fallback.

### 2. Rodar wrapper

```bash
python "${PERCUS_CANON_DIR}/plugin/percus-review/scripts/port_allocate.py" --slug <slug> [--name "Nome Bonito"]
```

`--name` é obrigatório se o projeto ainda não existe no Painel (auto-create requer nome para a tabela `projects`). Para projetos legados que já constam no Painel via `catalog-publish`, basta `--slug`.

### 3. Resultado esperado

Stdout (uma linha, consumível por scaffold):

```
PERCUS_PORT_BASE=3080
```

Stderr (informativo):

```
[port-allocate] OK slug=tiatendo port_base=3080 range=3080..3099 kind=cached
```

Cache em `.percus-ports.json` (commitar em git):

```json
{
  "slug": "tiatendo",
  "port_base": 3080,
  "range_end": 3099,
  "allocated_at": "2026-05-26T13:17:09Z",
  "unverified": false,
  "kind": "painel-allocated"
}
```

### 4. Próximo passo (operador)

- Adicionar `PERCUS_PORT_BASE=NNNN` ao `.env.example` do projeto.
- Trocar porta literal por env var:
  - **Vite (`vite.config.ts`)** — `server.port = Number(process.env.PERCUS_PORT_BASE)` + **`strictPort: true` obrigatório** (sem isso o Vite cai pra ephemeral e a alocação não tem efeito).
  - **Next.js (`package.json`)** — `"dev": "next dev --port 3080"`, `"start": "next start --port 3080"`.
  - **Storybook (`package.json`)** — `"storybook": "storybook dev -p 3082 --no-open"` (port_base + 2).
  - **Playwright UI** — `npx playwright test --ui-port=3083 --ui-host=127.0.0.1` (port_base + 3).
  - **docker-compose.yml** — `ports: ["${PERCUS_PORT_BASE}:3000"]`.
- Convenção de offsets alinhada com Painel: ver tabela em `01_REGRAS_INEGOCIAVEIS.md` R22 / `02_INFRA_E_STACK_PERCUS.md` §5.5.
- Documente a convenção escolhida no `docs/PORTS.md` do projeto (mapa offset → serviço real, especialmente em full-stack onde `+1` pode ser backend em vez de preview).

## Idempotência

Chamada repetida com mesmo slug retorna mesmo `port_base`. Cache local + endpoint Painel são ambos idempotentes. Operador pode rodar quantas vezes quiser.

## Fallback offline

Se o Painel não responder (network error, sem credencial, endpoint não deployado ainda):

1. Calcula `hash(slug) % 350 → 3000 + hash*20` (determinístico — mesmo slug sempre cai no mesmo bloco; bloco de 20 em v6.10.0+).
2. Escreve `.percus-ports.json` com `unverified: true`.
3. Próxima rodada com Painel online: detecta `unverified` e reconcilia.

**Risco aceito** (registrado no plano): chance baixa de hash collision entre 2 slugs distintos. Reconcile detecta e re-aloca o slot perdedor.

## Anti-padrões

- ❌ Editar `.percus-ports.json` à mão sem rodar o script (cache fica fora de sync com Painel).
- ❌ Hardcode de porta em vite.config/docker-compose depois de alocar `port_base` (viola R22).
- ❌ Usar `port_base` fora do range alocado (e.g., front em `+0`, mas worker em `+27` — fora do bloco de 20).
- ❌ Pular `--name` em projeto novo e ignorar o erro "name not provided" (deixa estado pela metade no Painel).

## Referências

- Regra: R22 em [01_REGRAS_INEGOCIAVEIS.md](../../01_REGRAS_INEGOCIAVEIS.md)
- Convenção de offsets: [02_INFRA_E_STACK_PERCUS.md](../../02_INFRA_E_STACK_PERCUS.md) §5.5
- **Manual operacional Painel-side:** `Painel Gestao e Afiliados/docs/PORT_ALLOCATION_CONSUMER_GUIDE.md` (snapshot vigente de alocações, troubleshooting, curl direto)
- Endpoint VIVO em prod: `POST https://api.ads4pros.com/admin/projects/port-allocate` (header `X-Internal-Auth`)
- Auditoria visual: `https://gestao.ads4pros.com/projetos.html` (badge `PORTS 3100·3119` em cada projeto)
- Wrapper: `plugin/percus-review/scripts/port_allocate.py`
- Setup catalog (mesma key): `comandos/SETUP_CATALOG.md`
