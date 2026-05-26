# Handoff Painel — Port Allocation v6.10.0

> **Para:** sessão Claude operando no repo `D:\Claud Automations\Painel Gestao e Afiliados`
> **De:** canon Percus `_Novo_Projeto` v6.10.0 (cross-repo write protocol — canon não comita aqui)
> **Data:** 2026-05-26
> **Pré-requisito:** ler primeiro `Painel Gestao e Afiliados/docs/PORT_ALLOCATION_CONSUMER_GUIDE.md` (versão atual 1.0) e `Painel Gestao e Afiliados/execution/database/migration_port_base.sql` (migration v6.9.0 aplicada em prod)

---

## 1. Decisão (do operador)

R22 mudou em duas dimensões:

| | v6.9.x (atual em prod) | v6.10.0 (alvo) |
|---|---|---|
| Tamanho do bloco | 10 portas | **20 portas** |
| Range global | 3100–4099 (100 projetos) | **3000–9999 (~349 projetos)** |
| CHECK constraint | `BETWEEN 3100 AND 4090 AND port_base % 10 = 0` | `BETWEEN 3000 AND 9980 AND port_base % 20 = 0` |

**Migração é destrutiva**: todos os 7 projetos já alocados vão receber `port_base` novo. Operador autorizou. Consumidores serão notificados via `HANDOFF_CONSUMIDORES_v6.10.md` (canon-side).

Motivação: bloco de 10 era apertado pra projeto full-stack real — Vite + Storybook + Playwright + backend FastAPI + worker + Postgres local + Redis local consomem 7-8 offsets, quase zero margem. Bloco de 20 dá folga + reserva.

---

## 2. Mudanças a aplicar (4 arquivos + 1 SQL novo)

### 2.1. `execution/engine/catalogEngine.py` — constantes

Editar 3 linhas (`catalogEngine.py:77-79`):

```python
# Antes
PORT_ALLOC_RANGE_START = 3100
PORT_ALLOC_RANGE_END = 4090  # inclusive; ultimo bloco e 4090..4099
PORT_ALLOC_BLOCK_SIZE = 10

# Depois (v6.10.0)
PORT_ALLOC_RANGE_START = 3000
PORT_ALLOC_RANGE_END = 9980  # inclusive; ultimo bloco e 9980..9999
PORT_ALLOC_BLOCK_SIZE = 20
```

Mensagem de erro de range exausto (`catalogEngine.py:138-141`): atualizar texto pra refletir novo limite (`>{PORT_ALLOC_RANGE_END}` continua dinâmico — só revisar a frase "Expandir range" porque agora já é o range expandido).

Nada mais muda no engine. `pg_advisory_xact_lock(4242)` continua serializando. Cálculo `maxAllocated + BLOCK_SIZE` segue funcionando.

### 2.2. SQL — nova migration `execution/database/migration_port_base_v2.sql`

Não editar `migration_port_base.sql` original (histórico). Criar arquivo novo:

```sql
-- Port allocation v2 (canon Percus v6.10.0) — bloco de 20 + range 3000-9999.
-- Criado: 2026-05-26
-- Pre-requisito: migration_port_base.sql ja aplicada (Fase 6 v6.9.0).
-- DESTRUTIVO: zera todos os port_base existentes e re-aloca por ORDER BY id.

BEGIN;

-- 1. Drop CHECK antigo (range 3100-4090 / step 10).
ALTER TABLE projects DROP CONSTRAINT IF EXISTS chk_projects_port_base_range;

-- 2. Zera todas as alocacoes existentes (UNIQUE INDEX uq_projects_port_base
--    permite multiplos NULLs; CHECK ja foi dropado acima).
UPDATE projects SET port_base = NULL WHERE port_base IS NOT NULL;

-- 3. Re-aloca por ordem cronologica (ORDER BY id) em blocos de 20 a partir de 3000.
--    Usa CTE com row_number() pra calcular o port_base novo deterministicamente.
WITH ordered AS (
    SELECT id,
           3000 + (ROW_NUMBER() OVER (ORDER BY id) - 1) * 20 AS new_port_base
    FROM projects
    WHERE active = true  -- apenas projetos ativos recebem realocacao
)
UPDATE projects p
SET port_base = o.new_port_base
FROM ordered o
WHERE p.id = o.id;

-- 4. Sanity check: confirma que ninguem caiu fora do novo range.
DO $$
DECLARE
    bad_count INT;
BEGIN
    SELECT COUNT(*) INTO bad_count FROM projects
    WHERE port_base IS NOT NULL
      AND (port_base < 3000 OR port_base > 9980 OR port_base % 20 != 0);
    IF bad_count > 0 THEN
        RAISE EXCEPTION 'migration v6.10.0 falhou: % linhas com port_base invalido', bad_count;
    END IF;
END $$;

-- 5. Novo CHECK constraint (bloco 20 / range 3000-9980).
ALTER TABLE projects
    ADD CONSTRAINT chk_projects_port_base_range
    CHECK (port_base IS NULL OR (port_base BETWEEN 3000 AND 9980 AND port_base % 20 = 0));

COMMIT;
```

