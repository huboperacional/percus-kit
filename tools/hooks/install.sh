#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
ln -sf "../../tools/hooks/pre-push" "$ROOT/.git/hooks/pre-push"
chmod +x "$ROOT/tools/hooks/pre-push"
echo "OK pre-push hook instalado"
