#!/bin/sh
# dedup-findings.sh — mirror POSIX do dedup-findings.ps1 (F5 echo dedup)
#
# Recebe pasta com .md de findings (1 arquivo por PR).
# Calcula hash MD5(file_path + primeiros_100_chars_descricao) por finding.
# Agrupa por hash, apresenta "1 finding unico, presente em N PRs".
#
# Output: JSON estruturado em stdout.
# Exit codes: 0 = ok, 1 = erro critico
#
# Usage:
#   bash dedup-findings.sh --findings-dir /path/to/pr-stack-reviews

set -u

# === Parse args ===
FINDINGS_DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --findings-dir|-FindingsDir)
            FINDINGS_DIR="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# === Empty response helper ===
empty_json() {
    printf '{"total_raw":0,"total_unique":0,"duplicates_collapsed":0,"groups":[],"consolidated_md":""}\n'
}

# === Validate dir ===
if [ -z "$FINDINGS_DIR" ] || [ ! -d "$FINDINGS_DIR" ]; then
    empty_json
    exit 0
fi

# === Check for .md files ===
MD_COUNT=$(find "$FINDINGS_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$MD_COUNT" = "0" ]; then
    empty_json
    exit 0
fi

# === Check python3 available ===
if ! command -v python3 >/dev/null 2>&1; then
    printf '{"error":"python3 nao encontrado — instale python3 pra usar dedup-findings.sh"}\n' >&2
    exit 1
fi

# === Main logic via Python3 inline ===
python3 - "$FINDINGS_DIR" <<'PYEOF'
import sys
import re
import json
import os
import hashlib
from pathlib import Path

findings_dir = sys.argv[1]

md_files = sorted(Path(findings_dir).glob("*.md"))
if not md_files:
    result = {"total_raw": 0, "total_unique": 0, "duplicates_collapsed": 0, "groups": [], "consolidated_md": ""}
    print(json.dumps(result))
    sys.exit(0)

# Pattern: bloco [SEV: risco|bug|preferencia] ate proximo [SEV: ou fim
BLOCK_PATTERN = re.compile(
    r'(\[SEV:\s*(risco|bug|prefer[eê]nci[ao])\][^\[]*?)(?=\[SEV:|$)',
    re.DOTALL
)
FILE_PATH_PATTERN = re.compile(
    r'(?:^|\s|`|")([A-Za-z0-9_./-]+\.[A-Za-z]{1,5}(?::\d+(?:-\d+)?)?)'
)
SEV_TAG_PATTERN = re.compile(r'^\[SEV:[^\]]+\]\s*')

all_findings = []

for md_file in md_files:
    source_name = md_file.stem
    try:
        content = md_file.read_text(encoding="utf-8")
    except Exception:
        continue

    for m in BLOCK_PATTERN.finditer(content):
        block = m.group(1).strip()
        sev   = m.group(2).strip()

        if not block:
            continue

        # Extract file_path
        file_path = ""
        fp_m = FILE_PATH_PATTERN.search(block)
        if fp_m:
            file_path = fp_m.group(1).strip().strip('`"')

        # Hash: file_path + primeiros 100 chars da descricao sem tag [SEV:]
        desc_raw   = SEV_TAG_PATTERN.sub("", block).strip()
        desc_slice = desc_raw[:100]
        hash_input = f"{file_path}|{desc_slice}"
        h = hashlib.md5(hash_input.encode("utf-8")).hexdigest()

        all_findings.append({
            "hash":        h,
            "severity":    sev,
            "file_path":   file_path,
            "description": block,
            "source":      source_name,
        })

# Group by hash
groups_map = {}
for f in all_findings:
    h = f["hash"]
    if h not in groups_map:
        groups_map[h] = {"hash": h, "severity": f["severity"], "file_path": f["file_path"],
                         "description": f["description"], "occurrences": 0, "sources": [], "_seen_sources": set()}
    groups_map[h]["occurrences"] += 1
    if f["source"] not in groups_map[h]["_seen_sources"]:
        groups_map[h]["_seen_sources"].add(f["source"])
        groups_map[h]["sources"].append(f["source"])

# Sort: most occurrences first, then severity
groups = sorted(groups_map.values(), key=lambda g: (-g["occurrences"], g["severity"]))

# Clean internal field
for g in groups:
    del g["_seen_sources"]
    g["sources"] = sorted(g["sources"])

# Build consolidated_md
md_lines = ["## Findings consolidados (deduplicados v6.7.0+)\n"]
for g in groups:
    md_lines.append(f"### [SEV: {g['severity']}] {g['file_path']}")
    if g["occurrences"] > 1:
        sources_str = ", ".join(g["sources"])
        md_lines.append(f"\n> **Mesmo finding presente em {g['occurrences']} PRs:** {sources_str}\n")
    md_lines.append(g["description"])
    md_lines.append("\n---\n")

consolidated_md = "\n".join(md_lines)

result = {
    "total_raw":            len(all_findings),
    "total_unique":         len(groups),
    "duplicates_collapsed": len(all_findings) - len(groups),
    "groups":               groups,
    "consolidated_md":      consolidated_md,
}
print(json.dumps(result))
PYEOF