**Importante:** rodar dentro de transação (`BEGIN`/`COMMIT`). Se o sanity check falhar, `ROLLBACK` automático.

### 2.3. Tests — `tests/test_portAllocate.py`

Ajustar valores esperados:
- `port_base` do 1º projeto: `3100` → `3000`.
- `port_base` do 2º projeto sequencial: `3110` → `3020`.
- Step: 10 → 20.
- Range exausto test: forjar projeto com port_base=9980 e esperar erro no próximo allocate.

Padrão geral: substituir literais `3100`, `3110`, `4090`, `+10` por `3000`, `3020`, `9980`, `+20`.

### 2.4. `docs/PORT_ALLOCATION_CONSUMER_GUIDE.md` — bump pra versão 2.0

Mudanças mínimas no doc atual:

**Header:**
```
Versão: 2.0 · Data: 2026-05-26 · Painel commit: <commit-novo> · Canon: percus-kit v6.10.0 (regra R22 v2).
```

**§1 (Por que isso existe):**
> O bloco é fixo por projeto (idempotente): a partir do `port_base` o projeto pode usar `port_base+0`, `port_base+1`, ..., **`port_base+19`** pra Vite, Storybook, Playwright UI, mock servers, backend full-stack, worker, qualquer coisa local. Outros projetos nunca vão receber portas dentro desse range.

**§2 (O que está vivo em produção):**
- Resposta `range_end`: `port_base + 19` em vez de `+9`.
- Backend: trocar `Range global 3100..4090 em blocos de 10 → 100 projetos` por `Range global 3000..9999 em blocos de 20 → ~349 projetos`.

**§2.5 (NOVA seção — Concorrência):**
```markdown
## 2.5. Concorrência (2+ consultas simultâneas)

O endpoint é **seguro sob chamadas paralelas**:

- **Mesmo slug, 2× simultâneo:** as duas chamadas pegam o `pg_advisory_xact_lock(4242)`; a primeira a entrar no lock cria/recupera o `port_base`; a segunda, ao entrar, encontra `port_base IS NOT NULL` e retorna o mesmo valor (`kind: "existing"`). **Garantia: idempotência total.**
- **Slugs distintos, 2× simultâneo:** o lock serializa as duas execuções. Cada uma vê `MAX(port_base)` atualizado e atribui o próximo bloco. **Garantia: blocos distintos sempre, sem race.**
- **Defesa em profundidade:** o UNIQUE INDEX `uq_projects_port_base` (parcial, só rows com port_base NOT NULL) seria acionado se o lock fosse bypassado de algum jeito. Nunca aconteceu, mas é rede de segurança.

Cliente não precisa fazer retry com backoff exponencial — o lock é PG-nativo e segura a transação até a vez chegar. Timeout padrão do httpx do consumer (`port_allocate.py`) é 15s; em prática, cada alocação leva <50ms.
```

**§3 (Snapshot):** depois da migration, o snapshot vira (assumindo `ORDER BY id`):

