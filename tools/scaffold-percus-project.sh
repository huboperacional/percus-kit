#!/usr/bin/env bash
# Scaffold Percus auth pattern em projeto Next.js/FastAPI. Idempotente. NAO acessa auth-service.
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --project-path <path> --audience-fallback <slug> [--force]

  --project-path        Path absoluto do projeto target
  --audience-fallback   Slug kebab-case (ex: plexco-coach)
  --force               Sobrescreve arquivos existentes
EOF
  exit "${1:-0}"
}

PROJECT_PATH=""
AUDIENCE=""
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-path) PROJECT_PATH="$2"; shift 2 ;;
    --audience-fallback) AUDIENCE="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown: $1"; usage 1 ;;
  esac
done

[[ -z "$PROJECT_PATH" || -z "$AUDIENCE" ]] && usage 1

if ! [[ "$AUDIENCE" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "X audience '$AUDIENCE' nao e kebab-case (R7)." >&2
  exit 1
fi

CANON_ROOT="${PERCUS_CANON_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
TEMPLATES="$CANON_ROOT/templates/login-ui"
[[ -d "$TEMPLATES" ]] || { echo "X templates/login-ui nao encontrado em $TEMPLATES"; exit 1; }
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

echo "[scaffold] canon:   $CANON_ROOT"
echo "[scaffold] target:  $PROJECT_PATH"
echo "[scaffold] audience: $AUDIENCE"

copy_if_needed() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" && $FORCE -eq 0 ]]; then
    if cmp -s "$src" "$dst"; then
      echo "  [skip] $dst (identico)"
      return
    fi
    echo "  [diff] $dst difere. Use --force."
    return
  fi
  cp "$src" "$dst"
  echo "  [copy] $dst"
}

if [[ -f "$PROJECT_PATH/package.json" ]]; then
  echo "[scaffold] tipo: Next.js"
  for f in "$TEMPLATES/components/"*; do
    copy_if_needed "$f" "$PROJECT_PATH/src/components/auth/$(basename "$f")"
  done
  copy_if_needed "$TEMPLATES/lib/phone-mask.ts" "$PROJECT_PATH/src/lib/phone-mask.ts"

  declare -A api_map=(
    [request.ts.template]="src/app/api/auth/request/route.ts"
    [validate.ts.template]="src/app/api/auth/validate/route.ts"
    [refresh.ts.template]="src/app/api/auth/refresh/route.ts"
    [logout.ts.template]="src/app/api/auth/logout/route.ts"
    [me.ts.template]="src/app/api/auth/me/route.ts"
  )
  for k in "${!api_map[@]}"; do
    copy_if_needed "$TEMPLATES/api/$k" "$PROJECT_PATH/${api_map[$k]}"
  done

  ENV_FILE="$PROJECT_PATH/.env.local"
  if [[ ! -f "$ENV_FILE" || $FORCE -eq 1 ]]; then
    sed -e "s|PERCUS_AUTH_AUDIENCE_FALLBACK=.*|PERCUS_AUTH_AUDIENCE_FALLBACK=$AUDIENCE|" \
        -e "s|NEXT_PUBLIC_PERCUS_AUDIENCE_FALLBACK=.*|NEXT_PUBLIC_PERCUS_AUDIENCE_FALLBACK=$AUDIENCE|" \
        "$TEMPLATES/.env.example" > "$ENV_FILE"
    echo "  [create] .env.local"
  fi

  (cd "$PROJECT_PATH" && npm install percus-auth@^0.4.0 || echo "  [warn] npm install falhou (ok se lib nao publicada ainda)")
elif [[ -f "$PROJECT_PATH/pyproject.toml" ]]; then
  echo "[scaffold] tipo: FastAPI"
  (cd "$PROJECT_PATH" && pip install "percus-auth>=0.4.0" || echo "  [warn] pip install falhou")
  ENV_FILE="$PROJECT_PATH/.env"
  if [[ ! -f "$ENV_FILE" || $FORCE -eq 1 ]]; then
    cat > "$ENV_FILE" <<EOF
AUTH_SERVICE_URL=https://auth.huboperacional.com.br
PERCUS_AUTH_AUDIENCE=$AUDIENCE
# INTERNAL_AUTH_KEY=<32B hex — set if this service calls /internal/* on auth-service>
EOF
    echo "  [create] .env"
  fi
else
  echo "X $PROJECT_PATH nao tem package.json nem pyproject.toml" >&2
  exit 1
fi

# CHECKLIST_AUTH.md
CHECKLIST_T="$CANON_ROOT/templates/CHECKLIST_AUTH.template.md"
if [[ -f "$CHECKLIST_T" ]]; then
  sed "s/{{AUDIENCE}}/$AUDIENCE/g" "$CHECKLIST_T" > "$PROJECT_PATH/CHECKLIST_AUTH.md"
  echo "  [create] CHECKLIST_AUTH.md"
fi

echo ""
echo "[scaffold] OK. Proximos passos manuais (ver CHECKLIST_AUTH.md):"
echo "  1. Criar audience '$AUDIENCE' em https://auth.huboperacional.com.br/admin/audiences/new"
echo "  2. Subir branding em /admin/audiences/$AUDIENCE/branding"
echo "  3. Smoke E2E: dev server + fluxo OTP"
