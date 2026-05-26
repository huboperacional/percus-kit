# Handoff Consumidores — Port Allocation v6.10.0

> **Para:** sessão Claude operando em qualquer projeto Percus consumidor (ex: Plexco Tasks, Tiatendo, GHL-Evolution, Familia-Milionaria, etc.)
> **De:** canon Percus `_Novo_Projeto` v6.10.0
> **Data:** 2026-05-26
> **Pré-requisito:** Painel já deployado com v6.10.0 (ver `_Novo_Projeto/docs/handoffs/HANDOFF_PAINEL_v6.10.md`)

---

## 1. O que mudou (1 minuto)

Antes (v6.9.x): cada projeto Percus tinha **10 portas locais** (`port_base` .. `port_base+9`).
Agora (v6.10.0): cada projeto tem **20 portas locais** (`port_base` .. `port_base+19`).

Range global expandiu de `3100-4099` (100 projetos) para `3000-9999` (~349 projetos).

**Quase todos os projetos foram re-alocados** (apenas `painel-gestao` manteve `3100` por coincidência de ordenação UUID). Snapshot **real** pós-migration em prod (ordem por `id` UUID, confirmada via smoke 2026-05-26):

| slug | port_base antigo (v6.9.x) | port_base novo (v6.10.0) |
|---|---|---|
| familia-milionaria | 3120 | **3000** |
| ghl-evolution | 3130 | **3020** |
| robo-vendas | 3140 | **3040** |
| zap-disparador | 3160 | **3060** |
| tiatendo | 3110 | **3080** |
| painel-gestao | 3100 | **3100** |
| social-midia | 3150 | **3120** |

> Painel é a fonte canônica — rode `port-allocate` que ele te devolve o número certo. A tabela acima é só pra referência rápida.

**Próximo bloco livre para projeto novo:** 3140·3159.

---

## 2. Passo-a-passo (por projeto, ~5 min)

### Passo 1 — Re-rodar port-allocate

Dentro da raiz do projeto:

```bash
python "${PERCUS_CANON_DIR}/plugin/percus-review/scripts/port_allocate.py" --slug <seu-slug>
# stdout: PERCUS_PORT_BASE=NNNN  (esse é o novo port_base)
```

Isso atualiza `.percus-ports.json` automaticamente. Confirma no arquivo:

```json
{
  "slug": "<seu-slug>",
  "port_base": NNNN,
  "range_end": NNNN+19,
  "unverified": false,
  "kind": "existing"
}
```

`range_end` agora é `port_base + 19` (era `+9`).

### Passo 2 — Atualizar `.env` e `.env.example`

Substituir o valor antigo:

```diff
- PERCUS_PORT_BASE=3110
+ PERCUS_PORT_BASE=3020
```

### Passo 3 — Revisar configs por stack

Procure qualquer **literal** de porta que esteja no range antigo (3110, 3111, 3112, ...) e troque pelo novo (3020, 3021, 3022, ...). Idealmente já está tudo expresso via `${PERCUS_PORT_BASE}` ou `process.env.PERCUS_PORT_BASE`; se sim, **nada a editar** (só re-startar o dev server).

Onde costuma haver literal:
- `vite.config.ts` — `server.port`, `preview.port`
- `next.config.mjs` — raramente, mas conferir
- `package.json` scripts — `"dev": "next dev --port 3110"`, `"storybook": "storybook dev -p 3112"`, `"playwright test --ui-port=3113"`
- `docker-compose.yml` / `docker-compose.*.yml` — `ports: ["3110:3000"]`
- `Dockerfile` — `EXPOSE 3110`
- `.env*` — `PORT=3110`, `BACKEND_PORT=3115`
- Documentação (`README.md`, `docs/PORTS.md`)
- Tests E2E (Playwright config, Cypress baseUrl)

**Comando útil para varrer:**
```bash
# Bash / git-bash:
grep -rn "31[0-9][0-9]" --include="*.{ts,tsx,js,json,yml,yaml,md,env}" --include=".env*" .

# PowerShell:
Get-ChildItem -Recurse -Include *.ts,*.tsx,*.js,*.json,*.yml,*.yaml,*.md,.env* | `
    Select-String -Pattern "31[0-9][0-9]"
