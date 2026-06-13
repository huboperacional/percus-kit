#!/usr/bin/env python3
"""security_audit.py — Runner declarativo de checklist YAML (Percus Fase 6 v6.2.0+).

Skills: security-audit (R14-R19), auth-consumer (IDENTITY/MAGIC/BRIDGE/EARLY202).
Decisao de formato (Opcao D) validada por conselho 3-membros
(Painel/.deepseek/council-log/20260516-175328-consult.jsonl).

Schema: cada item = {id, eixo, desc, check{type,pattern,paths}, fail_msg, fix_hint, severity}
Suporta apenas check.type=grep no v1.

Uso:
    python security_audit.py                                   # checklist default + human output
    python security_audit.py --json                            # JSON pra CI
    python security_audit.py --min-severity high               # filtra por severidade
    python security_audit.py --eixo R15                        # filtra por eixo
    python security_audit.py --checklist path.yaml             # checklist custom
    python security_audit.py --checklist path.yaml --label foo # label customizado no output
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional

try:
    import yaml
except ImportError:
    print("[security-audit] ERROR: pyyaml ausente. Rode: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

try:
    import jsonschema
    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False


SEVERITY_ORDER = {"low": 0, "medium": 1, "high": 2, "critical": 3}
ALLOWED_CHECK_TYPES = {"grep"}

ITEM_SCHEMA = {
    "type": "object",
    "required": ["id", "eixo", "desc", "check", "fail_msg", "severity"],
    "properties": {
        "id":        {"type": "string", "pattern": r"^[A-Z0-9][-A-Za-z0-9]+$"},
        "eixo":      {"type": "string", "pattern": r"^[A-Z][A-Z0-9]*$"},
        "desc":      {"type": "string", "minLength": 5},
        "check": {
            "type": "object",
            "required": ["type", "pattern", "paths"],
            "properties": {
                "type":    {"type": "string", "enum": list(ALLOWED_CHECK_TYPES)},
                "pattern": {"type": "string", "minLength": 1},
                "paths":   {"type": "array", "items": {"type": "string"}, "minItems": 1},
                "expect":  {"type": "string", "enum": ["present", "absent"]},
            },
            "additionalProperties": False,
        },
        "fail_msg":  {"type": "string", "minLength": 5},
        "fix_hint":  {"type": "string"},
        "severity":  {"type": "string", "enum": list(SEVERITY_ORDER.keys())},
    },
    "additionalProperties": False,
}


def _findDefaultChecklist() -> Path:
    """Resolve checklist.yaml default: skills/security-audit/checklist.yaml ao lado deste script."""
    scriptDir = Path(__file__).parent
    pluginRoot = scriptDir.parent
    return pluginRoot / "skills" / "security-audit" / "checklist.yaml"


def _validateItem(item: dict, index: int) -> Optional[str]:
    """Retorna msg de erro OR None se valido."""
    if not HAS_JSONSCHEMA:
        # Validacao manual minima
        for k in ("id", "eixo", "desc", "check", "fail_msg", "severity"):
            if k not in item:
                return f"item[{index}]: chave obrigatoria '{k}' ausente"
        check = item["check"]
        for k in ("type", "pattern", "paths"):
            if k not in check:
                return f"item[{index}].check: chave '{k}' ausente"
        if check["type"] not in ALLOWED_CHECK_TYPES:
            return f"item[{index}].check.type='{check['type']}' nao suportado (allowed: {ALLOWED_CHECK_TYPES})"
        if item["severity"] not in SEVERITY_ORDER:
            return f"item[{index}].severity='{item['severity']}' invalido"
        # Valida formato id e eixo manualmente
        import re as _re
        if not _re.match(r'^[A-Z0-9][-A-Za-z0-9]+$', item["id"]):
            return f"item[{index}].id='{item['id']}' invalido (esperado: ^[A-Z0-9][-A-Za-z0-9]+$)"
        if not _re.match(r'^[A-Z][A-Z0-9]*$', item["eixo"]):
            return f"item[{index}].eixo='{item['eixo']}' invalido (esperado: ^[A-Z][A-Z0-9]*$)"
        # Detecta chaves desconhecidas (schema drift)
        knownKeys = {"id", "eixo", "desc", "check", "fail_msg", "fix_hint", "severity"}
        unknown = set(item.keys()) - knownKeys
        if unknown:
            return f"item[{index}]: chaves desconhecidas {unknown} (schema drift). Atualize runner ou remova."
        # check sub-keys
        knownCheckKeys = {"type", "pattern", "paths", "expect"}
        unknownCheck = set(check.keys()) - knownCheckKeys
        if unknownCheck:
            return f"item[{index}].check: chaves desconhecidas {unknownCheck} (schema drift)."
        if "expect" in check and check["expect"] not in ("present", "absent"):
            return f"item[{index}].check.expect='{check['expect']}' invalido (allowed: present|absent)"
        return None

    try:
        jsonschema.validate(item, ITEM_SCHEMA)
        return None
    except jsonschema.ValidationError as e:
        return f"item[{index}]: {e.message}"


def _runGrepCheck(check: dict, projectRoot: Path) -> tuple[bool, int]:
    """Executa check.type=grep. Retorna (foundMatch, pathsScanned)."""
    pattern = re.compile(check["pattern"], re.IGNORECASE | re.MULTILINE)
    pathsScanned = 0

    for globPattern in check["paths"]:
        # pathlib glob: prefixar com '**/' se nao tem
        if not globPattern.startswith("**"):
            files = list(projectRoot.glob(globPattern))
        else:
            files = list(projectRoot.glob(globPattern))

        for f in files:
            if not f.is_file():
                continue
            pathsScanned += 1
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            if pattern.search(content):
                return True, pathsScanned

    return False, pathsScanned


# Force UTF-8 stdout (Windows console default cp1252 quebra com unicode marks)
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--checklist", type=Path, help="Path do checklist.yaml (default: bundled)")
    parser.add_argument("--label", help="Label no output (default: 'security-audit')")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--min-severity", choices=list(SEVERITY_ORDER.keys()), help="Filtra items >= severity")
    parser.add_argument("--eixo", help="Filtra so este eixo (ex: R15, IDENTITY)")
    args = parser.parse_args()

    runLabel = args.label or "security-audit"
    checklistPath = args.checklist or _findDefaultChecklist()
    if not checklistPath.exists():
        print(f"[security-audit] ERROR: checklist nao encontrado: {checklistPath}", file=sys.stderr)
        return 2

    try:
        items = yaml.safe_load(checklistPath.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        print(f"[security-audit] ERROR: YAML invalido: {e}", file=sys.stderr)
        return 2

    if not isinstance(items, list):
        print(f"[security-audit] ERROR: checklist.yaml deve ser lista, recebeu {type(items).__name__}", file=sys.stderr)
        return 2

    # Filtrar items que sao dicts (skippar version: 1 standalone)
    items = [i for i in items if isinstance(i, dict)]

    # Validar schema
    for idx, item in enumerate(items):
        err = _validateItem(item, idx)
        if err:
            print(f"[security-audit] ERROR schema: {err}", file=sys.stderr)
            return 2

    # Filtros CLI
    if args.eixo:
        items = [i for i in items if i["eixo"] == args.eixo]
    if args.min_severity:
        minLevel = SEVERITY_ORDER[args.min_severity]
        items = [i for i in items if SEVERITY_ORDER[i["severity"]] >= minLevel]

    projectRoot = Path.cwd()
    results = []
    for item in items:
        found, pathsScanned = _runGrepCheck(item["check"], projectRoot)
        # expect default = present. absent = quero que NAO encontre (security negative check).
        expect = item["check"].get("expect", "present")
        if expect == "present":
            status = "PASS" if found else "FAIL"
        else:  # absent
            status = "PASS" if not found else "FAIL"
        results.append({
            "id":            item["id"],
            "eixo":          item["eixo"],
            "desc":          item["desc"],
            "status":        status,
            "severity":      item["severity"],
            "paths_scanned": pathsScanned,
            "fail_msg":      item["fail_msg"] if status == "FAIL" else None,
            "fix_hint":      item.get("fix_hint") if status == "FAIL" else None,
        })

    summary = {
        "total":        len(results),
        "pass":         sum(1 for r in results if r["status"] == "PASS"),
        "fail":         sum(1 for r in results if r["status"] == "FAIL"),
        "by_severity": {
            sev: sum(1 for r in results if r["status"] == "FAIL" and r["severity"] == sev)
            for sev in SEVERITY_ORDER
        },
    }

    if args.json:
        out = {
            "version":        1,
            "label":          runLabel,
            "checklist_path": str(checklistPath),
            "project_cwd":    str(projectRoot),
            "summary":        summary,
            "items":          results,
        }
        print(json.dumps(out, indent=2, ensure_ascii=False))
    else:
        print(f"[{runLabel}] checklist v1, {summary['total']} items, projeto: {projectRoot.name}\n")
        currentEixo = None
        for r in results:
            if r["eixo"] != currentEixo:
                currentEixo = r["eixo"]
                print(f"\n{currentEixo}")
            mark = "✓" if r["status"] == "PASS" else "✗"
            sevDisplay = f" {r['severity']}" if r["status"] == "FAIL" else ""
            print(f"  {mark} {r['id']} ({r['status']}{sevDisplay})")
            if r["status"] == "FAIL":
                print(f"    {r['fail_msg']}")
                if r["fix_hint"]:
                    print(f"    fix: {r['fix_hint']}")

        sevCount = summary["by_severity"]
        sevStr = ", ".join(f"{n} {s}" for s, n in sevCount.items() if n > 0) or "0"
        print(f"\n[{runLabel}] RESUMO: {summary['total']} items, {summary['pass']} PASS, {summary['fail']} FAIL ({sevStr})")

    return 0 if summary["fail"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
