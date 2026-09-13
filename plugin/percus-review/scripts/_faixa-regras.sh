#!/usr/bin/env bash
# Par .sh de _faixa-regras.ps1 -- mede no canon qual e a ultima regra (R<N>).
#
# Ver o cabecalho do .ps1 para o porque. Resumo: a faixa estava literal em 36 lugares, em
# tres tetos que discordavam entre si (13, 19 e 23) com o canon ja em 25, e o revisor
# respondia que as regras acima do literal "nao existem". Aqui o numero e MEDIDO sempre.
#
# Duas respostas diferentes, de proposito: "medi e deu 25" e "nao consegui medir" nao
# desembocam no mesmo lugar. Sem medida, a faixa nao e chutada.

# Resolve o diretorio do canon.
#   $1 explicito > $PERCUS_CANON_DIR > sobe a arvore procurando 01_REGRAS_INEGOCIAVEIS.md
# O explicito vence ABSOLUTAMENTE, mesmo que nao tenha canon: quem passou o diretorio esta
# perguntando sobre AQUELE canon.
percus_canon_dir() {
    if [[ -n "${1:-}" ]]; then printf '%s' "$1"; return 0; fi
    if [[ -n "${PERCUS_CANON_DIR:-}" ]]; then printf '%s' "$PERCUS_CANON_DIR"; return 0; fi

    local dir
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local i=0
    while [[ $i -lt 8 && -n "$dir" && "$dir" != "/" ]]; do
        if [[ -f "$dir/01_REGRAS_INEGOCIAVEIS.md" ]]; then printf '%s' "$dir"; return 0; fi
        dir="$(dirname "$dir")"
        i=$((i + 1))
    done
    return 1
}

# Ecoa o maior N de "^## R<N>." no canon; ecoa 0 quando NAO CONSEGUIU MEDIR.
# 0 nao e um teto, e a ausencia de medida.
#
# Ancorado em "^##": o canon cita "R23" no corpo de outras regras dezenas de vezes, e contar
# citacao em vez de cabecalho e o erro que este arquivo existe pra nao repetir.
# `sort -n | tail -1` e nao "o ultimo": o canon declara R13 DEPOIS de R19.
percus_canon_max_rule() {
    local dir arq max
    dir="$(percus_canon_dir "${1:-}")" || { printf '0'; return 0; }
    arq="$dir/01_REGRAS_INEGOCIAVEIS.md"
    [[ -f "$arq" ]] || { printf '0'; return 0; }

    # `|| true` nao e defensividade solta: sob `set -e` + `pipefail` um canon que EXISTE mas
    # nao tem `## R<N>.` faz o grep devolver 1, o pipeline devolver 1, e a ATRIBUICAO matar o
    # script -- antes de chegar na guarda abaixo, que e justamente quem degrada com honestidade.
    # Hoje os call sites chamam dentro de `$( )`, onde o bash nao aplica errexit assim, e isso
    # mascara: medido em 2026-09-13, chamada direta sai 1 e a mesma dentro de `$( )` sai 0.
    # Seguranca por forma da chamada nao e seguranca. Achado do R11.
    max="$(grep -oE '^##[[:space:]]+R[0-9]+\.' "$arq" 2>/dev/null \
           | grep -oE '[0-9]+' | sort -n | tail -1 || true)"
    [[ -n "$max" ]] || { printf '0'; return 0; }
    printf '%s' "$max"
}

# Lista das regras do canon, uma por linha, no formato "R<N> — <titulo>".
# Ecoa a frase degradada quando NAO conseguiu ler -- nunca uma lista inventada.
#
# `tr -d '\r'` nao e decorativo: o canon vive num repo com conversao CRLF, e o \r entraria
# no fim de cada titulo e faria este par divergir do .ps1 (que come o \r no `\s*$`).
# `sort -n -k1,1` e nao a ordem do arquivo: o canon declara R13 DEPOIS de R19.
percus_regras_do_canon() {
    local dir arq saida
    local degradado='(nao foi possivel ler as regras do canon -- consulte 01_REGRAS_INEGOCIAVEIS.md)'

    dir="$(percus_canon_dir "${1:-}")" || { printf '%s' "$degradado"; return 0; }
    arq="$dir/01_REGRAS_INEGOCIAVEIS.md"
    [[ -f "$arq" ]] || { printf '%s' "$degradado"; return 0; }

    # `|| true` pelo mesmo motivo do percus_canon_max_rule: sem ele, canon sem regra derruba
    # quem chamou em vez de degradar. Ver o comentario la.
    # O `[^[:space:]]` no fim do grep casa a exigencia de titulo NAO-VAZIO que o `.ps1` ja
    # fazia com `.+?` -- sem isso os dois pares divergiriam num `## R<N>.` sem texto.
    saida="$(grep -oE '^##[[:space:]]+R[0-9]+\.[[:space:]]*[^[:space:]].*' "$arq" 2>/dev/null \
             | tr -d '\r' \
             | sed -E 's/^##[[:space:]]+R([0-9]+)\.[[:space:]]*/\1 /' \
             | sort -n -k1,1 \
             | sed -E 's/^([0-9]+) /R\1 — /' \
             | sed -E 's/[[:space:]]+$//' || true)"

    [[ -n "$saida" ]] || { printf '%s' "$degradado"; return 0; }
    printf '%s' "$saida"
}

# Trecho pronto pra embutir no prompt do revisor.
#   mediu     -> a faixa "R1-" ate o teto medido (hoje 25)
#   nao mediu -> "faixa nao medida -- consulte 01_REGRAS_INEGOCIAVEIS.md"
percus_faixa_regras() {
    local max
    max="$(percus_canon_max_rule "${1:-}")"
    if [[ -z "$max" || "$max" -le 0 ]] 2>/dev/null; then
        printf 'faixa nao medida -- consulte 01_REGRAS_INEGOCIAVEIS.md'
        return 0
    fi
    printf 'R1-R%s' "$max"
}
