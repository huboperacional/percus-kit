#!/usr/bin/env bash
# deepseek-review.sh — Revisa git diff usando DeepSeek API (cross-provider review).
#
# Lê git diff (cached + working tree, ou --base <ref> para escopo). Combina com AGENTS.md.
# Chama DeepSeek API com prompt de revisor Percus. Output: findings estruturados.
# Loga em .deepseek/reviews/<timestamp>.jsonl.
#
# Requer: DEEPSEEK_API_KEY (env var ou .env do projeto), curl, jq, git.

set -euo pipefail

BASE=""
MODEL="${DEEPSEEK_MODEL:-deepseek-v4-flash}"
# reasoning_effort (2026-08-19): este script roda a CADA commit e e o maior gastador do kit
# -- a telemetria mostrou uma review queimando 31.747 tokens de saida, 31.197 (98%) so
# raciocinando. Medido no mesmo prompt real de 11 KB: sem effort gastou 12826 tokens
# pensando e devolveu 3284 chars; com low gastou 2934 e devolveu 5140. Gasta menos E
# devolve mais. NAO trocar por max_tokens maior: ver
# conhecimento/resolver/cross-claude-review-queima-16000-e-volta-vazio.md. "" omite o campo.
REASONING_EFFORT="${DEEPSEEK_REASONING_EFFORT:-low}"
TEMPERATURE="${DEEPSEEK_TEMPERATURE:-0.0}"
ENDPOINT="${DEEPSEEK_ENDPOINT:-https://api.deepseek.com/v1/chat/completions}"

# === ARGS ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)
            BASE="$2"; shift 2 ;;
        --base=*)
            BASE="${1#*=}"; shift ;;
        -h|--help)
            sed -n '2,9p' "$0"; exit 0 ;;
        *)
            shift ;;
    esac
done

# === LOAD .env ===
if [[ -z "${DEEPSEEK_API_KEY:-}" && -f .env ]]; then
    while IFS='=' read -r key val; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key="$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        val="$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'\'']\(.*\)["'\'']$/\1/')"
        if [[ -n "$key" && -z "${!key:-}" ]]; then
            export "$key=$val"
        fi
    done < .env
fi
if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    echo "[deepseek-review] ERRO: DEEPSEEK_API_KEY ausente. Configure no .env do projeto." >&2
    exit 1
fi

# === DEPS ===
for cmd in curl jq git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[deepseek-review] ERRO: dependência '$cmd' não encontrada." >&2
        exit 1
    fi
done

# === COLLECT DIFF ===
if [[ -n "$BASE" ]]; then
    DIFF="$(git diff "$BASE...HEAD" 2>/dev/null || true)"
else
    CACHED="$(git diff --cached 2>/dev/null || true)"
    UNSTAGED="$(git diff 2>/dev/null || true)"
    DIFF="$(printf '%s\n%s' "$CACHED" "$UNSTAGED" | sed -e 's/^[[:space:]]*$//' )"
fi

if [[ -z "$(echo "$DIFF" | tr -d '[:space:]')" ]]; then
    echo "[deepseek-review] Nada pra revisar (diff vazio)."
    exit 0
fi

# === LOAD AGENTS.md ===
# Normaliza pra UTF-8 antes de mandar pro jq. AGENTS.md salvo em CP1252
# (Notepad legacy / Word / Win11 ANSI locale) vira bytes UTF-8 inválidos que
# jq repassa crus e a API DeepSeek rejeita ("invalid unicode code point").
# iconv é opcional: se ausente, fallback é cat (comportamento original).
if [[ -f AGENTS.md ]]; then
    if command -v iconv >/dev/null 2>&1; then
        AGENTS="$(iconv -f UTF-8 -t UTF-8 -c AGENTS.md 2>/dev/null)"
        if [[ -z "$AGENTS" ]]; then
            AGENTS="$(iconv -f CP1252 -t UTF-8 AGENTS.md 2>/dev/null || cat AGENTS.md)"
        fi
    else
        AGENTS="$(cat AGENTS.md)"
    fi
else
    AGENTS="(AGENTS.md ausente — revise pelo bom senso de Percus)"
fi

# === BUILD PROMPT ===
SYSTEM_PROMPT='Você é revisor cross-provider de código no padrão Percus.
Leia o git diff e o AGENTS.md (regras do projeto).
Para cada problema, emita finding no formato:

[SEV: bug | risco | preferência]
Arquivo: caminho/relativo:linha
Regra violada: R{N} (se aplicável)
Problema: descrição em 1-2 frases
Sugestão: ação concreta

Foque em: bugs, regressões, violações R1-R13, mock escondido (R3), JWT em localStorage (R7), pasta sensível tocada indevidamente, imports fora do stack canônico.
NÃO aponte estilo subjetivo sem regra concreta. NÃO sugira refactor fora do diff. Se nada relevante, responda "Sem findings críticos."'

USER_MSG="AGENTS.md do projeto:
${AGENTS}

---

Git diff:
${DIFF}"

# === BUILD JSON BODY (jq garante encoding seguro) ===
# USER_MSG vai por ARQUIVO (--rawfile), nao por argv: no git-bash do Windows o argv
# estoura em ~32KB e o jq morre com "Argument list too long". Efeito perverso: quanto
# MAIOR o diff, menor a chance de ser revisado — o wrapper so dizia "deepseek-review.sh
# falhou". Mesma licao que ja tinha sido aprendida pro curl logo abaixo.
# Encontrado em 2026-07-27 (diff de 52KB do proprio fix do router).
USER_MSG_FILE="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-usermsg-$$.txt")"
trap 'rm -f "$USER_MSG_FILE"' EXIT
printf '%s' "$USER_MSG" > "$USER_MSG_FILE"

