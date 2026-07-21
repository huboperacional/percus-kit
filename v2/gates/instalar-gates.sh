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
  echo "  ex.: export PERCUS_CANON_V2_DIR='/d/Claud Automations/_Novo_Projeto/v2'" >&2
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

# Fallback do caminho do canon: grava num arquivo do .git (nao versionado). A env
# var PERCUS_CANON_V2_DIR nao propaga pra shells ja abertos -> sem isto o
# fail-closed do gate travava commit legitimo. O hook le a env var OU este arquivo.
printf '%s\n' "$V2DIR" > "$GITDIR/percus-v2-dir"

# IDEMPOTENTE E AUTO-CURA (2026-07-21, 2o achado de sessao fria): re-rodar sempre
# reconstroi o bloco atual. Antes so pulava "se ja instalado" -- entao hook com
# bloco ANTIGO (que so lia a env var, sem o fallback .git/percus-v2-dir) ficava
# fail-closed TRAVADO num shell sem a env var. Agora remove o bloco velho e planta
# o novo, e o mesmo comando conserta instalacao antiga.
if [ -f "$HOOK" ]; then
  echo "Hook pre-commit ja existe. Preservando o resto e (re)plantando o gate V2."
  cp "$HOOK" "$HOOK.bak-percus"
  # 1) remove qualquer bloco percus-v2-gate ja presente (marcador a marcador).
  awk '
    /# --- percus-v2-gate ---/ { skip=1 }
    !skip { print }
    /# --- fim percus-v2-gate ---/ { skip=0 }
  ' "$HOOK" > "$HOOK.tmp" && mv "$HOOK.tmp" "$HOOK"
  # 2) remove um 'exit 0' que seja a ULTIMA linha nao-vazia -- o hook R11 do
  #    percus-review termina nele no sucesso, e o gate anexado depois viraria
  #    dead code (1o achado). Sem isto o gate instala e nunca roda no commit.
  awk '
    { l[NR]=$0 }
    END {
      last=NR; while (last>0 && l[last] ~ /^[[:space:]]*$/) last--
      skip=(l[last] ~ /^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/)?last:0
      for (i=1;i<=NR;i++) if (i!=skip) print l[i]
    }
  ' "$HOOK" > "$HOOK.tmp" && mv "$HOOK.tmp" "$HOOK"
else
  printf '#!/bin/sh\nset -e\n' > "$HOOK"
fi

cat >> "$HOOK" <<HOOKEOF

$MARCA
# Tetos do canon V2. Escape: PERCUS_GATE_OVERSIZE="motivo" git commit ...
# FAIL-CLOSED: gate instalado que nao consegue rodar BLOQUEIA. Le a env var OU o
# caminho gravado na instalacao (.git/percus-v2-dir) -- a env var nao propaga pra
# shells ja abertos, entao sem o fallback o fail-closed travaria commit legitimo.
PV2="\${PERCUS_CANON_V2_DIR:-}"
if [ -z "\$PV2" ]; then
  _gd=\$(git rev-parse --git-dir 2>/dev/null)
  [ -n "\$_gd" ] && [ -f "\$_gd/percus-v2-dir" ] && PV2=\$(cat "\$_gd/percus-v2-dir")
fi
if [ -z "\$PV2" ]; then
  echo "PERCUS: gate V2 sem caminho do canon (env var e .git/percus-v2-dir ausentes)." >&2
  echo "  Reinstale o gate, ou escape uma vez: PERCUS_HOOKS_DISABLED=1 git commit ..." >&2
  exit 1
fi
if [ ! -f "\$PV2/gates/percus-gate.sh" ]; then
  echo "PERCUS: gate V2 nao achado em \$PV2/gates/ -- caminho errado?" >&2
  exit 1
fi
[ "\${PERCUS_HOOKS_DISABLED:-}" = "1" ] || sh "\$PV2/gates/percus-gate.sh" || exit 1
# --- fim percus-v2-gate ---
HOOKEOF

chmod +x "$HOOK" 2>/dev/null || true

echo "Gate V2 instalado em $HOOK (fallback de caminho em $GITDIR/percus-v2-dir)"
echo "Teste real (atraves do hook):  sh \"$HOOK\"; echo \$?"
