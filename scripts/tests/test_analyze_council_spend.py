import json
from pathlib import Path
import sys
import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

from analyze_council_spend import parse_log_file, parse_log_data, compute_cost, render_markdown, aggregate
import analyze_council_spend as acs


@pytest.fixture(autouse=True)
def _reset_estado_de_modulo():
    """MODELOS_SEM_PRECO, SEM_TIMESTAMP e SEM_FUSO sao estado de MODULO (acumulam entre
    chamadas de compute_cost, de proposito -- e o mecanismo que avisa o relatorio real). Em
    teste isso vira vazamento entre casos se a ordem de execucao mudar; zera antes de CADA
    teste."""
    acs.MODELOS_SEM_PRECO.clear()
    acs.SEM_TIMESTAMP = 0
    acs.SEM_FUSO = 0
    yield


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
    # Forma da tabela mudou (ponto 17, resto): deepseek-v4-flash agora tem vigencia por data.
    # O timestamp "2026-08-19T08:00:00" e ANTERIOR ao periodo de setembro (vigente_desde
    # 2026-09-15), entao usa o periodo de agosto (preco da memoria, medido contra fatura
    # 2026-08-24): in_miss 0.22 + out 0.66 = 0.88. Sem prompt_cache_hit_tokens/miss no usage,
    # compute_cost joga tudo em in_miss (erra pra cima). O timestamp e NAIVE (sem offset de
    # fuso) -- pico nunca e aplicado (SEM_FUSO), mesmo caindo na janela 06-10h UTC de horario.
    assert compute_cost(entries[0]) == pytest.approx(0.88)


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


# --- preco com cache-hit, cache-miss e horario de pico (ponto 17, resto, T3 -----------------
# Tabela sempre INJETADA (nunca PRICING_PER_MTOKEN real): preco real muda com o fornecedor, os
# casos abaixo tem que continuar valendo o mesmo depois.

_TABELA_TESTE = {
    "modelo-teste": [{
        "vigente_desde": "2026-01-01",
        "in_hit": 0.007, "in_miss": 0.22, "out": 0.66,
        "pico": {"mult": 2.0, "janelas_utc": [[1, 4]], "dias": [0, 1, 2, 3, 4]},
        "fonte": "tabela de teste, nao e preco real",
    }],
}


def test_cache_hit_miss_fora_de_pico():
    """1M hit + 1M miss + 1M out, terca (weekday 1) 12:00 UTC -- fora da janela 01-04h."""
    entry = {
        "model": "modelo-teste",
        "tokens_in_hit": 1_000_000, "tokens_in_miss": 1_000_000, "tokens_out": 1_000_000,
        "timestamp": "2026-09-15T12:00:00Z",  # terca
    }
    assert compute_cost(entry, _TABELA_TESTE) == pytest.approx(0.887)


def test_cache_hit_miss_em_pico_dobra():
    """Mesma entry, mesmo dia (terca), mas 03:00 UTC cai em 01-04h -- dobra."""
    entry = {
        "model": "modelo-teste",
        "tokens_in_hit": 1_000_000, "tokens_in_miss": 1_000_000, "tokens_out": 1_000_000,
        "timestamp": "2026-09-15T03:00:00Z",
    }
    assert compute_cost(entry, _TABELA_TESTE) == pytest.approx(1.774)


def test_pico_nao_vale_no_fim_de_semana():
    """Mesmo horario (03:00 UTC), mas sabado (weekday 5) nao esta em `dias` -- sem pico."""
    entry = {
        "model": "modelo-teste",
        "tokens_in_hit": 1_000_000, "tokens_in_miss": 1_000_000, "tokens_out": 1_000_000,
        "timestamp": "2026-09-19T03:00:00Z",  # sabado
    }
    assert compute_cost(entry, _TABELA_TESTE) == pytest.approx(0.887)


def test_sem_hit_miss_tudo_vai_pra_miss():
    """So `tokens_in` (sem separar hit/miss) + 0 out: erra pra cima, tudo em in_miss."""
    entry = {"model": "modelo-teste", "tokens_in": 1_000_000, "tokens_out": 0}
    assert compute_cost(entry, _TABELA_TESTE) == pytest.approx(0.22)


def test_sem_timestamp_sem_pico_e_conta_no_contador():
    """timestamp ausente ou invalido: preco fica FORA de pico (nunca dobra por acaso) e o
    contador SEM_TIMESTAMP registra o rastro -- silencio seria subestimar sem avisar."""
    import analyze_council_spend as acs

    acs.SEM_TIMESTAMP = 0
    entry = {"model": "modelo-teste", "tokens_in": 1_000_000, "tokens_out": 0}  # sem timestamp
    assert compute_cost(entry, _TABELA_TESTE) == pytest.approx(0.22)  # fora de pico
    assert acs.SEM_TIMESTAMP == 1


