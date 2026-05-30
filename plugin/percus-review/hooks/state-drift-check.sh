#!/usr/bin/env bash
# Hook Stop event Percus state-drift-check (R2 / R8 / v6.12.0) - Unix.
# BLOQUEIA (exit 2) se uma feature tem tag divergente entre docs/PLANO.md e
# HANDOFF.md. Conservador: so bloqueia em match confiavel de nome. Logica espelha
# o state-drift-check.ps1 (primario, testado via Pester).
# Skip: PERCUS_SKIP_DRIFT_CHECK=1. Falha graceful: erro -> exit 0.
set +e

STDIN=$(cat || true)
[[ -z "$STDIN" ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" || -n "$PERCUS_SKIP_DRIFT_CHECK" ]] && exit 0

cwd=$(printf '%s' "$STDIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd','') or '')" 2>/dev/null || echo "")
[[ -z "$cwd" || ! -d "$cwd" ]] && cwd="$(pwd)"

python3 - "$cwd" <<'PYEOF'
import sys, os, re
cwd = sys.argv[1]

def find(*cands):
    for c in cands:
        p = os.path.join(cwd, c)
        if os.path.isfile(p):
            return p
    return None

plano = find('docs/PLANO.md', 'PLANO.md')
handoff = find('docs/HANDOFF.md', 'HANDOFF.md')
if not plano or not handoff:
    sys.exit(0)

def clean(text):
    t = text.strip()
    t = re.sub(r'`?\[[0-9A-Za-z-]+\]`?', '', t)
    for m in ['\U0001F3A8', '\U0001F916', '✓', '✅', '?', '!']:
        t = t.replace(m, '')
    t = re.split(r'\s+(?:—|–|--)\s+', t, 1)[0]
    return re.sub(r'\s+', ' ', t.strip())

def tagof(text):
    m = re.search(r'\[([0-9A-Za-z-]+)\]', text)
    return m.group(1) if m else None

def add(d, c, tg):
    if not c or not tg:
        return
    k = c.lower()
    if k == 'feature':
        return
    e = d.setdefault(k, {'disp': c, 'tags': []})
    if tg not in e['tags']:
        e['tags'].append(tg)

def read_lines(p):
    try:
        return open(p, encoding='utf-8', errors='replace').read().splitlines()
    except Exception:
        return []

plano_map = {}
for ln in read_lines(plano):
    m = re.match(r'^\s*[-*]\s+`?\[([0-9A-Za-z-]+)\]`?\s*(.*)$', ln)
    if m:
        add(plano_map, clean(m.group(2)), m.group(1))

handoff_map = {}
insec = False
for ln in read_lines(handoff):
    if re.match(r'^\s*#{1,6}\s', ln):
        insec = bool(re.search(r'(?i)status\s+de\s+features', ln))
        continue
    if not insec:
        continue
    t = ln.strip()
    if not t.startswith('|'):
        continue
    if re.match(r'^\|[\s:\-\|]+$', t):
        continue
    cells = [c.strip() for c in t.strip('|').split('|')]
    if len(cells) < 2:
        continue
    si = -1
    for i, c in enumerate(cells):
        if re.search(r'\[[0-9A-Za-z-]+\]', c):
            si = i
            break
    if si < 1:
        continue
    add(handoff_map, clean(cells[si - 1]), tagof(cells[si]))

drifts = []
for k, e in plano_map.items():
    if k not in handoff_map:
        continue
    pt = e['tags']
    ht = handoff_map[k]['tags']
    if len(pt) != 1 or len(ht) != 1:
        continue
    if pt[0] != ht[0]:
        drifts.append((e['disp'], pt[0], ht[0]))

if not drifts:
    sys.exit(0)

sys.stderr.write("[percus:hook state-drift] BLOCK: PLANO.md e HANDOFF.md divergem no status de %d feature(s):\n" % len(drifts))
for name, pt, ht in drifts:
    sys.stderr.write('  - "%s": [%s] no PLANO vs [%s] no HANDOFF\n' % (name, pt, ht))
sys.stderr.write("Sincronize os dois (fonte da verdade = PLANO.md) antes de encerrar a sessao (R2/R8).\n")
sys.stderr.write("Pular: PERCUS_SKIP_DRIFT_CHECK=1 (declarar motivo em voz alta).\n")
sys.exit(2)
PYEOF
exit $?
