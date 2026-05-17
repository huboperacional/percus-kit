"""analyze-council-spend: baseline custo do conselho 3-membros Percus.

Le logs em .deepseek/council-log/*.jsonl, estima tokens (preferindo usage real
dos providers; fallback tiktoken cl100k_base), aplica preco fixo e agrega.
"""
from __future__ import annotations
import argparse
import json
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Iterable

PRICING_PER_MTOKEN = {
    "deepseek-chat":           {"in": 0.27, "out": 1.10},
    "deepseek":                {"in": 0.27, "out": 1.10},
    "llama-3.3-70b-versatile": {"in": 0.59, "out": 0.79},
    "groq-llama":              {"in": 0.59, "out": 0.79},
    "claude-haiku-4-5":        {"in": 1.00, "out": 5.00},
    "claude-sonnet-4-6":       {"in": 3.00, "out": 15.00},
    "claude-opus-4-7":         {"in": 15.00, "out": 75.00},
    "cross-claude":            {"in": 3.00, "out": 15.00},
}


def parse_log_file(path: Path) -> list[dict[str, Any]]:
    """Extrai uma entrada por resposta de provider. Tolera entradas sem usage."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return []

    mode = data.get("mode", "unknown")
    ts = data.get("timestamp", "")
    prompt_text = (data.get("prompt") or "") + "\n" + (data.get("system_prompt") or "")
    entries: list[dict[str, Any]] = []
    for resp in data.get("responses", []) or []:
        if resp.get("status") != "ok":
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


def _estimate_tokens(prompt: str, completion: str) -> tuple[int, int]:
    try:
        import tiktoken
        enc = tiktoken.get_encoding("cl100k_base")
        return len(enc.encode(prompt)), len(enc.encode(completion))
    except ImportError:
        return (len(prompt) // 4, len(completion) // 4)


def compute_cost(entry: dict[str, Any]) -> float:
    """Custo USD pra uma entry. Retorna 0 se modelo desconhecido."""
    model = entry.get("model", "")
    pricing = PRICING_PER_MTOKEN.get(model)
    if pricing is None:
        provider = entry.get("provider", "")
        pricing = PRICING_PER_MTOKEN.get(provider)
    if pricing is None:
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
    p = argparse.ArgumentParser()
    p.add_argument("--root", default="D:/Claud Automations")
    p.add_argument("--days", type=int, default=30)
    p.add_argument("--output", default="-")
    args = p.parse_args()

    cutoff = datetime.now() - timedelta(days=args.days)
    entries: list[dict[str, Any]] = []
    for log in Path(args.root).rglob(".deepseek/council-log/*.jsonl"):
        try:
            raw = json.loads(log.read_text(encoding="utf-8"))
            ts_str = raw.get("timestamp", "")
            if ts_str:
                # Normalize timezone: strip offset (e.g. -03:00, +00:00, Z) to naive local
                import re as _re
                ts_clean = _re.sub(r"[+-]\d{2}:\d{2}$|Z$", "", ts_str)
                ts = datetime.fromisoformat(ts_clean)
            else:
                ts = cutoff
        except Exception:
            ts = cutoff
        if ts < cutoff:
            continue
        entries.extend(parse_log_file(log))

    agg = aggregate(entries)
    md = render_markdown(agg, entries, args.days)

    if args.output == "-":
        print(md)
    else:
        Path(args.output).write_text(md, encoding="utf-8")
        print(f"Wrote {args.output} ({len(md)} chars).")


if __name__ == "__main__":
    main()
