#!/usr/bin/env bash
# Hook pre-commit Percus mock-scan (R3) - Unix.
# Skip explicito: 'MOCK-OK:' em qualquer -m ou no arquivo de -F OU PERCUS_SKIP_MOCK_SCAN=1.

set -eo pipefail
source "$(dirname "$0")/_helpers.sh"

stdin_data=$(cat || true)
[[ -z "$stdin_data" ]] && exit 0

command=$(echo "$stdin_data" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[[ -z "$command" ]] && exit 0

[[ "$command" =~ git[[:space:]]+commit ]] || exit 0
[[ "$command" =~ git[[:space:]]+commit[[:space:]]+--amend[[:space:]]+--no-edit ]] && exit 0
[[ -n "$PERCUS_HOOKS_DISABLED" || -n "$PERCUS_SKIP_MOCK_SCAN" ]] && exit 0

project_root=$(resolve_percus_project_root "$command")

# Escape MOCK-OK: (T10, 2026-09-15) -- paridade com a perna .ps1, que e requisito
# de seguranca: uma perna que libera onde a outra bloqueia e defeito.
# Vale em QUALQUER -m "..."/-m '...' (todas as ocorrencias) ou nas primeiras
# 64 KB do arquivo de -F <arq> / --file=<arq> / --file <arq>. Caminho relativo
# resolve contra resolve_percus_project_root, nunca contra o pwd deste processo.
# `-F -` (stdin), inexistente, diretorio ou ilegivel -> SEM escape.
# `[[ =~ ]]` so pega a 1a ocorrencia: o laco consome o trecho casado e repete.
# Casamento do escape igual ao .ps1 `(?i)\bMOCK-OK:`: sem caixa e com fronteira.
percus_tem_escape() {
    local txt="$1" rc=1
    shopt -s nocasematch
    [[ "$txt" =~ (^|[^[:alnum:]_])MOCK-OK: ]] && rc=0
    shopt -u nocasematch
    return $rc
}

escape=0
re_msg_dq='-m[[:space:]]+"([^"]+)"'
re_msg_sq=$'-m[[:space:]]+\'([^\']+)\''
for re in "$re_msg_dq" "$re_msg_sq"; do
    rest="$command"
    while [[ $escape -eq 0 && "$rest" =~ $re ]]; do
        # Copia ANTES de chamar percus_tem_escape: o `=~` dela sobrescreve o
        # BASH_REMATCH, o resto nao encolhe e o laco nunca termina (medido).
        casado="${BASH_REMATCH[0]}"
        msg="${BASH_REMATCH[1]}"
        rest="${rest#*"$casado"}"
        percus_tem_escape "$msg" && escape=1
    done
done

if [[ $escape -eq 0 ]]; then
    # Grupos: 4 = entre aspas duplas, 5 = entre aspas simples, 6 = token nu.
    re_arq=$'(^|[[:space:]])(-F[[:space:]]+|--file=|--file[[:space:]]+)("([^"]*)"|\'([^\']*)\'|([^[:space:]"\';&|]+))'
    rest="$command"
    while [[ $escape -eq 0 && "$rest" =~ $re_arq ]]; do
        # Idem: copiar o BASH_REMATCH antes de qualquer outro `=~`.
        casado="${BASH_REMATCH[0]}"
        arq="${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
        # O 'x' repoe um caractere nao-espaco no lugar do fim do trecho casado:
        # sem ele o `^` casaria no inicio do resto e aceitaria `-F "a"-F b`, que o
        # .NET (fronteira real do comando) recusa.
        rest="x${rest#*"$casado"}"
        [[ -z "$arq" || "$arq" == "-" ]] && continue
        if [[ ! ( "$arq" == /* || "$arq" == \\* || "$arq" =~ ^[A-Za-z]: ) ]]; then
            arq="$project_root/$arq"
        fi
        [[ -f "$arq" ]] || continue
        # head -c: nunca le o arquivo inteiro para a memoria. Falha de leitura
        # (pipefail) -> sem escape. tr tira NUL, que o bash nao guarda em variavel.
        trecho=$(head -c 65536 -- "$arq" 2>/dev/null | tr -d '\000') && rc_leitura=0 || rc_leitura=$?
        [[ $rc_leitura -eq 0 ]] || continue
        percus_tem_escape "$trecho" && escape=1
    done
fi
[[ $escape -eq 1 ]] && exit 0

[[ -d "$project_root/.git" ]] || exit 0

files=$(get_percus_staged_files "$project_root" .py .ts .tsx .js .jsx .go .rs .java .css .html .vue .svelte .sql)
[[ -z "$files" ]] && exit 0

# 🔴 Descobre um locale em que `grep -P` REALMENTE roda, em vez de assumir um.
#
# Medido em 2026-08-17: no Git Bash do Windows (LANG vazio) o grep recusa `-P`
# com "supports only unibyte and UTF-8 locales" e sai com 2 em TODO padrao --
# o erro ia pro /dev/null, exit != 0 era lido como "nao casou", e esta perna
# inteira estava morta respondendo verde. Nessa maquina `C.UTF-8` resolve e
# `C` NAO; no macOS e em varios containers e o contrario, porque `C.UTF-8` nem
# existe la. Escolher um dos dois no escuro deixa metade das plataformas morta,
# entao a escolha e feita medindo.
# ⚠️ E nao basta sondar locale: o `grep` do macOS e BSD e NAO TEM `-P` de
# jeito nenhum. Sondar so locale faria o hook bloquear TODO commit num Mac,
# que e pior do que o defeito original. Entao a sonda escolhe um MOTOR:
# `grep -P` com o primeiro locale que funcionar, ou `perl` (presente por
# padrao no macOS e em quase todo Unix). Sem nenhum dos dois, fail-closed.
PERCUS_PCRE_MOTOR=""
PERCUS_GREP_LOCALE=""
for cand in "C.UTF-8" "C" "en_US.UTF-8" "$LANG"; do
    [[ -z "$cand" ]] && continue
    echo "x" | LC_ALL="$cand" grep -qP "x" 2>/dev/null && {
        PERCUS_PCRE_MOTOR="grep"; PERCUS_GREP_LOCALE="$cand"; break
    }
done
if [[ -z "$PERCUS_PCRE_MOTOR" ]] && command -v perl >/dev/null 2>&1; then
    echo "x" | perl -ne 'exit(/x/ ? 0 : 1)' 2>/dev/null && PERCUS_PCRE_MOTOR="perl"
fi

# Procura `$re` em `$line`. Devolve 0 = casou, 1 = nao casou, 2 = NAO CONSEGUI
# procurar. Os tres codigos importam: confundir 2 com 1 foi o que manteve este
# hook morto respondendo verde.
percus_casa() {
    local re="$1" line="$2"
    if [[ "$PERCUS_PCRE_MOTOR" == "grep" ]]; then
        # `&& rc=0 || rc=$?` porque com `set -e` uma atribuicao cujo comando
        # sai != 0 mata o script -- e sair 1 ("nao casou") e o caso comum.
        # `printf '%s'` e nao `echo`, igual ao ramo do perl: em shells onde `echo`
        # interpreta opcao, uma linha cujo conteudo e literalmente `-n` ou `-e`
        # entraria VAZIA no grep -- mudando em silencio o que esta sendo testado.
        # Os dois motores tem de receber a mesma entrada, byte a byte.
        PERCUS_MOTOR_ERR=$(printf '%s' "$line" | LC_ALL="$PERCUS_GREP_LOCALE" grep -qiP "$re" 2>&1) && return 0 || return $?
    fi
    # Perl: `(?i)` embutido reproduz o `-i` do grep, e os `(?-i:...)` dos
    # padroes seguem valendo dentro dele. Regex invalida faz o perl morrer com
    # status 255; qualquer coisa fora de 0/1 vira "nao consegui procurar".
    #
    # 🔴 A regex entra por VARIAVEL DE AMBIENTE, nunca interpolada pelo shell
    # dentro de `/.../`. Interpolando, o primeiro `/` do proprio padrao fecha o
    # literal e o perl morre com "syntax error" -- que o codigo 2 traduziria
    # como "nao consegui procurar" e viraria bloqueio em todo commit. Pegou o
    # padrao de URL de localhost, que tem tres barras. Medido 2026-08-17.
    local rc=0
    PERCUS_MOTOR_ERR=$(printf '%s' "$line" | PERCUS_RE="$re" perl -ne 'exit($_ =~ /(?i)$ENV{PERCUS_RE}/ ? 0 : 1)' 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 0 || $rc -eq 1 ]] && return $rc
    return 2
}

# Patterns: "regex|why"
declare -a patterns=(
    '\bMOCK_(?!OK\b)\w+|identificador MOCK_*'
    # 🔴 Um padrao por marcador, e NENHUM '|' dentro da regex.
    #
    # O parser abaixo faz re="${p%%|*}", que corta no PRIMEIRO '|'. A entrada
    # antiga era '\b(?-i:TODO|FIXME|XXX|HACK)\b[: ]|...', entao a regex extraida
    # virava '\b(?-i:TODO' -- grupo desbalanceado. O grep saia com erro 2, o
    # 2>/dev/null engolia, e a checagem de marcador pendente ficava MORTA
    # respondendo verde. Medido em 2026-08-17.
    #
    # 🔴 TODO saiu do gate em 2026-08-17 -- ver o comentario extenso na perna
    # .ps1. Resumo: a R3 escrita nao pede marcador nenhum (ela trata de dado
    # falso mentindo pro usuario), entao esta checagem era o hook sendo mais
    # estrito que a propria regra, e colidiu 3x com portugues. FIXME/XXX/HACK
    # ficam: sao jargao de dev, nao palavras do idioma.
    '\b(?-i:FIXME)\b[: ]|marcador FIXME pendente'
    '\b(?-i:XXX)\b[: ]|marcador XXX pendente'
    '\b(?-i:HACK)\b[: ]|marcador HACK pendente'
    'lorem[[:space:]]+ipsum|lorem ipsum'
    'dummy_|dummy_'
    'placeholder_value|placeholder_value'
    'https?://localhost:[0-9]+|URL localhost:porta hardcoded'
    # Fronteira de palavra por indicacao do conselho, na mesma rodada. A perna
    # .ps1 ja tinha; esta nao -- as duas pernas divergiam neste ponto sem
    # ninguem ter notado. Sem a fronteira, um comentario portugues legitimo
    # ("evita valor hardcoded") barra o commit, que e o mesmo defeito do TODO.
    '\bhardcoded\b|comentario hardcoded'
)

if [[ -z "$PERCUS_PCRE_MOTOR" ]]; then
    write_percus_block "mock-scan" \
        "o scan NAO PODE RODAR nesta maquina -- bloqueando por seguranca (fail-closed)." \
        "sem motor PCRE: grep -P falhou em todos os locales testados, e perl nao serviu" \
        "Sem PCRE o hook nao consegue procurar, e nao saber nunca pode virar liberacao." \
        "Conserte o ambiente; skip consciente: PERCUS_SKIP_MOCK_SCAN=1 (declarar motivo)."
    exit 2
fi

findings=()
grep_falhou=0
grep_erro_msg=""
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    content=$(get_percus_staged_content "$project_root" "$f")
    [[ -z "$content" ]] && continue
    line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        for p in "${patterns[@]}"; do
            re="${p%%|*}"
            why="${p##*|}"
            # Motor e locale saem da sonda la de cima -- ver o comentario dela.
            # `&& rc=0 || rc=$?` e obrigatorio: com `set -e` no topo, um comando
            # que sai != 0 fora de condicao MATA o script, e sair 1 ("nao
            # casou") e o caso COMUM aqui.
            percus_casa "$re" "$line" && rc=0 || rc=$?
            # 🔴 rc=2 e FALHA DA FERRAMENTA, nao "nao casou" (isso e rc=1).
            # Confundir os dois foi o que escondeu o defeito acima por tanto
            # tempo. E avisar no stderr sem bloquear seria o mesmo fail-open de
            # antes, so que barulhento: guarda que nao consegue procurar tem de
            # BARRAR, nunca liberar. Achado pelo review de 2026-08-17.
            if [[ $rc -eq 2 ]]; then
                grep_falhou=1
                grep_erro_msg="motor $PERCUS_PCRE_MOTOR nao conseguiu aplicar [$re]: ${PERCUS_MOTOR_ERR}"
                break 3
            fi
            if [[ $rc -eq 0 ]]; then
                trimmed=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-80)
                findings+=("${f}:${line_num} -> ${why} :: ${trimmed}")
                break
            fi
        done
        [[ ${#findings[@]} -ge 10 ]] && break
    done <<< "$content"
    [[ ${#findings[@]} -ge 10 ]] && break
done <<< "$files"

# Fail-closed: se o grep nao CONSEGUIU procurar, este hook nao sabe se ha mock
# ou nao -- e nao saber nunca pode virar liberacao. Bloqueia com mensagem
# propria, distinta da de "achei mock", pra ninguem confundir os dois casos.
if [[ $grep_falhou -eq 1 ]]; then
    write_percus_block "mock-scan" \
        "o scan NAO PODE RODAR nesta maquina -- bloqueando por seguranca (fail-closed)." \
        "$grep_erro_msg" \
        "Provavel causa: regex invalida, ou motor PCRE indisponivel." \
        "Conserte o ambiente; nao ignore. Skip consciente: PERCUS_SKIP_MOCK_SCAN=1 (declarar motivo)."
    exit 2
fi

[[ ${#findings[@]} -eq 0 ]] && exit 0

write_percus_block "mock-scan" \
    "encontrados ${#findings[@]}+ padrao(es) de mock/placeholder em arquivos staged (R3)." \
    "${findings[@]}" \
    "Remova o mock OU use commit message comecando com 'MOCK-OK: <motivo>' pra pular." \
    "Skip permanente: PERCUS_SKIP_MOCK_SCAN=1 (declarar motivo em voz alta)."
exit 2
