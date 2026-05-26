---
name: port-allocate
description: Use ao criar projeto Percus novo OU ao migrar um legado para o padrão de portas locais (R22). Aloca PERCUS_PORT_BASE único via Painel; cache local em .percus-ports.json. Fallback determinístico se Painel offline.
---

# Percus — Port Allocate

Aloca um **bloco de 10 portas locais** para o projeto (port_base, port_base+1, ..., port_base+9) consultando o Painel de Gestão como source of truth. Resolve colisões de porta em dev quando rodar múltiplos projetos Percus simultaneamente.

## Quando usar

- **Projeto novo** (parte do scaffold `COMANDO_PROJETO_NOVO`): aloca `port_base` antes do `npm install` / primeiro `dev`.
- **Projeto legado** sendo migrado para R22: 1 vez por projeto. Depois operador ajusta vite.config / next.config / docker-compose para usar `process.env.PERCUS_PORT_BASE`.

Se o projeto já tem `.percus-ports.json` válido (`unverified: false`), o script faz short-circuit e retorna do cache — chamada subsequente é gratis.

## Pre-requisitos

- Python 3.10+ no PATH com `httpx` instalado (`pip install httpx`).
- `.env` do projeto (ou env do processo) com:
  - `PAINEL_API_URL` (default `https://api.ads4pros.com`)
  - `CATALOG_INGEST_KEY` (mesma key do skill `catalog-publish`)
- Se nenhuma credencial estiver presente, **fallback offline determinístico** entra automaticamente — operador é avisado via stderr e `.percus-ports.json` recebe `unverified: true`.

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
PERCUS_PORT_BASE=3110
```

Stderr (informativo):

```
[port-allocate] OK slug=plexco-tasks port_base=3110 range=3110..3119 kind=cached
```

Cache em `.percus-ports.json` (commitar em git):

```json
{
  "slug": "plexco-tasks",
  "port_base": 3110,
  "range_end": 3119,
  "allocated_at": "2026-05-26T13:17:09Z",
  "unverified": false,
  "kind": "painel-allocated"
}
```

### 4. Próximo passo (operador)

- Adicionar `PERCUS_PORT_BASE=NNNN` ao `.env.example` do projeto.
- Trocar `port: 5173` (literal) por `port: Number(process.env.PERCUS_PORT_BASE ?? 3000)` em `vite.config.ts` / `next.config.ts`.
- Em `docker-compose.yml`, expor portas como `${PERCUS_PORT_BASE}:3000` (host:container).
- Convenção de offsets em `02_INFRA_E_STACK_PERCUS.md` — frontend usa `+0`, backend `+1`, etc.

## Idempotência

Chamada repetida com mesmo slug retorna mesmo `port_base`. Cache local + endpoint Painel são ambos idempotentes. Operador pode rodar quantas vezes quiser.

## Fallback offline

Se o Painel não responder (network error, sem credencial, endpoint não deployado ainda):

1. Calcula `hash(slug) % 100 → 3100 + hash*10` (determinístico — mesmo slug sempre cai no mesmo bloco).
2. Escreve `.percus-ports.json` com `unverified: true`.
3. Próxima rodada com Painel online: detecta `unverified` e reconcilia.

**Risco aceito** (registrado no plano): ~1% de chance de hash collision entre 2 slugs distintos. Reconcile detecta e re-aloca o slot perdedor.

## Anti-padrões

- ❌ Editar `.percus-ports.json` à mão sem rodar o script (cache fica fora de sync com Painel).
- ❌ Hardcode de porta em vite.config/docker-compose depois de alocar `port_base` (viola R22).
- ❌ Usar `port_base` fora do range alocado (e.g., front em `+0`, mas worker em `+27` — fora do bloco).
- ❌ Pular `--name` em projeto novo e ignorar o erro "name not provided" (deixa estado pela metade no Painel).

## Referências

- Regra: R22 em [01_REGRAS_INEGOCIAVEIS.md](../../01_REGRAS_INEGOCIAVEIS.md)
- Convenção de offsets: [02_INFRA_E_STACK_PERCUS.md](../../02_INFRA_E_STACK_PERCUS.md)
- Endpoint: `POST {PAINEL_API_URL}/admin/projects/port-allocate` (header `X-Internal-Auth`)
- Wrapper: `plugin/percus-review/scripts/port_allocate.py`
- Setup catalog (mesma key): `comandos/SETUP_CATALOG.md`
