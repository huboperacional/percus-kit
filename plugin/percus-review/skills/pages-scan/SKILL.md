---
name: pages-scan
description: Use when explicitly asked to extract/sync routes or pages to the Painel de Gestao (POST /admin/pages/ingest). Targets FastAPI (@app.get/@app.post), Next.js (app/**/page.tsx), and static HTML — not generic code scanning or auditing. Auto-invoked by pre-commit and on-stop hooks; manually invoke only when catalog is stale or after adding new routes.
---

# Percus — Pages Scan

Extrai a lista de paginas/rotas ativas do projeto e empurra pro Painel via `POST /admin/pages/ingest`. Resultado aparece na aba **Paginas** em `gestao/projeto-detalhe.html?slug=...`.

## Detectores

| Tipo | Como detecta | Origem |
|---|---|---|
| FastAPI | Procura `@<router>.(get\|post\|put\|delete\|patch)("path")` em arquivos `*.py` em `execution/api/` | AST parse |
| Next.js App Router | Filesystem `app/**/page.tsx` ou `app/**/route.ts` | Glob + path-to-route |
| Next.js Pages Router | Filesystem `pages/**/*.tsx` exceto `_*` e `api/_*` | Glob |
| HTML estatico | Filesystem `static/**/*.html` ou `public/**/*.html` | Glob |

Cada rota vira uma entrada `{route, kind, method, file_path, title, feature_tags}`.

## Feature tagging

Skill le `# feature: <slug>` (Python) ou `// feature: <slug>` ou frontmatter `feature: <slug>` (Next.js / HTML) acima/no topo do arquivo e popula `feature_tags`. Opcional — falta de tag nao bloqueia.

## Pre-requisitos

- `.env` tem `PAINEL_API_URL` + `CATALOG_INGEST_KEY` (mesmo do catalog-publish).
- Projeto ja registrado no Painel (via `catalog-publish` ou seed manual).

## Fluxo

### 1. Detectar tipo de projeto

```python
isFastapi = Path("execution/api").exists() or Path("services/api").exists()
isNextApp = Path("app").exists() and any(Path("app").rglob("page.tsx"))
isNextPages = Path("pages").exists()
isStaticHtml = Path("static").exists() or Path("public").exists()
```

### 2. Scan

Rodar o wrapper:

```bash
python "D:/Claud Automations/_Novo_Projeto/plugin/percus-review/scripts/scan_pages.py"
```

Output: imprime lista + posta no Painel.

### 3. Reportar

```
[pages-scan] OK
  Projeto: <slug>
  Paginas detectadas: N (api: A, web: W, static: S)
  Painel: https://gestao.ads4pros.com/projeto-detalhe.html?slug=<slug>
```

## Auto-trigger

- **Pre-commit hook**: re-scan se arquivos relevantes mudaram (`*.py` em `execution/api/`, `app/**/page.tsx`, `static/**/*.html`).
- **On-stop hook**: scan completo + push.

Skip: `$env:PERCUS_SKIP_PAGES_SCAN=1`.

## Anti-padroes

- Hardcode de rotas no `catalog-info.yaml` — fonte e o codigo, nao yaml.
- Tag de feature em rota irrelevante (`# feature: oauth-v3` num endpoint que so logga) — feature tags devem refletir uso real.

## Referencias

- Tabela `project_pages` no Painel: `execution/database/migration_features.sql`
- Endpoint: `POST https://api.ads4pros.com/admin/pages/ingest` (API), UI em `https://gestao.ads4pros.com/projeto-detalhe.html` (estatico)
- Drill-down UI: `projeto-detalhe.html` aba Paginas
- Convencao: `D:/Claud Automations/_Novo_Projeto/05_FEATURE_TRACKING.md`
