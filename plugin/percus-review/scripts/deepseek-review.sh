#!/usr/bin/env bash
# deepseek-review.sh — Revisa git diff usando DeepSeek API (cross-provider review).
#
# Lê git diff (cached + working tree, ou --base <ref> para escopo). Combina com AGENTS.md.
# Chama DeepSeek API com prompt de revisor Percus. Output: findings estruturados.
# Loga em .deepseek/reviews/<timestamp>.jsonl.
#
# Requer: DEEPSEEK_API_KEY (env var ou .env do projeto), curl, jq, git.

set -euo pipefail

# Faixa de regras MEDIDA no canon (nunca escrita a mao) -- ver _faixa-regras.sh.
# Carga GUARDADA, nao incondicional: sob `set -e` um source de arquivo ausente mata o script
# inteiro, e um cache parcial travaria TODO commit da frota por causa de um ornamento de
# prompt. Pego pelo proprio R11 nesta mudanca.
_PERCUS_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_PERCUS_SCRIPTS_DIR/_faixa-regras.sh" ]]; then
    # shellcheck source=/dev/null
    . "$_PERCUS_SCRIPTS_DIR/_faixa-regras.sh"
fi

BASE=""
TIMEOUT_ARG=""
BACKOFF_ARG=""
MAX_LINHAS_FATIA_ARG=""
MAX_FATIAS_ARG=""
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
        --endpoint)
            ENDPOINT="$2"; shift 2 ;;
        --endpoint=*)
            ENDPOINT="${1#*=}"; shift ;;
        --timeout)
            TIMEOUT_ARG="$2"; shift 2 ;;
        --timeout=*)
            TIMEOUT_ARG="${1#*=}"; shift ;;
        --backoff)
            BACKOFF_ARG="$2"; shift 2 ;;
        --backoff=*)
            BACKOFF_ARG="${1#*=}"; shift ;;
        --max-linhas-fatia)
            MAX_LINHAS_FATIA_ARG="$2"; shift 2 ;;
        --max-linhas-fatia=*)
            MAX_LINHAS_FATIA_ARG="${1#*=}"; shift ;;
        --max-fatias)
            MAX_FATIAS_ARG="$2"; shift 2 ;;
        --max-fatias=*)
            MAX_FATIAS_ARG="${1#*=}"; shift ;;
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

