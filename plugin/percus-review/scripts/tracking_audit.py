#!/usr/bin/env python3
"""tracking_audit.py — Auditoria dos 15 campos canonicos de paid media (R2).

Skill: tracking-audit. Decisao Opcao C (hibrido grep + E2E condicional, threshold
explicito) validada por conselho 3-membros
(Painel/.deepseek/council-log/20260516-174848-consult.jsonl).

Spec dos 15 campos: D:\\Claud Automations\\_Novo_Projeto\\03_TRACKING_ATTRIBUITION.md.

Threshold explicito:
    TOTAL >= 80% AND helper_detectado AND migration_ok => PASS
    TOTAL >= 60% mas falha em helper OR migration       => FAIL gap especifico
    TOTAL <  60%                                        => FAIL grave

Uso:
    python tracking_audit.py                          # grep estatico, human output
    python tracking_audit.py --json                   # JSON output (CI)
    python tracking_audit.py --e2e                    # adicional: Playwright runtime
    python tracking_audit.py --e2e --base-url URL     # E2E em URL custom
    python tracking_audit.py --helper-glob "lib/track*.ts"  # override
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional

# Force UTF-8 stdout
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


# Spec canonica dos 15 campos R2
CLICK_IDS = ["fbclid", "gclid", "gbraid", "wbraid", "msclkid", "ttclid"]
META_COOKIES = ["fbp", "fbc"]
UTMS = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term"]
PAGE_CTX = ["referrer", "landing_url"]
ALL_FIELDS = CLICK_IDS + META_COOKIES + UTMS + PAGE_CTX  # 15 total

assert len(ALL_FIELDS) == 15, f"Spec invariant violado: {len(ALL_FIELDS)} != 15"


def _scanFormInputs(projectRoot: Path) -> dict:
    """Camada 1: scan <input name="<field>"> em HTML/JSX/TSX."""
    found: set[str] = set()
    fileExts = ("*.html", "*.htm", "*.jsx", "*.tsx")
    for ext in fileExts:
        for f in projectRoot.rglob(ext):
            # skippar node_modules, .git, dist, build
            if any(part in f.parts for part in ("node_modules", ".git", "dist", "build", ".next")):
                continue
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for field in ALL_FIELDS:
                # match <input name="field"> ou name='field' ou name={`field`}
                pattern = rf'name\s*=\s*[\'"`]?{re.escape(field)}[\'"`]?'
                if re.search(pattern, content):
                    found.add(field)
    return {
        "covered": len(found),
        "total":   15,
        "missing": [f for f in ALL_FIELDS if f not in found],
    }


def _scanHelperLanding(projectRoot: Path, helperGlob: Optional[str] = None) -> dict:
    """Camada 2: helper de captura (URLSearchParams + persistencia)."""
    candidateGlobs = [helperGlob] if helperGlob else [
        "**/lib/tracking*.ts", "**/lib/tracking*.js", "**/lib/track*.ts",
        "**/utils/tracking*.ts", "**/utils/attribution*.ts",
        "**/lib/attribution*.ts", "**/services/tracking*.ts",
        # Backend helpers (Python)
        "**/utm*.py", "**/cookies.py", "**/attribution*.py", "**/tracking*.py",
    ]

    helperFile: Optional[Path] = None
    found: set[str] = set()

    for globPattern in candidateGlobs:
        if not globPattern:
            continue
        for f in projectRoot.glob(globPattern):
            if any(part in f.parts for part in ("node_modules", ".git", "dist", "build")):
                continue
            helperFile = f
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            for field in ALL_FIELDS:
                # helper le campos via URLSearchParams ou cookie read
                pattern = rf'[\'"`]{re.escape(field)}[\'"`]'
                if re.search(pattern, content):
                    found.add(field)
            if helperFile:
                break
        if helperFile:
            break

    return {
        "covered":       len(found),
        "total":         15,
        "missing":       [f for f in ALL_FIELDS if f not in found],
        "detected_file": str(helperFile.relative_to(projectRoot)) if helperFile else None,
    }


def _scanRequestBody(projectRoot: Path) -> dict:
    """Camada 3: campos em request body de POST signup/lead/conversion."""
    found: set[str] = set()
    candidateFile: Optional[Path] = None
    fileExts = ("*.ts", "*.tsx", "*.js", "*.jsx", "*.py")
    endpointPattern = re.compile(r'(signup|lead|conversion|register|track|capi)', re.IGNORECASE)

    for ext in fileExts:
        for f in projectRoot.rglob(ext):
            if any(part in f.parts for part in ("node_modules", ".git", "dist", "build", ".next", "tests", "__pycache__")):
                continue
            if not endpointPattern.search(f.name):
                continue
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            local_found = set()
            for field in ALL_FIELDS:
                # JSON body com field
                pattern = rf'[\'"`]{re.escape(field)}[\'"`]\s*:'
                if re.search(pattern, content):
                    local_found.add(field)
            if local_found and len(local_found) >= len(found):
                found = local_found
                candidateFile = f

    return {
        "covered":       len(found),
        "total":         15,
        "missing":       [f for f in ALL_FIELDS if f not in found],
        "detected_file": str(candidateFile.relative_to(projectRoot)) if candidateFile else None,
    }


def _scanDbMigration(projectRoot: Path) -> dict:
    """Camada 4: colunas em migrations Alembic / SQL."""
    found: set[str] = set()
    candidateFile: Optional[Path] = None
    # Procura migrations em paths comuns (root e subdir como services/api/alembic/)
    migrationGlobs = [
        "alembic/versions",
        "migrations",
        "db/migrations",
        "**/alembic/versions",
        "**/migrations",
    ]
    migrationFiles: list[Path] = []
    seen: set[Path] = set()
    for mglob in migrationGlobs:
        for mdir in projectRoot.glob(mglob):
            if not mdir.is_dir():
                continue
            for f in list(mdir.glob("*.py")) + list(mdir.glob("*.sql")):
                if f in seen:
                    continue
                seen.add(f)
                migrationFiles.append(f)

    for f in migrationFiles:
        if True:  # mantem mesmo nesting do bloco original
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            local_found = set()
            for field in ALL_FIELDS:
                # detecta `Column('field'`, ou ADD COLUMN field, ou 'field' VARCHAR
                pattern = rf"(['\"`]{re.escape(field)}['\"`]|ADD\s+COLUMN\s+{re.escape(field)}\b|\b{re.escape(field)}\s+(VARCHAR|TEXT|CHARACTER))"
                if re.search(pattern, content, re.IGNORECASE):
                    local_found.add(field)
            if local_found and len(local_found) >= len(found):
                found = local_found
                candidateFile = f

    return {
        "covered":       len(found),
        "total":         15,
        "missing":       [f for f in ALL_FIELDS if f not in found],
        "detected_file": str(candidateFile.relative_to(projectRoot)) if candidateFile else None,
    }


def _decideVerdict(layers: dict) -> tuple[str, list[str], float]:
    """Aplica threshold explicito do tracking-audit."""
    # Pontuacao agregada (cada camada vale 25%)
    pct = sum(layer["covered"] / 15.0 for layer in layers.values()) / 4.0 * 100.0
    helper_ok = layers["helper"]["covered"] >= 12  # >=80% do helper detectado
    migration_ok = layers["db"]["covered"] >= 12

    gaps = []
    for layerName, layer in layers.items():
        for missing in layer["missing"]:
            gaps.append(f"{layerName}: {missing}")

    if pct >= 80.0 and helper_ok and migration_ok:
        return "PASS", gaps, pct
    if pct < 60.0:
        return "FAIL_GRAVE", gaps, pct
    return "FAIL", gaps, pct


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--e2e", action="store_true", help="Adicional: Playwright runtime")
    parser.add_argument("--base-url", default="http://localhost:3000", help="URL pro E2E (default localhost:3000)")
    parser.add_argument("--helper-glob", help="Glob custom pro helper landing (override)")
    args = parser.parse_args()

    projectRoot = Path.cwd()

    layers = {
        "form":    _scanFormInputs(projectRoot),
        "helper":  _scanHelperLanding(projectRoot, args.helper_glob),
        "request": _scanRequestBody(projectRoot),
        "db":      _scanDbMigration(projectRoot),
    }

    verdict, gaps, pct = _decideVerdict(layers)

    if args.e2e:
        # E2E nao implementado v1 (precisa Playwright + servidor local).
        # MVP: warning + skip.
        print("[tracking-audit] WARN: --e2e nao implementado em v1. Esperar feedback do uso estatico.",
              file=sys.stderr)

    if args.json:
        out = {
            "version":            1,
            "project_cwd":        str(projectRoot),
            "fields_spec":        ALL_FIELDS,
            "layers":             layers,
            "total_coverage_pct": round(pct, 1),
            "verdict":            verdict,
            "gaps":               gaps,
        }
        print(json.dumps(out, indent=2, ensure_ascii=False))
    else:
        print(f"[tracking-audit] projeto: {projectRoot.name}")
        print(f"Spec: 15 campos canonicos R2\n")

        print("Camada 1 — Form/Input (HTML/JSX/TSX)")
        f1 = layers["form"]
        print(f"  Cobertura: {f1['covered']}/15 = {f1['covered']/15*100:.1f}%")
        if f1["missing"]:
            print(f"  Faltantes: {', '.join(f1['missing'])}")

        print("\nCamada 2 — Helper landing (URLSearchParams + storage)")
        f2 = layers["helper"]
        print(f"  Helper detectado: {f2['detected_file'] or 'NENHUM'}")
        print(f"  Cobertura: {f2['covered']}/15 = {f2['covered']/15*100:.1f}%")
        if f2["missing"] and f2["detected_file"]:
            print(f"  Faltantes: {', '.join(f2['missing'])}")

        print("\nCamada 3 — Request body (POST signup/lead/conversion)")
        f3 = layers["request"]
        print(f"  Endpoint detectado: {f3['detected_file'] or 'NENHUM'}")
        print(f"  Cobertura: {f3['covered']}/15 = {f3['covered']/15*100:.1f}%")
        if f3["missing"] and f3["detected_file"]:
            print(f"  Faltantes: {', '.join(f3['missing'])}")

        print("\nCamada 4 — DB migration (colunas em leads/signups/conversions)")
        f4 = layers["db"]
        print(f"  Migration: {f4['detected_file'] or 'NENHUMA'}")
        print(f"  Cobertura: {f4['covered']}/15 = {f4['covered']/15*100:.1f}%")
        if f4["missing"] and f4["detected_file"]:
            print(f"  Faltantes: {', '.join(f4['missing'])}")

        print(f"\nVEREDITO: {verdict} ({pct:.1f}% total)")
        if verdict == "PASS":
            print("  helper OK, migration OK, threshold >=80% atingido.")
        if gaps and len(gaps) <= 8:
            print(f"  Gaps: {', '.join(gaps)}")
        elif gaps:
            print(f"  Gaps: {len(gaps)} totais (use --json pra listar todos)")

    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
