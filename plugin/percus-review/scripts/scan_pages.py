#!/usr/bin/env python3
"""scan_pages.py — Extrai rotas/paginas do projeto e empurra pro Painel.

Fase 6 / Eixo A. Invocado pela skill `percus-review:pages-scan`.

Detecta:
    FastAPI: @<router>.(get|post|put|delete|patch)("path")
    Next.js App Router: app/**/page.tsx, app/**/route.ts
    Next.js Pages Router: pages/**/*.tsx (exceto _*)
    HTML estatico: static/**/*.html, public/**/*.html

Feature tagging (opcional):
    # feature: <slug>           (Python, acima do decorator)
    // feature: <slug>           (TS/JS, primeiras 10 linhas)
    --- feature: <slug> ---      (HTML, primeiras 20 linhas)

Uso:
    python scan_pages.py                  # le CWD, deriva slug do dir name
    python scan_pages.py --slug <slug>    # slug explicito
    python scan_pages.py --dry-run        # so imprime, nao posta

Env vars (.env do projeto):
    PAINEL_API_URL          default: https://api.ads4pros.com
    CATALOG_INGEST_KEY      ou METRICS_INGEST_KEY fallback
"""
from __future__ import annotations

import os
import re
import sys
import argparse
import json
from pathlib import Path
from typing import Optional

try:
    import httpx
except ImportError:
    print("[pages-scan] ERROR: httpx nao instalado. Rode: pip install httpx", file=sys.stderr)
    sys.exit(1)


FASTAPI_ROUTE_RE = re.compile(
    r"@\w+\.(get|post|put|delete|patch|head|options)\(\s*['\"]([^'\"]+)['\"]",
    re.IGNORECASE,
)
PYTHON_FEATURE_TAG_RE = re.compile(r"^\s*#\s*feature:\s*([\w/-]+)", re.MULTILINE)
TS_FEATURE_TAG_RE = re.compile(r"^\s*//\s*feature:\s*([\w/-]+)", re.MULTILINE)


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


def _extractFastapiRoutes(root: Path) -> list[dict]:
    """Scan FastAPI route definitions across the codebase."""
    apiDirs = [root / "execution" / "api", root / "services" / "api", root / "app" / "api"]
    pages: list[dict] = []
    for apiDir in apiDirs:
        if not apiDir.exists():
            continue
        for pyFile in apiDir.rglob("*.py"):
            try:
                text = pyFile.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            featureMatch = PYTHON_FEATURE_TAG_RE.search(text)
            featureTags = [featureMatch.group(1)] if featureMatch else []
            for m in FASTAPI_ROUTE_RE.finditer(text):
                method = m.group(1).upper()
                route = m.group(2)
                pages.append({
                    "route": route,
                    "kind": "api",
                    "method": method,
                    "file_path": str(pyFile.relative_to(root)).replace("\\", "/"),
                    "title": None,
                    "feature_tags": featureTags,
                })
    return pages


def _nextRouteFromPath(filePath: Path, basePath: Path) -> str:
    """Convert filesystem path to Next.js URL pattern."""
    rel = filePath.relative_to(basePath)
    parts: list[str] = []
    for p in rel.parts[:-1]:  # exclude filename
        if p.startswith("(") and p.endswith(")"):
            continue  # Next.js route groups
        parts.append(p)
    route = "/" + "/".join(parts) if parts else "/"
    return route.rstrip("/") or "/"


def _extractNextAppRoutes(root: Path) -> list[dict]:
    pages: list[dict] = []
    appDir = root / "app"
    if not appDir.exists():
        # Maybe Next.js inside services/web/app
        appDir = root / "services" / "web" / "app"
        if not appDir.exists():
            return pages

    for filename, kind in [("page.tsx", "web"), ("page.jsx", "web"), ("route.ts", "api"), ("route.tsx", "api")]:
        for tsFile in appDir.rglob(filename):
            try:
                text = tsFile.read_text(encoding="utf-8", errors="replace")
            except OSError:
                text = ""
            featureMatch = TS_FEATURE_TAG_RE.search(text[:2000])
            featureTags = [featureMatch.group(1)] if featureMatch else []
            route = _nextRouteFromPath(tsFile, appDir)
            pages.append({
                "route": route,
                "kind": kind,
                "method": "GET" if kind == "web" else None,
                "file_path": str(tsFile.relative_to(root)).replace("\\", "/"),
                "title": None,
                "feature_tags": featureTags,
            })
    return pages