# === TIMEOUT E BACKOFF (2026-09-14, FR-001/002): flag > env > padrao ===
e_inteiro() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; return 0; }
# Fix round 1 (2026-09-14, achado da review): "08"/"09" sao digitos validos pra e_inteiro mas o
# bash avalia -lt/-ge em contexto aritmetico, onde zero a esquerda vira octal -- "08" nao e octal
# valido (digito 8) e o bash solta "value too great for base" no stderr, alem de a comparacao
# falhar por acidente. 10#$v forca base 10 antes de qualquer comparacao/atribuicao.
config_de_env() {  # $1 nome da var, $2 padrao, $3 minimo
    local v="${!1:-}" n
    if [[ -z "$v" ]]; then printf '%s' "$2"; return 0; fi
    if e_inteiro "$v"; then
        n=$((10#$v))
        if [[ "$n" -ge "$3" ]]; then printf '%s' "$n"; return 0; fi
    fi
    echo "[deepseek-review] WARN: $1='$v' invalido -- usando padrao $2." >&2
    printf '%s' "$2"
}
if [[ -n "$TIMEOUT_ARG" ]]; then
    if ! e_inteiro "$TIMEOUT_ARG"; then echo "[deepseek-review] ERRO: --timeout precisa ser inteiro >= 1." >&2; exit 2; fi
    TIMEOUT_S=$((10#$TIMEOUT_ARG))
    if [[ "$TIMEOUT_S" -lt 1 ]]; then echo "[deepseek-review] ERRO: --timeout precisa ser inteiro >= 1." >&2; exit 2; fi
else
    TIMEOUT_S="$(config_de_env PERCUS_DEEPSEEK_TIMEOUT_S 180 1)"
fi
if [[ -n "$BACKOFF_ARG" ]]; then
    if ! e_inteiro "$BACKOFF_ARG"; then echo "[deepseek-review] ERRO: --backoff precisa ser inteiro >= 0." >&2; exit 2; fi
    BACKOFF_S=$((10#$BACKOFF_ARG))
else
    BACKOFF_S="$(config_de_env PERCUS_DEEPSEEK_BACKOFF_S 5 0)"
fi
# Fatiamento (2026-09-15, ponto 23): mesma precedencia do timeout.
if [[ -n "$MAX_LINHAS_FATIA_ARG" ]]; then
    if ! e_inteiro "$MAX_LINHAS_FATIA_ARG" || [[ "$((10#$MAX_LINHAS_FATIA_ARG))" -lt 200 ]]; then
        echo "[deepseek-review] ERRO: --max-linhas-fatia precisa ser inteiro >= 200." >&2; exit 2
    fi
    MAX_LINHAS_FATIA=$((10#$MAX_LINHAS_FATIA_ARG))
else
    MAX_LINHAS_FATIA="$(config_de_env PERCUS_R11_MAX_LINHAS_FATIA 1500 200)"
fi
if [[ -n "$MAX_FATIAS_ARG" ]]; then
    if ! e_inteiro "$MAX_FATIAS_ARG" || [[ "$((10#$MAX_FATIAS_ARG))" -lt 1 ]]; then
        echo "[deepseek-review] ERRO: --max-fatias precisa ser inteiro >= 1." >&2; exit 2
    fi
    MAX_FATIAS=$((10#$MAX_FATIAS_ARG))
else
    MAX_FATIAS="$(config_de_env PERCUS_R11_MAX_FATIAS 8 1)"
fi

# === COLLECT DIFF ===
# ⚠️ `2>/dev/null || true` num portao é a receita do falso-verde: `git diff`
# falhando vira string vazia, o teste abaixo lê "diff vazio" e o script sai 0 --
# R11 satisfeito sem ter revisado nada. Medido no irmão PowerShell em 2026-08-25,
# com arquivo staged. Portão que não consegue medir REPROVA.
if [[ -n "$BASE" ]]; then
    if ! git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null 2>&1; then
        echo "[deepseek-review] ERRO: --base '$BASE' não é um ref git válido." >&2
        echo "  Rode sem argumento (revisa staged+working tree) ou passe --base <ref>." >&2
        exit 2
    fi
    _err="$(mktemp)"
    if ! DIFF="$(git diff "$BASE...HEAD" 2>"$_err")"; then
        echo "[deepseek-review] ERRO: git diff '$BASE...HEAD' falhou: $(cat "$_err")" >&2
        rm -f "$_err"; exit 2
    fi
    rm -f "$_err"
else
    # Este ramo é o MAIS usado (invocação sem argumento) e ficou com o
    # `2>/dev/null || true` na primeira versão do conserto — três linhas abaixo
    # do comentário que denuncia o padrão. Achado pela review DeepSeek do
    # próprio patch: consertar uma cópia não conserta a classe.
    # stderr para ARQUIVO, não para o stdout: com `2>&1` os avisos do git
    # ("LF will be replaced by CRLF") entravam no DIFF enviado ao modelo.
    _err="$(mktemp)"
    if ! CACHED="$(git diff --cached 2>"$_err")"; then
        echo "[deepseek-review] ERRO: git diff --cached falhou: $(cat "$_err")" >&2
        rm -f "$_err"; exit 2
    fi
    if ! UNSTAGED="$(git diff 2>"$_err")"; then
        echo "[deepseek-review] ERRO: git diff falhou: $(cat "$_err")" >&2
        rm -f "$_err"; exit 2
    fi
    rm -f "$_err"
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
# A faixa e MEDIDA no canon agora, nao escrita a mao. Ate 2026-09-12 estava literal aqui com
# um teto de duas dezenas atras do canon, e o revisor reprovava regra valida dizendo que ela
# "nao existe". Verbete:
# conhecimento/resolver/revisor-cita-faixa-de-regras-fixa-no-prompt-e-reprova-regra-valida.md
if declare -F percus_faixa_regras >/dev/null 2>&1; then
    FAIXA_REGRAS="$(percus_faixa_regras)"
else
    FAIXA_REGRAS="faixa nao medida -- consulte 01_REGRAS_INEGOCIAVEIS.md"
fi

SYSTEM_PROMPT='Você é revisor cross-provider de código no padrão Percus.
Leia o git diff e o AGENTS.md (regras do projeto).
Para cada problema, emita finding no formato:

[SEV: bug | risco | preferência]
Arquivo: caminho/relativo:linha
Regra violada: R{N} (se aplicável)
Problema: descrição em 1-2 frases
Sugestão: ação concreta

Foque em: bugs, regressões, violações do canon Percus ('"$FAIXA_REGRAS"'), mock escondido (R3), JWT em localStorage (R7), pasta sensível tocada indevidamente, imports fora do stack canônico.
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
RESP_FILE="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-resp-$$.json")"
CURL_ERR="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/percus-curlerr-$$.txt")"
# CHAVE FORA DO ARGV (2026-09-15, F-f): `-H "Authorization: Bearer <chave>"` punha a chave na
# linha de comando do curl.exe, legivel por qualquer processo do usuario (Get-CimInstance
# Win32_Process, ps). O cabecalho vai num arquivo 600 lido com `-H @arquivo`. Sem fallback de
# nome previsivel: se o mktemp falhar, para. `--config -` nao serve aqui: o stdin ja e o corpo.
# `-H @arquivo` exige curl >= 7.55.0 (2017); o Git for Windows e o curl 8.18 desta maquina atendem.
AUTH_FILE="$(mktemp "${TMPDIR:-/tmp}/percus-auth-XXXXXX" 2>/dev/null)" || AUTH_FILE=""
# Fatiamento (ponto 23): blocos por arquivo, corpo e resposta de cada fatia moram em FATIA_DIR, que
# sai no MESMO trap do cabecalho. Todas as fatias reusam o mesmo AUTH_FILE.
FATIA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/percus-fatias-XXXXXX" 2>/dev/null)" || FATIA_DIR=""
# `|| true`: sob set -e um rm que falhasse dentro do trap trocaria o codigo de saida (exit 4 etc.).
trap 'rm -f "$USER_MSG_FILE" "$RESP_FILE" "$CURL_ERR" ${AUTH_FILE:+"$AUTH_FILE"} || true; rm -rf ${FATIA_DIR:+"$FATIA_DIR"} || true' EXIT
if [[ -z "$AUTH_FILE" ]]; then
    echo "[deepseek-review] ERRO: nao consegui criar o arquivo temporario do cabecalho de autenticacao." >&2
    exit 1
fi
if [[ -z "$FATIA_DIR" ]]; then
    echo "[deepseek-review] ERRO: nao consegui criar o diretorio temporario das fatias." >&2
    exit 1
fi
chmod 600 "$AUTH_FILE" 2>/dev/null || true
# printf e builtin (a chave nao vira argv de processo nenhum). \r tirado por defesa: o curl 8.18
# desta maquina ja apara o \r ao ler `-H @arquivo` (medido 2026-09-15), mas isso e do curl, nao
# nosso -- chave vinda com \r nao pode depender da versao dele para nao virar "Bearer x\r".
printf 'Authorization: Bearer %s\n' "${DEEPSEEK_API_KEY//$'\r'/}" > "$AUTH_FILE"
printf '%s' "$USER_MSG" > "$USER_MSG_FILE"

montar_body() {  # $1 system prompt, $2 arquivo com a mensagem do usuario -> define BODY
BODY="$(jq -n \
    --arg model "$MODEL" \
    --argjson temperature "$TEMPERATURE" \
    --arg sys "$1" \
    --rawfile usr "$2" \
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
}

# === CALL API: TIMEOUT E EXATAMENTE 1 RETRY (2026-09-14, FR-001..005) ===
# Body via stdin (--data-binary @-), NAO via argv: git-bash reencoda argv e quebra UTF-8.
# -o arquivo + -w status: sem isso 4xx/5xx e 2xx sem choices eram indistinguiveis.
mask_trecho() {  # stdin: corpo bruto -> stdout: primeiros 2000 CARACTERES, chave trocada por ***
    local raw masked
    raw="$(cat; printf x)"; raw="${raw%x}"
    masked="${raw//"$DEEPSEEK_API_KEY"/***}"
    # Mascara ANTES de cortar. Locale UTF-8 so no subshell: o corte e por caractere, nao por byte.
    ( LC_ALL=C.UTF-8; printf '%s' "${masked:0:2000}" )
}

tentativa() {  # define TENT_VEREDITO (ok|retry|fatal) e TENT_CAUSA
    local rc=0 status tem trecho
    : > "$RESP_FILE"
    status="$(printf '%s' "$BODY" | curl -sS -o "$RESP_FILE" -w '%{http_code}' --max-time "$TIMEOUT_S" \
        -X POST "$ENDPOINT" \
        -H "@$AUTH_FILE" \
        -H "Content-Type: application/json; charset=utf-8" \
        --data-binary @- 2>"$CURL_ERR")" || rc=$?
    status="$(printf '%s' "$status" | tr -d '\r' || true)"
    if [[ $rc -ne 0 ]]; then
        TENT_VEREDITO=retry
        if [[ $rc -eq 28 ]]; then TENT_CAUSA="erro de rede/timeout: timeout de ${TIMEOUT_S}s"
        else TENT_CAUSA="erro de rede/timeout: curl exit $rc $(tr -d '\r\n' < "$CURL_ERR")"; fi
        return 0
    fi
    tem="$(jq -r 'if type == "object" and (.choices | type) == "array" and (.choices | length) > 0 then "sim" else "nao" end' < "$RESP_FILE" 2>/dev/null | tr -d '\r' || true)"
    [[ "$tem" == "sim" ]] || tem="nao"
    if [[ "$tem" == "nao" ]]; then
        trecho="$(mask_trecho < "$RESP_FILE"; printf x)"; trecho="${trecho%x}"
        echo "[deepseek-review] resposta sem choices (HTTP $status) -- primeiros 2000 caracteres do corpo:" >&2
        printf '%s\n' "$trecho" >&2
        { mkdir -p ".deepseek/reviews" && printf 'timestamp=%s\nstatus=%s\n---\n%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$trecho" > ".deepseek/reviews/ultimo-erro.txt"; } 2>/dev/null \
            || echo "[deepseek-review] WARN: nao consegui gravar ultimo-erro.txt" >&2
    fi
    if [[ "$status" =~ ^2[0-9][0-9]$ ]]; then
        if [[ "$tem" == "sim" ]]; then TENT_VEREDITO=ok; TENT_CAUSA=""; return 0; fi
        TENT_VEREDITO=retry
        if [[ -z "$(tr -d ' \t\r\n' < "$RESP_FILE")" ]]; then TENT_CAUSA="HTTP $status com corpo vazio"
        else TENT_CAUSA="HTTP $status sem choices"; fi
        return 0
    fi
    if [[ "$status" == "429" || "$status" =~ ^5[0-9][0-9]$ ]]; then TENT_VEREDITO=retry; TENT_CAUSA="HTTP $status"; return 0; fi
    TENT_VEREDITO=fatal; TENT_CAUSA="HTTP $status"
    return 0
}

echo "[deepseek-review] timeout=${TIMEOUT_S}s backoff=${BACKOFF_S}s" >&2

agora_ms() {
    # EPOCHREALTIME (builtin do bash 5) primeiro: sem processo novo. Fallback `date +%s%3N`; em
    # date sem %N (BSD) o %3N volta literal e a ultima perna usa segundos*1000.
    local s="${EPOCHREALTIME:-}"
    s="${s//,/.}"  # separador decimal segue o locale (pt-BR usa virgula)
    if [[ "$s" == *.*[0-9] ]]; then printf '%s' "$(( ${s%.*} * 1000 + 10#${s#*.} / 1000 ))"; return 0; fi
    s="$(date +%s%3N 2>/dev/null || true)"
    case "$s" in ''|*[!0-9]*) s="$(( $(date +%s) * 1000 ))" ;; esac
    printf '%s' "$s"
}

# Uma chamada com timeout e exatamente 1 retry, e os portoes da resposta. Qualquer falha SAI do
# script com o codigo de sempre (+ " (fatia i/n)" quando fatiado): nada abaixo -- latest.jsonl,
# d-<hash>, spend -- e gravado. Fatia parcial nunca libera commit meio revisado.
revisar_chamada() {  # $1 sufixo ("" ou " (fatia i/n)"), $2 arquivo onde guardar a resposta ok
local SUF="$1" RESPONSE FINDINGS FINISH T0
T0="$(agora_ms)"
tentativa
if [[ "$TENT_VEREDITO" == "retry" ]]; then
    echo "[deepseek-review] tentativa 1 falhou: ${TENT_CAUSA}. Nova tentativa em ${BACKOFF_S}s.${SUF}" >&2
    sleep "$BACKOFF_S"
    tentativa
    if [[ "$TENT_VEREDITO" == "retry" ]]; then
        echo "[deepseek-review] PROVEDOR INDISPONIVEL apos retry: ${TENT_CAUSA}. Nenhum marcador gravado (exit 4).${SUF}" >&2
        exit 4
    fi
fi
if [[ "$TENT_VEREDITO" == "fatal" ]]; then
    echo "[deepseek-review] ERRO: ${TENT_CAUSA} -- nao recuperavel, sem nova tentativa. Nenhum marcador gravado (exit 1).${SUF}" >&2
    exit 1
fi
RESPONSE="$(cat "$RESP_FILE")"

FINDINGS="$(printf '%s' "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null | tr -d '\r' || true)"
if [[ -z "$FINDINGS" ]]; then
    # Com choices e content vazio: resposta inutilizavel, nao outage (FR-005 exit 3, sem retry).
    echo "[deepseek-review] REVIEW NAO CONCLUIDA -- content vazio.${SUF}" >&2
    echo "[deepseek-review] O marcador NAO foi escrito: o commit segue bloqueado (R11)." >&2
    exit 3
fi

# Vazia ja era barrada acima; CORTADA nao era. Resposta truncada tem texto -- passa no teste
# de vazio -- mas a ultima frase nao terminou e a conclusao pode nem ter sido escrita. Aceitar
# isso como review completa e a mesma classe de fail-open, so que mais dificil de ver.
FINISH="$(printf '%s' "$RESPONSE" | jq -r '.choices[0].finish_reason // empty' 2>/dev/null | tr -d '\r' || true)"
if [[ "$FINISH" == "length" ]]; then
    echo "[deepseek-review] REVIEW NAO CONCLUIDA -- resposta CORTADA no teto de tokens.${SUF}" >&2
    echo "[deepseek-review] O marcador NAO foi escrito: o commit segue bloqueado (R11)." >&2
    echo "[deepseek-review] Rode de novo. Se repetir, encolha o diff -- nao o teto." >&2
    exit 3
fi
# Fail-open residual: barrar so "length" deixa passar finish_reason ausente (resposta
# malformada) ou valor anomalo (content_filter, valor novo da API). Num gate, desconhecido
# conta como falha. "stop" e o encerramento normal no formato OpenAI que a DeepSeek usa --
# NAO generalize esta regra pro Cross-Claude, que devolve "end_turn".
if [[ "$FINISH" != "stop" ]]; then
    echo "[deepseek-review] REVIEW NAO CONCLUIDA -- finish_reason inesperado: '${FINISH:-<ausente>}'.${SUF}" >&2
    echo "[deepseek-review] O marcador NAO foi escrito: o commit segue bloqueado (R11)." >&2
    exit 3
fi
cp -f "$RESP_FILE" "$2"
CHAMADA_LAT_MS=$(( $(agora_ms) - T0 ))
}

# === FATIAMENTO POR ARQUIVO (2026-09-15, ponto 23) ===
# Os achados saturam em ~2,6 por chamada (verbete achado-de-review-satura-com-o-tamanho-do-diff).
# Acima do teto o diff e partido nas fronteiras `diff --git` (so no INICIO da linha: dentro de um
# .md a string vem com prefixo +/-/espaco). Codigo primeiro, teste depois, cada grupo na ordem do
# diff; gulosa ate o teto; arquivo maior que o teto vira fatia propria, sem corte.
# O awk grava cada bloco byte a byte (o \r de arquivo CRLF segue no diff enviado); o \r so e
# tirado do CAMINHO extraido do cabecalho.
DIFF_LINES="$(printf '%s\n' "$DIFF" | wc -l | tr -d ' \r')"
FAT_N=0
declare -a FAT_BLOCOS=() FAT_LINHAS=() FAT_ARQS=()
if [[ "$DIFF_LINES" -gt "$MAX_LINHAS_FATIA" ]]; then
    # Diretorio pelo AMBIENTE, nao por -v: -v interpreta escapes, e um TMPDIR Windows
    # (C:\Users\...\tmp) viraria tab no \t.
    printf '%s\n' "$DIFF" | PERCUS_FATIA_DIR="$FATIA_DIR" awk '
        BEGIN { dir = ENVIRON["PERCUS_FATIA_DIR"] }
        function eh_teste(p,   nome, cam) {
            # tolower: a convencao do kit e `x.tests.ps1`, mas o padrao do Pester em outros projetos
            # e `X.Tests.ps1`, e o awk e case-sensitive -- sem isto o teste ia pro grupo de codigo.
            cam = tolower(p); nome = cam; sub(/.*\//, "", nome)
            return (nome ~ /\.tests\.ps1$/ || nome ~ /^test_.*\.py$/ || nome ~ /_test\.py$/ || nome ~ /\.(test|spec)\.tsx?$/ || ("/" cam) ~ /\/tests\//) ? 1 : 0
        }
        function fecha() {
            if (n > 0) { close(arq); printf "%d\t%d\t%d\t%s\n", n, linhas, eh_teste(caminho), caminho > (dir "/indice.tsv") }
        }
        {
            cab = (substr($0, 1, 11) == "diff --git ")
            if (n == 0 || (cab && tem_cab)) {
                fecha(); n++; linhas = 0; tem_cab = 0; caminho = ""
                arq = sprintf("%s/b-%05d", dir, n)
            }
            if (cab) {
                tem_cab = 1; p = $0; sub(/\r$/, "", p); resto = p; pos = 0
                while ((k = index(resto, " b/")) > 0) { pos += k + 2; resto = substr(resto, k + 3) }
                if (pos > 0) { caminho = substr(p, pos + 1) }
                else {
                    resto = p; pos = 0
                    while ((k = index(resto, " \"b/")) > 0) { pos += k + 3; resto = substr(resto, k + 4) }
                    if (pos > 0) { caminho = substr(p, pos + 1); sub(/"$/, "", caminho) }
                }
            }
            print > arq
            linhas++
        }
        END { fecha(); close(dir "/indice.tsv") }
    '
    for GRUPO in 0 1; do
        CUR_B=""; CUR_L=0; CUR_A=""
        while IFS=$'\t' read -r B_N B_L B_T B_P; do
            [[ "$B_T" == "$GRUPO" ]] || continue
            if [[ -n "$CUR_B" && $((CUR_L + B_L)) -gt "$MAX_LINHAS_FATIA" ]]; then
                FAT_BLOCOS[FAT_N]="$CUR_B"; FAT_LINHAS[FAT_N]="$CUR_L"; FAT_ARQS[FAT_N]="$CUR_A"; FAT_N=$((FAT_N + 1))
                CUR_B=""; CUR_L=0; CUR_A=""
            fi
            CUR_B="${CUR_B:+$CUR_B }$B_N"; CUR_L=$((CUR_L + B_L))
            if [[ -n "$B_P" ]]; then CUR_A="${CUR_A:+$CUR_A, }$B_P"; fi
        done < "$FATIA_DIR/indice.tsv"
        if [[ -n "$CUR_B" ]]; then
            FAT_BLOCOS[FAT_N]="$CUR_B"; FAT_LINHAS[FAT_N]="$CUR_L"; FAT_ARQS[FAT_N]="$CUR_A"; FAT_N=$((FAT_N + 1))
        fi
    done
    if [[ "$FAT_N" -gt "$MAX_FATIAS" ]]; then
        echo "[deepseek-review] WARN: diff de ${DIFF_LINES} linhas precisaria de ${FAT_N} fatias (> ${MAX_FATIAS}): revisado inteiro; achados saturam em ~2,6 por chamada -- considere dividir o commit." >&2
    fi
fi
N_CHAMADAS=1
if [[ "$FAT_N" -gt 1 && "$FAT_N" -le "$MAX_FATIAS" ]]; then N_CHAMADAS="$FAT_N"; fi
echo "[deepseek-review] max_linhas_fatia=${MAX_LINHAS_FATIA} max_fatias=${MAX_FATIAS} diff_lines=${DIFF_LINES} chamadas=${N_CHAMADAS}" >&2

declare -a CH_LAT=()
if [[ "$N_CHAMADAS" -eq 1 ]]; then
    # Sem fatiar: corpo identico ao de antes do fatiamento.
    montar_body "$SYSTEM_PROMPT" "$USER_MSG_FILE"
    revisar_chamada "" "$FATIA_DIR/resp-1.json"
    CH_LAT[1]="$CHAMADA_LAT_MS"
    FAT_LINHAS[0]="$DIFF_LINES"
else
    # Em ordem: as fatias de teste so rodam depois de todas as de codigo passarem.
    for ((I = 1; I <= N_CHAMADAS; I++)); do
        for B in ${FAT_BLOCOS[I-1]}; do cat "$FATIA_DIR/$(printf 'b-%05d' "$B")"; done > "$FATIA_DIR/blocos-$I.txt"
        # Tira SO o \n final que o awk sempre acrescenta (paridade com o .ps1, que junta as linhas
        # sem terminador). `$(...)` comeria TAMBEM as linhas em branco do fim do diff -- o .sh
        # normaliza linha so com espaco para vazia antes de fatiar (achado do R11 desta mudanca).
        truncate -s -1 "$FATIA_DIR/blocos-$I.txt" 2>/dev/null || true
        {
            printf 'AGENTS.md do projeto:\n%s\n\n---\n\nGit diff:\n' "$AGENTS"
            cat "$FATIA_DIR/blocos-$I.txt"
        } > "$FATIA_DIR/usr-$I.txt"
        montar_body "${SYSTEM_PROMPT}

Esta e a fatia ${I} de ${N_CHAMADAS} (arquivos: ${FAT_ARQS[I-1]}). Revise so o que esta nela." "$FATIA_DIR/usr-$I.txt"
        revisar_chamada " (fatia ${I}/${N_CHAMADAS})" "$FATIA_DIR/resp-$I.json"
        CH_LAT[I]="$CHAMADA_LAT_MS"
    done
fi

# Todas as chamadas ok. Achados: resposta crua sem fatiar; fatiado, "### Fatia i/n -- arquivos"
# + resposta de cada uma. usage: cru sem fatiar; fatiado, soma campo a campo (ausente = 0).
if [[ "$N_CHAMADAS" -eq 1 ]]; then
    RESPONSE="$(cat "$FATIA_DIR/resp-1.json")"
    FINDINGS="$(printf '%s' "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null | tr -d '\r' || true)"
    USAGE_JSON="$(printf '%s' "$RESPONSE" | jq -c '.usage // null' | tr -d '\r')"
else
    TRAVESSAO=$'\xe2\x80\x94'
    FINDINGS=""
    for ((I = 1; I <= N_CHAMADAS; I++)); do
        PARTE="$(jq -r '.choices[0].message.content // empty' < "$FATIA_DIR/resp-$I.json" | tr -d '\r')"
        CAB_F="### Fatia ${I}/${N_CHAMADAS} ${TRAVESSAO} ${FAT_ARQS[I-1]}"
        if [[ -n "$FINDINGS" ]]; then FINDINGS="${FINDINGS}

"; fi
        FINDINGS="${FINDINGS}${CAB_F}

${PARTE}"
    done
    USAGE_JSON="$(cat "$FATIA_DIR"/resp-*.json | jq -s -c '
        [.[] | (.usage // {})] as $u
        | { prompt_tokens: ($u | map(.prompt_tokens // 0) | add),
            completion_tokens: ($u | map(.completion_tokens // 0) | add),
            total_tokens: ($u | map(.total_tokens // 0) | add),
            prompt_cache_hit_tokens: ($u | map(.prompt_cache_hit_tokens // 0) | add),
            prompt_cache_miss_tokens: ($u | map(.prompt_cache_miss_tokens // 0) | add) }' | tr -d '\r')"
fi
# Achados por ARQUIVO (--rawfile), nao por argv: fatiado, a soma das respostas pode passar do
# limite de ~32 KB do argv no git-bash (a mesma licao do USER_MSG acima).
printf '%s' "$FINDINGS" > "$FATIA_DIR/findings.txt"
# --argjson aborta com valor vazio: telemetria nao pode derrubar o marcador.
USAGE_JSON="${USAGE_JSON:-null}"

# === LOG ===
LOG_DIR=".deepseek/reviews"
mkdir -p "$LOG_DIR"
# Path FIXO latest.jsonl (2026-07-20): <timestamp>.jsonl acumulava milhares de
# marcadores (TTL 5min) e travava o hook R11. Um arquivo sobrescrito => O(1).
LOG_FILE="${LOG_DIR}/latest.jsonl"
LOG_TMP="${LOG_DIR}/latest.jsonl.tmp"
# Fatiado: UM latest.jsonl so, com os achados de todas as fatias e usage somado -- o hook le um
# arquivo so, e um por fatia liberaria commit meio revisado.
jq -n -c \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg base "$BASE" \
    --argjson diff_lines "$DIFF_LINES" \
    --arg model "$MODEL" \
    --rawfile findings "$FATIA_DIR/findings.txt" \
    --argjson usage "$USAGE_JSON" \
    --argjson fatias "$N_CHAMADAS" \
    '{ timestamp: $timestamp, base: $base, diff_lines: $diff_lines, model: $model, usage: $usage, findings: $findings, fatias: $fatias }' \
    | tr -d '\r' > "$LOG_TMP" && mv -f "$LOG_TMP" "$LOG_FILE"

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
    # e3b0c44298fc = hash do arquivo vazio: sem hash, nunca d-e3b0c44298fc.jsonl (emenda FR-011).
    if [ -n "$DIFF_HASH" ] && [ "$DIFF_HASH" != "e3b0c44298fc" ]; then
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
    # Uma linha por CHAMADA (fatia), com fatia/fatias/latency_ms; diff_lines e o da fatia. So
    # chega aqui com todas as fatias ok: falha no meio sai antes, sem spend de sucesso.
    SPEND_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for ((I = 1; I <= N_CHAMADAS; I++)); do
        jq -c \
            --arg timestamp "$SPEND_TS" \
            --arg model "$MODEL" \
            --argjson diff_lines "${FAT_LINHAS[I-1]:-0}" \
            --argjson fatia "$I" \
            --argjson fatias "$N_CHAMADAS" \
            --argjson latency_ms "${CH_LAT[I]:-0}" \
            '{timestamp: $timestamp, tool: "deepseek-review", provider: "deepseek",
              model: $model, usage: .usage, diff_lines: $diff_lines,
              fatia: $fatia, fatias: $fatias, latency_ms: $latency_ms}' \
            < "$FATIA_DIR/resp-$I.json" | tr -d '\r' >> "$SPEND_FILE"
    done
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
