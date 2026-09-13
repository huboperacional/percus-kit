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

    max="$(grep -oE '^##[[:space:]]+R[0-9]+\.' "$arq" 2>/dev/null \
           | grep -oE '[0-9]+' | sort -n | tail -1)"
    [[ -n "$max" ]] || { printf '0'; return 0; }
    printf '%s' "$max"
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
