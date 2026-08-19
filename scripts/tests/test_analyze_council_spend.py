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


def test_groq_llama_perdeu_o_fallback_ao_trocar_de_familia():
    """`groq-llama` mapeava 1:1 num modelo estavel -- ate 2026-08-18.

    Nessa data o Groq aposentou `llama-3.3-70b-versatile` e a perna passou a rodar
    `openai/gpt-oss-120b`: familia diferente E preco diferente (0.59/0.79 -> 0.15/0.60).
    Com isso o provider deixou de mapear 1:1 e o alias caiu na MESMA regra que ja tinha
    removido `deepseek` e `cross-claude`.

    O teste antigo afirmava o oposto (alias vivo, 0.59+0.79). Ele nao estava errado quando
    foi escrito -- caducou junto com a premissa. Mantido como caso invertido de proposito:
    apagar o teste apagaria a memoria de que este alias ja existiu e por que morreu.
    """
    from analyze_council_spend import MODELOS_SEM_PRECO

    MODELOS_SEM_PRECO.clear()
    entry = {
        "model": "llama-mystery",   # modelo fora da tabela: forca o caminho do fallback
        "provider": "groq-llama",
        "tokens_in": 1_000_000,
        "tokens_out": 1_000_000,
    }
    assert compute_cost(entry) == 0.0
    # o zero tem que deixar rastro: precificar run novo ao preco do modelo morto seria
    # 3,9x pra cima na entrada, e calado.
    assert "llama-mystery" in MODELOS_SEM_PRECO


def test_modelo_aposentado_continua_precificavel_no_historico():
    """Remover o ALIAS nao pode reprecificar o passado.

    Log de marco/junho carrega `model: llama-3.3-70b-versatile` explicito; esse id fica na
    tabela pro historico continuar somando ao preco da epoca. Quem sumiu foi so o atalho
    por provider, que era o unico ambiguo.
    """
    entry = {
        "model": "llama-3.3-70b-versatile",
        "provider": "groq-llama",
        "tokens_in": 1_000_000,
        "tokens_out": 1_000_000,
    }
    assert compute_cost(entry) == pytest.approx(0.59 + 0.79)


def test_modelo_novo_da_perna_groq_tem_preco():
    """A perna Groq nova nao pode cair em MODELOS_SEM_PRECO -- senao o relatorio subestima."""
    entry = {
        "model": "openai/gpt-oss-120b",
        "provider": "groq-llama",
        "tokens_in": 1_000_000,
        "tokens_out": 1_000_000,
    }
    assert compute_cost(entry) == pytest.approx(0.15 + 0.60)


def test_provider_ambiguo_no_tempo_nao_tem_fallback():
    """`deepseek` e `cross-claude` trocaram de modelo no tempo, entao o alias por provider
    foi removido: preferimos avisar a reprecificar o passado com o preco de hoje."""
    from analyze_council_spend import MODELOS_SEM_PRECO

    MODELOS_SEM_PRECO.clear()
    entry = {
        "model": "",
        "provider": "deepseek",
        "tokens_in": 1_000_000,
        "tokens_out": 1_000_000,
    }
    assert compute_cost(entry) == 0.0
    # e o zero nao pode ser calado -- tem que sobrar rastro pro relatorio avisar
    assert "deepseek" in MODELOS_SEM_PRECO


def test_render_markdown_empty_entries():
    """aggregate={} e entries=[] nao deve crashar."""
    result = render_markdown({}, [], 30)
    assert "Nenhum custo apurado" in result


# --- telemetria de gasto do caminho de REVIEW (2026-08-19) --------------------
# Contexto: o marcador .deepseek/reviews/latest.jsonl e SOBRESCRITO a cada review
# (decisao de 2026-07-20, pra nao pendurar o hook R11 em 148s enumerando milhares
# de arquivos). Otimo pro hook, cego pro custo: em agosto/2026 os logs de conselho
# de 62 diretorios somaram $0.89 de um painel de $29.76 -- 97% invisivel, porque o
# caminho mais usado do kit (review, presente em 48 projetos) nao deixava rastro.
# A telemetria mora em .deepseek/spend/<YYYY-MM>.jsonl: APPEND, arquivo por mes
# (12/ano, nao milhares), em diretorio que o hook nao varre.

def test_le_spend_jsonl_com_varias_linhas(tmp_path):
    """spend/*.jsonl e JSONL DE VERDADE: N objetos, um por linha.

    Diferente do council-log, que apesar da extensao .jsonl e UM objeto por arquivo.
    Ler o spend com json.loads(arquivo inteiro) devolveria zero entradas -- que e
    exatamente o modo de falhar calado que esta telemetria existe pra acabar.
    """
    from analyze_council_spend import parse_spend_file

    d = tmp_path / ".deepseek" / "spend"
    d.mkdir(parents=True)
    log = d / "2026-08.jsonl"
    log.write_text(
        '{"timestamp":"2026-08-19T08:00:00","tool":"deepseek-review","provider":"deepseek",'
        '"model":"deepseek-v4-flash","usage":{"prompt_tokens":1000000,"completion_tokens":1000000}}\n'
        '{"timestamp":"2026-08-19T09:00:00","tool":"deepseek-review","provider":"deepseek",'
        '"model":"deepseek-v4-flash","usage":{"prompt_tokens":500000,"completion_tokens":0}}\n',
        encoding="utf-8",
    )
    entries = parse_spend_file(log)
    assert len(entries) == 2
    assert entries[0]["model"] == "deepseek-v4-flash"
    assert entries[0]["tokens_in"] == 1_000_000
    assert compute_cost(entries[0]) == pytest.approx(0.14 + 0.28)


def test_spend_ignora_linha_corrompida_sem_perder_as_boas(tmp_path):
    """Append concorrente pode deixar linha pela metade. Uma linha ruim nao pode
    apagar o mes inteiro do relatorio -- perder tudo por causa de uma linha e o
    oposto de 'medir o gasto'."""
    from analyze_council_spend import parse_spend_file

    d = tmp_path / ".deepseek" / "spend"
    d.mkdir(parents=True)
    log = d / "2026-08.jsonl"
    log.write_text(
        '{"timestamp":"2026-08-19T08:00:00","model":"deepseek-v4-flash",'
        '"usage":{"prompt_tokens":1000000,"completion_tokens":0}}\n'
        '{"timestamp":"2026-08-19T08:30:00","model":"deepseek-v4-fl\n'   # cortada no meio
        '\n'                                                              # linha vazia
        '{"timestamp":"2026-08-19T09:00:00","model":"deepseek-v4-flash",'
        '"usage":{"prompt_tokens":1000000,"completion_tokens":0}}\n',
        encoding="utf-8",
    )
    entries = parse_spend_file(log)
    assert len(entries) == 2, "as duas linhas boas tem que sobreviver a uma corrompida"


def test_spend_sem_usage_nao_inventa_token(tmp_path):
    """Sem usage nao da pra estimar: o review nao guarda o texto do prompt nem da
    resposta no spend (de proposito -- telemetria nao e copia do conteudo). Entrada
    sem usage e DESCARTADA, em vez de virar zero calado dentro do total."""
    from analyze_council_spend import parse_spend_file

    d = tmp_path / ".deepseek" / "spend"
    d.mkdir(parents=True)
    log = d / "2026-08.jsonl"
    log.write_text('{"timestamp":"2026-08-19T08:00:00","model":"deepseek-v4-flash"}\n', encoding="utf-8")
    assert parse_spend_file(log) == []
