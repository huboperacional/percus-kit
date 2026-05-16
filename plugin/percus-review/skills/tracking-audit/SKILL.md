---
name: tracking-audit
description: Use em PR que toca form/lead/conversion. Valida que os 15 campos canonicos de paid media (fbclid, gclid, gbraid, wbraid, msclkid, ttclid, fbp, fbc, utm_source/medium/campaign/content/term, referrer, landing_url) sao capturados em form, helper, request body, e DB. Roda grep estatico primeiro (~5s); oferece smoke E2E runtime se thresholds satisfeitos mas suspeita issue.
---

# Percus — Tracking Audit (R2)

Auditoria automatica dos 15 campos canonicos de atribuicao paid media. Formato escolhido (Opcao C hibrido com threshold explicito) validado por conselho 3-membros (consult `Painel/.deepseek/council-log/20260516-174848-consult.jsonl`).

Spec dos 15 campos: `D:\Claud Automations\_Novo_Projeto\03_TRACKING_ATTRIBUITION.md`.

## Quando rodar

- PR que adiciona/modifica:
  - Formulario de signup/lead/checkout (HTML/JSX/TSX).
  - Helper de captura de landing (URLSearchParams).
  - Endpoint de signup/lead/conversion (request body shape).
  - Migration que toca tabela de leads/signups/conversions.
- Auditoria mensal de projetos com paid media ativo.

## NAO rodar

- PR puramente interno (admin, dashboard) que nao envolve aquisicao paga.
- Projeto sem paid media (early-stage MVP organic-only).

## Pre-requisitos

- Python 3.10+ no PATH.
- Repo do projeto-alvo como CWD ao rodar.
- (Opcional pro modo E2E) `playwright` instalado pro smoke runtime: `pip install playwright; playwright install chromium`.

## Como rodar

```bash
# Modo default: grep estatico, threshold explicito
python "D:/Claud Automations/_Novo_Projeto/plugin/percus-review/scripts/tracking_audit.py"

# JSON output (CI)
python scripts/tracking_audit.py --json

# Forcar smoke E2E (Playwright) apos grep — usar se suspeitar runtime issue
python scripts/tracking_audit.py --e2e

# Override URL base pro smoke E2E (default: http://localhost:3000)
python scripts/tracking_audit.py --e2e --base-url http://localhost:3000
```

## Threshold explicito (sem ambiguidade)

Score baseado em 4 camadas (cada uma vale 25%):

| Camada | Como detecta | % se OK |
|---|---|---|
| **Form/Input** | `<input name="<field>">` em HTML/JSX/TSX | 25% (todos os 15 presentes) |
| **Helper landing** | URLSearchParams + persistencia (localStorage/cookie) | 25% (todos os 15 lidos) |
| **Request body** | JSON payload no fetch/axios pra endpoint signup/lead/conversion | 25% (todos os 15 enviados) |
| **DB migration** | Coluna correspondente na tabela alvo | 25% (todos os 15 persistidos) |

**Veredito (criterio explicito, nao subjetivo):**

```
TOTAL >= 80% AND helper_detectado AND migration_ok => PASS
TOTAL >= 60% mas falha em helper OR migration       => FAIL com indicacao do gap
TOTAL <  60%                                        => FAIL grave (paid media broken)
```

Sem este threshold explicito o veredito seria nao-deterministico (risco apontado pelo CC no consult).

## Output (modo human)

```
[tracking-audit] projeto: <slug>
Spec: 15 campos canonicos R2 (D:\Claud Automations\_Novo_Projeto\03_TRACKING_ATTRIBUITION.md)

Camada 1 — Form/Input (HTML/JSX/TSX)
  ✓ fbclid, gclid, gbraid, wbraid, msclkid, ttclid
  ✓ fbp, fbc
  ✓ utm_source, utm_medium, utm_campaign, utm_content, utm_term
  ✗ referrer (faltante)
  ✗ landing_url (faltante)
  Cobertura: 13/15 = 86.7%

Camada 2 — Helper landing (URLSearchParams + storage)
  Helper detectado: lib/tracking-attribution.ts
  Cobertura: 15/15 = 100%

Camada 3 — Request body (fetch/axios pra POST /signup, /lead, /conversion)
  Endpoint detectado: services/leads.ts -> POST /leads
  Cobertura: 14/15 (falta: landing_url) = 93.3%

Camada 4 — DB migration (colunas em leads/signups/conversions)
  Migration: alembic/versions/abc123_add_attribution.py
  Cobertura: 15/15 = 100%

VEREDITO: PASS (95% total, helper OK, migration OK)
  Gaps: 2 form fields (referrer, landing_url). 1 request body field (landing_url).
  Sugestao: form pode delegar pro helper preencher (referrer + landing_url sao auto-capturaveis).

Exit 0 = PASS. Exit 1 = FAIL. Exit 2 = erro IO/schema.
```