def _extractStaticHtml(root: Path) -> list[dict]:
    pages: list[dict] = []
    for staticDir in [root / "static", root / "public"]:
        if not staticDir.exists():
            continue
        for htmlFile in staticDir.rglob("*.html"):
            try:
                text = htmlFile.read_text(encoding="utf-8", errors="replace")
            except OSError:
                text = ""
            titleMatch = re.search(r"<title>(.*?)</title>", text, re.IGNORECASE | re.DOTALL)
            title = titleMatch.group(1).strip() if titleMatch else None
            relPath = htmlFile.relative_to(staticDir)
            route = "/" + str(relPath).replace("\\", "/").replace("index.html", "").rstrip("/")
            route = route.rstrip("/") or "/"
            pages.append({
                "route": route,
                "kind": "static",
                "method": "GET",
                "file_path": str(htmlFile.relative_to(root)).replace("\\", "/"),
                "title": title,
                "feature_tags": [],
            })
    return pages


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--slug", help="Project slug (default: dir name normalized)")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    root = Path.cwd()
    slug = args.slug or root.name.lower().replace(" ", "-").replace("_", "-")

    pages: list[dict] = []
    pages.extend(_extractFastapiRoutes(root))
    pages.extend(_extractNextAppRoutes(root))
    pages.extend(_extractStaticHtml(root))

    # Dedupe by (route, kind, method)
    seen = set()
    deduped: list[dict] = []
    for p in pages:
        key = (p["route"], p["kind"], p.get("method"))
        if key in seen:
            continue
        seen.add(key)
        deduped.append(p)
    pages = deduped

    counts = {"api": 0, "web": 0, "static": 0}
    for p in pages:
        counts[p["kind"]] = counts.get(p["kind"], 0) + 1

    print(f"[pages-scan] Detectadas {len(pages)} paginas em {slug}: api={counts.get('api',0)}, web={counts.get('web',0)}, static={counts.get('static',0)}")

    if args.dry_run:
        for p in pages[:30]:
            tagsStr = f" tags={p['feature_tags']}" if p["feature_tags"] else ""
            print(f"  [{p['kind']}] {p.get('method') or '-'} {p['route']} -> {p['file_path']}{tagsStr}")
        if len(pages) > 30:
            print(f"  ... e mais {len(pages) - 30}")
        return 0

    # Push pro Painel
    dotenv = _loadDotenv(Path(".env"))
    apiUrl = os.getenv("PAINEL_API_URL") or dotenv.get("PAINEL_API_URL") or "https://api.ads4pros.com"
    key = (
        os.getenv("CATALOG_INGEST_KEY") or dotenv.get("CATALOG_INGEST_KEY")
        or os.getenv("METRICS_INGEST_KEY") or dotenv.get("METRICS_INGEST_KEY")
    )
    if not key:
        print("[pages-scan] ERROR: CATALOG_INGEST_KEY (ou METRICS_INGEST_KEY) nao definida", file=sys.stderr)
        return 3

    endpoint = f"{apiUrl.rstrip('/')}/admin/pages/ingest"
    try:
        resp = httpx.post(
            endpoint,
            json={"project_slug": slug, "pages": pages},
            headers={"X-Internal-Auth": key},
            timeout=30.0,
        )
    except httpx.HTTPError as exc:
        print(f"[pages-scan] ERROR network: {exc}", file=sys.stderr)
        return 2

    if resp.status_code in (200, 201):
        body = resp.json()
        # UI estatica fica em gestao.ads4pros.com (root, sem prefixo /gestao/), API em api.ads4pros.com
        uiUrl = os.getenv("PAINEL_UI_URL") or dotenv.get("PAINEL_UI_URL") or "https://gestao.ads4pros.com"
        print(f"[pages-scan] OK upserted={body.get('pages_upserted')} | Painel: {uiUrl}/projeto-detalhe.html?slug={slug}")
        return 0

    print(f"[pages-scan] ERROR HTTP {resp.status_code}: {resp.text[:200]}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
