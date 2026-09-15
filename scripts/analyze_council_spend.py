"""analyze-council-spend: baseline custo do conselho 3-membros Percus.

Le logs em .deepseek/council-log/*.jsonl, estima tokens (preferindo usage real
dos providers; fallback tiktoken cl100k_base), aplica preco fixo e agrega.
"""
from __future__ import annotations
import argparse
import json
import re
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable

# Keys duplicadas (ex: "deepseek" e "deepseek-chat") sao aliases deliberados:
# cobrem tanto o provider name retornado pela API quanto o model name nos logs.
# Modelos APOSENTADOS ficam na tabela de proposito: log de marco/junho foi cobrado ao preco
# daquela epoca, e apagar a linha faria o historico ser reprecificado (ou cair no fallback e
# virar 0). Entrada nova nao substitui a velha -- acompanha.
#
# Forma do valor (desde ponto 17, resto): LISTA de periodos por modelo, ordenada por
# `vigente_desde` (ISO "AAAA-MM-DD", UTC). Cada periodo e {"vigente_desde", "in_hit", "in_miss",
# "out", "pico", "fonte"}. compute_cost() usa o ULTIMO periodo com vigente_desde <= data da
# entry; entry anterior ao primeiro periodo cai no primeiro mesmo assim (nao existe preco antes
# da tabela comecar). Isso existe porque o preco DeepSeek MUDOU entre a medicao da memoria
# (2026-08-24) e a conferencia de hoje (2026-09-15) -- sem vigencia, reprecificar a tabela in
# place teria recalculado logs de agosto com o preco de hoje, o mesmo defeito que a troca de
# MODELO de 2026-07-24 ja causou uma vez (ver comentario de `groq-llama` abaixo).
#
# `in_hit`/`in_miss` existem porque a telemetria (prompt_cache_hit_tokens/prompt_cache_miss_tokens)
# ja separa os dois e um unico `in` nao consegue representar a diferenca -- e ela e grande (hit
# custa uma fracao de miss). Os tres (`in_hit`/`in_miss`/`out`) sao o preco PADRAO listado pela
# pagina do fornecedor (a taxa fora de pico, quando ela documenta as duas). `pico` e
# {"mult": float, "janelas_utc": [[h_ini,h_fim),...], "dias": [0..6, Monday=0]} ou None pra
# periodo sem janela com preco diferente do padrao; `mult` = preco da janela / preco padrao (pode
# ser > 1 ou < 1 -- aqui sempre > 1, mas o campo nao assume isso). `fonte` documenta onde o preco
# foi conferido (URL + data, ou a medicao que sustenta um periodo historico) -- a tabela
# versionada NAO e fonte, o fornecedor e (ver memoria `chave-openai-unica-em-25-projetos`, secao
# DeepSeek, 2026-08-24).
PRICING_PER_MTOKEN = {
    "deepseek-v4-flash": [
        {
            # Preco medido em 2026-08-24 contra fatura real (nao pagina) -- ver memoria. Peak
            # (01-04h e 06-10h UTC, seg-sex) documentado la como exatamente o dobro do padrao.
            "vigente_desde": "2026-08-15",  # data em que v4-flash virou modelo default do kit;
            # a data exata em que ESTE preco comecou a valer nao e conhecida (so a da medicao).
            "in_hit": 0.007, "in_miss": 0.22, "out": 0.66,
            "pico": {"mult": 2.0, "janelas_utc": [[1, 4], [6, 10]], "dias": [0, 1, 2, 3, 4]},
            "fonte": "memoria chave-openai-unica-em-25-projetos, medido contra fatura 2026-08-24",
        },
        {
            # Conferido HOJE na pagina oficial: "Off-peak rates are exactly half of peak
            # rates." e "Peak hours are 01:00 - 04:00 and 06:00 - 10:00 UTC, Monday through
            # Friday (all other hours are off-peak)." -- preco caiu frente a memoria de agosto
            # (hit 0.007->0.003, miss 0.22->0.15, out 0.66->0.6); pagina vence memoria.
            "vigente_desde": "2026-09-15",  # data da CONFERENCIA, nao da mudanca de preco --
            # a mudanca pode ter ocorrido em qualquer dia entre 2026-08-24 e hoje; desconhecido.
            "in_hit": 0.003, "in_miss": 0.15, "out": 0.6,
            "pico": {"mult": 2.0, "janelas_utc": [[1, 4], [6, 10]], "dias": [0, 1, 2, 3, 4]},
            "fonte": "https://api-docs.deepseek.com/quick_start/pricing conferido 2026-09-15",
        },
    ],  # modelo listado na pagina como "deepseek-flash"; chave mantida porque e o nome que
        # aparece nos logs/telemetria do kit.
    "deepseek-v4-pro": [{
        "vigente_desde": "2026-07-24",
        "in_hit": 0.435, "in_miss": 0.435, "out": 0.87, "pico": None,
        "fonte": "preco historico do kit (periodo anterior ao peak/off-peak, introduzido em "
                 "2026-08-16) -- nao reprecificar com o valor atual da pagina oficial",
    }],  # default 2026-07-24..2026-08-15
    "deepseek-chat": [{
        "vigente_desde": "2026-01-01",  # data anterior a qualquer log conhecido; modelo ja
        # estava em producao antes disso, mas nao ha registro de quando o preco comecou a valer.
        "in_hit": 0.27, "in_miss": 0.27, "out": 1.10, "pico": None,
        "fonte": "preco historico do kit (modelo descontinuado, sem cache-hit/peak nessa epoca)",
    }],  # descontinuado 2026-07-24
    "llama-3.3-70b-versatile": [{
        "vigente_desde": "2026-01-01",
        "in_hit": 0.59, "in_miss": 0.59, "out": 0.79, "pico": None,
        "fonte": "preco historico do kit (Groq, modelo decomissionado)",
    }],  # decomissionado pela Groq ~2026-08
    "openai/gpt-oss-120b": [{
        "vigente_desde": "2026-08-18",
        "in_hit": 0.15, "in_miss": 0.15, "out": 0.60, "pico": None,
        "fonte": "preco do kit (perna Groq, sem cache-hit/peak documentado)",
    }],  # default da perna Groq desde 2026-08-18
    # O alias `groq-llama` foi REMOVIDO em 2026-08-18, pela regra que este bloco ja aplicava aos
    # aliases `deepseek` e `cross-claude`: alias que resolve por PROVIDER so e seguro enquanto o
    # provider mapeia 1:1 num unico modelo. A justificativa antiga dizia, literalmente, "mapeia
    # 1:1 num unico modelo que nunca mudou de preco" -- e nesta data o provider trocou de modelo
    # (llama-3.3-70b-versatile -> openai/gpt-oss-120b) e de preco (0.59/0.79 -> 0.15/0.60).
    # Mantido, o alias precificaria run NOVO ao preco do modelo MORTO, 3,9x pra cima na entrada:
    # exatamente o defeito de reprecificacao que este bloco existe pra impedir -- e o mesmo
    # defeito que a vigencia por data, acima, resolve pra troca de PRECO (nao de modelo).
    # Consequencia deliberada: entrada de log sem campo `model` cai em MODELOS_SEM_PRECO, que e a
    # resposta honesta -- nao da pra saber qual dos dois rodou. Os wrappers emitem `model` no JSON
    # de resposta, entao isso so atinge log antigo, que e justamente o caso ambiguo.
    "claude-haiku-4-5": [{
        "vigente_desde": "2026-01-01",
        "in_hit": 1.00, "in_miss": 1.00, "out": 5.00, "pico": None,
        "fonte": "preco do kit (tabela regular Anthropic)",
    }],
    # Sonnet 5 esta em preco promocional de $2/$10 ate 2026-08-31. A tabela usa o preco REGULAR
    # de proposito: medidor que subestima e o defeito que esta versao acabou de consertar, e a
    # promo expira sozinha. Ate la o relatorio superestima o Sonnet 5 em ate 50%.
    "claude-sonnet-5": [{
        "vigente_desde": "2026-01-01",
        "in_hit": 3.00, "in_miss": 3.00, "out": 15.00, "pico": None,
        "fonte": "preco do kit (tabela regular Anthropic, de proposito nao-promocional)",
    }],
    "claude-opus-5": [{
        "vigente_desde": "2026-01-01",
        "in_hit": 5.00, "in_miss": 5.00, "out": 25.00, "pico": None,
        "fonte": "preco do kit (tabela regular Anthropic)",
    }],
    "claude-sonnet-4-6": [{
        "vigente_desde": "2026-01-01",
        "in_hit": 3.00, "in_miss": 3.00, "out": 15.00, "pico": None,
        "fonte": "preco do kit (tabela regular Anthropic) -- so vale pro canal PAGO; via agy "
                 "(provider gemini-agy) e cota, ver entrada 'gemini-agy' abaixo",
    }],
    "claude-opus-4-7": [{
        "vigente_desde": "2026-01-01",
        "in_hit": 5.00, "in_miss": 5.00, "out": 25.00, "pico": None,
        "fonte": "preco do kit (tabela regular Anthropic)",
    }],  # era 15/75 aqui -- 3x pra cima
    # Canal de COTA (Google AI Pro, 18 meses, ja pago): gemini e claude-sonnet-4-6 chamados via
    # essa assinatura tem custo marginal 0 -- nao e "modelo gratis", e "ja pago fora da API".
    # Chave por PROVIDER de proposito (nao por modelo): o mesmo texto "claude-sonnet-4-6" tambem
    # aparece no canal pago (cross-claude, entrada acima); e o provider que decide qual preco
    # vale, nao o nome do modelo -- ver compute_cost().
    "gemini-agy": [{
        "vigente_desde": "2026-01-01",
        "in_hit": 0.0, "in_miss": 0.0, "out": 0.0, "pico": None,
        "fonte": "cota Google AI Pro",
    }],
}