```

Substituir cada hit pelo novo número ou (preferível) por `${PERCUS_PORT_BASE}+offset`.

### Passo 4 — Tabela de offsets atualizada (12 slots nomeados)

A convenção canônica v6.10.0 (sugerida, não trava):

| Offset | Uso típico |
|---|---|
| `+0` | Dev server principal |
| `+1` | Preview/build ou backend secundário |
| `+2` | Storybook |
| `+3` | Playwright UI |
| `+4` | Mock server / MSW |
| `+5` | Backend FastAPI/uvicorn (full-stack) |
| `+6` | Worker |
| `+7` | Postgres local dedicado |
| `+8` | Redis local dedicado |
| `+9` | MinIO local |
| `+10` | Mailhog / dev SMTP UI |
| `+11` | Outro daemon |
| `+12..+19` | Reserva — documentar em `docs/PORTS.md` |

Projeto full-stack pode remapear como precisar — só **documentar em `docs/PORTS.md`** do projeto.

### Passo 5 — Smoke test

```bash
# Sobe o dev server:
npm run dev   # ou pnpm dev, ou docker compose up

# Em outro terminal — confere que pegou a porta nova:
curl -I http://localhost:NNNN/   # NNNN = seu port_base novo
```

Se o Vite cair pra ephemeral em vez do `port_base`, confirme **`strictPort: true`** em `vite.config.ts` (sem isso, R22 não tem efeito).

### Passo 6 — Commit

```bash
git add .percus-ports.json .env.example .env.* vite.config.* next.config.* package.json docker-compose*.yml docs/PORTS.md
git commit -m "chore(R22-v2): re-aloca port_base canon v6.10.0 (bloco 20)"
```

---

## 3. Validação cruzada

Depois que o dev server estiver no `port_base` novo:

1. **Auditoria visual:** `https://gestao.ads4pros.com/projetos.html` deve mostrar badge `PORTS NNNN·NNNN+19` (range de 20) no card do seu projeto.
2. **Cache local:** `.percus-ports.json` com `unverified: false` e `range_end == port_base + 19`.
3. **`.percus-version`** do projeto: bump pra `6.10.0` se já estava em alguma versão Fase 6/7.

---

## 4. Se algo der errado

| Sintoma | Diagnóstico | Fix |
|---|---|---|
| `port_allocate.py` retorna 404 / network error | Painel ainda em v6.9.x ou indisponível | Esperar deploy v6.10.0 do Painel; **não** rodar em fallback offline (vai dar `unverified: true` num número que talvez já esteja alocado pra outro projeto pós-realocação) |
| `range_end` no cache ainda é `port_base + 9` | Wrapper antigo (canon ≤v6.9.x) ou cache stale | `python port_allocate.py --force --slug <slug>` pra re-consultar Painel |
| Dev server sobe em porta ephemeral (52924, 60123…) | `strictPort: true` faltando em Vite | Adicionar `strictPort: true` em `server` e `preview` no `vite.config.ts` |
| 2 projetos batem na mesma porta | Um dos dois ainda está no `port_base` antigo | Re-rodar passos 1-5 no projeto retardatário |
| Erro `port_base range exausto` ao alocar projeto novo | Range 3000-9980 cheio (≥349 projetos alocados) | Bumpar `PORT_ALLOC_RANGE_END` no Painel — não esperado nessa década |

---

## 5. Comunicar pra equipe

Cada operador/agente que estiver em projeto Percus precisa:

1. Ler este handoff.
2. Rodar os 6 passos do §2 dentro do projeto.
3. Atualizar config local (`.env`) — devs com `.env` no host precisam puxar o valor novo de quem fez o commit.
4. Quem mantiver `docker-compose.override.yml` local com porta hardcoded, atualizar o override.

Não há mudança em portas de **produção** (VPS). Apenas portas **locais de dev** em cada máquina do operador.
