---
name: catalog-publish
description: Use after editing catalog-info.yaml or on session stop. Pushes the feature catalog to Painel de Gestao API (/admin/catalog/ingest) and updates project_features cross-projeto. Auto-invoked by on-stop hook when catalog-info.yaml changes.
---

# Percus — Catalog Publish

Empurra o `catalog-info.yaml` (raiz do repo) pro Painel de Gestao, atualizando a matriz feature × projeto consultada em `https://gestao.ads4pros.com/features.html`.

## Pre-requisitos

- `catalog-info.yaml` existe na raiz do projeto.
- `.env` tem `PAINEL_API_URL` (default `https://api.ads4pros.com`) e `CATALOG_INGEST_KEY`.
- PyYAML + httpx disponiveis no Python do projeto (`pip install pyyaml httpx`).

## Fluxo

### 1. Verificar mudanca

Skill so faz push se `catalog-info.yaml` mudou desde o ultimo commit. Verificar com:

```bash
git diff --quiet HEAD -- catalog-info.yaml && echo "no change" || echo "changed"
```

Se "no change", pular (skill termina sem operacao).

### 2. Validar YAML

Antes de push, parse local pra confirmar sintaxe:

```bash
python -c "import yaml; yaml.safe_load(open('catalog-info.yaml'))"
```

Se falha, mostrar erro ao operador e parar.

### 3. Push pro Painel

Rodar wrapper:

```bash
python "${env:PERCUS_CANON_DIR}/plugin/percus-review/scripts/catalog_publish.py"
```

(ou `.ps1` em Windows — pendente).

Resposta esperada: 201 `{"project_id": "...", "features_upserted": N}`.

### 4. Reportar

```
[catalog-publish] OK
  Projeto: <slug>
  Features upserted: N
  Painel: https://gestao.ads4pros.com/features.html
```

Se 404 (project not found in Painel) ou 401 (key invalida), pedir ao operador pra rodar `comandos/SETUP_CATALOG.md` primeiro.

## Auto-trigger (on-stop hook)

Hook `on-stop-check.{ps1,sh}` v6.0.0+ detecta `catalog-info.yaml` modificado e invoca esta skill automaticamente antes do Stop. Sem acao manual necessaria.

Skip explicito (raro): `$env:PERCUS_SKIP_CATALOG_PUBLISH=1` antes do Stop.

## Anti-padroes

- Editar catalog-info.yaml e nao commitar — diff some no proximo on-stop.
- Adicionar feature ad-hoc sem slug canonico (ver `05_FEATURE_TRACKING.md` "Slugs canonicos").
- Pular push depois de mudanca grande — Painel fica defasado.

## Referencias

- Convencao: `${env:PERCUS_CANON_DIR}/05_FEATURE_TRACKING.md`
- Template: `${env:PERCUS_CANON_DIR}/templates/catalog-info.yaml.template`
- Setup primeira vez: `${env:PERCUS_CANON_DIR}/comandos/SETUP_CATALOG.md`
- Endpoint: `POST https://gestao.ads4pros.com/admin/catalog/ingest` (header `X-Internal-Auth`)