def test_gemini_agy_e_cota_custo_zero_e_fora_de_modelos_sem_preco():
    """Canal de cota (Google AI Pro): modelo fora da tabela mas PROVIDER gemini-agy resolve
    pra custo 0 -- e diferente de 'modelo desconhecido', entao nao entra em MODELOS_SEM_PRECO."""
    from analyze_council_spend import MODELOS_SEM_PRECO

    MODELOS_SEM_PRECO.clear()
    tabela = {
        "gemini-agy": [{
            "vigente_desde": "2026-01-01",
            "in_hit": 0.0, "in_miss": 0.0, "out": 0.0, "pico": None, "fonte": "teste",
        }],
    }
    entry = {
        "model": "gemini-3.1-pro-high", "provider": "gemini-agy",
        "tokens_in": 1_000_000, "tokens_out": 1_000_000,
    }
    assert compute_cost(entry, tabela) == 0.0
    assert "gemini-3.1-pro-high" not in MODELOS_SEM_PRECO
    assert not MODELOS_SEM_PRECO


# --- vigencia por data e fuso naive (decisao do controlador, rodada 2) ----------------------

_TABELA_VIGENCIA = {
    "modelo-vigente": [
        {
            "vigente_desde": "2026-08-15",
            "in_hit": 0.007, "in_miss": 0.22, "out": 0.66, "pico": None,
            "fonte": "periodo agosto (teste)",
        },
        {
            "vigente_desde": "2026-09-15",
            "in_hit": 0.003, "in_miss": 0.15, "out": 0.6, "pico": None,
            "fonte": "periodo setembro (teste)",
        },
    ],
}


def test_vigencia_escolhe_periodo_de_agosto():
    """Entry de agosto usa o preco de agosto, mesmo com o periodo de setembro na tabela."""
    entry = {
        "model": "modelo-vigente", "tokens_in": 1_000_000, "tokens_out": 1_000_000,
        "timestamp": "2026-08-20T10:00:00Z",
    }
    assert compute_cost(entry, _TABELA_VIGENCIA) == pytest.approx(0.22 + 0.66)


def test_vigencia_escolhe_periodo_de_setembro():
    """Mesma entry, mesmo modelo, so a data muda -- preco de setembro (mais barato)."""
    entry = {
        "model": "modelo-vigente", "tokens_in": 1_000_000, "tokens_out": 1_000_000,
        "timestamp": "2026-09-20T10:00:00Z",
    }
    assert compute_cost(entry, _TABELA_VIGENCIA) == pytest.approx(0.15 + 0.6)


def test_vigencia_entrada_antes_do_primeiro_periodo_usa_o_primeiro():
    """Timestamp anterior a qualquer vigente_desde conhecido: cai no primeiro periodo mesmo
    assim -- nao existe preco antes da tabela comecar."""
    entry = {
        "model": "modelo-vigente", "tokens_in": 1_000_000, "tokens_out": 1_000_000,
        "timestamp": "2026-01-01T10:00:00Z",
    }
    assert compute_cost(entry, _TABELA_VIGENCIA) == pytest.approx(0.22 + 0.66)


def test_fuso_naive_nao_aplica_pico_e_conta_sem_fuso():
    """Timestamp SEM offset (naive) e parseavel: a DATA ainda escolhe o periodo certo, mas
    pico nunca e aplicado (hora sem fuso nao e confiavelmente UTC) -- e o contador SEM_FUSO
    (distinto de SEM_TIMESTAMP) registra o caso."""
    import analyze_council_spend as acs

    tabela = {
        "modelo-pico": [{
            "vigente_desde": "2026-01-01",
            "in_hit": 0.007, "in_miss": 0.22, "out": 0.66,
            "pico": {"mult": 2.0, "janelas_utc": [[1, 4]], "dias": [0, 1, 2, 3, 4]},
            "fonte": "teste",
        }],
    }
    entry = {
        "model": "modelo-pico", "tokens_in": 1_000_000, "tokens_out": 0,
        "timestamp": "2026-09-15T03:00:00",  # terca, 03:00 -- cairia em pico SE tivesse fuso
    }
    assert compute_cost(entry, tabela) == pytest.approx(0.22)  # sem mult, apesar da hora
    assert acs.SEM_FUSO == 1
    assert acs.SEM_TIMESTAMP == 0
