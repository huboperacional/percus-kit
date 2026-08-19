"""analyze-council-spend: baseline custo do conselho 3-membros Percus.

Le logs em .deepseek/council-log/*.jsonl, estima tokens (preferindo usage real
dos providers; fallback tiktoken cl100k_base), aplica preco fixo e agrega.
"""
from __future__ import annotations
import argparse
import json
import re
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Iterable

# Keys duplicadas (ex: "deepseek" e "deepseek-chat") sao aliases deliberados:
# cobrem tanto o provider name retornado pela API quanto o model name nos logs.
# Modelos APOSENTADOS ficam na tabela de proposito: log de marco/junho foi cobrado ao preco
# daquela epoca, e apagar a linha faria o historico ser reprecificado (ou cair no fallback e
# virar 0). Entrada nova nao substitui a velha -- acompanha.
PRICING_PER_MTOKEN = {
    "deepseek-v4-flash":       {"in": 0.14,  "out": 0.28},   # default desde 2026-08-15
    "deepseek-v4-pro":         {"in": 0.435, "out": 0.87},   # default 2026-07-24..2026-08-15
    "deepseek-chat":           {"in": 0.27,  "out": 1.10},   # descontinuado 2026-07-24
    "llama-3.3-70b-versatile": {"in": 0.59,  "out": 0.79},   # decomissionado pela Groq ~2026-08
    "openai/gpt-oss-120b":     {"in": 0.15,  "out": 0.60},   # default da perna Groq desde 2026-08-18
    # O alias `groq-llama` foi REMOVIDO em 2026-08-18, pela regra que este bloco ja aplicava aos
    # aliases `deepseek` e `cross-claude`: alias que resolve por PROVIDER so e seguro enquanto o
    # provider mapeia 1:1 num unico modelo. A justificativa antiga dizia, literalmente, "mapeia
    # 1:1 num unico modelo que nunca mudou de preco" -- e nesta data o provider trocou de modelo
    # (llama-3.3-70b-versatile -> openai/gpt-oss-120b) e de preco (0.59/0.79 -> 0.15/0.60).
    # Mantido, o alias precificaria run NOVO ao preco do modelo MORTO, 3,9x pra cima na entrada:
    # exatamente o defeito de reprecificacao que este bloco existe pra impedir.
    # Consequencia deliberada: entrada de log sem campo `model` cai em MODELOS_SEM_PRECO, que e a
    # resposta honesta -- nao da pra saber qual dos dois rodou. Os wrappers emitem `model` no JSON
    # de resposta, entao isso so atinge log antigo, que e justamente o caso ambiguo.
    "claude-haiku-4-5":        {"in": 1.00,  "out": 5.00},
    # Sonnet 5 esta em preco promocional de $2/$10 ate 2026-08-31. A tabela usa o preco REGULAR
    # de proposito: medidor que subestima e o defeito que esta versao acabou de consertar, e a
    # promo expira sozinha. Ate la o relatorio superestima o Sonnet 5 em ate 50%.
    "claude-sonnet-5":         {"in": 3.00,  "out": 15.00},
    "claude-opus-5":           {"in": 5.00,  "out": 25.00},
    "claude-sonnet-4-6":       {"in": 3.00,  "out": 15.00},
    "claude-opus-4-7":         {"in": 5.00,  "out": 25.00},  # era 15/75 aqui -- 3x pra cima
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
        entries.append({
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
        })
    return entries


def _estimate_tokens(prompt: str, completion: str) -> tuple[int, int]:
    try:
        import tiktoken
        enc = tiktoken.get_encoding("cl100k_base")
        return len(enc.encode(prompt)), len(enc.encode(completion))
    except ImportError:
        return (len(prompt) // 4, len(completion) // 4)


MODELOS_SEM_PRECO: set[str] = set()


def compute_cost(entry: dict[str, Any]) -> float:
    """Custo USD pra uma entry. Retorna 0 se modelo desconhecido -- e ANOTA o nome.

    O 0.0 calado e o que deixou a troca de modelo de 2026-07-24 passar tres semanas sem
    aparecer em relatorio nenhum: modelo fora da tabela nao custa zero, custa o-que-a-gente-
    nao-sabe. Quem consome este modulo tem que ler MODELOS_SEM_PRECO junto com o total.
    """
    model = entry.get("model", "")
    pricing = PRICING_PER_MTOKEN.get(model)
    if pricing is None:
        provider = entry.get("provider", "")
        pricing = PRICING_PER_MTOKEN.get(provider)
    if pricing is None:
        MODELOS_SEM_PRECO.add(model or entry.get("provider", "") or "?")
        return 0.0
    return (entry["tokens_in"] / 1_000_000) * pricing["in"] + \
           (entry["tokens_out"] / 1_000_000) * pricing["out"]


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
    # MODELOS_SEM_PRECO e estado de MODULO: sem zerar aqui, um segundo relatorio no mesmo
    # processo (ou o proximo teste do pytest) herda os modelos desconhecidos do anterior e
    # acusa subestimacao num periodo que nao tem nenhuma.
    MODELOS_SEM_PRECO.clear()
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
