#!/usr/bin/env bash
# Hook pre-commit Percus crud-evidence-warn (R2 / v6.12.0) - Unix. WARN-ONLY.
# Avisa (nunca bloqueia) quando o staged diff de PLANO.md/HANDOFF.md adiciona uma
# feature [5-T] sem o trailer 'CRUD-verified: YYYY-MM-DD' no commit.
# Logica espelha o crud-evidence-warn.ps1 (primario, testado via Pester).
# Skip: PERCUS_SKIP_CRUD_WARN=1. Falha graceful: erro -> exit 0.
set +e
source "$(dirname "$0")/_helpers.sh"

STDIN=$(cat || true)
[[ -z "$STDIN" ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" || -n "$PERCUS_SKIP_CRUD_WARN" ]] && exit 0

command=$(printf '%s' "$STDIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[[ -z "$command" ]] && exit 0
[[ "$command" =~ git[[:space:]]+commit ]] || exit 0
[[ "$command" =~ git[[:space:]]+commit[[:space:]]+--amend[[:space:]]+--no-edit ]] && exit 0

project_root=$(resolve_percus_project_root "$command")
[[ -d "$project_root/.git" ]] || exit 0

PERCUS_COMMAND="$command" python3 - "$project_root" <<'PYEOF'
import sys, os, re, subprocess, datetime
root = sys.argv[1]
command = os.environ.get('PERCUS_COMMAND', '')

def git(args):
    try:
        return subprocess.run(['git', '-C', root] + args, capture_output=True,
                              text=True, encoding='utf-8', errors='replace').stdout
    except Exception:
        return ''

staged = git(['diff', '--cached', '--name-only', '--diff-filter=ACMR']).splitlines()
tracking = [f for f in staged if os.path.basename(f) in ('PLANO.md', 'HANDOFF.md')]
if not tracking:
    sys.exit(0)

def clean(text):
    t = text.strip()
    t = re.sub(r'`?\[[0-9A-Za-z-]+\]`?', '', t)
    for m in ['\U0001F3A8', '\U0001F916', '✓', '✅', '?', '!']:
        t = t.replace(m, '')
    t = re.split(r'\s+(?:—|–|--)\s+', t, 1)[0]
    t = re.sub(r'^[-*]\s+', '', t)
    return re.sub(r'\s+', ' ', t.strip())

hits = []
for f in tracking:
    diff = git(['diff', '--cached', '--', f])
    if not diff:
        continue
    lines = diff.splitlines()
    removed = set()
    for ln in lines:
        if ln.startswith('-') and not ln.startswith('---') and '[5-T]' in ln:
            removed.add(re.sub(r'\s+', ' ', ln[1:].strip()))
    for ln in lines:
        if ln.startswith('+') and not ln.startswith('+++') and '[5-T]' in ln:
            norm = re.sub(r'\s+', ' ', ln[1:].strip())
            if norm in removed:
                continue
            name = clean(ln[1:]) or '(feature sem nome legivel)'
            hits.append((f, name))

if not hits:
    sys.exit(0)
if re.search(r'CRUD-verified:\s*\d{4}-\d{2}-\d{2}', command):
    sys.exit(0)

sys.stderr.write("[percus:warn crud-evidence] feature(s) marcada(s) [5-T] sem trailer 'CRUD-verified: YYYY-MM-DD' neste commit:\n")
logf = None
try:
    os.makedirs(os.path.join(root, '.deepseek'), exist_ok=True)
    logf = open(os.path.join(root, '.deepseek', 'crud-warn.log'), 'a', encoding='utf-8')
except Exception:
    logf = None
ts = datetime.datetime.now().isoformat()
for f, name in hits:
    sys.stderr.write('  - "%s" (%s)\n' % (name, f))
    if logf:
        try:
            logf.write("%s | crud-warn | %s | %s\n" % (ts, f, name))
        except Exception:
            pass
if logf:
    logf.close()
sys.stderr.write("Confirme o ciclo CRUD com F5 (R1) OU adicione o trailer 'CRUD-verified: <data>' no commit.\n")
sys.stderr.write("Silenciar: PERCUS_SKIP_CRUD_WARN=1 (warn-only -- nao bloqueia).\n")
sys.exit(0)
PYEOF
exit $?
