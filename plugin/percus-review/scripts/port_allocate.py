#!/usr/bin/env python3
"""port_allocate.py — Aloca PERCUS_PORT_BASE consultando o Painel (canon v6.10.0).

Source of truth: Painel `POST /admin/projects/port-allocate` (endpoint idempotente).
VIVO em prod desde 2026-05-26.
Cache local: <projeto>/.percus-ports.json (versionado em git).
Fallback offline (excecao): hash(slug) % 350 -> 3000 + hash*20, marcado unverified=true.
Bloco de 20 portas / range global 3000-9999 desde v6.10.0 (era 10 / 3100-4099).

Manual operacional: Painel Gestao e Afiliados/docs/PORT_ALLOCATION_CONSUMER_GUIDE.md.

Uso:
    python port_allocate.py --slug <slug> [--name <Nome Bonito>]
    python port_allocate.py                # auto-detecta slug (basename do cwd)

Env vars consumidas (do .env do projeto OU env do processo):
    PAINEL_API_URL       default: https://api.ads4pros.com
    CATALOG_INGEST_KEY   obrigatorio (ou METRICS_INGEST_KEY como fallback)

Exit codes:
    0   sucesso (port_base alocado/recuperado, .percus-ports.json escrito)
    1   erro de argumentos / parse de cache
    2   erro de network -> usa fallback offline (ainda exit 0)
    3   credencial faltando -> usa fallback offline (ainda exit 0)
    4   range exausto no Painel
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

try:
    import httpx
except ImportError:
    print("[port-allocate] ERROR: httpx nao instalado. Rode: pip install httpx", file=sys.stderr)
    sys.exit(1)


RANGE_START = 3000
RANGE_END = 9980  # ultimo port_base valido; range_end = 9999
BLOCK_SIZE = 20
CACHE_FILE = ".percus-ports.json"


def _loadDotenv(path: Path) -> dict[str, str]:
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


def _resolveAuth() -> tuple[str, Optional[str]]:
    dotenv = _loadDotenv(Path(".env"))
    apiUrl = (
        os.getenv("PAINEL_API_URL")
        or dotenv.get("PAINEL_API_URL")
        or "https://api.ads4pros.com"
    )
    key = (
        os.getenv("CATALOG_INGEST_KEY")
        or dotenv.get("CATALOG_INGEST_KEY")
        or os.getenv("METRICS_INGEST_KEY")
        or dotenv.get("METRICS_INGEST_KEY")
    )
    return apiUrl, key


def _deterministicFallback(slug: str) -> int:
    """Hash do slug % numBlocks -> bloco em [RANGE_START, RANGE_END]. Determinismo:
    sempre o mesmo slug cai no mesmo port_base offline. Colisao possivel;
    reconcile com Painel quando voltar online detecta e re-aloca."""
    h = hashlib.sha256(slug.encode("utf-8")).hexdigest()
    numBlocks = (RANGE_END - RANGE_START) // BLOCK_SIZE + 1
    blockIdx = int(h[:8], 16) % numBlocks
    return RANGE_START + blockIdx * BLOCK_SIZE


def _writeCache(payload: dict) -> None:
    Path(CACHE_FILE).write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def _readCache() -> Optional[dict]:
    p = Path(CACHE_FILE)
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def _autoSlug() -> str:
    """Slug = basename do cwd, lowercase + hyphens."""
    name = Path.cwd().name.lower()
    # Substitui caracteres non-slug por hyphen, colapsa multi-hyphen.
    cleaned = "".join(c if c.isalnum() or c == "-" else "-" for c in name)
    while "--" in cleaned:
        cleaned = cleaned.replace("--", "-")
    return cleaned.strip("-") or "unnamed-project"


def _emitOutput(payload: dict) -> None:
    """Escreve cache, ecoa PERCUS_PORT_BASE pra stdout consumido por scaffold."""
    _writeCache(payload)
    print(f"PERCUS_PORT_BASE={payload['port_base']}")
    if payload.get("unverified"):
        print(
            f"[port-allocate] WARN: fallback offline em uso (Painel inacessivel). "
            f"port_base={payload['port_base']} marcado unverified=true. "
            "Re-rode quando Painel voltar pra reconciliar.",
            file=sys.stderr,
        )
    else:
        print(
            f"[port-allocate] OK slug={payload['slug']} port_base={payload['port_base']} "
            f"range={payload['port_base']}..{payload['range_end']} kind={payload.get('kind', 'cached')}",
            file=sys.stderr,
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Aloca PERCUS_PORT_BASE via Painel")
    parser.add_argument("--slug", help="Slug do projeto (default: basename do cwd)")
    parser.add_argument("--name", help="Nome bonito (necessario se projeto novo)")
    parser.add_argument("--force", action="store_true", help="Ignora cache local")
    args = parser.parse_args()

    slug = args.slug or _autoSlug()

    # 1. Cache hit confirmado (verified) — short-circuit.
    cache = _readCache() if not args.force else None
    if cache and cache.get("slug") == slug and not cache.get("unverified") and cache.get("port_base"):
        _emitOutput({**cache, "kind": "cached"})
        return 0

    # 2. Tenta Painel.
    apiUrl, key = _resolveAuth()
    if not key:
        # Sem credencial — cai pro fallback determinístico direto.
        port = _deterministicFallback(slug)
        _emitOutput({
            "slug": slug,
            "port_base": port,
            "range_end": port + BLOCK_SIZE - 1,
            "allocated_at": datetime.now(timezone.utc).isoformat(),
            "unverified": True,
            "kind": "fallback-no-credential",
        })
        return 0

    endpoint = f"{apiUrl.rstrip('/')}/admin/projects/port-allocate"
    body = {"slug": slug}
    if args.name:
        body["name"] = args.name

    try:
        resp = httpx.post(
            endpoint,
            json=body,
            headers={"X-Internal-Auth": key, "Content-Type": "application/json"},
            timeout=15.0,
        )
    except httpx.HTTPError as exc:
        # Fallback offline.
        port = _deterministicFallback(slug)
        _emitOutput({
            "slug": slug,
            "port_base": port,
            "range_end": port + BLOCK_SIZE - 1,
            "allocated_at": datetime.now(timezone.utc).isoformat(),
            "unverified": True,
            "kind": "fallback-network-error",
            "error": str(exc),
        })
        return 0

    if resp.status_code == 200:
        data = resp.json()
        _emitOutput({
            "slug": data["slug"],
            "port_base": data["port_base"],
            "range_end": data["range_end"],
            "allocated_at": data.get("allocated_at") or datetime.now(timezone.utc).isoformat(),
            "unverified": False,
            "kind": data.get("kind", "painel-allocated"),
        })
        return 0

    if resp.status_code == 400 and "name not provided" in resp.text:
        print(
            f"[port-allocate] ERROR: projeto slug='{slug}' nao existe no Painel. "
            "Re-rode com --name 'Nome Bonito' pra auto-criar.",
            file=sys.stderr,
        )
        return 1

    print(
        f"[port-allocate] ERROR HTTP {resp.status_code} do Painel: {resp.text[:200]}",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
