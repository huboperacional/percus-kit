import json
from pathlib import Path
import pytest

import sys
sys.path.insert(0, str(Path(__file__).parent.parent))

from analyze_council_spend import parse_log_file

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
