#!/bin/sh
# instalar-gates -- planta o gate do V2 no projeto alvo.
#
# Por que existe: o republish do plugin foi descartado, entao gate novo nao chega
# aos projetos por la. Este instalador escreve um git hook nativo, self-contained,
# dentro do projeto -- zero dependencia de publicacao.
#
# Uso (a partir da raiz do projeto alvo):
#   sh "$PERCUS_CANON_V2_DIR/gates/instalar-gates.sh"

set -u

MARCA="# --- percus-v2-gate ---"
V2DIR="${PERCUS_CANON_V2_DIR:-}"

if [ -z "$V2DIR" ]; then
  echo "ERRO: defina PERCUS_CANON_V2_DIR apontando para a pasta do canon V2." >&2
  echo "  ex.: export PERCUS_CANON_V2_DIR='/d/Claud Automations/_Novo_Projeto_V2'" >&2
  exit 2
fi

if [ ! -f "$V2DIR/gates/percus-gate.sh" ]; then
  echo "ERRO: nao achei $V2DIR/gates/percus-gate.sh" >&2
  exit 2
fi

GITDIR=$(git rev-parse --git-dir 2>/dev/null) || {
  echo "ERRO: rode isto dentro de um repositorio git." >&2
  exit 2
}

HOOK="$GITDIR/hooks/pre-commit"
mkdir -p "$GITDIR/hooks"

# Ja instalado? Nao duplica.
if [ -f "$HOOK" ] && grep -q "$MARCA" "$HOOK" 2>/dev/null; then
  echo "Gate V2 ja estava instalado em $HOOK -- nada a fazer."
  exit 0
fi

# Hook existente de outra origem: preserva e acrescenta (merge hibrido).
if [ -f "$HOOK" ]; then
  echo "Hook pre-commit ja existe. Preservando e acrescentando o gate V2."
  cp "$HOOK" "$HOOK.bak-percus"
else
  printf '#!/bin/sh\nset -e\n' > "$HOOK"
fi

cat >> "$HOOK" <<HOOKEOF

$MARCA
# Tetos do canon V2. Escape: PERCUS_GATE_OVERSIZE="motivo" git commit ...
# FAIL-CLOSED: gate instalado que nao consegue rodar BLOQUEIA (guard fail-closed,
# precedente do canon). Var sumiu = commit para com instrucao, nao passa calado.
if [ -z "\${PERCUS_CANON_V2_DIR:-}" ]; then
  echo "PERCUS: gate V2 instalado mas PERCUS_CANON_V2_DIR nao definida." >&2
  echo "  Defina (setx PERCUS_CANON_V2_DIR \"D:/Claud Automations/_Novo_Projeto/v2\")" >&2
  echo "  ou escape uma vez: PERCUS_HOOKS_DISABLED=1 git commit ..." >&2
  exit 1
fi
if [ ! -f "\$PERCUS_CANON_V2_DIR/gates/percus-gate.sh" ]; then
  echo "PERCUS: gate V2 nao achado em \$PERCUS_CANON_V2_DIR/gates/ -- caminho errado?" >&2
  exit 1
fi
[ "\${PERCUS_HOOKS_DISABLED:-}" = "1" ] || sh "\$PERCUS_CANON_V2_DIR/gates/percus-gate.sh" || exit 1
# --- fim percus-v2-gate ---
HOOKEOF

chmod +x "$HOOK" 2>/dev/null || true

echo "Gate V2 instalado em $HOOK"
echo "Teste:  sh \"\$PERCUS_CANON_V2_DIR/gates/percus-gate.sh\"; echo \$?"