BODY="$(jq -n \
    --arg model "$MODEL" \
    --argjson temperature "$TEMPERATURE" \
    --arg sys "$SYSTEM_PROMPT" \
    --rawfile usr "$USER_MSG_FILE" \
    --arg effort "$REASONING_EFFORT" \
    '{
        model: $model,
        temperature: $temperature,
        messages: [
            { role: "system", content: $sys },
            { role: "user", content: $usr }
        ]
    }
    + (if $effort == "" then {} else {reasoning_effort: $effort} end)')"

# === CALL API ===
# Body via stdin (--data-binary @-), NÃO via argv. Em git-bash Windows, curl
# recebe argv via Windows-API que reencoda UTF-8 → CP1252 → UTF-8 e quebra
# multi-byte chars, gerando "invalid unicode code point" no parser DeepSeek.
# Stdin contorna o argv inteiro.
RESPONSE="$(printf '%s' "$BODY" | curl -sS -X POST "$ENDPOINT" \
    -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary @-)" || {
    echo "[deepseek-review] ERRO: chamada API falhou." >&2
    exit 1
}

FINDINGS="$(printf '%s' "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)"
if [[ -z "$FINDINGS" ]]; then
    echo "[deepseek-review] ERRO: resposta vazia ou inválida. Raw:" >&2
    echo "$RESPONSE" >&2
    exit 1
fi

# Vazia ja era barrada acima; CORTADA nao era. Resposta truncada tem texto -- passa no teste
# de vazio -- mas a ultima frase nao terminou e a conclusao pode nem ter sido escrita. Aceitar
# isso como review completa e a mesma classe de fail-open, so que mais dificil de ver.
FINISH="$(printf '%s' "$RESPONSE" | jq -r '.choices[0].finish_reason // empty' 2>/dev/null)"
if [[ "$FINISH" == "length" ]]; then
    echo "[deepseek-review] REVIEW NAO CONCLUIDA -- resposta CORTADA no teto de tokens." >&2
    echo "[deepseek-review] O marcador NAO foi escrito: o commit segue bloqueado (R11)." >&2
    echo "[deepseek-review] Rode de novo. Se repetir, encolha o diff -- nao o teto." >&2
    exit 3
fi
# Fail-open residual: barrar so "length" deixa passar finish_reason ausente (resposta
# malformada) ou valor anomalo (content_filter, valor novo da API). Num gate, desconhecido
# conta como falha. "stop" e o encerramento normal no formato OpenAI que a DeepSeek usa --
# NAO generalize esta regra pro Cross-Claude, que devolve "end_turn".
if [[ "$FINISH" != "stop" ]]; then
    echo "[deepseek-review] REVIEW NAO CONCLUIDA -- finish_reason inesperado: '${FINISH:-<ausente>}'." >&2
    echo "[deepseek-review] O marcador NAO foi escrito: o commit segue bloqueado (R11)." >&2
    exit 3
fi

# === LOG ===
LOG_DIR=".deepseek/reviews"
mkdir -p "$LOG_DIR"
# Path FIXO latest.jsonl (2026-07-20): <timestamp>.jsonl acumulava milhares de
# marcadores (TTL 5min) e travava o hook R11. Um arquivo sobrescrito => O(1).
LOG_FILE="${LOG_DIR}/latest.jsonl"
LOG_TMP="${LOG_DIR}/latest.jsonl.tmp"
DIFF_LINES="$(echo "$DIFF" | wc -l | tr -d ' ')"
jq -n \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg base "$BASE" \
    --argjson diff_lines "$DIFF_LINES" \
    --arg findings "$FINDINGS" \
    '{ timestamp: $timestamp, base: $base, diff_lines: $diff_lines, findings: $findings }' \
    > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"