## Output (modo --json)

```json
{
  "version": 1,
  "project_cwd": "...",
  "fields_spec": ["fbclid", "gclid", ...],
  "layers": {
    "form":    {"covered": 13, "total": 15, "missing": ["referrer", "landing_url"]},
    "helper":  {"covered": 15, "total": 15, "missing": [], "detected_file": "lib/tracking-attribution.ts"},
    "request": {"covered": 14, "total": 15, "missing": ["landing_url"], "detected_file": "services/leads.ts"},
    "db":      {"covered": 15, "total": 15, "missing": [], "detected_file": "alembic/versions/abc123_add_attribution.py"}
  },
  "total_coverage_pct": 95.0,
  "verdict": "PASS",
  "gaps": ["form: referrer", "form: landing_url", "request: landing_url"]
}
```

## Modo E2E (--e2e)

Quando grep da PASS mas suspeita-se de runtime issue (ex: campos no form mas perdidos no submit), `--e2e` adiciona segunda passada:

1. Sobe servidor local (operador deve ter `npm run dev` ou equivalente rodando).
2. Playwright abre URL `<base-url>/?fbclid=test_fb&gclid=test_g&...&utm_source=test_src`.
3. Preenche form de signup minimo + submete.
4. Inspeciona request body via network capture.
5. (Opcional) Verifica DB via conexao direta se DATABASE_URL no .env.

Output adicional:
```
Camada 5 — Runtime E2E (Playwright)
  URL chamada: http://localhost:3000/?fbclid=test_fb&gclid=test_g&...
  Form submetido: </api/signup>
  Request body inspecionado: 12/15 campos no payload
  Faltantes runtime: fbp, fbc, referrer (helper nao incluiu)
```

E2E NAO e default por requerer servidor + Playwright + DB conn. Use so quando grep da resultado confuso.

## Opcao D futura (parser AST, sugerida pelo CC)

Se grep gerar >2 falsos-negativos reportados (ex.: `<input name={`utm_${k}`}>` dinamico, spread de props `{...trackingFields}`), evoluir pra parser AST (ts-morph pra TSX, babel pra JSX). Custo: +1 dep no plugin. NAO incluido v1 — esperar feedback real do uso.

## Anti-padroes

- ❌ Aprovar PASS sem revisar lista de gaps. PASS apos threshold ainda permite gaps em form/request.
- ❌ Forcar PASS desabilitando campos no .yaml — campos sao canon R2, nao opcional.
- ❌ Pular tracking-audit em PR de form "porque eu cuido depois". Atribuicao quebrada vira reporting errado.
- ❌ Rodar E2E em CI sem mock do servidor (vai timeout). E2E so local pre-commit.

## Limitacoes v1

- `helper detectado` procura por arquivo com `tracking-attribution.ts` ou similar — operador pode ter nome diferente. Override: pass `--helper-glob "lib/track*.ts"`.
- Migration detection scanea `alembic/versions/` e `migrations/` — projetos com path custom nao detectam (fallback: warn user no output).
- Request body scan procura `fetch(.../signup|lead|conversion)` — endpoints com nome diferente nao detectam (fallback: warn).

## Referencias

- Spec 15 campos: `D:\Claud Automations\_Novo_Projeto\03_TRACKING_ATTRIBUITION.md` Secao 2.
- Decisao Opcao C: `Painel Gestao e Afiliados/.deepseek/council-log/20260516-174848-consult.jsonl`.
- Skill source-of-truth runtime: projeto `Paid Midia Tracking` (PMT) em `D:\Claud Automations\Paid Midia Tracking\`.
- Skill irma: `pages-scan` (catalog feature), `security-audit` (R14-R19).