def parse_log_data(data: dict[str, Any], path: Path) -> list[dict[str, Any]]:
    """Extrai uma entrada por resposta de provider a partir de um dict ja parseado.
    Tolera entradas sem usage e responses nulas."""
    mode = data.get("mode", "unknown")
    ts = data.get("timestamp", "")
    prompt_text = (data.get("prompt") or "") + "\n" + (data.get("system_prompt") or "")
    entries: list[dict[str, Any]] = []
    for resp in data.get("responses", []) or []:
        if not resp or resp.get("status") != "ok":
            continue
        provider = resp.get("provider") or resp.get("model") or "unknown"
        usage = resp.get("usage") or {}
        tokens_in = usage.get("prompt_tokens")
        tokens_out = usage.get("completion_tokens")
        if tokens_in is None or tokens_out is None:
            tokens_in, tokens_out = _estimate_tokens(prompt_text, resp.get("content") or "")
        entries.append({
            "provider": provider,
            "model": resp.get("model", provider),
            "mode": mode,
            "timestamp": ts,
            "tokens_in": int(tokens_in),
            "tokens_out": int(tokens_out),
            "latency_ms": int(resp.get("latency_ms") or 0),
            "source": str(path),
        })
    return entries


def parse_log_file(path: Path) -> list[dict[str, Any]]:
    """Le o arquivo JSONL e delega para parse_log_data. Retorna [] em caso de erro."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return []
    return parse_log_data(data, path)


def parse_spend_file(path: Path) -> list[dict[str, Any]]:
    """Le `.deepseek/spend/<YYYY-MM>.jsonl` -- a telemetria do caminho de REVIEW.

    Por que existe (medido em 2026-08-19): o marcador `.deepseek/reviews/latest.jsonl` e
    SOBRESCRITO a cada review, decisao de 2026-07-20 que existe pra nao pendurar o hook R11
    em ~148s enumerando milhares de arquivos. A decisao esta certa pro hook e deixa o custo
    cego: naquele dia os logs de conselho de 62 diretorios `.deepseek` somaram $0.89 de um
    painel de $29.76. 97% do gasto era invisivel -- e justamente pelo caminho mais usado do
    kit (review existe em 48 projetos, o dobro do conselho).

    🔑 Diferenca de formato que morde: council-log tem extensao `.jsonl` mas e UM objeto por
    ARQUIVO. Aqui e JSONL de verdade -- N objetos, um por LINHA, append. Ler este arquivo com
    `json.loads(texto_inteiro)` devolve zero entradas sem erro nenhum, que e o mesmo modo de
    falhar calado que esta funcao existe pra acabar. Por isso o parser e proprio, e nao
    reaproveita `parse_log_file`.

    Linha corrompida (append concorrente cortado no meio) e PULADA, nao aborta o arquivo:
    perder o mes inteiro por causa de uma linha e o oposto de medir o gasto.

    Entrada sem `usage` e DESCARTADA em vez de estimada. O spend nao guarda o texto do prompt
    nem da resposta -- telemetria nao e copia de conteudo -- entao nao ha de onde estimar, e
    chutar zero somaria silenciosamente errado no total.
    """
    entries: list[dict[str, Any]] = []
    try:
        texto = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return []
    for linha in texto.splitlines():
        linha = linha.strip()
        if not linha:
            continue
        try:
            d = json.loads(linha)
        except json.JSONDecodeError:
            continue
        if not isinstance(d, dict):
            continue
        usage = d.get("usage") or {}
        tokens_in = usage.get("prompt_tokens")
        tokens_out = usage.get("completion_tokens")
        if tokens_in is None and tokens_out is None:
            continue
        model = d.get("model") or ""
        entry: dict[str, Any] = {
            "provider": d.get("provider") or model or "unknown",
            "model": model,
            # O modo identifica a FERRAMENTA, nao o modo do conselho: e isso que finalmente
            # separa "gastei revisando" de "gastei consultando" no relatorio.
            "mode": d.get("tool") or "review",
            "timestamp": d.get("timestamp", ""),
            "tokens_in": int(tokens_in or 0),
            "tokens_out": int(tokens_out or 0),
            "latency_ms": int(d.get("latency_ms") or 0),
            "source": str(path),
        }
        # Cache-hit/miss: a telemetria ja separa (`prompt_cache_hit_tokens` /
        # `prompt_cache_miss_tokens`); guardados so quando presentes -- compute_cost() cai pro
        # fallback (tudo em in_miss, erra pra cima) quando ausentes.
        hit = usage.get("prompt_cache_hit_tokens")
        miss = usage.get("prompt_cache_miss_tokens")
        if hit is not None:
            entry["tokens_in_hit"] = int(hit)
        if miss is not None:
            entry["tokens_in_miss"] = int(miss)
        entries.append(entry)
    return entries


def _estimate_tokens(prompt: str, completion: str) -> tuple[int, int]:
    try:
        import tiktoken
        enc = tiktoken.get_encoding("cl100k_base")
        return len(enc.encode(prompt)), len(enc.encode(completion))
    except ImportError:
        return (len(prompt) // 4, len(completion) // 4)


MODELOS_SEM_PRECO: set[str] = set()

# Contador de entries sem timestamp NENHUM (ausente ou nao-parseavel): nao da pra escolher
# periodo de vigencia nem janela de pico, entao a entry usa o periodo MAIS CARO entre os
# vigentes do modelo (erra pra cima) e fica de fora de pico. O contador e o rastro pra isso nao
# ficar calado. Reset em main() e nos testes que o leem, junto de MODELOS_SEM_PRECO -- mesmo
# motivo: estado de modulo sobrevive entre relatorios/testes.
SEM_TIMESTAMP: int = 0

# Contador de entries com timestamp PARSEAVEL mas sem offset de fuso (naive): a data ainda da
# pra usar (escolhe o periodo de vigencia certo), mas a HORA nao e confiavelmente UTC, entao
# pico nunca e aplicado (mult=1) -- dobrar por acaso seria pior que nao dobrar. Mesmo padrao de
# reset que SEM_TIMESTAMP e MODELOS_SEM_PRECO.
SEM_FUSO: int = 0


def _em_pico(dt_utc: datetime, pico: dict[str, Any]) -> bool:
    """True se `dt_utc` (UTC-aware) cai numa janela de pico (dia da semana + hora)."""
    if dt_utc.weekday() not in pico.get("dias", []):
        return False
    hora = dt_utc.hour
    for h_ini, h_fim in pico.get("janelas_utc", []):
        if h_ini <= hora < h_fim:
            return True
    return False


def _resolver_periodo(periodos: list[dict[str, Any]], data_iso: str | None) -> dict[str, Any]:
    """Escolhe o periodo de vigencia certo pra uma data ISO ("AAAA-MM-DD") ou None.

    Comparacao de string funciona pq "AAAA-MM-DD" ordena igual cronologicamente -- sem parsear
    pra `date`. `data_iso=None` (sem timestamp nenhum) usa o periodo MAIS CARO (soma dos tres
    precos-base, sem contar pico -- pico exige hora, que tambem falta aqui): erra pra cima,
    mesma invariante do resto do modulo. Data anterior ao primeiro periodo conhecido cai no
    primeiro periodo mesmo assim -- nao existe preco antes da tabela comecar.
    """
    if not periodos:
        # Tabela corrompida ou entrada de teste equivocada (lista vazia em vez de period(o)s):
        # nao ha preco nenhum pra devolver. Levanta em vez de IndexError opaco mais adiante --
        # quem chama `compute_cost` com uma tabela assim tem um bug de dado, nao de runtime.
        raise ValueError("_resolver_periodo recebeu lista de periodos vazia")
    if data_iso is None:
        return max(periodos, key=lambda p: p["in_hit"] + p["in_miss"] + p["out"])
    candidatos = [p for p in periodos if p["vigente_desde"] <= data_iso]
    if not candidatos:
        # Anterior a QUALQUER vigente_desde conhecido: cai no mais antigo -- nao depende da
        # tabela vir pre-ordenada, porque usa min() em vez de periodos[0].
        return min(periodos, key=lambda p: p["vigente_desde"])
    return max(candidatos, key=lambda p: p["vigente_desde"])


def compute_cost(entry: dict[str, Any], tabela: dict[str, Any] | None = None) -> float:
    """Custo USD pra uma entry. Retorna 0 se modelo desconhecido -- e ANOTA o nome.

    O 0.0 calado e o que deixou a troca de modelo de 2026-07-24 passar tres semanas sem
    aparecer em relatorio nenhum: modelo fora da tabela nao custa zero, custa o-que-a-gente-
    nao-sabe. Quem consome este modulo tem que ler MODELOS_SEM_PRECO junto com o total.

    `tabela` e injetavel pra teste (nunca a tabela real em pytest -- preco real muda e os
    testes tem que continuar valendo o mesmo depois).
    """
    global SEM_TIMESTAMP, SEM_FUSO
    if tabela is None:
        tabela = PRICING_PER_MTOKEN
    model = entry.get("model", "")
    provider = entry.get("provider", "")
    # Canal de COTA (gemini-agy): o PROVIDER decide, nao o modelo -- o mesmo modelo
    # (ex: claude-sonnet-4-6) tambem existe no canal pago, com preco != 0. Checado antes do
    # lookup por modelo de proposito, e EXCLUSIVO: se a tabela nao tiver a chave "gemini-agy",
    # cai direto em MODELOS_SEM_PRECO -- nunca em fallback pro lookup por modelo, que acharia o
    # preco do canal PAGO e cobraria cota como dinheiro de verdade (o oposto do que essa
    # entrada existe pra evitar).
    if provider == "gemini-agy":
        periodos = tabela.get("gemini-agy")
    else:
        periodos = tabela.get(model)
        if periodos is None:
            periodos = tabela.get(provider)
    if periodos is None:
        MODELOS_SEM_PRECO.add(model or provider or "?")
        return 0.0

    # Parse de timestamp: `Z` nao e aceito por `datetime.fromisoformat` antes do Python 3.11 --
    # troca por `+00:00`. Naive (sem offset) e PARSEAVEL (da pra escolher periodo pela data),
    # mas fica marcado como SEM_FUSO e nunca entra em pico -- a hora sozinha, sem fuso, nao da
    # pra saber se cai numa janela UTC.
    ts_str = entry.get("timestamp")
    dt_utc: datetime | None = None
    data_iso: str | None = None
    if not ts_str or not isinstance(ts_str, str):
        # not isinstance: log com `timestamp` nao-string (epoch numerico, por ex.) nao pode
        # estourar `.replace`/`.fromisoformat` com TypeError e derrubar o relatorio inteiro --
        # vira SEM_TIMESTAMP como qualquer outro timestamp inutilizavel, mesma invariante.
        SEM_TIMESTAMP += 1
    else:
        try:
            dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        except (ValueError, TypeError):
            dt = None
        if dt is None:
            SEM_TIMESTAMP += 1
        elif dt.tzinfo is None:
            SEM_FUSO += 1
            data_iso = dt.date().isoformat()  # usavel pra vigencia; hora nao e usavel pra pico
        else:
            dt_utc = dt.astimezone(timezone.utc)
            data_iso = dt_utc.date().isoformat()

    pricing = _resolver_periodo(periodos, data_iso)

    tokens_in_hit = entry.get("tokens_in_hit")
    tokens_in_miss = entry.get("tokens_in_miss")
    tokens_in_total = entry.get("tokens_in", 0)
    if tokens_in_hit is None and tokens_in_miss is None:
        # Sem telemetria de cache nenhuma: todo tokens_in vai pra miss (o preco mais caro) --
        # erra pra cima, nunca pra baixo.
        tokens_in_hit = 0
        tokens_in_miss = tokens_in_total
    else:
        # So um dos dois veio (o outro None): a fatia que falta pra bater com tokens_in NAO
        # pode sumir do custo -- vai pra miss (o preco mais caro), mesma invariante "erra pra
        # cima" do caso sem telemetria nenhuma. max(0, ...) porque tokens_in pode nao bater
        # exatamente com hit+miss (fontes diferentes) e negativo seria pior que zero.
        tokens_in_hit = tokens_in_hit or 0
        tokens_in_miss = tokens_in_miss or 0
        faltante = tokens_in_total - tokens_in_hit - tokens_in_miss
        if faltante > 0:
            tokens_in_miss += faltante
    tokens_out = entry.get("tokens_out", 0)

    mult = 1.0
    pico = pricing.get("pico")
    if pico is not None and dt_utc is not None and _em_pico(dt_utc, pico):
        mult = pico.get("mult", 1.0)

    custo = (tokens_in_hit / 1_000_000) * pricing["in_hit"] + \
            (tokens_in_miss / 1_000_000) * pricing["in_miss"] + \
            (tokens_out / 1_000_000) * pricing["out"]
    return custo * mult


def aggregate(entries: Iterable[dict[str, Any]]) -> dict[tuple[str, str], dict[str, Any]]:
    """Agrega por (provider, mode)."""
    agg: dict[tuple[str, str], dict[str, Any]] = defaultdict(lambda: {
        "tokens_in": 0, "tokens_out": 0, "cost": 0.0, "calls": 0, "latency_sum": 0
    })
    for e in entries:
        k = (e["provider"], e["mode"])
        agg[k]["tokens_in"] += e["tokens_in"]
        agg[k]["tokens_out"] += e["tokens_out"]
        agg[k]["cost"] += compute_cost(e)
        agg[k]["calls"] += 1
        agg[k]["latency_sum"] += e["latency_ms"]
    return agg


def render_markdown(agg: dict, entries: list, days: int) -> str:
    total = sum(v["cost"] for v in agg.values())
    out = [f"# Council spend — ultimos {days} dias\n",
           f"**Total estimado:** ${total:.2f} USD\n",
           "## Por provider x mode\n",
           "| Provider | Mode | Calls | Tokens in | Tokens out | Custo USD | Latencia media (ms) |",
           "|---|---|---:|---:|---:|---:|---:|"]
    for (prov, mode), v in sorted(agg.items(), key=lambda x: -x[1]["cost"]):
        avg_lat = v["latency_sum"] // max(v["calls"], 1)
        out.append(f"| {prov} | {mode} | {v['calls']} | {v['tokens_in']:,} | "
                   f"{v['tokens_out']:,} | ${v['cost']:.4f} | {avg_lat} |")
    out.append("\n## Top-10 consultas mais caras\n")
    out.append("| Timestamp | Provider | Mode | Custo USD | Source |")
    out.append("|---|---|---|---:|---|")
    top = sorted(entries, key=lambda e: -compute_cost(e))[:10]
    for e in top:
        out.append(f"| {e['timestamp']} | {e['provider']} | {e['mode']} | "
                   f"${compute_cost(e):.4f} | {Path(e['source']).name} |")
    if MODELOS_SEM_PRECO:
        out.append("\n## AVISO -- modelo(s) sem preco na tabela\n")
        out.append("Estas chamadas entraram no relatorio contadas como **custo zero**. "
                   "O total acima esta SUBESTIMADO ate que sejam precificadas em "
                   "`PRICING_PER_MTOKEN`:\n")
        for m in sorted(MODELOS_SEM_PRECO):
            out.append(f"- `{m}`")
        out.append("")
    if SEM_TIMESTAMP:
        out.append("\n## AVISO -- entradas sem timestamp valido\n")
        out.append(f"**{SEM_TIMESTAMP}** chamada(s) sem `timestamp` (ausente ou invalido): "
                   "cobradas no periodo de vigencia de MAIOR preco-base (erra pra cima NA "
                   "ESCOLHA DE PERIODO), mas pico NUNCA e aplicado por falta de hora confiavel "
                   "-- pode SUBESTIMAR o total se a chamada real caiu numa janela de pico.\n")
    if SEM_FUSO:
        out.append("\n## AVISO -- entradas com timestamp sem fuso (naive)\n")
        out.append(f"**{SEM_FUSO}** chamada(s) tinham `timestamp` parseavel mas sem offset de "
                   "fuso: o periodo de vigencia foi escolhido pela data mesmo assim, mas pico "
                   "NUNCA foi aplicado (hora sem fuso nao e confiavelmente UTC) -- pode "
                   "SUBESTIMAR o total se a chamada real caiu numa janela de pico.\n")
    out.append("\n## Conclusao automatica\n")
    if total == 0:
        out.append("- Nenhum custo apurado. Possivel ausencia de logs no periodo.")
    else:
        by_prov: dict[str, float] = defaultdict(float)
        for (prov, _), v in agg.items():
            by_prov[prov] += v["cost"]
        dominant, dom_cost = max(by_prov.items(), key=lambda x: x[1])
        share = dom_cost / total * 100
        out.append(f"- Provider dominante: **{dominant}** ({share:.0f}% do gasto).")
        if dominant.startswith("cross-claude") or "claude" in dominant.lower():
            out.append("- Caminho F-2 recomendado: **F.2 model router** (Cross-Claude domina).")
        elif total < 20:
            out.append("- Gasto < $20/mes: considerar **pular F-1/F-2/F-3 e ir direto pra F-4** (auditoria).")
        else:
            out.append("- Caminho F-2 recomendado: **F.5 truncation ja cobre; avaliar F.2 vs F.1 cache.**")
    return "\n".join(out) + "\n"


def main():
    # MODELOS_SEM_PRECO, SEM_TIMESTAMP e SEM_FUSO sao estado de MODULO: sem zerar aqui, um
    # segundo relatorio no mesmo processo (ou o proximo teste do pytest) herda o estado do
    # anterior e acusa subestimacao/contadores positivos num periodo que nao tem nenhuma.
    global SEM_TIMESTAMP, SEM_FUSO
    MODELOS_SEM_PRECO.clear()
    SEM_TIMESTAMP = 0
    SEM_FUSO = 0
    p = argparse.ArgumentParser()
    p.add_argument("--root", default="D:/Claud Automations")
    p.add_argument("--days", type=int, default=30)
    p.add_argument("--output", default="-")
    args = p.parse_args()

    if args.days <= 0:
        p.error("--days deve ser > 0")

    cutoff = datetime.now() - timedelta(days=args.days)
    entries: list[dict[str, Any]] = []
    for log in Path(args.root).rglob(".deepseek/council-log/*.jsonl"):
        try:
            # Leitura unica: raw dict e reaproveitado tanto pro filtro de cutoff
            # quanto para parse_log_data (evita double file read).
            raw = json.loads(log.read_text(encoding="utf-8"))
            ts_str = raw.get("timestamp", "")
            if ts_str:
                # Normalize timezone: strip offset (e.g. -03:00, +00:00, Z) to naive local
                ts_clean = re.sub(r"[+-]\d{2}:\d{2}$|Z$", "", ts_str)
                ts = datetime.fromisoformat(ts_clean)
            else:
                ts = cutoff
        except (json.JSONDecodeError, UnicodeDecodeError, OSError, ValueError):
            ts = cutoff
            raw = {}
        # Cada JSONL = 1 consulta com timestamp unico; entries herdam esse timestamp.
        # O filtro per-file e correto: se a consulta esta fora do periodo, todas as suas
        # entries (um por provider) tambem estao.
        if ts < cutoff:
            continue
        entries.extend(parse_log_data(raw, log))

    # Telemetria do caminho de REVIEW. O filtro de cutoff acima e POR ARQUIVO porque cada
    # council-log e uma consulta so. Aqui nao da: o spend e um arquivo por MES com N linhas,
    # entao o corte tem que ser POR LINHA -- filtrar por arquivo incluiria agosto inteiro num
    # relatorio de 7 dias, ou descartaria as linhas de hoje junto com as do dia 1.
    for spend in Path(args.root).rglob(".deepseek/spend/*.jsonl"):
        for e in parse_spend_file(spend):
            ts_str = e.get("timestamp") or ""
            if ts_str:
                try:
                    ts = datetime.fromisoformat(re.sub(r"[+-]\d{2}:\d{2}$|Z$", "", ts_str))
                except ValueError:
                    ts = cutoff
            else:
                ts = cutoff
            if ts < cutoff:
                continue
            entries.append(e)

    agg = aggregate(entries)
    md = render_markdown(agg, entries, args.days)

    if args.output == "-":
        print(md)
    else:
        Path(args.output).write_text(md, encoding="utf-8")
        print(f"Wrote {args.output} ({len(md)} chars).")


if __name__ == "__main__":
    main()