# === MARCADOR POR HASH DO DIFF (2026-08-19) ===
# Validade da review deixa de ser TEMPO e passa a ser CONTEUDO. A janela de 5 min media a coisa
# errada: consertar um finding ou rodar a suite estourava a janela e forcava re-review do MESMO
# diff. `git diff HEAD` (nao --cached) porque ele NAO muda no `git add`, entao o fluxo
# editar -> revisar -> stage -> commit nao invalida a review no meio.
# Resolve tambem o marcador compartilhado entre sessoes: o hash de outra sessao nao casa com o
# meu diff, sem precisar de id de sessao. O tr -d e o $(...) existem pra bater byte a byte com
# o irmao PowerShell -- hash divergente entre runtimes seria falha silenciosa.
# Falha aqui nao derruba nada: latest.jsonl ja foi escrito e a regra de 5 min segue valendo.
if command -v sha256sum >/dev/null 2>&1; then
    # Hash do ARQUIVO escrito por `git diff --output=`, nunca da saida capturada pelo shell:
    # o irmao PowerShell decodifica a saida do processo com o encoding do console, e diff com
    # acento gerava hash DIFERENTE pro mesmo diff (medido 2026-08-19). Com --output= quem
    # escreve os bytes e o git, identico nos dois runtimes.
    TMP_DIFF="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-diff-$$")"
    # -C na raiz, igual aos hooks: se o review rodar de um subdiretorio, o hash tem que ser o
    # mesmo que o hook calcula, senao o marcador nunca casa e a otimizacao morre em silencio.
    REPO_TOP=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
    git -C "$REPO_TOP" diff HEAD --output="$TMP_DIFF" 2>/dev/null || true
    DIFF_HASH=$(sha256sum "$TMP_DIFF" 2>/dev/null | cut -c1-12)
    rm -f "$TMP_DIFF"
    # Guarda do hash vazio: sem ela, `git diff` falhando gera o marcador "d-.jsonl" -- lixo que
    # ainda por cima casaria com um hash vazio do outro lado, liberando commit sem review.
    if [ -n "$DIFF_HASH" ]; then
        cp -f "$LOG_FILE" "$LOG_DIR/d-$DIFF_HASH.jsonl" 2>/dev/null || true
    fi
fi
# === TELEMETRIA DE GASTO (2026-08-19) ===
# Diretorio SEPARADO do marcador, de proposito. O latest.jsonl e sobrescrito a cada review
# (2026-07-20) pra manter o hook R11 em O(1) -- decisao certa, que custou a visibilidade do
# custo: em 2026-08-19 os logs de conselho de 62 diretorios .deepseek somavam $0.89 de um
# painel de $29.76. 97% invisivel, pelo caminho MAIS usado (review existe em 48 projetos).
#
# APPEND de uma linha por review em .deepseek/spend/<YYYY-MM>.jsonl -- arquivo por MES, que e
# o que impede a volta do acumulo que pendurou o hook em 148s. O hook nunca varre este dir.
#
# NOTA: o marcador acima nao grava model/usage nesta versao .sh (o irmao .ps1 passou a gravar
# em 2026-08-15 e este ficou para tras). A telemetria abaixo grava os dois de qualquer jeito,
# entao o gasto do caminho Unix passa a ser mensuravel mesmo com o marcador incompleto.
#
# `|| true` no fim: este script libera o commit (R11). Telemetria que falha nao pode custar um
# commit -- mesmo principio que fez os campos ausentes virarem null no marcador.
{
    SPEND_DIR=".deepseek/spend"
    mkdir -p "$SPEND_DIR"
    SPEND_FILE="${SPEND_DIR}/$(date -u +%Y-%m).jsonl"
    # -c: uma linha so. Append curto e o mais proximo de atomico sem lock; se duas sessoes
    # appendarem juntas e uma linha sair cortada, o leitor pula a linha ruim em vez de perder
    # o mes inteiro.
    # DIFF_LINES com piso 0: `--argjson` exige JSON numerico valido e ABORTA o bloco se vier
    # vazio. No marcador acima isso falharia alto; aqui, com o `|| true`, falharia em SILENCIO
    # -- devolvendo exatamente a cegueira de custo que esta telemetria veio acabar.
    printf '%s' "$RESPONSE" | jq -c \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg model "$MODEL" \
        --argjson diff_lines "${DIFF_LINES:-0}" \
        '{timestamp: $timestamp, tool: "deepseek-review", provider: "deepseek",
          model: $model, usage: .usage, diff_lines: $diff_lines}' \
        >> "$SPEND_FILE"
} 2>/dev/null || true

# Auto-poda: so latest.jsonl fica (mecanismo novo). Marcadores <ts>.jsonl irmaos
# drenam sozinhos no proximo review -- pilha nunca mais cresce, sem tocar hooks.
# Poda: preserva marcadores por hash (d-*.jsonl) dentro de 24 h e apaga o resto. O que
# continua sendo apagado sem do e o <timestamp>.jsonl de wrapper antigo -- eram esses que
# acumulavam aos milhares e penduravam o hook em 148 s (2026-07-20). As 24 h nao sao
# "frescor" (o hash ja garante o conteudo): sao so o teto que impede crescimento sem fim.
for old in "$LOG_DIR"/*.jsonl; do
    [ "$old" = "$LOG_FILE" ] && continue
    case "$(basename "$old")" in
        d-*.jsonl)
            [ -n "$(find "$old" -mmin +1440 2>/dev/null)" ] && rm -f "$old"
            ;;
        *)
            [ -e "$old" ] && rm -f "$old"
            ;;
    esac
done

# === OUTPUT ===
printf '## Findings DeepSeek (cross-provider review)\n\n'
printf '%s\n' "$FINDINGS"
