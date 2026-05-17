import json
from pathlib import Path
import sys
import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from analyze_council_spend import parse_log_file, parse_log_data, compute_cost, render_markdown, aggregate

def test_parse_log_file_extracts_usage(tmp_path):
    log = tmp_path / "20260517-120000-consult.jsonl"
    log.write_text(json.dumps({
        "mode": "consult",
        "timestamp": "2026-05-17T12:00:00",
        "prompt": "Q",
        "system_prompt": "S",
        "responses": [
            {"provider": "deepseek", "status": "ok",
             "usage": {"prompt_tokens": 100, "completion_tokens": 50}},
            {"provider": "groq-llama", "status": "ok",
             "usage": {"prompt_tokens": 100, "completion_tokens": 60}},
        ],
        "total_latency_ms": 1500,
    }), encoding="utf-8")

    entries = parse_log_file(log)
    assert len(entries) == 2
    assert entries[0]["provider"] == "deepseek"
    assert entries[0]["tokens_in"] == 100
    assert entries[0]["tokens_out"] == 50
    assert entries[0]["mode"] == "consult"


def test_parse_log_data_direct(tmp_path):
    """parse_log_data recebe dict ja parseado e retorna entries corretas."""
    log_path = tmp_path / "direct.jsonl"
    data = {
        "mode": "consult",
        "timestamp": "2026-05-17T12:00:00",
        "prompt": "Q",
        "responses": [
            {"provider": "deepseek", "status": "ok",
             "usage": {"prompt_tokens": 200, "completion_tokens": 80}},
        ],
    }
    entries = parse_log_data(data, log_path)
    assert len(entries) == 1
    assert entries[0]["tokens_in"] == 200
    assert entries[0]["tokens_out"] == 80
    assert entries[0]["provider"] == "deepseek"


def test_compute_cost_deepseek():
    entry = {"model": "deepseek-chat", "tokens_in": 1_000_000, "tokens_out": 1_000_000}
    assert compute_cost(entry) == pytest.approx(0.27 + 1.10)

def test_compute_cost_unknown_model_zero():
    entry = {"model": "mystery-model", "tokens_in": 1000, "tokens_out": 500}
    assert compute_cost(entry) == 0.0


# --- 5 novos testes do code quality review ---

def test_parse_log_file_null_responses(tmp_path):
    """responses: null deve retornar [] sem crash."""
    log = tmp_path / "null-responses.jsonl"
    log.write_text(json.dumps({
        "mode": "consult",
        "timestamp": "2026-05-17T12:00:00",
        "prompt": "Q",
        "responses": None,
    }), encoding="utf-8")
    assert parse_log_file(log) == []


def test_parse_log_file_skips_non_ok(tmp_path):
    """Entry com status != 'ok' nao deve aparecer no output."""
    log = tmp_path / "non-ok.jsonl"
    log.write_text(json.dumps({
        "mode": "consult",
        "timestamp": "2026-05-17T12:00:00",
        "prompt": "Q",
        "responses": [
            {"provider": "deepseek", "status": "error",
             "usage": {"prompt_tokens": 100, "completion_tokens": 50}},
            {"provider": "groq-llama", "status": "ok",
             "usage": {"prompt_tokens": 100, "completion_tokens": 60}},
        ],
    }), encoding="utf-8")
    entries = parse_log_file(log)
    assert len(entries) == 1
    assert entries[0]["provider"] == "groq-llama"


def test_parse_log_file_malformed_json(tmp_path):
    """Arquivo com JSON invalido deve retornar []."""
    log = tmp_path / "malformed.jsonl"
    log.write_text("{not valid json", encoding="utf-8")
    assert parse_log_file(log) == []


def test_compute_cost_provider_fallback():
    """Model desconhecido mas provider conhecido deve usar pricing do provider."""
    entry = {
        "model": "claude-mystery",
        "provider": "cross-claude",
        "tokens_in": 1_000_000,
        "tokens_out": 1_000_000,
    }
    cost = compute_cost(entry)
    # cross-claude: in=3.00, out=15.00 por M tokens
    assert cost == pytest.approx(3.00 + 15.00)


def test_render_markdown_empty_entries():
    """aggregate={} e entries=[] nao deve crashar."""
    result = render_markdown({}, [], 30)
    assert "Nenhum custo apurado" in result
