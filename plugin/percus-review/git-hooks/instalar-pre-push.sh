#!/bin/sh
# instalar-pre-push -- planta o hook git nativo pre-push (R20, camada 2) num repo.
#
# Mesmo padrao do /percus-review:install-git-hooks para o pre-commit: respeita core.hooksPath,
# marcadores === PERCUS-MERGED-HOOK BEGIN/END ===, merge hibrido que preserva logica custom, e
# backup .bak antes de tocar em hook existente. Existe como SCRIPT (e nao so como passo do comando
# markdown) porque instalacao de guarda de seguranca tem de ser deterministica e testavel.
#
# Uso:  sh "<plugin>/git-hooks/instalar-pre-push.sh" [<dir do repo>]    (default: cwd)
#
# Modos (hook alvo):
#   NOVO     ausente                       -> template puro
#   GERIDO   tem BEGIN e END               -> troca SO o bloco entre os marcadores (preserva o resto)
#   HIBRIDO  hook custom em sh/bash        -> shebang + bloco Percus + corpo custom (roda DEPOIS)
#   RECUSA   hook custom em outra linguagem (python, node...) -> exit 3, nada muda
# Sempre que o alvo existe e o conteudo muda: copia em <alvo>.bak (ou .bak.<epoch> se ja houver).
# Exit: 0 instalado/ja atualizado | 2 uso/ambiente | 3 recusado.

set -u

REPO="${1:-.}"
AQUI=$(dirname "$0")
TEMPLATE="$AQUI/pre-push.template.sh"

[ -f "$TEMPLATE" ] || { echo "ERRO: template nao achado: $TEMPLATE" >&2; exit 2; }

TOP=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null | tr -d '\r')
[ -n "$TOP" ] || { echo "ERRO: '$REPO' nao e um repositorio git com arvore de trabalho" >&2; exit 2; }

# core.hooksPath efetivo (local > global > system). Relativo e ancorado na raiz do repo (e onde o
# git o resolve ao executar hooks); barra invertida do Windows vira barra.
HOOKS_DIR=$(git -C "$TOP" config --get core.hooksPath 2>/dev/null | tr -d '\r')
if [ -n "$HOOKS_DIR" ]; then
    HOOKS_DIR=$(printf '%s' "$HOOKS_DIR" | tr '\\' '/')
    case "$HOOKS_DIR" in
        /*|[A-Za-z]:/*) : ;;
        *) HOOKS_DIR="$TOP/$HOOKS_DIR" ;;
    esac
else
    COMMON=$(git -C "$TOP" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | tr -d '\r')
    [ -n "$COMMON" ] || { echo "ERRO: nao resolvi o git dir comum de $TOP" >&2; exit 2; }
    HOOKS_DIR="$COMMON/hooks"
fi
mkdir -p "$HOOKS_DIR" || { echo "ERRO: nao consegui criar $HOOKS_DIR" >&2; exit 2; }
TARGET="$HOOKS_DIR/pre-push"
TMP="$TARGET.percus-tmp.$$"
trap 'rm -f "$TMP" "$TMP.bloco" "$TMP.raw"' EXIT

# Template sem CR: o cache do plugin pode chegar com CRLF, e sh com CR no fim da linha quebra.
tr -d '\r' < "$TEMPLATE" > "$TMP" || exit 2
awk '/=== PERCUS-MERGED-HOOK BEGIN ===/{d=1} d{print} /=== PERCUS-MERGED-HOOK END ===/{d=0}' "$TMP" > "$TMP.bloco"
grep -q 'PERCUS-MERGED-HOOK END' "$TMP.bloco" || { echo "ERRO: template sem marcadores BEGIN/END" >&2; exit 2; }

MODO=""
if [ ! -e "$TARGET" ]; then
    MODO="NOVO"
    : # $TMP ja e o template puro
elif grep -q '=== PERCUS-MERGED-HOOK BEGIN ===' "$TARGET" && grep -q '=== PERCUS-MERGED-HOOK END ===' "$TARGET"; then
    MODO="GERIDO"
    awk -v bloco="$TMP.bloco" '
        /=== PERCUS-MERGED-HOOK BEGIN ===/ && !feito { while ((getline l < bloco) > 0) print l; pulando=1; feito=1; next }
        pulando { if (/=== PERCUS-MERGED-HOOK END ===/) pulando=0; next }
        { print }
    ' "$TARGET" > "$TMP.raw" || exit 2
    tr -d '\r' < "$TMP.raw" > "$TMP" || exit 2
else
    PRIMEIRA=$(sed -n 1p "$TARGET" | tr -d '\r')
    case "$PRIMEIRA" in
        '#!'*)
            case "$PRIMEIRA" in
                */sh|*/sh\ *|*/bash|*/bash\ *|*/dash|*/dash\ *|*\ sh|*\ sh\ *|*\ bash|*\ bash\ *|*\ dash|*\ dash\ *) : ;;
                *) echo "RECUSADO: $TARGET e hook custom em outra linguagem ($PRIMEIRA)." >&2
                   echo "  Merge hibrido so vale para sh/bash. Chame o pre-push Percus de dentro dele, ou mova o custom." >&2
                   exit 3 ;;
            esac
            SHEBANG="$PRIMEIRA"; PULA=1 ;;
        *) SHEBANG="#!/bin/sh"; PULA=0 ;;
    esac
    MODO="HIBRIDO"
    {
        printf '%s\n' "$SHEBANG"
        cat "$TMP.bloco"
        # Corpo preservado sem CR tambem: custom salvo em CRLF viraria then\r/fi\r no sh.
        if [ "$PULA" = 1 ]; then sed 1d "$TARGET" | tr -d '\r'; else tr -d '\r' < "$TARGET"; fi
    } > "$TMP" || exit 2
fi

# Guarda final, qualquer modo: pipe/grupo em sh so reporta o status do ULTIMO comando, entao uma
# etapa que falhou no meio poderia promover hook truncado. Sem os dois marcadores, nada e escrito.
if ! grep -q '=== PERCUS-MERGED-HOOK BEGIN ===' "$TMP" || ! grep -q '=== PERCUS-MERGED-HOOK END ===' "$TMP"; then
    echo "ERRO: hook gerado sem marcadores BEGIN/END (etapa falhou no meio); nada mudou" >&2
    exit 2
fi

if [ -e "$TARGET" ] && cmp -s "$TMP" "$TARGET"; then
    echo "pre-push Percus ja atualizado em $TARGET (nada mudou)"
    exit 0
fi

BAK=""
if [ -e "$TARGET" ]; then
    BAK="$TARGET.bak"
    [ -e "$BAK" ] && BAK="$TARGET.bak.$(date +%s)"
    cp -p "$TARGET" "$BAK" || { echo "ERRO: backup falhou ($BAK); nada mudou" >&2; exit 2; }
fi

mv -f "$TMP" "$TARGET" || { echo "ERRO: nao consegui escrever $TARGET" >&2; exit 2; }
chmod +x "$TARGET" 2>/dev/null || true

echo "pre-push Percus instalado em $TARGET (modo $MODO)"
[ -n "$BAK" ] && echo "  backup do anterior: $BAK"
exit 0
