#!/usr/bin/env bash
# Hook PreToolUse Percus external-action-guard (Layer 1, R20) - Unix.
# STUB FAIL-CLOSED (v6.28.0): espelha SO o contrato minimo do external-action-guard.ps1 --
# bloqueia acao externa publica (git push / gh pr|issue comment|close|merge / slack-cli / mailto:)
# sem PERCUS_EXTERNAL_OVERRIDE=1. NAO reimplementa o check de premise_validity do council-log do .ps1;
# so garante que o Unix FALHE FECHADO em vez de deixar passar silenciosamente (o .ps1 e a versao completa,
# operador roda Windows). Ver nota "Runtime suportado & paridade .sh" em 01_REGRAS_INEGOCIAVEIS.md (R20).
# Skip global: PERCUS_HOOKS_DISABLED=1. Escape declarado: PERCUS_EXTERNAL_OVERRIDE=1.
set +e

STDIN=$(cat || true)
[[ -z "$STDIN" ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" ]] && exit 0

# Extrai o comando do JSON do hook. Fallback sem python3: usa o stdin cru (fail-closed -- ainda casa
# os padroes perigosos abaixo, so nao isola o campo command).
command=$(printf '%s' "$STDIN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)
[[ -z "$command" ]] && command="$STDIN"

# Padroes de acao externa publica (espelham external-action-guard.ps1)
patterns=(
  'gh[[:space:]]+(pr|issue)[[:space:]]+comment'
  'gh[[:space:]]+pr[[:space:]]+(close|merge)'
  'gh[[:space:]]+issue[[:space:]]+close'
  'slack-cli'
  'git[[:space:]]+push'
  'mailto:'
)

is_external=0
for p in "${patterns[@]}"; do
  if [[ "$command" =~ $p ]]; then is_external=1; break; fi
done
[[ "$is_external" -eq 0 ]] && exit 0

# Escape hatch: operador autorizou explicitamente
if [[ "$PERCUS_EXTERNAL_OVERRIDE" == "1" ]]; then
  echo "[percus:hook external-action-guard] PERCUS_EXTERNAL_OVERRIDE setado -- permitindo." >&2
  exit 0
fi

# Default fail-closed: bloqueia acao externa publica sem aprovacao explicita (R20)
{
  echo ""
  echo "[percus:hook external-action-guard] BLOCK (R20):"
  echo "  Comando: $command"
  echo "  Razao: acao externa publica requer aprovacao explicita do operador (R20)"
  echo ""
  echo "  Para autorizar: setar PERCUS_EXTERNAL_OVERRIDE=1 com motivo declarado no commit/log."
  echo "  (Stub Unix fail-closed -- a versao completa com check de council e o .ps1 no Windows.)"
  echo ""
} >&2
exit 2