| slug | range (`port_base`..`port_base+19`) |
|---|---|
| `painel-gestao` | **3000**·3019 |
| `tiatendo` | **3020**·3039 |
| `familia-milionaria` | **3040**·3059 |
| `ghl-evolution` | **3060**·3079 |
| `robo-vendas` | **3080**·3099 |
| `social-midia` | **3100**·3119 |
| `zap-disparador` | **3120**·3139 |

Próximo bloco livre: **3140**·3159.

> Confirmar ordem real via `SELECT slug, port_base FROM projects WHERE port_base IS NOT NULL ORDER BY port_base;` após rodar a migration. Se a ordem por `id` diferir desse snapshot, atualizar a tabela acima com a verdade do banco.

**§4 (Como adaptar cada projeto):** substituir `port_base+9` → `port_base+19` nos exemplos; substituir tabela de offsets pela canônica de v6.10.0 (12 slots nomeados + reserva +12..+19) — copiar de `_Novo_Projeto/01_REGRAS_INEGOCIAVEIS.md` R22.

### 2.5. Snapshot HTML/UI (`static/gestao/projetos.html`)

Se o template do badge tiver `PORTS 3110·3119` hardcoded, trocar pra renderização dinâmica `PORTS ${port_base}·${port_base+19}`. (Provavelmente já é dinâmico; só conferir.)

---

## 3. Ordem de execução

1. **Backup**: `pg_dump -t projects ...` no banco prod antes de qualquer coisa.
2. Aplicar `migration_port_base_v2.sql` em **staging** primeiro (se houver). Confirmar 7 linhas com port_base 3000, 3020, 3040, 3060, 3080, 3100, 3120.
3. Editar `catalogEngine.py:77-79` (constantes).
4. Atualizar tests + rodar `pytest tests/test_portAllocate.py`. Suite verde.
5. Editar `docs/PORT_ALLOCATION_CONSUMER_GUIDE.md` (bump 2.0).
6. Commitar tudo num único commit com mensagem `feat(R22-v2): bloco de 20 portas + range 3000-9999 (canon v6.10.0)`.
7. **Build + deploy da imagem `ads4pros-api`** (mesmo workflow de v6.9.0 → `ads4pros-api:fase7-20260526a`). Nova tag sugerida: `ads4pros-api:fase7-20260526b`.
8. Rodar `migration_port_base_v2.sql` em prod **antes** de subir a nova imagem (a imagem nova tem CHECK constraint novo; sem a migration, INSERT bate no CHECK).
9. Subir nova imagem.
10. Smoke: `curl -X POST https://api.ads4pros.com/admin/projects/port-allocate -H "X-Internal-Auth: $KEY" -d '{"slug":"painel-gestao"}'` → esperar `port_base: 3000, range_end: 3019, kind: "existing"`.
11. Notificar canon-side (sessão `_Novo_Projeto`) que está vivo em prod.

---

## 4. Rollback

Se migration falhar em prod ou snapshot pós-migration estiver inconsistente:

```sql
BEGIN;
ALTER TABLE projects DROP CONSTRAINT IF EXISTS chk_projects_port_base_range;
UPDATE projects SET port_base = NULL WHERE port_base IS NOT NULL;
-- Restaura snapshot v6.9.x manualmente a partir do pg_dump.
ALTER TABLE projects
    ADD CONSTRAINT chk_projects_port_base_range
    CHECK (port_base IS NULL OR (port_base BETWEEN 3100 AND 4090 AND port_base % 10 = 0));
COMMIT;
```

Imagem `ads4pros-api:fase7-20260526a` (v6.9.x) volta a ser compatível.

---

## 5. Não fazer

- **Não editar `migration_port_base.sql` original.** Criar `migration_port_base_v2.sql` novo. Histórico de migrations é imutável.
- **Não tocar em código fora do escopo desta v2.** Endpoint `/admin/projects/port-allocate` continua igual; engine continua usando advisory lock; UNIQUE INDEX continua o mesmo. Só **constantes + migration + tests + doc** mudam.
- **Não rodar migration sem backup.** É destrutiva por design (zera port_base antes de re-alocar).
