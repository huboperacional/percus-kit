#!/usr/bin/env python3
"""catalog_publish.py — Le catalog-info.yaml da CWD e empurra pro Painel.

Fase 6 / Eixo A. Invocado pela skill `percus-review:catalog-publish`.

Uso:
    python catalog_publish.py                      # le catalog-info.yaml da CWD
    python catalog_publish.py <path-to-yaml>       # path explicito

Env vars consumidas (do .env do projeto):
    PAINEL_API_URL          default: https://gestao.ads4pros.com
    CATALOG_INGEST_KEY      obrigatorio (senao fallback pra METRICS_INGEST_KEY)
    METRICS_INGEST_KEY      fallback

Exit codes:
    0   sucesso
    1   erro de parse / arquivo nao encontrado
    2   erro de network / API
    3   credencial faltando
"""
from __future__ import annotations

import os
import sys
import json
from pathlib import Path
from typing import Optional

try:
    import yaml
except ImportError:
    print("[catalog-publish] ERROR: pyyaml nao instalado. Rode: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

try:
    import httpx
except ImportError:
    print("[catalog-publish] ERROR: httpx nao instalado. Rode: pip install httpx", file=sys.stderr)
    sys.exit(1)


def _loadDotenv(path: Path) -> dict[str, str]:
    """Parse minimal .env (KEY=value, sem export, sem quotes complexos)."""
    env: dict[str, str] = {}
    if not path.exists():
        return env
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def main() -> int:
    yamlPath = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("catalog-info.yaml")
    if not yamlPath.exists():
        print(f"[catalog-publish] ERROR: {yamlPath} nao encontrado", file=sys.stderr)
        return 1

    try:
        parsed = yaml.safe_load(yamlPath.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        print(f"[catalog-publish] ERROR parse YAML: {exc}", file=sys.stderr)
        return 1

    if not isinstance(parsed, dict) or "metadata" not in parsed:
        print("[catalog-publish] ERROR: catalog-info.yaml sem metadata", file=sys.stderr)
        return 1

    # Resolve credenciais (env do processo OU .env local)
    dotenv = _loadDotenv(Path(".env"))
    apiUrl = os.getenv("PAINEL_API_URL") or dotenv.get("PAINEL_API_URL") or "https://gestao.ads4pros.com"
    key = (
        os.getenv("CATALOG_INGEST_KEY")
        or dotenv.get("CATALOG_INGEST_KEY")
        or os.getenv("METRICS_INGEST_KEY")
        or dotenv.get("METRICS_INGEST_KEY")
    )
    if not key:
        print("[catalog-publish] ERROR: CATALOG_INGEST_KEY (ou METRICS_INGEST_KEY) nao definida", file=sys.stderr)
        return 3

    endpoint = f"{apiUrl.rstrip('/')}/admin/catalog/ingest"
    # PyYAML retorna date/datetime; serializa via default=str pra atravessar JSON.
    body = json.dumps(parsed, default=str)
    try:
        resp = httpx.post(
            endpoint,
            content=body,
            headers={"X-Internal-Auth": key, "Content-Type": "application/json"},
            timeout=20.0,
        )
    except httpx.HTTPError as exc:
        print(f"[catalog-publish] ERROR network: {exc}", file=sys.stderr)
        return 2

    if resp.status_code in (200, 201):
        body = resp.json()
        slug = parsed.get("metadata", {}).get("name", "?")
        print(f"[catalog-publish] OK\n  Projeto: {slug}\n  Features upserted: {body.get('features_upserted')}\n  Painel: {apiUrl}/gestao/features.html")
        return 0

    print(f"[catalog-publish] ERROR HTTP {resp.status_code}: {resp.text[:200]}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
