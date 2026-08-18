## Guard de segurança checa a INTENÇÃO e não o ALVO (ex.: `APP_ENV=test` não protege banco nenhum) {#guard-checa-intencao-nao-alvo}

`tags: guard, seguranca, teste, pytest, conftest, autouse, truncate, APP_ENV, DATABASE_URL, banco live, producao, falsa seguranca, fixture`

**Sintoma:** existe um guard explícito protegendo uma operação destrutiva, o código parece defensivo, e **mesmo assim a operação roda em produção**.

**Causa-raiz — o padrão geral:** o guard verifica **a intenção declarada** em vez do **alvo real**. Caso concreto: `conftest.py` com fixture `autouse` que dá `TRUNCATE` em tabelas antes de cada teste, protegida por `if s.APP_ENV != "test": pytest.fail(...)`. Só que o `pyproject.toml` **sempre** seta `APP_ENV=test` (`[tool.pytest.ini_options] env = [...]`). O guard **nunca dispara** — ele confirma que "estou rodando testes", que é sempre verdade sob pytest. **Ele nunca olha `DATABASE_URL`.** Se a URL aponta pro banco de produção, rodar a suíte **trunca produção**, com o guard aceso e verde.

**Regra:** um guard destrutivo tem que checar **o alvo**, não o contexto. `APP_ENV=test` responde *"é um teste?"*; a pergunta certa é *"esse host/banco pode ser destruído?"*.

**Solução:** assertar sobre o **alvo** — extrair host/database da `DATABASE_URL` e falhar se não for localhost nem terminar em `_test`. Alternativas: apontar o teste pra um DB dedicado; tornar a fixture não-autouse (só quem pede DB paga).

**✅ IMPLEMENTAÇÃO DE REFERÊNCIA (2026-07-16, Scraper-prospeccao — a receita acima funcionou):**
1. **Banco dedicado** `scraper_prospeccao_test` no mesmo Postgres (owner = role da app já existente, **sem role nova**) + `alembic upgrade head`. Reversível com `DROP DATABASE`. (Se preferir **efêmero** em container no VPS, ver [Postgres efêmero pra testes destrutivos](pg-efemero-testes-destrutivos.md) — mesma família, receita distinta; escolha persistente quando não há Docker local e a suíte roda direto da máquina.)
2. **Repoint no import do `conftest.py`, ANTES dos imports de `app.*`** — crítico e fácil de errar: `get_settings()` costuma ser `lru_cache` e o módulo de database cria o engine **no import**, então **a primeira leitura vence pra sempre**. Como env var vence `env_file` no pydantic-settings, um `os.environ["DATABASE_URL"] = <test>` no topo repointa **o processo inteiro** (engine do app incluso). Imports de `app` depois disso, com `# noqa: E402`.
3. **O guard lê o engine, não a config:** `assert_test_database(test_engine.url.render_as_string(hide_password=True))` dentro da própria fixture destrutiva — re-derivado **do engine que está prestes a ser truncado**. Assim, mesmo que o repoint falhe, falha **alto** em vez de truncar calado.
4. **`hide_password=True` importa:** o guard só lê o *path* (nome do banco), e ele levanta exceção **exatamente quando a URL é a de produção** — com `hide_password=False` a senha do banco LIVE fica no frame que estoura, e `pytest --showlocals` (ou wrapper de CI) a joga no log.
5. **Suffix `_test`, não `contains "test"`** — `contains` deixa passar `test_scraper_prospeccao`, que pode ser um banco real. Teste esse caso.
6. **Prova que vale (não presuma):** **controle positivo** — plante uma linha-sentinela **no banco LIVE** numa tabela da lista de TRUNCATE, rode a suíte, confira que sobreviveu; e confira que o **banco de teste** foi truncado/re-seeded (prova que a fixture rodou, no alvo certo). Contagem de linhas sozinha é baseline inútil se o alvo já estiver vazio. **Controle negativo:** force `TEST_DATABASE_URL` no banco LIVE → tem que recusar carregar o conftest. `pg_stat_activity` confirma o alvo ao vivo.

⚠️ **O banco dedicado NÃO acelera a suíte** — se ele é remoto, o round-trip por teste continua (13 testes = ~4min). Ele só a torna **incapaz de destruir prod**. Suíte rápida é problema separado (PG local via `TEST_DATABASE_URL`).

**Sintoma-satélite que denuncia:** se testes **puros** (sem I/O) estão lentos/instáveis, alguém está fazendo I/O por baixo via `autouse`. Escape local, blast-radius zero — **sombrear a fixture pelo nome no módulo**:

    @pytest.fixture(autouse=True)
    def _truncate_tables():
        """Override conftest's DB-truncating autouse fixture — this test is pure."""
        yield

(no Scraper-prospeccao isso levou 83 testes de **240s com erros aleatórios** pra **0.7s**).

**Ref:** Scraper-prospeccao — achado 2026-07-15, **RESOLVIDO 2026-07-16**. Implementação: `services/api/tests/db_target.py` (`resolve_test_database_url`/`assert_test_database`/`derive_test_database_url`, 16 testes em 0.06s) + `services/api/tests/conftest.py`. Review R11 Cross-Claude: 0 bugs confirmados; os 2 achados aplicados viraram os pontos 4 e "precedência testável" acima. Memória `reference_pytest_trunca_banco_live_scraper`.
